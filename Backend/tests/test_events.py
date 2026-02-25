"""Events API: list, CRUD, submit, cancel, pledge, register, organizers, tiers, tickets, etc."""
import os
from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


def _future_iso(hours_from_now: float = 24) -> str:
    t = datetime.now(timezone.utc) + timedelta(hours=hours_from_now)
    return t.isoformat().replace("+00:00", "Z")


async def test_list_events_public(client: AsyncClient, test_event_approved) -> None:
    """Public list excludes draft; use approved event so it appears."""
    r = await client.get("/api/v1/events")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    titles = [e["title"] for e in data]
    assert "Test Event" in titles


async def test_list_events_with_filters(client: AsyncClient, test_event) -> None:
    r = await client.get("/api/v1/events?city=Ottawa&has_funding=true")
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_get_event(client: AsyncClient, test_event) -> None:
    r = await client.get(f"/api/v1/events/{test_event.id}")
    assert r.status_code == 200
    data = r.json()
    assert data["title"] == "Test Event"
    assert "venue" in data
    assert "total_pledged_cents" in data
    assert "funding_days_left" in data


async def test_get_event_404(client: AsyncClient) -> None:
    r = await client.get("/api/v1/events/999999")
    assert r.status_code == 404


async def test_create_event_requires_auth(client: AsyncClient, test_venue) -> None:
    r = await client.post(
        "/api/v1/events",
        json={
            "venue_id": test_venue.id,
            "title": "New Event",
            "start_time": _future_iso(48),
            "end_time": _future_iso(50),
            "min_pledge_cents": 100,
            "max_capacity": 30,
        },
    )
    assert r.status_code == 401


async def test_create_event_success(
    client: AsyncClient,
    test_venue,
    auth_headers_organizer: dict[str, str],
) -> None:
    """Create event: need funding_end_at or ticket_strategy_id when no funding; add funding_end_at."""
    funding_end = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat().replace("+00:00", "Z")
    r = await client.post(
        "/api/v1/events",
        headers=auth_headers_organizer,
        json={
            "venue_id": test_venue.id,
            "title": "Created Event",
            "description": "Desc",
            "start_time": _future_iso(48),
            "end_time": _future_iso(50),
            "funding_end_at": funding_end,
            "funding_goal_cents": 5000,
            "min_pledge_cents": 200,
            "max_capacity": 40,
            "registration_type": "open",
        },
    )
    assert r.status_code == 200
    assert r.json()["title"] == "Created Event"
    assert r.json()["status"] == "draft"


async def test_patch_event(
    client: AsyncClient,
    test_event,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/events/{test_event.id}",
        headers=auth_headers_organizer,
        json={"title": "Updated Title"},
    )
    assert r.status_code == 200
    assert r.json()["title"] == "Updated Title"


async def test_get_calendar_ics(client: AsyncClient, test_event) -> None:
    r = await client.get(f"/api/v1/events/{test_event.id}/calendar.ics")
    assert r.status_code == 200
    assert "text/calendar" in r.headers.get("content-type", "")
    assert b"BEGIN:VCALENDAR" in r.content
    assert b"Test Event" in r.content


async def test_publish_event(
    client: AsyncClient,
    test_event,
    auth_headers_organizer: dict[str, str],
) -> None:
    """Publish draft event (draft → approved); backend has /publish, no /submit."""
    r = await client.post(
        f"/api/v1/events/{test_event.id}/publish",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["status"] == "approved"


async def test_delete_draft_event(
    client: AsyncClient,
    auth_headers_organizer: dict[str, str],
    test_venue,
) -> None:
    funding_end = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat().replace("+00:00", "Z")
    create_r = await client.post(
        "/api/v1/events",
        headers=auth_headers_organizer,
        json={
            "venue_id": test_venue.id,
            "title": "To Delete",
            "start_time": _future_iso(48),
            "end_time": _future_iso(50),
            "funding_end_at": funding_end,
            "funding_goal_cents": 3000,
            "min_pledge_cents": 100,
            "max_capacity": 20,
        },
    )
    assert create_r.status_code == 200
    eid = create_r.json()["id"]
    r = await client.delete(f"/api/v1/events/{eid}", headers=auth_headers_organizer)
    assert r.status_code == 200
    get_r = await client.get(f"/api/v1/events/{eid}")
    assert get_r.status_code == 404


async def test_get_funding(client: AsyncClient, test_event_approved) -> None:
    r = await client.get(f"/api/v1/events/{test_event_approved.id}/funding")
    assert r.status_code == 200
    data = r.json()
    assert "total_pledged_cents" in data
    assert "goal_cents" in data
    assert "backers_count" in data


async def test_pledge_requires_customer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/pledge",
        headers=auth_headers_organizer,
        json={"amount_cents": 1000},
    )
    assert r.status_code == 403


