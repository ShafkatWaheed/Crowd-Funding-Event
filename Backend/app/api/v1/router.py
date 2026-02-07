"""
Aggregates all v1 API routers.
"""
from fastapi import APIRouter

from app.api.v1 import auth, users, events, venues, map_, admin

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/me", tags=["users"])
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(venues.router, prefix="/venues", tags=["venues"])
api_router.include_router(map_.router, prefix="/events", tags=["map"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
