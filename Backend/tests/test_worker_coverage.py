"""
Worker task tests: test individual tasks with mocked DB sessions and Redis.
"""
import pytest
from datetime import datetime, timezone
from unittest.mock import patch, AsyncMock, MagicMock

from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.sponsor import SponsorPayment


# ---------------------------------------------------------------------------
# Helpers: create a mock ctx dict like ARQ provides
# ---------------------------------------------------------------------------

def _mock_ctx():
    return {"redis": MagicMock()}


def _mock_session_maker():
    """Create a properly mocked async_session_maker context manager."""
    mock_session = AsyncMock()
    mock_sm = MagicMock()
    mock_sm.return_value.__aenter__ = AsyncMock(return_value=mock_session)
    mock_sm.return_value.__aexit__ = AsyncMock(return_value=False)
    return mock_sm, mock_session


# ---------------------------------------------------------------------------
# Email tasks (email_notify is module-level import)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_ticket_purchased_email():
    """send_ticket_purchased_email calls email_notifications."""
    mock_sm, mock_session = _mock_session_maker()
    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.worker.tasks.email_notify") as mock_email:
            mock_email.notify_ticket_purchased = AsyncMock()
            from app.worker.tasks import send_ticket_purchased_email
            await send_ticket_purchased_email(
                _mock_ctx(),
                buyer_email="test@test.com",
                buyer_name="Test",
                event_title="Test Event",
                tier_name="General",
                ticket_code="TKT-001",
                receipt_number="RCP-001",
                amount_cents=2500,
                quantity=1,
                event_date="2026-04-01",
                discount_cents=0,
                commission_cents=250,
            )
            mock_email.notify_ticket_purchased.assert_called_once()


@pytest.mark.asyncio
async def test_send_event_cancelled_email():
    """send_event_cancelled_email calls email_notifications."""
    mock_sm, mock_session = _mock_session_maker()
    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.worker.tasks.email_notify") as mock_email:
            mock_email.notify_event_cancelled = AsyncMock()
            from app.worker.tasks import send_event_cancelled_email
            await send_event_cancelled_email(
                _mock_ctx(),
                event_id=1,
                event_title="Cancelled Event",
                reason="Testing",
                event_date="2026-04-01",
            )
            mock_email.notify_event_cancelled.assert_called_once()


# ---------------------------------------------------------------------------
# Push notification tasks (push_svc imported inside function)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_push_notification_task():
    """send_push_notification enqueues FCM push."""
    mock_sm, mock_session = _mock_session_maker()
    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.services.push_notification.send_push", new_callable=AsyncMock) as mock_push:
            from app.worker.tasks import send_push_notification
            await send_push_notification(
                _mock_ctx(),
                user_id=1,
                title="Test",
                body="Test notification",
                data={"test": True},
            )
            mock_push.assert_called_once()


@pytest.mark.asyncio
async def test_send_push_notification_bulk_task():
    """send_push_notification_bulk enqueues bulk FCM push."""
    mock_sm, mock_session = _mock_session_maker()
    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.services.push_notification.send_push_bulk", new_callable=AsyncMock) as mock_push:
            from app.worker.tasks import send_push_notification_bulk
            await send_push_notification_bulk(
                _mock_ctx(),
                user_ids=[1, 2, 3],
                title="Test",
                body="Bulk notification",
                data={},
            )
            mock_push.assert_called_once()


# ---------------------------------------------------------------------------
# Refund tasks (get_gateway imported inside function)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_process_pledge_refund():
    """process_pledge_refund processes a pledge refund."""
    mock_sm, mock_session = _mock_session_maker()
    mock_funding = MagicMock(spec=Funding)
    mock_funding.id = 1
    mock_funding.amount_cents = 5000
    mock_funding.status = FundingStatus.refund_processing
    mock_funding.gateway_transaction_id = "txn-123"

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_funding
    mock_session.execute = AsyncMock(return_value=mock_result)

    mock_gw = AsyncMock()
    mock_gw.refund = AsyncMock(return_value=MagicMock(status="completed", transaction_id="ref-1"))

    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.services.payment_gateway.get_gateway", new_callable=AsyncMock, return_value=mock_gw):
            from app.worker.tasks import process_pledge_refund
            await process_pledge_refund(_mock_ctx(), funding_id=1)


@pytest.mark.asyncio
async def test_process_ticket_refund():
    """process_ticket_refund processes a ticket refund."""
    mock_sm, mock_session = _mock_session_maker()
    mock_sale = MagicMock(spec=TicketSale)
    mock_sale.id = 1
    mock_sale.amount_paid_cents = 2500
    mock_sale.status = TicketSaleStatus.refund_processing
    mock_sale.gateway_transaction_id = "txn-456"

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_sale
    mock_session.execute = AsyncMock(return_value=mock_result)

    mock_gw = AsyncMock()
    mock_gw.refund = AsyncMock(return_value=MagicMock(status="completed", transaction_id="ref-2"))

    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.services.payment_gateway.get_gateway", new_callable=AsyncMock, return_value=mock_gw):
            from app.worker.tasks import process_ticket_refund
            await process_ticket_refund(_mock_ctx(), ticket_sale_id=1)


