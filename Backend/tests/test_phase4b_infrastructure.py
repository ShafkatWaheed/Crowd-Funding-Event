"""
Phase 4B Infrastructure service-level tests.

Covers:
- push_notification.py       (FCM push delivery)
- email_notifications.py     (high-level notification emails)
- email_templates.py         (HTML template rendering)
- email_service.py           (provider-agnostic email sending)
- admin.py                   (admin dashboard & user/event queries)
- kyc_verification.py        (KYC document management & verification)
- funding/reservations.py    (spot reservation queries)
- upload_validation.py       (file upload validation)
"""
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch, AsyncMock, MagicMock

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.event import Event, EventStatus
from app.models.device_token import DeviceToken
from app.models.funding import Funding, FundingStatus


# ═══════════════════════════════════════════════════════════════════════════
# 1. push_notification.py
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_send_push_disabled(db_session: AsyncSession, test_device_token: DeviceToken):
    """send_push returns 0 when push_notifications_enabled is false."""
    from app.services.push_notification import send_push

    with patch("app.services.platform_settings.get_bool", new_callable=AsyncMock, return_value=False):
        result = await send_push(
            db_session, user_id=test_device_token.user_id, title="Hi", body="Hello"
        )
    assert result == 0


@pytest.mark.asyncio
async def test_send_push_no_tokens(db_session: AsyncSession, test_users: dict[str, User]):
    """send_push returns 0 when the user has no device tokens."""
    from app.services.push_notification import send_push

    with patch("app.services.platform_settings.get_bool", new_callable=AsyncMock, return_value=True):
        result = await send_push(
            db_session, user_id=test_users["admin"].id, title="Hi", body="Hello"
        )
    assert result == 0


