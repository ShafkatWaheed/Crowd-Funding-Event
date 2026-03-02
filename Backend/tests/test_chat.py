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
