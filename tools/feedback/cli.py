from __future__ import annotations

import json
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

import click
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from db import make_engine, make_session_factory
from ingest import BlockedRun, InvalidMetricsFile, ingest_file
from models import Run


DEFAULT_DB_URL = "sqlite:///feedback.db"

# Runs whose metadata.uuid is in this set are never ingested. Edit freely.
BLOCKED_UUIDS: frozenset[str] = frozenset({"05cd22dd-5f7d-409e-89b0-d786d75cdba8"
    # "3a1d1ce6-15ae-4f7e-ac96-b3321e5ae884",
})

# Runs whose metadata.username is in this set are never ingested. Edit freely.
BLOCKED_USERNAMES: frozenset[str] = frozenset({"erebrus","erebrus_web"
    # "tester",
})


@click.group()
@click.option(
    "--db-url",
    default=DEFAULT_DB_URL,
    envvar="FEEDBACK_DB_URL",
    show_default=True,
    help="SQLAlchemy database URL.",
)
@click.pass_context
def cli(ctx: click.Context, db_url: str) -> None:
    """Feedback metrics ingestion tool."""
    ctx.ensure_object(dict)
    ctx.obj["db_url"] = db_url


@contextmanager
def _open_session(ctx: click.Context) -> Iterator[Session]:
    engine = make_engine(ctx.obj["db_url"])
    SessionFactory = make_session_factory(engine)
    with SessionFactory() as session:
        yield session


@cli.command("ingest")
@click.argument("path", type=click.Path(exists=True, path_type=Path))
@click.pass_context
def ingest_cmd(ctx: click.Context, path: Path) -> None:
    """Ingest a metrics JSON file, or every *.json file in a directory."""
    if path.is_dir():
        files = sorted(path.glob("*.json"))
    else:
        files = [path]

    if not files:
        click.echo(f"No JSON files found at {path}", err=True)
        sys.exit(1)

    ok = 0
    skipped = 0
    failed = 0
    with _open_session(ctx) as session:
        for f in files:
            try:
                with session.begin():
                    result = ingest_file(
                        f,
                        session,
                        blocked_uuids=BLOCKED_UUIDS,
                        blocked_usernames=BLOCKED_USERNAMES,
                    )
            except BlockedRun as e:
                click.echo(f"SKIP {f.name}: {e}", err=True)
                skipped += 1
                continue
            except InvalidMetricsFile as e:
                click.echo(f"SKIP {f.name}: invalid metrics file: {e}", err=True)
                failed += 1
                continue
            except Exception as e:  # pragma: no cover - catch-all for unexpected
                click.echo(f"FAIL {f.name}: {type(e).__name__}: {e}", err=True)
                failed += 1
                continue

            verb = "Replaced" if result.replaced else "Inserted"
            click.echo(
                f"{verb} {f.name}: uuid={result.uuid} run_id={result.run_id} "
                f"levels={result.level_attempts} events={result.events} "
                f"samples={result.metric_samples}"
            )
            ok += 1

    click.echo(f"Done: {ok} ingested, {skipped} skipped, {failed} failed.")
    if failed:
        sys.exit(1)


@cli.command("list_uuids")
@click.pass_context
def list_uuids(ctx: click.Context) -> None:
    """List all UUIDs that have at least one run."""
    with _open_session(ctx) as session:
        rows = session.scalars(
            select(Run.uuid).distinct().order_by(Run.uuid)
        ).all()
    for uuid in rows:
        click.echo(uuid)


@cli.command("list_runs")
@click.pass_context
def list_runs(ctx: click.Context) -> None:
    """List (uuid, run_id, start_time, levels, sector) for every stored run.

    The levels column shows "tutorial" when the run's only level is the
    tutorial, otherwise the number of distinct levels (the synthetic "_"
    level is never counted). The sector column comes from metadata.sector.
    """
    with _open_session(ctx) as session:
        runs = session.scalars(
            select(Run).order_by(Run.run_id)
        ).all()
        if not runs:
            click.echo("(no runs)")
            return
        for run in runs:
            levels = {la.level for la in run.level_attempts if la.level != "_"}
            if len(levels) == 1 and "tutorial" in next(iter(levels)).lower():
                levels_col = "tutorial"
            else:
                levels_col = str(len(levels))
            sector = run.raw_metadata.get("sector")
            sector_col = "" if sector is None else str(sector)
            click.echo(
                f"{run.uuid}\t{run.run_id}\t{run.start_time or ''}\t"
                f"{levels_col}\t{sector_col}"
            )


@cli.command("remove_run")
@click.argument("uuid")
@click.argument("run_id", type=int)
@click.pass_context
def remove_run(ctx: click.Context, uuid: str, run_id: int) -> None:
    """Remove the run identified by UUID and RUN_ID."""
    with _open_session(ctx) as session:
        with session.begin():
            existing_id = session.scalar(
                select(Run.id).where(Run.uuid == uuid, Run.run_id == run_id)
            )
            if existing_id is None:
                click.echo(
                    f"No run found for uuid={uuid} run_id={run_id}", err=True
                )
                sys.exit(1)
            session.execute(delete(Run).where(Run.id == existing_id))
    click.echo(f"Removed run uuid={uuid} run_id={run_id}")


