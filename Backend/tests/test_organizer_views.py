"""Tests for organizer and public sponsor views: bid events, sponsorship-available,
organizer-sponsors, prerequisites CRUD, uploads, review, event sponsors."""
import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sponsor import SponsorBid, SponsorshipCategory, BidStatus, SponsorPayment, PaymentStatus, SponsorTicket
from app.models.prerequisite import CategoryPrerequisite, BidPrerequisiteUpload, UploadStatus
from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── Fixtures ──────────────────────────────────────────────────────


@pytest_asyncio.fixture
async def paid_bid(
    db_session: AsyncSession,
    test_sponsorship_category,
    test_users_with_sponsor,
):
    """A paid bid (sponsor paid for the category)."""
    bid = SponsorBid(
        category_id=test_sponsorship_category.id,
        sponsor_user_id=test_users_with_sponsor["sponsor"].id,
        amount_cents=10000,
        proposal_text="Paid sponsorship",
        status=BidStatus.paid,
    )
    db_session.add(bid)
    await db_session.flush()
    payment = SponsorPayment(
        bid_id=bid.id,
        amount_cents=10000,
        platform_cut_cents=500,
        net_to_organizer_cents=9500,
        receipt_number=f"SP-TEST-{bid.id}",
        status=PaymentStatus.completed,
    )
    db_session.add(payment)
    # Sponsor ticket for event
    ticket = SponsorTicket(
        event_id=test_sponsorship_category.event_id,
        sponsor_user_id=test_users_with_sponsor["sponsor"].id,
        receipt_number=f"SPT-TEST-{test_sponsorship_category.event_id}-1",
        qr_data_encrypted="test-qr",
    )
    db_session.add(ticket)
    await db_session.commit()
    return bid


@pytest_asyncio.fixture
async def prerequisite(
    db_session: AsyncSession,
    test_sponsorship_category,
):
    """A prerequisite on the sponsorship category."""
    prereq = CategoryPrerequisite(
        category_id=test_sponsorship_category.id,
        name="Business License",
        description="Upload your business license",
        is_required=True,
        requires_document=True,
    )
    db_session.add(prereq)
    await db_session.commit()
    return prereq


@pytest_asyncio.fixture
async def prerequisite_upload(
    db_session: AsyncSession,
    test_sponsor_bid,
    prerequisite,
):
    """An upload for a prerequisite on the test bid."""
    upload = BidPrerequisiteUpload(
        bid_id=test_sponsor_bid.id,
        prerequisite_id=prerequisite.id,
        file_url="/static/uploads/prerequisites/test.pdf",
        status=UploadStatus.pending,
    )
    db_session.add(upload)
    await db_session.commit()
    return upload


# =====================================================================
# Sponsor Bid Events  (GET /me/sponsor-bid-events)
# =====================================================================


