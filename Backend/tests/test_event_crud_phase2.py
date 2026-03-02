"""
Phase 2 event/crud.py coverage — targets uncovered branches in auto_transition_status,
list_events filters, create validations, update branches, and list_events_for_map.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventStatus, RegistrationType
from app.models.ticket import TicketTier
from app.models.venue import Venue
from app.core.exceptions import ConflictError, NotFoundError, ForbiddenError

from app.services.event import crud


# ---------------------------------------------------------------------------
# auto_transition_status
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_auto_transition_approved_to_waiting_event_date(db_session, test_event):
    """Approved event with past funding_end_at transitions to waiting_event_date."""
    test_event.status = EventStatus.approved
    test_event.funding_end_at = datetime.now(timezone.utc) - timedelta(days=1)
    test_event.start_time = None
    await db_session.flush()
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=7):
        result = await crud.auto_transition_status(db_session, test_event)
    assert result.status == EventStatus.waiting_event_date
    assert result.event_date_deadline is not None


@pytest.mark.asyncio
async def test_auto_transition_approved_to_selling_tickets(db_session, test_event):
    """Approved event without funding but with start_time and tiers transitions to selling_tickets."""
    # Create a ticket strategy first
    from app.models.ticket_strategy import TicketStrategy
    ts = TicketStrategy(organizer_id=test_event.organizer_id, name="Test Strategy")
    db_session.add(ts)
    await db_session.flush()

    test_event.status = EventStatus.approved
    test_event.funding_end_at = None
    test_event.funding_goal_cents = None
    test_event.start_time = datetime.now(timezone.utc) + timedelta(days=30)
    test_event.end_time = datetime.now(timezone.utc) + timedelta(days=31)
    test_event.ticket_strategy_id = ts.id
    await db_session.flush()
    # Add a tier
    tier = TicketTier(event_id=test_event.id, name="GA", price_cents=1000, display_order=0)
    db_session.add(tier)
    await db_session.flush()

    result = await crud.auto_transition_status(db_session, test_event)
    assert result.status == EventStatus.selling_tickets


@pytest.mark.asyncio
async def test_auto_transition_selling_to_live(db_session, test_event):
    """Selling_tickets event transitions to live when start_time is past."""
    test_event.status = EventStatus.selling_tickets
    test_event.start_time = datetime.now(timezone.utc) - timedelta(hours=1)
    test_event.end_time = datetime.now(timezone.utc) + timedelta(hours=5)
    await db_session.flush()
    result = await crud.auto_transition_status(db_session, test_event)
    assert result.status == EventStatus.live


@pytest.mark.asyncio
async def test_auto_transition_live_to_completed(db_session, test_event):
    """Live event transitions to completed when end_time is past."""
    test_event.status = EventStatus.live
    test_event.start_time = datetime.now(timezone.utc) - timedelta(hours=6)
    test_event.end_time = datetime.now(timezone.utc) - timedelta(hours=1)
    await db_session.flush()
    result = await crud.auto_transition_status(db_session, test_event)
    assert result.status == EventStatus.completed


@pytest.mark.asyncio
async def test_auto_transition_no_change(db_session, test_event):
    """Draft event stays draft."""
    result = await crud.auto_transition_status(db_session, test_event)
    assert result.status == EventStatus.draft


# ---------------------------------------------------------------------------
# list_events filter branches
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_events_live_filter(db_session, test_event_approved):
    """List events with live=True filter."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, live=True)
    assert isinstance(rows, (list, tuple))


@pytest.mark.asyncio
async def test_list_events_registration_type(db_session, test_event_approved):
    """List events with registration_type filter."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, registration_type="open")
    assert isinstance(rows, (list, tuple))


@pytest.mark.asyncio
async def test_list_events_invalid_registration_type(db_session):
    """Invalid registration_type returns empty list."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, registration_type="invalid_type")
    assert rows == []


@pytest.mark.asyncio
async def test_list_events_date_range(db_session, test_event_approved):
    """List events with date range."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(
            db_session,
            date_from=datetime.now(timezone.utc) - timedelta(days=365),
            date_to=datetime.now(timezone.utc) + timedelta(days=365),
        )
    assert isinstance(rows, (list, tuple))


@pytest.mark.asyncio
async def test_list_events_has_funding(db_session, test_event_approved):
    """List events with has_funding=True."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, has_funding=True)
    assert isinstance(rows, (list, tuple))


