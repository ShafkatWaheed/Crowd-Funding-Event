"""
Aggregates all v1 API routers.
"""
from fastapi import APIRouter

from app.api.v1 import auth, users, venues, map_, admin, ticket_strategies, discount_strategies, milestones, schedule, sponsors, public_profiles, ratings, notifications, config, banking, webhooks, chat, organizer_faq, event_polls
from app.api.v1.events import router as events_router

api_router = APIRouter()


@api_router.get("/health")
def health():
    return {"status": "ok"}


api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/me", tags=["users"])
api_router.include_router(map_.router, prefix="/events", tags=["map"])        # before events (avoids /{event_id} catching /map)
api_router.include_router(sponsors.router, prefix="", tags=["sponsors"])      # before events (avoids /{event_id} catching /sponsorship-available)
api_router.include_router(events_router, prefix="/events", tags=["events"])
api_router.include_router(venues.router, prefix="/venues", tags=["venues"])
api_router.include_router(ticket_strategies.router, prefix="/ticket-strategies", tags=["ticket-strategies"])
api_router.include_router(discount_strategies.router, prefix="/discount-strategies", tags=["discount-strategies"])
api_router.include_router(milestones.router, prefix="/events", tags=["milestones"])
api_router.include_router(schedule.router, prefix="/events", tags=["schedule"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(public_profiles.router, prefix="/users", tags=["profiles"])
api_router.include_router(ratings.router, prefix="", tags=["ratings"])
api_router.include_router(notifications.router, prefix="/me", tags=["notifications"])
api_router.include_router(organizer_faq.router, prefix="/me", tags=["faqs"])
api_router.include_router(config.router, prefix="/config", tags=["config"])
api_router.include_router(banking.router, prefix="", tags=["banking"])
api_router.include_router(webhooks.router, prefix="", tags=["webhooks"])
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
api_router.include_router(event_polls.router, prefix="/events", tags=["polls"])
