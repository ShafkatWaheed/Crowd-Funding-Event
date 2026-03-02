"""
Tests for app.services.ticket.sales — purchase_ticket + get_purchase_group_tickets.

Covers lines 27-210 (purchase_ticket) and 213-232 (get_purchase_group_tickets)
to raise coverage from ~65 % to 70 %+.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.ticket import TicketSaleStatus


# ---------------------------------------------------------------------------
# Helpers — patch context managers used across many tests
# ---------------------------------------------------------------------------

def _platform_settings_patches(
    max_backend_enabled: bool = False,
    max_per_purchase: int = 10,
    commission_pct: int = 10,
    community_commission: str | None = None,
):
    """Return nested context-managers that mock platform_settings calls.

    The purchase_ticket function calls:
      - settings_svc.get_bool(db, "max_tickets_backend_enabled")
      - settings_svc.get_int(db, "max_tickets_per_purchase")
      - settings_svc.get_int(db, "ticket_commission_percent")
      - settings_svc.get_str(db, "community_ticket_commission_percent")
    """

    async def _mock_get_bool(db, key):
        if key == "max_tickets_backend_enabled":
            return max_backend_enabled
        return False

    async def _mock_get_int(db, key):
        if key == "max_tickets_per_purchase":
            return max_per_purchase
        if key == "ticket_commission_percent":
            return commission_pct
        return 0

    async def _mock_get_str(db, key):
        if key == "community_ticket_commission_percent":
            return community_commission
        return None

    return (
        patch("app.services.platform_settings.get_bool", side_effect=_mock_get_bool),
        patch("app.services.platform_settings.get_int", side_effect=_mock_get_int),
        patch("app.services.platform_settings.get_str", side_effect=_mock_get_str),
    )


def _price_patch(final_price_cents: int = 2500, total_discount_cents: int = 0, tier_price_cents: int = 2500):
    """Mock compute_ticket_price to return a known dict."""
    return patch(
        "app.services.ticket.sales.compute_ticket_price",
        new_callable=AsyncMock,
        return_value={
            "final_price_cents": final_price_cents,
            "total_discount_cents": total_discount_cents,
            "tier_price_cents": tier_price_cents,
        },
    )


def _gateway_patch(status: str = "success", txn_id: str = "tx-1", auth_code: str = "auth-1"):
    """Mock the payment gateway for paid tickets."""
    return patch(
        "app.services.payment_gateway.get_gateway",
        new_callable=AsyncMock,
    )


def _gateway_result(status="success", txn_id="tx-1", auth_code="auth-1", failure_reason=None):
    mock_result = MagicMock(
        status=status,
        transaction_id=txn_id,
        authorization_code=auth_code,
    )
    if failure_reason:
        mock_result.failure_reason = failure_reason
    return mock_result


# ---------------------------------------------------------------------------
# 1. Invalid quantity — 0
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_quantity_zero_raises(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    with pytest.raises(ConflictError, match="Quantity must be at least 1"):
        await purchase_ticket(
            db_session,
            event_id=test_event_approved.id,
            user=test_users["customer"],
            tier_id=test_ticket_tier.id,
            quantity=0,
        )


# ---------------------------------------------------------------------------
# 2. Invalid quantity — negative
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_quantity_negative_raises(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    with pytest.raises(ConflictError, match="Quantity must be at least 1"):
        await purchase_ticket(
            db_session,
            event_id=test_event_approved.id,
            user=test_users["customer"],
            tier_id=test_ticket_tier.id,
            quantity=-1,
        )


# ---------------------------------------------------------------------------
# 3. Exceeds max_tickets_per_purchase (backend-enforced)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_exceeds_max_tickets_per_purchase(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches(
        max_backend_enabled=True, max_per_purchase=2,
    )
    with p_bool, p_int, p_str:
        with pytest.raises(ConflictError, match="Quantity must not exceed 2"):
            await purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=test_users["customer"],
                tier_id=test_ticket_tier.id,
                quantity=5,
            )


# ---------------------------------------------------------------------------
# 4. Not registered — purchase fails
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_not_registered_raises(db_session, test_event_approved, test_ticket_tier, test_users):
    """No test_registration fixture → should fail at the registration check."""
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches()
    with p_bool, p_int, p_str:
        with _price_patch():
            with pytest.raises(ConflictError, match="Only registered attendees"):
                await purchase_ticket(
                    db_session,
                    event_id=test_event_approved.id,
                    user=test_users["customer"],
                    tier_id=test_ticket_tier.id,
                    quantity=1,
                )


# ---------------------------------------------------------------------------
# 5. Happy path — free ticket (amount=0, no payment gateway)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_free_ticket(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches()
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=0, total_discount_cents=0, tier_price_cents=0):
            sales = await purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=test_users["customer"],
                tier_id=test_ticket_tier.id,
                quantity=1,
            )

    assert len(sales) == 1
    sale = sales[0]
    assert sale.status == TicketSaleStatus.purchased
    assert sale.amount_paid_cents == 0
    assert sale.commission_cents == 0
    assert sale.net_to_organizer_cents == 0
    assert sale.receipt_number is not None
    assert sale.ticket_code is not None
    assert sale.purchase_group_id is None  # single ticket → no group


# ---------------------------------------------------------------------------
# 6. Happy path — paid ticket
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_paid_ticket(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches(commission_pct=10)
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            with _gateway_patch() as mock_gw:
                mock_gw.return_value.charge = AsyncMock(
                    return_value=_gateway_result()
                )
                sales = await purchase_ticket(
                    db_session,
                    event_id=test_event_approved.id,
                    user=test_users["customer"],
                    tier_id=test_ticket_tier.id,
                    quantity=1,
                )

    assert len(sales) == 1
    sale = sales[0]
    assert sale.status == TicketSaleStatus.purchased
    assert sale.amount_paid_cents == 2500
    assert sale.commission_cents == 250  # 10% of 2500
    assert sale.net_to_organizer_cents == 2250
    assert sale.gateway_transaction_id == "tx-1"
    assert sale.gateway_auth_code == "auth-1"
    assert sale.receipt_number is not None


# ---------------------------------------------------------------------------
# 7. Multiple tickets (quantity > 1) — group purchase
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_multiple_tickets_group(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches(commission_pct=10)
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            with _gateway_patch() as mock_gw:
                mock_gw.return_value.charge = AsyncMock(
                    return_value=_gateway_result()
                )
                sales = await purchase_ticket(
                    db_session,
                    event_id=test_event_approved.id,
                    user=test_users["customer"],
                    tier_id=test_ticket_tier.id,
                    quantity=3,
                )

    assert len(sales) == 3
    group_ids = {s.purchase_group_id for s in sales}
    assert len(group_ids) == 1  # all same group
    assert None not in group_ids  # group id is set
    for s in sales:
        assert s.status == TicketSaleStatus.purchased
        assert s.amount_paid_cents == 2500


# ---------------------------------------------------------------------------
# 8. Payment gateway failure (status="failed")
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_payment_gateway_failure(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches(commission_pct=10)
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            with _gateway_patch() as mock_gw:
                mock_gw.return_value.charge = AsyncMock(
                    return_value=_gateway_result(status="failed", failure_reason="card declined")
                )
                with pytest.raises(ConflictError, match="Payment failed"):
                    await purchase_ticket(
                        db_session,
                        event_id=test_event_approved.id,
                        user=test_users["customer"],
                        tier_id=test_ticket_tier.id,
                        quantity=1,
                    )


# ---------------------------------------------------------------------------
# 9. Payment gateway exception
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_payment_gateway_exception(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches(commission_pct=10)
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            with _gateway_patch() as mock_gw:
                mock_gw.return_value.charge = AsyncMock(
                    side_effect=RuntimeError("Network timeout")
                )
                with pytest.raises(ConflictError, match="Payment processing error"):
                    await purchase_ticket(
                        db_session,
                        event_id=test_event_approved.id,
                        user=test_users["customer"],
                        tier_id=test_ticket_tier.id,
                        quantity=1,
                    )


# ---------------------------------------------------------------------------
# 10. Waitlisted — capacity exceeded
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_waitlisted_capacity_exceeded(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket
    from app.models.ticket import TicketSale

    # Set capacity to 1 and insert one existing purchased ticket to fill it
    test_event_approved.max_capacity = 1
    await db_session.flush()

    existing_sale = TicketSale(
        event_id=test_event_approved.id,
        user_id=test_users["organizer"].id,  # different user
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="EXIST-001",
        receipt_number="RCP-EXIST-001",
        amount_paid_cents=2500,
        status=TicketSaleStatus.purchased,
    )
    db_session.add(existing_sale)
    await db_session.flush()

    p_bool, p_int, p_str = _platform_settings_patches()
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            # No gateway mock needed — waitlisted tickets don't get charged
            sales = await purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=test_users["customer"],
                tier_id=test_ticket_tier.id,
                quantity=1,
            )

    assert len(sales) == 1
    assert sales[0].status == TicketSaleStatus.waitlisted


# ---------------------------------------------------------------------------
# 11. With reserved spots — consume_one_reserved_spot
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_with_reserved_spots(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket
    from app.models.funding import Funding, FundingStatus

    # Create a pledge with reserved_spots = 1 for the customer
    pledge = Funding(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        amount_cents=5000,
        platform_cut_cents=500,
        net_to_organizer_cents=4500,
        status=FundingStatus.pledged,
        reserved_spots=1,
        receipt_number="PLG-RESV-001",
    )
    db_session.add(pledge)
    await db_session.flush()

    p_bool, p_int, p_str = _platform_settings_patches(commission_pct=10)
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            with _gateway_patch() as mock_gw:
                mock_gw.return_value.charge = AsyncMock(
                    return_value=_gateway_result()
                )
                sales = await purchase_ticket(
                    db_session,
                    event_id=test_event_approved.id,
                    user=test_users["customer"],
                    tier_id=test_ticket_tier.id,
                    quantity=1,
                )

    assert len(sales) == 1
    assert sales[0].status == TicketSaleStatus.purchased

    # Verify the reserved spot was consumed
    await db_session.refresh(pledge)
    assert pledge.reserved_spots == 0


# ---------------------------------------------------------------------------
# 12. Tier-linked funding — consume_reserved_spots_for_tier
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_tier_linked_funding(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket
    from app.models.funding import Funding, FundingStatus, PledgeSpotReservation

    # Enable tier-linked funding
    test_event_approved.link_funding_to_tiers = True
    await db_session.flush()

    # Create a pledge with reserved spots
    pledge = Funding(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        amount_cents=5000,
        platform_cut_cents=500,
        net_to_organizer_cents=4500,
        status=FundingStatus.pledged,
        reserved_spots=1,
        receipt_number="PLG-TIER-001",
    )
    db_session.add(pledge)
    await db_session.flush()

    # Create a PledgeSpotReservation linking the pledge to the ticket tier
    psr = PledgeSpotReservation(
        funding_id=pledge.id,
        ticket_tier_id=test_ticket_tier.id,
        spots=1,
    )
    db_session.add(psr)
    await db_session.flush()

    p_bool, p_int, p_str = _platform_settings_patches(commission_pct=10)
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            with _gateway_patch() as mock_gw:
                mock_gw.return_value.charge = AsyncMock(
                    return_value=_gateway_result()
                )
                sales = await purchase_ticket(
                    db_session,
                    event_id=test_event_approved.id,
                    user=test_users["customer"],
                    tier_id=test_ticket_tier.id,
                    quantity=1,
                )

    assert len(sales) == 1
    assert sales[0].status == TicketSaleStatus.purchased

    # Verify tier-specific reservation was consumed
    await db_session.refresh(psr)
    assert psr.spots == 0


# ---------------------------------------------------------------------------
# 13. Community rules commission override
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_community_rules_commission(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    # Enable community_rules on the event
    test_event_approved.community_rules = True
    await db_session.flush()

    # Community commission = 5% instead of default 10%
    p_bool, p_int, p_str = _platform_settings_patches(
        commission_pct=10,
        community_commission="5",
    )
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2000, total_discount_cents=500, tier_price_cents=2500):
            with _gateway_patch() as mock_gw:
                mock_gw.return_value.charge = AsyncMock(
                    return_value=_gateway_result()
                )
                sales = await purchase_ticket(
                    db_session,
                    event_id=test_event_approved.id,
                    user=test_users["customer"],
                    tier_id=test_ticket_tier.id,
                    quantity=1,
                )

    assert len(sales) == 1
    sale = sales[0]
    assert sale.status == TicketSaleStatus.purchased
    # 5% of 2000 = 100
    assert sale.commission_cents == 100
    assert sale.net_to_organizer_cents == 1900


# ---------------------------------------------------------------------------
# 14. Extra perks passed through
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_with_extra_perks(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches()
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=0, total_discount_cents=0, tier_price_cents=0):
            sales = await purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=test_users["customer"],
                tier_id=test_ticket_tier.id,
                quantity=1,
                extra_perks="VIP backstage pass",
            )

    assert len(sales) == 1
    assert sales[0].extra_perks == "VIP backstage pass"


# ---------------------------------------------------------------------------
# 15. Max tickets backend enabled but quantity within limit
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_within_max_tickets_limit(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches(
        max_backend_enabled=True, max_per_purchase=5, commission_pct=10,
    )
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            with _gateway_patch() as mock_gw:
                mock_gw.return_value.charge = AsyncMock(
                    return_value=_gateway_result()
                )
                sales = await purchase_ticket(
                    db_session,
                    event_id=test_event_approved.id,
                    user=test_users["customer"],
                    tier_id=test_ticket_tier.id,
                    quantity=3,
                )

    assert len(sales) == 3
    for s in sales:
        assert s.status == TicketSaleStatus.purchased


# ---------------------------------------------------------------------------
# 16. Discount applied — total_discount > 0 and equals tier price (extra_perks="")
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_full_discount_extra_perks_empty_string(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    """When total_discount_cents >= tier_price_cents and no extra_perks provided,
    extra_perks should be set to empty string (line 168 logic)."""
    from app.services.ticket.sales import purchase_ticket

    p_bool, p_int, p_str = _platform_settings_patches()
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=0, total_discount_cents=2500, tier_price_cents=2500):
            sales = await purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=test_users["customer"],
                tier_id=test_ticket_tier.id,
                quantity=1,
            )

    assert len(sales) == 1
    # When total_discount >= tier_price and no extra_perks arg, extra_perks is ""
    assert sales[0].extra_perks == ""


# ---------------------------------------------------------------------------
# 17. get_purchase_group_tickets — not found
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_purchase_group_not_found(db_session):
    from app.services.ticket.sales import get_purchase_group_tickets

    with pytest.raises(NotFoundError):
        await get_purchase_group_tickets(db_session, purchase_group_id="nonexistent-group-id")


# ---------------------------------------------------------------------------
# 18. get_purchase_group_tickets — happy path
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_purchase_group_happy_path(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    """Purchase multiple tickets, then retrieve them by group ID."""
    from app.services.ticket.sales import purchase_ticket, get_purchase_group_tickets

    p_bool, p_int, p_str = _platform_settings_patches()
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=0, total_discount_cents=0, tier_price_cents=0):
            sales = await purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=test_users["customer"],
                tier_id=test_ticket_tier.id,
                quantity=2,
            )

    group_id = sales[0].purchase_group_id
    assert group_id is not None

    result = await get_purchase_group_tickets(db_session, purchase_group_id=group_id)
    assert len(result) == 2
    assert all(s.purchase_group_id == group_id for s in result)


# ---------------------------------------------------------------------------
# 19. get_purchase_group_tickets — wrong user (Forbidden)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_purchase_group_wrong_user(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    from app.services.ticket.sales import purchase_ticket, get_purchase_group_tickets

    p_bool, p_int, p_str = _platform_settings_patches()
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=0, total_discount_cents=0, tier_price_cents=0):
            sales = await purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=test_users["customer"],
                tier_id=test_ticket_tier.id,
                quantity=2,
            )

    group_id = sales[0].purchase_group_id
    assert group_id is not None

    # Pass a different user_id → should raise ForbiddenError
    with pytest.raises(ForbiddenError, match="your own purchase groups"):
        await get_purchase_group_tickets(
            db_session,
            purchase_group_id=group_id,
            user_id=test_users["organizer"].id,
        )


# ---------------------------------------------------------------------------
# 20. Waitlisted tickets don't charge the gateway
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_purchase_waitlisted_no_payment_charge(db_session, test_event_approved, test_ticket_tier, test_users, test_registration):
    """When capacity is exceeded, tickets are waitlisted and no payment is attempted."""
    from app.services.ticket.sales import purchase_ticket
    from app.models.ticket import TicketSale

    # Fill the event to capacity
    test_event_approved.max_capacity = 1
    await db_session.flush()
    existing = TicketSale(
        event_id=test_event_approved.id,
        user_id=test_users["organizer"].id,
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="FILL-001",
        receipt_number="RCP-FILL-001",
        amount_paid_cents=2500,
        status=TicketSaleStatus.purchased,
    )
    db_session.add(existing)
    await db_session.flush()

    p_bool, p_int, p_str = _platform_settings_patches(commission_pct=10)
    with p_bool, p_int, p_str:
        with _price_patch(final_price_cents=2500, total_discount_cents=0, tier_price_cents=2500):
            # No gateway mock → if purchase_ticket tries to charge, it will error
            # Since waitlisted tickets skip payment, this should succeed.
            sales = await purchase_ticket(
                db_session,
                event_id=test_event_approved.id,
                user=test_users["customer"],
                tier_id=test_ticket_tier.id,
                quantity=1,
            )

    assert len(sales) == 1
    assert sales[0].status == TicketSaleStatus.waitlisted
    assert sales[0].gateway_transaction_id is None
    assert sales[0].gateway_auth_code is None
