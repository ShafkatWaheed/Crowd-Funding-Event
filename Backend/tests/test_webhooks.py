"""
Stripe webhook handler tests: dispute created, invalid signature, unknown event.
"""
import json

import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_stripe_webhook_charge_disputed(
    client: AsyncClient,
    db_session,
    test_event_approved,
    test_users,
):
    """POST /webhooks/stripe with charge.dispute.created creates a Dispute record."""
    payload = {
        "type": "charge.dispute.created",
        "data": {
            "object": {
                "id": "dp_test_123",
                "charge": "ch_test_abc",
                "amount": 5000,
                "reason": "product_not_received",
                "metadata": {
                    "event_id": str(test_event_approved.id),
                    "user_id": str(test_users["customer"].id),
                },
            }
        },
    }
    r = await client.post(
        "/api/v1/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Content-Type": "application/json"},
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True

    # Verify dispute was created in DB
    from sqlalchemy import select
    from app.models.dispute import Dispute

    dispute = (await db_session.execute(
        select(Dispute).where(Dispute.stripe_dispute_id == "dp_test_123")
    )).scalar_one_or_none()
    assert dispute is not None
    assert dispute.amount_cents == 5000
    assert dispute.event_id == test_event_approved.id


async def test_stripe_webhook_duplicate_dispute(
    client: AsyncClient,
    db_session,
    test_event_approved,
    test_users,
):
    """Duplicate dispute webhook is idempotent — returns ok with 'duplicate'."""
    payload = {
        "type": "charge.dispute.created",
        "data": {
            "object": {
                "id": "dp_test_dup",
                "charge": "ch_test_dup",
                "amount": 3000,
                "reason": "fraudulent",
                "metadata": {},
            }
        },
    }
    # First call
    await client.post(
        "/api/v1/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Content-Type": "application/json"},
    )
    # Duplicate call
    r = await client.post(
        "/api/v1/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Content-Type": "application/json"},
    )
    assert r.status_code == 200
    assert r.json().get("message") == "duplicate"


async def test_stripe_webhook_unknown_event(
    client: AsyncClient,
    db_session,
):
    """POST /webhooks/stripe with unknown event type returns ok (ignored)."""
    payload = {
        "type": "payment_intent.succeeded",
        "data": {"object": {"id": "pi_test_123"}},
    }
    r = await client.post(
        "/api/v1/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Content-Type": "application/json"},
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True
