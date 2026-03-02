"""
Service-level tests for chat_service.py — Phase 3.

DB-touching functions (real db_session):
  validate_participant, update_pg_metadata, clear_unread, get_conversations

Redis-touching functions (mocked Redis):
  send_message, get_messages, mark_read, get_read_cursor

File-system function:
  purge_old_archives
"""
import pytest
from datetime import datetime, timezone
from unittest.mock import patch, AsyncMock, MagicMock

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.sponsor import SponsorBid, BidStatus, SponsorshipCategory
from app.models.event import Event, EventStatus
from app.models.user import User, UserRole

from app.services.chat_service import (
    validate_participant,
    update_pg_metadata,
    clear_unread,
    get_conversations,
    send_message,
    get_messages,
    mark_read,
    get_read_cursor,
    purge_old_archives,
    ARCHIVE_DIR,
)

from tests.conftest import SKIP_DB

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

async def _make_category(db, event, name="Gold", min_bid=5000, total_spots=3):
    cat = SponsorshipCategory(
        event_id=event.id, name=name, total_spots=total_spots,
        min_bid_cents=min_bid,
    )
    db.add(cat)
    await db.flush()
    return cat


async def _make_bid(db, category, sponsor_user, amount_cents=10000, status=BidStatus.pending):
    bid = SponsorBid(
        category_id=category.id,
        sponsor_user_id=sponsor_user.id,
        amount_cents=amount_cents,
        proposal_text="Test bid",
        status=status,
    )
    db.add(bid)
    await db.flush()
    return bid


# ===========================================================================
# validate_participant
# ===========================================================================


