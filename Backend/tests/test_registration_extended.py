"""
Extended registration tests: waitlist approve/reject, capacity enforcement,
cancelled event, completed event, re-registration, auto-approve.
"""
import pytest

from app.models.event import EventStatus, RegistrationType
from app.models.registration import Registration, RegistrationStatus


# ---------------------------------------------------------------------------
# Registration - capacity enforcement
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_register_full_event_waitlists(client, db_session, test_event_approved, test_users, auth_headers_customer):
    """Register when at capacity → waitlist."""
    test_event_approved.max_capacity = 0  # full
    await db_session.commit()
    resp = await client.post(f"/api/v1/events/{test_event_approved.id}/register", headers=auth_headers_customer)
    assert resp.status_code == 200
    assert resp.json()["status"] == "waitlist"


@pytest.mark.asyncio
async def test_register_cancelled_event_fails(client, db_session, test_event, test_users, auth_headers_customer):
    """Cannot register for a cancelled event."""
    test_event.status = EventStatus.cancelled
    await db_session.commit()
    resp = await client.post(f"/api/v1/events/{test_event.id}/register", headers=auth_headers_customer)
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_register_completed_event_fails(client, db_session, test_event, test_users, auth_headers_customer):
    """Cannot register for a completed event."""
    test_event.status = EventStatus.completed
    await db_session.commit()
    resp = await client.post(f"/api/v1/events/{test_event.id}/register", headers=auth_headers_customer)
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_register_closed_event_waitlists(client, db_session, test_event_approved, test_users, auth_headers_customer):
    """Closed event → always waitlist."""
    test_event_approved.registration_type = RegistrationType.closed
    await db_session.commit()
    resp = await client.post(f"/api/v1/events/{test_event_approved.id}/register", headers=auth_headers_customer)
    assert resp.status_code == 200
    assert resp.json()["status"] == "waitlist"


@pytest.mark.asyncio
async def test_reregister_after_cancel(client, db_session, test_event_approved, test_users, auth_headers_customer):
    """Re-registration after cancellation reactivates."""
    # Register first
    resp1 = await client.post(f"/api/v1/events/{test_event_approved.id}/register", headers=auth_headers_customer)
    assert resp1.status_code == 200
    # Unregister
    resp2 = await client.post(f"/api/v1/events/{test_event_approved.id}/unregister", headers=auth_headers_customer)
    assert resp2.status_code == 200
    # Re-register
    resp3 = await client.post(f"/api/v1/events/{test_event_approved.id}/register", headers=auth_headers_customer)
    assert resp3.status_code == 200
    assert resp3.json()["status"] == "registered"


# ---------------------------------------------------------------------------
# Waitlist approve / reject
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_approve_waitlist(client, db_session, test_event_approved, test_users, auth_headers_organizer, auth_headers_customer):
    """Organizer approves waitlist → registered."""
    test_event_approved.registration_type = RegistrationType.closed
    await db_session.commit()
    # Customer registers → waitlist
    resp = await client.post(f"/api/v1/events/{test_event_approved.id}/register", headers=auth_headers_customer)
    reg_id = resp.json()["id"]
    # Organizer approves
    resp2 = await client.post(
        f"/api/v1/events/{test_event_approved.id}/registrations/{reg_id}/decision",
        headers=auth_headers_organizer,
        json={"action": "approve"},
    )
    assert resp2.status_code == 200
    assert resp2.json()["status"] == "registered"


@pytest.mark.asyncio
async def test_reject_waitlist(client, db_session, test_event_approved, test_users, auth_headers_organizer, auth_headers_customer):
    """Organizer rejects waitlist → cancelled."""
    test_event_approved.registration_type = RegistrationType.closed
    await db_session.commit()
    resp = await client.post(f"/api/v1/events/{test_event_approved.id}/register", headers=auth_headers_customer)
    reg_id = resp.json()["id"]
    resp2 = await client.post(
        f"/api/v1/events/{test_event_approved.id}/registrations/{reg_id}/decision",
        headers=auth_headers_organizer,
        json={"action": "reject"},
    )
    assert resp2.status_code == 200
    assert resp2.json()["status"] == "cancelled"


@pytest.mark.asyncio
async def test_approve_non_waitlist_fails(client, db_session, test_registration, test_users, auth_headers_organizer, test_event_approved):
    """Cannot approve a non-waitlist registration."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/registrations/{test_registration.id}/decision",
        headers=auth_headers_organizer,
        json={"action": "approve"},
    )
    assert resp.status_code == 409


# ---------------------------------------------------------------------------
# Unregister edge cases
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_unregister_not_registered(client, db_session, test_event_approved, test_users, auth_headers_customer):
    """Unregister when not registered → error."""
    resp = await client.post(f"/api/v1/events/{test_event_approved.id}/unregister", headers=auth_headers_customer)
    assert resp.status_code in (404, 409)


@pytest.mark.asyncio
async def test_unregister_cancelled_event_fails(client, db_session, test_event, test_users, auth_headers_customer):
    """Cannot unregister from a cancelled event."""
    test_event.status = EventStatus.cancelled
    await db_session.commit()
    resp = await client.post(f"/api/v1/events/{test_event.id}/unregister", headers=auth_headers_customer)
    assert resp.status_code in (404, 409)


# ---------------------------------------------------------------------------
# My-registration endpoint
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_my_registration_after_register(client, db_session, test_event_approved, test_users, auth_headers_customer):
    """GET my-registration returns the registration after registering."""
    await client.post(f"/api/v1/events/{test_event_approved.id}/register", headers=auth_headers_customer)
    resp = await client.get(f"/api/v1/events/{test_event_approved.id}/my-registration", headers=auth_headers_customer)
    assert resp.status_code == 200
    assert resp.json()["status"] == "registered"
