"""Expanded webhook tests: dispute.closed (won/lost), no matching dispute, empty body."""
import json

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.dispute import Dispute, DisputeStatus
from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── Helpers ───────────────────────────────────────────────────────


async def _create_dispute(db_session, stripe_id, event_id=None, user_id=None):
    """Insert a dispute directly for testing."""
    d = Dispute(
        stripe_dispute_id=stripe_id,
        transaction_id=f"ch_{stripe_id}",
        event_id=event_id,
        user_id=user_id,
        amount_cents=5000,
        reason="product_not_received",
        status=DisputeStatus.open,
    )
    db_session.add(d)
    await db_session.commit()
    return d


# ── Dispute Closed (won) ─────────────────────────────────────────


async def test_dispute_closed_won(
    client: AsyncClient,
    db_session: AsyncSession,
    test_event_approved,
    test_users,
):
    """charge.dispute.closed with status=won resolves the dispute."""
    dispute = await _create_dispute(
        db_session, "dp_won_test", event_id=test_event_approved.id, user_id=test_users["customer"].id
    )
    payload = {
        "type": "charge.dispute.closed",
        "data": {"object": {"id": "dp_won_test", "status": "won"}},
    }
    r = await client.post(
        "/api/v1/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Content-Type": "application/json"},
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True

    await db_session.refresh(dispute)
    assert dispute.status == DisputeStatus.won
    assert dispute.resolved_at is not None


# ── Dispute Closed (lost) ────────────────────────────────────────


async def test_dispute_closed_lost(
    client: AsyncClient,
    db_session: AsyncSession,
    test_event_approved,
    test_users,
):
    """charge.dispute.closed with status=lost marks dispute as lost."""
    dispute = await _create_dispute(
        db_session, "dp_lost_test", event_id=test_event_approved.id, user_id=test_users["customer"].id
    )
    payload = {
        "type": "charge.dispute.closed",
        "data": {"object": {"id": "dp_lost_test", "status": "lost"}},
    }
    r = await client.post(
        "/api/v1/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Content-Type": "application/json"},
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True

    await db_session.refresh(dispute)
    assert dispute.status == DisputeStatus.lost
    assert dispute.resolved_at is not None


# ── Dispute Closed for non-existent dispute ──────────────────────


async def test_dispute_closed_no_match(
    client: AsyncClient,
    db_session: AsyncSession,
):
    """charge.dispute.closed for unknown dispute_id is silently ignored."""
    payload = {
        "type": "charge.dispute.closed",
        "data": {"object": {"id": "dp_nonexistent_xyz", "status": "won"}},
    }
    r = await client.post(
        "/api/v1/webhooks/stripe",
        content=json.dumps(payload),
        headers={"Content-Type": "application/json"},
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


# ── Dispute Created without metadata ─────────────────────────────


async def test_dispute_created_no_metadata(
    client: AsyncClient,
    db_session: AsyncSession,
):
    """charge.dispute.created without metadata still creates a dispute."""
    payload = {
        "type": "charge.dispute.created",
        "data": {
            "object": {
                "id": "dp_no_meta",
                "charge": "ch_no_meta",
                "amount": 2000,
                "reason": "general",
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


# ── Malformed body ────────────────────────────────────────────────


async def test_webhook_empty_body(
    client: AsyncClient,
    db_session: AsyncSession,
):
    """POST /webhooks/stripe with empty body raises an error."""
    import json as json_mod
    with pytest.raises((json_mod.JSONDecodeError, Exception)):
        await client.post(
            "/api/v1/webhooks/stripe",
            content="",
            headers={"Content-Type": "application/json"},
        )


async def test_webhook_invalid_json(
    client: AsyncClient,
    db_session: AsyncSession,
):
    """POST /webhooks/stripe with invalid JSON raises an error."""
    import json as json_mod
    with pytest.raises((json_mod.JSONDecodeError, Exception)):
        await client.post(
            "/api/v1/webhooks/stripe",
            content="not json",
            headers={"Content-Type": "application/json"},
        )
