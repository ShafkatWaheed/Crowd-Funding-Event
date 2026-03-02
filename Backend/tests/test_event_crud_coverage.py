"""
Service-level tests for event/crud.py, event/lifecycle.py, event/organizers.py, event/discounts.py.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventStatus, EventOrganizer, EventDiscount, RegistrationType
from app.models.ticket import TicketTier, TicketSale, TicketSaleStatus
from app.models.funding import Funding, FundingStatus
from app.models.user import User, UserRole
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError

from app.services.event import (
    crud as event_crud,
    lifecycle as event_lifecycle,
    organizers as event_organizers,
    discounts as event_discounts,
)


# ===========================================================================
# CRUD: get_by_id, get_or_404, publish_event
# ===========================================================================

@pytest.mark.asyncio
async def test_get_by_id_returns_none(db_session, test_users):
    """get_by_id returns None for non-existent event."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await event_crud.get_by_id(db_session, 99999)
    assert result is None


@pytest.mark.asyncio
async def test_get_by_id_with_venue(db_session, test_event_approved):
    """get_by_id loads venue when requested."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await event_crud.get_by_id(db_session, test_event_approved.id, load_venue=True)
    assert result is not None
    assert result.id == test_event_approved.id


@pytest.mark.asyncio
async def test_get_by_id_with_organizer(db_session, test_event_approved):
    """get_by_id loads organizer when requested."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await event_crud.get_by_id(db_session, test_event_approved.id, load_organizer=True)
    assert result is not None


@pytest.mark.asyncio
async def test_get_or_404_success(db_session, test_event_approved):
    """get_or_404 returns event."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await event_crud.get_or_404(db_session, test_event_approved.id)
    assert result.id == test_event_approved.id


@pytest.mark.asyncio
async def test_get_or_404_not_found(db_session, test_users):
    """get_or_404 raises NotFoundError."""
    with pytest.raises(NotFoundError):
        await event_crud.get_or_404(db_session, 99999)


@pytest.mark.asyncio
async def test_publish_event_success(db_session, test_event, test_users, test_organizer_bank):
    """Publish draft event (has funding goal + funding deadline)."""
    organizer = test_users["organizer"]
    # test_event is draft and has funding_goal_cents + funding_end_at — publishable
    result = await event_crud.publish_event(db_session, test_event.id, organizer)
    assert result.status == EventStatus.approved


@pytest.mark.asyncio
async def test_publish_event_not_draft(db_session, test_event_approved, test_users):
    """Cannot publish non-draft event."""
    organizer = test_users["organizer"]
    with pytest.raises(ConflictError, match="draft"):
        await event_crud.publish_event(db_session, test_event_approved.id, organizer)


@pytest.mark.asyncio
async def test_publish_event_forbidden(db_session, test_event, test_users):
    """Customer cannot publish event."""
    customer = test_users["customer"]
    with pytest.raises(ForbiddenError):
        await event_crud.publish_event(db_session, test_event.id, customer)


# ===========================================================================
# CRUD: list_events
# ===========================================================================

@pytest.mark.asyncio
async def test_list_events_basic(db_session, test_event_approved):
    """List events returns approved events."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        events, cursor = await event_crud.list_events(db_session)
    assert len(events) >= 1


@pytest.mark.asyncio
async def test_list_events_search(db_session, test_event_approved):
    """List events with search filter."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        events, _ = await event_crud.list_events(db_session, search="Test")
    assert len(events) >= 1


@pytest.mark.asyncio
async def test_list_events_city_filter(db_session, test_event_approved):
    """List events with city filter."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        events, _ = await event_crud.list_events(db_session, city="Ottawa")
    assert len(events) >= 1


@pytest.mark.asyncio
async def test_list_events_invalid_status(db_session, test_event_approved):
    """List events with invalid status returns empty."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        events, _ = await event_crud.list_events(db_session, status="nonexistent")
    assert events == []


@pytest.mark.asyncio
async def test_list_events_with_organizer_id(db_session, test_event, test_users):
    """List events scoped to organizer includes all statuses."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        events, _ = await event_crud.list_events(db_session, organizer_id=organizer.id)
    assert len(events) >= 1


