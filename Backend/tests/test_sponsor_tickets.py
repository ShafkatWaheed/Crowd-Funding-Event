"""Tests for sponsor ticket endpoints: list, scan, scanned list."""
import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sponsor import SponsorTicket, SponsorDelegate, BidStatus
from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── Fixtures ──────────────────────────────────────────────────────


@pytest_asyncio.fixture
async def sponsor_ticket_with_event(
    db_session: AsyncSession,
    test_event_approved,
    test_users_with_sponsor,
):
    """A sponsor ticket (with QR) for the sponsor user on the approved event."""
    ticket = SponsorTicket(
        event_id=test_event_approved.id,
        sponsor_user_id=test_users_with_sponsor["sponsor"].id,
        receipt_number=f"SPT-TEST-{test_event_approved.id}-1",
        qr_data_encrypted="encrypted-qr-payload-abc",
    )
    db_session.add(ticket)
    await db_session.commit()
    return ticket


# ── List my sponsor tickets ──────────────────────────────────────


async def test_list_sponsor_tickets_empty(
    client: AsyncClient,
    test_users_with_sponsor,
    auth_headers_sponsor,
):
    """GET /me/sponsor-tickets returns [] when sponsor has no tickets."""
    r = await client.get(
        "/api/v1/me/sponsor-tickets",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    assert r.json() == []


async def test_list_sponsor_tickets_with_ticket(
    client: AsyncClient,
    sponsor_ticket_with_event,
    test_sponsor_profile,
    auth_headers_sponsor,
):
    """GET /me/sponsor-tickets returns the sponsor's ticket."""
    r = await client.get(
        "/api/v1/me/sponsor-tickets",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1
    ticket = data[0]
    assert ticket["event_id"] == sponsor_ticket_with_event.event_id
    assert ticket["receipt_number"] == sponsor_ticket_with_event.receipt_number
    assert "categories" in ticket
    assert "event_title" in ticket


async def test_list_sponsor_tickets_unauthenticated(client: AsyncClient, test_users):
    """GET /me/sponsor-tickets without auth returns 401."""
    r = await client.get("/api/v1/me/sponsor-tickets")
    assert r.status_code == 401


# ── Scan sponsor ticket ──────────────────────────────────────────


async def test_scan_sponsor_ticket_missing_payload(
    client: AsyncClient,
    test_event_approved,
    sponsor_ticket_with_event,
    auth_headers_organizer,
):
    """POST /events/{eid}/scan-sponsor with empty payload returns 400."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-sponsor",
        json={"encrypted_payload": ""},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 400


async def test_scan_sponsor_ticket_no_payload_field(
    client: AsyncClient,
    test_event_approved,
    sponsor_ticket_with_event,
    auth_headers_organizer,
):
    """POST /events/{eid}/scan-sponsor with missing field returns 400."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-sponsor",
        json={},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 400


async def test_scan_sponsor_ticket_customer_forbidden(
    client: AsyncClient,
    test_event_approved,
    sponsor_ticket_with_event,
    auth_headers_customer,
):
    """Customer cannot scan sponsor tickets (only organizer/admin)."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-sponsor",
        json={"encrypted_payload": "some-data"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_scan_sponsor_unauthenticated(
    client: AsyncClient,
    test_event_approved,
    sponsor_ticket_with_event,
):
    """Scan without auth returns 401."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-sponsor",
        json={"encrypted_payload": "some-data"},
    )
    assert r.status_code == 401


# ── Scanned sponsor tickets list ─────────────────────────────────


async def test_scanned_sponsor_tickets_empty(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
):
    """GET /events/{eid}/scanned-sponsor-tickets returns [] when none scanned."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-sponsor-tickets",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json() == []


async def test_scanned_sponsor_tickets_customer_forbidden(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
):
    """Customer cannot view scanned sponsor tickets."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-sponsor-tickets",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_scanned_sponsor_tickets_unauthenticated(
    client: AsyncClient,
    test_event_approved,
    test_users,
):
    """No auth returns 401 for scanned tickets list."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-sponsor-tickets",
    )
    assert r.status_code == 401
