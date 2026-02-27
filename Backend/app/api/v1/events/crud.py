"""
Events CRUD: list, featured, genres, create, get, patch, delete, calendar.ics.
"""
import asyncio
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import Response
from sqlalchemy import select

from app.dependencies import CurrentUserOptional, DbSession, ReadDbSession, require_role
from app.rate_limit import limiter, dynamic_limit
from app.models.event import Event, EventStatus, RegistrationType
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User, UserRole
from app.schemas import (
    EVENT_GENRES,
    EventCreate,
    EventResponse,
    EventUpdate,
)
from app.core.exceptions import ForbiddenError, NotFoundError
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import ticket as ticket_service
from app.services import notification_service as notif_svc
from app.models.notification import NotificationType

from ._helpers import (
    _event_to_ics,
    _event_to_response,
    _get_first_images,
    _parse_date_or_datetime,
    _parse_iso_datetime,
)

router = APIRouter()


@limiter.limit(dynamic_limit("public_search", "60/minute"))
async def list_events(
    request: Request,
    db: ReadDbSession,
    search: str | None = Query(None, description="Search in event title and description"),
    city: str | None = Query(None, description="e.g. Ottawa"),
    status: str | None = Query(None),
    live: bool | None = Query(None),
    registration_type: str | None = Query(None),
    organizer_id: int | None = Query(None),
    date_from: str | None = Query(None, description="Events starting on or after (ISO date or datetime)"),
    date_to: str | None = Query(None, description="Events starting on or before (ISO date or datetime)"),
    has_funding: bool | None = Query(None, description="True = has goal or deadline; False = no funding"),
    has_tickets: bool | None = Query(None, description="True = has ticket tiers; False = no tiers"),
    min_capacity: int | None = Query(None, description="Event max_capacity >= this"),
    max_capacity: int | None = Query(None, description="Event max_capacity <= this"),
    genre: str | None = Query(None, description="Filter by genre"),
    community_rules: bool | None = Query(None, description="True = community rules events only"),
    sponsorship_only: bool = Query(False, description="True = only events with sponsorship categories"),
    include_all_statuses: bool = Query(False, description="True = show draft/pending/cancelled (for organizer/admin)"),
    offset: int | None = Query(None, ge=0, description="Pagination offset (deprecated: prefer cursor)"),
    limit: int = Query(20, ge=1, le=100, description="Page size (max 100)"),
    cursor: str | None = Query(None, description="Keyset cursor from previous response for infinite scroll"),
):
    """List events with optional search and filters."""
    date_from_dt = _parse_date_or_datetime(date_from, end_of_day=False)
    date_to_dt = _parse_date_or_datetime(date_to, end_of_day=True)
    events, next_cursor = await event_service.list_events(
        db,
        search=search,
        city=city,
        status=status,
        live=live,
        registration_type=registration_type,
        organizer_id=organizer_id,
        date_from=date_from_dt,
        date_to=date_to_dt,
        has_funding=has_funding,
        has_tickets=has_tickets,
        min_capacity=min_capacity,
        max_capacity=max_capacity,
        genre=genre,
        community_rules=community_rules,
        sponsorship_only=sponsorship_only,
        include_all_statuses=include_all_statuses,
        offset=offset if offset is not None else 0,
        limit=limit,
        cursor=cursor,
    )
    event_ids = [e.id for e in events]
    pledged, reserved, tickets_sold, first_images = await asyncio.gather(
        funding_service.get_pledged_totals_for_events(db, event_ids=event_ids),
        funding_service.get_total_reserved_spots_for_events(db, event_ids=event_ids),
        ticket_service.get_ticket_sold_counts_for_events(db, event_ids=event_ids),
        _get_first_images(db, event_ids),
    )
    now = datetime.now(timezone.utc)
    out = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        out.append(
            _event_to_response(
                e,
                total_pledged_cents=total_cents,
                funding_days_left=days_left,
                total_reserved_spots=reserved.get(e.id, 0),
                tickets_sold_count=tickets_sold.get(e.id, 0),
                first_image_url=first_images.get(e.id),
            )
        )
    return {"items": out, "next_cursor": next_cursor}


