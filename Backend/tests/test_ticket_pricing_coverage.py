"""
Service-level tests for ticket/pricing.py — compute_ticket_price.
Covers: free tier, common discount, selective (percent + flat), pledge discount,
event discount rules (ticket_percent, pledge_percent, pledger/non-pledger targeting),
milestone discount, early bird discount, discount cap, and combined discounts.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventDiscount
from app.models.ticket import TicketTier, UserEventDiscount
from app.models.funding import Funding, FundingStatus

from app.services.ticket.pricing import compute_ticket_price


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

async def _make_tier(db, event, price_cents=5000, name="GA"):
    tier = TicketTier(event_id=event.id, name=name, price_cents=price_cents, display_order=0)
    db.add(tier)
    await db.flush()
    return tier


async def _make_pledge(db, event, user, amount_cents=3000):
    p = Funding(
        event_id=event.id, user_id=user.id,
        amount_cents=amount_cents, platform_cut_cents=0,
        net_to_organizer_cents=amount_cents,
        status=FundingStatus.pledged, receipt_number=f"PLG-{user.id}",
    )
    db.add(p)
    await db.flush()
    return p


# ===========================================================================
# BASIC: free tier, no discounts
# ===========================================================================

@pytest.mark.asyncio
async def test_free_tier_returns_zeros(db_session, test_event_approved, test_users):
    """Free tier (price_cents=0) returns all zeros immediately."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=0)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["tier_price_cents"] == 0
    assert result["final_price_cents"] == 0
    assert result["total_discount_cents"] == 0


@pytest.mark.asyncio
async def test_no_discounts(db_session, test_event_approved, test_users):
    """Tier with price but no discounts configured — full price."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=5000)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["tier_price_cents"] == 5000
    assert result["final_price_cents"] == 5000
    assert result["total_discount_cents"] == 0


# ===========================================================================
# COMMON DISCOUNT
# ===========================================================================

@pytest.mark.asyncio
async def test_common_discount(db_session, test_event_approved, test_users):
    """Common discount percent applies to base price."""
    test_event_approved.common_discount_percent = 20
    await db_session.flush()
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["common_discount_cents"] == 2000  # 20% of 10000
    assert result["final_price_cents"] == 8000


# ===========================================================================
# SELECTIVE (USER-SPECIFIC) DISCOUNT
# ===========================================================================

@pytest.mark.asyncio
async def test_selective_discount_percent(db_session, test_event_approved, test_users):
    """User-specific percent discount."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    ued = UserEventDiscount(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        discount_type="percent",
        value=15,
    )
    db_session.add(ued)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["selective_discount_cents"] == 1500  # 15% of 10000
    assert result["final_price_cents"] == 8500


@pytest.mark.asyncio
async def test_selective_discount_flat(db_session, test_event_approved, test_users):
    """User-specific flat discount."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    ued = UserEventDiscount(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        discount_type="flat",
        value=3000,
    )
    db_session.add(ued)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["selective_discount_cents"] == 3000
    assert result["final_price_cents"] == 7000


@pytest.mark.asyncio
async def test_selective_discount_flat_capped_at_base(db_session, test_event_approved, test_users):
    """Flat discount cannot exceed base price."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=2000)
    ued = UserEventDiscount(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        discount_type="flat",
        value=5000,
    )
    db_session.add(ued)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["selective_discount_cents"] == 2000  # capped at base


# ===========================================================================
# PLEDGE DISCOUNT
# ===========================================================================

@pytest.mark.asyncio
async def test_pledge_discount(db_session, test_event_approved, test_users):
    """Pledge discount based on user's total pledged amount."""
    test_event_approved.pledge_discount_percent = 10
    await db_session.flush()
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    await _make_pledge(db_session, test_event_approved, test_users["customer"], amount_cents=5000)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["pledge_discount_cents"] > 0


@pytest.mark.asyncio
async def test_pledge_discount_zero_when_no_pledge(db_session, test_event_approved, test_users):
    """No pledge discount when user hasn't pledged."""
    test_event_approved.pledge_discount_percent = 10
    await db_session.flush()
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["pledge_discount_cents"] == 0


@pytest.mark.asyncio
async def test_pledge_discount_capped_at_base(db_session, test_event_approved, test_users):
    """Pledge discount cannot exceed base price."""
    test_event_approved.pledge_discount_percent = 100
    await db_session.flush()
    tier = await _make_tier(db_session, test_event_approved, price_cents=1000)
    await _make_pledge(db_session, test_event_approved, test_users["customer"], amount_cents=50000)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["pledge_discount_cents"] <= 1000  # capped at base