async def test_validate_participant_sponsor_is_participant(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Sponsor who placed the bid is recognized as a participant with is_sponsor=True."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)

    ctx = await validate_participant(db_session, bid.id, sponsor.id)
    assert ctx["is_sponsor"] is True
    assert ctx["sponsor_user_id"] == sponsor.id
    assert ctx["bid"] is bid


async def test_validate_participant_organizer_is_participant(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Organizer of the event linked to the bid is recognized with is_sponsor=False."""
    sponsor = test_users_with_sponsor["sponsor"]
    organizer = test_users_with_sponsor["organizer"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)

    ctx = await validate_participant(db_session, bid.id, organizer.id)
    assert ctx["is_sponsor"] is False
    assert ctx["organizer_user_id"] == organizer.id


async def test_validate_participant_unrelated_user_raises(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """A user who is neither sponsor nor organizer gets ValueError."""
    sponsor = test_users_with_sponsor["sponsor"]
    customer = test_users_with_sponsor["customer"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)

    with pytest.raises(ValueError, match="Not a participant"):
        await validate_participant(db_session, bid.id, customer.id)


async def test_validate_participant_bid_not_found(
    db_session, test_users_with_sponsor,
):
    """Non-existent bid ID raises ValueError."""
    sponsor = test_users_with_sponsor["sponsor"]
    with pytest.raises(ValueError, match="Bid not found"):
        await validate_participant(db_session, 999999, sponsor.id)


async def test_validate_participant_writable_when_open(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Bid pending + event approved -> is_writable=True."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor, status=BidStatus.pending)

    ctx = await validate_participant(db_session, bid.id, sponsor.id)
    assert ctx["is_writable"] is True


async def test_validate_participant_not_writable_when_bid_withdrawn(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Bid withdrawn -> is_writable=False even if event is approved."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor, status=BidStatus.withdrawn)

    ctx = await validate_participant(db_session, bid.id, sponsor.id)
    assert ctx["is_writable"] is False


async def test_validate_participant_not_writable_when_event_completed(
    db_session, test_users_with_sponsor,
):
    """Bid pending but event completed -> is_writable=False."""
    from app.models.venue import Venue
    from datetime import timedelta
    sponsor = test_users_with_sponsor["sponsor"]
    organizer = test_users_with_sponsor["organizer"]

    # Create a completed event
    venue = Venue(
        organizer_id=organizer.id, name="Hall B", address="456 Ave",
        city="Toronto", province="ON", lat=43.65, lng=-79.38, max_capacity=50,
    )
    db_session.add(venue)
    await db_session.flush()

    start = datetime.now(timezone.utc) - timedelta(days=2)
    end = start + timedelta(hours=2)
    event = Event(
        organizer_id=organizer.id, venue_id=venue.id, title="Done Event",
        description="Completed", start_time=start, end_time=end,
        funding_goal_cents=10000, funding_end_at=start - timedelta(days=10),
        min_pledge_cents=500, status=EventStatus.completed, max_capacity=50,
        lat=venue.lat, lng=venue.lng,
    )
    db_session.add(event)
    await db_session.flush()

    cat = await _make_category(db_session, event)
    bid = await _make_bid(db_session, cat, sponsor, status=BidStatus.pending)

    ctx = await validate_participant(db_session, bid.id, sponsor.id)
    assert ctx["is_writable"] is False


# ===========================================================================
# update_pg_metadata
# ===========================================================================


async def test_update_pg_metadata_sponsor_sends(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """When sponsor sends, unread_count_organizer increments."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)
    assert bid.unread_count_organizer == 0

    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=True)
    await db_session.refresh(bid)
    assert bid.unread_count_organizer == 1
    assert bid.last_message_at is not None


async def test_update_pg_metadata_organizer_sends(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """When organizer sends, unread_count_sponsor increments."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)
    assert bid.unread_count_sponsor == 0

    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=False)
    await db_session.refresh(bid)
    assert bid.unread_count_sponsor == 1


async def test_update_pg_metadata_increments_multiple(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Multiple sends stack the unread count."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)

    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=True)
    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=True)
    await db_session.refresh(bid)
    assert bid.unread_count_organizer == 2
    # sponsor count should remain 0
    assert bid.unread_count_sponsor == 0


async def test_update_pg_metadata_bid_not_found(db_session):
    """Non-existent bid ID does not raise — returns silently."""
    # Should not raise
    await update_pg_metadata(db_session, 999999, sender_is_sponsor=True)


# ===========================================================================
# clear_unread
# ===========================================================================


async def test_clear_unread_sponsor(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Clearing unread for sponsor sets unread_count_sponsor to 0."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)

    # Simulate organizer sending two messages
    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=False)
    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=False)
    await db_session.refresh(bid)
    assert bid.unread_count_sponsor == 2

    await clear_unread(db_session, bid.id, user_is_sponsor=True)
    await db_session.refresh(bid)
    assert bid.unread_count_sponsor == 0


async def test_clear_unread_organizer(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Clearing unread for organizer sets unread_count_organizer to 0."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)

    # Simulate sponsor sending
    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=True)
    await db_session.refresh(bid)
    assert bid.unread_count_organizer == 1

    await clear_unread(db_session, bid.id, user_is_sponsor=False)
    await db_session.refresh(bid)
    assert bid.unread_count_organizer == 0


# ===========================================================================
# get_conversations
# ===========================================================================


async def test_get_conversations_sponsor_sees_all_bids(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Sponsor sees all their bids (even ones without messages)."""
    sponsor = test_users_with_sponsor["sponsor"]
    await _make_bid(db_session, test_sponsorship_category, sponsor)

    convos = await get_conversations(db_session, sponsor.id)
    assert len(convos) == 1
    assert convos[0]["sponsor_user_id"] == sponsor.id
    assert convos[0]["event_title"] == "Test Event"


async def test_get_conversations_organizer_sees_only_with_messages(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Organizer only sees bids where last_message_at is set."""
    sponsor = test_users_with_sponsor["sponsor"]
    organizer = test_users_with_sponsor["organizer"]

    # Bid without any message
    bid_no_msg = await _make_bid(db_session, test_sponsorship_category, sponsor)

    # Organizer should see nothing yet (no last_message_at)
    convos = await get_conversations(db_session, organizer.id)
    assert len(convos) == 0

    # Set last_message_at to simulate a chat message
    bid_no_msg.last_message_at = datetime.now(timezone.utc)
    await db_session.flush()

    convos = await get_conversations(db_session, organizer.id)
    assert len(convos) == 1
    assert convos[0]["bid_id"] == bid_no_msg.id


async def test_get_conversations_empty_results(
    db_session, test_users_with_sponsor,
):
    """User with no bids at all gets empty list."""
    customer = test_users_with_sponsor["customer"]
    convos = await get_conversations(db_session, customer.id)
    assert convos == []


async def test_get_conversations_unread_count_for_sponsor(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Conversation dict includes correct unread_count for the calling user."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor)

    # Organizer sends two messages -> sponsor has 2 unread
    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=False)
    await update_pg_metadata(db_session, bid.id, sender_is_sponsor=False)

    convos = await get_conversations(db_session, sponsor.id)
    assert len(convos) == 1
    assert convos[0]["unread_count"] == 2


async def test_get_conversations_is_writable_field(
    db_session, test_event_approved, test_users_with_sponsor, test_sponsorship_category,
):
    """Conversation dict includes is_writable reflecting bid+event statuses."""
    sponsor = test_users_with_sponsor["sponsor"]
    bid = await _make_bid(db_session, test_sponsorship_category, sponsor, status=BidStatus.pending)

    convos = await get_conversations(db_session, sponsor.id)
    assert len(convos) == 1
    # pending bid + approved event => writable
    assert convos[0]["is_writable"] is True


# ===========================================================================
# Redis-touching functions (mocked)
# ===========================================================================


async def test_send_message_mocked_redis():
    """send_message appends to Redis stream and publishes, returns message dict.

    send_message does lazy imports of platform_settings and async_session_maker
    inside the function body. We mock both at the point of use.
    """
    from contextlib import asynccontextmanager

    mock_redis = AsyncMock()
    mock_redis.xadd = AsyncMock(return_value="1700000000000-0")
    mock_redis.publish = AsyncMock()
    mock_redis.aclose = AsyncMock()

    # Mock platform_settings.get_int (imported inside send_message as settings_svc)
    mock_get_int = AsyncMock(return_value=1000)

    # Mock async_session_maker to yield a mock session
    mock_session = AsyncMock()

    @asynccontextmanager
    async def mock_cm():
        yield mock_session

    mock_session_maker = MagicMock(side_effect=lambda: mock_cm())

    with patch("app.services.chat_service._get_redis", return_value=mock_redis), \
         patch("app.services.platform_settings.get_int", mock_get_int), \
         patch("app.db.base.async_session_maker", mock_session_maker):
        result = await send_message(42, 7, "Hello!", "cli-abc", "text")

    assert result["id"] == "1700000000000-0"
    assert result["bid_id"] == 42
    assert result["sender_id"] == 7
    assert result["body"] == "Hello!"
    mock_redis.xadd.assert_called_once()
    mock_redis.publish.assert_called_once()


async def test_get_messages_mocked_redis():
    """get_messages reads from Redis stream and returns formatted list."""
    mock_redis = AsyncMock()
    mock_redis.xrevrange = AsyncMock(return_value=[
        ("1700000000000-0", {"sender_id": "7", "body": "Hello", "client_id": "c1", "type": "text", "ts": "1700000000000"}),
        ("1699999999000-0", {"sender_id": "8", "body": "Hi there", "client_id": "c2", "type": "text", "ts": "1699999999000"}),
    ])
    mock_redis.aclose = AsyncMock()

    with patch("app.services.chat_service._get_redis", return_value=mock_redis):
        messages = await get_messages(bid_id=42)

    assert len(messages) == 2
    assert messages[0]["id"] == "1700000000000-0"
    assert messages[0]["sender_id"] == 7
    assert messages[0]["body"] == "Hello"
    assert messages[1]["body"] == "Hi there"


async def test_get_messages_with_before_id_filter():
    """get_messages with before_id skips that exact message ID."""
    mock_redis = AsyncMock()
    mock_redis.xrevrange = AsyncMock(return_value=[
        ("1700000000000-0", {"sender_id": "7", "body": "Cursor msg", "client_id": "c1", "type": "text", "ts": "1700000000000"}),
        ("1699999999000-0", {"sender_id": "8", "body": "Older msg", "client_id": "c2", "type": "text", "ts": "1699999999000"}),
    ])
    mock_redis.aclose = AsyncMock()

    with patch("app.services.chat_service._get_redis", return_value=mock_redis):
        messages = await get_messages(bid_id=42, before_id="1700000000000-0")

    # The cursor message itself should be excluded
    assert len(messages) == 1
    assert messages[0]["id"] == "1699999999000-0"


async def test_mark_read_mocked_redis():
    """mark_read sets the cursor in Redis hash."""
    mock_redis = AsyncMock()
    mock_redis.hset = AsyncMock()
    mock_redis.aclose = AsyncMock()

    with patch("app.services.chat_service._get_redis", return_value=mock_redis):
        await mark_read(bid_id=42, user_id=7, message_id="1700000000000-0")

    mock_redis.hset.assert_called_once_with("chat:read:42", "7", "1700000000000-0")


async def test_get_read_cursor_mocked_redis():
    """get_read_cursor returns the stored cursor from Redis hash."""
    mock_redis = AsyncMock()
    mock_redis.hget = AsyncMock(return_value="1700000000000-0")
    mock_redis.aclose = AsyncMock()

    with patch("app.services.chat_service._get_redis", return_value=mock_redis):
        cursor = await get_read_cursor(bid_id=42, user_id=7)

    assert cursor == "1700000000000-0"
    mock_redis.hget.assert_called_once_with("chat:read:42", "7")


async def test_get_read_cursor_none_when_not_set():
    """get_read_cursor returns None when user has no cursor."""
    mock_redis = AsyncMock()
    mock_redis.hget = AsyncMock(return_value=None)
    mock_redis.aclose = AsyncMock()

    with patch("app.services.chat_service._get_redis", return_value=mock_redis):
        cursor = await get_read_cursor(bid_id=42, user_id=7)

    assert cursor is None


# ===========================================================================
# purge_old_archives
# ===========================================================================


async def test_purge_old_archives_no_dir():
    """When the archive directory does not exist, returns 0."""
    with patch("app.services.chat_service.ARCHIVE_DIR") as mock_dir:
        mock_dir.exists.return_value = False
        result = await purge_old_archives()
    assert result == 0