@pytest.mark.asyncio
async def test_list_events_with_limit(db_session, test_event_approved):
    """List events with limit."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        events, cursor = await event_crud.list_events(db_session, limit=1)
    assert len(events) <= 1


# ===========================================================================
# CRUD: create, update
# ===========================================================================

@pytest.mark.asyncio
async def test_create_event_minimal(db_session, test_users, test_venue):
    """Create event with minimal fields."""
    organizer = test_users["organizer"]
    start = datetime.now(timezone.utc) + timedelta(days=30)
    end = start + timedelta(hours=3)
    funding_end = start - timedelta(days=1)
    event = await event_crud.create(
        db_session,
        organizer_id=organizer.id,
        venue_id=test_venue.id,
        title="New Event",
        description="Test",
        start_time=start,
        end_time=end,
        funding_goal_cents=5000,
        funding_end_at=funding_end,
        min_pledge_cents=500,
        registration_type="open",
        max_capacity=50,
    )
    assert event.id is not None
    assert event.title == "New Event"
    assert event.status == EventStatus.draft


@pytest.mark.asyncio
async def test_create_event_end_before_start(db_session, test_users, test_venue):
    """Create event with end before start fails."""
    organizer = test_users["organizer"]
    start = datetime.now(timezone.utc) + timedelta(days=30)
    end = start - timedelta(hours=1)
    with pytest.raises(ConflictError, match="end_time"):
        await event_crud.create(
            db_session,
            organizer_id=organizer.id,
            venue_id=test_venue.id,
            title="Bad Event",
            description="Test",
            start_time=start,
            end_time=end,
            funding_goal_cents=5000,
            funding_end_at=start - timedelta(days=1),
            min_pledge_cents=500,
            registration_type="open",
            max_capacity=50,
        )


@pytest.mark.asyncio
async def test_create_event_start_before_funding_end(db_session, test_users, test_venue):
    """Create event with start before funding deadline fails."""
    organizer = test_users["organizer"]
    funding_end = datetime.now(timezone.utc) + timedelta(days=60)
    start = funding_end - timedelta(days=1)
    end = start + timedelta(hours=3)
    with pytest.raises(ConflictError, match="funding"):
        await event_crud.create(
            db_session,
            organizer_id=organizer.id,
            venue_id=test_venue.id,
            title="Bad Event",
            description="Test",
            start_time=start,
            end_time=end,
            funding_goal_cents=5000,
            funding_end_at=funding_end,
            min_pledge_cents=500,
            registration_type="open",
            max_capacity=50,
        )


@pytest.mark.asyncio
async def test_create_event_venue_not_found(db_session, test_users):
    """Create event with bad venue fails."""
    organizer = test_users["organizer"]
    start = datetime.now(timezone.utc) + timedelta(days=30)
    with pytest.raises(NotFoundError, match="Venue"):
        await event_crud.create(
            db_session,
            organizer_id=organizer.id,
            venue_id=99999,
            title="Bad Event",
            description="Test",
            start_time=start,
            end_time=start + timedelta(hours=3),
            funding_goal_cents=5000,
            funding_end_at=start - timedelta(days=1),
            min_pledge_cents=500,
            registration_type="open",
            max_capacity=50,
        )


@pytest.mark.asyncio
async def test_update_event_title(db_session, test_event, test_users, test_venue):
    """Update event title."""
    result = await event_crud.update(db_session, test_event, title="New Title")
    assert result.title == "New Title"


@pytest.mark.asyncio
async def test_update_event_capacity_below_sold(db_session, test_event_approved, test_ticket_sale, test_users):
    """Cannot reduce capacity below sold + reserved."""
    with pytest.raises(ConflictError, match="capacity"):
        await event_crud.update(db_session, test_event_approved, max_capacity=0)


@pytest.mark.asyncio
async def test_update_event_end_before_start(db_session, test_event, test_users, test_venue):
    """Update end_time before start_time fails."""
    bad_end = test_event.start_time - timedelta(hours=1)
    with pytest.raises(ConflictError, match="end_time"):
        await event_crud.update(db_session, test_event, end_time=bad_end)


# ===========================================================================
# CRUD: get_effective_policy
# ===========================================================================

@pytest.mark.asyncio
async def test_get_effective_policy(db_session, test_event_approved):
    """get_effective_policy returns policy dict."""
    policy = await event_crud.get_effective_policy(db_session, test_event_approved)
    assert "waitlist_max_size" in policy
    assert "max_co_organizers" in policy


# ===========================================================================
# LIFECYCLE: cancel_event
# ===========================================================================

@pytest.mark.asyncio
async def test_cancel_event_draft(db_session, test_event, test_users):
    """Cancel draft event (no pledges/sponsors/tickets, so refund calls are safe)."""
    organizer = test_users["organizer"]
    result = await event_lifecycle.cancel_event(db_session, test_event, organizer)
    assert result.status == EventStatus.cancelled


@pytest.mark.asyncio
async def test_cancel_event_already_cancelled(db_session, test_event, test_users):
    """Cannot cancel already cancelled event."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.cancelled
    await db_session.flush()
    with pytest.raises(ConflictError, match="already cancelled"):
        await event_lifecycle.cancel_event(db_session, test_event, organizer)


