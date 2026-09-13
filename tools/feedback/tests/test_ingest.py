from __future__ import annotations

import json
from pathlib import Path

import pytest
from click.testing import CliRunner
from sqlalchemy import select
from sqlalchemy.orm import Session

from cli import cli
from db import make_engine, make_session_factory
from ingest import InvalidMetricsFile, ingest_file, ingest_payload
from models import Event, LevelAttempt, MetricSample, Run


EXAMPLE_FILE = Path(__file__).parent.parent / "example_metrics.json"


@pytest.fixture
def session() -> Session:
    engine = make_engine("sqlite:///:memory:")
    SessionFactory = make_session_factory(engine)
    with SessionFactory() as s:
        yield s


def _sample_payload(uuid: str = "abc", run_id: int = 1) -> dict:
    return {
        "metadata": {
            "uuid": uuid,
            "run_id": run_id,
            "version": "1.0",
            "OS": "Linux",
            "username": "tester",
            "session_id": 42,
        },
        "data": [
            {
                "level": "res://lv1",
                "events": [
                    {"name": "level_started", "timestamp": 100, "turn": 0, "data": {"a": 1}},
                    {"name": "level_started", "timestamp": 200, "turn": 1},
                ],
                "values": {
                    "coins": [
                        {"value": 1.0, "timestamp": 100, "turn": 0},
                        {"value": 2.0, "timestamp": 200, "turn": 1},
                    ],
                    "void_speed": [{"value": 0.5, "timestamp": 150, "turn": 1}],
                },
            },
            {
                "level": "res://lv2",
                "events": [],
                "values": {},
            },
        ],
        "metrics": [],
    }


def test_ingest_example_file(session: Session):
    with session.begin():
        result = ingest_file(EXAMPLE_FILE, session)

    assert result.uuid == "3a1d1ce6-15ae-4f7e-ac96-b3321e5ae884"
    assert result.run_id == 1779701666
    assert result.replaced is False
    assert result.level_attempts == 1
    assert result.events == 1
    assert result.metric_samples == 0

    run = session.scalars(select(Run)).one()
    assert run.os == "Windows"
    assert run.version == "1.7.2"
    assert run.source_filename == "example_metrics.json"
    assert run.raw_metadata["session_id"] == 1779701664

    event = session.scalars(select(Event)).one()
    assert event.name == "level_started"
    assert event.timestamp_ms == 5692
    assert event.turn == 0
    assert event.data["cards"][0] == "block1"


def test_ingest_two_levels_with_samples(session: Session):
    with session.begin():
        result = ingest_payload(_sample_payload(), session)

    assert result.level_attempts == 2
    assert result.events == 2
    assert result.metric_samples == 3

    lvl1 = session.scalars(
        select(LevelAttempt).where(LevelAttempt.level == "res://lv1")
    ).one()
    assert lvl1.sequence == 0
    coins = sorted(
        (s for s in lvl1.metric_samples if s.metric_name == "coins"),
        key=lambda s: s.timestamp_ms,
    )
    assert [s.value for s in coins] == [1.0, 2.0]

    lvl2 = session.scalars(
        select(LevelAttempt).where(LevelAttempt.level == "res://lv2")
    ).one()
    assert lvl2.sequence == 1
    assert lvl2.events == []
    assert lvl2.metric_samples == []


def test_replace_existing_run(session: Session):
    with session.begin():
        ingest_payload(_sample_payload(uuid="u", run_id=7), session)

    # Replacement payload: same (uuid, run_id), different shape
    replacement = {
        "metadata": {"uuid": "u", "run_id": 7, "version": "1.1"},
        "data": [{"level": "res://only", "events": [], "values": {}}],
        "metrics": [],
    }
    with session.begin():
        result = ingest_payload(replacement, session)

    assert result.replaced is True
    assert session.scalar(select(Run.id).where(Run.uuid == "u", Run.run_id == 7)) is not None
    assert session.query(Run).count() == 1
    assert session.query(LevelAttempt).count() == 1
    # Events and samples from the prior version should be gone (cascade).
    assert session.query(Event).count() == 0
    assert session.query(MetricSample).count() == 0


def test_different_runs_coexist(session: Session):
    with session.begin():
        ingest_payload(_sample_payload(uuid="u1", run_id=1), session)
    with session.begin():
        ingest_payload(_sample_payload(uuid="u1", run_id=2), session)
    with session.begin():
        ingest_payload(_sample_payload(uuid="u2", run_id=1), session)

    assert session.query(Run).count() == 3


