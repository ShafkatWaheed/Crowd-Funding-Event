"""
Shared Redis connection pool for ARQ task enqueuing.
Import `get_arq_pool` in services/endpoints to enqueue jobs.
Use `enqueue()` for fire-and-forget tasks that fall back to inline if Redis is down.
"""
from __future__ import annotations

from typing import Any

from arq import create_pool
from arq.connections import ArqRedis, RedisSettings

from app.config import settings
from app.logger import get_logger

logger = get_logger("arq.pool")

_pool: ArqRedis | None = None


def _redis_settings() -> RedisSettings:
    return RedisSettings.from_dsn(settings.REDIS_URL)


async def get_arq_pool() -> ArqRedis:
    global _pool
    if _pool is None:
        _pool = await create_pool(_redis_settings())
    return _pool


async def close_arq_pool() -> None:
    global _pool
    if _pool is not None:
        await _pool.aclose()
        _pool = None


async def enqueue(task_name: str, *args: Any, **kwargs: Any) -> bool:
    """Enqueue an ARQ job. Returns True if enqueued, False if Redis unavailable.

    When Redis is down the caller should fall back to running the task inline
    or simply skip it (for best-effort tasks like emails).
    """
    try:
        pool = await get_arq_pool()
        await pool.enqueue_job(task_name, *args, **kwargs)
        return True
    except Exception:
        logger.warning("Failed to enqueue %s — Redis may be unavailable", task_name)
        return False
