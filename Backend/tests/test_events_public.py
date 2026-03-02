"""
Public events API (no auth). Requires a running PostgreSQL test DB.
Skip with: pytest -k "not test_events" or set SKIP_DB_TESTS=1
"""
import os
import pytest
from httpx import AsyncClient


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(
        os.environ.get("SKIP_DB_TESTS", "").lower() in ("1", "true", "yes"),
        reason="SKIP_DB_TESTS set",
    ),
]


async def test_list_events_empty_or_ok(client: AsyncClient) -> None:
    r = await client.get("/api/v1/events")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, dict)
    assert "items" in data