def test_missing_uuid_rejected(session: Session):
    payload = {"metadata": {"run_id": 1}, "data": []}
    with pytest.raises(InvalidMetricsFile, match="uuid"):
        with session.begin():
            ingest_payload(payload, session)


def test_missing_run_id_rejected(session: Session):
    payload = {"metadata": {"uuid": "x"}, "data": []}
    with pytest.raises(InvalidMetricsFile, match="run_id"):
        with session.begin():
            ingest_payload(payload, session)


def test_invalid_event_rejected(session: Session):
    payload = {
        "metadata": {"uuid": "x", "run_id": 1},
        "data": [{"level": "l", "events": [{"name": "x", "turn": 0}], "values": {}}],
    }
    with pytest.raises(InvalidMetricsFile, match="timestamp"):
        with session.begin():
            ingest_payload(payload, session)


def test_invalid_sample_rejected(session: Session):
    payload = {
        "metadata": {"uuid": "x", "run_id": 1},
        "data": [
            {
                "level": "l",
                "events": [],
                "values": {"m": [{"value": "not-a-number", "timestamp": 1, "turn": 0}]},
            }
        ],
    }
    with pytest.raises(InvalidMetricsFile, match="value"):
        with session.begin():
            ingest_payload(payload, session)


def test_failed_ingest_does_not_partially_overwrite(session: Session):
    # Seed a good run. _sample_payload has: 1 run, 2 level attempts, 2 events, 3 samples.
    good = _sample_payload(uuid="u", run_id=42)
    with session.begin():
        ingest_payload(good, session)

    # Now try to replace it with a payload that's structurally broken.
    broken = _sample_payload(uuid="u", run_id=42)
    broken["data"][0]["events"][0].pop("timestamp")

    with pytest.raises(InvalidMetricsFile):
        with session.begin():
            ingest_payload(broken, session)

    # Seed data should be exactly intact.
    assert session.query(Run).count() == 1
    assert session.query(LevelAttempt).count() == 2
    assert session.query(Event).count() == 2
    assert session.query(MetricSample).count() == 3


def _make_db_with_runs(tmp_path: Path, runs: list[tuple[str, int]]) -> Path:
    """Initialize a fresh SQLite DB and ingest one _sample_payload per (uuid, run_id)."""
    db_path = tmp_path / "feedback.db"
    engine = make_engine(f"sqlite:///{db_path}")
    SessionFactory = make_session_factory(engine)
    with SessionFactory() as s:
        with s.begin():
            for uuid, run_id in runs:
                ingest_payload(_sample_payload(uuid=uuid, run_id=run_id), s)
    return db_path


def test_cli_ingest_example(tmp_path: Path):
    db_path = tmp_path / "feedback.db"
    runner = CliRunner()
    result = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "ingest", str(EXAMPLE_FILE)],
    )
    assert result.exit_code == 0, result.output
    assert "Inserted example_metrics.json" in result.output

    # Re-run: should report Replaced, exit 0.
    result2 = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "ingest", str(EXAMPLE_FILE)],
    )
    assert result2.exit_code == 0, result2.output
    assert "Replaced example_metrics.json" in result2.output


def test_cli_ingest_directory(tmp_path: Path):
    # Drop two distinct runs into a directory.
    a = _sample_payload(uuid="dir-a", run_id=1)
    b = _sample_payload(uuid="dir-b", run_id=1)
    (tmp_path / "a.json").write_text(json.dumps(a))
    (tmp_path / "b.json").write_text(json.dumps(b))

    db_path = tmp_path / "feedback.db"
    runner = CliRunner()
    result = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "ingest", str(tmp_path)],
    )
    assert result.exit_code == 0, result.output
    assert "Done: 2 ingested, 0 skipped, 0 failed." in result.output


def test_cli_ingest_directory_with_one_bad_file(tmp_path: Path):
    good = _sample_payload(uuid="ok", run_id=1)
    bad = {"metadata": {"uuid": "x"}, "data": []}  # missing run_id
    (tmp_path / "good.json").write_text(json.dumps(good))
    (tmp_path / "bad.json").write_text(json.dumps(bad))

    db_path = tmp_path / "feedback.db"
    runner = CliRunner()
    result = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "ingest", str(tmp_path)],
    )
    assert result.exit_code == 1
    assert "Done: 1 ingested, 0 skipped, 1 failed." in result.output
    # Good file made it through despite the bad one.
    engine = make_engine(f"sqlite:///{db_path}")
    SessionFactory = make_session_factory(engine)
    with SessionFactory() as s:
        assert s.query(Run).count() == 1


