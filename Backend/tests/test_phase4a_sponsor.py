"""
Phase 4A — Sponsor subsystem service-level tests.

Covers:
  - sponsor/profile.py       (get / create / update)
  - sponsor/categories.py    (CRUD, bid stats, my bids)
  - sponsor/delegates.py     (list / add / remove / check-in)
  - sponsor/organizer_queries.py  (bid events, admin detail, summary, available, organizer sponsors, paid)
  - sponsor/tickets.py       (get / list / won categories / scan)
"""
import pytest
import pytest_asyncio
from unittest.mock import patch

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.user import User, UserRole
from app.models.event import Event
from app.models.sponsor import (
    BidStatus,
    SponsorBid,
    SponsorDelegate,
    SponsorProfile,
    SponsorTicket,
    SponsorshipCategory,
)
from app.schemas.sponsor import (
    CategoryCreate,
    CategoryUpdate,
    SponsorProfileCreate,
    SponsorProfileUpdate,
)

# ── Services under test ──
from app.services.sponsor import profile as profile_svc
from app.services.sponsor import categories as categories_svc
from app.services.sponsor import delegates as delegates_svc
from app.services.sponsor import organizer_queries as oq_svc
from app.services.sponsor import tickets as tickets_svc


# ---------------------------------------------------------------------------
# Local helpers
# ---------------------------------------------------------------------------

async def _make_sponsor_ticket(
    db: AsyncSession, event: Event, sponsor_user: User,
) -> SponsorTicket:
    ticket = SponsorTicket(
        event_id=event.id,
        sponsor_user_id=sponsor_user.id,
        receipt_number=f"SPT-{event.id}-{sponsor_user.id}",
    )
    db.add(ticket)
    await db.flush()
    return ticket


async def _make_category(
    db: AsyncSession, event: Event, *, name: str = "Silver", spots: int = 5, min_bid: int = 1000,
) -> SponsorshipCategory:
    cat = SponsorshipCategory(
        event_id=event.id,
        name=name,
        total_spots=spots,
        min_bid_cents=min_bid,
    )
    db.add(cat)
    await db.flush()
    return cat


async def _make_bid(
    db: AsyncSession,
    category: SponsorshipCategory,
    sponsor_user: User,
    *,
    amount: int = 5000,
    status: BidStatus = BidStatus.pending,
) -> SponsorBid:
    bid = SponsorBid(
        category_id=category.id,
        sponsor_user_id=sponsor_user.id,
        amount_cents=amount,
        status=status,
    )
    db.add(bid)
    await db.flush()
    return bid


# ===========================================================================
# 1. sponsor/profile.py
# ===========================================================================


