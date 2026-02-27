"""
ARQ background tasks for refund processing, email sending, and other async work.

Each task gets its own DB session (not tied to the HTTP request lifecycle).
The pattern: API sets status to *_processing -> enqueues task -> task completes the refund.
"""
from __future__ import annotations

import logging
import time
import traceback
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import select, update

from app.db.base import async_session_maker
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.sponsor import SponsorBid, SponsorPayment, PaymentStatus, BidStatus, SponsorshipCategory
from app.services import email_notifications as email_notify

logger = logging.getLogger("arq.tasks")


async def _log_cron_run(
    task_name: str,
    *,
    status: str,
    started_at: datetime,
    duration_ms: float,
    items_processed: int | None = None,
    error: str | None = None,
) -> None:
    """Persist a cron run record to worker_run_logs."""
    try:
        from app.models.worker_run_log import WorkerRunLog
        async with async_session_maker() as db:
            db.add(WorkerRunLog(
                task_name=task_name,
                status=status,
                started_at=started_at,
                finished_at=datetime.now(timezone.utc),
                duration_ms=duration_ms,
                items_processed=items_processed,
                error=error,
            ))
            await db.commit()
    except Exception:
        logger.exception("Failed to log cron run for %s", task_name)


async def _is_cron_enabled(setting_key: str) -> bool:
    """Check if a cron job is enabled via platform settings."""
    try:
        from app.services import platform_settings as settings_svc
        async with async_session_maker() as db:
            return await settings_svc.get_bool(db, setting_key)
    except Exception:
        return True


# ═══════════════════════════════════════════
#  Email tasks
# ═══════════════════════════════════════════

async def send_event_cancelled_email(
    ctx: dict,
    event_id: int,
    event_title: str,
    reason: str | None,
    event_date: Any | None,
) -> None:
    """Send cancellation emails to all registrants/pledgers of an event."""
    async with async_session_maker() as db:
        try:
            await email_notify.notify_event_cancelled(
                db,
                event_id=event_id,
                event_title=event_title,
                reason=reason,
                event_date=event_date,
            )
            logger.info("Event %d: cancellation emails sent", event_id)
        except Exception:
            logger.exception("Event %d: failed to send cancellation emails", event_id)


async def send_ticket_purchased_email(
    ctx: dict,
    *,
    buyer_email: str,
    buyer_name: str,
    event_title: str,
    tier_name: str,
    ticket_code: str,
    receipt_number: str,
    amount_cents: int,
    quantity: int,
    event_date: Any | None,
    discount_cents: int,
    commission_cents: int,
) -> None:
    try:
        await email_notify.notify_ticket_purchased(
            buyer_email=buyer_email,
            buyer_name=buyer_name,
            event_title=event_title,
            tier_name=tier_name,
            ticket_code=ticket_code,
            receipt_number=receipt_number,
            amount_cents=amount_cents,
            quantity=quantity,
            event_date=event_date,
            discount_cents=discount_cents,
            commission_cents=commission_cents,
        )
        logger.info("Ticket purchase email sent to %s", buyer_email)
    except Exception:
        logger.exception("Failed to send ticket purchase email to %s", buyer_email)


async def send_waitlist_rejected_email(
    ctx: dict,
    *,
    buyer_email: str,
    buyer_name: str,
    event_title: str,
    tier_name: str,
    amount_cents: int,
) -> None:
    try:
        await email_notify.notify_waitlist_ticket_rejected(
            buyer_email=buyer_email,
            buyer_name=buyer_name,
            event_title=event_title,
            tier_name=tier_name,
            amount_cents=amount_cents,
        )
        logger.info("Waitlist rejection email sent to %s", buyer_email)
    except Exception:
        logger.exception("Failed to send waitlist rejection email to %s", buyer_email)


async def send_ticket_refund_approved_email(
    ctx: dict,
    *,
    buyer_email: str,
    buyer_name: str,
    event_title: str,
    tier_name: str,
    amount_cents: int,
    receipt_number: str | None = None,
) -> None:
    try:
        await email_notify.notify_ticket_refund_approved(
            buyer_email=buyer_email,
            buyer_name=buyer_name,
            event_title=event_title,
            tier_name=tier_name,
            amount_cents=amount_cents,
            receipt_number=receipt_number,
        )
        logger.info("Ticket refund approved email sent to %s", buyer_email)
    except Exception:
        logger.exception("Failed to send ticket refund email to %s", buyer_email)


