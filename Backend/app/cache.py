"""
Async Redis cache layer with graceful degradation.

All operations silently return None / no-op when Redis is unavailable,
matching the ARQ pattern in app.worker.redis_pool.
"""
from __future__ import annotations

import json
import logging
from typing import Any

import redis.asyncio as aioredis

from app.config import settings

logger = logging.getLogger("app.cache")

_client: aioredis.Redis | None = None
_enabled: bool = True


def set_cache_enabled(enabled: bool) -> None:
    global _enabled
    _enabled = enabled
    logger.info("Cache %s", "enabled" if enabled else "disabled")


async def init_cache() -> None:
    global _client
    try:
        _client = aioredis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            socket_connect_timeout=3,
        )
        await _client.ping()
        logger.info("Redis cache connected")
    except Exception:
        logger.warning("Redis cache not available — caching disabled")
        _client = None


async def close_cache() -> None:
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


async def cache_get(key: str) -> str | None:
    if not _enabled or _client is None:
        return None
    try:
        return await _client.get(key)
    except Exception:
        logger.debug("cache_get failed for %s", key)
        return None


async def cache_set(key: str, value: str, ttl: int = 60) -> None:
    if not _enabled or _client is None:
        return
    try:
        await _client.set(key, value, ex=ttl)
    except Exception:
        logger.debug("cache_set failed for %s", key)


async def cache_delete(key: str) -> None:
    if _client is None:
        return
    try:
        await _client.delete(key)
    except Exception:
        logger.debug("cache_delete failed for %s", key)


async def cache_delete_pattern(pattern: str) -> None:
    """Delete all keys matching a glob pattern (e.g. 'featured:*')."""
    if _client is None:
        return
    try:
        cursor: int | bytes = 0
        while True:
            cursor, keys = await _client.scan(cursor=cursor, match=pattern, count=100)
            if keys:
                await _client.delete(*keys)
            if cursor == 0:
                break
    except Exception:
        logger.debug("cache_delete_pattern failed for %s", pattern)


async def cache_json_get(key: str) -> Any | None:
    raw = await cache_get(key)
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return None


async def cache_json_set(key: str, data: Any, ttl: int = 60) -> None:
    try:
        raw = json.dumps(data, default=str)
    except (TypeError, ValueError):
        return
    await cache_set(key, raw, ttl)