def test_cli_list_uuids_empty(tmp_path: Path):
    db_path = _make_db_with_runs(tmp_path, [])
    runner = CliRunner()
    result = runner.invoke(
        cli, ["--db-url", f"sqlite:///{db_path}", "list_uuids"]
    )
    assert result.exit_code == 0
    assert result.output == ""


def test_cli_list_uuids(tmp_path: Path):
    db_path = _make_db_with_runs(
        tmp_path, [("uuid-a", 1), ("uuid-a", 2), ("uuid-b", 1)]
    )
    runner = CliRunner()
    result = runner.invoke(
        cli, ["--db-url", f"sqlite:///{db_path}", "list_uuids"]
    )
    assert result.exit_code == 0
    assert result.output.splitlines() == ["uuid-a", "uuid-b"]


def test_cli_list_runs_empty(tmp_path: Path):
    db_path = _make_db_with_runs(tmp_path, [])
    runner = CliRunner()
    result = runner.invoke(
        cli, ["--db-url", f"sqlite:///{db_path}", "list_runs"]
    )
    assert result.exit_code == 0
    assert "(no runs)" in result.output


def test_cli_list_runs(tmp_path: Path):
    db_path = _make_db_with_runs(
        tmp_path, [("uuid-b", 5), ("uuid-a", 2), ("uuid-a", 1)]
    )
    runner = CliRunner()
    result = runner.invoke(
        cli, ["--db-url", f"sqlite:///{db_path}", "list_runs"]
    )
    assert result.exit_code == 0
    lines = result.output.splitlines()
    assert len(lines) == 3
    # Sorted by uuid, then run_id ascending.
    assert lines[0].startswith("uuid-a\t1\t")
    assert lines[1].startswith("uuid-a\t2\t")
    assert lines[2].startswith("uuid-b\t5\t")


def test_cli_remove_run(tmp_path: Path):
    db_path = _make_db_with_runs(
        tmp_path, [("uuid-a", 1), ("uuid-a", 2)]
    )
    runner = CliRunner()
    result = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "remove_run", "uuid-a", "1"],
    )
    assert result.exit_code == 0
    assert "Removed run uuid=uuid-a run_id=1" in result.output

    engine = make_engine(f"sqlite:///{db_path}")
    SessionFactory = make_session_factory(engine)
    with SessionFactory() as s:
        assert s.query(Run).count() == 1
        remaining = s.scalars(select(Run)).one()
        assert remaining.run_id == 2
        # Children cascaded away.
        assert s.query(LevelAttempt).count() == 2  # only the surviving run's
        assert s.query(Event).count() == 2
        assert s.query(MetricSample).count() == 3


def test_cli_remove_run_not_found(tmp_path: Path):
    db_path = _make_db_with_runs(tmp_path, [("uuid-a", 1)])
    runner = CliRunner()
    result = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "remove_run", "uuid-b", "999"],
    )
    assert result.exit_code == 1
    assert "No run found" in result.output


def test_cli_show_run(tmp_path: Path):
    db_path = _make_db_with_runs(tmp_path, [("uuid-a", 1)])
    runner = CliRunner()
    result = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "show_run", "uuid-a", "1"],
    )
    assert result.exit_code == 0
    out = result.output
    assert "uuid=uuid-a" in out
    assert "run_id=1" in out
    assert "Metadata:" in out
    assert "version: 1.0" in out
    assert "Levels (2):" in out
    assert "res://lv1" in out
    assert "res://lv2" in out
    assert "level_started" in out
    assert "coins" in out
    assert "void_speed" in out


def test_cli_show_run_with_example_file(tmp_path: Path):
    # Use the real example file to exercise an event with a non-empty 'data' payload.
    db_path = tmp_path / "feedback.db"
    runner = CliRunner()
    ingest_result = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "ingest", str(EXAMPLE_FILE)],
    )
    assert ingest_result.exit_code == 0

    result = runner.invoke(
        cli,
        [
            "--db-url",
            f"sqlite:///{db_path}",
            "show_run",
            "3a1d1ce6-15ae-4f7e-ac96-b3321e5ae884",
            "1779701666",
        ],
    )
    assert result.exit_code == 0
    assert "OS: Windows" in result.output
    assert "version: 1.7.2" in result.output
    assert "level_started" in result.output
    # The event 'data' field should be rendered as JSON.
    assert '"cards"' in result.output
    assert "Samples: (none)" in result.output


def test_cli_show_run_not_found(tmp_path: Path):
    db_path = _make_db_with_runs(tmp_path, [])
    runner = CliRunner()
    result = runner.invoke(
        cli,
        ["--db-url", f"sqlite:///{db_path}", "show_run", "uuid-x", "1"],
    )
    assert result.exit_code == 1
    assert "No run found" in result.output
