"""
Extended event service tests: CRUD, lifecycle, organizers, discounts, permissions.
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock

from app.models.event import Event, EventStatus, EventOrganizer, RegistrationType


# ---------------------------------------------------------------------------
# Event CRUD extended
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_events_with_filters(client, db_session, test_event_approved, auth_headers_customer):
    """List events with various filters."""
    resp = await client.get("/api/v1/events", params={"status": "approved"}, headers=auth_headers_customer)
    assert resp.status_code == 200

    resp2 = await client.get("/api/v1/events", params={"city": "Ottawa"}, headers=auth_headers_customer)
    assert resp2.status_code == 200


@pytest.mark.asyncio
async def test_list_events_with_search(client, db_session, test_event_approved, auth_headers_customer):
    """Search events by title."""
    resp = await client.get("/api/v1/events", params={"search": "Test"}, headers=auth_headers_customer)
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_get_event_by_id(client, db_session, test_event_approved, auth_headers_customer):
    """Get single event by ID."""
    resp = await client.get(f"/api/v1/events/{test_event_approved.id}", headers=auth_headers_customer)
    assert resp.status_code == 200
    assert resp.json()["id"] == test_event_approved.id


@pytest.mark.asyncio
async def test_get_event_not_found(client, db_session, auth_headers_customer):
    """Get non-existent event."""
    resp = await client.get("/api/v1/events/99999", headers=auth_headers_customer)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_update_event(client, db_session, test_event, auth_headers_organizer):
    """Organizer updates event title."""
    resp = await client.patch(
        f"/api/v1/events/{test_event.id}",
        headers=auth_headers_organizer,
        json={"title": "Updated Title"},
    )
    assert resp.status_code == 200
    assert resp.json()["title"] == "Updated Title"


@pytest.mark.asyncio
async def test_update_event_forbidden(client, db_session, test_event, auth_headers_customer):
    """Customer cannot update event."""
    resp = await client.patch(
        f"/api/v1/events/{test_event.id}",
        headers=auth_headers_customer,
        json={"title": "Hacked"},
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_delete_draft_event(client, db_session, test_event, auth_headers_organizer):
    """Organizer can delete draft event."""
    resp = await client.delete(f"/api/v1/events/{test_event.id}", headers=auth_headers_organizer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_get_genres(client, db_session, auth_headers_customer):
    """GET genres endpoint."""
    resp = await client.get("/api/v1/events/genres", headers=auth_headers_customer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_get_cities(client, db_session, auth_headers_customer):
    """GET cities endpoint."""
    resp = await client.get("/api/v1/events/cities", headers=auth_headers_customer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_get_featured_events(client, db_session, test_event_approved, auth_headers_customer):
    """GET featured events."""
    resp = await client.get("/api/v1/events/featured", headers=auth_headers_customer)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Event lifecycle extended
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_publish_event(client, db_session, test_event, test_organizer_bank, auth_headers_organizer):
    """Publish draft event."""
    resp = await client.post(f"/api/v1/events/{test_event.id}/publish", headers=auth_headers_organizer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_cancel_event(client, db_session, test_event_approved, auth_headers_organizer):
    """Cancel approved event."""
    with patch("app.worker.redis_pool.enqueue", new_callable=AsyncMock):
        resp = await client.post(
            f"/api/v1/events/{test_event_approved.id}/cancel",
            headers=auth_headers_organizer,
            json={"reason": "Testing cancellation"},
        )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_reactivate_event(client, db_session, test_event, auth_headers_organizer):
    """Reactivate cancelled event → draft."""
    test_event.status = EventStatus.cancelled
    await db_session.commit()
    resp = await client.post(f"/api/v1/events/{test_event.id}/reactivate", headers=auth_headers_organizer)
    assert resp.status_code == 200
    assert resp.json()["status"] == "draft"


@pytest.mark.asyncio
async def test_clone_event(client, db_session, test_event_completed, auth_headers_organizer):
    """Clone completed event → new draft."""
    resp = await client.post(f"/api/v1/events/{test_event_completed.id}/clone", headers=auth_headers_organizer)
    assert resp.status_code == 200
    assert resp.json()["id"] != test_event_completed.id
    assert resp.json()["status"] == "draft"


@pytest.mark.asyncio
async def test_set_event_date(client, db_session, test_event, auth_headers_organizer):
    """Set event dates."""
    start = (datetime.now(timezone.utc) + timedelta(days=60)).isoformat()
    end = (datetime.now(timezone.utc) + timedelta(days=60, hours=3)).isoformat()
    resp = await client.post(
        f"/api/v1/events/{test_event.id}/set-event-date",
        headers=auth_headers_organizer,
        json={"start_time": start, "end_time": end},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_extend_funding(client, db_session, test_event_approved, auth_headers_organizer):
    """Request funding extension."""
    new_end = (datetime.now(timezone.utc) + timedelta(days=60)).isoformat()
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/extend-funding",
        headers=auth_headers_organizer,
        json={"funding_end_at": new_end},
    )
    assert resp.status_code in (200, 400, 409)


# ---------------------------------------------------------------------------
# Event organizers
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_organizers(client, db_session, test_event_approved, auth_headers_organizer):
    """List event organizers."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/organizers",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_add_co_organizer(client, db_session, test_event_approved, test_users, auth_headers_organizer):
    """Add co-organizer to event."""
    organizer2 = test_users["organizer2"]
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/organizers",
        headers=auth_headers_organizer,
        json={"user_id": organizer2.id, "permission": "full"},
    )
    assert resp.status_code in (200, 201)


@pytest.mark.asyncio
async def test_respond_to_invitation(client, db_session, test_event_approved, test_users, auth_headers_organizer, auth_headers_organizer2):
    """Co-organizer accepts invitation."""
    organizer2 = test_users["organizer2"]
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/organizers",
        headers=auth_headers_organizer,
        json={"user_id": organizer2.id, "permission": "full"},
    )
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/organizers/{organizer2.id}/respond",
        headers=auth_headers_organizer2,
        json={"accept": True},
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Event discounts (rules)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_discount_rule(client, db_session, test_event_approved, auth_headers_organizer):
    """Create discount rule."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/discounts/rules",
        headers=auth_headers_organizer,
        json={"name": "Launch Discount", "discount_type": "ticket_percent", "value": 15, "target": "all"},
    )
    assert resp.status_code in (200, 201)


@pytest.mark.asyncio
async def test_list_discount_rules(client, db_session, test_event_approved, auth_headers_organizer):
    """List discount rules for event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/discounts/rules",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_my_discounts(client, db_session, test_event_approved, test_registration, auth_headers_customer):
    """Customer gets their discounts for event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/my-discounts",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Event reactions
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_react_to_event(client, db_session, test_event_approved, test_users, auth_headers_customer):
    """Customer reacts to event."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/react",
        params={"reaction": "like"},
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_get_my_reaction(client, db_session, test_event_approved, auth_headers_customer):
    """Get my reaction to event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/my-reaction",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Calendar export
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_event_calendar_ics(client, db_session, test_event_approved):
    """Get event calendar as iCal."""
    resp = await client.get(f"/api/v1/events/{test_event_approved.id}/calendar.ics")
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# User events
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_my_events(client, db_session, test_event, auth_headers_organizer):
    """Organizer lists their events."""
    resp = await client.get("/api/v1/me/events", headers=auth_headers_organizer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_co_organized_events(client, db_session, test_users, auth_headers_organizer2):
    """List co-organized events."""
    resp = await client.get("/api/v1/me/co-organized-events", headers=auth_headers_organizer2)
    assert resp.status_code == 200