class TestSponsorProfile:

    @pytest.mark.asyncio
    async def test_get_profile_existing(
        self, db_session: AsyncSession, test_sponsor_profile: SponsorProfile,
        test_users_with_sponsor: dict[str, User],
    ):
        result = await profile_svc.get_profile(db_session, test_users_with_sponsor["sponsor"].id)
        assert result is not None
        assert result.company_name == "Test Corp"

    @pytest.mark.asyncio
    async def test_get_profile_none(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        result = await profile_svc.get_profile(db_session, test_users["customer"].id)
        assert result is None

    @pytest.mark.asyncio
    async def test_create_profile_success(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        customer = test_users["customer"]
        assert customer.role == UserRole.customer

        data = SponsorProfileCreate(
            company_name="New Corp", contact_name="Alice", profession="Finance",
        )
        result = await profile_svc.create_profile(db_session, customer, data)
        assert result.company_name == "New Corp"
        assert result.user_id == customer.id
        # role should have been upgraded
        assert customer.role == UserRole.sponsor

    @pytest.mark.asyncio
    async def test_create_profile_duplicate_409(
        self, db_session: AsyncSession, test_sponsor_profile: SponsorProfile,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        data = SponsorProfileCreate(
            company_name="Dup Corp", contact_name="Bob", profession="Sales",
        )
        with pytest.raises(HTTPException) as exc_info:
            await profile_svc.create_profile(db_session, sponsor, data)
        assert exc_info.value.status_code == 409

    @pytest.mark.asyncio
    async def test_update_profile_success(
        self, db_session: AsyncSession, test_sponsor_profile: SponsorProfile,
        test_users_with_sponsor: dict[str, User],
    ):
        data = SponsorProfileUpdate(company_name="Updated Corp")
        result = await profile_svc.update_profile(
            db_session, test_users_with_sponsor["sponsor"].id, data,
        )
        assert result.company_name == "Updated Corp"
        # untouched fields remain
        assert result.contact_name == "Sponsor Person"

    @pytest.mark.asyncio
    async def test_update_profile_not_found_404(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        data = SponsorProfileUpdate(company_name="Ghost")
        with pytest.raises(HTTPException) as exc_info:
            await profile_svc.update_profile(db_session, test_users["customer"].id, data)
        assert exc_info.value.status_code == 404


# ===========================================================================
# 2. sponsor/categories.py
# ===========================================================================


class TestSponsorCategories:

    # -- _require_organizer --

    @pytest.mark.asyncio
    async def test_require_organizer_success(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users: dict[str, User],
    ):
        event = await categories_svc._require_organizer(
            db_session, test_event_approved.id, test_users["organizer"],
        )
        assert event.id == test_event_approved.id

    @pytest.mark.asyncio
    async def test_require_organizer_wrong_user_403(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users: dict[str, User],
    ):
        with pytest.raises(HTTPException) as exc_info:
            await categories_svc._require_organizer(
                db_session, test_event_approved.id, test_users["customer"],
            )
        assert exc_info.value.status_code == 403

    @pytest.mark.asyncio
    async def test_require_organizer_event_not_found_404(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        with pytest.raises(HTTPException) as exc_info:
            await categories_svc._require_organizer(
                db_session, 999999, test_users["organizer"],
            )
        assert exc_info.value.status_code == 404

    # -- list_categories --

    @pytest.mark.asyncio
    async def test_list_categories(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
        test_event_approved: Event,
    ):
        cats = await categories_svc.list_categories(db_session, test_event_approved.id)
        assert len(cats) >= 1
        assert cats[0].name == "Gold Sponsor"

    @pytest.mark.asyncio
    async def test_list_categories_empty(
        self, db_session: AsyncSession, test_event_approved: Event,
    ):
        cats = await categories_svc.list_categories(db_session, test_event_approved.id)
        assert cats == []

    # -- create_category --

    @pytest.mark.asyncio
    async def test_create_category_success(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users: dict[str, User],
    ):
        data = CategoryCreate(name="Bronze", total_spots=10, min_bid_cents=500)
        cat = await categories_svc.create_category(
            db_session, test_event_approved.id, test_users["organizer"], data,
        )
        assert cat.name == "Bronze"
        assert cat.total_spots == 10
        assert cat.event_id == test_event_approved.id

    @pytest.mark.asyncio
    async def test_create_category_forbidden_403(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users: dict[str, User],
    ):
        data = CategoryCreate(name="Blocked", total_spots=1, min_bid_cents=100)
        with pytest.raises(HTTPException) as exc_info:
            await categories_svc.create_category(
                db_session, test_event_approved.id, test_users["customer"], data,
            )
        assert exc_info.value.status_code == 403

    # -- update_category --

    @pytest.mark.asyncio
    async def test_update_category_success(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
        test_users: dict[str, User],
    ):
        data = CategoryUpdate(name="Platinum")
        cat = await categories_svc.update_category(
            db_session, test_sponsorship_category.id, test_users["organizer"], data,
        )
        assert cat.name == "Platinum"

    @pytest.mark.asyncio
    async def test_update_category_not_found_404(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        data = CategoryUpdate(name="Ghost")
        with pytest.raises(HTTPException) as exc_info:
            await categories_svc.update_category(db_session, 999999, test_users["organizer"], data)
        assert exc_info.value.status_code == 404

    # -- delete_category --

    @pytest.mark.asyncio
    async def test_delete_category_success(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users: dict[str, User],
    ):
        cat = await _make_category(db_session, test_event_approved, name="Deletable")
        await categories_svc.delete_category(db_session, cat.id, test_users["organizer"])
        # verify gone
        with pytest.raises(HTTPException) as exc_info:
            await categories_svc._get_category(db_session, cat.id)
        assert exc_info.value.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_category_not_found_404(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        with pytest.raises(HTTPException) as exc_info:
            await categories_svc.delete_category(db_session, 999999, test_users["organizer"])
        assert exc_info.value.status_code == 404

    # -- get_bid_stats --

    @pytest.mark.asyncio
    async def test_get_bid_stats_with_bids(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
        test_sponsor_bid: SponsorBid,
    ):
        count, pending_amounts = await categories_svc.get_bid_stats(
            db_session, test_sponsorship_category.id,
        )
        assert count == 1
        assert pending_amounts == [10000]

    @pytest.mark.asyncio
    async def test_get_bid_stats_empty(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
    ):
        count, pending_amounts = await categories_svc.get_bid_stats(
            db_session, test_sponsorship_category.id,
        )
        assert count == 0
        assert pending_amounts == []

    # -- get_my_bid_count --

    @pytest.mark.asyncio
    async def test_get_my_bid_count(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
        test_sponsor_bid: SponsorBid, test_users_with_sponsor: dict[str, User],
    ):
        cnt = await categories_svc.get_my_bid_count(
            db_session, test_sponsorship_category.id,
            test_users_with_sponsor["sponsor"].id,
        )
        assert cnt == 1

    @pytest.mark.asyncio
    async def test_get_my_bid_count_zero(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
        test_users: dict[str, User],
    ):
        cnt = await categories_svc.get_my_bid_count(
            db_session, test_sponsorship_category.id, test_users["customer"].id,
        )
        assert cnt == 0

    # -- get_my_bids --

    @pytest.mark.asyncio
    async def test_get_my_bids(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
        test_sponsor_bid: SponsorBid, test_users_with_sponsor: dict[str, User],
    ):
        bids = await categories_svc.get_my_bids(
            db_session, test_sponsorship_category.id,
            test_users_with_sponsor["sponsor"].id,
        )
        assert len(bids) == 1
        assert bids[0]["amount_cents"] == 10000
        assert bids[0]["status"] == "pending"

    @pytest.mark.asyncio
    async def test_get_my_bids_empty(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
        test_users: dict[str, User],
    ):
        bids = await categories_svc.get_my_bids(
            db_session, test_sponsorship_category.id, test_users["customer"].id,
        )
        assert bids == []


# ===========================================================================
# 3. sponsor/delegates.py
# ===========================================================================


class TestSponsorDelegates:

    @pytest.mark.asyncio
    async def test_list_delegates_empty(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        result = await delegates_svc.list_delegates(db_session, ticket.id, sponsor.id)
        assert result == []

    @pytest.mark.asyncio
    async def test_add_delegate_success(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        delegate = await delegates_svc.add_delegate(
            db_session, ticket.id, sponsor.id, "Alice", email="alice@test.com",
        )
        assert delegate.name == "Alice"
        assert delegate.email == "alice@test.com"
        assert delegate.sponsor_ticket_id == ticket.id

    @pytest.mark.asyncio
    async def test_add_delegate_duplicate_email_conflict(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        await delegates_svc.add_delegate(
            db_session, ticket.id, sponsor.id, "Alice", email="dup@test.com",
        )
        with pytest.raises(ConflictError):
            await delegates_svc.add_delegate(
                db_session, ticket.id, sponsor.id, "Bob", email="dup@test.com",
            )

    @pytest.mark.asyncio
    async def test_add_delegate_over_max_conflict(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        # add max_delegates=2 delegates
        await delegates_svc.add_delegate(
            db_session, ticket.id, sponsor.id, "D1", max_delegates=2,
        )
        await delegates_svc.add_delegate(
            db_session, ticket.id, sponsor.id, "D2", max_delegates=2,
        )
        with pytest.raises(ConflictError):
            await delegates_svc.add_delegate(
                db_session, ticket.id, sponsor.id, "D3", max_delegates=2,
            )

    @pytest.mark.asyncio
    async def test_remove_delegate_success(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        delegate = await delegates_svc.add_delegate(
            db_session, ticket.id, sponsor.id, "ToRemove",
        )
        await delegates_svc.remove_delegate(db_session, delegate.id, sponsor.id)
        # list should be empty
        remaining = await delegates_svc.list_delegates(db_session, ticket.id, sponsor.id)
        assert remaining == []

    @pytest.mark.asyncio
    async def test_remove_delegate_checked_in_fails(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        delegate = await delegates_svc.add_delegate(
            db_session, ticket.id, sponsor.id, "CheckedIn",
        )
        # check in first
        await delegates_svc.check_in_delegate(db_session, delegate.id)
        with pytest.raises(ConflictError):
            await delegates_svc.remove_delegate(db_session, delegate.id, sponsor.id)

    @pytest.mark.asyncio
    async def test_check_in_delegate_success(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        delegate = await delegates_svc.add_delegate(
            db_session, ticket.id, sponsor.id, "Guest",
        )
        result = await delegates_svc.check_in_delegate(db_session, delegate.id)
        assert result["already_checked_in"] is False
        assert result["name"] == "Guest"
        assert "checked_in_at" in result

    @pytest.mark.asyncio
    async def test_check_in_delegate_already(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        delegate = await delegates_svc.add_delegate(
            db_session, ticket.id, sponsor.id, "Repeat",
        )
        await delegates_svc.check_in_delegate(db_session, delegate.id)
        result = await delegates_svc.check_in_delegate(db_session, delegate.id)
        assert result["already_checked_in"] is True

    @pytest.mark.asyncio
    async def test_list_delegates_with_data(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        await delegates_svc.add_delegate(db_session, ticket.id, sponsor.id, "A")
        await delegates_svc.add_delegate(db_session, ticket.id, sponsor.id, "B")
        result = await delegates_svc.list_delegates(db_session, ticket.id, sponsor.id)
        assert len(result) == 2

    @pytest.mark.asyncio
    async def test_remove_delegate_not_found(
        self, db_session: AsyncSession, test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        with pytest.raises(NotFoundError):
            await delegates_svc.remove_delegate(db_session, 999999, sponsor.id)

    @pytest.mark.asyncio
    async def test_add_delegate_wrong_owner_forbidden(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        other = test_users_with_sponsor["customer"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        with pytest.raises(ForbiddenError):
            await delegates_svc.add_delegate(
                db_session, ticket.id, other.id, "Intruder",
            )


# ===========================================================================
# 4. sponsor/organizer_queries.py
# ===========================================================================


class TestOrganizerQueries:

    @pytest.mark.asyncio
    async def test_get_sponsor_bid_events_with_data(
        self, db_session: AsyncSession, test_sponsor_bid: SponsorBid,
        test_users_with_sponsor: dict[str, User],
    ):
        events = await oq_svc.get_sponsor_bid_events(
            db_session, test_users_with_sponsor["sponsor"].id,
        )
        assert len(events) == 1

    @pytest.mark.asyncio
    async def test_get_sponsor_bid_events_empty(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        events = await oq_svc.get_sponsor_bid_events(db_session, test_users["customer"].id)
        assert events == []

    @pytest.mark.asyncio
    async def test_get_sponsor_bids_detail_for_admin_with_data(
        self, db_session: AsyncSession, test_sponsor_bid: SponsorBid,
        test_users_with_sponsor: dict[str, User],
    ):
        detail = await oq_svc.get_sponsor_bids_detail_for_admin(
            db_session, test_users_with_sponsor["sponsor"].id,
        )
        assert len(detail) == 1
        assert len(detail[0]["bids"]) == 1
        assert detail[0]["bids"][0]["status"] == "pending"

    @pytest.mark.asyncio
    async def test_get_sponsor_bids_detail_for_admin_empty(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        detail = await oq_svc.get_sponsor_bids_detail_for_admin(
            db_session, test_users["customer"].id,
        )
        assert detail == []

    @pytest.mark.asyncio
    async def test_get_sponsor_bid_summary_for_event(
        self, db_session: AsyncSession, test_sponsor_bid: SponsorBid,
        test_event_approved: Event, test_users_with_sponsor: dict[str, User],
    ):
        summary = await oq_svc.get_sponsor_bid_summary_for_event(
            db_session, test_event_approved.id,
            test_users_with_sponsor["sponsor"].id,
        )
        assert summary["pending"] == 1
        assert summary["accepted"] == 0

    @pytest.mark.asyncio
    async def test_get_sponsor_bid_summary_for_event_empty(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users: dict[str, User],
    ):
        summary = await oq_svc.get_sponsor_bid_summary_for_event(
            db_session, test_event_approved.id, test_users["customer"].id,
        )
        assert summary == {"pending": 0, "accepted": 0, "rejected": 0, "paid": 0, "withdrawn": 0}

    @pytest.mark.asyncio
    async def test_get_events_with_sponsorship_available(
        self, db_session: AsyncSession, test_sponsorship_category: SponsorshipCategory,
        test_event_approved: Event,
    ):
        results = await oq_svc.get_events_with_sponsorship_available(db_session)
        assert len(results) >= 1
        event_ids = [r["event"].id for r in results]
        assert test_event_approved.id in event_ids

    @pytest.mark.asyncio
    async def test_get_events_with_sponsorship_available_empty(
        self, db_session: AsyncSession, test_event_approved: Event,
    ):
        # no categories => no availability
        results = await oq_svc.get_events_with_sponsorship_available(db_session)
        assert results == []

    @pytest.mark.asyncio
    async def test_get_organizer_sponsors_with_data(
        self, db_session: AsyncSession, test_sponsor_bid: SponsorBid,
        test_sponsor_profile: SponsorProfile,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsors = await oq_svc.get_organizer_sponsors(
            db_session, test_users_with_sponsor["organizer"].id,
        )
        assert len(sponsors) == 1
        assert sponsors[0]["company_name"] == "Test Corp"
        assert sponsors[0]["total_bids"] == 1

    @pytest.mark.asyncio
    async def test_get_organizer_sponsors_empty(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        sponsors = await oq_svc.get_organizer_sponsors(
            db_session, test_users["organizer"].id,
        )
        assert sponsors == []

    @pytest.mark.asyncio
    async def test_get_sponsor_events_for_organizer_with_data(
        self, db_session: AsyncSession, test_sponsor_bid: SponsorBid,
        test_users_with_sponsor: dict[str, User],
    ):
        events = await oq_svc.get_sponsor_events_for_organizer(
            db_session,
            test_users_with_sponsor["organizer"].id,
            test_users_with_sponsor["sponsor"].id,
        )
        assert len(events) == 1
        assert events[0]["bids"]  # at least one bid record

    @pytest.mark.asyncio
    async def test_get_sponsor_events_for_organizer_empty(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        events = await oq_svc.get_sponsor_events_for_organizer(
            db_session, test_users["organizer"].id, test_users["customer"].id,
        )
        assert events == []

    @pytest.mark.asyncio
    async def test_get_paid_sponsors_with_data(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_sponsorship_category: SponsorshipCategory,
        test_sponsor_profile: SponsorProfile,
        test_users_with_sponsor: dict[str, User],
    ):
        # create a paid bid to surface the paid sponsor
        await _make_bid(
            db_session, test_sponsorship_category,
            test_users_with_sponsor["sponsor"],
            amount=8000, status=BidStatus.paid,
        )
        sponsors = await oq_svc.get_paid_sponsors(db_session, test_event_approved.id)
        assert len(sponsors) == 1
        assert sponsors[0]["company_name"] == "Test Corp"

    @pytest.mark.asyncio
    async def test_get_paid_sponsors_empty(
        self, db_session: AsyncSession, test_event_approved: Event,
    ):
        sponsors = await oq_svc.get_paid_sponsors(db_session, test_event_approved.id)
        assert sponsors == []


# ===========================================================================
# 5. sponsor/tickets.py
# ===========================================================================


class TestSponsorTickets:

    @pytest.mark.asyncio
    async def test_get_sponsor_ticket_found(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        result = await tickets_svc.get_sponsor_ticket(
            db_session, test_event_approved.id, sponsor.id,
        )
        assert result is not None
        assert result.event_id == test_event_approved.id

    @pytest.mark.asyncio
    async def test_get_sponsor_ticket_not_found(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users: dict[str, User],
    ):
        result = await tickets_svc.get_sponsor_ticket(
            db_session, test_event_approved.id, test_users["customer"].id,
        )
        assert result is None

    @pytest.mark.asyncio
    async def test_list_sponsor_tickets(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        await _make_sponsor_ticket(db_session, test_event_approved, sponsor)
        tickets = await tickets_svc.list_sponsor_tickets(db_session, sponsor.id)
        assert len(tickets) >= 1

    @pytest.mark.asyncio
    async def test_list_sponsor_tickets_empty(
        self, db_session: AsyncSession, test_users: dict[str, User],
    ):
        tickets = await tickets_svc.list_sponsor_tickets(
            db_session, test_users["customer"].id,
        )
        assert tickets == []

    @pytest.mark.asyncio
    async def test_get_won_categories_empty(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        cats = await tickets_svc.get_won_categories(
            db_session, test_event_approved.id,
            test_users_with_sponsor["sponsor"].id,
        )
        assert cats == []

    @pytest.mark.asyncio
    async def test_scan_sponsor_ticket_success(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
        test_sponsor_profile: SponsorProfile,
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        ticket = await _make_sponsor_ticket(db_session, test_event_approved, sponsor)

        mock_data = {"eid": test_event_approved.id, "sid": ticket.id}
        with patch("app.services.ticket_crypto.decrypt_ticket_qr", return_value=mock_data):
            result = await tickets_svc.scan_sponsor_ticket(
                db_session, test_event_approved.id, "encrypted-payload",
            )
        assert result["ticket_id"] == ticket.id
        assert result["company_name"] == "Test Corp"
        assert result["already_scanned"] is False

    @pytest.mark.asyncio
    async def test_scan_sponsor_ticket_wrong_event_400(
        self, db_session: AsyncSession, test_event_approved: Event,
        test_users_with_sponsor: dict[str, User],
    ):
        sponsor = test_users_with_sponsor["sponsor"]
        await _make_sponsor_ticket(db_session, test_event_approved, sponsor)

        mock_data = {"eid": 999999, "sid": 1}
        with patch("app.services.ticket_crypto.decrypt_ticket_qr", return_value=mock_data):
            with pytest.raises(HTTPException) as exc_info:
                await tickets_svc.scan_sponsor_ticket(
                    db_session, test_event_approved.id, "wrong-event-payload",
                )
            assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_scan_sponsor_ticket_invalid_qr_400(
        self, db_session: AsyncSession, test_event_approved: Event,
    ):
        with patch(
            "app.services.ticket_crypto.decrypt_ticket_qr",
            side_effect=ValueError("bad qr"),
        ):
            with pytest.raises(HTTPException) as exc_info:
                await tickets_svc.scan_sponsor_ticket(
                    db_session, test_event_approved.id, "bad-qr",
                )
            assert exc_info.value.status_code == 400
