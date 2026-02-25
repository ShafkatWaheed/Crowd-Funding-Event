"""Sponsors API: single router built from sub-routers, same paths and tags as before."""
from fastapi import APIRouter

from app.api.v1.sponsors import profile, templates, categories, bids, payments, tickets, organizer_views

router = APIRouter()
router.include_router(profile.router, prefix="")
router.include_router(templates.router, prefix="")
router.include_router(categories.router, prefix="")
router.include_router(bids.router, prefix="")
router.include_router(payments.router, prefix="")
router.include_router(tickets.router, prefix="")
router.include_router(organizer_views.router, prefix="")
