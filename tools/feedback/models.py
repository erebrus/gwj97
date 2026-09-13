from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import (
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class Run(Base):
    __tablename__ = "runs"

    id: Mapped[int] = mapped_column(primary_key=True)
    uuid: Mapped[str] = mapped_column(String(64), index=True)
    run_id: Mapped[int] = mapped_column(Integer)

    os: Mapped[str | None] = mapped_column(String(64), nullable=True)
    version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    username: Mapped[str | None] = mapped_column(String(255), nullable=True)
    session_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    session_start_time: Mapped[str | None] = mapped_column(String(32), nullable=True)
    start_time: Mapped[str | None] = mapped_column(String(32), nullable=True)
    end_time: Mapped[str | None] = mapped_column(String(32), nullable=True)
    fullscreen: Mapped[str | None] = mapped_column(String(8), nullable=True)
    screen_size: Mapped[str | None] = mapped_column(String(32), nullable=True)
    window_size: Mapped[str | None] = mapped_column(String(32), nullable=True)

    raw_metadata: Mapped[dict[str, Any]] = mapped_column(JSON)
    ingested_at: Mapped[datetime] = mapped_column(DateTime, default=_utc_now)
    source_filename: Mapped[str | None] = mapped_column(String(512), nullable=True)

    level_attempts: Mapped[list["LevelAttempt"]] = relationship(
        back_populates="run",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="LevelAttempt.sequence",
    )

    __table_args__ = (
        UniqueConstraint("uuid", "run_id", name="uq_runs_uuid_run_id"),
    )


class LevelAttempt(Base):
    __tablename__ = "level_attempts"

    id: Mapped[int] = mapped_column(primary_key=True)
    run_id: Mapped[int] = mapped_column(
        ForeignKey("runs.id", ondelete="CASCADE"), index=True
    )
    level: Mapped[str] = mapped_column(String(512))
    sequence: Mapped[int] = mapped_column(Integer)

    run: Mapped[Run] = relationship(back_populates="level_attempts")
    events: Mapped[list["Event"]] = relationship(
        back_populates="level_attempt",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    metric_samples: Mapped[list["MetricSample"]] = relationship(
        back_populates="level_attempt",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class Event(Base):
    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True)
    level_attempt_id: Mapped[int] = mapped_column(
        ForeignKey("level_attempts.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(128), index=True)
    timestamp_ms: Mapped[int] = mapped_column(Integer)
    turn: Mapped[int] = mapped_column(Integer)
    data: Mapped[Any | None] = mapped_column(JSON, nullable=True)

    level_attempt: Mapped[LevelAttempt] = relationship(back_populates="events")


class MetricSample(Base):
    __tablename__ = "metric_samples"

    id: Mapped[int] = mapped_column(primary_key=True)
    level_attempt_id: Mapped[int] = mapped_column(
        ForeignKey("level_attempts.id", ondelete="CASCADE")
    )
    metric_name: Mapped[str] = mapped_column(String(128))
    value: Mapped[float] = mapped_column(Float)
    timestamp_ms: Mapped[int] = mapped_column(Integer)
    turn: Mapped[int] = mapped_column(Integer)

    level_attempt: Mapped[LevelAttempt] = relationship(back_populates="metric_samples")

    __table_args__ = (
        Index(
            "ix_metric_samples_attempt_name",
            "level_attempt_id",
            "metric_name",
        ),
    )


class DiscordCursor(Base):
    """Tracks the last-processed Discord message ID per channel."""

    __tablename__ = "discord_cursors"

    channel_id: Mapped[str] = mapped_column(String(32), primary_key=True)
    last_message_id: Mapped[str] = mapped_column(String(32))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=_utc_now, onupdate=_utc_now
    )