# ===========================================================================
# EVENT DISCOUNTS (EventDiscount rules)
# ===========================================================================

@pytest.mark.asyncio
async def test_event_discount_ticket_percent(db_session, test_event_approved, test_users):
    """EventDiscount with ticket_percent type."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    disc = EventDiscount(
        event_id=test_event_approved.id,
        name="25% ticket discount",
        discount_type="ticket_percent",
        value=25,
        target="all",
    )
    db_session.add(disc)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["event_discount_cents"] == 2500  # 25% of 10000


@pytest.mark.asyncio
async def test_event_discount_pledge_percent(db_session, test_event_approved, test_users):
    """EventDiscount with pledge_percent type (discount on total pledged)."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    await _make_pledge(db_session, test_event_approved, test_users["customer"], amount_cents=8000)
    disc = EventDiscount(
        event_id=test_event_approved.id,
        name="50% pledge discount",
        discount_type="pledge_percent",
        value=50,
        target="all",
    )
    db_session.add(disc)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["event_discount_cents"] == 4000  # 50% of 8000


@pytest.mark.asyncio
async def test_event_discount_pledgers_only(db_session, test_event_approved, test_users):
    """Discount targeting 'pledgers' — skipped for non-pledger."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    disc = EventDiscount(
        event_id=test_event_approved.id,
        name="Pledger-only discount",
        discount_type="ticket_percent",
        value=30,
        target="pledgers",
    )
    db_session.add(disc)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["event_discount_cents"] == 0  # no pledge, skipped


@pytest.mark.asyncio
async def test_event_discount_pledgers_with_pledge(db_session, test_event_approved, test_users):
    """Discount targeting 'pledgers' — applies when user has pledged."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    await _make_pledge(db_session, test_event_approved, test_users["customer"], amount_cents=1000)
    disc = EventDiscount(
        event_id=test_event_approved.id,
        name="Pledger discount",
        discount_type="ticket_percent",
        value=30,
        target="pledgers",
    )
    db_session.add(disc)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["event_discount_cents"] == 3000  # 30% of 10000


