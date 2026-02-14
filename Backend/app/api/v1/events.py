"""
Events: CRUD, list (filters), pledge, register, registrations.
"""
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from pydantic import BaseModel

from app.dependencies import CurrentUserOptional, DbSession, require_role
from app.models.event import Event, EventStatus, RegistrationType
from app.models.user import User, UserRole
from app.schemas import (
    AddEventOrganizerBody,
    CancelBody,
    EVENT_GENRES,
    EventCreate,
    EventDiscountCreate,
    EventDiscountResponse,
    EventImageResponse,
    EventOrganizerItem,
    EventPostCreate,
    EventPostResponse,
    EventResponse,
    EventUpdate,
    EventVenueInfo,
    ExtendFundingBody,
    ExtensionApprovalAction,
    SetEventDateBody,
    FundingSummaryResponse,
    PledgeBody,
    PledgeResponse,
    RegistrationDecisionBody,
    RegistrationResponse,
    ScanTicketBody,
    ScanTicketResponse,
    TicketPricePreviewResponse,
    TicketPurchaseBody,
    TicketSaleResponse,
    TicketTierCreate,
    TicketTierResponse,
    TicketTierUpdate,
    UnpledgeResponse,
    UnregisterResponse,
    UserDiscountBody,
)
from app.core.exceptions import ForbiddenError, NotFoundError
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import post as post_service
from app.services import registration as registration_service
from app.services import ticket as ticket_service
from app.services import discount_strategy as ds_service
# DiscountStrategyResponse no longer needed — endpoint returns raw dicts

router = APIRouter()


def _parse_iso_datetime(v: str | None) -> datetime | None:
    if v is None:
        return None
    dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _event_to_response(
    e: Event,
    *,
    total_pledged_cents: int | None = None,
    funding_days_left: int | None = None,
    include_dislike: bool = False,
    organizer_trust: dict | None = None,
) -> EventResponse:
    """Build response; e.venue must be loaded so everyone can see venue info when viewing an event."""
    from app.schemas.event import OrganizerTrustInfo
    venue_info = EventVenueInfo.model_validate(e.venue) if e.venue else None
    if venue_info is None:
        raise ValueError("Event.venue must be loaded when building EventResponse")
    trust_info = None
    if organizer_trust:
        trust_info = OrganizerTrustInfo(
            trust_score=organizer_trust["trust_score"],
            label=organizer_trust["label"],
            completed_events=organizer_trust["completed_events"],
            published_events=organizer_trust["published_events"],
        )
    return EventResponse(
        id=e.id,
        organizer_id=e.organizer_id,
        venue_id=e.venue_id,
        venue=venue_info,
        title=e.title,
        description=e.description,
        start_time=e.start_time,
        end_time=e.end_time,
        status=e.status.value,
        registration_type=e.registration_type.value,
        max_capacity=e.max_capacity,
        funding_goal_cents=e.funding_goal_cents,
        funding_end_at=e.funding_end_at,
        total_pledged_cents=total_pledged_cents,
        funding_days_left=funding_days_left,
        min_pledge_cents=e.min_pledge_cents,
        common_discount_percent=e.common_discount_percent,
        pledge_discount_percent=e.pledge_discount_percent,
        cancellation_reason=e.cancellation_reason,
        registration_count=e.registration_count,
        genre=e.genre,
        community_rules=e.community_rules,
        posts_enabled=e.posts_enabled,
        refund_deadline_days=e.refund_deadline_days,
        event_date_deadline=e.event_date_deadline,
        ticket_strategy_id=e.ticket_strategy_id,
        ticket_strategy_name=e.ticket_strategy.name if e.ticket_strategy_id and e.ticket_strategy else None,
        like_count=e.like_count,
        dislike_count=e.dislike_count if include_dislike else 0,
        pending_extension=e.pending_extension,
        pending_cancellation=e.pending_cancellation,
        organizer_trust=trust_info,
        lat=e.lat,
        lng=e.lng,
        created_at=e.created_at,
        updated_at=e.updated_at,
    )


def _parse_date_or_datetime(v: str | None, end_of_day: bool = False) -> datetime | None:
    """Parse ISO date (YYYY-MM-DD) or datetime; return as UTC. If date only: start of day or end of day."""
    if v is None:
        return None
    v = v.strip()
    if not v:
        return None
    try:
        if "T" in v or " " in v or (len(v) >= 19 and v[10:11] in ("T", " ")):
            dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
        else:
            d = date.fromisoformat(v)
            if end_of_day:
                dt = datetime.combine(d, datetime.max.time()).replace(tzinfo=timezone.utc)
            else:
                dt = datetime.combine(d, datetime.min.time()).replace(tzinfo=timezone.utc)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except (ValueError, TypeError):
        return None


