"""Tests for the public config endpoint."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_get_public_config(client: AsyncClient, test_users):
    """GET /config returns dict with expected boolean and integer keys."""
    r = await client.get("/api/v1/config")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, dict)
    # Integer keys
    assert "max_tickets_per_purchase" in data
    assert "waitlist_max_size_limit" in data
    assert "event_max_images_limit" in data
    # Boolean keys
    assert "feature_sponsors_enabled" in data
    assert "feature_milestones_enabled" in data


async def test_config_returns_consistent_types(client: AsyncClient, test_users):
    """Config integers are ints and booleans are bools."""
    r = await client.get("/api/v1/config")
    data = r.json()
    assert isinstance(data["max_tickets_per_purchase"], int)
    assert isinstance(data["feature_sponsors_enabled"], bool)


async def test_config_no_auth_required(client: AsyncClient, test_users):
    """Config endpoint does not require authentication."""
    r = await client.get("/api/v1/config")
    assert r.status_code == 200


async def test_config_cached_second_call(client: AsyncClient, test_users):
    """Calling config twice returns same data (cache hit)."""
    r1 = await client.get("/api/v1/config")
    r2 = await client.get("/api/v1/config")
    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r1.json() == r2.json()


async def test_config_has_all_expected_keys(client: AsyncClient, test_users):
    """Config response includes all public int + bool keys."""
    r = await client.get("/api/v1/config")
    data = r.json()
    expected_int_keys = [
        "max_tickets_per_purchase",
        "waitlist_max_size_limit",
        "event_max_images_limit",
        "max_posts_per_event_limit",
        "max_co_organizers_limit",
    ]
    expected_bool_keys = [
        "max_tickets_frontend_enabled",
        "feature_milestones_enabled",
        "feature_schedule_enabled",
        "feature_sponsors_enabled",
        "feature_community_rules_enabled",
    ]
    for key in expected_int_keys:
        assert key in data, f"Missing int key: {key}"
    for key in expected_bool_keys:
        assert key in data, f"Missing bool key: {key}"
