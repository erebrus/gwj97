from __future__ import annotations

import json
from typing import Iterator

import pytest
from sqlalchemy.orm import Session

from db import make_engine, make_session_factory
from discord_fetch import fetch_and_ingest
from models import DiscordCursor, Event, LevelAttempt, MetricSample, Run


@pytest.fixture
def session() -> Session:
    engine = make_engine("sqlite:///:memory:")
    SessionFactory = make_session_factory(engine)
    with SessionFactory() as s:
        yield s


def _good_payload(uuid: str, run_id: int) -> dict:
    return {
        "metadata": {"uuid": uuid, "run_id": run_id, "version": "1.0"},
        "data": [{"level": "res://lv1", "events": [], "values": {}}],
        "metrics": [],
    }


def _msg(msg_id: str, *attachments: dict) -> dict:
    return {"id": msg_id, "attachments": list(attachments)}


def _attach(filename: str, url: str) -> dict:
    return {"filename": filename, "url": url}


class FakeDiscordClient:
    """In-memory stand-in for ``DiscordClient`` used in tests."""

    def __init__(self, messages: list[dict], attachments: dict[str, bytes]):
        self.messages = messages
        self.attachments = attachments
        self.fetched_after: list[str] = []
        self.downloaded_urls: list[str] = []

    def fetch_messages_after(
        self, channel_id: str, after_id: str
    ) -> Iterator[dict]:
        self.fetched_after.append(after_id)
        for msg in sorted(self.messages, key=lambda m: int(m["id"])):
            if int(msg["id"]) > int(after_id):
                yield msg

    def download_attachment(self, url: str) -> bytes:
        self.downloaded_urls.append(url)
        if url not in self.attachments:
            raise RuntimeError(f"unknown URL: {url}")
        return self.attachments[url]


def test_fetches_and_ingests_json_attachments(session: Session):
    client = FakeDiscordClient(
        messages=[
            _msg("100", _attach("feedback_metrics.json", "url1")),
            _msg("200", _attach("feedback_metrics.json", "url2")),
        ],
        attachments={
            "url1": json.dumps(_good_payload("u1", 1)).encode(),
            "url2": json.dumps(_good_payload("u2", 1)).encode(),
        },
    )

    stats = fetch_and_ingest(session, "channel-A", client)

    assert stats.messages_scanned == 2
    assert stats.files_seen == 2
    assert stats.ingested == 2
    assert stats.skipped == 0
    assert stats.failed == 0

    assert session.query(Run).count() == 2

    cursor = session.get(DiscordCursor, "channel-A")
    assert cursor is not None
    assert cursor.last_message_id == "200"


def test_skips_non_json_attachments(session: Session):
    client = FakeDiscordClient(
        messages=[
            _msg(
                "100",
                _attach("screenshot.png", "url_png"),
                _attach("feedback_metrics.json", "url_json"),
            ),
        ],
        attachments={
            "url_json": json.dumps(_good_payload("u1", 1)).encode(),
        },
    )

    stats = fetch_and_ingest(session, "channel-A", client)

    assert stats.files_seen == 1
    assert stats.ingested == 1
    assert "url_png" not in client.downloaded_urls
    assert "url_json" in client.downloaded_urls


def test_resumes_from_stored_cursor(session: Session):
    with session.begin():
        session.add(
            DiscordCursor(channel_id="channel-A", last_message_id="150")
        )

    client = FakeDiscordClient(
        messages=[
            _msg("100", _attach("a.json", "u100")),  # older than cursor
            _msg("200", _attach("b.json", "u200")),  # newer than cursor
        ],
        attachments={
            "u200": json.dumps(_good_payload("u1", 1)).encode(),
        },
    )

    stats = fetch_and_ingest(session, "channel-A", client)

    assert stats.messages_scanned == 1
    assert client.fetched_after == ["150"]
    assert "u100" not in client.downloaded_urls
    assert "u200" in client.downloaded_urls
    assert session.query(Run).count() == 1
    assert session.get(DiscordCursor, "channel-A").last_message_id == "200"