@pytest.mark.asyncio
async def test_event_discount_non_pledgers(db_session, test_event_approved, test_users):
    """Discount targeting 'non_pledgers' — applies when user has NOT pledged."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    disc = EventDiscount(
        event_id=test_event_approved.id,
        name="Non-pledger discount",
        discount_type="ticket_percent",
        value=10,
        target="non_pledgers",
    )
    db_session.add(disc)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["event_discount_cents"] == 1000  # non-pledger gets 10%


@pytest.mark.asyncio
async def test_event_discount_non_pledgers_skipped_for_pledger(db_session, test_event_approved, test_users):
    """Discount targeting 'non_pledgers' — skipped when user has pledged."""
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    await _make_pledge(db_session, test_event_approved, test_users["customer"], amount_cents=1000)
    disc = EventDiscount(
        event_id=test_event_approved.id,
        name="Non-pledger discount",
        discount_type="ticket_percent",
        value=10,
        target="non_pledgers",
    )
    db_session.add(disc)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["event_discount_cents"] == 0  # pledger, skipped


# ===========================================================================
# EARLY BIRD DISCOUNT
# ===========================================================================

@pytest.mark.asyncio
async def test_early_bird_ticket_discount(db_session, test_event_approved, test_users):
    """Early bird discount on tickets (within window)."""
    from app.models.milestone import EarlyBirdDiscount
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    ebd = EarlyBirdDiscount(
        event_id=test_event_approved.id,
        applies_to="tickets",
        window_start=datetime.now(timezone.utc) - timedelta(days=1),
        window_end=datetime.now(timezone.utc) + timedelta(days=7),
        discount_type="percent",
        value=20,
    )
    db_session.add(ebd)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["early_bird_discount_cents"] == 2000  # 20% of 10000


@pytest.mark.asyncio
async def test_early_bird_ticket_expired(db_session, test_event_approved, test_users):
    """Early bird discount on tickets — window expired."""
    from app.models.milestone import EarlyBirdDiscount
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    ebd = EarlyBirdDiscount(
        event_id=test_event_approved.id,
        applies_to="tickets",
        window_start=datetime.now(timezone.utc) - timedelta(days=14),
        window_end=datetime.now(timezone.utc) - timedelta(days=1),
        discount_type="percent",
        value=20,
    )
    db_session.add(ebd)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["early_bird_discount_cents"] == 0  # expired


@pytest.mark.asyncio
async def test_early_bird_fixed_cents(db_session, test_event_approved, test_users):
    """Early bird discount with fixed_cents type."""
    from app.models.milestone import EarlyBirdDiscount
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    ebd = EarlyBirdDiscount(
        event_id=test_event_approved.id,
        applies_to="tickets",
        window_start=datetime.now(timezone.utc) - timedelta(days=1),
        window_end=datetime.now(timezone.utc) + timedelta(days=7),
        discount_type="fixed_cents",
        value=1500,
    )
    db_session.add(ebd)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["early_bird_discount_cents"] == 1500


@pytest.mark.asyncio
async def test_early_bird_funding_no_early_pledge(db_session, test_event_approved, test_users):
    """Early bird funding discount — user has no early bird pledge."""
    from app.models.milestone import EarlyBirdDiscount
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    ebd = EarlyBirdDiscount(
        event_id=test_event_approved.id,
        applies_to="funding",
        window_start=datetime.now(timezone.utc) - timedelta(days=1),
        window_end=datetime.now(timezone.utc) + timedelta(days=7),
        discount_type="percent",
        value=15,
    )
    db_session.add(ebd)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["early_bird_discount_cents"] == 0  # no early bird pledge


@pytest.mark.asyncio
async def test_early_bird_funding_with_early_pledge(db_session, test_event_approved, test_users):
    """Early bird funding discount — user has early bird pledge."""
    from app.models.milestone import EarlyBirdDiscount
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    pledge = await _make_pledge(db_session, test_event_approved, test_users["customer"], amount_cents=5000)
    pledge.is_early_bird = True
    await db_session.flush()
    ebd = EarlyBirdDiscount(
        event_id=test_event_approved.id,
        applies_to="funding",
        window_start=datetime.now(timezone.utc) - timedelta(days=1),
        window_end=datetime.now(timezone.utc) + timedelta(days=7),
        discount_type="percent",
        value=15,
    )
    db_session.add(ebd)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["early_bird_discount_cents"] == 1500  # 15% of 10000


# ===========================================================================
# DISCOUNT CAP
# ===========================================================================

@pytest.mark.asyncio
async def test_discount_capped(db_session, test_event_approved, test_users):
    """Total discount is capped by max_discount_percent."""
    test_event_approved.common_discount_percent = 50
    test_event_approved.max_discount_percent = 30  # cap at 30%
    await db_session.flush()
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["total_discount_cents"] == 3000  # capped at 30%
    assert result["final_price_cents"] == 7000
    assert result["discount_capped"] is True


@pytest.mark.asyncio
async def test_discount_not_capped(db_session, test_event_approved, test_users):
    """Discount below cap — discount_capped is False."""
    test_event_approved.common_discount_percent = 10
    test_event_approved.max_discount_percent = 100
    await db_session.flush()
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["discount_capped"] is False


# ===========================================================================
# COMBINED DISCOUNTS
# ===========================================================================

@pytest.mark.asyncio
async def test_combined_discounts(db_session, test_event_approved, test_users):
    """Multiple discount types stack correctly."""
    test_event_approved.common_discount_percent = 10
    test_event_approved.pledge_discount_percent = 5
    test_event_approved.max_discount_percent = 100
    await db_session.flush()
    tier = await _make_tier(db_session, test_event_approved, price_cents=10000)
    await _make_pledge(db_session, test_event_approved, test_users["customer"], amount_cents=10000)
    disc = EventDiscount(
        event_id=test_event_approved.id,
        name="5% ticket discount",
        discount_type="ticket_percent",
        value=5,
        target="all",
    )
    db_session.add(disc)
    await db_session.flush()
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["common_discount_cents"] == 1000
    assert result["event_discount_cents"] == 500
    assert result["pledge_discount_cents"] > 0
    assert result["final_price_cents"] < 10000
    assert result["final_price_cents"] >= 0


@pytest.mark.asyncio
async def test_final_price_never_negative(db_session, test_event_approved, test_users):
    """Final price is always >= 0 even with extreme discounts."""
    test_event_approved.common_discount_percent = 100
    test_event_approved.max_discount_percent = 100
    await db_session.flush()
    tier = await _make_tier(db_session, test_event_approved, price_cents=1000)
    with patch("app.services.event.crud.auto_transition_status", new_callable=AsyncMock, side_effect=lambda db, e: e):
        result = await compute_ticket_price(
            db_session, event_id=test_event_approved.id,
            user_id=test_users["customer"].id, tier_id=tier.id,
        )
    assert result["final_price_cents"] == 0
