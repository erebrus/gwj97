from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from models import Event, LevelAttempt, MetricSample, Run


class InvalidMetricsFile(ValueError):
    """Raised when a metrics JSON payload fails structural validation."""


class BlockedRun(ValueError):
    """Raised when a run is excluded by the uuid/username blocklists."""


@dataclass
class IngestResult:
    uuid: str
    run_id: int
    replaced: bool
    level_attempts: int
    events: int
    metric_samples: int


def ingest_file(
    path: Path,
    session: Session,
    *,
    blocked_uuids: frozenset[str] = frozenset(),
    blocked_usernames: frozenset[str] = frozenset(),
) -> IngestResult:
    with open(path, "r", encoding="utf-8") as f:
        payload = json.load(f)
    return ingest_payload(
        payload,
        session,
        source_filename=path.name,
        blocked_uuids=blocked_uuids,
        blocked_usernames=blocked_usernames,
    )


def ingest_payload(
    payload: Any,
    session: Session,
    source_filename: str | None = None,
    *,
    blocked_uuids: frozenset[str] = frozenset(),
    blocked_usernames: frozenset[str] = frozenset(),
) -> IngestResult:
    if not isinstance(payload, dict):
        raise InvalidMetricsFile("payload must be a JSON object")

    # Parse + validate everything in memory before touching the DB, so a
    # malformed file can never partially overwrite a previously good run.
    run = _build_run(payload, source_filename)

    # Check blocklists before touching the DB so a now-blocked re-ingest
    # never deletes a previously stored run.
    if run.uuid in blocked_uuids:
        raise BlockedRun(f"uuid {run.uuid} is blocklisted")
    if run.username is not None and run.username in blocked_usernames:
        raise BlockedRun(f"username {run.username!r} is blocklisted")

    existing_id = session.scalar(
        select(Run.id).where(Run.uuid == run.uuid, Run.run_id == run.run_id)
    )
    replaced = existing_id is not None
    if replaced:
        session.execute(delete(Run).where(Run.id == existing_id))
        session.flush()
        # FK cascade removes children at the DB level, but ORM identity
        # map still holds them; clear it so newly inserted children with
        # reused PKs don't collide.
        session.expunge_all()

    session.add(run)
    session.flush()

    n_events = sum(len(la.events) for la in run.level_attempts)
    n_samples = sum(len(la.metric_samples) for la in run.level_attempts)

    return IngestResult(
        uuid=run.uuid,
        run_id=run.run_id,
        replaced=replaced,
        level_attempts=len(run.level_attempts),
        events=n_events,
        metric_samples=n_samples,
    )


def _build_run(payload: dict, source_filename: str | None) -> Run:
    metadata = payload.get("metadata")
    if not isinstance(metadata, dict):
        raise InvalidMetricsFile("missing or invalid 'metadata' object")

    uuid = metadata.get("uuid")
    if not isinstance(uuid, str) or not uuid:
        raise InvalidMetricsFile("metadata.uuid missing or not a non-empty string")

    run_id = metadata.get("run_id")
    # Some producers serialize run_id as a float (e.g. 1779701666.0); accept
    # any whole number, but reject bools and non-integral values.
    if isinstance(run_id, bool):
        raise InvalidMetricsFile("metadata.run_id missing or not an int")
    if isinstance(run_id, float) and run_id.is_integer():
        run_id = int(run_id)
    if not isinstance(run_id, int):
        raise InvalidMetricsFile("metadata.run_id missing or not an int")

    data = payload.get("data")
    if not isinstance(data, list):
        raise InvalidMetricsFile("missing or invalid 'data' list")

    run = Run(
        uuid=uuid,
        run_id=run_id,
        os=_opt_str(metadata, "OS"),
        version=_opt_str(metadata, "version"),
        username=_opt_str(metadata, "username"),
        session_id=_opt_int(metadata, "session_id"),
        session_start_time=_opt_str(metadata, "session_start_time"),
        start_time=_opt_str(metadata, "start_time"),
        end_time=_opt_str(metadata, "end_time"),
        fullscreen=_opt_str(metadata, "fullscreen"),
        screen_size=_opt_str(metadata, "screen_size"),
        window_size=_opt_str(metadata, "window_size"),
        raw_metadata=metadata,
        source_filename=source_filename,
    )

    for sequence, attempt_payload in enumerate(data):
        run.level_attempts.append(_build_level_attempt(attempt_payload, sequence))

    return run


