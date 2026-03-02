"""
Service-level tests for registration.py.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventStatus, RegistrationType
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User, UserRole
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError

from app.services import registration as reg_svc


# ===========================================================================
# register
# ===========================================================================

@pytest.mark.asyncio
async def test_register_open_event(db_session, test_event_approved, test_users):
    """Register for open event."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        reg = await reg_svc.register(
            db_session,
            event_id=test_event_approved.id,
            user=customer,
        )
    assert reg.status == RegistrationStatus.registered


@pytest.mark.asyncio
async def test_register_cancelled_event(db_session, test_event, test_users):
    """Cannot register for cancelled event."""
    customer = test_users["customer"]
    test_event.status = EventStatus.cancelled
    await db_session.flush()
    with pytest.raises(ConflictError, match="cancelled"):
        await reg_svc.register(db_session, event_id=test_event.id, user=customer)


@pytest.mark.asyncio
async def test_register_completed_event(db_session, test_event, test_users):
    """Cannot register for completed event."""
    customer = test_users["customer"]
    test_event.status = EventStatus.completed
    await db_session.flush()
    with pytest.raises(ConflictError, match="ended"):
        await reg_svc.register(db_session, event_id=test_event.id, user=customer)


@pytest.mark.asyncio
async def test_register_already_registered(db_session, test_event_approved, test_registration, test_users):
    """Cannot register twice."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="Already"):
            await reg_svc.register(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
            )


@pytest.mark.asyncio
async def test_register_closed_event_waitlist(db_session, test_event_approved, test_users):
    """Closed event puts user on waitlist."""
    customer = test_users["customer"]
    test_event_approved.registration_type = RegistrationType.closed
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        reg = await reg_svc.register(
            db_session,
            event_id=test_event_approved.id,
            user=customer,
        )
    assert reg.status == RegistrationStatus.waitlist


@pytest.mark.asyncio
async def test_register_full_capacity_waitlist(db_session, test_event_approved, test_users):
    """Full event puts user on waitlist."""
    customer = test_users["customer"]
    test_event_approved.max_capacity = 0  # full
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        reg = await reg_svc.register(
            db_session,
            event_id=test_event_approved.id,
            user=customer,
        )
    assert reg.status == RegistrationStatus.waitlist


# ===========================================================================
# list_registrations
# ===========================================================================

@pytest.mark.asyncio
async def test_list_registrations(db_session, test_event_approved, test_registration):
    """List registrations for event."""
    result = await reg_svc.list_registrations(
        db_session, event_id=test_event_approved.id
    )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_registrations_empty(db_session, test_event_approved):
    """List registrations for event with none."""
    result = await reg_svc.list_registrations(
        db_session, event_id=test_event_approved.id
    )
    assert len(result) == 0


# ===========================================================================
# get_registration_or_404
# ===========================================================================

@pytest.mark.asyncio
async def test_get_registration_or_404(db_session, test_event_approved, test_registration):
    """Get registration by ID."""
    result = await reg_svc.get_registration_or_404(
        db_session,
        event_id=test_event_approved.id,
        registration_id=test_registration.id,
    )
    assert result.id == test_registration.id


@pytest.mark.asyncio
async def test_get_registration_not_found(db_session, test_event_approved):
    """Get non-existent registration."""
    with pytest.raises(NotFoundError, match="Registration"):
        await reg_svc.get_registration_or_404(
            db_session,
            event_id=test_event_approved.id,
            registration_id=99999,
        )


# ===========================================================================
# approve_waitlist, reject_waitlist
# ===========================================================================

@pytest.mark.asyncio
async def test_approve_waitlist(db_session, test_event_approved, test_users):
    """Approve waitlisted registration."""
    customer = test_users["customer"]
    reg = Registration(
        event_id=test_event_approved.id,
        user_id=customer.id,
        status=RegistrationStatus.waitlist,
    )
    db_session.add(reg)
    await db_session.flush()
    result = await reg_svc.approve_waitlist(
        db_session,
        event_id=test_event_approved.id,
        registration_id=reg.id,
    )
    assert result.status == RegistrationStatus.registered


@pytest.mark.asyncio
async def test_approve_waitlist_not_waitlisted(db_session, test_event_approved, test_registration):
    """Cannot approve non-waitlisted registration."""
    with pytest.raises(ConflictError, match="waitlist"):
        await reg_svc.approve_waitlist(
            db_session,
            event_id=test_event_approved.id,
            registration_id=test_registration.id,
        )


@pytest.mark.asyncio
async def test_reject_waitlist(db_session, test_event_approved, test_users):
    """Reject waitlisted registration."""
    customer = test_users["customer"]
    reg = Registration(
        event_id=test_event_approved.id,
        user_id=customer.id,
        status=RegistrationStatus.waitlist,
    )
    db_session.add(reg)
    await db_session.flush()
    result = await reg_svc.reject_waitlist(
        db_session,
        event_id=test_event_approved.id,
        registration_id=reg.id,
    )
    assert result.status == RegistrationStatus.cancelled


@pytest.mark.asyncio
async def test_reject_waitlist_not_waitlisted(db_session, test_event_approved, test_registration):
    """Cannot reject non-waitlisted registration."""
    with pytest.raises(ConflictError, match="waitlist"):
        await reg_svc.reject_waitlist(
            db_session,
            event_id=test_event_approved.id,
            registration_id=test_registration.id,
        )


# ===========================================================================
# unregister
# ===========================================================================

@pytest.mark.asyncio
async def test_unregister(db_session, test_event_approved, test_registration, test_users):
    """Customer unregisters."""
    customer = test_users["customer"]
    result = await reg_svc.unregister(
        db_session,
        event_id=test_event_approved.id,
        user=customer,
    )
    assert "refunded_cents" in result
    assert "refund_eligible" in result


@pytest.mark.asyncio
async def test_unregister_cancelled_event(db_session, test_event, test_users):
    """Cannot unregister from cancelled event."""
    customer = test_users["customer"]
    test_event.status = EventStatus.cancelled
    await db_session.flush()
    with pytest.raises(ConflictError, match="cancelled"):
        await reg_svc.unregister(db_session, event_id=test_event.id, user=customer)


@pytest.mark.asyncio
async def test_unregister_not_registered(db_session, test_event_approved, test_users):
    """Cannot unregister if not registered."""
    organizer = test_users["organizer"]
    with pytest.raises(NotFoundError):
        await reg_svc.unregister(
            db_session,
            event_id=test_event_approved.id,
            user=organizer,
        )


# ===========================================================================
# auto_approve_waitlist_when_switching_to_open
# ===========================================================================

@pytest.mark.asyncio
async def test_auto_approve_waitlist(db_session, test_event_approved, test_users):
    """Auto-approve waitlist entries when switching to open."""
    customer = test_users["customer"]
    reg = Registration(
        event_id=test_event_approved.id,
        user_id=customer.id,
        status=RegistrationStatus.waitlist,
    )
    db_session.add(reg)
    await db_session.flush()
    count = await reg_svc.auto_approve_waitlist_when_switching_to_open(
        db_session,
        event_id=test_event_approved.id,
        event_max_capacity=50,
    )
    assert count >= 1


@pytest.mark.asyncio
async def test_auto_approve_waitlist_no_slots(db_session, test_event_approved, test_users):
    """No waitlist approved when capacity is 0."""
    count = await reg_svc.auto_approve_waitlist_when_switching_to_open(
        db_session,
        event_id=test_event_approved.id,
        event_max_capacity=0,
    )
    assert count == 0
