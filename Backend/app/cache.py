"""
Async Redis cache layer with graceful degradation.

Features:
- Probabilistic Early Recomputation (PER) + SETNX lock for stampede prevention
- Cascade invalidation for event mutations
- Circuit breaker to avoid repeated slow timeouts when Redis is down

All operations silently return None / no-op when Redis is unavailable,
matching the ARQ pattern in app.worker.redis_pool.
"""
from __future__ import annotations

import asyncio
import json
import math
import random
import re
import time
from typing import Any, Awaitable, Callable

import redis.asyncio as aioredis

from app.config import settings
from app.logger import get_logger

logger = get_logger("app.cache")

_client: aioredis.Redis | None = None
_enabled: bool = True

# ── Circuit breaker state ──
_consecutive_failures: int = 0
_circuit_open_until: float = 0.0
_CIRCUIT_BREAKER_THRESHOLD: int = 5
_CIRCUIT_BREAKER_COOLDOWN: int = 30


def configure_circuit_breaker(threshold: int, cooldown: int) -> None:
    """Update circuit breaker parameters (called from startup settings load)."""
    global _CIRCUIT_BREAKER_THRESHOLD, _CIRCUIT_BREAKER_COOLDOWN
    _CIRCUIT_BREAKER_THRESHOLD = threshold
    _CIRCUIT_BREAKER_COOLDOWN = cooldown


def set_cache_enabled(enabled: bool) -> None:
    global _enabled
    _enabled = enabled
    logger.info("Cache %s", "enabled" if enabled else "disabled")


def _circuit_is_open() -> bool:
    """Return True if the circuit breaker is tripped (Redis considered down)."""
    if _consecutive_failures < _CIRCUIT_BREAKER_THRESHOLD:
        return False
    if time.monotonic() >= _circuit_open_until:
        # Cooldown elapsed — allow one probe request
        return False
    return True


def _record_failure() -> None:
    global _consecutive_failures, _circuit_open_until
    _consecutive_failures += 1
    if _consecutive_failures >= _CIRCUIT_BREAKER_THRESHOLD:
        _circuit_open_until = time.monotonic() + _CIRCUIT_BREAKER_COOLDOWN
        if _consecutive_failures == _CIRCUIT_BREAKER_THRESHOLD:
            logger.warning(
                "Cache circuit breaker OPEN — skipping Redis for %ds",
                _CIRCUIT_BREAKER_COOLDOWN,
            )


def _record_success() -> None:
    global _consecutive_failures, _circuit_open_until
    if _consecutive_failures > 0:
        _consecutive_failures = 0
        _circuit_open_until = 0.0
        logger.info("Cache circuit breaker CLOSED — Redis recovered")


def _is_available() -> bool:
    """Check if cache is enabled, connected, and circuit is closed."""
    return _enabled and _client is not None and not _circuit_is_open()


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


# ── Low-level ops (circuit-breaker aware) ──


async def cache_get(key: str) -> str | None:
    if not _is_available():
        return None
    try:
        result = await _client.get(key)
        _record_success()
        return result
    except Exception:
        logger.debug("cache_get failed for %s", key)
        _record_failure()
        return None


async def cache_set(key: str, value: str, ttl: int = 60) -> None:
    if not _is_available():
        return
    try:
        await _client.set(key, value, ex=ttl)
        _record_success()
    except Exception:
        logger.debug("cache_set failed for %s", key)
        _record_failure()


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


# ── JSON helpers ──


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


# ── Metadata-aware cache (stores compute_time for PER) ──


async def _cache_get_with_metadata(key: str) -> dict | None:
    """Get cached value + compute_time metadata for PER calculations."""
    raw = await cache_get(key)
    if raw is None:
        return None
    try:
        envelope = json.loads(raw)
        if isinstance(envelope, dict) and "_meta" in envelope:
            return envelope
    except (json.JSONDecodeError, TypeError):
        pass
    return None


