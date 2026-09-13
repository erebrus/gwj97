from __future__ import annotations

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from models import Base


def make_engine(url: str) -> Engine:
    kwargs: dict = {"future": True}
    # In-memory SQLite needs a single shared connection across the engine,
    # otherwise each checkout sees a fresh empty database.
    if url == "sqlite:///:memory:":
        kwargs["poolclass"] = StaticPool
        kwargs["connect_args"] = {"check_same_thread": False}

    engine = create_engine(url, **kwargs)

    if engine.dialect.name == "sqlite":
        @event.listens_for(engine, "connect")
        def _fk_pragma_on_connect(dbapi_connection, _):
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    Base.metadata.create_all(engine)
    return engine


def make_session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=engine, future=True, expire_on_commit=False)
