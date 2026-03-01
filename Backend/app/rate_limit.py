"""
Global rate-limiter configuration using slowapi.

Provides:
  - `limiter`            – shared Limiter instance (import in route modules)
  - `dynamic_limit`      – factory returning a callable that reads from the
                           in-memory cache; use as @limiter.limit(dynamic_limit("key", "10/minute"))
  - `reload_rate_limits` – async function to refresh in-memory limits from
                           platform settings (call on startup + settings update)
  - `setup_rate_limiting(app)` – call once in main.py to wire up the handler
"""
from __future__ import annotations

import re
from typing import Callable

from fastapi import Request
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.logger import get_logger

logger = get_logger("rate_limit")

_VALID_LIMIT = re.compile(r"^\d+/(second|minute|hour|day)$")

_SETTINGS_KEY_MAP: dict[str, str] = {
    "global":          "rate_limit_global_default",
    "auth_verify":     "rate_limit_auth_verify",
    "public_config":   "rate_limit_public_config",
    "event_register":  "rate_limit_event_register",
    "ticket_purchase": "rate_limit_ticket_purchase",
    "pledge":          "rate_limit_pledge",
    "file_upload":     "rate_limit_file_upload",
    "payment_action":  "rate_limit_payment_action",
    "event_create":    "rate_limit_event_create",
    "content_create":  "rate_limit_content_create",
    "public_search":   "rate_limit_public_search",
    "social_action":   "rate_limit_social_action",
    "qr_scan":         "rate_limit_qr_scan",
}

_limits: dict[str, str] = {
    "global":          "120/minute",
    "auth_verify":     "10/minute",
    "public_config":   "60/minute",
    "event_register":  "20/minute",
    "ticket_purchase": "15/minute",
    "pledge":          "20/minute",
    "file_upload":     "10/minute",
    "payment_action":  "10/minute",
    "event_create":    "5/minute",
    "content_create":  "15/minute",
    "public_search":   "60/minute",
    "social_action":   "30/minute",
    "qr_scan":         "30/minute",
}


def _key_func(request: Request) -> str:
    """Prefer authenticated user id, fall back to IP."""
    user = getattr(request.state, "user", None)
    if user and hasattr(user, "id"):
        return f"user:{user.id}"
    return get_remote_address(request)


def _global_limit() -> str:
    return _limits.get("global", "120/minute")


from app.config import settings

limiter = Limiter(
    key_func=_key_func,
    default_limits=[_global_limit],
    storage_uri=settings.RATELIMIT_STORAGE_URL,
    in_memory_fallback_enabled=True,
)


def dynamic_limit(endpoint_key: str, fallback: str) -> Callable[..., str]:
    """Return a callable that resolves the rate limit for *endpoint_key*
    from the in-memory cache, falling back to *fallback* if missing."""
    def _resolver(_request: Request | None = None) -> str:
        return _limits.get(endpoint_key, fallback)
    return _resolver


async def reload_rate_limits(db) -> None:
    """Read all rate_limit_* settings from the DB and refresh _limits.
    Invalid values are silently skipped (the hardcoded default stays)."""
    from app.services import platform_settings as ps

    for short_key, settings_key in _SETTINGS_KEY_MAP.items():
        try:
            value = await ps.get_str(db, settings_key)
            if value and _VALID_LIMIT.match(value):
                _limits[short_key] = value
            elif value:
                logger.warning(
                    "Ignoring invalid rate limit for %s: %r", settings_key, value,
                )
        except Exception:
            logger.exception("Failed to load rate limit %s", settings_key)

    logger.info("Rate limits reloaded: %s", _limits)


def setup_rate_limiting(app):
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
