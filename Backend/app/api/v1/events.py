"""
Events: CRUD, list (filters), pledge, register, registrations.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query

from app.dependencies import DbSession, require_role
from app.models.event import Event, RegistrationType
from app.models.user import User, UserRole
from app.schemas import (
    EventCreate,
    EventResponse,
    EventUpdate,
    FundingSummaryResponse,
    PledgeBody,
    PledgeResponse,
    RegistrationDecisionBody,
    RegistrationResponse,
)
from app.core.exceptions import ForbiddenError
from app.services import event as event_service
from app.services import funding as funding_service
from app.services import registration as registration_service

router = APIRouter()


def _parse_iso_datetime(v: str | None) -> datetime | None:
    if v is None:
        return None
    dt = datetime.fromisoformat(v.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _event_to_response(e: Event) -> EventResponse:
    return EventResponse(
        id=e.id,
        organizer_id=e.organizer_id,
        venue_id=e.venue_id,
        title=e.title,
        description=e.description,
        start_time=e.start_time,
        end_time=e.end_time,
        status=e.status.value,
        registration_type=e.registration_type.value,
        max_capacity=e.max_capacity,
        funding_goal_cents=e.funding_goal_cents,
        funding_end_at=e.funding_end_at,
        lat=e.lat,
        lng=e.lng,
        created_at=e.created_at,
        updated_at=e.updated_at,
    )


@router.get("", response_model=list[EventResponse])
async def list_events(
    db: DbSession,
    city: str | None = Query(None, description="e.g. Ottawa"),
    status: str | None = Query(None),
    live: bool | None = Query(None),
    registration_type: str | None = Query(None),
    organizer_id: int | None = Query(None),
):
    """List events with optional filters."""
    events = await event_service.list_events(
        db,
        city=city,
        status=status,
        live=live,
        registration_type=registration_type,
        organizer_id=organizer_id,
    )
    return [_event_to_response(e) for e in events]


@router.post("", response_model=EventResponse)
async def create_event(
    body: EventCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create event (organizer or admin). Organizer is set to current user."""
    start_time = _parse_iso_datetime(body.start_time)
    end_time = _parse_iso_datetime(body.end_time)
    funding_end_at = _parse_iso_datetime(body.funding_end_at)
    if not start_time or not end_time:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="start_time and end_time required as ISO datetime")
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
        registration_type=reg_type,
        max_capacity=body.max_capacity,
    )
    return _event_to_response(event)


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(event_id: int, db: DbSession):
    """Event detail (public)."""
    event = await event_service.get_or_404(db, event_id)
    return _event_to_response(event)


@router.patch("/{event_id}", response_model=EventResponse)
async def update_event(
    event_id: int,
    body: EventUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update event (owner or admin)."""
    event = await event_service.get_or_404(db, event_id)
    if not event_service._event_can_edit(current_user, event):
        raise ForbiddenError("You cannot update this event")
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
        funding_goal_cents=body.funding_goal_cents,
        funding_end_at=funding_end_at,
        registration_type=reg_type,
        max_capacity=body.max_capacity,
    )
    return _event_to_response(updated)


@router.delete("/{event_id}")
async def delete_event(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete (draft/pending) or cancel event (owner or admin)."""
    event = await event_service.get_or_404(db, event_id)
    await event_service.delete_or_cancel(db, event, current_user)
    return {"ok": True}


@router.post("/{event_id}/submit", response_model=EventResponse)
async def submit_event_for_approval(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Submit draft event for admin approval (draft → pending_approval). Organizer or admin only."""
    event = await event_service.submit_for_approval(db, event_id=event_id, user=current_user)
    return _event_to_response(event)


@router.post("/{event_id}/pledge")
async def pledge_event(
    event_id: int,
    body: PledgeBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer)),
):
    """Pledge to event (customer)."""
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
        created_at=pledge.created_at,
    )


@router.get("/{event_id}/funding")
async def get_event_funding(event_id: int, db: DbSession):
    """Funding summary for event (public or organizer/admin)."""
    summary = await funding_service.get_summary(db, event_id=event_id)
    return FundingSummaryResponse(**summary)


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


@router.get("/{event_id}/registrations")
async def list_registrations(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """List registrations for event (organizer/admin)."""
    event = await event_service.get_or_404(db, event_id)
    if current_user.role != UserRole.admin and event.organizer_id != current_user.id:
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
    if current_user.role != UserRole.admin and event.organizer_id != current_user.id:
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