async def send_waitlist_approved_email(
    ctx: dict,
    *,
    buyer_email: str,
    buyer_name: str,
    event_title: str,
    tier_name: str,
    amount_cents: int,
    ticket_code: str | None = None,
    event_date: Any | None = None,
) -> None:
    try:
        await email_notify.notify_waitlist_ticket_approved(
            buyer_email=buyer_email,
            buyer_name=buyer_name,
            event_title=event_title,
            tier_name=tier_name,
            amount_cents=amount_cents,
            ticket_code=ticket_code,
            event_date=event_date,
        )
        logger.info("Waitlist approval email sent to %s", buyer_email)
    except Exception:
        logger.exception("Failed to send waitlist approval email to %s", buyer_email)


async def send_sponsor_bid_approved_email(
    ctx: dict,
    *,
    sponsor_email: str,
    sponsor_name: str,
    event_title: str,
    category_name: str,
    bid_amount_cents: int,
) -> None:
    try:
        await email_notify.notify_sponsor_bid_approved(
            sponsor_email=sponsor_email,
            sponsor_name=sponsor_name,
            event_title=event_title,
            category_name=category_name,
            bid_amount_cents=bid_amount_cents,
        )
        logger.info("Sponsor bid approved email sent to %s", sponsor_email)
    except Exception:
        logger.exception("Failed to send sponsor bid approved email to %s", sponsor_email)


async def send_sponsor_bid_rejected_email(
    ctx: dict,
    *,
    sponsor_email: str,
    sponsor_name: str,
    event_title: str,
    category_name: str,
    bid_amount_cents: int,
) -> None:
    try:
        await email_notify.notify_sponsor_bid_rejected(
            sponsor_email=sponsor_email,
            sponsor_name=sponsor_name,
            event_title=event_title,
            category_name=category_name,
            bid_amount_cents=bid_amount_cents,
        )
        logger.info("Sponsor bid rejected email sent to %s", sponsor_email)
    except Exception:
        logger.exception("Failed to send sponsor bid rejected email to %s", sponsor_email)


async def send_sponsor_refund_email(
    ctx: dict,
    *,
    sponsor_email: str,
    sponsor_name: str,
    event_title: str,
    category_name: str,
    refunded_cents: int,
    receipt_number: str | None = None,
) -> None:
    try:
        await email_notify.notify_sponsor_refund(
            sponsor_email=sponsor_email,
            sponsor_name=sponsor_name,
            event_title=event_title,
            category_name=category_name,
            refunded_cents=refunded_cents,
            receipt_number=receipt_number,
        )
        logger.info("Sponsor refund email sent to %s", sponsor_email)
    except Exception:
        logger.exception("Failed to send sponsor refund email to %s", sponsor_email)


async def process_pledge_refund(ctx: dict, funding_id: int) -> None:
    """
    Complete a single pledge refund. Called after the API has already set
    status=refund_processing and released reserved spots.

    Future: this is where the payment gateway refund call would go.
    For now, simulates processing then marks as refunded.
    """
    async with async_session_maker() as db:
        try:
            funding = (await db.execute(
                select(Funding).where(Funding.id == funding_id)
            )).scalar_one_or_none()

            if not funding or funding.status != FundingStatus.refund_processing:
                logger.warning("Pledge %d: skip (not in refund_processing)", funding_id)
                return

            # --- Payment gateway refund would go here ---
            # e.g. await payment_gateway.refund(funding.payment_intent_id, funding.amount_cents)

            funding.status = FundingStatus.refunded
            await db.commit()

            await _send_pledge_refund_email(db, funding)
            logger.info("Pledge %d: refunded (%d cents)", funding_id, funding.amount_cents)

        except Exception:
            await db.rollback()
            await _mark_funding_failed(db, funding_id)
            logger.exception("Pledge %d: refund failed", funding_id)


async def process_bulk_pledge_refunds(ctx: dict, event_id: int, guest_refund: bool = True) -> None:
    """
    Process all pledge refunds for a cancelled event.
    Each pledge is handled individually so one failure doesn't block the rest.
    """
    async with async_session_maker() as db:
        conditions = [
            Funding.event_id == event_id,
            Funding.status == FundingStatus.refund_processing,
        ]
        if not guest_refund:
            conditions.append(Funding.is_guest == False)  # noqa: E712

        result = await db.execute(select(Funding.id).where(*conditions))
        funding_ids = [row[0] for row in result.all()]

    for fid in funding_ids:
        await process_pledge_refund(ctx, fid)

    logger.info("Event %d: bulk refund complete (%d pledges)", event_id, len(funding_ids))


