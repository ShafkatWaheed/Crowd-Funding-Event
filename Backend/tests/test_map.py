"""Map API: GET /events/map."""
import os
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_map_events_public(client: AsyncClient, test_event_approved) -> None:
    r = await client.get("/api/v1/events/map")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    ids = [m["id"] for m in data]
    assert test_event_approved.id in ids


async def test_map_events_with_city(client: AsyncClient, test_event_approved) -> None:
    r = await client.get("/api/v1/events/map?city=Ottawa")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


async def test_map_events_live_filter(client: AsyncClient, test_event_approved) -> None:
    r = await client.get("/api/v1/events/map?live=false")
    assert r.status_code == 200
    assert isinstance(r.json(), list)
