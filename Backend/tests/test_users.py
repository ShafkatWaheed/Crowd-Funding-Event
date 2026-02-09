"""Users API: GET/PATCH /me, GET /me/pledges, GET /me/tickets."""
import os
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_get_me_requires_auth(client: AsyncClient) -> None:
    r = await client.get("/api/v1/me")
    assert r.status_code == 401


async def test_get_me_success(
    client: AsyncClient,
    test_users: dict,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/me", headers=auth_headers_organizer)
    assert r.status_code == 200
    data = r.json()
    assert data["email"] == "organizer@test.com"
    assert data["role"] == "organizer"
    assert "id" in data


async def test_patch_me(
    client: AsyncClient,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.patch(
        "/api/v1/me",
        headers=auth_headers_customer,
        json={"display_name": "New Name"},
    )
    assert r.status_code == 200
    assert r.json()["display_name"] == "New Name"


async def test_get_my_pledges_requires_customer(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/me/pledges", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_get_my_pledges_success(
    client: AsyncClient,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/me/pledges", headers=auth_headers_customer)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_get_my_tickets_requires_customer(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/me/tickets", headers=auth_headers_organizer)
    assert r.status_code == 403


async def test_get_my_tickets_success(
    client: AsyncClient,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.get("/api/v1/me/tickets", headers=auth_headers_customer)
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_get_me_as_admin(
    client: AsyncClient,
    test_users,
    auth_headers_admin: dict[str, str],
) -> None:
    r = await client.get("/api/v1/me", headers=auth_headers_admin)
    assert r.status_code == 200
    assert r.json()["role"] == "admin"
    assert r.json()["email"] == "admin@test.com"


async def test_patch_me_empty_body(
    client: AsyncClient,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.patch("/api/v1/me", headers=auth_headers_customer, json={})
    assert r.status_code == 200
