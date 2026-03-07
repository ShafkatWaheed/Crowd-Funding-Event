"""Event Schedule API tests."""
import pytest
from datetime import date, datetime, timedelta, timezone
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]

BASE = "/api/v1/events"

# Helper: must use UTC date to match the test_event fixture (which uses datetime.now(timezone.utc))
_future_date = (datetime.now(timezone.utc).date() + timedelta(days=30)).isoformat()


# =====================================================================
# Schedule CRUD
# =====================================================================


async def test_list_schedule(
    client: AsyncClient,
    test_event_approved,
    test_schedule_item,
):
    """GET /events/{id}/schedule returns day-grouped list (public)."""
    r = await client.get(f"{BASE}/{test_event_approved.id}/schedule")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # Each entry is a day group with 'date' and 'items'
    day_group = data[0]
    assert "date" in day_group
    assert "items" in day_group
    assert isinstance(day_group["items"], list)
    assert len(day_group["items"]) >= 1
    assert day_group["items"][0]["title"] == "Opening Ceremony"


async def test_create_schedule_item(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """POST /events/{id}/schedule as organizer creates a single item (201)."""
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/schedule",
        json={
            "title": "Keynote Speech",
            "date": _future_date,
            "start_time": "14:00",
            "end_time": "15:30",
            "description": "Main keynote by the founder",
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 201
    data = r.json()
    assert data["title"] == "Keynote Speech"
    assert data["date"] == _future_date
    assert data["start_time"] == "14:00"
    assert data["end_time"] == "15:30"
    assert data["description"] == "Main keynote by the founder"
    assert "id" in data
    assert data["event_id"] == test_event_approved.id


async def test_bulk_create_schedule(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """POST /events/{id}/schedule/bulk creates multiple items at once (201)."""
    items = [
        {
            "title": "Workshop A",
            "date": _future_date,
            "start_time": "09:00",
            "end_time": "10:00",
        },
        {
            "title": "Workshop B",
            "date": _future_date,
            "start_time": "10:30",
            "end_time": "11:30",
        },
    ]
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/schedule/bulk",
        json=items,
        headers=auth_headers_organizer,
    )
    assert r.status_code == 201
    data = r.json()
    assert isinstance(data, list)
    assert len(data) == 2
    titles = {item["title"] for item in data}
    assert "Workshop A" in titles
    assert "Workshop B" in titles


async def test_update_schedule_item(
    client: AsyncClient,
    test_event_approved,
    test_schedule_item,
    test_users,
    auth_headers_organizer,
):
    """PATCH /events/{id}/schedule/{iid} updates schedule item fields."""
    iid = test_schedule_item.id
    r = await client.patch(
        f"{BASE}/{test_event_approved.id}/schedule/{iid}",
        json={
            "title": "Opening Ceremony (Updated)",
            "start_time": "10:30",
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["title"] == "Opening Ceremony (Updated)"
    assert data["start_time"] == "10:30"


async def test_delete_schedule_item(
    client: AsyncClient,
    test_event_approved,
    test_schedule_item,
    test_users,
    auth_headers_organizer,
):
    """DELETE /events/{id}/schedule/{iid} returns 204."""
    iid = test_schedule_item.id
    r = await client.delete(
        f"{BASE}/{test_event_approved.id}/schedule/{iid}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 204

    # Verify item is removed from the schedule
    r2 = await client.get(f"{BASE}/{test_event_approved.id}/schedule")
    assert r2.status_code == 200
    all_items = []
    for group in r2.json():
        all_items.extend(group.get("items", []))
    ids = [item["id"] for item in all_items]
    assert iid not in ids


async def test_schedule_not_organizer(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """POST /events/{id}/schedule as customer returns 403."""
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/schedule",
        json={
            "title": "Unauthorized Session",
            "date": _future_date,
            "start_time": "12:00",
            "end_time": "13:00",
        },
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_schedule_export(
    client: AsyncClient,
    test_event_approved,
    test_schedule_item,
):
    """GET /events/{id}/schedule/export returns an xlsx file download."""
    r = await client.get(
        f"{BASE}/{test_event_approved.id}/schedule/export",
    )
    assert r.status_code == 200
    assert "spreadsheetml" in r.headers.get("content-type", "")
    assert "attachment" in r.headers.get("content-disposition", "")
    # Response body should be non-empty binary data
    assert len(r.content) > 0


async def test_list_schedule_empty(
    client: AsyncClient,
    test_event_approved,
):
    """GET /events/{id}/schedule on event with no schedule items returns empty list."""
    r = await client.get(f"{BASE}/{test_event_approved.id}/schedule")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) == 0


async def test_create_schedule_item_missing_fields(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """POST /events/{id}/schedule with missing required fields returns 422."""
    # Missing 'date', 'start_time', 'end_time' — only 'title' provided
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/schedule",
        json={
            "title": "Incomplete Item",
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 422


# =====================================================================
# Overlap & validation — Phase 0B.4
# =====================================================================


async def test_schedule_overlap_detection(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """Two overlapping items on the same date should have overlaps=True in response."""
    # Create first item: 14:00-15:00
    r1 = await client.post(
        f"{BASE}/{test_event_approved.id}/schedule",
        json={
            "title": "Session A",
            "date": _future_date,
            "start_time": "14:00",
            "end_time": "15:00",
        },
        headers=auth_headers_organizer,
    )
    assert r1.status_code == 201

    # Create second overlapping item: 14:30-15:30
    r2 = await client.post(
        f"{BASE}/{test_event_approved.id}/schedule",
        json={
            "title": "Session B",
            "date": _future_date,
            "start_time": "14:30",
            "end_time": "15:30",
        },
        headers=auth_headers_organizer,
    )
    assert r2.status_code == 201

    # List schedule — both items on the same date should have overlaps flag
    r3 = await client.get(f"{BASE}/{test_event_approved.id}/schedule")
    assert r3.status_code == 200
    data = r3.json()
    # Find the day group for our future_date
    day_group = next((g for g in data if g["date"] == _future_date), None)
    assert day_group is not None
    items = day_group["items"]
    assert len(items) >= 2
    # At least one item should have overlaps=True
    assert any(item.get("overlaps") is True for item in items)


async def test_schedule_time_validation_end_before_start(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """Creating item with end_time before start_time returns 400/422."""
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/schedule",
        json={
            "title": "Bad Time",
            "date": _future_date,
            "start_time": "15:00",
            "end_time": "14:00",
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code in (400, 409, 422)


async def test_schedule_date_out_of_range(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """Creating item with date far outside event range returns 400/422."""
    past_date = "2020-01-01"
    r = await client.post(
        f"{BASE}/{test_event_approved.id}/schedule",
        json={
            "title": "Past Item",
            "date": past_date,
            "start_time": "10:00",
            "end_time": "11:00",
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code in (400, 409, 422)