@pytest.mark.asyncio
async def test_cancel_event_completed(db_session, test_event, test_users):
    """Cannot cancel completed event."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.completed
    await db_session.flush()
    with pytest.raises(ConflictError, match="completed"):
        await event_lifecycle.cancel_event(db_session, test_event, organizer)


@pytest.mark.asyncio
async def test_cancel_event_forbidden(db_session, test_event, test_users):
    """Customer cannot cancel event."""
    customer = test_users["customer"]
    with pytest.raises(ForbiddenError):
        await event_lifecycle.cancel_event(db_session, test_event, customer)


@pytest.mark.asyncio
async def test_cancel_event_selling_tickets_non_admin(db_session, test_event, test_users):
    """Non-admin cannot cancel selling_tickets event directly."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.selling_tickets
    await db_session.flush()
    with pytest.raises(ConflictError, match="admin"):
        await event_lifecycle.cancel_event(db_session, test_event, organizer)


@pytest.mark.asyncio
async def test_cancel_event_admin_bypasses_threshold(db_session, test_event_approved, test_pledge, test_users):
    """Admin can cancel even with high funding percentage."""
    admin = test_users["admin"]
    # Admin bypasses threshold check; refund functions run against real DB (pledge exists but no gateway needed for refund_all)
    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        result = await event_lifecycle.cancel_event(db_session, test_event_approved, admin)
    assert result.status == EventStatus.cancelled


# ===========================================================================
# LIFECYCLE: reactivate_event
# ===========================================================================

@pytest.mark.asyncio
async def test_reactivate_event(db_session, test_event, test_users):
    """Reactivate cancelled event to draft."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.cancelled
    await db_session.flush()
    result = await event_lifecycle.reactivate_event(db_session, test_event, organizer)
    assert result.status == EventStatus.draft


@pytest.mark.asyncio
async def test_reactivate_event_not_cancelled(db_session, test_event, test_users):
    """Cannot reactivate non-cancelled event."""
    organizer = test_users["organizer"]
    with pytest.raises(ConflictError, match="cancelled"):
        await event_lifecycle.reactivate_event(db_session, test_event, organizer)


@pytest.mark.asyncio
async def test_reactivate_event_forbidden(db_session, test_event, test_users):
    """Customer cannot reactivate event."""
    customer = test_users["customer"]
    test_event.status = EventStatus.cancelled
    await db_session.flush()
    with pytest.raises(ForbiddenError):
        await event_lifecycle.reactivate_event(db_session, test_event, customer)


# ===========================================================================
# LIFECYCLE: extend_funding
# ===========================================================================

@pytest.mark.asyncio
async def test_extend_funding_admin(db_session, test_event_approved, test_users):
    """Admin extends funding directly."""
    admin = test_users["admin"]
    new_end = datetime.now(timezone.utc) + timedelta(days=90)
    result = await event_lifecycle.extend_funding(
        db_session, test_event_approved, admin,
        new_funding_end_at=new_end,
    )
    assert result.funding_end_at is not None


@pytest.mark.asyncio
async def test_extend_funding_organizer_pending(db_session, test_event_approved, test_users):
    """Organizer extension goes to pending."""
    organizer = test_users["organizer"]
    new_end = datetime.now(timezone.utc) + timedelta(days=90)
    result = await event_lifecycle.extend_funding(
        db_session, test_event_approved, organizer,
        new_funding_end_at=new_end,
    )
    assert result.pending_extension is not None


@pytest.mark.asyncio
async def test_extend_funding_cancelled(db_session, test_event, test_users):
    """Cannot extend cancelled event."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.cancelled
    await db_session.flush()
    with pytest.raises(ConflictError, match="cancelled"):
        await event_lifecycle.extend_funding(
            db_session, test_event, organizer,
            new_funding_end_at=datetime.now(timezone.utc) + timedelta(days=30),
        )