def test_initial_after_when_no_cursor(session: Session):
    client = FakeDiscordClient(
        messages=[
            _msg("100", _attach("a.json", "u100")),
            _msg("500", _attach("b.json", "u500")),
        ],
        attachments={
            "u500": json.dumps(_good_payload("u1", 1)).encode(),
        },
    )

    stats = fetch_and_ingest(
        session, "channel-A", client, initial_after="200"
    )

    assert stats.messages_scanned == 1
    assert client.fetched_after == ["200"]


def test_invalid_metrics_file_is_skipped_and_cursor_advances(session: Session):
    client = FakeDiscordClient(
        messages=[
            _msg("100", _attach("bad.json", "url_bad")),
            _msg("200", _attach("good.json", "url_good")),
        ],
        attachments={
            # missing run_id -> InvalidMetricsFile
            "url_bad": b'{"metadata": {"uuid": "x"}, "data": []}',
            "url_good": json.dumps(_good_payload("u1", 1)).encode(),
        },
    )

    stats = fetch_and_ingest(session, "channel-A", client)

    assert stats.skipped == 1
    assert stats.ingested == 1
    assert session.get(DiscordCursor, "channel-A").last_message_id == "200"


def test_invalid_json_is_failed_and_cursor_advances(session: Session):
    client = FakeDiscordClient(
        messages=[_msg("100", _attach("a.json", "url_bad"))],
        attachments={"url_bad": b"this is not json"},
    )

    stats = fetch_and_ingest(session, "channel-A", client)

    assert stats.failed == 1
    assert stats.ingested == 0
    assert session.get(DiscordCursor, "channel-A").last_message_id == "100"


def test_no_messages_leaves_cursor_untouched(session: Session):
    client = FakeDiscordClient(messages=[], attachments={})
    stats = fetch_and_ingest(session, "channel-A", client)

    assert stats.messages_scanned == 0
    assert session.get(DiscordCursor, "channel-A") is None


def test_message_with_no_attachments_still_advances_cursor(session: Session):
    client = FakeDiscordClient(messages=[_msg("100")], attachments={})

    stats = fetch_and_ingest(session, "channel-A", client)

    assert stats.messages_scanned == 1
    assert stats.files_seen == 0
    assert session.get(DiscordCursor, "channel-A").last_message_id == "100"


def test_replace_semantics_on_repeat_uuid_run(session: Session):
    payload = _good_payload("u1", 7)
    payload["data"][0]["events"] = [
        {"name": "level_started", "timestamp": 1, "turn": 0}
    ]
    client = FakeDiscordClient(
        messages=[
            _msg("100", _attach("v1.json", "url1")),
            _msg("200", _attach("v2.json", "url2")),
        ],
        attachments={
            "url1": json.dumps(payload).encode(),
            "url2": json.dumps(_good_payload("u1", 7)).encode(),  # no events
        },
    )

    stats = fetch_and_ingest(session, "channel-A", client)

    assert stats.ingested == 2
    assert session.query(Run).count() == 1  # second replaced first
    assert session.query(Event).count() == 0  # v2 has no events
    assert session.query(LevelAttempt).count() == 1
    assert session.query(MetricSample).count() == 0


def test_independent_channels_have_independent_cursors(session: Session):
    client = FakeDiscordClient(
        messages=[_msg("100", _attach("a.json", "u100"))],
        attachments={"u100": json.dumps(_good_payload("u1", 1)).encode()},
    )

    fetch_and_ingest(session, "channel-A", client)
    fetch_and_ingest(session, "channel-B", client)

    assert session.get(DiscordCursor, "channel-A").last_message_id == "100"
    assert session.get(DiscordCursor, "channel-B").last_message_id == "100"
