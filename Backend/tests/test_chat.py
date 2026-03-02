"""Chat REST API: conversations, messages, mark-read (no WebSocket tests)."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# =====================================================================
# 1. List conversations (authenticated)
# =====================================================================


async def test_list_conversations(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """GET /chat/conversations as customer returns a list (possibly empty)."""
    r = await client.get(
        "/api/v1/chat/conversations",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


# =====================================================================
# 2. Chat unauthenticated returns 401/403
# =====================================================================


async def test_chat_unauthenticated(
    client: AsyncClient,
    test_users,
):
    """GET /chat/conversations without auth returns 401 or 403."""
    r = await client.get("/api/v1/chat/conversations")
    assert r.status_code in (401, 403)


# =====================================================================
# 3. List conversations returns empty when no bids/conversations exist
# =====================================================================


async def test_list_conversations_empty(
    client: AsyncClient,
    test_users,
    auth_headers_organizer,
):
    """GET /chat/conversations for organizer with no bids returns empty list."""
    r = await client.get(
        "/api/v1/chat/conversations",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) == 0


# =====================================================================
# 4. Chat messages for invalid bid returns 403/404
# =====================================================================


async def test_chat_messages_invalid_bid(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """GET /chat/bids/999999/messages returns 403 or 404 for a nonexistent bid."""
    r = await client.get(
        "/api/v1/chat/bids/999999/messages",
        headers=auth_headers_customer,
    )
    assert r.status_code in (403, 404)


# =====================================================================
# 5. Mark chat as read for invalid bid returns error
# =====================================================================


async def test_chat_read_endpoint(
    client: AsyncClient,
    test_users,
    auth_headers_customer,
):
    """POST /chat/bids/{bid_id}/read returns 403/404 when user is not a participant."""
    r = await client.post(
        "/api/v1/chat/bids/999999/read",
        params={"message_id": "0-0"},
        headers=auth_headers_customer,
    )
    assert r.status_code in (403, 404)


# =====================================================================
# 6. Chat participant validation — Phase 0B.3
# =====================================================================


async def test_validate_participant_sponsor(
    client: AsyncClient,
    test_users_with_sponsor,
    test_sponsor_bid,
    auth_headers_sponsor,
):
    """Sponsor can access their own bid's chat messages endpoint."""
    r = await client.get(
        f"/api/v1/chat/bids/{test_sponsor_bid.id}/messages",
        headers=auth_headers_sponsor,
    )
    # Should succeed (200) with empty messages, not 403/404
    assert r.status_code == 200


async def test_validate_participant_organizer(
    client: AsyncClient,
    test_users_with_sponsor,
    test_sponsor_bid,
    auth_headers_organizer,
):
    """Organizer can access chat for bids on their own event."""
    r = await client.get(
        f"/api/v1/chat/bids/{test_sponsor_bid.id}/messages",
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200


async def test_validate_participant_wrong_user(
    client: AsyncClient,
    test_users_with_sponsor,
    test_sponsor_bid,
    auth_headers_customer,
):
    """Customer (non-participant) gets 403 on bid chat."""
    r = await client.get(
        f"/api/v1/chat/bids/{test_sponsor_bid.id}/messages",
        headers=auth_headers_customer,
    )
    assert r.status_code in (403, 404)


async def test_sponsor_conversations_with_bid(
    client: AsyncClient,
    test_users_with_sponsor,
    test_sponsor_bid,
    auth_headers_sponsor,
):
    """Sponsor with an active bid sees it in conversations list."""
    r = await client.get(
        "/api/v1/chat/conversations",
        headers=auth_headers_sponsor,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    # Should include the bid in conversations
    assert any(c.get("bid_id") == test_sponsor_bid.id for c in data)
