"""Tickets API: ticket-tiers CRUD, ticket-price, purchase-ticket, scan-ticket, ticket-sales, scanned-tickets, discounts."""
import os
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ----- Ticket tiers -----
async def test_list_ticket_tiers_public(client: AsyncClient, test_event_approved, test_ticket_tier) -> None:
    """List ticket tiers is public (no auth)."""
    r = await client.get(f"/api/v1/events/{test_event_approved.id}/ticket-tiers")
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(t["name"] == "General" for t in data)


async def test_create_ticket_tier_requires_auth(client: AsyncClient, test_event_approved) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/ticket-tiers",
        json={"name": "VIP", "price_cents": 5000, "display_order": 0},
    )
    assert r.status_code == 401


async def test_create_ticket_tier_success(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/ticket-tiers",
        headers=auth_headers_organizer,
        json={"name": "VIP", "price_cents": 5000, "display_order": 1},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "VIP"
    assert data["price_cents"] == 5000
    assert data["event_id"] == test_event_approved.id


async def test_update_ticket_tier(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/events/{test_event_approved.id}/ticket-tiers/{test_ticket_tier.id}",
        headers=auth_headers_organizer,
        json={"name": "General Updated", "price_cents": 3000},
    )
    assert r.status_code == 200
    assert r.json()["name"] == "General Updated"
    assert r.json()["price_cents"] == 3000


async def test_delete_ticket_tier(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    create_r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/ticket-tiers",
        headers=auth_headers_organizer,
        json={"name": "To Delete", "price_cents": 1000, "display_order": 10},
    )
    assert create_r.status_code == 200
    tier_id = create_r.json()["id"]
    r = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/ticket-tiers/{tier_id}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    list_r = await client.get(f"/api/v1/events/{test_event_approved.id}/ticket-tiers")
    assert not any(t["id"] == tier_id for t in list_r.json())


async def test_update_ticket_tier_404(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.patch(
        f"/api/v1/events/{test_event_approved.id}/ticket-tiers/999999",
        headers=auth_headers_organizer,
        json={"name": "X"},
    )
    assert r.status_code == 404


# ----- Ticket price -----
async def test_ticket_price_success(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-price",
        headers=auth_headers_customer,
        params={"ticket_tier_id": test_ticket_tier.id},
    )
    assert r.status_code == 200
    data = r.json()
    assert "tier_price_cents" in data
    assert "final_price_cents" in data
    assert data["tier_price_cents"] == 2500


async def test_ticket_price_requires_customer(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-price",
        headers=auth_headers_organizer,
        params={"ticket_tier_id": test_ticket_tier.id},
    )
    assert r.status_code == 403


# ----- Purchase ticket -----
async def test_purchase_ticket_requires_auth(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/purchase-ticket",
        json={"tier_id": test_ticket_tier.id},
    )
    assert r.status_code == 401


async def test_purchase_ticket_requires_customer(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/purchase-ticket",
        headers=auth_headers_organizer,
        json={"tier_id": test_ticket_tier.id},
    )
    assert r.status_code == 403


async def test_purchase_ticket_requires_registered(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_customer: dict[str, str],
) -> None:
    """Customer must be registered before purchasing."""
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/purchase-ticket",
        headers=auth_headers_customer,
        json={"tier_id": test_ticket_tier.id},
    )
    assert r.status_code in (403, 409)  # not registered


async def test_purchase_ticket_success(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_customer: dict[str, str],
) -> None:
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/purchase-ticket",
        headers=auth_headers_customer,
        json={"tier_id": test_ticket_tier.id},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["event_id"] == test_event_approved.id
    assert data["ticket_tier_id"] == test_ticket_tier.id
    assert "ticket_code" in data and len(data["ticket_code"]) > 0
    assert data["scanned_at"] is None


# ----- Scan ticket -----
async def test_scan_ticket_success(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_customer: dict[str, str],
    auth_headers_organizer: dict[str, str],
) -> None:
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    purchase_r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/purchase-ticket",
        headers=auth_headers_customer,
        json={"tier_id": test_ticket_tier.id},
    )
    assert purchase_r.status_code == 200
    ticket_code = purchase_r.json()["ticket_code"]

    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-ticket",
        headers=auth_headers_organizer,
        json={"ticket_code": ticket_code},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["already_scanned"] is False
    assert data["ticket"]["scanned_at"] is not None
    assert data["ticket"]["ticket_code"] == ticket_code


async def test_scan_ticket_already_scanned(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_customer: dict[str, str],
    auth_headers_organizer: dict[str, str],
) -> None:
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    purchase_r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/purchase-ticket",
        headers=auth_headers_customer,
        json={"tier_id": test_ticket_tier.id},
    )
    ticket_code = purchase_r.json()["ticket_code"]
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-ticket",
        headers=auth_headers_organizer,
        json={"ticket_code": ticket_code},
    )
    r2 = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-ticket",
        headers=auth_headers_organizer,
        json={"ticket_code": ticket_code},
    )
    assert r2.status_code == 200
    assert r2.json()["already_scanned"] is True


async def test_scan_ticket_invalid_code(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-ticket",
        headers=auth_headers_organizer,
        json={"ticket_code": "nonexistent-code-xyz"},
    )
    assert r.status_code == 404


# ----- Ticket sales & scanned-tickets -----
async def test_ticket_sales_requires_organizer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/ticket-sales",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_scanned_tickets_requires_organizer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-tickets",
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_scanned_tickets_after_scan(
    client: AsyncClient,
    test_event_approved,
    test_ticket_tier,
    auth_headers_customer: dict[str, str],
    auth_headers_organizer: dict[str, str],
) -> None:
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/register",
        headers=auth_headers_customer,
    )
    purchase_r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/purchase-ticket",
        headers=auth_headers_customer,
        json={"tier_id": test_ticket_tier.id},
    )
    ticket_code = purchase_r.json()["ticket_code"]
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/scan-ticket",
        headers=auth_headers_organizer,
        json={"ticket_code": ticket_code},
    )
    r = await client.get(
        f"/api/v1/events/{test_event_approved.id}/scanned-tickets",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert len(data) == 1
    assert data[0]["scanned_at"] is not None
    assert data[0]["ticket_code"] == ticket_code


# ----- Discounts -----
async def test_set_discount_requires_organizer(
    client: AsyncClient,
    test_event_approved,
    test_users: dict,
    auth_headers_customer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/discounts",
        headers=auth_headers_customer,
        json={"user_id": test_users["customer"].id, "discount_type": "percent", "value": 20},
    )
    assert r.status_code == 403


async def test_set_discount_success(
    client: AsyncClient,
    test_event_approved,
    test_users: dict,
    auth_headers_organizer: dict[str, str],
) -> None:
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/discounts",
        headers=auth_headers_organizer,
        json={"user_id": test_users["customer"].id, "discount_type": "percent", "value": 15},
    )
    assert r.status_code == 200
    data = r.json()
    assert data["event_id"] == test_event_approved.id
    assert data["user_id"] == test_users["customer"].id
    assert data["discount_type"] == "percent"
    assert data["value"] == 15


async def test_remove_discount(
    client: AsyncClient,
    test_event_approved,
    test_users: dict,
    auth_headers_organizer: dict[str, str],
) -> None:
    await client.post(
        f"/api/v1/events/{test_event_approved.id}/discounts",
        headers=auth_headers_organizer,
        json={"user_id": test_users["customer"].id, "discount_type": "fixed_cents", "value": 500},
    )
    r = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/discounts/{test_users['customer'].id}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