@cli.command("remove_uuid")
@click.argument("uuid")
@click.option(
    "--yes",
    "-y",
    is_flag=True,
    default=False,
    help="Skip the confirmation prompt.",
)
@click.pass_context
def remove_uuid(ctx: click.Context, uuid: str, yes: bool) -> None:
    """Remove every run (and its data) belonging to UUID."""
    with _open_session(ctx) as session:
        with session.begin():
            count = session.scalar(
                select(func.count()).select_from(Run).where(Run.uuid == uuid)
            )
            if not count:
                click.echo(f"No runs found for uuid={uuid}", err=True)
                sys.exit(1)

            if not yes:
                click.confirm(
                    f"Remove {count} run(s) for uuid={uuid}?", abort=True
                )

            session.execute(delete(Run).where(Run.uuid == uuid))
    click.echo(f"Removed {count} run(s) for uuid={uuid}")


@cli.command("show_run")
@click.argument("uuid")
@click.argument("run_id", type=int)
@click.pass_context
def show_run(ctx: click.Context, uuid: str, run_id: int) -> None:
    """Print metadata and per-level data for a single run."""
    with _open_session(ctx) as session:
        run = session.scalar(
            select(Run).where(Run.uuid == uuid, Run.run_id == run_id)
        )
        if run is None:
            click.echo(
                f"No run found for uuid={uuid} run_id={run_id}", err=True
            )
            sys.exit(1)

        click.echo(f"Run uuid={run.uuid} run_id={run.run_id}")
        click.echo("")
        click.echo("Metadata:")
        for k in sorted(run.raw_metadata.keys()):
            click.echo(f"  {k}: {run.raw_metadata[k]}")

        click.echo("")
        click.echo(f"Levels ({len(run.level_attempts)}):")
        for la in run.level_attempts:
            click.echo("")
            click.echo(f"  [{la.sequence}] level: {la.level}")
            click.echo(f"      Events ({len(la.events)}):")
            for i, e in enumerate(la.events):
                click.echo(
                    f"        [{i}] {e.name} @ t={e.timestamp_ms} turn={e.turn}"
                )
                if e.data is not None:
                    click.echo(f"            data: {json.dumps(e.data)}")

            by_metric: dict[str, list] = {}
            for s in la.metric_samples:
                by_metric.setdefault(s.metric_name, []).append(s)
            if not by_metric:
                click.echo("      Samples: (none)")
            else:
                click.echo("      Samples:")
                for metric_name in sorted(by_metric.keys()):
                    samples = by_metric[metric_name]
                    click.echo(f"        {metric_name} ({len(samples)}):")
                    for s in samples:
                        click.echo(
                            f"          {s.value} @ t={s.timestamp_ms} turn={s.turn}"
                        )


@cli.command("fetch_discord")
@click.option(
    "--token",
    envvar="DISCORD_BOT_TOKEN",
    required=True,
    help="Discord bot token (or set DISCORD_BOT_TOKEN env var).",
)
@click.option(
    "--channel-id",
    "channel_id",
    envvar="DISCORD_CHANNEL_ID",
    required=True,
    help="Discord channel ID to scan (or set DISCORD_CHANNEL_ID env var).",
)
@click.option(
    "--initial-after",
    default="0",
    show_default=True,
    help="On first run (no stored cursor), scan messages newer than this ID.",
)
@click.option(
    "--debug",
    is_flag=True,
    default=False,
    help="Print each raw message returned by Discord to stderr for diagnosis.",
)
@click.pass_context
def fetch_discord(
    ctx: click.Context,
    token: str,
    channel_id: str,
    initial_after: str,
    debug: bool,
) -> None:
    """Fetch JSON attachments from a Discord channel and ingest them.

    Tracks a per-channel cursor so subsequent runs only scan new messages.
    Designed to be invoked on a schedule (cron, etc.) and exit when done.
    """
    from discord_fetch import DiscordClient, fetch_and_ingest

    client = DiscordClient(token)
    with _open_session(ctx) as session:
        stats = fetch_and_ingest(
            session,
            channel_id,
            client,
            initial_after=initial_after,
            debug=debug,
            blocked_uuids=BLOCKED_UUIDS,
            blocked_usernames=BLOCKED_USERNAMES,
        )

    click.echo(
        f"Discord fetch: messages={stats.messages_scanned} "
        f"json_files={stats.files_seen} ingested={stats.ingested} "
        f"skipped={stats.skipped} failed={stats.failed}"
    )
    if stats.failed:
        sys.exit(1)


if __name__ == "__main__":
    cli()