@pytest.mark.asyncio
async def test_extend_funding_no_params(db_session, test_event_approved, test_users):
    """Must provide at least one param."""
    admin = test_users["admin"]
    with pytest.raises(ConflictError, match="At least one"):
        await event_lifecycle.extend_funding(db_session, test_event_approved, admin)


@pytest.mark.asyncio
async def test_extend_funding_negative_goal(db_session, test_event_approved, test_users):
    """Negative funding goal fails."""
    admin = test_users["admin"]
    with pytest.raises(ConflictError, match="positive"):
        await event_lifecycle.extend_funding(
            db_session, test_event_approved, admin,
            new_funding_goal_cents=-100,
        )


# ===========================================================================
# LIFECYCLE: set_event_date
# ===========================================================================

@pytest.mark.asyncio
async def test_set_event_date(db_session, test_event, test_users):
    """Set event dates."""
    organizer = test_users["organizer"]
    start = datetime.now(timezone.utc) + timedelta(days=60)
    end = start + timedelta(hours=3)
    result = await event_lifecycle.set_event_date(
        db_session, test_event, organizer,
        new_start_time=start, new_end_time=end,
    )
    assert result.start_time == start
    assert result.end_time == end


@pytest.mark.asyncio
async def test_set_event_date_end_before_start(db_session, test_event, test_users):
    """end_time must be after start_time."""
    organizer = test_users["organizer"]
    start = datetime.now(timezone.utc) + timedelta(days=60)
    end = start - timedelta(hours=1)
    with pytest.raises(ConflictError, match="end_time"):
        await event_lifecycle.set_event_date(
            db_session, test_event, organizer,
            new_start_time=start, new_end_time=end,
        )


@pytest.mark.asyncio
async def test_set_event_date_before_funding(db_session, test_event, test_users):
    """start_time must be after funding deadline."""
    organizer = test_users["organizer"]
    # Set start before funding_end_at
    start = test_event.funding_end_at - timedelta(days=5)
    end = start + timedelta(hours=3)
    with pytest.raises(ConflictError, match="funding deadline"):
        await event_lifecycle.set_event_date(
            db_session, test_event, organizer,
            new_start_time=start, new_end_time=end,
        )


@pytest.mark.asyncio
async def test_set_event_date_cancelled(db_session, test_event, test_users):
    """Cannot set date on cancelled event."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.cancelled
    await db_session.flush()
    start = datetime.now(timezone.utc) + timedelta(days=60)
    with pytest.raises(ConflictError, match="cancelled"):
        await event_lifecycle.set_event_date(
            db_session, test_event, organizer,
            new_start_time=start, new_end_time=start + timedelta(hours=3),
        )


# ===========================================================================
# LIFECYCLE: start_selling_tickets
# ===========================================================================

@pytest.mark.asyncio
async def test_start_selling_wrong_status(db_session, test_event, test_users):
    """Cannot start selling from draft status."""
    organizer = test_users["organizer"]
    with pytest.raises(ConflictError, match="Cannot start selling"):
        await event_lifecycle.start_selling_tickets(db_session, test_event, organizer)


@pytest.mark.asyncio
async def test_start_selling_no_dates(db_session, test_event, test_users):
    """Cannot start selling without dates set."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.waiting_event_date
    test_event.start_time = None
    await db_session.flush()
    with pytest.raises(ConflictError, match="start and end times"):
        await event_lifecycle.start_selling_tickets(db_session, test_event, organizer)


@pytest.mark.asyncio
async def test_start_selling_no_strategy(db_session, test_event, test_users):
    """Cannot start selling without ticket strategy."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.waiting_event_date
    test_event.ticket_strategy_id = None
    await db_session.flush()
    with pytest.raises(ConflictError, match="ticket strategy"):
        await event_lifecycle.start_selling_tickets(db_session, test_event, organizer)


@pytest.mark.asyncio
async def test_start_selling_success(db_session, test_event, test_ticket_strategy, test_ticket_tier, test_users):
    """Successfully start selling tickets from waiting_event_date."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.waiting_event_date
    test_event.ticket_strategy_id = test_ticket_strategy.id
    # test_event already has start_time and end_time from fixture
    await db_session.flush()
    # Need a tier for this event
    tier = TicketTier(
        event_id=test_event.id,
        name="VIP",
        price_cents=5000,
        display_order=0,
    )
    db_session.add(tier)
    await db_session.flush()
    result = await event_lifecycle.start_selling_tickets(db_session, test_event, organizer)
    assert result.status == EventStatus.selling_tickets
    assert result.ticket_selling_started_at is not None


