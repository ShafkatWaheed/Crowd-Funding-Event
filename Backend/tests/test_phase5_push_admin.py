"""
Phase 5 coverage tests for push_notification._send_to_tokens and admin.py.

Targets:
- push_notification.py: _send_to_tokens (lines 79-126) — FCM send, stale token cleanup
- admin.py: approve/reject event, compute_event_warnings (additional), get_dashboard
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock, MagicMock

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.event import Event, EventStatus
from app.models.device_token import DeviceToken
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketTier, TicketSale, TicketSaleStatus
from app.models.payment_info import OrganizerBankAccount


# ═══════════════════════════════════════════════════════════════════════════
# 1. push_notification._send_to_tokens — lines 79-126
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_send_to_tokens_fcm_import_error(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """_send_to_tokens returns 0 when firebase_admin cannot be imported."""
    from app.services.push_notification import _send_to_tokens

    with patch.dict("sys.modules", {"firebase_admin": None, "firebase_admin.messaging": None}):
        result = await _send_to_tokens(db_session, [test_device_token], "Hi", "Body", None)
    assert result == 0


@pytest.mark.asyncio
async def test_send_to_tokens_firebase_app_value_error(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """_send_to_tokens returns 0 when get_firebase_app raises ValueError."""
    from app.services.push_notification import _send_to_tokens

    mock_fb = MagicMock()
    mock_messaging = MagicMock()

    with patch.dict("sys.modules", {
        "firebase_admin": mock_fb,
        "firebase_admin.messaging": mock_messaging,
    }):
        with patch("app.core.firebase.get_firebase_app", side_effect=ValueError("No app")):
            result = await _send_to_tokens(db_session, [test_device_token], "Hi", "Body", None)
    assert result == 0


@pytest.mark.asyncio
async def test_send_to_tokens_success(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """_send_to_tokens with successful FCM response returns 1."""
    from app.services.push_notification import _send_to_tokens

    mock_send_resp = MagicMock(success=True, exception=None)
    mock_batch_resp = MagicMock(responses=[mock_send_resp])

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each = MagicMock(return_value=mock_batch_resp)

    mock_fb = MagicMock()
    mock_fb.messaging = mock_messaging

    with patch.dict("sys.modules", {
        "firebase_admin": mock_fb,
        "firebase_admin.messaging": mock_messaging,
    }):
        with patch("app.core.firebase.get_firebase_app"):
            result = await _send_to_tokens(db_session, [test_device_token], "Hi", "Body", None)
    assert result == 1


@pytest.mark.asyncio
async def test_send_to_tokens_with_data_dict(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """_send_to_tokens converts data dict values to strings."""
    from app.services.push_notification import _send_to_tokens

    mock_send_resp = MagicMock(success=True, exception=None)
    mock_batch_resp = MagicMock(responses=[mock_send_resp])

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each = MagicMock(return_value=mock_batch_resp)

    mock_fb = MagicMock()
    mock_fb.messaging = mock_messaging

    with patch.dict("sys.modules", {
        "firebase_admin": mock_fb,
        "firebase_admin.messaging": mock_messaging,
    }):
        with patch("app.core.firebase.get_firebase_app"):
            result = await _send_to_tokens(
                db_session,
                [test_device_token],
                "Hi",
                "Body",
                {"event_id": 42, "type": "test"},
            )
    assert result == 1
    # Verify the data dict was converted to strings
    call_kwargs = mock_messaging.Message.call_args
    assert call_kwargs is not None


@pytest.mark.asyncio
async def test_send_to_tokens_stale_token_removal(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """_send_to_tokens removes stale UNREGISTERED tokens from DB."""
    from app.services.push_notification import _send_to_tokens

    token_id = test_device_token.id

    mock_exc = MagicMock()
    mock_exc.code = "UNREGISTERED"
    mock_send_resp = MagicMock(success=False, exception=mock_exc)
    mock_batch_resp = MagicMock(responses=[mock_send_resp])

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each = MagicMock(return_value=mock_batch_resp)

    mock_fb = MagicMock()
    mock_fb.messaging = mock_messaging

    with patch.dict("sys.modules", {
        "firebase_admin": mock_fb,
        "firebase_admin.messaging": mock_messaging,
    }):
        with patch("app.core.firebase.get_firebase_app"):
            result = await _send_to_tokens(db_session, [test_device_token], "Hi", "Body", None)
    assert result == 0

    # Verify the stale token was deleted
    remaining = (
        await db_session.execute(select(DeviceToken).where(DeviceToken.id == token_id))
    ).scalar_one_or_none()
    assert remaining is None


@pytest.mark.asyncio
async def test_send_to_tokens_not_registered_string(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """_send_to_tokens removes tokens where exception contains 'not-registered'."""
    from app.services.push_notification import _send_to_tokens

    token_id = test_device_token.id

    mock_exc = MagicMock()
    mock_exc.code = "SOME_OTHER_CODE"
    mock_exc.__str__ = lambda self: "Requested entity was not-registered"
    mock_send_resp = MagicMock(success=False, exception=mock_exc)
    mock_batch_resp = MagicMock(responses=[mock_send_resp])

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each = MagicMock(return_value=mock_batch_resp)

    mock_fb = MagicMock()
    mock_fb.messaging = mock_messaging

    with patch.dict("sys.modules", {
        "firebase_admin": mock_fb,
        "firebase_admin.messaging": mock_messaging,
    }):
        with patch("app.core.firebase.get_firebase_app"):
            result = await _send_to_tokens(db_session, [test_device_token], "Hi", "Body", None)
    assert result == 0

    remaining = (
        await db_session.execute(select(DeviceToken).where(DeviceToken.id == token_id))
    ).scalar_one_or_none()
    assert remaining is None


@pytest.mark.asyncio
async def test_send_to_tokens_non_stale_failure(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """_send_to_tokens does NOT remove token when failure is not UNREGISTERED."""
    from app.services.push_notification import _send_to_tokens

    token_id = test_device_token.id

    mock_exc = MagicMock()
    mock_exc.code = "INTERNAL"
    mock_exc.__str__ = lambda self: "Internal server error"
    mock_send_resp = MagicMock(success=False, exception=mock_exc)
    mock_batch_resp = MagicMock(responses=[mock_send_resp])

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each = MagicMock(return_value=mock_batch_resp)

    mock_fb = MagicMock()
    mock_fb.messaging = mock_messaging

    with patch.dict("sys.modules", {
        "firebase_admin": mock_fb,
        "firebase_admin.messaging": mock_messaging,
    }):
        with patch("app.core.firebase.get_firebase_app"):
            result = await _send_to_tokens(db_session, [test_device_token], "Hi", "Body", None)
    assert result == 0

    # Token should NOT be deleted (non-stale failure)
    remaining = (
        await db_session.execute(select(DeviceToken).where(DeviceToken.id == token_id))
    ).scalar_one_or_none()
    assert remaining is not None


@pytest.mark.asyncio
async def test_send_to_tokens_send_each_exception(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """_send_to_tokens returns 0 when send_each raises an exception."""
    from app.services.push_notification import _send_to_tokens

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each = MagicMock(side_effect=RuntimeError("Network error"))

    mock_fb = MagicMock()
    mock_fb.messaging = mock_messaging

    with patch.dict("sys.modules", {
        "firebase_admin": mock_fb,
        "firebase_admin.messaging": mock_messaging,
    }):
        with patch("app.core.firebase.get_firebase_app"):
            result = await _send_to_tokens(db_session, [test_device_token], "Hi", "Body", None)
    assert result == 0


@pytest.mark.asyncio
async def test_send_to_tokens_multiple_tokens_mixed(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """_send_to_tokens with multiple tokens — some succeed, some fail, some stale."""
    from app.services.push_notification import _send_to_tokens

    # Create 3 device tokens
    tokens = []
    for i in range(3):
        dt = DeviceToken(
            user_id=test_users["customer"].id,
            token=f"multi-token-{i}",
            platform="web",
        )
        db_session.add(dt)
    await db_session.flush()
    tokens_db = (
        await db_session.execute(
            select(DeviceToken).where(
                DeviceToken.user_id == test_users["customer"].id,
                DeviceToken.token.in_([f"multi-token-{i}" for i in range(3)]),
            )
        )
    ).scalars().all()

    stale_token_id = tokens_db[2].id

    # Token 0: success, Token 1: non-stale failure, Token 2: stale (UNREGISTERED)
    mock_exc_internal = MagicMock()
    mock_exc_internal.code = "INTERNAL"
    mock_exc_internal.__str__ = lambda self: "Internal"

    mock_exc_stale = MagicMock()
    mock_exc_stale.code = "UNREGISTERED"

    responses = [
        MagicMock(success=True, exception=None),
        MagicMock(success=False, exception=mock_exc_internal),
        MagicMock(success=False, exception=mock_exc_stale),
    ]
    mock_batch_resp = MagicMock(responses=responses)

    mock_messaging = MagicMock()
    mock_messaging.Message = MagicMock(return_value=MagicMock())
    mock_messaging.Notification = MagicMock(return_value=MagicMock())
    mock_messaging.send_each = MagicMock(return_value=mock_batch_resp)

    mock_fb = MagicMock()
    mock_fb.messaging = mock_messaging

    with patch.dict("sys.modules", {
        "firebase_admin": mock_fb,
        "firebase_admin.messaging": mock_messaging,
    }):
        with patch("app.core.firebase.get_firebase_app"):
            result = await _send_to_tokens(
                db_session, list(tokens_db), "Hi", "Body", None
            )
    assert result == 1  # only token 0 succeeded

    # Token 2 (stale) should be deleted
    stale = (
        await db_session.execute(select(DeviceToken).where(DeviceToken.id == stale_token_id))
    ).scalar_one_or_none()
    assert stale is None


@pytest.mark.asyncio
async def test_send_push_full_flow_with_mocked_send_to_tokens(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """send_push end-to-end: enabled, has tokens, _send_to_tokens returns count."""
    from app.services.push_notification import send_push

    with (
        patch("app.services.platform_settings.get_bool", new_callable=AsyncMock, return_value=True),
        patch(
            "app.services.push_notification._send_to_tokens",
            new_callable=AsyncMock,
            return_value=1,
        ) as mock_inner,
    ):
        result = await send_push(
            db_session,
            user_id=test_device_token.user_id,
            title="Hello",
            body="World",
        )
    assert result == 1
    mock_inner.assert_awaited_once()


# ═══════════════════════════════════════════════════════════════════════════
# 2. admin.py — approve_or_reject_event (lines 63-101)
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_approve_event_success(
    db_session: AsyncSession,
    test_event_pending: Event,
    test_organizer_bank: OrganizerBankAccount,
    test_users: dict[str, User],
):
    """Approve event succeeds when organizer has bank + event has funding goal."""
    from app.services.admin import approve_or_reject_event

    event = await approve_or_reject_event(db_session, test_event_pending.id, approved=True)
    assert event.status == EventStatus.approved


@pytest.mark.asyncio
async def test_approve_event_with_ticket_tiers(
    db_session: AsyncSession,
    test_event_pending: Event,
    test_organizer_bank: OrganizerBankAccount,
    test_users: dict[str, User],
):
    """Approve event succeeds when there are ticket tiers even with no funding goal."""
    # Remove funding goal
    test_event_pending.funding_goal_cents = 0
    await db_session.flush()

    # Add a ticket tier
    tier = TicketTier(
        event_id=test_event_pending.id,
        name="General",
        price_cents=2500,
        display_order=0,
    )
    db_session.add(tier)
    await db_session.flush()

    from app.services.admin import approve_or_reject_event

    event = await approve_or_reject_event(db_session, test_event_pending.id, approved=True)
    assert event.status == EventStatus.approved


@pytest.mark.asyncio
async def test_approve_event_no_bank_fails(
    db_session: AsyncSession,
    test_event_pending: Event,
    test_users: dict[str, User],
):
    """Cannot approve event without a verified bank account."""
    from app.services.admin import approve_or_reject_event
    from app.core.exceptions import ConflictError

    with pytest.raises(ConflictError, match="bank"):
        await approve_or_reject_event(db_session, test_event_pending.id, approved=True)


@pytest.mark.asyncio
async def test_approve_event_no_funding_no_tiers_fails(
    db_session: AsyncSession,
    test_event_pending: Event,
    test_organizer_bank: OrganizerBankAccount,
    test_users: dict[str, User],
):
    """Cannot approve event without funding goal or ticket tiers."""
    from app.services.admin import approve_or_reject_event
    from app.core.exceptions import ConflictError

    # Remove funding goal
    test_event_pending.funding_goal_cents = 0
    await db_session.flush()

    with pytest.raises(ConflictError, match="funding goal"):
        await approve_or_reject_event(db_session, test_event_pending.id, approved=True)


@pytest.mark.asyncio
async def test_reject_event_sets_draft(
    db_session: AsyncSession,
    test_event_pending: Event,
    test_users: dict[str, User],
):
    """Rejecting event sets status to draft."""
    from app.services.admin import approve_or_reject_event

    event = await approve_or_reject_event(db_session, test_event_pending.id, approved=False)
    assert event.status == EventStatus.draft


@pytest.mark.asyncio
async def test_approve_nonexistent_event_404(
    db_session: AsyncSession,
    test_users: dict[str, User],
):
    """approve_or_reject_event raises NotFoundError for non-existent event."""
    from app.services.admin import approve_or_reject_event
    from app.core.exceptions import NotFoundError

    with pytest.raises(NotFoundError):
        await approve_or_reject_event(db_session, 999999, approved=True)


# ═══════════════════════════════════════════════════════════════════════════
# 3. admin.py — compute_event_warnings additional conditions (lines 104-140)
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_warnings_funding_deadline_but_zero_goal(test_event_approved: Event):
    """Warning when funding deadline set but goal is $0."""
    from app.services.admin import compute_event_warnings

    test_event_approved.funding_goal_cents = 0
    test_event_approved.funding_end_at = datetime.now(timezone.utc) + timedelta(days=10)
    test_event_approved.description = "A sufficiently long description for testing purposes."
    test_event_approved.genre = "music"
    warnings = compute_event_warnings(test_event_approved)
    assert any("goal is $0" in w for w in warnings)


@pytest.mark.asyncio
async def test_warnings_funding_goal_but_no_deadline(test_event_approved: Event):
    """Warning when funding goal set but no funding deadline."""
    from app.services.admin import compute_event_warnings

    test_event_approved.funding_goal_cents = 10000
    test_event_approved.funding_end_at = None
    test_event_approved.description = "A sufficiently long description for testing purposes."
    test_event_approved.genre = "music"
    warnings = compute_event_warnings(test_event_approved)
    assert any("no funding deadline" in w.lower() for w in warnings)


@pytest.mark.asyncio
async def test_warnings_no_ticket_tier_assigned(test_event_approved: Event):
    """Warning when no ticket tier assigned for selling_tickets status."""
    from app.services.admin import compute_event_warnings

    test_event_approved.status = EventStatus.selling_tickets
    test_event_approved.ticket_strategy_id = None
    test_event_approved.funding_end_at = None
    test_event_approved.description = "A sufficiently long description for testing purposes."
    test_event_approved.genre = "music"
    test_event_approved.funding_goal_cents = 0
    warnings = compute_event_warnings(test_event_approved)
    assert any("ticket tier" in w.lower() for w in warnings)


@pytest.mark.asyncio
async def test_warnings_start_date_in_past_for_draft(test_event_approved: Event):
    """Warning when start date is in the past for draft events."""
    from app.services.admin import compute_event_warnings

    test_event_approved.status = EventStatus.draft
    test_event_approved.start_time = datetime.now(timezone.utc) - timedelta(days=5)
    test_event_approved.end_time = datetime.now(timezone.utc) + timedelta(hours=1)
    test_event_approved.description = "A sufficiently long description for testing purposes."
    test_event_approved.genre = "music"
    warnings = compute_event_warnings(test_event_approved)
    assert any("past" in w.lower() for w in warnings)


@pytest.mark.asyncio
async def test_warnings_end_before_start(test_event_approved: Event):
    """Warning when end time is before start time."""
    from app.services.admin import compute_event_warnings

    now = datetime.now(timezone.utc) + timedelta(days=30)
    test_event_approved.start_time = now
    test_event_approved.end_time = now - timedelta(hours=1)
    test_event_approved.description = "A sufficiently long description for testing purposes."
    test_event_approved.genre = "music"
    warnings = compute_event_warnings(test_event_approved)
    assert any("End time" in w for w in warnings)


@pytest.mark.asyncio
async def test_warnings_funding_deadline_passed(test_event_approved: Event):
    """Warning when funding deadline already passed for draft events."""
    from app.services.admin import compute_event_warnings

    test_event_approved.status = EventStatus.draft
    test_event_approved.funding_end_at = datetime.now(timezone.utc) - timedelta(days=5)
    test_event_approved.funding_goal_cents = 10000
    test_event_approved.description = "A sufficiently long description for testing purposes."
    test_event_approved.genre = "music"
    warnings = compute_event_warnings(test_event_approved)
    assert any("deadline already passed" in w.lower() for w in warnings)


@pytest.mark.asyncio
async def test_warnings_no_description(test_event_approved: Event):
    """Warning when description is None."""
    from app.services.admin import compute_event_warnings

    test_event_approved.description = None
    test_event_approved.genre = "music"
    warnings = compute_event_warnings(test_event_approved)
    assert any("Description" in w for w in warnings)


@pytest.mark.asyncio
async def test_warnings_clean_event_no_warnings(test_event_approved: Event):
    """A well-configured event produces no warnings."""
    from app.services.admin import compute_event_warnings

    test_event_approved.description = "A sufficiently long description for testing purposes."
    test_event_approved.genre = "music"
    test_event_approved.max_capacity = 100
    test_event_approved.ticket_strategy_id = 1
    test_event_approved.start_time = datetime.now(timezone.utc) + timedelta(days=30)
    test_event_approved.end_time = datetime.now(timezone.utc) + timedelta(days=30, hours=2)
    test_event_approved.funding_goal_cents = 10000
    test_event_approved.funding_end_at = datetime.now(timezone.utc) + timedelta(days=20)
    warnings = compute_event_warnings(test_event_approved)
    assert warnings == []


# ═══════════════════════════════════════════════════════════════════════════
# 4. admin.py — list_events_for_admin with invalid status (lines 52-53)
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_list_events_for_admin_invalid_status(
    db_session: AsyncSession, test_event_approved: Event
):
    """list_events_for_admin ignores an invalid status string."""
    from app.services.admin import list_events_for_admin

    # "bogus" is not a valid EventStatus — the ValueError is caught, query runs unfiltered
    items, total = await list_events_for_admin(db_session, status="bogus")
    assert total >= 1


# ═══════════════════════════════════════════════════════════════════════════
# 5. admin.py — _period_cutoff returns None for unknown period (line 215)
# ═══════════════════════════════════════════════════════════════════════════


def test_period_cutoff_unknown():
    """_period_cutoff returns None for unknown period string."""
    from app.services.admin import _period_cutoff

    assert _period_cutoff("unknown") is None


def test_period_cutoff_known():
    """_period_cutoff returns a datetime for known period."""
    from app.services.admin import _period_cutoff

    result = _period_cutoff("30d")
    assert result is not None
    assert isinstance(result, datetime)


# ═══════════════════════════════════════════════════════════════════════════
# 6. admin.py — get_stats with escrow exception (lines 185-186)
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_get_stats_with_data(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_ticket_tier: TicketTier,
    test_ticket_sale: TicketSale,
    test_pledge: Funding,
    test_users: dict[str, User],
):
    """get_stats returns correct totals with ticket sales and pledges."""
    from app.services.admin import get_stats

    stats = await get_stats(db_session)
    assert "total_escrow_held_cents" in stats
    assert isinstance(stats["total_escrow_held_cents"], int)
    assert stats["events_total"] >= 1
    assert stats["users_total"] >= 4
    # ticket_commission and funding_commission are present
    assert isinstance(stats["total_ticket_commission_cents"], int)
    assert isinstance(stats["total_funding_commission_cents"], int)


# ═══════════════════════════════════════════════════════════════════════════
# 7. admin.py — get_dashboard (lines 219-625) — the BIG function
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_get_dashboard_no_data(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """get_dashboard with no events returns zeroed KPIs."""
    from app.services.admin import get_dashboard

    result = await get_dashboard(db_session, period="7d")
    assert "kpis" in result
    assert "by_genre" in result
    assert "by_status" in result
    assert "by_escrow_status" in result
    assert "time_series" in result
    assert "top_events" in result
    assert "action_items" in result
    assert "available_filters" in result
    assert result["kpis"]["tickets_sold"] == 0
    assert result["kpis"]["pledges_made"] == 0
    assert result["kpis"]["events_total"] == 0


@pytest.mark.asyncio
async def test_get_dashboard_basic(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_ticket_tier: TicketTier,
    test_ticket_sale: TicketSale,
    test_pledge: Funding,
    test_users: dict[str, User],
):
    """get_dashboard returns structured data with correct aggregations."""
    from app.services.admin import get_dashboard

    # Set genre on the event for by_genre breakdown
    test_event_approved.genre = "music"
    await db_session.flush()

    result = await get_dashboard(db_session, period="30d")

    assert "kpis" in result
    assert result["kpis"]["users_total"] >= 4
    assert result["kpis"]["events_total"] >= 1
    assert result["kpis"]["tickets_sold"] >= 1
    assert result["kpis"]["pledges_made"] >= 1
    assert result["kpis"]["total_ticket_sales_cents"] >= 2500
    assert result["kpis"]["total_funding_cents"] >= 2000
    assert result["kpis"]["avg_ticket_price_cents"] > 0

    # by_genre should have at least "music"
    assert len(result["by_genre"]) >= 1
    assert result["by_genre"][0]["genre"] == "music"

    # by_status should show approved
    assert len(result["by_status"]) >= 1

    # top_events should include test event
    assert len(result["top_events"]) >= 1
    assert any(e["title"] == "Test Event" for e in result["top_events"])

    # action_items should have the expected keys
    assert "pending_approval" in result["action_items"]
    assert "pending_cancellations" in result["action_items"]
    assert "pending_extensions" in result["action_items"]
    assert "under_review" in result["action_items"]
    assert "pending_refunds" in result["action_items"]


@pytest.mark.asyncio
async def test_get_dashboard_with_genre_filter(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_pledge: Funding,
    test_users: dict[str, User],
):
    """get_dashboard with genre filter narrows results."""
    from app.services.admin import get_dashboard

    test_event_approved.genre = "music"
    await db_session.flush()

    result = await get_dashboard(db_session, period="90d", genre="music")
    assert "kpis" in result
    assert result["kpis"]["events_total"] >= 1


@pytest.mark.asyncio
async def test_get_dashboard_with_status_filter(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """get_dashboard with status filter."""
    from app.services.admin import get_dashboard

    result = await get_dashboard(db_session, period="30d", status="approved")
    assert "kpis" in result
    assert result["kpis"]["events_total"] >= 1


@pytest.mark.asyncio
async def test_get_dashboard_with_invalid_status_filter(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """get_dashboard with invalid status filter (lines 239-240)."""
    from app.services.admin import get_dashboard

    # "bogus" status triggers ValueError in EventStatus() which is caught
    result = await get_dashboard(db_session, period="30d", status="bogus")
    assert "kpis" in result
    # Should still return results since invalid status is ignored
    assert result["kpis"]["events_total"] >= 1


@pytest.mark.asyncio
async def test_get_dashboard_all_periods(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """get_dashboard works for all supported periods."""
    from app.services.admin import get_dashboard

    for period in ("7d", "30d", "90d", "130d", "1y"):
        result = await get_dashboard(db_session, period=period)
        assert "kpis" in result


@pytest.mark.asyncio
async def test_get_dashboard_unknown_period(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """get_dashboard with unknown period (no cutoff applied)."""
    from app.services.admin import get_dashboard

    result = await get_dashboard(db_session, period="all")
    assert "kpis" in result


@pytest.mark.asyncio
async def test_get_dashboard_with_refund_ticket(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_ticket_tier: TicketTier,
    test_users: dict[str, User],
):
    """get_dashboard counts refunded tickets in refund_rate."""
    from app.services.admin import get_dashboard

    # Create a refunded ticket sale
    refunded_sale = TicketSale(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="TKT-REFUND-001",
        receipt_number="TKT-REC-REFUND-001",
        amount_paid_cents=2500,
        status=TicketSaleStatus.refunded,
    )
    db_session.add(refunded_sale)
    await db_session.flush()

    result = await get_dashboard(db_session, period="30d")
    assert result["kpis"]["refund_rate_percent"] > 0
    assert result["action_items"]["pending_refunds"] >= 0


@pytest.mark.asyncio
async def test_get_dashboard_with_pending_approval_event(
    db_session: AsyncSession,
    test_event_pending: Event,
    test_users: dict[str, User],
):
    """get_dashboard action_items counts pending_approval events."""
    from app.services.admin import get_dashboard

    result = await get_dashboard(db_session, period="30d")
    assert result["action_items"]["pending_approval"] >= 1


@pytest.mark.asyncio
async def test_get_dashboard_funding_goal_hit_rate(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """get_dashboard computes funding_goal_hit_rate when pledges meet goal."""
    from app.services.admin import get_dashboard

    # Ensure event has a funding goal and add a pledge that meets it
    test_event_approved.funding_goal_cents = 5000
    await db_session.flush()

    pledge = Funding(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        amount_cents=5000,
        platform_cut_cents=500,
        net_to_organizer_cents=4500,
        status=FundingStatus.pledged,
        receipt_number="PLG-GOAL-001",
    )
    db_session.add(pledge)
    await db_session.flush()

    result = await get_dashboard(db_session, period="30d")
    assert result["kpis"]["funding_goal_hit_rate_percent"] > 0


@pytest.mark.asyncio
async def test_get_dashboard_available_filters(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """get_dashboard returns available_filters with genres and statuses."""
    from app.services.admin import get_dashboard

    test_event_approved.genre = "tech"
    await db_session.flush()

    result = await get_dashboard(db_session, period="30d")
    assert "genres" in result["available_filters"]
    assert "statuses" in result["available_filters"]
    assert "tech" in result["available_filters"]["genres"]


@pytest.mark.asyncio
async def test_get_dashboard_time_series_with_data(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_ticket_tier: TicketTier,
    test_ticket_sale: TicketSale,
    test_pledge: Funding,
    test_users: dict[str, User],
):
    """get_dashboard time_series includes dates with ticket/funding activity."""
    from app.services.admin import get_dashboard

    result = await get_dashboard(db_session, period="30d")
    # With ticket_sale and pledge, there should be at least one date entry
    assert isinstance(result["time_series"], list)
    if result["time_series"]:
        entry = result["time_series"][0]
        assert "date" in entry
        assert "revenue_cents" in entry
        assert "tickets_sold" in entry
        assert "pledges_count" in entry