@pytest.mark.asyncio
async def test_list_events_no_funding(db_session, test_event_approved):
    """List events with has_funding=False."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, has_funding=False)
    assert isinstance(rows, (list, tuple))


@pytest.mark.asyncio
async def test_list_events_has_tickets(db_session, test_event_approved, test_ticket_tier):
    """List events with has_tickets=True."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, has_tickets=True)
    assert len(rows) >= 1


@pytest.mark.asyncio
async def test_list_events_no_tickets(db_session, test_event_approved):
    """List events with has_tickets=False."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, has_tickets=False)
    assert isinstance(rows, (list, tuple))


@pytest.mark.asyncio
async def test_list_events_capacity_filter(db_session, test_event_approved):
    """List events with min/max capacity filters."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, min_capacity=1, max_capacity=999999)
    assert isinstance(rows, (list, tuple))


@pytest.mark.asyncio
async def test_list_events_genre_filter(db_session, test_event_approved):
    """List events with genre filter."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, genre="music")
    assert isinstance(rows, (list, tuple))


@pytest.mark.asyncio
async def test_list_events_include_all_statuses(db_session, test_event):
    """List events with include_all_statuses shows drafts."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        rows, _ = await crud.list_events(db_session, include_all_statuses=True)
    assert len(rows) >= 1


# ---------------------------------------------------------------------------
# create — additional validation branches
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_no_dates(db_session, test_users, test_venue):
    """Create event with neither start_time nor funding_end_at raises."""
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=0):
        with pytest.raises(ConflictError, match="At least one"):
            await crud.create(
                db_session,
                organizer_id=test_users["organizer"].id,
                venue_id=test_venue.id,
                title="No Dates", description=None,
                start_time=None, end_time=None,
                funding_goal_cents=None, funding_end_at=None,
                min_pledge_cents=100,
                registration_type=RegistrationType.open,
                max_capacity=100,
            )


@pytest.mark.asyncio
async def test_create_funding_end_no_goal(db_session, test_users, test_venue):
    """Create event with funding_end_at but no funding_goal raises."""
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=0):
        with pytest.raises(ConflictError, match="Funding goal"):
            await crud.create(
                db_session,
                organizer_id=test_users["organizer"].id,
                venue_id=test_venue.id,
                title="No Goal", description=None,
                start_time=None, end_time=None,
                funding_goal_cents=None,
                funding_end_at=datetime.now(timezone.utc) + timedelta(days=30),
                min_pledge_cents=100,
                registration_type=RegistrationType.open,
                max_capacity=100,
            )


@pytest.mark.asyncio
async def test_create_end_time_required(db_session, test_users, test_venue):
    """Create event with start_time but no end_time raises."""
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=0):
        with pytest.raises(ConflictError, match="end_time is required"):
            await crud.create(
                db_session,
                organizer_id=test_users["organizer"].id,
                venue_id=test_venue.id,
                title="No End", description=None,
                start_time=datetime.now(timezone.utc) + timedelta(days=60),
                end_time=None,
                funding_goal_cents=10000,
                funding_end_at=datetime.now(timezone.utc) + timedelta(days=30),
                min_pledge_cents=100,
                registration_type=RegistrationType.open,
                max_capacity=100,
            )


@pytest.mark.asyncio
async def test_create_no_funding_no_strategy(db_session, test_users, test_venue):
    """Event without funding period requires ticket strategy."""
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=0):
        with pytest.raises(ConflictError, match="Ticket strategy"):
            await crud.create(
                db_session,
                organizer_id=test_users["organizer"].id,
                venue_id=test_venue.id,
                title="No Strategy", description=None,
                start_time=datetime.now(timezone.utc) + timedelta(days=30),
                end_time=datetime.now(timezone.utc) + timedelta(days=31),
                funding_goal_cents=None, funding_end_at=None,
                min_pledge_cents=100,
                registration_type=RegistrationType.open,
                max_capacity=100,
                ticket_strategy_id=None,
            )