# ===========================================================================
# LIFECYCLE: approve_extension, reject_extension
# ===========================================================================

@pytest.mark.asyncio
async def test_approve_extension(db_session, test_event_approved, test_users):
    """Admin approves pending extension."""
    admin = test_users["admin"]
    organizer = test_users["organizer"]
    new_end = datetime.now(timezone.utc) + timedelta(days=90)
    # Create pending extension first
    await event_lifecycle.extend_funding(
        db_session, test_event_approved, organizer,
        new_funding_end_at=new_end,
    )
    result = await event_lifecycle.approve_extension(db_session, test_event_approved, admin)
    assert result.pending_extension is None


@pytest.mark.asyncio
async def test_approve_extension_not_admin(db_session, test_event_approved, test_users):
    """Non-admin cannot approve extension."""
    organizer = test_users["organizer"]
    test_event_approved.pending_extension = {"funding_end_at": "2026-12-01T00:00:00+00:00"}
    await db_session.flush()
    with pytest.raises(ForbiddenError, match="admin"):
        await event_lifecycle.approve_extension(db_session, test_event_approved, organizer)


@pytest.mark.asyncio
async def test_approve_extension_no_pending(db_session, test_event_approved, test_users):
    """No pending extension to approve."""
    admin = test_users["admin"]
    test_event_approved.pending_extension = None
    await db_session.flush()
    with pytest.raises(ConflictError, match="No pending"):
        await event_lifecycle.approve_extension(db_session, test_event_approved, admin)


@pytest.mark.asyncio
async def test_reject_extension(db_session, test_event_approved, test_users):
    """Admin rejects pending extension."""
    admin = test_users["admin"]
    test_event_approved.pending_extension = {"funding_end_at": "2026-12-01T00:00:00+00:00"}
    await db_session.flush()
    result = await event_lifecycle.reject_extension(db_session, test_event_approved, admin)
    assert result.pending_extension is None


@pytest.mark.asyncio
async def test_reject_extension_not_admin(db_session, test_event_approved, test_users):
    """Non-admin cannot reject extension."""
    organizer = test_users["organizer"]
    test_event_approved.pending_extension = {"funding_end_at": "2026-12-01T00:00:00+00:00"}
    await db_session.flush()
    with pytest.raises(ForbiddenError, match="admin"):
        await event_lifecycle.reject_extension(db_session, test_event_approved, organizer)


# ===========================================================================
# LIFECYCLE: delete_or_cancel
# ===========================================================================