@router.get("/genres", response_model=list[str])
async def list_genres():
    """Return the list of available event genres."""
    return EVENT_GENRES


@router.get("/featured")
@limiter.limit(dynamic_limit("public_search", "60/minute"))
async def get_featured_events(request: Request, db: ReadDbSession, sponsorship_only: bool = Query(False)):
    """Returns trending, popular, and coming-soon event lists for the discover page."""
    from app.cache import cache_json_get, cache_json_set
    from app.services.platform_settings import get_int as get_setting_int

    cache_key = f"featured:{sponsorship_only}"
    cached = await cache_json_get(cache_key)
    if cached is not None:
        return cached

    trending = await event_service.get_trending_events(db, limit=10, sponsorship_only=sponsorship_only)
    popular = await event_service.get_popular_events(db, limit=10, sponsorship_only=sponsorship_only)
    coming_soon = await event_service.get_coming_soon_events(db, limit=10, sponsorship_only=sponsorship_only)

    trending_ids = [e.id for e in trending]
    popular_ids = [e.id for e in popular]
    coming_soon_ids = [e.id for e in coming_soon]
    all_ids = list(set(trending_ids + popular_ids + coming_soon_ids))
    pledged, reserved, tickets_sold, first_images = await asyncio.gather(
        funding_service.get_pledged_totals_for_events(db, event_ids=all_ids),
        funding_service.get_total_reserved_spots_for_events(db, event_ids=all_ids),
        ticket_service.get_ticket_sold_counts_for_events(db, event_ids=all_ids),
        _get_first_images(db, all_ids),
    )

    now = datetime.now(timezone.utc)

    def _to_resp(e: Event) -> EventResponse:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        return _event_to_response(
            e,
            total_pledged_cents=total_cents,
            funding_days_left=days_left,
            total_reserved_spots=reserved.get(e.id, 0),
            tickets_sold_count=tickets_sold.get(e.id, 0),
            first_image_url=first_images.get(e.id),
        )

    result = {
        "trending": [_to_resp(e).model_dump(mode="json") for e in trending],
        "popular": [_to_resp(e).model_dump(mode="json") for e in popular],
        "coming_soon": [_to_resp(e).model_dump(mode="json") for e in coming_soon],
    }
    ttl = await get_setting_int(db, "cache_ttl_featured")
    await cache_json_set(cache_key, result, ttl=ttl)
    return result