@pytest.mark.asyncio
async def test_process_sponsor_refund():
    """process_sponsor_refund processes a sponsor payment refund."""
    mock_sm, mock_session = _mock_session_maker()
    mock_payment = MagicMock(spec=SponsorPayment)
    mock_payment.id = 1
    mock_payment.amount_cents = 10000
    mock_payment.status = "refund_processing"
    mock_payment.gateway_transaction_id = "txn-789"

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = mock_payment
    mock_session.execute = AsyncMock(return_value=mock_result)

    mock_gw = AsyncMock()
    mock_gw.refund = AsyncMock(return_value=MagicMock(status="completed", transaction_id="ref-3"))

    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.services.payment_gateway.get_gateway", new_callable=AsyncMock, return_value=mock_gw):
            from app.worker.tasks import process_sponsor_refund
            await process_sponsor_refund(_mock_ctx(), payment_id=1)


# ---------------------------------------------------------------------------
# Cron tasks — test disabled path (early return)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_check_all_ticket_escrows_disabled():
    """check_all_ticket_escrows returns early when disabled."""
    with patch("app.worker.tasks._is_cron_enabled", new_callable=AsyncMock, return_value=False):
        from app.worker.tasks import check_all_ticket_escrows
        await check_all_ticket_escrows(_mock_ctx())


@pytest.mark.asyncio
async def test_check_all_sponsor_escrows_disabled():
    """check_all_sponsor_escrows returns early when disabled."""
    with patch("app.worker.tasks._is_cron_enabled", new_callable=AsyncMock, return_value=False):
        from app.worker.tasks import check_all_sponsor_escrows
        await check_all_sponsor_escrows(_mock_ctx())


@pytest.mark.asyncio
async def test_daily_reconciliation_disabled():
    """daily_reconciliation returns early when disabled."""
    with patch("app.worker.tasks._is_cron_enabled", new_callable=AsyncMock, return_value=False):
        from app.worker.tasks import daily_reconciliation
        await daily_reconciliation(_mock_ctx())


# ---------------------------------------------------------------------------
# Cron tasks — test enabled path
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_daily_reconciliation_enabled():
    """daily_reconciliation runs reconciliation when enabled."""
    mock_sm, mock_session = _mock_session_maker()
    mock_report = MagicMock()
    mock_report.run_date = "2026-03-01"
    mock_report.status = "success"
    mock_report.delta_cents = 0

    with patch("app.worker.tasks._is_cron_enabled", new_callable=AsyncMock, return_value=True):
        with patch("app.worker.tasks.async_session_maker", mock_sm):
            with patch("app.services.reconciliation.run_reconciliation", new_callable=AsyncMock, return_value=mock_report):
                with patch("app.worker.tasks._log_cron_run", new_callable=AsyncMock):
                    from app.worker.tasks import daily_reconciliation
                    await daily_reconciliation(_mock_ctx())


@pytest.mark.asyncio
async def test_check_all_ticket_escrows_enabled():
    """check_all_ticket_escrows processes when enabled with empty list."""
    mock_sm, mock_session = _mock_session_maker()
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = []
    mock_session.execute = AsyncMock(return_value=mock_result)

    with patch("app.worker.tasks._is_cron_enabled", new_callable=AsyncMock, return_value=True):
        with patch("app.worker.tasks.async_session_maker", mock_sm):
            with patch("app.worker.tasks._log_cron_run", new_callable=AsyncMock):
                from app.worker.tasks import check_all_ticket_escrows
                await check_all_ticket_escrows(_mock_ctx())


@pytest.mark.asyncio
async def test_archive_resolved_chats_enabled():
    """archive_resolved_chats runs without error when enabled."""
    mock_sm, mock_session = _mock_session_maker()
    mock_result = MagicMock()
    mock_result.scalars.return_value.all.return_value = []
    mock_session.execute = AsyncMock(return_value=mock_result)

    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
            with patch("app.worker.tasks._log_cron_run", new_callable=AsyncMock):
                from app.worker.tasks import archive_resolved_chats
                await archive_resolved_chats(_mock_ctx())


@pytest.mark.asyncio
async def test_cleanup_old_records_enabled():
    """cleanup_old_records runs without error."""
    mock_sm, mock_session = _mock_session_maker()
    mock_exec_result = MagicMock()
    mock_exec_result.rowcount = 0
    mock_session.execute = AsyncMock(return_value=mock_exec_result)

    with patch("app.worker.tasks.async_session_maker", mock_sm):
        with patch("app.services.platform_settings.get_int", new_callable=AsyncMock, return_value=30):
            with patch("app.worker.tasks._log_cron_run", new_callable=AsyncMock):
                from app.worker.tasks import cleanup_old_records
                await cleanup_old_records(_mock_ctx())