@pytest.mark.asyncio
async def test_delete_draft_event(db_session, test_event, test_users):
    """Draft event is hard-deleted."""
    organizer = test_users["organizer"]
    event_id = test_event.id
    await event_lifecycle.delete_or_cancel(db_session, test_event, organizer)
    from sqlalchemy import select
    result = (await db_session.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    assert result is None


@pytest.mark.asyncio
async def test_delete_completed_event(db_session, test_event, test_users):
    """Cannot delete completed event."""
    organizer = test_users["organizer"]
    test_event.status = EventStatus.completed
    await db_session.flush()
    with pytest.raises(ConflictError, match="completed"):
        await event_lifecycle.delete_or_cancel(db_session, test_event, organizer)


@pytest.mark.asyncio
async def test_delete_approved_event_low_funding(db_session, test_event_approved, test_users):
    """Approved event with low funding gets soft-cancelled."""
    organizer = test_users["organizer"]
    # No pledges, so threshold check passes and refund is a no-op
    await event_lifecycle.delete_or_cancel(db_session, test_event_approved, organizer)
    assert test_event_approved.status == EventStatus.cancelled


@pytest.mark.asyncio
async def test_delete_event_forbidden(db_session, test_event, test_users):
    """Customer cannot delete event."""
    customer = test_users["customer"]
    with pytest.raises(ForbiddenError):
        await event_lifecycle.delete_or_cancel(db_session, test_event, customer)


# ===========================================================================
# ORGANIZERS: list, add, update, respond, remove
# ===========================================================================

@pytest.mark.asyncio
async def test_list_event_organizers(db_session, test_event_approved, test_users):
    """List organizers returns main + co-organizers."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        main, co_orgs = await event_organizers.list_event_organizers(db_session, event_id=test_event_approved.id)
    assert main.id == test_users["organizer"].id
    assert isinstance(co_orgs, list)


@pytest.mark.asyncio
async def test_list_event_organizers_not_found(db_session, test_users):
    """List organizers for non-existent event raises NotFoundError."""
    with pytest.raises(NotFoundError):
        await event_organizers.list_event_organizers(db_session, event_id=99999)


@pytest.mark.asyncio
async def test_add_co_organizer(db_session, test_event_approved, test_users):
    """Add co-organizer to event."""
    organizer = test_users["organizer"]
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        eo = await event_organizers.add_event_organizer(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer2.id,
            added_by=organizer,
            permission="full",
        )
    assert eo.user_id == organizer2.id
    assert eo.invitation_status == "pending"


@pytest.mark.asyncio
async def test_add_co_organizer_not_main(db_session, test_event_approved, test_users):
    """Only main organizer can add co-organizers."""
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ForbiddenError, match="main organizer"):
            await event_organizers.add_event_organizer(
                db_session,
                event_id=test_event_approved.id,
                user_id=organizer2.id,
                added_by=organizer2,
                permission="read",
            )


@pytest.mark.asyncio
async def test_add_co_organizer_self(db_session, test_event_approved, test_users):
    """Cannot add main organizer as co-organizer."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="already the main organizer"):
            await event_organizers.add_event_organizer(
                db_session,
                event_id=test_event_approved.id,
                user_id=organizer.id,
                added_by=organizer,
            )


@pytest.mark.asyncio
async def test_add_co_organizer_bad_permission(db_session, test_event_approved, test_users):
    """Invalid permission string."""
    organizer = test_users["organizer"]
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="Permission"):
            await event_organizers.add_event_organizer(
                db_session,
                event_id=test_event_approved.id,
                user_id=organizer2.id,
                added_by=organizer,
                permission="admin",
            )


@pytest.mark.asyncio
async def test_add_co_organizer_not_organizer_role(db_session, test_event_approved, test_users):
    """Cannot add customer as co-organizer."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="organizer role"):
            await event_organizers.add_event_organizer(
                db_session,
                event_id=test_event_approved.id,
                user_id=customer.id,
                added_by=organizer,
            )


@pytest.mark.asyncio
async def test_respond_to_invitation_accept(db_session, test_event_approved, test_users):
    """Co-organizer accepts invitation."""
    organizer = test_users["organizer"]
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await event_organizers.add_event_organizer(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer2.id,
            added_by=organizer,
        )
        eo = await event_organizers.respond_to_invitation(
            db_session,
            event_id=test_event_approved.id,
            user=organizer2,
            accept=True,
        )
    assert eo.invitation_status == "accepted"


@pytest.mark.asyncio
async def test_respond_to_invitation_decline(db_session, test_event_approved, test_users):
    """Co-organizer declines invitation."""
    organizer = test_users["organizer"]
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await event_organizers.add_event_organizer(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer2.id,
            added_by=organizer,
        )
        eo = await event_organizers.respond_to_invitation(
            db_session,
            event_id=test_event_approved.id,
            user=organizer2,
            accept=False,
        )
    assert eo.invitation_status == "declined"


@pytest.mark.asyncio
async def test_respond_no_invitation(db_session, test_event_approved, test_users):
    """Cannot respond without invitation."""
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises((NotFoundError, TypeError)):
            await event_organizers.respond_to_invitation(
                db_session,
                event_id=test_event_approved.id,
                user=organizer2,
                accept=True,
            )


@pytest.mark.asyncio
async def test_update_co_organizer_permission(db_session, test_event_approved, test_users):
    """Update co-organizer permission."""
    organizer = test_users["organizer"]
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await event_organizers.add_event_organizer(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer2.id,
            added_by=organizer,
        )
        eo = await event_organizers.update_event_organizer_permission(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer2.id,
            updated_by=organizer,
            permission="full",
        )
    assert eo.permission == "full"


@pytest.mark.asyncio
async def test_update_permission_main_organizer(db_session, test_event_approved, test_users):
    """Cannot update main organizer's permission."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="main organizer"):
            await event_organizers.update_event_organizer_permission(
                db_session,
                event_id=test_event_approved.id,
                user_id=organizer.id,
                updated_by=organizer,
                permission="read",
            )


