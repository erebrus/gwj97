from __future__ import annotations

import json
import sys
import time
from dataclasses import dataclass
from typing import Iterator, Protocol

import requests
from sqlalchemy import select
from sqlalchemy.orm import Session

from ingest import BlockedRun, InvalidMetricsFile, ingest_payload
from models import DiscordCursor


DISCORD_API_BASE = "https://discord.com/api/v10"
MAX_PAGE = 100
MAX_RATE_LIMIT_RETRIES = 5


class DiscordError(RuntimeError):
    """Raised when the Discord API returns an error we cannot recover from."""


class DiscordClientProtocol(Protocol):
    def fetch_messages_after(
        self, channel_id: str, after_id: str
    ) -> Iterator[dict]: ...

    def download_attachment(self, url: str) -> bytes: ...


class DiscordClient:
    """Minimal Discord REST client for one-shot message-history fetching.

    Only implements the two operations needed by ``fetch_and_ingest``:
    paginating message history forward from a cursor, and downloading
    an attachment by its (signed) CDN URL.
    """

    def __init__(self, token: str, user_agent: str = "feedback-tool/0.1"):
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bot {token}"
        self.session.headers["User-Agent"] = user_agent

    def fetch_messages_after(
        self, channel_id: str, after_id: str
    ) -> Iterator[dict]:
        """Yield messages newer than ``after_id`` in chronological order."""
        cursor = after_id
        while True:
            resp = self._get_with_retry(
                f"{DISCORD_API_BASE}/channels/{channel_id}/messages",
                params={"after": cursor, "limit": MAX_PAGE},
            )
            batch = resp.json()
            if not isinstance(batch, list):
                raise DiscordError(
                    f"Unexpected Discord API response: {batch!r}"
                )
            if not batch:
                return
            # API returns newest-first within the batch; sort so callers see
            # messages in chronological order.
            batch.sort(key=lambda m: int(m["id"]))
            for msg in batch:
                yield msg
            cursor = batch[-1]["id"]
            if len(batch) < MAX_PAGE:
                return

    def download_attachment(self, url: str) -> bytes:
        # Attachment URLs are signed CDN URLs; sending the bot Authorization
        # header here can cause Cloudflare to reject the request.
        resp = requests.get(url, timeout=30)
        if resp.status_code >= 400:
            raise DiscordError(
                f"Failed to download attachment ({resp.status_code}): {url}"
            )
        return resp.content

    def _get_with_retry(self, url: str, *, params: dict | None = None):
        for _ in range(MAX_RATE_LIMIT_RETRIES):
            resp = self.session.get(url, params=params, timeout=30)
            if resp.status_code == 429:
                retry_after = float(resp.headers.get("Retry-After", "1"))
                time.sleep(retry_after)
                continue
            if resp.status_code >= 400:
                raise DiscordError(
                    f"Discord API {resp.status_code} on GET {url}: "
                    f"{resp.text[:200]}"
                )
            return resp
        raise DiscordError(
            f"Discord API rate-limited GET {url} after "
            f"{MAX_RATE_LIMIT_RETRIES} retries"
        )


@dataclass
class FetchStats:
    messages_scanned: int = 0
    files_seen: int = 0
    ingested: int = 0
    skipped: int = 0
    failed: int = 0


def fetch_and_ingest(
    session: Session,
    channel_id: str,
    client: DiscordClientProtocol,
    *,
    initial_after: str = "0",
    debug: bool = False,
    blocked_uuids: frozenset[str] = frozenset(),
    blocked_usernames: frozenset[str] = frozenset(),
) -> FetchStats:
    """Fetch new metrics-JSON attachments from a Discord channel and ingest them.

    Resumes from the stored cursor for ``channel_id``. If no cursor exists,
    starts from ``initial_after`` (default ``"0"`` means "from the beginning
    of the channel"). Advances the cursor after every fully-scanned message,
    so soft failures (bad JSON, invalid metrics file) don't cause the same
    message to be retried forever.

    If ``debug`` is true, prints each raw message returned by the Discord API
    to stderr before processing — useful for diagnosing why expected
    attachments aren't being picked up (e.g. missing Message Content intent).
    """
    with session.begin():
        after_id = session.scalar(
            select(DiscordCursor.last_message_id).where(
                DiscordCursor.channel_id == channel_id
            )
        )
    if after_id is None:
        after_id = initial_after

    stats = FetchStats()

    for msg in client.fetch_messages_after(channel_id, after_id):
        stats.messages_scanned += 1
        msg_id = msg["id"]

        if debug:
            _print_debug_message(msg)

        for att in msg.get("attachments", []):
            filename = att.get("filename", "")
            if not filename.lower().endswith(".json"):
                continue
            stats.files_seen += 1
            url = att.get("url", "")

            try:
                raw = client.download_attachment(url)
                payload = json.loads(raw)
            except Exception as e:
                stats.failed += 1
                print(
                    f"FAIL {filename} (msg {msg_id}): download/parse: {e}",
                    file=sys.stderr,
                )
                continue

            try:
                with session.begin():
                    ingest_payload(
                        payload,
                        session,
                        source_filename=filename,
                        blocked_uuids=blocked_uuids,
                        blocked_usernames=blocked_usernames,
                    )
                stats.ingested += 1
                print(f"Ingested {filename} (msg {msg_id})")
            except (InvalidMetricsFile, BlockedRun) as e:
                stats.skipped += 1
                print(
                    f"SKIP {filename} (msg {msg_id}): {e}",
                    file=sys.stderr,
                )
            except Exception as e:
                stats.failed += 1
                print(
                    f"FAIL {filename} (msg {msg_id}): "
                    f"{type(e).__name__}: {e}",
                    file=sys.stderr,
                )

        # Advance cursor for every scanned message so we don't re-scan it
        # next run, even if its attachments produced soft failures.
        with session.begin():
            _upsert_cursor(session, channel_id, msg_id)

    return stats


def _print_debug_message(msg: dict) -> None:
    """Print a compact diagnostic view of a Discord message to stderr."""
    author = msg.get("author") or {}
    webhook_id = msg.get("webhook_id")
    author_label = (
        f"webhook:{webhook_id}" if webhook_id else
        f"{author.get('username', '?')} (id={author.get('id', '?')}, "
        f"bot={author.get('bot', False)})"
    )
    attachments = msg.get("attachments", []) or []
    att_brief = [
        {
            "filename": a.get("filename"),
            "content_type": a.get("content_type"),
            "size": a.get("size"),
        }
        for a in attachments
    ]
    embeds = msg.get("embeds", []) or []
    content = msg.get("content", "")
    content_preview = content if len(content) <= 120 else content[:117] + "..."

    print(
        f"[debug] msg id={msg.get('id')} author={author_label} "
        f"content={content_preview!r} "
        f"attachments({len(attachments)})={att_brief} "
        f"embeds={len(embeds)}",
        file=sys.stderr,
    )


def _upsert_cursor(
    session: Session, channel_id: str, last_message_id: str
) -> None:
    cursor = session.get(DiscordCursor, channel_id)
    if cursor is None:
        session.add(
            DiscordCursor(channel_id=channel_id, last_message_id=last_message_id)
        )
    else:
        cursor.last_message_id = last_message_id
