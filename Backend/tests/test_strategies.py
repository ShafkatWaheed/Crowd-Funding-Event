"""Ticket-strategy & Discount-strategy CRUD endpoints."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── Ticket strategies (/api/v1/ticket-strategies) ──────────────────────


async def test_list_ticket_strategies(
    client: AsyncClient,
    test_ticket_strategy,
    auth_headers_organizer: dict[str, str],
) -> None:
    """GET /ticket-strategies returns the organizer's strategies."""
    r = await client.get("/api/v1/ticket-strategies", headers=auth_headers_organizer)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    names = [s["name"] for s in data]
    assert "Concert Standard" in names


async def test_create_ticket_strategy(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    """POST /ticket-strategies creates a new strategy with tiers."""
    r = await client.post(
        "/api/v1/ticket-strategies",
        headers=auth_headers_organizer,
        json={
            "name": "Gala VIP",
            "tiers": [
                {"name": "VIP", "price_cents": 5000},
                {"name": "Standard", "price_cents": 2000},
            ],
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "Gala VIP"
    assert len(data["tiers"]) == 2
    tier_names = {t["name"] for t in data["tiers"]}
    assert tier_names == {"VIP", "Standard"}


async def test_get_ticket_strategy(
    client: AsyncClient,
    test_ticket_strategy,
    auth_headers_organizer: dict[str, str],
) -> None:
    """GET /ticket-strategies/{id} returns the strategy with tiers."""
    sid = test_ticket_strategy.id
    r = await client.get(
        f"/api/v1/ticket-strategies/{sid}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["id"] == sid
    assert data["name"] == "Concert Standard"
    assert len(data["tiers"]) >= 1
    assert data["tiers"][0]["name"] == "General"
    assert data["tiers"][0]["price_cents"] == 2500


async def test_delete_ticket_strategy(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    """DELETE /ticket-strategies/{id} removes the strategy."""
    # Create one to delete (don't touch the shared fixture)
    create_r = await client.post(
        "/api/v1/ticket-strategies",
        headers=auth_headers_organizer,
        json={
            "name": "Throwaway",
            "tiers": [{"name": "Basic", "price_cents": 1000}],
        },
    )
    assert create_r.status_code == 200
    sid = create_r.json()["id"]

    r = await client.delete(
        f"/api/v1/ticket-strategies/{sid}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True

    # Confirm it's gone
    get_r = await client.get(
        f"/api/v1/ticket-strategies/{sid}",
        headers=auth_headers_organizer,
    )
    assert get_r.status_code == 404


async def test_strategies_not_organizer(
    client: AsyncClient,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    """POST /ticket-strategies as customer returns 403."""
    r = await client.post(
        "/api/v1/ticket-strategies",
        headers=auth_headers_customer,
        json={
            "name": "Should Fail",
            "tiers": [{"name": "Tier", "price_cents": 100}],
        },
    )
    assert r.status_code == 403


# ── Discount strategies (/api/v1/discount-strategies) ──────────────────


async def test_list_discount_strategies(
    client: AsyncClient,
    test_discount_strategy,
    auth_headers_organizer: dict[str, str],
) -> None:
    """GET /discount-strategies returns the organizer's discount strategies."""
    r = await client.get("/api/v1/discount-strategies", headers=auth_headers_organizer)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    names = [d["name"] for d in data]
    assert "Early Bird 10%" in names


async def test_create_discount_strategy(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    """POST /discount-strategies creates a new discount strategy."""
    r = await client.post(
        "/api/v1/discount-strategies",
        headers=auth_headers_organizer,
        json={
            "name": "Pledger Bonus",
            "discount_type": "ticket_percent",
            "value": 15,
            "target": "pledgers",
        },
    )
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Pledger Bonus"
    assert data["discount_type"] == "ticket_percent"
    assert data["value"] == 15
    assert data["target"] == "pledgers"


async def test_get_discount_strategy(
    client: AsyncClient,
    test_discount_strategy,
    auth_headers_organizer: dict[str, str],
) -> None:
    """GET /discount-strategies/{id} returns the strategy."""
    sid = test_discount_strategy.id
    r = await client.get(
        f"/api/v1/discount-strategies/{sid}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["id"] == sid
    assert data["name"] == "Early Bird 10%"
    assert data["discount_type"] == "ticket_percent"
    assert data["value"] == 10


async def test_delete_discount_strategy(
    client: AsyncClient,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    """DELETE /discount-strategies/{id} removes the strategy (204)."""
    # Create one to delete
    create_r = await client.post(
        "/api/v1/discount-strategies",
        headers=auth_headers_organizer,
        json={
            "name": "Temp Discount",
            "discount_type": "fixed_cents",
            "value": 500,
            "target": "all",
        },
    )
    assert create_r.status_code == 201
    sid = create_r.json()["id"]

    r = await client.delete(
        f"/api/v1/discount-strategies/{sid}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 204

    # Confirm it's gone
    get_r = await client.get(
        f"/api/v1/discount-strategies/{sid}",
        headers=auth_headers_organizer,
    )
    assert get_r.status_code == 404


async def test_discount_strategies_not_customer(
    client: AsyncClient,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    """POST /discount-strategies as customer returns 403."""
    r = await client.post(
        "/api/v1/discount-strategies",
        headers=auth_headers_customer,
        json={
            "name": "Nope",
            "discount_type": "ticket_percent",
            "value": 5,
            "target": "all",
        },
    )
    assert r.status_code == 403
