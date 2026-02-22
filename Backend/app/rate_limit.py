"""
Global rate-limiter configuration using slowapi.

Provides:
  - `limiter`   – shared Limiter instance (import in route modules)
  - `setup_rate_limiting(app)` – call once in main.py to wire up the handler
"""
from __future__ import annotations

from fastapi import Request
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address


def _key_func(request: Request) -> str:
    """Prefer authenticated user id, fall back to IP."""
    user = getattr(request.state, "user", None)
    if user and hasattr(user, "id"):
        return f"user:{user.id}"
    return get_remote_address(request)


limiter = Limiter(key_func=_key_func, default_limits=["120/minute"])


def setup_rate_limiting(app):
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