async def _cache_set_with_metadata(
    key: str, value: Any, compute_time: float, ttl: int = 60
) -> None:
    """Store value wrapped in an envelope with compute_time metadata."""
    envelope = {
        "_meta": True,
        "value": value,
        "compute_time": compute_time,
    }
    try:
        raw = json.dumps(envelope, default=str)
    except (TypeError, ValueError):
        return
    await cache_set(key, raw, ttl)


# ── Stampede prevention: PER + SETNX lock ──


async def cache_get_or_compute(
    key: str,
    compute_fn: Callable[[], Awaitable[Any]],
    ttl: int = 60,
    beta: float = 1.0,
    lock_ttl: int = 5,
) -> Any:
    """Get from cache with stampede prevention.

    Uses Probabilistic Early Recomputation (PER) to refresh cache before TTL
    expiry under load, and a SETNX lock to serialise cold-start recomputation.

    Args:
        key: Cache key.
        compute_fn: Async callable that produces the value on cache miss.
        ttl: Time-to-live in seconds for the cached entry.
        beta: PER aggressiveness (higher = recompute earlier before expiry).
              Recommended: 2.0 for hot paths, 1.0 default, 0.5 for long-TTL keys.
        lock_ttl: Max seconds the SETNX lock is held (prevents deadlock).
    """
    # 1. Try cache with metadata
    cached = await _cache_get_with_metadata(key)

    if cached is not None:
        try:
            remaining_ttl = await _client.ttl(key) if _client else 0
            compute_time = cached.get("compute_time", 0.1)
            # PER: probability of early recompute increases as TTL → 0
            delta = compute_time * beta * math.log(random.random())
            if remaining_ttl + delta > 0:
                return cached["value"]  # still fresh enough
            # Fell through → this request is the probabilistic "winner"
        except Exception:
            return cached["value"]  # on any error, serve cached

    # 2. Cold start OR PER winner → lock to serialise recomputation
    if _is_available():
        lock_key = f"lock:{key}"
        try:
            acquired = await _client.set(lock_key, "1", nx=True, ex=lock_ttl)
        except Exception:
            acquired = True  # Redis error → compute anyway

        if acquired:
            t0 = time.monotonic()
            result = await compute_fn()
            compute_time = time.monotonic() - t0
            await _cache_set_with_metadata(key, result, compute_time, ttl)
            try:
                await _client.delete(lock_key)
            except Exception:
                pass
            return result
        else:
            # Another request is recomputing — serve stale if available
            if cached is not None:
                return cached["value"]
            # Cold start, no stale value — brief wait then check
            await asyncio.sleep(0.1)
            fresh = await _cache_get_with_metadata(key)
            if fresh is not None:
                return fresh["value"]
            # Lock holder may have failed — compute as fallback
            return await compute_fn()

    # 3. Redis unavailable — compute directly
    return await compute_fn()


# ── Key helpers ──


_UNSAFE_CHARS = re.compile(r"[:\*\?\n\r\x00]")


def safe_cache_key(*parts: str | int) -> str:
    """Build a colon-separated cache key, sanitizing string parts.

    Strips characters that could cause key collisions or interact with
    cache_delete_pattern (colons, wildcards, newlines, nulls).
    Each segment is truncated to 64 chars.
    """
    sanitized = []
    for p in parts:
        s = str(p)
        s = _UNSAFE_CHARS.sub("_", s)
        sanitized.append(s[:64])
    return ":".join(sanitized)


# ── Cascade invalidation ──


async def invalidate_event_cascade(event_id: int) -> None:
    """Invalidate all cache keys affected by an event mutation.

    Call this after any event create/update/delete or status transition.
    """
    await cache_delete(safe_cache_key("event", event_id))
    await cache_delete_pattern("featured:*")
    await cache_delete_pattern("map:*")
    await cache_delete("cities")
    # admin_dash has short TTL (30s) — let it expire naturally