async def process_ticket_refund(ctx: dict, ticket_sale_id: int) -> None:
    """
    Complete a single ticket refund.
    """
    async with async_session_maker() as db:
        try:
            sale = (await db.execute(
                select(TicketSale).where(TicketSale.id == ticket_sale_id)
            )).scalar_one_or_none()

            if not sale or sale.status != TicketSaleStatus.refund_processing:
                logger.warning("Ticket %d: skip (not in refund_processing)", ticket_sale_id)
                return

            # --- Payment gateway refund would go here ---

            sale.status = TicketSaleStatus.refunded
            await db.commit()
            logger.info("Ticket %d: refunded (%d cents)", ticket_sale_id, sale.amount_paid_cents)

        except Exception:
            await db.rollback()
            await _mark_ticket_failed(db, ticket_sale_id)
            logger.exception("Ticket %d: refund failed", ticket_sale_id)


async def process_sponsor_refund(ctx: dict, payment_id: int) -> None:
    """
    Complete a sponsor payment refund.
    """
    async with async_session_maker() as db:
        try:
            payment = (await db.execute(
                select(SponsorPayment).where(SponsorPayment.id == payment_id)
            )).scalar_one_or_none()

            if not payment or payment.status != PaymentStatus.refund_processing:
                logger.warning("SponsorPayment %d: skip (not in refund_processing)", payment_id)
                return

            # --- Payment gateway refund would go here ---

            payment.status = PaymentStatus.refunded
            await db.commit()
            logger.info("SponsorPayment %d: refunded (%d cents)", payment_id, payment.amount_cents)

        except Exception:
            await db.rollback()
            await _mark_sponsor_payment_failed(db, payment_id)
            logger.exception("SponsorPayment %d: refund failed", payment_id)


async def process_bulk_sponsor_refunds(ctx: dict, event_id: int) -> None:
    """Process all sponsor payment refunds for a cancelled event."""
    async with async_session_maker() as db:
        result = await db.execute(
            select(SponsorPayment.id)
            .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorshipCategory.event_id == event_id,
                SponsorPayment.status == PaymentStatus.refund_processing,
            )
        )
        payment_ids = [row[0] for row in result.all()]

    for pid in payment_ids:
        await process_sponsor_refund(ctx, pid)

    logger.info("Event %d: bulk sponsor refund complete (%d payments)", event_id, len(payment_ids))


# ── Helpers ──

async def _mark_funding_failed(db, funding_id: int) -> None:
    async with async_session_maker() as session:
        await session.execute(
            update(Funding)
            .where(Funding.id == funding_id, Funding.status == FundingStatus.refund_processing)
            .values(status=FundingStatus.refund_failed)
        )
        await session.commit()


async def _mark_ticket_failed(db, ticket_sale_id: int) -> None:
    async with async_session_maker() as session:
        await session.execute(
            update(TicketSale)
            .where(TicketSale.id == ticket_sale_id, TicketSale.status == TicketSaleStatus.refund_processing)
            .values(status=TicketSaleStatus.refund_failed)
        )
        await session.commit()


async def _mark_sponsor_payment_failed(db, payment_id: int) -> None:
    async with async_session_maker() as session:
        await session.execute(
            update(SponsorPayment)
            .where(SponsorPayment.id == payment_id, SponsorPayment.status == PaymentStatus.refund_processing)
            .values(status=PaymentStatus.refund_failed)
        )
        await session.commit()


async def send_push_notification(
    ctx: dict,
    *,
    user_id: int,
    title: str,
    body: str,
    data: dict | None = None,
) -> None:
    """Send FCM push notification to a single user's devices."""
    async with async_session_maker() as db:
        try:
            from app.services import push_notification as push_svc
            await push_svc.send_push(db, user_id=user_id, title=title, body=body, data=data)
            await db.commit()
        except Exception:
            await db.rollback()
            logger.exception("Push notification failed for user %d", user_id)


async def send_push_notification_bulk(
    ctx: dict,
    *,
    user_ids: list[int],
    title: str,
    body: str,
    data: dict | None = None,
) -> None:
    """Send FCM push notifications to multiple users."""
    async with async_session_maker() as db:
        try:
            from app.services import push_notification as push_svc
            await push_svc.send_push_bulk(db, user_ids=user_ids, title=title, body=body, data=data)
            await db.commit()
        except Exception:
            await db.rollback()
            logger.exception("Bulk push notification failed for %d users", len(user_ids))