@router.get("", response_model=list[EventResponse])
async def list_events(
    db: DbSession,
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
    include_all_statuses: bool = Query(False, description="True = show draft/pending/cancelled (for organizer/admin)"),
):
    """List events with optional search and filters."""
    date_from_dt = _parse_date_or_datetime(date_from, end_of_day=False)
    date_to_dt = _parse_date_or_datetime(date_to, end_of_day=True)
    events = await event_service.list_events(
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
        include_all_statuses=include_all_statuses,
    )
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids)
    now = datetime.now(timezone.utc)
    out = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0  # 0 = ended
        out.append(
            _event_to_response(
                e,
                total_pledged_cents=total_cents,
                funding_days_left=days_left,
            )
        )
    return out


@router.get("/genres", response_model=list[str])
async def list_genres():
    """Return the list of available event genres."""
    return EVENT_GENRES


@router.get("/featured")
async def get_featured_events(db: DbSession):
    """Returns trending, popular, and coming-soon event lists for the discover page."""
    trending = await event_service.get_trending_events(db, limit=10)
    popular = await event_service.get_popular_events(db, limit=10)
    coming_soon = await event_service.get_coming_soon_events(db, limit=10)

    trending_ids = [e.id for e in trending]
    popular_ids = [e.id for e in popular]
    coming_soon_ids = [e.id for e in coming_soon]
    all_ids = list(set(trending_ids + popular_ids + coming_soon_ids))
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=all_ids)

    now = datetime.now(timezone.utc)

    def _to_resp(e: Event) -> EventResponse:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        return _event_to_response(e, total_pledged_cents=total_cents, funding_days_left=days_left)

    return {
        "trending": [_to_resp(e) for e in trending],
        "popular": [_to_resp(e) for e in popular],
        "coming_soon": [_to_resp(e) for e in coming_soon],
    }


@router.post("", response_model=EventResponse)
async def create_event(
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
        common_discount_percent=body.common_discount_percent,
        pledge_discount_percent=body.pledge_discount_percent,
        allow_any_venue=(current_user.role == UserRole.admin),
        publish=body.publish,
        genre=body.genre,
        community_rules=body.community_rules,
        posts_enabled=body.posts_enabled,
        refund_deadline_days=body.refund_deadline_days,
        ticket_strategy_id=body.ticket_strategy_id,
    )
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(event_id: int, db: DbSession, current_user: CurrentUserOptional = None):
    """Event detail (public). Includes venue so everyone can see where the event is."""
    event = await event_service.get_by_id(db, event_id, load_venue=True)
    if not event:
        raise NotFoundError("Event", event_id)
    summary = await funding_service.get_summary(db, event_id=event_id)
    now = datetime.now(timezone.utc)
    days_left = None
    if event.funding_end_at is not None:
        end = event.funding_end_at if event.funding_end_at.tzinfo else event.funding_end_at.replace(tzinfo=timezone.utc)
        delta = (end - now).days
        days_left = max(0, delta) if delta > 0 else 0
    is_admin = current_user is not None and current_user.role == UserRole.admin
    # Compute organizer trust score
    trust = await event_service.get_organizer_trust_score(db, organizer_id=event.organizer_id)
    return _event_to_response(
        event,
        total_pledged_cents=summary["total_pledged_cents"],
        funding_days_left=days_left,
        include_dislike=is_admin,
        organizer_trust=trust,
    )


def _event_to_ics(event: Event) -> str:
    """Build iCalendar (.ics) string for the event. Event.venue must be loaded for location."""
    def ical_dt(dt: datetime) -> str:
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.strftime("%Y%m%dT%H%M%SZ")

    now = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    uid = f"event-{event.id}@crowdfund"
    summary = (event.title or "Event").replace("\r", "").replace("\n", " ")
    description = (event.description or "").replace("\r", " ").replace("\n", " ")
    location = ""
    if event.venue:
        parts = [event.venue.name, event.venue.address, event.venue.city]
        if event.venue.province:
            parts.append(event.venue.province)
        location = ", ".join(p for p in parts if p).replace("\r", " ").replace("\n", " ")
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//CrowdFund Event//EN",
        "CALSCALE:GREGORIAN",
        "BEGIN:VEVENT",
        f"UID:{uid}",
        f"DTSTAMP:{now}",
        f"DTSTART:{ical_dt(event.start_time)}",
        f"DTEND:{ical_dt(event.end_time)}",
        f"SUMMARY:{summary}",
        f"DESCRIPTION:{description}",
        f"LOCATION:{location}",
        "END:VEVENT",
        "END:VCALENDAR",
    ]
    return "\r\n".join(lines)


