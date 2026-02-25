"""
Events API: single router aggregating all event sub-routers.
Same prefix and tags as before; only code organization changed.
"""
from fastapi import APIRouter

from app.schemas import EventResponse

from . import crud, lifecycle, organizers, pledge, registration, tickets, discounts, posts, images, reactions
from ._helpers import _build_tier_reservation_response, _event_to_response, _get_first_images
from .tickets import _ticket_sale_to_response

router = APIRouter()
# Register empty-path routes on this router (FastAPI disallows prefix and path both "")
router.get("", response_model=list[EventResponse])(crud.list_events)
router.post("", response_model=EventResponse)(crud.create_event)
router.include_router(crud.router, prefix="")
router.include_router(lifecycle.router, prefix="")
router.include_router(organizers.router, prefix="")
router.include_router(pledge.router, prefix="")
router.include_router(registration.router, prefix="")
router.include_router(tickets.router, prefix="")
router.include_router(discounts.router, prefix="")
router.include_router(posts.router, prefix="")
router.include_router(images.router, prefix="")
router.include_router(reactions.router, prefix="")

__all__ = [
    "router",
    "_event_to_response",
    "_get_first_images",
    "_build_tier_reservation_response",
    "_ticket_sale_to_response",
]