async def test_pledge_success(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/pledge",
        headers=auth_headers_customer,
        json={"amount_cents": 1000},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["amount_cents"] == 1000
    assert data["status"] == "pledged"


async def test_register_success(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["status"] in ("registered", "waitlist")


async def test_unregister(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer: dict[str, str],
) -> None:
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/unregister",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert "refunded_cents" in r.json()


async def test_list_registrations_requires_organizer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/registrations",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_list_registrations_success(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/registrations",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_list_organizers(
    client: AsyncClient,
    test_event,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event.id}/organizers",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data) >= 1
    main = next((o for o in data if o["is_main"]), None)
    assert main is not None


async def test_list_ticket_tiers_empty(client: AsyncClient, test_event) -> None:
    r = await client.get(f"/api/v1/events/{test_event.id}/ticket-tiers")
    assert r.status_code == 200
    assert r.json() == []


async def test_create_ticket_tier(
    client: AsyncClient,
    test_event,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event.id}/ticket-tiers",
        headers=auth_headers_organizer,
        json={"name": "VIP", "price_cents": 5000, "display_order": 0},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "VIP"
    assert data["price_cents"] == 5000


async def test_ticket_price_requires_ticket_tier_id(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-price",
        headers=auth_headers_customer,
    )
    assert r.status_code in (400, 422)  # ticket_tier_id required


async def test_scan_ticket_requires_organizer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-ticket",
        headers=auth_headers_customer,
        json={"ticket_code": "any"},
    )
    assert r.status_code == 403


async def test_scan_ticket_invalid_code(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-ticket",
        headers=auth_headers_organizer,
        json={"ticket_code": "invalid-code-123"},
    )
    assert r.status_code == 404


async def test_list_ticket_sales(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-sales",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_list_scanned_tickets(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-tickets",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    # All returned tickets must have scanned_at set
    for item in data:
        assert item.get("scanned_at") is not None


async def test_cancel_event(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/cancel",
        headers=auth_headers_organizer,
        json={"reason": "Test cancellation"},
    )
    assert r.status_code == 200
    assert r.json()["status"] == "cancelled"


async def test_extend_funding(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    new_end = (datetime.now(timezone.utc) + timedelta(days=60)).isoformat().replace("+00:00", "Z")
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/extend-funding",
        headers=auth_headers_organizer,
        json={"funding_end_at": new_end, "funding_goal_cents": None},
    )
    assert r.status_code == 200
    data = r.json()
    assert "funding_end_at" in data or "end_time" in data


async def test_add_and_remove_co_organizer(
    client: AsyncClient,
    test_event,
    test_users: dict,
    auth_headers_organizer: dict[str, str],
) -> None:
    organizer2 = test_users["organizer2"]
    add_r = await client.post(
        f"/api/v1/events/{test_event.id}/organizers",
        headers=auth_headers_organizer,
        json={"user_id": organizer2.id},
    )
    assert add_r.status_code == 200
    assert add_r.json()["user_id"] == organizer2.id
    list_r = await client.get(
        f"/api/v1/events/{test_event.id}/organizers",
        headers=auth_headers_organizer,
    )
    assert len(list_r.json()) >= 2
    remove_r = await client.delete(
        f"/api/v1/events/{test_event.id}/organizers/{organizer2.id}",
        headers=auth_headers_organizer,
    )
    assert remove_r.status_code == 200


async def test_add_organizer_requires_main_organizer(
    client: AsyncClient,
    test_event,
    test_users: dict,
    auth_headers_organizer2: dict[str, str],
) -> None:
    """Only main organizer can add co-organizers; organizer2 is not main."""
    r = await client.post(
        f"/api/v1/events/{test_event.id}/organizers",
        headers=auth_headers_organizer2,
        json={"user_id": test_users["organizer"].id},
    )
    assert r.status_code == 403


async def test_registration_decision_approve(
    client: AsyncClient,
    db_session,
    test_event_approved,
    test_users: dict,
    auth_headers_customer: dict[str, str],
    auth_headers_organizer: dict[str, str],
) -> None:
    """For closed event, customer registers (waitlist), organizer approves."""
    from app.models.event import RegistrationType
    test_event_approved.registration_type = RegistrationType.closed
    await db_session.commit()
    reg_r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    assert reg_r.status_code == 200
    reg_id = reg_r.json()["id"]
    decision_r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/registrations/{reg_id}/decision",
        headers=auth_headers_organizer,
        json={"action": "approve"},
    )
    assert decision_r.status_code == 200
    assert decision_r.json()["status"] == "registered"
