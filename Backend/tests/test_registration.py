"""Registration API: register, unregister, my-registration, list registrations, decision."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_register_open_event(client, test_event_approved, auth_headers_customer, test_users):
    """Register on open event returns status=registered."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "registered"
    assert data["event_id"] == test_event_approved.id


async def test_register_closed_event(client, test_event_approved, auth_headers_customer, test_users, db_session):
    """Register on closed event returns status=waitlist."""
    from app.models.event import RegistrationType
    test_event_approved.registration_type = RegistrationType.closed
    await db_session.commit()
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "waitlist"


async def test_register_already_registered(client, test_event_approved, test_registration, auth_headers_customer, test_users):
    """Second registration returns 409."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    assert r.status_code == 409


async def test_register_draft_event(client, test_event, auth_headers_customer, test_users):
    """Register on draft event fails."""
    r = await client.post(
        f"/api/v1/events/{test_event.id}/register",
        headers=auth_headers_customer,
    )
    assert r.status_code in (400, 409)


async def test_my_registration_exists(client, test_event_approved, test_registration, auth_headers_customer, test_users):
    """GET my-registration when registered returns registered=True."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/my-registration",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["registered"] is True
    assert data["status"] == "registered"


async def test_my_registration_none(client, test_event_approved, auth_headers_customer, test_users):
    """GET my-registration when not registered returns registered=False."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/my-registration",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["registered"] is False


async def test_unregister(client, test_event_approved, test_registration, auth_headers_customer, test_users):
    """POST unregister succeeds."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/unregister",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert "refunded_cents" in data


async def test_unregister_not_registered(client, test_event_approved, auth_headers_customer, test_users):
    """Unregister when not registered returns error."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/unregister",
        headers=auth_headers_customer,
    )
    assert r.status_code in (404, 400, 409)


async def test_list_registrations_organizer(client, test_event_approved, test_registration, auth_headers_organizer, test_users):
    """GET registrations as organizer returns list."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/registrations",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_list_registrations_customer_forbidden(client, test_event_approved, auth_headers_customer, test_users):
    """GET registrations as customer returns 403."""
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/registrations",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_register_unauthenticated(client, test_event_approved, test_users):
    """Register without auth returns 401/403."""
    r = await client.post(f"/api/v1/events/{test_event_approved.id}/register")
    assert r.status_code in (401, 403)
