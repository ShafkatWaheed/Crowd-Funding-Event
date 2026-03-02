"""
Push notification service tests: bulk with invalid tokens, no-token graceful no-op.
"""
import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from app.services.push_notification import send_push, send_push_bulk

from tests.conftest import SKIP_DB

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


async def test_send_push_no_tokens(
    db_session,
    test_users,
):
    """send_push with a user that has no device tokens returns 0 (graceful no-op)."""
    with patch(
        "app.services.platform_settings.get_bool",
        new_callable=AsyncMock,
        return_value=True,
    ):
        result = await send_push(
            db_session,
            user_id=test_users["customer"].id,
            title="Test",
            body="No tokens",
        )
    assert result == 0


async def test_send_push_bulk_no_tokens(
    db_session,
    test_users,
):
    """send_push_bulk with users that have no tokens returns 0."""
    with patch(
        "app.services.platform_settings.get_bool",
        new_callable=AsyncMock,
        return_value=True,
    ):
        result = await send_push_bulk(
            db_session,
            user_ids=[test_users["customer"].id, test_users["organizer"].id],
            title="Bulk Test",
            body="No tokens for anyone",
        )
    assert result == 0
