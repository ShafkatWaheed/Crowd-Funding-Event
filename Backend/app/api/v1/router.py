"""
Aggregates all v1 API routers.
"""
from fastapi import APIRouter

from app.api.v1 import auth, users, events, venues, map_, admin, ticket_strategies, discount_strategies, milestones, schedule, sponsors

api_router = APIRouter()


@api_router.get("/health")
def health():
    return {"status": "ok"}


api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/me", tags=["users"])
api_router.include_router(map_.router, prefix="/events", tags=["map"])        # before events (avoids /{event_id} catching /map)
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(venues.router, prefix="/venues", tags=["venues"])
api_router.include_router(ticket_strategies.router, prefix="/ticket-strategies", tags=["ticket-strategies"])
api_router.include_router(discount_strategies.router, prefix="/discount-strategies", tags=["discount-strategies"])
api_router.include_router(milestones.router, prefix="/events", tags=["milestones"])
api_router.include_router(schedule.router, prefix="/events", tags=["schedule"])
api_router.include_router(sponsors.router, prefix="", tags=["sponsors"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