@router.get("/{event_id}/calendar.ics")
async def get_event_calendar(event_id: int, db: DbSession):
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
    - Approved/live events: substantive edits (title, description, dates, funding,
      registration type, genre, community rules) move status to pending_approval.
    - Operational changes (venue, max_capacity, ticket_strategy, posts, discounts,
      refund_deadline) are always allowed without re-approval.
    - Admin edits always apply without status change.
    """
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot update this event")

    # Fields that require admin re-approval when changed on an approved/live event
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
        common_discount_percent=body.common_discount_percent,
        pledge_discount_percent=body.pledge_discount_percent,
        genre=body.genre,
        community_rules=body.community_rules,
        posts_enabled=body.posts_enabled,
        refund_deadline_days=body.refund_deadline_days,
        ticket_strategy_id=body.ticket_strategy_id,
    )

    if needs_approval:
        updated.status = EventStatus.pending_approval
        await db.flush()

    updated = await event_service.get_by_id(db, updated.id, load_venue=True)
    return _event_to_response(updated)


@router.post("/{event_id}/cancel", response_model=EventResponse)
async def cancel_event(
    event_id: int,
    body: CancelBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Organizer (main or co-) cancels the event. A reason is required."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot cancel this event")
    event = await event_service.cancel_event(db, event, current_user, reason=body.reason)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/extend-funding", response_model=EventResponse)
async def extend_funding_endpoint(
    event_id: int,
    body: ExtendFundingBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Extend funding: new deadline and/or new goal. Requires admin approval for organizers."""
    event = await event_service.get_or_404(db, event_id)
    if not any([body.funding_end_at, body.funding_goal_cents]):
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="At least one of funding_end_at or funding_goal_cents required")
    new_funding_end_at = _parse_iso_datetime(body.funding_end_at)
    event = await event_service.extend_funding(
        db, event, current_user,
        new_funding_end_at=new_funding_end_at,
        new_funding_goal_cents=body.funding_goal_cents,
    )
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/set-event-date", response_model=EventResponse)
async def set_event_date_endpoint(
    event_id: int,
    body: SetEventDateBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Set or update event start/end time. Applies directly, no admin approval needed."""
    event = await event_service.get_or_404(db, event_id)
    new_start = _parse_iso_datetime(body.start_time)
    new_end = _parse_iso_datetime(body.end_time)
    if new_start is None or new_end is None:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Both start_time and end_time are required as valid ISO datetimes")
    event = await event_service.set_event_date(
        db, event, current_user,
        new_start_time=new_start,
        new_end_time=new_end,
    )
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/start-selling", response_model=EventResponse)
async def start_selling_tickets_endpoint(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Manually transition event to selling_tickets. Requires dates + ticket strategy."""
    event = await event_service.get_or_404(db, event_id)
    event = await event_service.start_selling_tickets(db, event, current_user)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


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


# ----- Event co-organizers (main organizer only can add/remove) -----
@router.get("/{event_id}/organizers", response_model=list[EventOrganizerItem])
async def list_event_organizers(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List main + co-organizers for the event. Requires organizer/co-organizer/admin."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_read_event_mgmt(db, event, current_user):
        raise ForbiddenError("You cannot view organizers for this event")
    main, co_organizers = await event_service.list_event_organizers(db, event_id=event_id)
    out = [
        EventOrganizerItem(
            user_id=main.id,
            display_name=main.display_name,
            email=main.email,
            is_main=True,
            permission="full",
        ),
    ]
    for eo in co_organizers:
        u = eo.user
        out.append(
            EventOrganizerItem(
                user_id=u.id,
                display_name=u.display_name,
                email=u.email,
                is_main=False,
                permission=eo.permission,
            ),
        )
    return out


@router.post("/{event_id}/organizers")
async def add_event_organizer(
    event_id: int,
    body: AddEventOrganizerBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Add a co-organizer (main organizer only). User must have organizer role."""
    event = await event_service.get_or_404(db, event_id)
    if not event_service.is_main_organizer(current_user, event):
        raise ForbiddenError("Only the main organizer can add co-organizers")
    eo = await event_service.add_event_organizer(
        db, event_id=event_id, user_id=body.user_id,
        added_by=current_user, permission=body.permission,
    )
    return {"id": eo.id, "event_id": eo.event_id, "user_id": eo.user_id, "permission": eo.permission}


@router.delete("/{event_id}/organizers/{user_id}")
async def remove_event_organizer(
    event_id: int,
    user_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Remove a co-organizer (main organizer only)."""
    event = await event_service.get_or_404(db, event_id)
    if not event_service.is_main_organizer(current_user, event):
        raise ForbiddenError("Only the main organizer can remove co-organizers")
    await event_service.remove_event_organizer(db, event_id=event_id, user_id=user_id, removed_by=current_user)
    return {"ok": True}


@router.post("/{event_id}/reactivate", response_model=EventResponse)
async def reactivate_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Move a cancelled event back to draft so it can be edited and republished."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot reactivate this event")
    event = await event_service.reactivate_event(db, event, current_user)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/publish", response_model=EventResponse)
async def publish_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Publish a draft event (draft → approved). No admin approval needed."""
    event = await event_service.publish_event(db, event_id=event_id, user=current_user)
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


@router.post("/{event_id}/clone", response_model=EventResponse)
async def clone_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Clone a completed event into a new draft with pre-filled values (no dates)."""
    event = await event_service.get_or_404(db, event_id)
    new_event = await event_service.clone_event(db, event, current_user)
    new_event = await event_service.get_by_id(db, new_event.id, load_venue=True)
    return _event_to_response(new_event)


@router.post("/{event_id}/pledge")
async def pledge_event(
    event_id: int,
    body: PledgeBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Pledge to event (customer). Only allowed during approved (funding active) status."""
    event = await event_service.get_or_404(db, event_id)
    if event.status not in (EventStatus.approved,):
        from fastapi import HTTPException
        raise HTTPException(status_code=409, detail="Pledging is only allowed during the funding period")
    pledge = await funding_service.create_pledge(
        db,
        event_id=event_id,
        user=current_user,
        amount_cents=body.amount_cents,
    )
    return PledgeResponse(
        id=pledge.id,
        event_id=pledge.event_id,
        user_id=pledge.user_id,
        amount_cents=pledge.amount_cents,
        status=pledge.status.value,
        is_guest=pledge.is_guest,
        created_at=pledge.created_at,
    )


@router.post("/{event_id}/unpledge", response_model=UnpledgeResponse)
async def unpledge_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Unpledge from event (customer). Guest pledges are non-refundable."""
    result = await funding_service.unpledge(
        db,
        event_id=event_id,
        user=current_user,
    )
    return UnpledgeResponse(**result)


@router.get("/{event_id}/funding")
async def get_event_funding(event_id: int, db: DbSession):
    """Funding summary for event (public or organizer/admin)."""
    summary = await funding_service.get_summary(db, event_id=event_id)
    return FundingSummaryResponse(**summary)


@router.get("/{event_id}/escrow")
async def get_event_escrow(event_id: int, db: DbSession):
    """Escrow summary for event (public)."""
    from app.services import escrow as escrow_service
    return await escrow_service.get_escrow_summary(db, event_id=event_id)


@router.get("/{event_id}/organizer-trust")
async def get_event_organizer_trust(event_id: int, db: DbSession):
    """Organizer trust score for this event's organizer (public)."""
    event = await event_service.get_by_id(db, event_id)
    if not event:
        raise NotFoundError("Event", event_id)
    return await event_service.get_organizer_trust_score(db, organizer_id=event.organizer_id)


@router.post("/{event_id}/register")
async def register_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Register for event (open: first-come; closed: request). Check capacity."""
    reg = await registration_service.register(db, event_id=event_id, user=current_user)
    return RegistrationResponse(
        id=reg.id,
        event_id=reg.event_id,
        user_id=reg.user_id,
        status=reg.status.value,
        created_at=reg.created_at,
    )


@router.get("/{event_id}/my-registration")
async def get_my_registration(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Check if the current user is registered for this event. Returns status or null."""
    from sqlalchemy import select
    from app.models.registration import Registration
    q = select(Registration).where(
        Registration.event_id == event_id,
        Registration.user_id == current_user.id,
    )
    result = await db.execute(q)
    reg = result.scalar_one_or_none()
    if reg:
        return {"registered": True, "status": reg.status.value}
    return {"registered": False, "status": None}


@router.post("/{event_id}/unregister", response_model=UnregisterResponse)
async def unregister_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Customer unregisters from event. Not allowed after funding ends (selling_tickets/waiting/live/completed)."""
    event = await event_service.get_or_404(db, event_id)
    blocked_statuses = (
        EventStatus.selling_tickets, EventStatus.waiting_event_date,
        EventStatus.live, EventStatus.completed,
    )
    if event.status in blocked_statuses:
        from fastapi import HTTPException
        raise HTTPException(
            status_code=409,
            detail=f"Cannot unregister — event is in '{event.status.value}' state",
        )
    result = await registration_service.unregister(db, event_id=event_id, user=current_user)
    return UnregisterResponse(
        refunded_cents=result["refunded_cents"],
        pledges_refunded=result["pledges_refunded"],
        refund_eligible=result["refund_eligible"],
    )


@router.get("/{event_id}/registrations")
async def list_registrations(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List registrations for event (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view registrations for this event")
    regs = await registration_service.list_registrations(db, event_id=event_id)
    return [
        RegistrationResponse(
            id=r.id,
            event_id=r.event_id,
            user_id=r.user_id,
            status=r.status.value,
            created_at=r.created_at,
        )
        for r in regs
    ]


@router.post("/{event_id}/registrations/{registration_id}/decision", response_model=RegistrationResponse)
async def decide_registration(
    event_id: int,
    registration_id: int,
    body: RegistrationDecisionBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """
    Organizer/admin approves or rejects a waitlist request.
    - approve: waitlist -> registered (if capacity allows)
    - reject: waitlist -> cancelled
    """
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot manage registrations for this event")

    if body.action == "approve":
        reg = await registration_service.approve_waitlist(
            db, event_id=event_id, registration_id=registration_id
        )
    else:
        reg = await registration_service.reject_waitlist(
            db, event_id=event_id, registration_id=registration_id
        )

    return RegistrationResponse(
        id=reg.id,
        event_id=reg.event_id,
        user_id=reg.user_id,
        status=reg.status.value,
        created_at=reg.created_at,
    )


# ----- Ticket tiers (organizer) -----
@router.get("/{event_id}/ticket-tiers", response_model=list[TicketTierResponse])
async def list_ticket_tiers(event_id: int, db: DbSession):
    """List ticket tiers for an event (public)."""
    tiers = await ticket_service.list_tiers(db, event_id=event_id)
    return [TicketTierResponse.model_validate(t) for t in tiers]


@router.post("/{event_id}/ticket-tiers", response_model=TicketTierResponse)
async def create_ticket_tier(
    event_id: int,
    body: TicketTierCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create a ticket tier (organizer/admin)."""
    tier = await ticket_service.create_tier(
        db, event_id=event_id, user=current_user,
        name=body.name, description=body.description,
        price_cents=body.price_cents,
        display_order=body.display_order,
    )
    return TicketTierResponse.model_validate(tier)


@router.patch("/{event_id}/ticket-tiers/{tier_id}", response_model=TicketTierResponse)
async def update_ticket_tier(
    event_id: int,
    tier_id: int,
    body: TicketTierUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update a ticket tier (organizer/admin)."""
    tier = await ticket_service.get_tier_or_404(db, event_id=event_id, tier_id=tier_id)
    tier = await ticket_service.update_tier(
        db, tier, current_user,
        name=body.name, description=body.description,
        price_cents=body.price_cents,
        display_order=body.display_order,
    )
    return TicketTierResponse.model_validate(tier)


@router.delete("/{event_id}/ticket-tiers/{tier_id}")
async def delete_ticket_tier(
    event_id: int,
    tier_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete a ticket tier (organizer/admin)."""
    tier = await ticket_service.get_tier_or_404(db, event_id=event_id, tier_id=tier_id)
    await ticket_service.delete_tier(db, tier, current_user)
    return {"ok": True}


# ----- Ticket price & purchase (customer) -----
@router.get("/{event_id}/ticket-price", response_model=TicketPricePreviewResponse)
async def get_ticket_price(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
    ticket_tier_id: int = Query(..., description="Ticket tier id", alias="ticket_tier_id"),
):
    """Preview ticket price for current user (with discounts + commission). Customer only."""
    info = await ticket_service.compute_ticket_price(
        db, event_id=event_id, user_id=current_user.id, tier_id=ticket_tier_id
    )
    # Add commission preview
    from app.services import platform_settings as settings_svc
    final = info["final_price_cents"]
    commission_pct = await settings_svc.get_int(db, "ticket_commission_percent")
    commission = final * commission_pct // 100 if final > 0 else 0
    info["commission_cents"] = commission
    info["net_to_organizer_cents"] = final - commission
    info["ticket_commission_percent"] = commission_pct
    return TicketPricePreviewResponse(**info)


@router.post("/{event_id}/purchase-ticket", response_model=TicketSaleResponse)
async def purchase_ticket(
    event_id: int,
    body: TicketPurchaseBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Purchase a ticket (customer, must be registered). Returns ticket with ticket_code for QR."""
    sale = await ticket_service.purchase_ticket(
        db, event_id=event_id, user=current_user,
        tier_id=body.tier_id, extra_perks=body.extra_perks,
    )
    return _ticket_sale_to_response(sale)


# ----- Scan ticket (organizer) -----
@router.post("/{event_id}/scan-ticket", response_model=ScanTicketResponse)
async def scan_ticket(
    event_id: int,
    body: ScanTicketBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Scan a ticket by QR code (organizer/admin). Returns ticket and already_scanned if already scanned."""
    sale, already_scanned = await ticket_service.scan_ticket(
        db, event_id=event_id, ticket_code=body.ticket_code, scanned_by_user=current_user,
    )
    return ScanTicketResponse(already_scanned=already_scanned, ticket=_ticket_sale_to_response(sale))


def _ticket_sale_to_response(sale) -> TicketSaleResponse:
    """Build TicketSaleResponse from a TicketSale (with event, ticket_tier, user, scanned_by loaded as needed)."""
    scanned_by_name = None
    if getattr(sale, "scanned_by", None) and sale.scanned_by:
        scanned_by_name = sale.scanned_by.display_name or sale.scanned_by.email
    attendee_name = None
    if getattr(sale, "user", None) and sale.user:
        attendee_name = sale.user.display_name or sale.user.email
    return TicketSaleResponse(
        id=sale.id,
        event_id=sale.event_id,
        user_id=sale.user_id,
        ticket_tier_id=sale.ticket_tier_id,
        ticket_code=sale.ticket_code,
        tier_name=sale.ticket_tier.name if sale.ticket_tier else None,
        event_title=sale.event.title if sale.event else None,
        attendee_display_name=attendee_name,
        amount_paid_cents=sale.amount_paid_cents,
        discount_applied_cents=sale.discount_applied_cents,
        commission_cents=getattr(sale, "commission_cents", 0) or 0,
        net_to_organizer_cents=getattr(sale, "net_to_organizer_cents", 0) or 0,
        extra_perks=sale.extra_perks,
        status=sale.status.value,
        scanned_at=sale.scanned_at,
        scanned_by_id=sale.scanned_by_id,
        scanned_by_display_name=scanned_by_name,
        created_at=sale.created_at,
    )


# ----- Ticket sales list & user discounts (organizer) -----
@router.get("/{event_id}/ticket-sales", response_model=list[TicketSaleResponse])
async def list_event_ticket_sales(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List ticket sales for event (organizer/admin). Includes scanned_at and scanned_by for scan list view."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view ticket sales for this event")
    sales = await ticket_service.list_event_ticket_sales(db, event_id=event_id)
    return [_ticket_sale_to_response(s) for s in sales]


@router.get("/{event_id}/scanned-tickets", response_model=list[TicketSaleResponse])
async def list_event_scanned_tickets(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List only scanned tickets for event (organizer/admin). Same response shape as ticket-sales."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view scanned tickets for this event")
    sales = await ticket_service.list_event_scanned_ticket_sales(db, event_id=event_id)
    return [_ticket_sale_to_response(s) for s in sales]


@router.get("/{event_id}/waitlisted-tickets", response_model=list[TicketSaleResponse])
async def list_event_waitlisted_tickets(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List waitlisted tickets for event (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot view waitlisted tickets for this event")
    sales = await ticket_service.list_event_waitlisted_tickets(db, event_id=event_id)
    return [_ticket_sale_to_response(s) for s in sales]


@router.post("/{event_id}/waitlisted-tickets/{ticket_id}/approve", response_model=TicketSaleResponse)
async def approve_waitlisted_ticket(
    event_id: int,
    ticket_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Approve a waitlisted ticket → purchased (organizer/admin)."""
    sale = await ticket_service.approve_waitlisted_ticket(
        db, event_id=event_id, ticket_sale_id=ticket_id, user=current_user,
    )
    return _ticket_sale_to_response(sale)


@router.post("/{event_id}/waitlisted-tickets/{ticket_id}/reject", response_model=TicketSaleResponse)
async def reject_waitlisted_ticket(
    event_id: int,
    ticket_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Reject a waitlisted ticket → cancelled (organizer/admin)."""
    sale = await ticket_service.reject_waitlisted_ticket(
        db, event_id=event_id, ticket_sale_id=ticket_id, user=current_user,
    )
    return _ticket_sale_to_response(sale)


@router.post("/{event_id}/discounts")
async def set_user_discount(
    event_id: int,
    body: UserDiscountBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Set selective discount for a user on this event (organizer/admin)."""
    ued = await ticket_service.set_user_discount(
        db, event_id=event_id, target_user_id=body.user_id, current_user=current_user,
        discount_type=body.discount_type, value=body.value,
    )
    return {"id": ued.id, "event_id": ued.event_id, "user_id": ued.user_id, "discount_type": ued.discount_type, "value": ued.value}


@router.delete("/{event_id}/discounts/{user_id}")
async def remove_user_discount(
    event_id: int,
    user_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Remove selective discount for a user (organizer/admin)."""
    await ticket_service.remove_user_discount(
        db, event_id=event_id, target_user_id=user_id, current_user=current_user,
    )
    return {"ok": True}


# ═══════════════════════════════════════════════════════
# Event Posts (Feed / Wall)
# ═══════════════════════════════════════════════════════

@router.get("/{event_id}/posts", response_model=list[EventPostResponse])
async def list_event_posts(event_id: int, db: DbSession):
    """List posts on an event (public)."""
    posts = await post_service.list_posts(db, event_id=event_id)
    return [
        EventPostResponse(
            id=p.id,
            event_id=p.event_id,
            user_id=p.user_id,
            author_name=p.user.display_name if p.user else None,
            content=p.content,
            created_at=p.created_at,
        )
        for p in posts
    ]


@router.post("/{event_id}/posts", response_model=EventPostResponse)
async def create_event_post(
    event_id: int,
    body: EventPostCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Create a post on an event. Customers must be registered; organizers/admins can always post."""
    post = await post_service.create_post(
        db, event_id=event_id, user=current_user, content=body.content,
    )
    return EventPostResponse(
        id=post.id,
        event_id=post.event_id,
        user_id=post.user_id,
        author_name=post.user.display_name if post.user else None,
        content=post.content,
        created_at=post.created_at,
    )


@router.delete("/{event_id}/posts/{post_id}")
async def delete_event_post(
    event_id: int,
    post_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Delete a post. Author, organizer, or admin can delete."""
    await post_service.delete_post(
        db, event_id=event_id, post_id=post_id, user=current_user,
    )
    return {"ok": True}


@router.post("/{event_id}/toggle-posts")
async def toggle_event_posts(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Organizer toggles posts on/off for the event."""
    event = await event_service.get_or_404(db, event_id)
    new_val = not event.posts_enabled
    await post_service.toggle_posts(db, event_id=event_id, user=current_user, enabled=new_val)
    return {"posts_enabled": new_val}


# ═══════════════════════════════════════════════════════
# Event Images
# ═══════════════════════════════════════════════════════

@router.get("/{event_id}/images", response_model=list[EventImageResponse])
async def list_event_images(event_id: int, db: DbSession):
    """List images for an event (public)."""
    from app.models.image import EventImage
    from sqlalchemy import select
    q = (
        select(EventImage)
        .where(EventImage.event_id == event_id)
        .order_by(EventImage.display_order.asc(), EventImage.created_at.asc())
    )
    result = await db.execute(q)
    return [EventImageResponse.model_validate(img) for img in result.scalars().all()]


@router.post("/{event_id}/images", response_model=EventImageResponse)
async def add_event_image(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
    image_url: str = Query(..., description="URL of the image"),
    caption: str | None = Query(None),
    display_order: int = Query(0),
):
    """Add an image to event by URL (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot manage this event")
    from app.models.image import EventImage
    img = EventImage(
        event_id=event_id,
        image_url=image_url,
        caption=caption,
        display_order=display_order,
    )
    db.add(img)
    await db.flush()
    await db.refresh(img)
    return EventImageResponse.model_validate(img)


@router.delete("/{event_id}/images/{image_id}")
async def delete_event_image(
    event_id: int,
    image_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete an image from event (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot manage this event")
    from app.models.image import EventImage
    from sqlalchemy import select
    q = select(EventImage).where(EventImage.id == image_id, EventImage.event_id == event_id)
    result = await db.execute(q)
    img = result.scalar_one_or_none()
    if not img:
        raise NotFoundError("Image", image_id)
    await db.delete(img)
    await db.flush()
    return {"ok": True}


# ═══════════════════════════════════════════════════════
# Like / Dislike
# ═══════════════════════════════════════════════════════

@router.post("/{event_id}/react")
async def react_to_event(
    event_id: int,
    db: DbSession,
    reaction: str = Query(..., description="'like' or 'dislike'"),
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Like or dislike an event. Toggles: same reaction again removes it; different reaction switches it."""
    if reaction not in ("like", "dislike"):
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="reaction must be 'like' or 'dislike'")

    from sqlalchemy import select
    from app.models.event import EventReaction

    event = await event_service.get_or_404(db, event_id)

    q = select(EventReaction).where(
        EventReaction.event_id == event_id,
        EventReaction.user_id == current_user.id,
    )
    existing = (await db.execute(q)).scalar_one_or_none()

    if existing:
        if existing.reaction == reaction:
            # Toggle off
            if reaction == "like":
                event.like_count = max(0, event.like_count - 1)
            else:
                event.dislike_count = max(0, event.dislike_count - 1)
            await db.delete(existing)
            await db.flush()
            return {"action": "removed", "reaction": reaction, "like_count": event.like_count, "dislike_count": event.dislike_count}
        else:
            # Switch reaction
            if existing.reaction == "like":
                event.like_count = max(0, event.like_count - 1)
            else:
                event.dislike_count = max(0, event.dislike_count - 1)
            existing.reaction = reaction
            if reaction == "like":
                event.like_count += 1
            else:
                event.dislike_count += 1
            await db.flush()
            return {"action": "switched", "reaction": reaction, "like_count": event.like_count, "dislike_count": event.dislike_count}
    else:
        new_reaction = EventReaction(
            event_id=event_id,
            user_id=current_user.id,
            reaction=reaction,
        )
        db.add(new_reaction)
        if reaction == "like":
            event.like_count += 1
        else:
            event.dislike_count += 1
        await db.flush()
        return {"action": "added", "reaction": reaction, "like_count": event.like_count, "dislike_count": event.dislike_count}


@router.get("/{event_id}/my-reaction")
async def get_my_reaction(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Check the current user's reaction on an event."""
    from sqlalchemy import select
    from app.models.event import EventReaction
    q = select(EventReaction).where(
        EventReaction.event_id == event_id,
        EventReaction.user_id == current_user.id,
    )
    existing = (await db.execute(q)).scalar_one_or_none()
    return {"reaction": existing.reaction if existing else None}


# ═══════════════════════════════════════════
# Extension Approval (admin)
# ═══════════════════════════════════════════


@router.post("/{event_id}/extension-decision", response_model=EventResponse)
async def decide_extension(
    event_id: int,
    body: ExtensionApprovalAction,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin approve/reject a pending funding extension request."""
    event = await event_service.get_or_404(db, event_id)
    if body.action == "approve":
        event = await event_service.approve_extension(db, event, current_user)
    elif body.action == "reject":
        event = await event_service.reject_extension(db, event, current_user)
    else:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="action must be 'approve' or 'reject'")
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


# ----- Admin: Cancellation Approval -----
@router.post("/{event_id}/cancellation/approve")
async def approve_cancellation(
    event_id: int,
    body: ExtensionApprovalAction,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin approve/reject a pending cancellation request."""
    event = await event_service.get_or_404(db, event_id)
    if not event.pending_cancellation:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="No pending cancellation for this event")
    if body.action == "approve":
        # Actually cancel the event
        reason = event.pending_cancellation.get("reason", "Admin-approved cancellation")
        event.pending_cancellation = None
        event.status = EventStatus.cancelled
        event.cancellation_reason = reason
        from app.services import funding as funding_service
        await funding_service.refund_all_pledges_for_event(db, event_id=event.id)
        await db.flush()
    elif body.action == "reject":
        event.pending_cancellation = None
        await db.flush()
    else:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="action must be 'approve' or 'reject'")
    event = await event_service.get_by_id(db, event.id, load_venue=True)
    return _event_to_response(event)


# ═══════════════════════════════════════════
# Event Discounts CRUD
# ═══════════════════════════════════════════


@router.get("/{event_id}/discounts/rules", response_model=list[EventDiscountResponse])
async def list_event_discounts(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List all discount rules for an event."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_read_event_mgmt(db, event, current_user):
        raise ForbiddenError("You cannot view discounts for this event")
    return await event_service.list_event_discounts(db, event_id=event_id)


@router.post("/{event_id}/discounts/rules", response_model=EventDiscountResponse)
async def create_event_discount(
    event_id: int,
    body: EventDiscountCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create a discount rule for the event."""
    return await event_service.create_event_discount(
        db, event_id=event_id, user=current_user,
        name=body.name, discount_type=body.discount_type,
        value=body.value, target=body.target,
    )


@router.delete("/{event_id}/discounts/rules/{discount_id}")
async def delete_event_discount(
    event_id: int,
    discount_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete a discount rule from the event."""
    await event_service.delete_event_discount(db, event_id=event_id, discount_id=discount_id, user=current_user)
    return {"ok": True}


@router.get("/{event_id}/my-discounts")
async def get_my_discounts(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Return discount rules applicable to the current user for this event."""
    return await event_service.compute_event_discounts_for_user(
        db, event_id=event_id, user_id=current_user.id,
    )


# ═══════════════════════════════════════════
# Organizer Customer History
# ═══════════════════════════════════════════


# ═══════════════════════════════════════════
# Discount Strategy ↔ Event links
# ═══════════════════════════════════════════


@router.get("/{event_id}/discount-strategies")
async def list_event_discount_strategies(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List discount strategies attached to an event (with auto_apply flag)."""
    return await ds_service.list_event_strategies(db, event_id=event_id)


class AttachDiscountBody(BaseModel):
    auto_apply: bool = True


@router.post("/{event_id}/discount-strategies/{strategy_id}")
async def attach_discount_strategy(
    event_id: int,
    strategy_id: int,
    db: DbSession,
    body: AttachDiscountBody | None = None,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Attach a discount strategy to an event. auto_apply=true → applied to all; false → customer must claim."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot modify this event")
    auto = body.auto_apply if body else True
    await ds_service.attach_to_event(
        db, event_id=event_id, strategy_id=strategy_id, user=current_user, auto_apply=auto,
    )
    return {"ok": True}


@router.delete("/{event_id}/discount-strategies/{strategy_id}")
async def detach_discount_strategy(
    event_id: int,
    strategy_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Detach a discount strategy from an event."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, current_user):
        raise ForbiddenError("You cannot modify this event")
    await ds_service.detach_from_event(db, event_id=event_id, strategy_id=strategy_id, user=current_user)
    return {"ok": True}


# ═══════════════════════════════════════════
# Customer Discount Claims
# ═══════════════════════════════════════════


@router.get("/{event_id}/claimable-discounts")
async def list_claimable_discounts(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Return non-auto-apply discounts the customer can claim for this event."""
    return await ds_service.list_claimable_discounts(
        db, event_id=event_id, user_id=current_user.id,
    )


@router.post("/{event_id}/claim-discount/{link_id}")
async def claim_discount(
    event_id: int,
    link_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Customer claims a non-auto-apply discount."""
    claim = await ds_service.claim_discount(db, link_id=link_id, user_id=current_user.id)
    return {"ok": True, "claim_id": claim.id}


@router.delete("/{event_id}/claim-discount/{link_id}")
async def unclaim_discount(
    event_id: int,
    link_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    """Customer removes a claimed discount."""
    await ds_service.unclaim_discount(db, link_id=link_id, user_id=current_user.id)
    return {"ok": True}
