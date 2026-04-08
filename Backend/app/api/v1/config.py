"""
Public configuration endpoint -- no auth required.
Exposes the subset of platform settings the frontend needs.
"""
from fastapi import APIRouter, Request

from app.cache import cache_json_get, cache_json_set, cache_delete
from app.dependencies import DbSession
from app.rate_limit import limiter, dynamic_limit
from app.services import platform_settings as settings_svc

router = APIRouter()

_PUBLIC_INT_KEYS = [
    "max_tickets_per_purchase",
    "waitlist_max_size_limit",
    "event_max_images_limit",
    "max_posts_per_event_limit",
    "max_co_organizers_limit",
    "completed_event_chat_retention_days",
]
_PUBLIC_BOOL_KEYS = [
    "max_tickets_frontend_enabled",
    "feature_milestones_enabled",
    "feature_schedule_enabled",
    "feature_sponsors_enabled",
    "feature_community_rules_enabled",
    "offline_ticket_auto_download_enabled",
]

_CACHE_KEY = "public_config"


@router.get("")
@limiter.limit(dynamic_limit("public_config", "60/minute"))
async def get_public_config(request: Request, db: DbSession) -> dict:
    cached = await cache_json_get(_CACHE_KEY)
    if cached is not None:
        return cached

    result: dict = {}
    for key in _PUBLIC_INT_KEYS:
        result[key] = await settings_svc.get_int(db, key)
    for key in _PUBLIC_BOOL_KEYS:
        result[key] = await settings_svc.get_bool(db, key)

    await cache_json_set(_CACHE_KEY, result, ttl=120)
    return result


async def invalidate_public_config() -> None:
    await cache_delete(_CACHE_KEY)