def _build_level_attempt(payload: Any, sequence: int) -> LevelAttempt:
    if not isinstance(payload, dict):
        raise InvalidMetricsFile(f"data[{sequence}] is not an object")

    level = payload.get("level")
    if not isinstance(level, str):
        raise InvalidMetricsFile(f"data[{sequence}].level missing or not a string")

    attempt = LevelAttempt(level=level, sequence=sequence)

    # Orion levels generate noisy card telemetry that we don't want stored.
    skip_card_events = "orion" in level.lower()

    events = payload.get("events", [])
    if not isinstance(events, list):
        raise InvalidMetricsFile(f"data[{sequence}].events is not a list")
    for i, e in enumerate(events):
        event = _build_event(e, sequence, i)
        if skip_card_events and event.name in ("card_seen", "card_picked"):
            continue
        attempt.events.append(event)

    values = payload.get("values", {})
    if not isinstance(values, dict):
        raise InvalidMetricsFile(f"data[{sequence}].values is not an object")
    for metric_name, samples in values.items():
        if not isinstance(samples, list):
            raise InvalidMetricsFile(
                f"data[{sequence}].values[{metric_name!r}] is not a list"
            )
        for j, s in enumerate(samples):
            attempt.metric_samples.append(
                _build_sample(metric_name, s, sequence, j)
            )

    return attempt


def _build_event(payload: Any, level_idx: int, event_idx: int) -> Event:
    where = f"data[{level_idx}].events[{event_idx}]"
    if not isinstance(payload, dict):
        raise InvalidMetricsFile(f"{where} is not an object")

    name = payload.get("name")
    if not isinstance(name, str) or not name:
        raise InvalidMetricsFile(f"{where}.name missing or not a non-empty string")

    timestamp = payload.get("timestamp")
    if not isinstance(timestamp, int) or isinstance(timestamp, bool):
        raise InvalidMetricsFile(f"{where}.timestamp missing or not an int")

    turn = payload.get("turn")
    if not isinstance(turn, int) or isinstance(turn, bool):
        raise InvalidMetricsFile(f"{where}.turn missing or not an int")

    data = payload.get("data")
    if data is not None and not isinstance(data, (dict, list)):
        raise InvalidMetricsFile(f"{where}.data must be object, array, or absent")

    return Event(name=name, timestamp_ms=timestamp, turn=turn, data=data)


def _build_sample(
    metric_name: str, payload: Any, level_idx: int, sample_idx: int
) -> MetricSample:
    where = f"data[{level_idx}].values[{metric_name!r}][{sample_idx}]"
    if not isinstance(payload, dict):
        raise InvalidMetricsFile(f"{where} is not an object")

    value = payload.get("value")
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise InvalidMetricsFile(f"{where}.value missing or not numeric")

    timestamp = payload.get("timestamp")
    if not isinstance(timestamp, int) or isinstance(timestamp, bool):
        raise InvalidMetricsFile(f"{where}.timestamp missing or not an int")

    turn = payload.get("turn")
    if not isinstance(turn, int) or isinstance(turn, bool):
        raise InvalidMetricsFile(f"{where}.turn missing or not an int")

    return MetricSample(
        metric_name=metric_name,
        value=float(value),
        timestamp_ms=timestamp,
        turn=turn,
    )


def _opt_str(d: dict, key: str) -> str | None:
    v = d.get(key)
    if v is None:
        return None
    return str(v)


def _opt_int(d: dict, key: str) -> int | None:
    v = d.get(key)
    if v is None:
        return None
    if isinstance(v, bool):
        return None
    if isinstance(v, int):
        return v
    try:
        return int(v)
    except (TypeError, ValueError):
        return None
