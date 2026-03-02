"""
Phase 5 — Domain gap coverage tests.

Covers three services below 70% coverage:
  1. sponsor/categories.py  (templates, copy, bid stats)
  2. funding/reservations.py (tier-linked spot reservations)
  3. funding/pledges.py      (create_pledge with tiers, milestones, early bird)
"""
import pytest
import pytest_asyncio
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus, PledgeSpotReservation
from app.models.milestone import (
    FundingMilestone,
    FundingMilestoneSnapshot,
    FundingMilestoneUser,
    EarlyBirdDiscount,
)
from app.models.prerequisite import CategoryPrerequisite
from app.models.registration import Registration, RegistrationStatus
from app.models.sponsor import SponsorshipCategory, SponsorBid, BidStatus
from app.models.ticket import TicketTier, TicketSale, TicketSaleStatus
from app.models.user import User, UserRole
from app.schemas.sponsor import CategoryCreate, CategoryUpdate

# ── Services under test ──
from app.services.sponsor import categories as cat_svc
from app.services.funding import reservations as res_svc
from app.services.funding import pledges as pledge_svc


# ═══════════════════════════════════════════════════════════════════════════
# SECTION 1 — sponsor/categories.py
# ═══════════════════════════════════════════════════════════════════════════


class TestListTemplates:
    """list_templates() — line 99-105."""

    @pytest.mark.asyncio
    async def test_list_templates_returns_user_templates(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        organizer = test_users["organizer"]
        t1 = SponsorshipCategory(
            event_id=None,
            organizer_id=organizer.id,
            is_template=True,
            name="Alpha Template",
            total_spots=5,
            min_bid_cents=1000,
        )
        t2 = SponsorshipCategory(
            event_id=None,
            organizer_id=organizer.id,
            is_template=True,
            name="Beta Template",
            total_spots=3,
            min_bid_cents=2000,
        )
        db_session.add_all([t1, t2])
        await db_session.flush()

        result = await cat_svc.list_templates(db_session, organizer)
        names = [c.name for c in result]
        # ordered by name
        assert names == ["Alpha Template", "Beta Template"]

    @pytest.mark.asyncio
    async def test_list_templates_excludes_other_users(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        organizer = test_users["organizer"]
        customer = test_users["customer"]
        db_session.add(
            SponsorshipCategory(
                event_id=None,
                organizer_id=organizer.id,
                is_template=True,
                name="Org Template",
                total_spots=1,
                min_bid_cents=500,
            )
        )
        await db_session.flush()

        result = await cat_svc.list_templates(db_session, customer)
        assert result == []

    @pytest.mark.asyncio
    async def test_list_templates_empty(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        result = await cat_svc.list_templates(db_session, test_users["organizer"])
        assert result == []


class TestTemplateCRUD:
    """update_template() / delete_template() — lines 126-157."""

    @pytest.mark.asyncio
    async def test_update_template_success(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        organizer = test_users["organizer"]
        tmpl = SponsorshipCategory(
            event_id=None,
            organizer_id=organizer.id,
            is_template=True,
            name="Old Name",
            total_spots=5,
            min_bid_cents=1000,
        )
        db_session.add(tmpl)
        await db_session.flush()

        updated = await cat_svc.update_template(
            db_session, tmpl.id, organizer, CategoryUpdate(name="New Name")
        )
        assert updated.name == "New Name"

    @pytest.mark.asyncio
    async def test_update_template_not_found(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            await cat_svc.update_template(
                db_session, 99999, test_users["organizer"], CategoryUpdate(name="X")
            )
        assert exc_info.value.status_code == 404

    @pytest.mark.asyncio
    async def test_update_template_forbidden(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        organizer = test_users["organizer"]
        customer = test_users["customer"]
        tmpl = SponsorshipCategory(
            event_id=None,
            organizer_id=organizer.id,
            is_template=True,
            name="Mine",
            total_spots=2,
            min_bid_cents=500,
        )
        db_session.add(tmpl)
        await db_session.flush()

        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            await cat_svc.update_template(
                db_session, tmpl.id, customer, CategoryUpdate(name="Stolen")
            )
        assert exc_info.value.status_code == 403

    @pytest.mark.asyncio
    async def test_delete_template_success(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        organizer = test_users["organizer"]
        tmpl = SponsorshipCategory(
            event_id=None,
            organizer_id=organizer.id,
            is_template=True,
            name="Doomed",
            total_spots=1,
            min_bid_cents=500,
        )
        db_session.add(tmpl)
        await db_session.flush()
        tmpl_id = tmpl.id

        await cat_svc.delete_template(db_session, tmpl_id, organizer)

        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            await cat_svc._get_category(db_session, tmpl_id)
        assert exc_info.value.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_template_not_found(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            await cat_svc.delete_template(db_session, 99999, test_users["organizer"])
        assert exc_info.value.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_template_forbidden(
        self, db_session: AsyncSession, test_users: dict[str, User]
    ):
        organizer = test_users["organizer"]
        customer = test_users["customer"]
        tmpl = SponsorshipCategory(
            event_id=None,
            organizer_id=organizer.id,
            is_template=True,
            name="Protected",
            total_spots=1,
            min_bid_cents=500,
        )
        db_session.add(tmpl)
        await db_session.flush()

        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            await cat_svc.delete_template(db_session, tmpl.id, customer)
        assert exc_info.value.status_code == 403


class TestCopyTemplateToEvent:
    """copy_template_to_event() — lines 160-206."""

    @pytest.mark.asyncio
    async def test_copy_template_basic(
        self,
        db_session: AsyncSession,
        test_users: dict[str, User],
        test_event_approved: Event,
    ):
        organizer = test_users["organizer"]
        tmpl = SponsorshipCategory(
            event_id=None,
            organizer_id=organizer.id,
            is_template=True,
            name="Gold Template",
            description="Gold level sponsor",
            total_spots=3,
            min_bid_cents=5000,
            sort_order=1,
        )
        db_session.add(tmpl)
        await db_session.flush()

        copied = await cat_svc.copy_template_to_event(
            db_session, tmpl.id, test_event_approved.id, organizer
        )
        assert copied.name == "Gold Template"
        assert copied.description == "Gold level sponsor"
        assert copied.is_template is False
        assert copied.event_id == test_event_approved.id
        assert copied.total_spots == 3
        assert copied.min_bid_cents == 5000

    @pytest.mark.asyncio
    async def test_copy_template_with_prerequisites(
        self,
        db_session: AsyncSession,
        test_users: dict[str, User],
        test_event_approved: Event,
    ):
        organizer = test_users["organizer"]
        tmpl = SponsorshipCategory(
            event_id=None,
            organizer_id=organizer.id,
            is_template=True,
            name="Premium Template",
            total_spots=2,
            min_bid_cents=10000,
        )
        db_session.add(tmpl)
        await db_session.flush()

        prereq1 = CategoryPrerequisite(
            category_id=tmpl.id,
            name="Business License",
            description="Must have a valid business license",
            is_required=True,
        )
        prereq2 = CategoryPrerequisite(
            category_id=tmpl.id,
            name="Insurance Certificate",
            description="Proof of liability insurance",
            is_required=False,
        )
        db_session.add_all([prereq1, prereq2])
        await db_session.flush()

        copied = await cat_svc.copy_template_to_event(
            db_session, tmpl.id, test_event_approved.id, organizer
        )
        assert copied.is_template is False
        assert copied.event_id == test_event_approved.id

        # Verify prerequisites were copied
        from sqlalchemy import select

        prereq_q = select(CategoryPrerequisite).where(
            CategoryPrerequisite.category_id == copied.id
        )
        copied_prereqs = list(
            (await db_session.execute(prereq_q)).scalars().all()
        )
        assert len(copied_prereqs) == 2
        names = sorted([p.name for p in copied_prereqs])
        assert names == ["Business License", "Insurance Certificate"]

    @pytest.mark.asyncio
    async def test_copy_template_not_found(
        self,
        db_session: AsyncSession,
        test_users: dict[str, User],
        test_event_approved: Event,
    ):
        from fastapi import HTTPException

        with pytest.raises(HTTPException) as exc_info:
            await cat_svc.copy_template_to_event(
                db_session, 99999, test_event_approved.id, test_users["organizer"]
            )
        assert exc_info.value.status_code == 404


class TestBidStats:
    """get_bid_stats(), get_my_bid_count(), get_my_bids() — lines 209-241."""

    @pytest.mark.asyncio
    async def test_get_bid_stats(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        cat = SponsorshipCategory(
            event_id=test_event_approved.id,
            name="Stat Cat",
            total_spots=5,
            min_bid_cents=1000,
        )
        db_session.add(cat)
        await db_session.flush()

        customer = test_users["customer"]
        organizer = test_users["organizer"]
        bids = [
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=customer.id,
                amount_cents=2000,
                status=BidStatus.pending,
            ),
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=organizer.id,
                amount_cents=3000,
                status=BidStatus.accepted,
            ),
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=customer.id,
                amount_cents=1000,
                status=BidStatus.withdrawn,
            ),
        ]
        db_session.add_all(bids)
        await db_session.flush()

        total_active, pending_amounts = await cat_svc.get_bid_stats(
            db_session, cat.id
        )
        # withdrawn excluded; pending + accepted = 2 active
        assert total_active == 2
        assert pending_amounts == [2000]

    @pytest.mark.asyncio
    async def test_get_bid_stats_with_paid(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        cat = SponsorshipCategory(
            event_id=test_event_approved.id,
            name="Paid Cat",
            total_spots=5,
            min_bid_cents=1000,
        )
        db_session.add(cat)
        await db_session.flush()

        bid = SponsorBid(
            category_id=cat.id,
            sponsor_user_id=test_users["customer"].id,
            amount_cents=5000,
            status=BidStatus.paid,
        )
        db_session.add(bid)
        await db_session.flush()

        total_active, pending_amounts = await cat_svc.get_bid_stats(
            db_session, cat.id
        )
        assert total_active == 1
        assert pending_amounts == []  # paid is not pending

    @pytest.mark.asyncio
    async def test_get_my_bid_count(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        cat = SponsorshipCategory(
            event_id=test_event_approved.id,
            name="Count Cat",
            total_spots=5,
            min_bid_cents=1000,
        )
        db_session.add(cat)
        await db_session.flush()

        customer = test_users["customer"]
        bids = [
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=customer.id,
                amount_cents=2000,
                status=BidStatus.pending,
            ),
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=customer.id,
                amount_cents=3000,
                status=BidStatus.accepted,
            ),
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=customer.id,
                amount_cents=1000,
                status=BidStatus.withdrawn,
            ),
        ]
        db_session.add_all(bids)
        await db_session.flush()

        count = await cat_svc.get_my_bid_count(db_session, cat.id, customer.id)
        assert count == 2  # pending + accepted; withdrawn excluded

    @pytest.mark.asyncio
    async def test_get_my_bids(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        cat = SponsorshipCategory(
            event_id=test_event_approved.id,
            name="My Bids Cat",
            total_spots=5,
            min_bid_cents=1000,
        )
        db_session.add(cat)
        await db_session.flush()

        customer = test_users["customer"]
        bids = [
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=customer.id,
                amount_cents=2000,
                status=BidStatus.pending,
            ),
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=customer.id,
                amount_cents=3000,
                status=BidStatus.accepted,
            ),
            SponsorBid(
                category_id=cat.id,
                sponsor_user_id=customer.id,
                amount_cents=1000,
                status=BidStatus.withdrawn,
            ),
        ]
        db_session.add_all(bids)
        await db_session.flush()

        result = await cat_svc.get_my_bids(db_session, cat.id, customer.id)
        # withdrawn excluded from get_my_bids
        assert len(result) == 2
        assert all("id" in r and "amount_cents" in r and "status" in r for r in result)
        statuses = {r["status"] for r in result}
        assert statuses == {"pending", "accepted"}

    @pytest.mark.asyncio
    async def test_get_my_bids_empty(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        cat = SponsorshipCategory(
            event_id=test_event_approved.id,
            name="Empty Cat",
            total_spots=5,
            min_bid_cents=1000,
        )
        db_session.add(cat)
        await db_session.flush()

        result = await cat_svc.get_my_bids(
            db_session, cat.id, test_users["customer"].id
        )
        assert result == []


# ═══════════════════════════════════════════════════════════════════════════
# SECTION 2 — funding/reservations.py  (tier-linked reservations)
# ═══════════════════════════════════════════════════════════════════════════


_pledge_counter = 0


async def _make_pledge_with_tier_reservation(
    db: AsyncSession,
    event: Event,
    user: User,
    tier: TicketTier,
    amount_cents: int,
    spots: int,
) -> tuple[Funding, PledgeSpotReservation]:
    """Helper: create a pledge + PledgeSpotReservation row."""
    global _pledge_counter
    _pledge_counter += 1
    pledge = Funding(
        event_id=event.id,
        user_id=user.id,
        amount_cents=amount_cents,
        platform_cut_cents=0,
        net_to_organizer_cents=amount_cents,
        status=FundingStatus.pledged,
        reserved_spots=spots,
        receipt_number=f"PLG-TIER-{event.id}-{user.id}-{tier.id}-{_pledge_counter}",
    )
    db.add(pledge)
    await db.flush()
    psr = PledgeSpotReservation(
        funding_id=pledge.id,
        ticket_tier_id=tier.id,
        spots=spots,
    )
    db.add(psr)
    await db.flush()
    return pledge, psr


class TestGetReservedSpotsForTiers:
    """get_reserved_spots_for_tiers() — lines 77-97."""

    @pytest.mark.asyncio
    async def test_returns_totals_per_tier(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, customer, test_ticket_tier, 5000, 2
        )
        result = await res_svc.get_reserved_spots_for_tiers(
            db_session, test_event_approved.id, [test_ticket_tier.id]
        )
        assert result[test_ticket_tier.id] == 2

    @pytest.mark.asyncio
    async def test_empty_tier_ids(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
    ):
        result = await res_svc.get_reserved_spots_for_tiers(
            db_session, test_event_approved.id, []
        )
        assert result == {}

    @pytest.mark.asyncio
    async def test_multiple_pledgers_sum(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        organizer = test_users["organizer"]
        await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, customer, test_ticket_tier, 5000, 2
        )
        await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, organizer, test_ticket_tier, 5000, 3
        )
        result = await res_svc.get_reserved_spots_for_tiers(
            db_session, test_event_approved.id, [test_ticket_tier.id]
        )
        assert result[test_ticket_tier.id] == 5


class TestGetReservedSpotsForTier:
    """get_reserved_spots_for_tier() — lines 100-112."""

    @pytest.mark.asyncio
    async def test_returns_total_for_single_tier(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        await _make_pledge_with_tier_reservation(
            db_session,
            test_event_approved,
            test_users["customer"],
            test_ticket_tier,
            5000,
            3,
        )
        result = await res_svc.get_reserved_spots_for_tier(
            db_session, test_event_approved.id, test_ticket_tier.id
        )
        assert result == 3

    @pytest.mark.asyncio
    async def test_returns_zero_when_no_reservations(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
    ):
        result = await res_svc.get_reserved_spots_for_tier(
            db_session, test_event_approved.id, test_ticket_tier.id
        )
        assert result == 0


class TestGetUserReservedSpotsForTier:
    """get_user_reserved_spots_for_tier() — lines 115-130."""

    @pytest.mark.asyncio
    async def test_returns_user_spots(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, customer, test_ticket_tier, 5000, 2
        )
        result = await res_svc.get_user_reserved_spots_for_tier(
            db_session, test_event_approved.id, customer.id, test_ticket_tier.id
        )
        assert result == 2

    @pytest.mark.asyncio
    async def test_excludes_other_users(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        organizer = test_users["organizer"]
        await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, organizer, test_ticket_tier, 5000, 3
        )
        result = await res_svc.get_user_reserved_spots_for_tier(
            db_session,
            test_event_approved.id,
            test_users["customer"].id,
            test_ticket_tier.id,
        )
        assert result == 0


class TestConsumeReservedSpotsForTier:
    """consume_reserved_spots_for_tier() — lines 133-163."""

    @pytest.mark.asyncio
    async def test_consume_decrements_spots(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        pledge, psr = await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, customer, test_ticket_tier, 5000, 3
        )

        await res_svc.consume_reserved_spots_for_tier(
            db_session,
            test_event_approved.id,
            customer.id,
            test_ticket_tier.id,
            1,
        )
        await db_session.refresh(psr)
        await db_session.refresh(pledge)
        assert psr.spots == 2
        assert pledge.reserved_spots == 2

    @pytest.mark.asyncio
    async def test_consume_multiple_spots(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        pledge, psr = await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, customer, test_ticket_tier, 5000, 5
        )
        await res_svc.consume_reserved_spots_for_tier(
            db_session,
            test_event_approved.id,
            customer.id,
            test_ticket_tier.id,
            3,
        )
        await db_session.refresh(psr)
        await db_session.refresh(pledge)
        assert psr.spots == 2
        assert pledge.reserved_spots == 2

    @pytest.mark.asyncio
    async def test_consume_across_multiple_pledges(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        pledge1, psr1 = await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, customer, test_ticket_tier, 2500, 1
        )
        pledge2, psr2 = await _make_pledge_with_tier_reservation(
            db_session, test_event_approved, customer, test_ticket_tier, 5000, 2
        )
        # Consume 2 spots: should consume 1 from pledge1, 1 from pledge2
        await res_svc.consume_reserved_spots_for_tier(
            db_session,
            test_event_approved.id,
            customer.id,
            test_ticket_tier.id,
            2,
        )
        await db_session.refresh(psr1)
        await db_session.refresh(psr2)
        await db_session.refresh(pledge1)
        await db_session.refresh(pledge2)
        assert psr1.spots == 0
        assert psr2.spots == 1
        assert pledge1.reserved_spots == 0
        assert pledge2.reserved_spots == 1


# ═══════════════════════════════════════════════════════════════════════════
# SECTION 3 — funding/pledges.py
# ═══════════════════════════════════════════════════════════════════════════

# Helpers for mocking the payment gateway and platform settings
# that are imported inside create_pledge.

def _mock_payment_context():
    """Context manager stack for mocking payment gateway used by create_pledge."""
    mock_result = MagicMock(
        status="success",
        transaction_id="tx-test-001",
        authorization_code="auth-test-001",
    )
    return patch(
        "app.services.payment_gateway.get_gateway",
        new_callable=AsyncMock,
        return_value=MagicMock(
            charge=AsyncMock(return_value=mock_result),
        ),
    )


def _mock_settings_context(commission=10, community_override=None):
    """Context managers for platform_settings.get_int / get_str."""
    p1 = patch(
        "app.services.platform_settings.get_int",
        new_callable=AsyncMock,
        return_value=commission,
    )
    p2 = patch(
        "app.services.platform_settings.get_str",
        new_callable=AsyncMock,
        return_value=community_override,
    )
    return p1, p2


class TestCreatePledgeTierReservations:
    """create_pledge() with tier_reservations — lines 131-291."""

    @pytest.mark.asyncio
    async def test_tier_reservation_success(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Happy path: registered user, tier-linked reservations."""
        test_event_approved.link_funding_to_tiers = True
        test_ticket_tier.max_reserved_spots = 10
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            pledge = await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=5000,
                tier_reservations=[
                    {"tier_id": test_ticket_tier.id, "spots": 2}
                ],
            )

        assert pledge.reserved_spots == 2
        assert pledge.status == FundingStatus.pledged
        assert pledge.receipt_number is not None

        # Verify PledgeSpotReservation rows
        from sqlalchemy import select

        psr_q = select(PledgeSpotReservation).where(
            PledgeSpotReservation.funding_id == pledge.id
        )
        psrs = list((await db_session.execute(psr_q)).scalars().all())
        assert len(psrs) == 1
        assert psrs[0].ticket_tier_id == test_ticket_tier.id
        assert psrs[0].spots == 2

    @pytest.mark.asyncio
    async def test_tier_reservation_guest_rejected(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
    ):
        """Guest (unregistered) user cannot reserve tier spots."""
        test_event_approved.link_funding_to_tiers = True
        test_ticket_tier.max_reserved_spots = 10
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="registered"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=5000,
                    tier_reservations=[
                        {"tier_id": test_ticket_tier.id, "spots": 2}
                    ],
                )

    @pytest.mark.asyncio
    async def test_tier_not_found(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Tier ID that doesn't belong to the event."""
        test_event_approved.link_funding_to_tiers = True
        test_ticket_tier.max_reserved_spots = 10
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="not found"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=5000,
                    tier_reservations=[{"tier_id": 99999, "spots": 2}],
                )

    @pytest.mark.asyncio
    async def test_tier_no_reservations_allowed(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Tier with max_reserved_spots=0 does not allow reservations."""
        test_event_approved.link_funding_to_tiers = True
        test_ticket_tier.max_reserved_spots = 0
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="does not allow"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=5000,
                    tier_reservations=[
                        {"tier_id": test_ticket_tier.id, "spots": 2}
                    ],
                )

    @pytest.mark.asyncio
    async def test_tier_over_capacity(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Requesting more spots than the tier allows."""
        test_event_approved.link_funding_to_tiers = True
        test_ticket_tier.max_reserved_spots = 2
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="only has"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=50000,
                    tier_reservations=[
                        {"tier_id": test_ticket_tier.id, "spots": 5}
                    ],
                )

    @pytest.mark.asyncio
    async def test_tier_amount_below_minimum(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Amount too low to cover tier price * spots."""
        test_event_approved.link_funding_to_tiers = True
        test_ticket_tier.max_reserved_spots = 10
        # tier price is 2500 cents, 2 spots = 5000 required
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="at least"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=1000,  # < 5000
                    tier_reservations=[
                        {"tier_id": test_ticket_tier.id, "spots": 2}
                    ],
                )

    @pytest.mark.asyncio
    async def test_tier_event_capacity_exceeded(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Event max_capacity is exceeded by reservations."""
        test_event_approved.link_funding_to_tiers = True
        test_event_approved.max_capacity = 2  # very small
        test_ticket_tier.max_reserved_spots = 100
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="capacity"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=25000,  # 2500 * 10 spots
                    tier_reservations=[
                        {"tier_id": test_ticket_tier.id, "spots": 10}
                    ],
                )

    @pytest.mark.asyncio
    async def test_tier_spots_zero_rejected(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_ticket_tier: TicketTier,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Requesting 0 spots for a tier is rejected."""
        test_event_approved.link_funding_to_tiers = True
        test_ticket_tier.max_reserved_spots = 10
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="Spots must be >= 1"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=5000,
                    tier_reservations=[
                        {"tier_id": test_ticket_tier.id, "spots": 0}
                    ],
                )


class TestCreatePledgeGenericSpots:
    """create_pledge() with reserved_spots > 0 (no tier link) — lines 191-224."""

    @pytest.mark.asyncio
    async def test_generic_spots_success(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        test_event_approved.max_reserved_spots_per_user = 5
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            pledge = await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=2500,  # 500 cents/spot * 5
                reserved_spots=2,
            )

        assert pledge.reserved_spots == 2
        assert pledge.status == FundingStatus.pledged

    @pytest.mark.asyncio
    async def test_generic_spots_guest_rejected(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        """Guest user cannot reserve generic spots."""
        test_event_approved.max_reserved_spots_per_user = 5
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="registered"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=2500,
                    reserved_spots=2,
                )

    @pytest.mark.asyncio
    async def test_generic_spots_not_enabled(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Event with max_reserved_spots_per_user=0 rejects spot reservation."""
        test_event_approved.max_reserved_spots_per_user = 0
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="not enabled"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=2500,
                    reserved_spots=2,
                )

    @pytest.mark.asyncio
    async def test_generic_spots_amount_too_low(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Amount below min_pledge_cents * reserved_spots."""
        test_event_approved.max_reserved_spots_per_user = 5
        # min_pledge_cents = 500, 2 spots = 1000 required
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="at least"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=100,  # < 1000
                    reserved_spots=2,
                )

    @pytest.mark.asyncio
    async def test_generic_spots_exceeds_per_user_limit(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """User already has spots; adding more exceeds per-user max."""
        test_event_approved.max_reserved_spots_per_user = 3
        await db_session.flush()

        customer = test_users["customer"]
        # Create an existing pledge with 2 reserved spots
        existing = Funding(
            event_id=test_event_approved.id,
            user_id=customer.id,
            amount_cents=1000,
            platform_cut_cents=100,
            net_to_organizer_cents=900,
            status=FundingStatus.pledged,
            reserved_spots=2,
            receipt_number="PLG-EXISTING-001",
        )
        db_session.add(existing)
        await db_session.flush()

        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="Cannot reserve"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=5000,
                    reserved_spots=2,  # 2 existing + 2 new = 4 > max 3
                )

    @pytest.mark.asyncio
    async def test_generic_spots_event_capacity_exceeded(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_registration: Registration,
    ):
        """Event capacity is reached; no room for more reserved spots."""
        test_event_approved.max_reserved_spots_per_user = 100
        test_event_approved.max_capacity = 1
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="capacity"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=50000,
                    reserved_spots=5,
                )


class TestCreatePledgeMinAmount:
    """create_pledge() zero-spots path: min pledge amount check — lines 226-229."""

    @pytest.mark.asyncio
    async def test_amount_below_event_minimum(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        """Pledge with no spots but amount < event.min_pledge_cents."""
        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with pytest.raises(ConflictError, match="event minimum"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=100,  # min_pledge_cents is 500
                )


class TestCreatePledgePaymentFailure:
    """create_pledge() payment failure paths — lines 254-264."""

    @pytest.mark.asyncio
    async def test_payment_declined(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()
        failed_result = MagicMock(
            status="failed",
            failure_reason="card declined",
        )
        mock_gw = patch(
            "app.services.payment_gateway.get_gateway",
            new_callable=AsyncMock,
            return_value=MagicMock(
                charge=AsyncMock(return_value=failed_result),
            ),
        )

        with settings_p1, settings_p2, mock_gw:
            with pytest.raises(ConflictError, match="Payment failed"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=1000,
                )

    @pytest.mark.asyncio
    async def test_payment_processing_error(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()
        mock_gw = patch(
            "app.services.payment_gateway.get_gateway",
            new_callable=AsyncMock,
            return_value=MagicMock(
                charge=AsyncMock(side_effect=RuntimeError("network error")),
            ),
        )

        with settings_p1, settings_p2, mock_gw:
            with pytest.raises(ConflictError, match="Payment processing error"):
                await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=1000,
                )


class TestCreatePledgeEarlyBird:
    """Early bird discount applied in create_pledge — lines 298-312."""

    @pytest.mark.asyncio
    async def test_early_bird_flag_set(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        """Pledge created within early bird window gets is_early_bird=True."""
        # Create early bird with explicit window_start to avoid naive/aware mismatch
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

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            pledge = await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=1000,
            )

        assert pledge.is_early_bird is True

    @pytest.mark.asyncio
    async def test_no_early_bird_outside_window(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        """Pledge without active early bird discount: is_early_bird stays False."""
        # Create an expired early bird discount
        ebd = EarlyBirdDiscount(
            event_id=test_event_approved.id,
            applies_to="funding",
            window_end=datetime.now(timezone.utc) - timedelta(days=1),
            discount_type="percent",
            value=10,
        )
        db_session.add(ebd)
        await db_session.flush()

        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            pledge = await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=1000,
            )

        assert pledge.is_early_bird is False


class TestCheckMilestoneSnapshots:
    """_check_milestone_snapshots() — lines 382-443."""

    @pytest.mark.asyncio
    async def test_milestone_snapshot_created(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_milestone: FundingMilestone,
    ):
        """Crossing a 50% milestone creates snapshot + user entries."""
        # funding_goal_cents = 10000, so 50% = 5000
        customer = test_users["customer"]

        # Create a pledge that crosses 50%
        pledge = Funding(
            event_id=test_event_approved.id,
            user_id=customer.id,
            amount_cents=6000,
            platform_cut_cents=600,
            net_to_organizer_cents=5400,
            status=FundingStatus.pledged,
            receipt_number="PLG-MILE-001",
        )
        db_session.add(pledge)
        await db_session.flush()

        await pledge_svc._check_milestone_snapshots(
            db_session, test_event_approved
        )

        from sqlalchemy import select

        snap_q = select(FundingMilestoneSnapshot).where(
            FundingMilestoneSnapshot.event_id == test_event_approved.id,
            FundingMilestoneSnapshot.milestone_percent == 50,
        )
        snapshot = (await db_session.execute(snap_q)).scalar_one_or_none()
        assert snapshot is not None

        user_q = select(FundingMilestoneUser).where(
            FundingMilestoneUser.snapshot_id == snapshot.id
        )
        users = list((await db_session.execute(user_q)).scalars().all())
        assert len(users) == 1
        assert users[0].user_id == customer.id

    @pytest.mark.asyncio
    async def test_milestone_not_crossed(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_milestone: FundingMilestone,
    ):
        """Funding below 50% does not create a snapshot."""
        customer = test_users["customer"]
        pledge = Funding(
            event_id=test_event_approved.id,
            user_id=customer.id,
            amount_cents=1000,  # 10% < 50%
            platform_cut_cents=100,
            net_to_organizer_cents=900,
            status=FundingStatus.pledged,
            receipt_number="PLG-MILE-002",
        )
        db_session.add(pledge)
        await db_session.flush()

        await pledge_svc._check_milestone_snapshots(
            db_session, test_event_approved
        )

        from sqlalchemy import select

        snap_q = select(FundingMilestoneSnapshot).where(
            FundingMilestoneSnapshot.event_id == test_event_approved.id,
        )
        snapshots = list((await db_session.execute(snap_q)).scalars().all())
        assert len(snapshots) == 0

    @pytest.mark.asyncio
    async def test_milestone_no_goal(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
    ):
        """Event with no funding goal: _check_milestone_snapshots returns early."""
        test_event_approved.funding_goal_cents = 0
        await db_session.flush()
        # Should not raise
        await pledge_svc._check_milestone_snapshots(
            db_session, test_event_approved
        )

    @pytest.mark.asyncio
    async def test_milestone_already_snapshotted(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_milestone: FundingMilestone,
    ):
        """If milestone snapshot already exists, don't create a duplicate."""
        customer = test_users["customer"]
        pledge = Funding(
            event_id=test_event_approved.id,
            user_id=customer.id,
            amount_cents=6000,
            platform_cut_cents=600,
            net_to_organizer_cents=5400,
            status=FundingStatus.pledged,
            receipt_number="PLG-MILE-003",
        )
        db_session.add(pledge)
        await db_session.flush()

        # First call creates the snapshot
        await pledge_svc._check_milestone_snapshots(
            db_session, test_event_approved
        )
        # Second call should not create another
        await pledge_svc._check_milestone_snapshots(
            db_session, test_event_approved
        )

        from sqlalchemy import select

        snap_q = select(FundingMilestoneSnapshot).where(
            FundingMilestoneSnapshot.event_id == test_event_approved.id,
            FundingMilestoneSnapshot.milestone_percent == 50,
        )
        snapshots = list((await db_session.execute(snap_q)).scalars().all())
        assert len(snapshots) == 1

    @pytest.mark.asyncio
    async def test_milestone_no_milestones_defined(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        """No milestones or discount milestones: returns early (no error)."""
        customer = test_users["customer"]
        pledge = Funding(
            event_id=test_event_approved.id,
            user_id=customer.id,
            amount_cents=6000,
            platform_cut_cents=600,
            net_to_organizer_cents=5400,
            status=FundingStatus.pledged,
            receipt_number="PLG-MILE-004",
        )
        db_session.add(pledge)
        await db_session.flush()

        # Should not raise
        await pledge_svc._check_milestone_snapshots(
            db_session, test_event_approved
        )

    @pytest.mark.asyncio
    async def test_milestone_multiple_pledgers_recorded(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_milestone: FundingMilestone,
    ):
        """Multiple pledgers contribute; all recorded in snapshot users."""
        customer = test_users["customer"]
        organizer = test_users["organizer"]

        p1 = Funding(
            event_id=test_event_approved.id,
            user_id=customer.id,
            amount_cents=3000,
            platform_cut_cents=300,
            net_to_organizer_cents=2700,
            status=FundingStatus.pledged,
            receipt_number="PLG-MILE-005A",
        )
        p2 = Funding(
            event_id=test_event_approved.id,
            user_id=organizer.id,
            amount_cents=4000,
            platform_cut_cents=400,
            net_to_organizer_cents=3600,
            status=FundingStatus.pledged,
            receipt_number="PLG-MILE-005B",
        )
        db_session.add_all([p1, p2])
        await db_session.flush()

        await pledge_svc._check_milestone_snapshots(
            db_session, test_event_approved
        )

        from sqlalchemy import select

        snap_q = select(FundingMilestoneSnapshot).where(
            FundingMilestoneSnapshot.event_id == test_event_approved.id,
            FundingMilestoneSnapshot.milestone_percent == 50,
        )
        snapshot = (await db_session.execute(snap_q)).scalar_one()
        user_q = select(FundingMilestoneUser).where(
            FundingMilestoneUser.snapshot_id == snapshot.id
        )
        user_ids = {
            u.user_id
            for u in (await db_session.execute(user_q)).scalars().all()
        }
        assert customer.id in user_ids
        assert organizer.id in user_ids


class TestCreatePledgeMilestoneIntegration:
    """create_pledge triggers _check_milestone_snapshots internally — line 315."""

    @pytest.mark.asyncio
    async def test_pledge_triggers_milestone_check(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
        test_milestone: FundingMilestone,
    ):
        """A pledge that crosses the 50% milestone creates a snapshot."""
        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            pledge = await pledge_svc.create_pledge(
                db_session,
                event_id=test_event_approved.id,
                user=customer,
                amount_cents=6000,  # 60% > 50% milestone
            )

        from sqlalchemy import select

        snap_q = select(FundingMilestoneSnapshot).where(
            FundingMilestoneSnapshot.event_id == test_event_approved.id,
            FundingMilestoneSnapshot.milestone_percent == 50,
        )
        snapshot = (await db_session.execute(snap_q)).scalar_one_or_none()
        assert snapshot is not None


class TestCreatePledgeEscrowIntegration:
    """create_pledge calls escrow check — lines 319-323."""

    @pytest.mark.asyncio
    async def test_escrow_check_error_swallowed(
        self,
        db_session: AsyncSession,
        test_event_approved: Event,
        test_users: dict[str, User],
    ):
        """Even if escrow check_and_release_stage1 fails, pledge still succeeds."""
        customer = test_users["customer"]
        settings_p1, settings_p2 = _mock_settings_context()

        with settings_p1, settings_p2, _mock_payment_context():
            with patch(
                "app.services.escrow.check_and_release_stage1",
                new_callable=AsyncMock,
                side_effect=RuntimeError("escrow boom"),
            ):
                pledge = await pledge_svc.create_pledge(
                    db_session,
                    event_id=test_event_approved.id,
                    user=customer,
                    amount_cents=1000,
                )

        assert pledge.status == FundingStatus.pledged