@pytest.mark.asyncio
async def test_self_remove_from_event(db_session, test_event_approved, test_users):
    """Co-organizer self-removes."""
    organizer = test_users["organizer"]
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await event_organizers.add_event_organizer(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer2.id,
            added_by=organizer,
        )
        await event_organizers.self_remove_from_event(
            db_session,
            event_id=test_event_approved.id,
            user=organizer2,
        )


@pytest.mark.asyncio
async def test_self_remove_main_organizer(db_session, test_event_approved, test_users):
    """Main organizer cannot self-remove."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="Main organizer"):
            await event_organizers.self_remove_from_event(
                db_session,
                event_id=test_event_approved.id,
                user=organizer,
            )


@pytest.mark.asyncio
async def test_remove_event_organizer(db_session, test_event_approved, test_users):
    """Main organizer removes co-organizer."""
    organizer = test_users["organizer"]
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await event_organizers.add_event_organizer(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer2.id,
            added_by=organizer,
        )
        await event_organizers.remove_event_organizer(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer2.id,
            removed_by=organizer,
        )


@pytest.mark.asyncio
async def test_remove_main_organizer(db_session, test_event_approved, test_users):
    """Cannot remove main organizer."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="main organizer"):
            await event_organizers.remove_event_organizer(
                db_session,
                event_id=test_event_approved.id,
                user_id=organizer.id,
                removed_by=organizer,
            )


@pytest.mark.asyncio
async def test_remove_nonexistent_co_organizer(db_session, test_event_approved, test_users):
    """Cannot remove non-existent co-organizer."""
    organizer = test_users["organizer"]
    organizer2 = test_users["organizer2"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(NotFoundError, match="Co-organizer"):
            await event_organizers.remove_event_organizer(
                db_session,
                event_id=test_event_approved.id,
                user_id=organizer2.id,
                removed_by=organizer,
            )


# ===========================================================================
# DISCOUNTS: list, create, delete, compute
# ===========================================================================

@pytest.mark.asyncio
async def test_list_event_discounts_empty(db_session, test_event_approved):
    """List discounts for event with none."""
    result = await event_discounts.list_event_discounts(db_session, event_id=test_event_approved.id)
    assert result == []


@pytest.mark.asyncio
async def test_create_event_discount(db_session, test_event_approved, test_users):
    """Create ticket_percent discount."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        disc = await event_discounts.create_event_discount(
            db_session,
            event_id=test_event_approved.id,
            user=organizer,
            name="10% Off",
            discount_type="ticket_percent",
            value=10,
            target="all",
        )
    assert disc.name == "10% Off"
    assert disc.value == 10


@pytest.mark.asyncio
async def test_create_event_discount_pledge_percent(db_session, test_event_approved, test_users):
    """Create pledge_percent discount."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        disc = await event_discounts.create_event_discount(
            db_session,
            event_id=test_event_approved.id,
            user=organizer,
            name="Pledge Disc",
            discount_type="pledge_percent",
            value=20,
            target="pledgers",
        )
    assert disc.discount_type == "pledge_percent"


@pytest.mark.asyncio
async def test_create_discount_bad_type(db_session, test_event_approved, test_users):
    """Invalid discount type fails."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="discount_type"):
            await event_discounts.create_event_discount(
                db_session,
                event_id=test_event_approved.id,
                user=organizer,
                name="Bad",
                discount_type="invalid",
                value=10,
            )


@pytest.mark.asyncio
async def test_create_discount_bad_target(db_session, test_event_approved, test_users):
    """Invalid target fails."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="target"):
            await event_discounts.create_event_discount(
                db_session,
                event_id=test_event_approved.id,
                user=organizer,
                name="Bad",
                discount_type="ticket_percent",
                value=10,
                target="vips",
            )