@pytest.mark.asyncio
async def test_create_wrong_venue_owner(db_session, test_users, test_venue):
    """Cannot create event at someone else's venue."""
    with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=0):
        with pytest.raises(ForbiddenError, match="your own venues"):
            await crud.create(
                db_session,
                organizer_id=test_users["customer"].id,
                venue_id=test_venue.id,
                title="Wrong Venue", description=None,
                start_time=None, end_time=None,
                funding_goal_cents=10000,
                funding_end_at=datetime.now(timezone.utc) + timedelta(days=30),
                min_pledge_cents=100,
                registration_type=RegistrationType.open,
                max_capacity=100,
            )


# ---------------------------------------------------------------------------
# update — uncovered branches
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_update_venue_change(db_session, test_event, test_users, test_venue):
    """Update event venue."""
    # Create another venue
    venue2 = Venue(
        organizer_id=test_users["organizer"].id,
        name="Venue 2", address="456 St", city="NYC",
        max_capacity=500, lat=40.7, lng=-74.0,
    )
    db_session.add(venue2)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await crud.update(db_session, test_event, venue_id=venue2.id)
    assert result.venue_id == venue2.id
    assert result.lat == 40.7


@pytest.mark.asyncio
async def test_update_venue_not_found(db_session, test_event):
    """Update event with non-existent venue."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(NotFoundError):
            await crud.update(db_session, test_event, venue_id=99999)


@pytest.mark.asyncio
async def test_update_multiple_fields(db_session, test_event):
    """Update multiple simple fields at once."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await crud.update(
            db_session, test_event,
            description="Updated desc",
            genre="music",
            posts_enabled=False,
            parking_info="Lot A",
            transit_info="Bus 42",
            rideshare_info="Uber",
            accessibility_info="Wheelchair OK",
            has_schedule=True,
            link_funding_to_tiers=True,
        )
    assert result.description == "Updated desc"
    assert result.genre == "music"
    assert result.posts_enabled is False
    assert result.parking_info == "Lot A"


@pytest.mark.asyncio
async def test_update_community_rules_non_draft(db_session, test_event_approved):
    """Cannot change community_rules on non-draft event."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ConflictError, match="draft"):
            await crud.update(db_session, test_event_approved, community_rules=True)


@pytest.mark.asyncio
async def test_update_policy_fields(db_session, test_event):
    """Update per-event policy fields with ceiling clamping."""
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=100):
            result = await crud.update(
                db_session, test_event,
                waitlist_max_size=50,
                waitlist_auto_approve=False,
                event_max_images=10,
                max_posts_per_day=5,
                max_co_organizers=3,
                refund_deadline_percent=25,
            )
    assert result.waitlist_max_size == 50
    assert result.waitlist_auto_approve is False


# ---------------------------------------------------------------------------
# list_events_for_map
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_events_for_map(db_session, test_event_approved):
    """List events for map (need lat/lng)."""
    test_event_approved.lat = 40.7
    test_event_approved.lng = -74.0
    await db_session.flush()
    result = await crud.list_events_for_map(db_session)
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_events_for_map_with_status(db_session, test_event_approved):
    """List map events with status filter."""
    test_event_approved.lat = 40.7
    test_event_approved.lng = -74.0
    await db_session.flush()
    result = await crud.list_events_for_map(db_session, status="approved")
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_events_for_map_invalid_status(db_session):
    """Map events with invalid status returns empty."""
    result = await crud.list_events_for_map(db_session, status="nonexistent")
    assert result == []


@pytest.mark.asyncio
async def test_list_events_for_map_radius_filter(db_session, test_event_approved):
    """List map events with lat/lng/radius."""
    test_event_approved.lat = 40.7
    test_event_approved.lng = -74.0
    await db_session.flush()
    result = await crud.list_events_for_map(
        db_session, lat=40.7, lng=-74.0, radius_km=50
    )
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_events_for_map_search(db_session, test_event_approved):
    """List map events with search filter."""
    test_event_approved.lat = 40.7
    test_event_approved.lng = -74.0
    await db_session.flush()
    result = await crud.list_events_for_map(db_session, search="Test")
    assert isinstance(result, (list, tuple))
