"""
Service-level tests for dashboard.py, milestone.py, chat_service.py.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventStatus
from app.models.user import User, UserRole
from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError


# ===========================================================================
# DASHBOARD
# ===========================================================================

@pytest.mark.asyncio
async def test_organizer_dashboard(db_session, test_event_approved, test_users):
    """Organizer dashboard returns KPIs."""
    from app.services import dashboard as dash_svc
    organizer = test_users["organizer"]
    result = await dash_svc.get_organizer_dashboard(db_session, organizer.id)
    assert "total_revenue" in result
    assert "tickets_sold" in result
    assert "total_backers" in result
    assert "total_events" in result


@pytest.mark.asyncio
async def test_organizer_dashboard_with_data(db_session, test_event_approved, test_pledge, test_ticket_sale, test_users):
    """Dashboard with actual data."""
    from app.services import dashboard as dash_svc
    organizer = test_users["organizer"]
    result = await dash_svc.get_organizer_dashboard(db_session, organizer.id)
    assert result["total_revenue"]["value"] >= 0
    assert result["tickets_sold"]["value"] >= 0


@pytest.mark.asyncio
async def test_organizer_dashboard_empty(db_session, test_users):
    """Dashboard for organizer with no events."""
    from app.services import dashboard as dash_svc
    organizer = test_users["organizer"]
    result = await dash_svc.get_organizer_dashboard(db_session, organizer.id)
    assert result["total_events"]["value"] == 0


@pytest.mark.asyncio
async def test_organizer_dashboard_event_filter(db_session, test_event_approved, test_users):
    """Dashboard filtered by specific event."""
    from app.services import dashboard as dash_svc
    organizer = test_users["organizer"]
    result = await dash_svc.get_organizer_dashboard(
        db_session, organizer.id, event_id=test_event_approved.id
    )
    assert "total_revenue" in result


@pytest.mark.asyncio
async def test_organizer_dashboard_status_filter(db_session, test_event_approved, test_users):
    """Dashboard filtered by event status."""
    from app.services import dashboard as dash_svc
    organizer = test_users["organizer"]
    result = await dash_svc.get_organizer_dashboard(
        db_session, organizer.id, status_filter="approved"
    )
    assert "total_revenue" in result


@pytest.mark.asyncio
async def test_organizer_time_series(db_session, test_event_approved, test_users):
    """Organizer time series returns points."""
    from app.services import dashboard as dash_svc
    organizer = test_users["organizer"]
    result = await dash_svc.get_organizer_time_series(db_session, organizer.id)
    assert "points" in result
    assert "granularity" in result


@pytest.mark.asyncio
async def test_organizer_time_series_weekly(db_session, test_event_approved, test_users):
    """Time series with 90+ days uses weekly granularity."""
    from app.services import dashboard as dash_svc
    organizer = test_users["organizer"]
    result = await dash_svc.get_organizer_time_series(db_session, organizer.id, days=90)
    assert result["granularity"] == "weekly"


# ===========================================================================
# MILESTONE
# ===========================================================================

@pytest.mark.asyncio
async def test_list_milestones(db_session, test_event_approved, test_milestone):
    """List milestones for event."""
    from app.services import milestone as ms_svc
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await ms_svc.list_milestones(db_session, test_event_approved.id)
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_list_milestones_empty(db_session, test_event_approved):
    """List milestones when none exist."""
    from app.services import milestone as ms_svc
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await ms_svc.list_milestones(db_session, test_event_approved.id)
    assert len(result) == 0


@pytest.mark.asyncio
async def test_create_milestone(db_session, test_event, test_users):
    """Create milestone on draft event."""
    from app.services import milestone as ms_svc
    from app.services.milestone import MilestoneCreate
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await ms_svc.create_milestone(
            db_session,
            test_event.id,
            MilestoneCreate(title="75% Funded", unlock_percent=75, description="Almost there"),
            organizer,
        )
    assert result.title == "75% Funded"


@pytest.mark.asyncio
async def test_create_milestone_forbidden(db_session, test_event, test_users):
    """Customer cannot create milestone."""
    from app.services import milestone as ms_svc
    from app.services.milestone import MilestoneCreate
    customer = test_users["customer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        with pytest.raises(ForbiddenError):
            await ms_svc.create_milestone(
                db_session,
                test_event.id,
                MilestoneCreate(title="Bad", unlock_percent=50),
                customer,
            )


@pytest.mark.asyncio
async def test_delete_milestone(db_session, test_event_approved, test_milestone, test_users):
    """Delete milestone."""
    from app.services import milestone as ms_svc
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await ms_svc.delete_milestone(db_session, test_milestone.id, organizer)


@pytest.mark.asyncio
async def test_react_to_milestone(db_session, test_milestone, test_users):
    """React to milestone."""
    from app.services import milestone as ms_svc
    customer = test_users["customer"]
    result = await ms_svc.react_to_milestone(
        db_session, test_milestone.id, customer.id, "like"
    )
    assert result["action"] in ("added", "switched", "removed")


@pytest.mark.asyncio
async def test_react_to_milestone_invalid(db_session, test_milestone, test_users):
    """Invalid reaction."""
    from app.services import milestone as ms_svc
    customer = test_users["customer"]
    with pytest.raises(ConflictError, match="like"):
        await ms_svc.react_to_milestone(
            db_session, test_milestone.id, customer.id, "love"
        )


@pytest.mark.asyncio
async def test_get_my_reaction(db_session, test_milestone, test_users):
    """Get my reaction to milestone."""
    from app.services import milestone as ms_svc
    customer = test_users["customer"]
    result = await ms_svc.get_my_reaction(db_session, test_milestone.id, customer.id)
    assert "reaction" in result


@pytest.mark.asyncio
async def test_list_snapshots(db_session, test_event_approved):
    """List milestone snapshots."""
    from app.services import milestone as ms_svc
    result = await ms_svc.list_snapshots(db_session, test_event_approved.id)
    assert isinstance(result, list)


# ===========================================================================
# EARLY BIRD DISCOUNTS
# ===========================================================================

@pytest.mark.asyncio
async def test_list_early_bird_discounts(db_session, test_event_approved):
    """List early bird discounts (create one with explicit window_start to avoid tz mismatch)."""
    from app.services import milestone as ms_svc
    from app.models.milestone import EarlyBirdDiscount
    ebd = EarlyBirdDiscount(
        event_id=test_event_approved.id,
        applies_to="funding",
        window_start=datetime.now(timezone.utc) - timedelta(days=1),
        window_end=datetime.now(timezone.utc) + timedelta(days=7),
        discount_type="percent",
        value=10,
    )
    db_session.add(ebd)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await ms_svc.list_early_bird_discounts(db_session, test_event_approved.id)
    assert len(result) >= 1


@pytest.mark.asyncio
async def test_create_early_bird_discount(db_session, test_event_approved, test_users):
    """Create early bird discount."""
    from app.services import milestone as ms_svc
    from app.services.milestone import EarlyBirdDiscountCreate
    organizer = test_users["organizer"]
    window_end = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await ms_svc.create_early_bird_discount(
            db_session,
            test_event_approved.id,
            EarlyBirdDiscountCreate(
                applies_to="funding",
                discount_type="percent",
                value=15,
                window_end=window_end,
            ),
            organizer,
        )
    assert result.value == 15


@pytest.mark.asyncio
async def test_delete_early_bird_discount(db_session, test_event_approved, test_early_bird_discount, test_users):
    """Delete early bird discount."""
    from app.services import milestone as ms_svc
    organizer = test_users["organizer"]
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        await ms_svc.delete_early_bird_discount(db_session, test_early_bird_discount.id, organizer)
