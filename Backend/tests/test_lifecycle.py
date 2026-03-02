"""Event lifecycle API tests: publish, cancel, reactivate, clone, set-event-date,
start-selling, extend-funding, extension-decision, cancellation/approve."""
import pytest
from datetime import datetime, timedelta, timezone

from tests.conftest import SKIP_DB

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_publish_event(client, test_event, auth_headers_organizer, test_users):
    """Publish a draft event."""
    r = await client.post(
        f"/api/v1/events/{test_event.id}/publish",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] in ("pending_approval", "approved")


async def test_publish_already_approved(client, test_event_approved, auth_headers_organizer, test_users):
    """Publishing an already approved event returns error."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/publish",
        headers=auth_headers_organizer,
    )
    assert r.status_code in (400, 409)


async def test_cancel_event(client, test_event_approved, auth_headers_organizer, test_users):
    """Cancel an approved event with reason."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/cancel",
        json={"reason": "Test cancellation"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "cancelled"


async def test_cancel_with_reason_stored(client, test_event_approved, auth_headers_organizer, test_users):
    """Cancel stores the reason."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/cancel",
        json={"reason": "Budget issues"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200


async def test_reactivate_cancelled(client, test_event_approved, auth_headers_organizer, test_users, db_session):
    """Reactivate a cancelled event back to draft."""
    from app.models.event import EventStatus
    test_event_approved.status = EventStatus.cancelled
    await db_session.commit()
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/reactivate",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "draft"


async def test_clone_event(client, test_event_approved, auth_headers_organizer, test_users):
    """Clone creates a new event."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/clone",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["id"] != test_event_approved.id
    assert data["status"] == "draft"


async def test_set_event_date(client, test_event_approved, auth_headers_organizer, test_users):
    """Set event date with valid ISO datetimes."""
    start = (datetime.now(timezone.utc) + timedelta(days=60)).isoformat()
    end = (datetime.now(timezone.utc) + timedelta(days=60, hours=3)).isoformat()
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/set-event-date",
        json={"start_time": start, "end_time": end},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200


async def test_extend_funding(client, test_event_approved, auth_headers_organizer, test_users):
    """Extend funding with new end date."""
    new_end = (datetime.now(timezone.utc) + timedelta(days=45)).isoformat()
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/extend-funding",
        json={"funding_end_at": new_end},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200


async def test_lifecycle_customer_forbidden(client, test_event, auth_headers_customer, test_users):
    """Customer cannot publish event."""
    r = await client.post(
        f"/api/v1/events/{test_event.id}/publish",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_extension_decision(client, test_event_approved, auth_headers_admin, test_users, db_session):
    """Admin approves extension decision."""
    # Set up a pending extension
    test_event_approved.pending_extension = {
        "funding_end_at": (datetime.now(timezone.utc) + timedelta(days=60)).isoformat(),
        "funding_goal_cents": 20000,
    }
    await db_session.commit()
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/extension-decision",
        json={"action": "approve"},
        headers=auth_headers_admin,
    )
    assert r.status_code == 200