async def mock_auto_settle(ctx: dict) -> None:
    """Periodic task: settle mock ledger entries whose settlement delay has elapsed."""
    if not await _is_cron_enabled("arq_mock_auto_settle_enabled"):
        return
    started_at = datetime.now(timezone.utc)
    t0 = time.monotonic()
    count = 0
    try:
        async with async_session_maker() as db:
            from app.services import platform_settings as settings_svc
            delay_seconds = await settings_svc.get_int(db, "mock_settlement_delay_seconds")
            if delay_seconds <= 0:
                await _log_cron_run("mock_auto_settle", status="skipped", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000)
                return
            from app.models.payment_mock_ledger import PaymentMockLedger, MockLedgerStatus
            cutoff = datetime.now(timezone.utc) - timedelta(seconds=delay_seconds)
            pending = (await db.execute(
                select(PaymentMockLedger).where(
                    PaymentMockLedger.status == MockLedgerStatus.settlement_pending,
                    PaymentMockLedger.created_at <= cutoff,
                )
            )).scalars().all()

            for entry in pending:
                entry.status = MockLedgerStatus.settled
                entry.completed_at = datetime.now(timezone.utc)
            count = len(pending)

            if pending:
                await db.commit()
                logger.info("Auto-settled %d mock ledger entries", count)
        await _log_cron_run("mock_auto_settle", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=count)
    except Exception:
        logger.exception("mock_auto_settle failed")
        await _log_cron_run("mock_auto_settle", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def process_escrow_release(ctx: dict, escrow_type: str, escrow_id: int, stage: int) -> None:
    """Process an escrow stage release via payment gateway."""
    async with async_session_maker() as db:
        try:
            from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow
            from app.services.payment_gateway import get_gateway

            model_map = {
                "fund": FundEscrow,
                "ticket": TicketEscrow,
                "sponsor": SponsorEscrow,
            }
            model = model_map.get(escrow_type)
            if not model:
                logger.error("Unknown escrow type: %s", escrow_type)
                return

            escrow = (await db.execute(
                select(model).where(model.id == escrow_id)
            )).scalar_one_or_none()
            if not escrow:
                logger.warning("Escrow %s/%d not found", escrow_type, escrow_id)
                return

            gateway = await get_gateway(db)
            stage_attr = f"stage{stage}_released_cents"
            amount = getattr(escrow, stage_attr, 0)
            if amount <= 0:
                logger.info("Escrow %s/%d stage %d: nothing to release", escrow_type, escrow_id, stage)
                return

            result = await gateway.release_hold(
                db,
                hold_id=f"{escrow_type}_{escrow_id}",
                to_account=f"organizer_event_{escrow.event_id}",
                amount_cents=amount,
            )
            await db.commit()
            logger.info(
                "Escrow %s/%d stage %d: released %d cents (txn %s)",
                escrow_type, escrow_id, stage, amount, result.transaction_id,
            )

        except Exception:
            await db.rollback()
            logger.exception("Escrow %s/%d stage %d: release failed", escrow_type, escrow_id, stage)


async def process_scheduled_payouts(ctx: dict) -> None:
    """Daily cron task: process scheduled organizer payouts with netting."""
    if not await _is_cron_enabled("arq_scheduled_payouts_enabled"):
        return
    started_at = datetime.now(timezone.utc)
    t0 = time.monotonic()
    count = 0
    try:
        from datetime import date as date_type
        from app.models.payment_info import OrganizerBankAccount

        async with async_session_maker() as db:
            today = date_type.today()
            weekday = today.isoweekday()
            day_of_month = today.day

            accounts = (await db.execute(select(OrganizerBankAccount))).scalars().all()

            for acct in accounts:
                should_pay = False
                if acct.payout_schedule == "daily":
                    should_pay = True
                elif acct.payout_schedule == "weekly" and weekday == acct.payout_day:
                    should_pay = True
                elif acct.payout_schedule == "monthly" and day_of_month == acct.payout_day:
                    should_pay = True

                if not should_pay:
                    continue

                count += 1
                logger.info("Payout check for organizer user_id=%d", acct.user_id)

            await db.commit()
            logger.info("Scheduled payouts processed for %s", today)
        await _log_cron_run("process_scheduled_payouts", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=count)
    except Exception:
        logger.exception("Failed to process scheduled payouts")
        await _log_cron_run("process_scheduled_payouts", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def daily_reconciliation(ctx: dict) -> None:
    """Daily cron task: run reconciliation check at 2 AM."""
    if not await _is_cron_enabled("arq_daily_reconciliation_enabled"):
        return
    started_at = datetime.now(timezone.utc)
    t0 = time.monotonic()
    try:
        async with async_session_maker() as db:
            from app.services.reconciliation import run_reconciliation
            report = await run_reconciliation(db)
            await db.commit()
            logger.info(
                "Reconciliation %s: status=%s delta=%d cents",
                report.run_date, report.status, report.delta_cents,
            )

            if abs(report.delta_cents) > 100:
                from app.services import notification_service as notif_svc
                from app.models.notification import NotificationType
                from app.models.user import User, UserRole
                admins = (await db.execute(
                    select(User.id).where(User.role == UserRole.admin)
                )).scalars().all()
                for admin_id in admins:
                    await notif_svc.create_notification(
                        db,
                        user_id=admin_id,
                        type=NotificationType.event_status_changed,
                        title="Reconciliation Discrepancy",
                        message=f"Delta: ${abs(report.delta_cents) / 100:.2f}",
                        data={"delta_cents": report.delta_cents},
                    )
                await db.commit()
        await _log_cron_run("daily_reconciliation", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=1)
    except Exception:
        logger.exception("Daily reconciliation failed")
        await _log_cron_run("daily_reconciliation", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def check_all_ticket_escrows(ctx: dict) -> None:
    """Periodic task: check and auto-release ticket escrow stages for all active ticket escrows."""
    if not await _is_cron_enabled("arq_ticket_escrow_check_enabled"):
        return
    started_at = datetime.now(timezone.utc)
    t0 = time.monotonic()
    count = 0
    try:
        async with async_session_maker() as db:
            from app.models.escrow import TicketEscrow, EscrowStatus
            from app.services import ticket_escrow as te_svc

            escrows = (await db.execute(
                select(TicketEscrow.event_id).where(
                    TicketEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released])
                )
            )).scalars().all()
            count = len(escrows)

            for event_id in escrows:
                try:
                    await te_svc.check_and_release_stage1(db, event_id=event_id)
                    await te_svc.check_and_release_stage2(db, event_id=event_id)
                    await te_svc.check_and_release_stage3(db, event_id=event_id)
                except Exception:
                    logger.exception("Ticket escrow check failed for event %d", event_id)

            await db.commit()
            logger.info("Checked %d active ticket escrows", count)
        await _log_cron_run("check_all_ticket_escrows", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=count)
    except Exception:
        logger.exception("check_all_ticket_escrows failed")
        await _log_cron_run("check_all_ticket_escrows", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def check_all_sponsor_escrows(ctx: dict) -> None:
    """Periodic task: check and auto-release sponsor escrow stages for all active sponsor escrows."""
    if not await _is_cron_enabled("arq_sponsor_escrow_check_enabled"):
        return
    started_at = datetime.now(timezone.utc)
    t0 = time.monotonic()
    count = 0
    try:
        async with async_session_maker() as db:
            from app.models.escrow import SponsorEscrow, EscrowStatus
            from app.services import sponsor_escrow as se_svc

            escrows = (await db.execute(
                select(SponsorEscrow.event_id).where(
                    SponsorEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released])
                )
            )).scalars().all()
            count = len(escrows)

            for event_id in escrows:
                try:
                    await se_svc.check_and_release_stage1(db, event_id=event_id)
                    await se_svc.check_and_release_stage2(db, event_id=event_id)
                    await se_svc.check_and_release_stage3(db, event_id=event_id)
                except Exception:
                    logger.exception("Sponsor escrow check failed for event %d", event_id)

            await db.commit()
            logger.info("Checked %d active sponsor escrows", count)
        await _log_cron_run("check_all_sponsor_escrows", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=count)
    except Exception:
        logger.exception("check_all_sponsor_escrows failed")
        await _log_cron_run("check_all_sponsor_escrows", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def _send_pledge_refund_email(db, funding: Funding) -> None:
    """Best-effort email after successful refund."""
    try:
        from sqlalchemy.orm import selectinload
        async with async_session_maker() as session:
            f = (await session.execute(
                select(Funding)
                .options(selectinload(Funding.user), selectinload(Funding.event))
                .where(Funding.id == funding.id)
            )).scalar_one()

            if f.user and f.event:
                await email_notify.notify_unpledge_refund(
                    user_email=f.user.email,
                    user_name=f.user.display_name or "",
                    event_title=f.event.title or f"Event #{f.event_id}",
                    refunded_cents=f.amount_cents,
                    pledges_count=1,
                )
    except Exception:
        logger.exception("Failed to send refund email for funding %d", funding.id)
