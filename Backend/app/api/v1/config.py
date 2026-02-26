"""
Public configuration endpoint -- no auth required.
Exposes the subset of platform settings the frontend needs.
"""
from fastapi import APIRouter

from app.dependencies import DbSession
from app.services import platform_settings as settings_svc

router = APIRouter()

_PUBLIC_INT_KEYS = ["max_tickets_per_purchase"]
_PUBLIC_BOOL_KEYS = [
    "max_tickets_frontend_enabled",
    "feature_milestones_enabled",
    "feature_schedule_enabled",
    "feature_sponsors_enabled",
    "feature_community_rules_enabled",
]


@router.get("")
async def get_public_config(db: DbSession) -> dict:
    result: dict = {}
    for key in _PUBLIC_INT_KEYS:
        result[key] = await settings_svc.get_int(db, key)
    for key in _PUBLIC_BOOL_KEYS:
        result[key] = await settings_svc.get_bool(db, key)
    return result