@pytest.mark.asyncio
async def test_send_push_fcm_not_available(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """send_push returns 0 when firebase is not initialised."""
    from app.services.push_notification import send_push

    with (
        patch("app.services.platform_settings.get_bool", new_callable=AsyncMock, return_value=True),
        patch("app.services.push_notification._send_to_tokens", new_callable=AsyncMock, return_value=0) as mock_send,
    ):
        result = await send_push(
            db_session, user_id=test_device_token.user_id, title="Hi", body="Hello"
        )
    mock_send.assert_awaited_once()
    assert result == 0


@pytest.mark.asyncio
async def test_send_push_bulk_disabled(db_session: AsyncSession, test_device_token: DeviceToken):
    """send_push_bulk returns 0 when push is disabled."""
    from app.services.push_notification import send_push_bulk

    with patch("app.services.platform_settings.get_bool", new_callable=AsyncMock, return_value=False):
        result = await send_push_bulk(
            db_session,
            user_ids=[test_device_token.user_id],
            title="Hi",
            body="Hello",
        )
    assert result == 0


@pytest.mark.asyncio
async def test_send_push_bulk_no_tokens(db_session: AsyncSession, test_users: dict[str, User]):
    """send_push_bulk returns 0 when no matching device tokens exist."""
    from app.services.push_notification import send_push_bulk

    with patch("app.services.platform_settings.get_bool", new_callable=AsyncMock, return_value=True):
        result = await send_push_bulk(
            db_session,
            user_ids=[test_users["admin"].id, test_users["organizer"].id],
            title="Hi",
            body="Hello",
        )
    assert result == 0


@pytest.mark.asyncio
async def test_send_push_bulk_deduplicates_user_ids(
    db_session: AsyncSession, test_device_token: DeviceToken
):
    """send_push_bulk deduplicates user_ids before querying."""
    from app.services.push_notification import send_push_bulk

    uid = test_device_token.user_id
    with (
        patch("app.services.platform_settings.get_bool", new_callable=AsyncMock, return_value=True),
        patch("app.services.push_notification._send_to_tokens", new_callable=AsyncMock, return_value=1) as mock_send,
    ):
        result = await send_push_bulk(
            db_session, user_ids=[uid, uid, uid], title="Hi", body="Hello"
        )
    assert result == 1
    mock_send.assert_awaited_once()


# ═══════════════════════════════════════════════════════════════════════════
# 2. email_notifications.py
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_format_date_none():
    """_format_date returns None for None input."""
    from app.services.email_notifications import _format_date

    assert _format_date(None) is None


@pytest.mark.asyncio
async def test_format_date_aware():
    """_format_date returns a formatted string for an aware datetime."""
    from app.services.email_notifications import _format_date

    dt = datetime(2025, 6, 15, 14, 30, tzinfo=timezone.utc)
    result = _format_date(dt)
    assert "Jun 15, 2025" in result
    assert "UTC" in result


@pytest.mark.asyncio
async def test_format_date_naive():
    """_format_date adds UTC to a naive datetime."""
    from app.services.email_notifications import _format_date

    dt = datetime(2025, 1, 1, 0, 0)
    result = _format_date(dt)
    assert result is not None
    assert "UTC" in result


@pytest.mark.asyncio
async def test_notify_ticket_purchased():
    """notify_ticket_purchased calls send_email with correct subject."""
    from app.services.email_notifications import notify_ticket_purchased

    with patch("app.services.email_notifications.send_email", new_callable=AsyncMock, return_value=True) as mock_send:
        await notify_ticket_purchased(
            buyer_email="buyer@test.com",
            buyer_name="Buyer",
            event_title="Test Event",
            tier_name="VIP",
            ticket_code="TKT-123",
            receipt_number="REC-123",
            amount_cents=5000,
            quantity=2,
        )
    mock_send.assert_awaited_once()
    call_args = mock_send.call_args
    assert "Ticket Confirmed" in call_args[0][2]  # subject


@pytest.mark.asyncio
async def test_notify_unpledge_refund_zero_amount():
    """notify_unpledge_refund skips sending when refunded_cents is 0."""
    from app.services.email_notifications import notify_unpledge_refund

    with patch("app.services.email_notifications.send_email", new_callable=AsyncMock) as mock_send:
        await notify_unpledge_refund(
            user_email="user@test.com",
            user_name="User",
            event_title="Test Event",
            refunded_cents=0,
        )
    mock_send.assert_not_awaited()


@pytest.mark.asyncio
async def test_notify_unpledge_refund_positive_amount():
    """notify_unpledge_refund sends email when refunded_cents > 0."""
    from app.services.email_notifications import notify_unpledge_refund

    with patch("app.services.email_notifications.send_email", new_callable=AsyncMock, return_value=True) as mock_send:
        await notify_unpledge_refund(
            user_email="user@test.com",
            user_name="User",
            event_title="Test Event",
            refunded_cents=1500,
            pledges_count=2,
        )
    mock_send.assert_awaited_once()
    assert "Pledge Refunded" in mock_send.call_args[0][2]


@pytest.mark.asyncio
async def test_notify_unregister_refund_zero():
    """notify_unregister_refund skips when refunded_cents <= 0."""
    from app.services.email_notifications import notify_unregister_refund

    with patch("app.services.email_notifications.send_email", new_callable=AsyncMock) as mock_send:
        await notify_unregister_refund(
            user_email="u@t.com", user_name="U", event_title="E", refunded_cents=0
        )
    mock_send.assert_not_awaited()


@pytest.mark.asyncio
async def test_notify_sponsor_bid_approved():
    """notify_sponsor_bid_approved calls send_email."""
    from app.services.email_notifications import notify_sponsor_bid_approved

    with patch("app.services.email_notifications.send_email", new_callable=AsyncMock, return_value=True) as mock_send:
        await notify_sponsor_bid_approved(
            sponsor_email="s@t.com",
            sponsor_name="Sponsor",
            event_title="Event",
            category_name="Gold",
            bid_amount_cents=50000,
        )
    mock_send.assert_awaited_once()
    assert "Bid Accepted" in mock_send.call_args[0][2]


@pytest.mark.asyncio
async def test_notify_sponsor_bid_rejected():
    """notify_sponsor_bid_rejected calls send_email."""
    from app.services.email_notifications import notify_sponsor_bid_rejected

    with patch("app.services.email_notifications.send_email", new_callable=AsyncMock, return_value=True) as mock_send:
        await notify_sponsor_bid_rejected(
            sponsor_email="s@t.com",
            sponsor_name="Sponsor",
            event_title="Event",
            category_name="Gold",
            bid_amount_cents=50000,
        )
    mock_send.assert_awaited_once()
    assert "Bid Not Accepted" in mock_send.call_args[0][2]


# ═══════════════════════════════════════════════════════════════════════════
# 3. email_templates.py
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_event_cancelled_template_contains_title():
    """event_cancelled_template renders HTML with event title and reason."""
    from app.services.email_templates import event_cancelled_template

    html = await event_cancelled_template("My Big Event", "Weather issues")
    assert "My Big Event" in html
    assert "Weather issues" in html
    assert "<!DOCTYPE html>" in html


@pytest.mark.asyncio
async def test_ticket_purchased_template_free():
    """ticket_purchased_template renders 'FREE' for zero-cent tickets."""
    from app.services.email_templates import ticket_purchased_template

    html = await ticket_purchased_template(
        event_title="Free Fest",
        tier_name="General",
        ticket_code="TKT-001",
        receipt_number="REC-001",
        amount_cents=0,
        quantity=1,
    )
    assert "FREE" in html
    assert "Free Fest" in html


@pytest.mark.asyncio
async def test_ticket_purchased_template_paid():
    """ticket_purchased_template renders dollar amount for paid tickets."""
    from app.services.email_templates import ticket_purchased_template

    html = await ticket_purchased_template(
        event_title="Concert",
        tier_name="VIP",
        ticket_code="TKT-002",
        receipt_number="REC-002",
        amount_cents=5000,
        quantity=2,
    )
    assert "$50.00" in html
    assert "Concert" in html
    assert "VIP" in html


@pytest.mark.asyncio
async def test_unpledge_refund_template():
    """unpledge_refund_template renders refund amount."""
    from app.services.email_templates import unpledge_refund_template

    html = await unpledge_refund_template("Charity Gala", refunded_cents=2500)
    assert "$25.00" in html
    assert "Charity Gala" in html


@pytest.mark.asyncio
async def test_cancellation_refund_template():
    """cancellation_refund_template renders event title, reason, and refund."""
    from app.services.email_templates import cancellation_refund_template

    html = await cancellation_refund_template(
        event_title="Big Event",
        reason="Venue closed",
        refunded_cents=10000,
    )
    assert "Big Event" in html
    assert "Venue closed" in html
    assert "$100.00" in html


@pytest.mark.asyncio
async def test_sponsor_bid_approved_template():
    """sponsor_bid_approved_template renders category and bid amount."""
    from app.services.email_templates import sponsor_bid_approved_template

    html = await sponsor_bid_approved_template(
        event_title="Tech Conf",
        category_name="Platinum",
        bid_amount_cents=100000,
    )
    assert "Tech Conf" in html
    assert "Platinum" in html
    assert "$1,000.00" in html


@pytest.mark.asyncio
async def test_cents_to_dollars():
    """_cents_to_dollars helper formats correctly."""
    from app.services.email_templates import _cents_to_dollars

    assert _cents_to_dollars(0) == "$0.00"
    assert _cents_to_dollars(100) == "$1.00"
    assert _cents_to_dollars(99999) == "$999.99"
    assert _cents_to_dollars(123456) == "$1,234.56"


# ═══════════════════════════════════════════════════════════════════════════
# 4. email_service.py
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_console_backend_send():
    """ConsoleBackend.send returns True."""
    from app.services.email_service import ConsoleBackend

    backend = ConsoleBackend()
    result = await backend.send("test@test.com", "Test", "Subject", "<p>body</p>")
    assert result is True


@pytest.mark.asyncio
async def test_console_backend_send_bulk():
    """ConsoleBackend.send_bulk returns count of recipients."""
    from app.services.email_service import ConsoleBackend

    backend = ConsoleBackend()
    recipients = [
        {"email": "a@t.com", "name": "A"},
        {"email": "b@t.com", "name": "B"},
        {"email": "c@t.com", "name": "C"},
    ]
    result = await backend.send_bulk(recipients, "Subject", "<p>body</p>")
    assert result == 3


@pytest.mark.asyncio
async def test_get_email_backend_console():
    """get_email_backend returns ConsoleBackend for 'console'."""
    from app.services.email_service import get_email_backend, ConsoleBackend, _backend_cache

    _backend_cache.pop("console", None)
    backend = get_email_backend(provider_override="console")
    assert isinstance(backend, ConsoleBackend)


@pytest.mark.asyncio
async def test_get_email_backend_unknown_raises():
    """get_email_backend raises ValueError for unknown provider."""
    from app.services.email_service import get_email_backend, _backend_cache

    _backend_cache.pop("xyz", None)
    with pytest.raises(ValueError, match="Unknown EMAIL_PROVIDER"):
        get_email_backend(provider_override="xyz")


@pytest.mark.asyncio
async def test_send_email_disabled():
    """send_email returns False when EMAIL_ENABLED is False."""
    from app.services.email_service import send_email

    with patch("app.services.email_service.settings") as mock_settings:
        mock_settings.EMAIL_ENABLED = False
        result = await send_email("t@t.com", "T", "Subj", "<p>hi</p>")
    assert result is False


@pytest.mark.asyncio
async def test_send_email_bulk_disabled():
    """send_email_bulk returns 0 when EMAIL_ENABLED is False."""
    from app.services.email_service import send_email_bulk

    with patch("app.services.email_service.settings") as mock_settings:
        mock_settings.EMAIL_ENABLED = False
        result = await send_email_bulk(
            [{"email": "a@t.com"}], "Subj", "<p>hi</p>"
        )
    assert result == 0


@pytest.mark.asyncio
async def test_send_email_bulk_empty_recipients():
    """send_email_bulk returns 0 for empty recipients."""
    from app.services.email_service import send_email_bulk

    with patch("app.services.email_service.settings") as mock_settings:
        mock_settings.EMAIL_ENABLED = True
        result = await send_email_bulk([], "Subj", "<p>hi</p>")
    assert result == 0


# ═══════════════════════════════════════════════════════════════════════════
# 5. admin.py
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_list_users_returns_all(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """list_users returns all seeded users."""
    from app.services.admin import list_users

    items, total = await list_users(db_session)
    assert total >= 4
    assert len(items) >= 4


@pytest.mark.asyncio
async def test_list_users_search(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """list_users filters by search term."""
    from app.services.admin import list_users

    items, total = await list_users(db_session, search="admin")
    assert total >= 1
    assert all("admin" in u.display_name.lower() or "admin" in u.email.lower() for u in items)


@pytest.mark.asyncio
async def test_list_users_pagination(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """list_users respects offset and limit."""
    from app.services.admin import list_users

    items, total = await list_users(db_session, offset=0, limit=2)
    assert len(items) == 2
    assert total >= 4


@pytest.mark.asyncio
async def test_list_events_for_admin(
    db_session: AsyncSession, test_event_approved: Event
):
    """list_events_for_admin returns approved events."""
    from app.services.admin import list_events_for_admin

    items, total = await list_events_for_admin(db_session, status="approved")
    assert total >= 1
    assert all(e.status == EventStatus.approved for e in items)


@pytest.mark.asyncio
async def test_list_events_for_admin_search(
    db_session: AsyncSession, test_event_approved: Event
):
    """list_events_for_admin filters by title search."""
    from app.services.admin import list_events_for_admin

    items, total = await list_events_for_admin(db_session, search="Test Event")
    assert total >= 1


@pytest.mark.asyncio
async def test_compute_event_warnings_short_description(
    test_event_approved: Event,
):
    """compute_event_warnings flags short descriptions."""
    from app.services.admin import compute_event_warnings

    test_event_approved.description = "Hi"
    warnings = compute_event_warnings(test_event_approved)
    assert any("Description" in w for w in warnings)


@pytest.mark.asyncio
async def test_compute_event_warnings_zero_capacity(
    test_event_approved: Event,
):
    """compute_event_warnings flags zero capacity."""
    from app.services.admin import compute_event_warnings

    test_event_approved.max_capacity = 0
    warnings = compute_event_warnings(test_event_approved)
    assert any("Capacity is 0" in w for w in warnings)


@pytest.mark.asyncio
async def test_compute_event_warnings_no_genre(
    test_event_approved: Event,
):
    """compute_event_warnings flags missing genre."""
    from app.services.admin import compute_event_warnings

    test_event_approved.genre = None
    warnings = compute_event_warnings(test_event_approved)
    assert any("genre" in w.lower() for w in warnings)


@pytest.mark.asyncio
async def test_get_stats(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """get_stats returns expected keys with correct types."""
    from app.services.admin import get_stats

    stats = await get_stats(db_session)
    assert "events_total" in stats
    assert "users_total" in stats
    assert "total_ticket_commission_cents" in stats
    assert isinstance(stats["events_total"], int)
    assert stats["events_total"] >= 1
    assert stats["users_total"] >= 4


# ═══════════════════════════════════════════════════════════════════════════
# 6. kyc_verification.py
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_kyc_list_documents_empty(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """list_documents returns empty list for user with no docs."""
    from app.services.kyc_verification import list_documents

    docs = await list_documents(db_session, test_users["customer"].id)
    assert docs == []


@pytest.mark.asyncio
async def test_kyc_upload_document(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """upload_document creates a new KycDocument."""
    from app.services.kyc_verification import upload_document, list_documents
    from app.models.kyc_document import KycDocumentType, KycDocumentStatus

    doc = await upload_document(
        db_session,
        user_id=test_users["customer"].id,
        document_type=KycDocumentType.id_front,
        file_path="/tmp/fake_id.jpg",
        mime_type="image/jpeg",
        original_filename="id_front.jpg",
    )
    assert doc.id is not None
    assert doc.document_type == KycDocumentType.id_front
    assert doc.status == KycDocumentStatus.pending

    docs = await list_documents(db_session, test_users["customer"].id)
    assert len(docs) == 1


@pytest.mark.asyncio
async def test_kyc_upload_document_replaces_existing(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """upload_document replaces an existing pending doc of the same type."""
    from app.services.kyc_verification import upload_document, list_documents
    from app.models.kyc_document import KycDocumentType

    with patch("os.path.exists", return_value=False):
        doc1 = await upload_document(
            db_session,
            user_id=test_users["customer"].id,
            document_type=KycDocumentType.id_front,
            file_path="/tmp/id1.jpg",
            mime_type="image/jpeg",
            original_filename="id1.jpg",
        )
        doc2 = await upload_document(
            db_session,
            user_id=test_users["customer"].id,
            document_type=KycDocumentType.id_front,
            file_path="/tmp/id2.jpg",
            mime_type="image/jpeg",
            original_filename="id2.jpg",
        )

    # Should reuse the same row
    assert doc1.id == doc2.id
    assert doc2.file_path == "/tmp/id2.jpg"


@pytest.mark.asyncio
async def test_kyc_delete_document(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """delete_document removes a pending document."""
    from app.services.kyc_verification import upload_document, delete_document, list_documents
    from app.models.kyc_document import KycDocumentType

    doc = await upload_document(
        db_session,
        user_id=test_users["customer"].id,
        document_type=KycDocumentType.proof_of_address,
        file_path="/tmp/addr.pdf",
        mime_type="application/pdf",
        original_filename="addr.pdf",
    )
    with patch("os.path.exists", return_value=False):
        await delete_document(db_session, test_users["customer"].id, doc.id)

    docs = await list_documents(db_session, test_users["customer"].id)
    assert all(d.id != doc.id for d in docs)


@pytest.mark.asyncio
async def test_kyc_delete_nonexistent_raises(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """delete_document raises ValueError for non-existent document."""
    from app.services.kyc_verification import delete_document

    with pytest.raises(ValueError, match="Document not found"):
        await delete_document(db_session, test_users["customer"].id, 99999)


@pytest.mark.asyncio
async def test_kyc_submit_for_review_missing_docs(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """submit_for_review raises ValueError when required docs are missing."""
    from app.services.kyc_verification import submit_for_review

    with pytest.raises(ValueError, match="Missing required documents"):
        await submit_for_review(db_session, test_users["customer"].id)


@pytest.mark.asyncio
async def test_kyc_submit_for_review_user_not_found(db_session: AsyncSession):
    """submit_for_review raises ValueError for a non-existent user."""
    from app.services.kyc_verification import submit_for_review

    with pytest.raises(ValueError, match="User not found"):
        await submit_for_review(db_session, 99999)


@pytest.mark.asyncio
async def test_kyc_list_pending_users(
    db_session: AsyncSession, test_users: dict[str, User]
):
    """list_pending_users returns users with kyc_status='submitted'."""
    from app.services.kyc_verification import list_pending_users

    # No users submitted yet
    pending = await list_pending_users(db_session)
    assert len(pending) == 0

    # Set one user to submitted
    user = test_users["customer"]
    user.kyc_status = "submitted"
    await db_session.flush()

    pending = await list_pending_users(db_session)
    assert len(pending) == 1
    assert pending[0].id == user.id


# ═══════════════════════════════════════════════════════════════════════════
# 7. funding/reservations.py
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_get_user_reserved_spots_none(
    db_session: AsyncSession, test_event_approved: Event, test_users: dict[str, User]
):
    """get_user_reserved_spots returns 0 when no pledges exist."""
    from app.services.funding.reservations import get_user_reserved_spots

    spots = await get_user_reserved_spots(
        db_session, test_event_approved.id, test_users["customer"].id
    )
    assert spots == 0


@pytest.mark.asyncio
async def test_get_user_reserved_spots_with_pledge(
    db_session: AsyncSession, test_pledge: Funding, test_users: dict[str, User]
):
    """get_user_reserved_spots returns reserved spots from the pledge."""
    from app.services.funding.reservations import get_user_reserved_spots

    test_pledge.reserved_spots = 3
    await db_session.flush()

    spots = await get_user_reserved_spots(
        db_session, test_pledge.event_id, test_users["customer"].id
    )
    assert spots == 3


@pytest.mark.asyncio
async def test_get_total_reserved_spots(
    db_session: AsyncSession, test_pledge: Funding
):
    """get_total_reserved_spots sums reserved spots across all pledges."""
    from app.services.funding.reservations import get_total_reserved_spots

    test_pledge.reserved_spots = 5
    await db_session.flush()

    total = await get_total_reserved_spots(db_session, test_pledge.event_id)
    assert total == 5


@pytest.mark.asyncio
async def test_get_total_reserved_spots_for_events_empty(db_session: AsyncSession):
    """get_total_reserved_spots_for_events returns empty dict for empty list."""
    from app.services.funding.reservations import get_total_reserved_spots_for_events

    result = await get_total_reserved_spots_for_events(db_session, event_ids=[])
    assert result == {}


@pytest.mark.asyncio
async def test_get_total_reserved_spots_for_events(
    db_session: AsyncSession, test_pledge: Funding
):
    """get_total_reserved_spots_for_events returns correct mapping."""
    from app.services.funding.reservations import get_total_reserved_spots_for_events

    test_pledge.reserved_spots = 2
    await db_session.flush()

    result = await get_total_reserved_spots_for_events(
        db_session, event_ids=[test_pledge.event_id]
    )
    assert result[test_pledge.event_id] == 2


@pytest.mark.asyncio
async def test_consume_one_reserved_spot(
    db_session: AsyncSession, test_pledge: Funding, test_users: dict[str, User]
):
    """consume_one_reserved_spot decrements reserved_spots by 1."""
    from app.services.funding.reservations import consume_one_reserved_spot

    test_pledge.reserved_spots = 2
    await db_session.flush()

    await consume_one_reserved_spot(
        db_session, test_pledge.event_id, test_users["customer"].id
    )
    await db_session.refresh(test_pledge)
    assert test_pledge.reserved_spots == 1


@pytest.mark.asyncio
async def test_consume_one_reserved_spot_none_available(
    db_session: AsyncSession, test_event_approved: Event, test_users: dict[str, User]
):
    """consume_one_reserved_spot raises ConflictError when no spots available."""
    from app.services.funding.reservations import consume_one_reserved_spot
    from app.core.exceptions import ConflictError

    with pytest.raises(ConflictError, match="No reserved spots"):
        await consume_one_reserved_spot(
            db_session, test_event_approved.id, test_users["customer"].id
        )


# ═══════════════════════════════════════════════════════════════════════════
# 8. upload_validation.py
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_validate_upload_image_valid(db_session: AsyncSession):
    """validate_upload accepts a valid image file."""
    from app.services.upload_validation import validate_upload

    fake_file = AsyncMock()
    fake_file.content_type = "image/jpeg"
    fake_file.read = AsyncMock(return_value=b"\xff\xd8" + b"\x00" * 100)

    with (
        patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10),
        patch("app.services.platform_settings.get_str", new_callable=AsyncMock, return_value="image/jpeg,image/png"),
    ):
        contents = await validate_upload(db_session, fake_file, category="image")
    assert len(contents) == 102


@pytest.mark.asyncio
async def test_validate_upload_unsupported_type(db_session: AsyncSession):
    """validate_upload raises HTTPException for unsupported file type."""
    from app.services.upload_validation import validate_upload
    from fastapi import HTTPException

    fake_file = AsyncMock()
    fake_file.content_type = "application/zip"
    fake_file.read = AsyncMock(return_value=b"\x00" * 100)

    with (
        patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10),
        patch("app.services.platform_settings.get_str", new_callable=AsyncMock, return_value="image/jpeg,image/png"),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await validate_upload(db_session, fake_file, category="image")
    assert exc_info.value.status_code == 400
    assert "Unsupported file type" in exc_info.value.detail


@pytest.mark.asyncio
async def test_validate_upload_too_large(db_session: AsyncSession):
    """validate_upload raises HTTPException for oversized files."""
    from app.services.upload_validation import validate_upload
    from fastapi import HTTPException

    # Create a file larger than 1 MB
    fake_file = AsyncMock()
    fake_file.content_type = "image/jpeg"
    fake_file.read = AsyncMock(return_value=b"\x00" * (2 * 1024 * 1024))  # 2 MB

    with (
        patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=1),  # 1 MB limit
        patch("app.services.platform_settings.get_str", new_callable=AsyncMock, return_value="image/jpeg"),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await validate_upload(db_session, fake_file, category="image")
    assert exc_info.value.status_code == 400
    assert "File too large" in exc_info.value.detail


@pytest.mark.asyncio
async def test_validate_upload_document_category(db_session: AsyncSession):
    """validate_upload uses document settings for category='document'."""
    from app.services.upload_validation import validate_upload

    fake_file = AsyncMock()
    fake_file.content_type = "application/pdf"
    fake_file.read = AsyncMock(return_value=b"%PDF" + b"\x00" * 50)

    async def mock_get_int(db, key):
        if key == "upload_max_document_size_mb":
            return 25
        return 10

    async def mock_get_str(db, key):
        if key == "upload_allowed_document_types":
            return "application/pdf,image/jpeg"
        return "image/jpeg,image/png"

    with (
        patch("app.services.platform_settings.get_int", side_effect=mock_get_int),
        patch("app.services.platform_settings.get_str", side_effect=mock_get_str),
    ):
        contents = await validate_upload(db_session, fake_file, category="document")
    assert len(contents) == 54


@pytest.mark.asyncio
async def test_validate_upload_empty_allowed_types(db_session: AsyncSession):
    """validate_upload allows any type when allowed_types is empty."""
    from app.services.upload_validation import validate_upload

    fake_file = AsyncMock()
    fake_file.content_type = "application/octet-stream"
    fake_file.read = AsyncMock(return_value=b"\x00" * 10)

    with (
        patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=10),
        patch("app.services.platform_settings.get_str", new_callable=AsyncMock, return_value=""),
    ):
        contents = await validate_upload(db_session, fake_file, category="image")
    assert len(contents) == 10
