"""Event discount rules, user discounts, discount-strategy attach/detach, claimable discounts."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── Discount rules (/api/v1/events/{id}/discounts/rules) ──────────────


async def test_list_discount_rules(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    """GET /events/{id}/discounts/rules returns a list (possibly empty)."""
    eid = test_event_approved.id
    r = await client.get(
        f"/api/v1/events/{eid}/discounts/rules",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_create_discount_rule(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    """POST /events/{id}/discounts/rules creates a discount rule."""
    eid = test_event_approved.id
    r = await client.post(
        f"/api/v1/events/{eid}/discounts/rules",
        headers=auth_headers_organizer,
        json={
            "name": "Launch Promo",
            "discount_type": "ticket_percent",
            "value": 20,
            "target": "all",
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == "Launch Promo"
    assert data["discount_type"] == "ticket_percent"
    assert data["value"] == 20
    assert data["event_id"] == eid


async def test_delete_discount_rule(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer: dict[str, str],
) -> None:
    """DELETE /events/{id}/discounts/rules/{did} removes the rule."""
    eid = test_event_approved.id
    # Create one first
    create_r = await client.post(
        f"/api/v1/events/{eid}/discounts/rules",
        headers=auth_headers_organizer,
        json={
            "name": "Temp Rule",
            "discount_type": "ticket_percent",
            "value": 10,
            "target": "all",
        },
    )
    assert create_r.status_code == 200
    did = create_r.json()["id"]

    r = await client.delete(
        f"/api/v1/events/{eid}/discounts/rules/{did}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


# ── User discounts (/api/v1/events/{id}/discounts) ────────────────────


async def test_create_user_discount(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    """POST /events/{id}/discounts assigns a per-user discount."""
    eid = test_event_approved.id
    customer_id = test_users["customer"].id
    r = await client.post(
        f"/api/v1/events/{eid}/discounts",
        headers=auth_headers_organizer,
        json={
            "user_id": customer_id,
            "discount_type": "percent",
            "value": 25,
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert data["event_id"] == eid
    assert data["user_id"] == customer_id
    assert data["discount_type"] == "percent"
    assert data["value"] == 25


async def test_delete_user_discount(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer: dict[str, str],
) -> None:
    """DELETE /events/{id}/discounts/{user_id} removes the user discount."""
    eid = test_event_approved.id
    customer_id = test_users["customer"].id

    # Set up the discount first
    set_r = await client.post(
        f"/api/v1/events/{eid}/discounts",
        headers=auth_headers_organizer,
        json={
            "user_id": customer_id,
            "discount_type": "percent",
            "value": 10,
        },
    )
    assert set_r.status_code == 200

    r = await client.delete(
        f"/api/v1/events/{eid}/discounts/{customer_id}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


# ── My discounts & claimable ──────────────────────────────────────────


async def test_my_discounts(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    """GET /events/{id}/my-discounts returns discount info for current user."""
    eid = test_event_approved.id
    r = await client.get(
        f"/api/v1/events/{eid}/my-discounts",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    # Response shape may vary; at minimum it should be a valid JSON response
    assert r.json() is not None


async def test_claimable_discounts(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    """GET /events/{id}/claimable-discounts returns a list for the customer."""
    eid = test_event_approved.id
    r = await client.get(
        f"/api/v1/events/{eid}/claimable-discounts",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert isinstance(r.json(), list)


# ── Discount strategy attach / detach ─────────────────────────────────


async def test_attach_discount_strategy(
    client: AsyncClient,
    test_event_approved,
    test_discount_strategy,
    auth_headers_organizer: dict[str, str],
) -> None:
    """POST /events/{id}/discount-strategies/{sid} attaches a strategy."""
    eid = test_event_approved.id
    sid = test_discount_strategy.id
    r = await client.post(
        f"/api/v1/events/{eid}/discount-strategies/{sid}",
        headers=auth_headers_organizer,
        json={"auto_apply": True},
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


async def test_detach_discount_strategy(
    client: AsyncClient,
    test_event_approved,
    test_discount_strategy,
    auth_headers_organizer: dict[str, str],
) -> None:
    """DELETE /events/{id}/discount-strategies/{sid} detaches a strategy."""
    eid = test_event_approved.id
    sid = test_discount_strategy.id

    # Attach first so there is something to detach
    attach_r = await client.post(
        f"/api/v1/events/{eid}/discount-strategies/{sid}",
        headers=auth_headers_organizer,
        json={"auto_apply": True},
    )
    assert attach_r.status_code == 200

    r = await client.delete(
        f"/api/v1/events/{eid}/discount-strategies/{sid}",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


# ── Authorization guard ───────────────────────────────────────────────


async def test_discounts_not_customer(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer: dict[str, str],
) -> None:
    """POST /events/{id}/discounts/rules as customer returns 403."""
    eid = test_event_approved.id
    r = await client.post(
        f"/api/v1/events/{eid}/discounts/rules",
        headers=auth_headers_customer,
        json={
            "name": "Should Fail",
            "discount_type": "ticket_percent",
            "value": 5,
            "target": "all",
        },
    )
    assert r.status_code == 403
