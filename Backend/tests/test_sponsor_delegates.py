"""Tests for sponsor delegate endpoints: list, add, remove, check-in."""
import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sponsor import SponsorTicket, SponsorDelegate, BidStatus, SponsorBid, SponsorshipCategory
from app.models.event import EventStatus
from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── Fixtures ──────────────────────────────────────────────────────


@pytest_asyncio.fixture
async def sponsor_ticket(
    db_session: AsyncSession,
    test_event_approved,
    test_users_with_sponsor,
):
    """A sponsor ticket for the sponsor user on the approved event."""
    ticket = SponsorTicket(
        event_id=test_event_approved.id,
        sponsor_user_id=test_users_with_sponsor["sponsor"].id,
        receipt_number=f"SPT-TEST-{test_event_approved.id}-1",
        qr_data_encrypted="test-qr-data",
    )
    db_session.add(ticket)
    await db_session.commit()
    return ticket


@pytest_asyncio.fixture
async def delegate(
    db_session: AsyncSession,
    sponsor_ticket,
):
    """A delegate on the sponsor ticket."""
    d = SponsorDelegate(
        sponsor_ticket_id=sponsor_ticket.id,
        name="John Delegate",
        email="delegate@test.com",
        phone="555-0100",
    )
    db_session.add(d)
    await db_session.commit()
    return d


# ── List delegates ────────────────────────────────────────────────


async def test_list_delegates_empty(
    client: AsyncClient,
    sponsor_ticket,
    auth_headers_sponsor,
):
    """GET /me/sponsor-tickets/{id}/delegates returns empty list when none."""
    r = await client.get(
        f"/api/v1/me/sponsor-tickets/{sponsor_ticket.id}/delegates",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert r.json() == []


async def test_list_delegates_with_data(
    client: AsyncClient,
    sponsor_ticket,
    delegate,
    auth_headers_sponsor,
):
    """GET /me/sponsor-tickets/{id}/delegates returns delegates."""
    r = await client.get(
        f"/api/v1/me/sponsor-tickets/{sponsor_ticket.id}/delegates",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1
    assert data[0]["name"] == "John Delegate"
    assert data[0]["checked_in"] is False


# ── Add delegate ──────────────────────────────────────────────────


async def test_add_delegate(
    client: AsyncClient,
    sponsor_ticket,
    auth_headers_sponsor,
):
    """POST /me/sponsor-tickets/{id}/delegates adds a delegate."""
    r = await client.post(
        f"/api/v1/me/sponsor-tickets/{sponsor_ticket.id}/delegates",
        json={"name": "New Delegate", "email": "new@test.com", "phone": "555-0101"},
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "New Delegate"
    assert data["email"] == "new@test.com"
    assert data["checked_in"] is False
    assert "id" in data


async def test_add_delegate_minimal(
    client: AsyncClient,
    sponsor_ticket,
    auth_headers_sponsor,
):
    """POST with only name (no email/phone) still works."""
    r = await client.post(
        f"/api/v1/me/sponsor-tickets/{sponsor_ticket.id}/delegates",
        json={"name": "Minimal Delegate"},
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "Minimal Delegate"
    assert data["email"] is None


async def test_add_delegate_unauthorized(
    client: AsyncClient,
    sponsor_ticket,
    auth_headers_customer,
):
    """Non-owner cannot add delegates to a ticket."""
    r = await client.post(
        f"/api/v1/me/sponsor-tickets/{sponsor_ticket.id}/delegates",
        json={"name": "Intruder"},
        headers=auth_headers_customer,
    )
    assert r.status_code in (403, 404)


# ── Remove delegate ───────────────────────────────────────────────


async def test_remove_delegate(
    client: AsyncClient,
    sponsor_ticket,
    delegate,
    auth_headers_sponsor,
):
    """DELETE /me/sponsor-tickets/{id}/delegates/{did} removes the delegate."""
    r = await client.delete(
        f"/api/v1/me/sponsor-tickets/{sponsor_ticket.id}/delegates/{delegate.id}",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


async def test_remove_delegate_not_owner(
    client: AsyncClient,
    sponsor_ticket,
    delegate,
    auth_headers_customer,
):
    """Non-owner cannot remove delegates."""
    r = await client.delete(
        f"/api/v1/me/sponsor-tickets/{sponsor_ticket.id}/delegates/{delegate.id}",
        headers=auth_headers_customer,
    )
    assert r.status_code in (403, 404)


# ── Check-in delegate ────────────────────────────────────────────


async def test_check_in_delegate(
    client: AsyncClient,
    test_event_approved,
    sponsor_ticket,
    delegate,
    auth_headers_organizer,
):
    """POST /events/{eid}/sponsor-delegates/{did}/check-in marks checked in."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsor-delegates/{delegate.id}/check-in",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["already_checked_in"] is False
    assert data["name"] == "John Delegate"
    assert data["checked_in_at"] is not None


async def test_check_in_delegate_customer_forbidden(
    client: AsyncClient,
    test_event_approved,
    sponsor_ticket,
    delegate,
    auth_headers_customer,
):
    """Customer cannot check in delegates (only organizer/admin)."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsor-delegates/{delegate.id}/check-in",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_check_in_unauthenticated(
    client: AsyncClient,
    test_event_approved,
    sponsor_ticket,
    delegate,
):
    """Check-in without auth returns 401."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/sponsor-delegates/{delegate.id}/check-in",
    )
    assert r.status_code == 401
