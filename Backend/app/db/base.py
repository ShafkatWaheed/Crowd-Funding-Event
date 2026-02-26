"""
Database engine, session, and base model.
Uses async SQLAlchemy with asyncpg for PostgreSQL.
"""
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings


class Base(DeclarativeBase):
    pass


async_engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DATABASE_ECHO,
    pool_size=10,
    max_overflow=20,
    pool_timeout=30,
    pool_recycle=1800,
)

async_session_maker = async_sessionmaker(
    async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# ── Read-replica engine (falls back to primary when REPLICA_URL is unset) ──

read_engine = create_async_engine(
    settings.DATABASE_REPLICA_URL or settings.DATABASE_URL,
    echo=settings.DATABASE_ECHO,
    pool_size=10,
    max_overflow=20,
    pool_timeout=30,
    pool_recycle=1800,
    execution_options={"postgresql_readonly": True},
)

read_session_maker = async_sessionmaker(
    read_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


async def get_read_db_session() -> AsyncGenerator[AsyncSession, None]:
    """Yield a read-only session bound to the replica (or primary fallback)."""
    async with read_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db() -> None:
    """Create all tables. Use Alembic in production."""
    import app.models  # noqa: F401 - register all models with Base.metadata
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