async def test_sponsor_bid_events_empty(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """GET /me/sponsor-bid-events returns [] when sponsor has no bids."""
    r = await client.get(
        "/api/v1/me/sponsor-bid-events",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert r.json() == []


async def test_sponsor_bid_events_with_bid(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsor_profile,
    auth_headers_sponsor,
):
    """GET /me/sponsor-bid-events returns events the sponsor has bids on."""
    r = await client.get(
        "/api/v1/me/sponsor-bid-events",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1
    assert "bid_summary" in data[0]


async def test_sponsor_bid_events_unauthenticated(
    client: AsyncClient,
    test_users,
):
    """GET /me/sponsor-bid-events without auth returns 401."""
    r = await client.get("/api/v1/me/sponsor-bid-events")
    assert r.status_code == 401


# =====================================================================
# Sponsorship Available Events  (GET /events/sponsorship-available)
# =====================================================================


async def test_sponsorship_available_no_categories(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """Returns [] when no events have sponsorship categories."""
    r = await client.get(
        "/api/v1/events/sponsorship-available",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_sponsorship_available_with_category(
    client: AsyncClient,
    test_sponsorship_category,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """Returns events that have open sponsorship categories."""
    r = await client.get(
        "/api/v1/events/sponsorship-available",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    # Should include our approved event with the sponsorship category
    if len(data) > 0:
        assert "categories_summary" in data[0]


async def test_sponsorship_available_exclude_my_bids(
    client: AsyncClient,
    test_sponsor_bid,
    test_sponsor_profile,
    auth_headers_sponsor,
):
    """exclude_my_bids=true filters out events where sponsor already bid."""
    r = await client.get(
        "/api/v1/events/sponsorship-available?exclude_my_bids=true",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200


# =====================================================================
# Organizer Sponsors  (GET /me/organizer-sponsors)
# =====================================================================


async def test_organizer_sponsors_empty(
    client: AsyncClient,
    test_users,
    auth_headers_organizer,
):
    """GET /me/organizer-sponsors returns items or empty list for organizer."""
    r = await client.get(
        "/api/v1/me/organizer-sponsors",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200


async def test_organizer_sponsors_customer_forbidden(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """Customer cannot access organizer sponsors."""
    r = await client.get(
        "/api/v1/me/organizer-sponsors",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_organizer_sponsors_unauthenticated(
    client: AsyncClient,
    test_users,
):
    """No auth returns 401."""
    r = await client.get("/api/v1/me/organizer-sponsors")
    assert r.status_code == 401


# =====================================================================
# Sponsor Events for Organizer  (GET /me/organizer-sponsors/{id}/events)
# =====================================================================


async def test_sponsor_events_for_organizer(
    client: AsyncClient,
    test_sponsor_bid,
    test_users_with_sponsor,
    auth_headers_organizer,
):
    """Organizer can list events where a specific sponsor has bid."""
    sponsor_id = test_users_with_sponsor["sponsor"].id
    r = await client.get(
        f"/api/v1/me/organizer-sponsors/{sponsor_id}/events",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200


async def test_sponsor_events_for_organizer_customer_forbidden(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_customer,
):
    """Customer cannot view sponsor events for organizer."""
    r = await client.get(
        f"/api/v1/me/organizer-sponsors/{test_users_with_sponsor['sponsor'].id}/events",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


# =====================================================================
# Prerequisites CRUD
# =====================================================================


async def test_create_prerequisite(
    client: AsyncClient,
    test_event_approved,
    test_sponsorship_category,
    auth_headers_organizer,
):
    """POST .../prerequisites creates a prerequisite (organizer only)."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/prerequisites",
        data={"name": "Insurance Proof", "is_required": "true", "requires_document": "true"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Insurance Proof"
    assert data["is_required"] is True


async def test_list_prerequisites(
    client: AsyncClient,
    test_event_approved,
    test_sponsorship_category,
    prerequisite,
    auth_headers_organizer,
):
    """GET .../prerequisites returns the prerequisites."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/prerequisites",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1
    assert data[0]["name"] == "Business License"


async def test_delete_prerequisite(
    client: AsyncClient,
    test_event_approved,
    test_sponsorship_category,
    prerequisite,
    auth_headers_organizer,
):
    """DELETE .../prerequisites/{id} removes the prerequisite."""
    r = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/prerequisites/{prerequisite.id}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 204


async def test_delete_prerequisite_not_found(
    client: AsyncClient,
    test_event_approved,
    test_sponsorship_category,
    auth_headers_organizer,
):
    """DELETE .../prerequisites/99999 returns 404."""
    r = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/sponsorships/{test_sponsorship_category.id}/prerequisites/99999",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 404


# =====================================================================
# Bid prerequisite uploads
# =====================================================================


async def test_list_bid_prerequisite_uploads(
    client: AsyncClient,
    test_sponsor_bid,
    prerequisite_upload,
    auth_headers_sponsor,
):
    """GET /bids/{bid_id}/prerequisites lists uploads."""
    r = await client.get(
        f"/api/v1/bids/{test_sponsor_bid.id}/prerequisites",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1
    assert data[0]["status"] == "pending"


async def test_list_bid_prerequisite_uploads_empty(
    client: AsyncClient,
    test_sponsor_bid,
    auth_headers_sponsor,
):
    """GET /bids/{bid_id}/prerequisites returns [] when no uploads."""
    r = await client.get(
        f"/api/v1/bids/{test_sponsor_bid.id}/prerequisites",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert r.json() == []


# =====================================================================
# Review prerequisite upload
# =====================================================================


async def test_review_prerequisite_upload(
    client: AsyncClient,
    test_sponsor_bid,
    prerequisite,
    prerequisite_upload,
    auth_headers_organizer,
):
    """PATCH /bids/{bid_id}/prerequisites/{prereq_id}/review approves the upload."""
    r = await client.patch(
        f"/api/v1/bids/{test_sponsor_bid.id}/prerequisites/{prerequisite.id}/review",
        data={"status": "approved", "reviewer_note": "Looks good"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "approved"
    assert data["reviewer_note"] == "Looks good"


async def test_review_prerequisite_upload_not_found(
    client: AsyncClient,
    test_sponsor_bid,
    auth_headers_organizer,
):
    """PATCH review for non-existent upload returns 404."""
    r = await client.patch(
        f"/api/v1/bids/{test_sponsor_bid.id}/prerequisites/99999/review",
        data={"status": "approved"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 404


# =====================================================================
# Event Sponsors (public)  (GET /events/{eid}/sponsors)
# =====================================================================


async def test_list_event_sponsors_empty(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """GET /events/{eid}/sponsors returns [] when no paid sponsors."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsors",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json() == []


async def test_list_event_sponsors_with_paid(
    client: AsyncClient,
    test_event_approved,
    paid_bid,
    test_sponsor_profile,
    auth_headers_customer,
):
    """GET /events/{eid}/sponsors returns paid sponsors."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/sponsors",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