@limiter.limit(dynamic_limit("event_create", "5/minute"))
async def create_event(
    request: Request,
    body: EventCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create event (organizer or admin). At least one of event date or funding deadline must be set."""
    start_time = _parse_iso_datetime(body.start_time) if body.start_time else None
    end_time = _parse_iso_datetime(body.end_time) if body.end_time else None
    funding_end_at = _parse_iso_datetime(body.funding_end_at) if body.funding_end_at else None
    reg_type = RegistrationType(body.registration_type)
    event = await event_service.create(
        db,
        organizer_id=current_user.id,
        venue_id=body.venue_id,
        title=body.title,
        description=body.description,
        start_time=start_time,
        end_time=end_time,
        funding_goal_cents=body.funding_goal_cents,
        funding_end_at=funding_end_at,
        min_pledge_cents=body.min_pledge_cents,
        registration_type=reg_type,
        max_capacity=body.max_capacity,
        max_reserved_spots_per_user=body.max_reserved_spots_per_user,
        common_discount_percent=body.common_discount_percent,
        pledge_discount_percent=body.pledge_discount_percent,
        allow_any_venue=(current_user.role == UserRole.admin),
        publish=body.publish,
        genre=body.genre,
        community_rules=body.community_rules,
        posts_enabled=body.posts_enabled,
        refund_deadline_days=body.refund_deadline_days,
        ticket_strategy_id=body.ticket_strategy_id,
        parking_info=body.parking_info,
        transit_info=body.transit_info,
        rideshare_info=body.rideshare_info,
        accessibility_info=body.accessibility_info,
        has_schedule=body.has_schedule,
        link_funding_to_tiers=body.link_funding_to_tiers,
        waitlist_max_size=body.waitlist_max_size,
        waitlist_auto_approve=body.waitlist_auto_approve,
        event_max_images=body.event_max_images,
        max_posts_per_day=body.max_posts_per_day,
        max_co_organizers=body.max_co_organizers,
        refund_deadline_percent=body.refund_deadline_percent,
    )
    if body.max_discount_percent is not None:
        event.max_discount_percent = max(0, min(100, body.max_discount_percent))
    event.age_restricted = body.age_restricted
    event.min_age = body.min_age
    await db.flush()
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(event_id: int, db: ReadDbSession, current_user: CurrentUserOptional = None):
    """Event detail (public). Includes venue so everyone can see where the event is."""
    from app.cache import cache_json_get, cache_json_set
    from app.services.platform_settings import get_int as get_setting_int

    is_admin = current_user is not None and current_user.role == UserRole.admin

    if not is_admin:
        cached = await cache_json_get(f"event:{event_id}")
        if cached is not None:
            if current_user is not None:
                event_obj = await event_service.get_by_id(db, event_id)
                if event_obj:
                    co_perm = await event_service.get_co_organizer_role(db, event_obj, current_user)
                    cached["viewer_co_organizer_permission"] = co_perm
            return cached

    event = await event_service.get_by_id(db, event_id, load_venue=True, load_organizer=True)
    if not event:
        raise NotFoundError("Event", event_id)
    summary = await funding_service.get_summary(db, event_id=event_id)
    ticket_stats = await ticket_service.get_ticket_sales_stats(db, event_id=event_id)
    now = datetime.now(timezone.utc)
    days_left = None
    if event.funding_end_at is not None:
        end = event.funding_end_at if event.funding_end_at.tzinfo else event.funding_end_at.replace(tzinfo=timezone.utc)
        delta = (end - now).days
        days_left = max(0, delta) if delta > 0 else 0
    trust = await event_service.get_organizer_trust_score(db, organizer_id=event.organizer_id)
    first_images = await _get_first_images(db, [event.id])
    eff_policy = await event_service.get_effective_policy(db, event)
    resp = _event_to_response(
        event,
        total_pledged_cents=summary["total_pledged_cents"],
        funding_days_left=days_left,
        total_reserved_spots=summary.get("total_reserved_spots", 0),
        tickets_sold_count=ticket_stats["total_sold"],
        include_dislike=is_admin,
        organizer_trust=trust,
        first_image_url=first_images.get(event.id),
        effective_policy=eff_policy,
    )

    if not is_admin:
        ttl = await get_setting_int(db, "cache_ttl_event_detail")
        await cache_json_set(f"event:{event_id}", resp.model_dump(mode="json"), ttl=ttl)

    if current_user is not None:
        co_perm = await event_service.get_co_organizer_role(db, event, current_user)
        resp.viewer_co_organizer_permission = co_perm

    return resp


@router.get("/{event_id}/calendar.ics")
async def get_event_calendar(event_id: int, db: ReadDbSession):
    """Add to calendar: returns iCalendar (.ics) file for the event. Public."""
    event = await event_service.get_by_id(db, event_id, load_venue=True)
    if not event:
        raise NotFoundError("Event", event_id)
    ics = _event_to_ics(event)
    filename = "".join(c if c.isalnum() or c in " -_" else "_" for c in (event.title or "event")[:80]) + ".ics"
    return Response(
        content=ics,
        media_type="text/calendar",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.patch("/{event_id}", response_model=EventResponse)
async def update_event(
    event_id: int,
    body: EventUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """
    Update event (main organizer, co-organizer, or admin).
    - Draft events: edit freely, stays draft.
    - Approved/live events: substantive edits move status to pending_approval.
    - Admin edits always apply without status change.
    """
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot update this event")

    _SUBSTANTIVE_FIELDS = {
        "title", "description", "start_time", "end_time",
        "funding_goal_cents", "funding_end_at", "min_pledge_cents",
        "registration_type", "genre", "community_rules",
        "common_discount_percent", "pledge_discount_percent",
    }
    body_data = body.model_dump(exclude_unset=True)
    has_substantive_change = bool(_SUBSTANTIVE_FIELDS & body_data.keys())

    needs_approval = (
        has_substantive_change
        and event.status in (EventStatus.approved, EventStatus.waiting_event_date)
        and current_user.role != UserRole.admin
    )

    start_time = _parse_iso_datetime(body.start_time) if body.start_time else None
    end_time = _parse_iso_datetime(body.end_time) if body.end_time else None
    funding_end_at = _parse_iso_datetime(body.funding_end_at) if body.funding_end_at is not None else None
    reg_type = RegistrationType(body.registration_type) if body.registration_type is not None else None
    updated = await event_service.update(
        db,
        event,
        title=body.title,
        description=body.description,
        start_time=start_time,
        end_time=end_time,
        venue_id=body.venue_id,
        funding_goal_cents=body.funding_goal_cents,
        funding_end_at=funding_end_at,
        min_pledge_cents=body.min_pledge_cents,
        registration_type=reg_type,
        max_capacity=body.max_capacity,
        max_reserved_spots_per_user=body.max_reserved_spots_per_user,
        common_discount_percent=body.common_discount_percent,
        pledge_discount_percent=body.pledge_discount_percent,
        genre=body.genre,
        community_rules=body.community_rules,
        posts_enabled=body.posts_enabled,
        refund_deadline_days=body.refund_deadline_days,
        ticket_strategy_id=body.ticket_strategy_id,
        parking_info=body.parking_info,
        transit_info=body.transit_info,
        rideshare_info=body.rideshare_info,
        accessibility_info=body.accessibility_info,
        has_schedule=body.has_schedule,
        link_funding_to_tiers=body.link_funding_to_tiers,
        waitlist_max_size=body.waitlist_max_size,
        waitlist_auto_approve=body.waitlist_auto_approve,
        event_max_images=body.event_max_images,
        max_posts_per_day=body.max_posts_per_day,
        max_co_organizers=body.max_co_organizers,
        refund_deadline_percent=body.refund_deadline_percent,
    )

    if body.max_discount_percent is not None:
        updated.max_discount_percent = max(0, min(100, body.max_discount_percent))
    if body.age_restricted is not None:
        updated.age_restricted = body.age_restricted
    if body.min_age is not None:
        updated.min_age = body.min_age
    await db.flush()

    if needs_approval:
        updated.status = EventStatus.pending_approval
        await db.flush()

    if event.status in (EventStatus.approved, EventStatus.waiting_event_date,
                        EventStatus.selling_tickets, EventStatus.live):
        reg_q = select(Registration.user_id).where(
            Registration.event_id == event.id,
            Registration.status.in_([RegistrationStatus.registered, RegistrationStatus.waitlist]),
        )
        reg_ids = [r for r in (await db.execute(reg_q)).scalars().all()]
        if reg_ids:
            await notif_svc.create_bulk_notifications(
                db, user_ids=reg_ids,
                type=NotificationType.event_updated,
                title="Event Updated",
                message=f'"{event.title}" has been updated. Check the latest details.',
                data={"event_id": event.id},
            )

    from app.cache import cache_delete, cache_delete_pattern
    await cache_delete(f"event:{event_id}")
    await cache_delete_pattern("featured:*")

    updated = await event_service.get_by_id(db, updated.id, load_venue=True)
    return _event_to_response(updated)


@router.delete("/{event_id}")
async def delete_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete (draft/pending) or cancel event (main organizer, co-organizer, or admin)."""
    event = await event_service.get_or_404(db, event_id)
    await event_service.delete_or_cancel(db, event, current_user)
    return {"ok": True}