@pytest.mark.asyncio
async def test_create_discount_pledge_non_pledgers(db_session, test_event_approved, test_users):
    """pledge_percent + non_pledgers fails."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="non-pledgers"):
            await event_discounts.create_event_discount(
                db_session,
                event_id=test_event_approved.id,
                user=organizer,
                name="Bad",
                discount_type="pledge_percent",
                value=10,
                target="non_pledgers",
            )


@pytest.mark.asyncio
async def test_create_discount_value_zero(db_session, test_event_approved, test_users):
    """Value 0 fails."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="1-100"):
            await event_discounts.create_event_discount(
                db_session,
                event_id=test_event_approved.id,
                user=organizer,
                name="Bad",
                discount_type="ticket_percent",
                value=0,
            )


@pytest.mark.asyncio
async def test_create_discount_value_over_100(db_session, test_event_approved, test_users):
    """Value > 100 fails."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="1-100"):
            await event_discounts.create_event_discount(
                db_session,
                event_id=test_event_approved.id,
                user=organizer,
                name="Bad",
                discount_type="ticket_percent",
                value=101,
            )


@pytest.mark.asyncio
async def test_create_discount_forbidden(db_session, test_event_approved, test_users):
    """Customer cannot create discount."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ForbiddenError):
            await event_discounts.create_event_discount(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                name="No",
                discount_type="ticket_percent",
                value=10,
            )


@pytest.mark.asyncio
async def test_delete_event_discount(db_session, test_event_approved, test_users):
    """Delete discount."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        disc = await event_discounts.create_event_discount(
            db_session,
            event_id=test_event_approved.id,
            user=organizer,
            name="To Delete",
            discount_type="ticket_percent",
            value=5,
        )
        await event_discounts.delete_event_discount(
            db_session,
            event_id=test_event_approved.id,
            discount_id=disc.id,
            user=organizer,
        )


@pytest.mark.asyncio
async def test_delete_discount_not_found(db_session, test_event_approved, test_users):
    """Delete non-existent discount."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(NotFoundError, match="Discount"):
            await event_discounts.delete_event_discount(
                db_session,
                event_id=test_event_approved.id,
                discount_id=99999,
                user=organizer,
            )


@pytest.mark.asyncio
async def test_compute_discounts_for_user_no_discounts(db_session, test_event_approved, test_users):
    """Compute discounts returns empty for no discounts."""
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await event_discounts.compute_event_discounts_for_user(
            db_session,
            event_id=test_event_approved.id,
            user_id=customer.id,
        )
    assert result == []


@pytest.mark.asyncio
async def test_compute_discounts_pledger_gets_pledger_discount(db_session, test_event_approved, test_pledge, test_users):
    """Pledger gets pledger-targeted discount."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await event_discounts.create_event_discount(
            db_session,
            event_id=test_event_approved.id,
            user=organizer,
            name="Pledger Disc",
            discount_type="ticket_percent",
            value=15,
            target="pledgers",
        )
        result = await event_discounts.compute_event_discounts_for_user(
            db_session,
            event_id=test_event_approved.id,
            user_id=customer.id,
        )
    assert len(result) == 1
    assert result[0]["target"] == "pledgers"


@pytest.mark.asyncio
async def test_compute_discounts_non_pledger_skips_pledger_discount(db_session, test_event_approved, test_users):
    """Non-pledger doesn't get pledger-targeted discount."""
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await event_discounts.create_event_discount(
            db_session,
            event_id=test_event_approved.id,
            user=organizer,
            name="Pledger Only",
            discount_type="ticket_percent",
            value=15,
            target="pledgers",
        )
        # organizer has no pledge, so should not get this discount
        result = await event_discounts.compute_event_discounts_for_user(
            db_session,
            event_id=test_event_approved.id,
            user_id=organizer.id,
        )
    assert len(result) == 0


@pytest.mark.asyncio
async def test_compute_discounts_all_target(db_session, test_event_approved, test_users):
    """All-targeted discount available to any user."""
    organizer = test_users["organizer"]
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await event_discounts.create_event_discount(
            db_session,
            event_id=test_event_approved.id,
            user=organizer,
            name="Everyone",
            discount_type="ticket_percent",
            value=5,
            target="all",
        )
        result = await event_discounts.compute_event_discounts_for_user(
            db_session,
            event_id=test_event_approved.id,
            user_id=customer.id,
        )
    assert len(result) == 1
    assert result[0]["target"] == "all"
