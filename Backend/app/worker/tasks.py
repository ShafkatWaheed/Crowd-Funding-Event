"""
ARQ background tasks for refund processing, email sending, and other async work.

Each task gets its own DB session (not tied to the HTTP request lifecycle).
The pattern: API sets status to *_processing -> enqueues task -> task completes the refund.
"""
from __future__ import annotations

import time
import traceback
from datetime import datetime, timedelta, timezone
from typing import Any

from app.db.base import async_session_maker
from app.logger import get_logger
from app.models.funding import FundingStatus
from app.models.ticket import TicketSaleStatus
from app.models.sponsor import PaymentStatus
from app.services import email_notifications as email_notify

logger = get_logger("arq.tasks")


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
        from app.repositories.worker_run_repo import worker_run_repo
        async with async_session_maker() as db:
            await worker_run_repo.create_run_log(
                db,
                task_name=task_name,
                status=status,
                started_at=started_at,
                finished_at=datetime.now(timezone.utc),
                duration_ms=duration_ms,
                items_processed=items_processed,
                error=error,
            )
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
#  Poll tasks
# ═══════════════════════════════════════════

async def notify_poll_created(ctx: dict, *, event_id: int, poll_id: int) -> None:
    """Send in-app + push notifications to all event registrants when a new poll is created."""
    async with async_session_maker() as db:
        try:
            from app.models.notification import NotificationType
            from app.models.registration import RegistrationStatus
            from app.repositories.registration_repo import registration_repo as reg_repo
            from app.services import notification_service as notif_svc

            registrations = await reg_repo.list_by_event(db, event_id)
            user_ids = [
                r.user_id
                for r in registrations
                if r.status == RegistrationStatus.confirmed
            ]
            if user_ids:
                await notif_svc.create_bulk_notifications(
                    db,
                    user_ids=user_ids,
                    type=NotificationType.poll_created,
                    title="New Poll Available",
                    message="A new poll has been posted for your event — tap to vote!",
                    data={"event_id": event_id, "poll_id": poll_id, "route": f"/events/{event_id}"},
                )
                await db.commit()
                logger.info("Poll %d: notified %d registrants", poll_id, len(user_ids))
        except Exception:
            logger.exception("notify_poll_created failed for poll %d", poll_id)


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
    Complete a single pledge refund via payment gateway.
    Called after the API has already set status=refund_processing and released reserved spots.
    """
    from app.services.payment_gateway import get_gateway
    from app.repositories.funding_repo import funding_repo

    async with async_session_maker() as db:
        try:
            funding = await funding_repo.get_funding_by_id(db, funding_id)

            if not funding or funding.status != FundingStatus.refund_processing:
                logger.warning("Pledge %d: skip (not in refund_processing)", funding_id)
                return

            gateway = await get_gateway(db)
            result = await gateway.refund(
                db,
                original_transaction_id=funding.gateway_transaction_id or "",
                amount_cents=funding.amount_cents,
                description=f"Pledge refund for funding #{funding_id}",
            )
            if result.status != "completed":
                raise RuntimeError(f"Gateway returned status={result.status}")

            await funding_repo.complete_refund(db, funding, result.transaction_id)
            await db.commit()

            await _send_pledge_refund_email(db, funding)
            logger.info("Pledge %d: refunded (%d cents, txn=%s)", funding_id, funding.amount_cents, result.transaction_id)

        except Exception:
            await db.rollback()
            await _mark_funding_failed(db, funding_id)
            logger.exception("Pledge %d: refund failed", funding_id)


async def process_bulk_pledge_refunds(ctx: dict, event_id: int, guest_refund: bool = True) -> None:
    """
    Process all pledge refunds for a cancelled event.
    Each pledge is handled individually so one failure doesn't block the rest.
    """
    from app.repositories.funding_repo import funding_repo

    async with async_session_maker() as db:
        funding_ids = await funding_repo.get_refundable_pledge_ids(
            db, event_id, guest_refund=guest_refund,
        )

    for fid in funding_ids:
        await process_pledge_refund(ctx, fid)

    logger.info("Event %d: bulk refund complete (%d pledges)", event_id, len(funding_ids))


async def release_reserved_spots(ctx: dict, event_id: int) -> None:
    """Zero out pledge-reserved spots for an event (deferred job).
    If event.release_tier_spot_limits is True, also zeroes tier.max_reserved_spots
    for all tiers of the event, fully retiring per-tier pledge caps.
    """
    from app.repositories.event_repo import event_repo

    async with async_session_maker() as db:
        try:
            event = await event_repo.get_by_id(db, event_id)
            if event is None:
                logger.warning("release_reserved_spots: event %d not found", event_id)
                return
            await event_repo.zero_reserved_spots(
                db, event_id,
                zero_tier_limits=event.release_tier_spot_limits,
            )
            await db.commit()
            logger.info(
                "release_reserved_spots: zeroed spots for event %d (zero_tier_limits=%s)",
                event_id, event.release_tier_spot_limits,
            )
        except Exception:
            await db.rollback()
            logger.exception("release_reserved_spots failed for event %d", event_id)


async def process_ticket_refund(ctx: dict, ticket_sale_id: int) -> None:
    """
    Complete a single ticket refund via payment gateway.
    """
    from app.services.payment_gateway import get_gateway
    from app.repositories.ticket_repo import ticket_repo

    async with async_session_maker() as db:
        try:
            sale = await ticket_repo.get_sale_by_id(db, ticket_sale_id)

            if not sale or sale.status != TicketSaleStatus.refund_processing:
                logger.warning("Ticket %d: skip (not in refund_processing)", ticket_sale_id)
                return

            gateway = await get_gateway(db)
            result = await gateway.refund(
                db,
                original_transaction_id=sale.gateway_transaction_id or "",
                amount_cents=sale.amount_paid_cents,
                description=f"Ticket refund for sale #{ticket_sale_id}",
            )
            if result.status != "completed":
                raise RuntimeError(f"Gateway returned status={result.status}")

            await ticket_repo.complete_refund(db, sale, result.transaction_id)

            # Auto-unregister if no remaining active tickets and no active pledges
            from app.repositories.funding_repo import funding_repo as f_repo
            from app.repositories.registration_repo import registration_repo as r_repo
            from app.repositories.event_repo import event_repo as e_repo
            from app.models.registration import RegistrationStatus

            still_has_tickets = await ticket_repo.has_active_ticket_sales(db, sale.event_id, sale.user_id)
            has_pledges = await f_repo.has_active_pledges(db, sale.event_id, sale.user_id)
            if not still_has_tickets and not has_pledges:
                reg = await r_repo.get_existing_registration(db, sale.event_id, sale.user_id)
                if reg and reg.status == RegistrationStatus.registered:
                    event = await e_repo.get_by_id(db, sale.event_id)
                    await r_repo.update_registration_status(
                        db, reg, RegistrationStatus.cancelled, event=event,
                    )
                    logger.info("Ticket %d: auto-unregistered user %d from event %d after full refund", ticket_sale_id, sale.user_id, sale.event_id)

            # Revoke chat access if no remaining financial ties
            try:
                from app.services.chat import conversation_service
                await conversation_service.revoke_access(db, user_id=sale.user_id, event_id=sale.event_id)
            except Exception:
                logger.debug("Could not revoke chat access after ticket refund", extra={"user_id": sale.user_id, "event_id": sale.event_id})

            await db.commit()
            logger.info("Ticket %d: refunded (%d cents, txn=%s)", ticket_sale_id, sale.amount_paid_cents, result.transaction_id)

        except Exception:
            await db.rollback()
            await _mark_ticket_failed(db, ticket_sale_id)
            logger.exception("Ticket %d: refund failed", ticket_sale_id)


async def process_sponsor_refund(ctx: dict, payment_id: int) -> None:
    """
    Complete a sponsor payment refund via payment gateway.
    """
    from app.services.payment_gateway import get_gateway
    from app.repositories.sponsor_repo import sponsor_repo

    async with async_session_maker() as db:
        try:
            payment = await sponsor_repo.get_payment_by_id(db, payment_id)

            if not payment or payment.status != PaymentStatus.refund_processing:
                logger.warning("SponsorPayment %d: skip (not in refund_processing)", payment_id)
                return

            gateway = await get_gateway(db)
            result = await gateway.refund(
                db,
                original_transaction_id=payment.gateway_transaction_id or "",
                amount_cents=payment.amount_cents,
                description=f"Sponsor refund for payment #{payment_id}",
            )
            if result.status != "completed":
                raise RuntimeError(f"Gateway returned status={result.status}")

            await sponsor_repo.complete_payment_refund(db, payment, result.transaction_id)
            await db.commit()
            logger.info("SponsorPayment %d: refunded (%d cents, txn=%s)", payment_id, payment.amount_cents, result.transaction_id)

        except Exception:
            await db.rollback()
            await _mark_sponsor_payment_failed(db, payment_id)
            logger.exception("SponsorPayment %d: refund failed", payment_id)


async def process_bulk_sponsor_refunds(ctx: dict, event_id: int) -> None:
    """Process all sponsor payment refunds for a cancelled event."""
    from app.repositories.sponsor_repo import sponsor_repo

    async with async_session_maker() as db:
        payment_ids = await sponsor_repo.get_refundable_payment_ids_for_event(db, event_id)

    for pid in payment_ids:
        await process_sponsor_refund(ctx, pid)

    logger.info("Event %d: bulk sponsor refund complete (%d payments)", event_id, len(payment_ids))


# ── Helpers ──

async def _mark_funding_failed(db, funding_id: int) -> None:
    from app.repositories.funding_repo import funding_repo
    async with async_session_maker() as session:
        await funding_repo.mark_refund_failed(session, funding_id)
        await session.commit()
        await _notify_refund_failure(session, "pledge", funding_id)


async def _mark_ticket_failed(db, ticket_sale_id: int) -> None:
    from app.repositories.ticket_repo import ticket_repo
    async with async_session_maker() as session:
        await ticket_repo.mark_refund_failed(session, ticket_sale_id)
        await session.commit()
        await _notify_refund_failure(session, "ticket", ticket_sale_id)


async def _mark_sponsor_payment_failed(db, payment_id: int) -> None:
    from app.repositories.sponsor_repo import sponsor_repo
    async with async_session_maker() as session:
        await sponsor_repo.mark_payment_refund_failed(session, payment_id)
        await session.commit()
        await _notify_refund_failure(session, "sponsor", payment_id)


async def _notify_refund_failure(db, item_type: str, item_id: int) -> None:
    """Send failure notifications to admins (technical) and organizer (soft)."""
    try:
        from app.services import notification_service as notif_svc
        from app.models.notification import NotificationType
        from app.repositories.ticket_repo import ticket_repo
        from app.repositories.funding_repo import funding_repo
        from app.repositories.sponsor_repo import sponsor_repo
        from app.repositories.event_repo import event_repo
        from app.repositories.user_repo import user_repo

        type_map = {
            "ticket": NotificationType.ticket_refund_failed,
            "pledge": NotificationType.pledge_refund_failed,
            "sponsor": NotificationType.sponsor_refund_failed,
        }

        event_id = None
        organizer_id = None
        event_title = "Unknown"
        amount_cents = 0

        if item_type == "ticket":
            sale = await ticket_repo.get_sale_by_id(db, item_id)
            if sale:
                event_id = sale.event_id
                amount_cents = sale.amount_paid_cents
        elif item_type == "pledge":
            funding = await funding_repo.get_funding_by_id(db, item_id)
            if funding:
                event_id = funding.event_id
                amount_cents = funding.amount_cents
        elif item_type == "sponsor":
            payment = await sponsor_repo.get_payment_by_id(db, item_id)
            if payment:
                bid = await sponsor_repo.get_bid(db, payment.bid_id)
                if bid:
                    cat = await sponsor_repo.get_category(db, bid.category_id)
                    if cat:
                        event_id = cat.event_id
                amount_cents = payment.amount_cents

        if event_id:
            event = await event_repo.get_event_by_id_basic(db, event_id)
            if event:
                event_title = event.title
                organizer_id = event.organizer_id

        admin_ids = await user_repo.get_admin_ids(db)
        if admin_ids:
            await notif_svc.create_bulk_notifications(
                db, user_ids=admin_ids,
                type=type_map[item_type],
                title=f"{item_type.title()} Refund Failed",
                message=(
                    f"{item_type.title()} refund failed: #{item_id} for "
                    f"'{event_title}' (${amount_cents / 100:.2f}). "
                    "Manual intervention may be required."
                ),
                data={
                    "item_type": item_type, "item_id": item_id,
                    "event_id": event_id, "amount_cents": amount_cents,
                },
            )

        if organizer_id:
            await notif_svc.create_notification(
                db, user_id=organizer_id,
                type=NotificationType.refund_delayed_organizer,
                title="Refund Delayed",
                message=(
                    f"A refund for your event '{event_title}' is delayed. "
                    "Our team has been notified and is working on it."
                ),
                data={"event_id": event_id, "item_type": item_type},
            )

        await db.commit()
    except Exception:
        logger.exception("Failed to send refund failure notifications for %s %d", item_type, item_id)


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


async def mock_verify_bank_account(ctx: dict, bank_account_id: int) -> None:
    """Mock: auto-verify a bank account after the configured delay."""
    async with async_session_maker() as db:
        try:
            from app.models.payment_info import BankVerificationStatus
            from app.services import notification_service as notif_svc
            from app.models.notification import NotificationType
            from app.repositories.banking_repo import banking_repo

            acct = await banking_repo.get_account_by_id(db, bank_account_id)

            if not acct or acct.verification_status != BankVerificationStatus.pending:
                logger.info("Bank account %d: skip mock verify (not pending)", bank_account_id)
                return

            await banking_repo.verify_bank_account(db, acct)
            acct.verification_status = BankVerificationStatus.verified

            await notif_svc.create_notification(
                db, user_id=acct.user_id,
                type=NotificationType.bank_verified,
                title="Bank Account Verified",
                message="Your bank account has been verified. Payouts can now proceed.",
                data={"bank_account_id": acct.id},
            )
            await db.commit()
            logger.info("Bank account %d: mock verified for user %d", bank_account_id, acct.user_id)
        except Exception:
            await db.rollback()
            logger.exception("Bank account %d: mock verify failed", bank_account_id)


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
            from app.models.payment_mock_ledger import MockLedgerStatus
            from app.repositories.ledger_repo import ledger_repo
            cutoff = datetime.now(timezone.utc) - timedelta(seconds=delay_seconds)
            pending = await ledger_repo.get_pending_settlements(db, cutoff)

            for entry in pending:
                await ledger_repo.update_entry_status(
                    db, entry, status=MockLedgerStatus.settled, completed_at=datetime.now(timezone.utc),
                )
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
            from app.services.payment_gateway import get_gateway
            from app.repositories.escrow_repo import escrow_repo

            escrow = await escrow_repo.get_escrow_by_type_and_id(db, escrow_type, escrow_id)
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
        from app.repositories.banking_repo import banking_repo

        async with async_session_maker() as db:
            today = date_type.today()
            weekday = today.isoweekday()
            day_of_month = today.day

            accounts = await banking_repo.list_all_accounts(db)

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
                from app.repositories.user_repo import user_repo
                admins = await user_repo.get_admin_ids(db)
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
            from app.services import ticket_escrow as te_svc
            from app.repositories.escrow_repo import escrow_repo

            escrows = await escrow_repo.get_active_ticket_escrow_event_ids(db)
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
            from app.services import sponsor_escrow as se_svc
            from app.repositories.escrow_repo import escrow_repo as _esc_repo

            escrows = await _esc_repo.get_active_sponsor_escrow_event_ids(db)
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


async def cleanup_old_records(ctx: dict) -> None:
    """Periodic task: purge old WorkerRunLog and Notification rows past retention."""
    started_at = datetime.now(timezone.utc)
    t0 = time.monotonic()
    total_deleted = 0
    try:
        async with async_session_maker() as db:
            from app.services import platform_settings as settings_svc
            from app.repositories.worker_run_repo import worker_run_repo
            from app.repositories.notification_repo import notification_repo

            log_days = await settings_svc.get_int(db, "worker_run_log_retention_days")
            notif_days = await settings_svc.get_int(db, "notification_retention_days")

            if log_days > 0:
                cutoff = datetime.now(timezone.utc) - timedelta(days=log_days)
                total_deleted += await worker_run_repo.delete_before(db, cutoff)

            if notif_days > 0:
                cutoff = datetime.now(timezone.utc) - timedelta(days=notif_days)
                total_deleted += await notification_repo.delete_notifications_before(db, cutoff)

            # Clean up stale device tokens (orphaned from logout failures,
            # app uninstalls, force-quits, etc.)
            device_token_days = await settings_svc.get_int(db, "device_token_retention_days")
            if device_token_days > 0:
                cutoff = datetime.now(timezone.utc) - timedelta(days=device_token_days)
                total_deleted += await notification_repo.delete_device_tokens_before(db, cutoff)

            await db.commit()
            logger.info("Cleanup: deleted %d old records", total_deleted)
        await _log_cron_run("cleanup_old_records", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=total_deleted)
    except Exception:
        logger.exception("cleanup_old_records failed")
        await _log_cron_run("cleanup_old_records", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def archive_resolved_chats(ctx: dict) -> None:
    """Archive Redis chat streams for resolved bids / completed events, then clear metadata."""
    t0 = time.monotonic()
    started_at = datetime.now(timezone.utc)
    try:
        from app.services import chat_service
        from app.services import platform_settings as settings_svc
        from app.repositories.sponsor_repo import sponsor_repo

        async with async_session_maker() as db:
            retention_days = await settings_svc.get_int(db, "chat_archive_retention_days")
            cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)

            # 1) Bids whose events are completed/cancelled with end_date past cutoff
            event_ids = await sponsor_repo.get_archivable_bid_ids_by_event_status(db, cutoff)
            # 2) Rejected/withdrawn bids past cutoff
            bid_ids = await sponsor_repo.get_archivable_bid_ids_by_bid_status(db, cutoff)
            all_ids = set(event_ids + bid_ids)

            archived = 0
            for bid_id in all_ids:
                if await chat_service.archive_stream(bid_id):
                    archived += 1
                await sponsor_repo.clear_bid_chat_metadata(db, bid_id)

            await db.commit()
            logger.info("archive_resolved_chats: archived %d / %d streams", archived, len(all_ids))

        await _log_cron_run("archive_resolved_chats", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=archived)
    except Exception:
        logger.exception("archive_resolved_chats failed")
        await _log_cron_run("archive_resolved_chats", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def transition_event_status(ctx: dict, event_id: int, trigger_field: str, scheduled_for_iso: str) -> None:
    """Deferred: run auto_transition_status for a single event at the scheduled time.

    Idempotency: compares event.{trigger_field}.isoformat() to scheduled_for_iso.
    If the date has changed since this job was enqueued (stale job), exits without
    making changes. If the event just reached waiting_event_date, enqueues a follow-up
    job at the newly calculated event_date_deadline.
    """
    try:
        from app.repositories.event_repo import event_repo
        from app.services.event import auto_transition_status
        from app.models.event import EventStatus

        async with async_session_maker() as db:
            event = await event_repo.get_by_id(db, event_id)
            if event is None:
                logger.info("transition_event_status: event %d not found, skipping", event_id)
                return

            current_val = getattr(event, trigger_field, None)
            if current_val is None or current_val.isoformat() != scheduled_for_iso:
                logger.info(
                    "transition_event_status: stale job for event %d field=%s (expected %s, got %s), skipping",
                    event_id, trigger_field, scheduled_for_iso,
                    current_val.isoformat() if current_val else "None",
                )
                return

            prev_status = event.status
            await auto_transition_status(db, event)

            # Close chat channels/conversations when event completes or is cancelled
            if event.status != prev_status and event.status in (
                EventStatus.completed, EventStatus.cancelled
            ):
                try:
                    from app.services.chat import channel_service, conversation_service
                    await channel_service.close_event_channels(db, event_id=event_id)
                    await conversation_service.close_event_conversations(db, event_id=event_id)
                except Exception:
                    logger.debug("Could not close chat for event %d", event_id)

            await db.commit()

            logger.info(
                "transition_event_status: event %d %s → %s (via %s)",
                event_id, prev_status.value, event.status.value, trigger_field,
            )

            # Chain: approved→waiting_event_date calculates event_date_deadline —
            # enqueue the cancellation check job now that the deadline is known
            if (
                event.status != prev_status
                and event.status == EventStatus.waiting_event_date
                and event.event_date_deadline
            ):
                from app.worker.redis_pool import enqueue as arq_enqueue
                await arq_enqueue(
                    "transition_event_status",
                    event_id,
                    "event_date_deadline",
                    event.event_date_deadline.isoformat(),
                    _defer_until=event.event_date_deadline,
                )

    except Exception:
        logger.exception("transition_event_status failed for event %d", event_id)


async def reconcile_event_statuses(ctx: dict) -> None:
    """Safety-net cron: catch events that missed their deferred transition job.

    Covers all transitional statuses. Deferred jobs handle the normal case;
    this catches stragglers from Redis flush, worker downtime, or missed jobs.
    Interval is configurable via cron_event_reconcile_interval_min (default 60 min).
    """
    t0 = time.monotonic()
    started_at = datetime.now(timezone.utc)
    count = 0
    try:
        from app.repositories.event_repo import event_repo
        from app.services.event import auto_transition_status
        from app.models.event import EventStatus
        from app.worker.redis_pool import enqueue as arq_enqueue

        now = datetime.now(timezone.utc)
        async with async_session_maker() as db:
            events = await event_repo.get_events_needing_transition(db, now)
            for event in events:
                prev_status = event.status
                await auto_transition_status(db, event)
                count += 1
                # Chain: enqueue event_date_deadline follow-up if just transitioned
                if (
                    event.status != prev_status
                    and event.status == EventStatus.waiting_event_date
                    and event.event_date_deadline
                ):
                    await arq_enqueue(
                        "transition_event_status",
                        event.id,
                        "event_date_deadline",
                        event.event_date_deadline.isoformat(),
                        _defer_until=event.event_date_deadline,
                    )
            if count:
                await db.commit()

        logger.info("reconcile_event_statuses: processed %d events", count)
        await _log_cron_run("reconcile_event_statuses", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=count)
    except Exception:
        logger.exception("reconcile_event_statuses failed")
        await _log_cron_run("reconcile_event_statuses", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def purge_old_chat_archives(ctx: dict) -> None:
    """Delete archived chat JSON files older than the retention period."""
    t0 = time.monotonic()
    started_at = datetime.now(timezone.utc)
    try:
        from app.services import chat_service
        from app.services import platform_settings as settings_svc

        async with async_session_maker() as db:
            retention_days = await settings_svc.get_int(db, "chat_archive_retention_days")

        purged = await chat_service.purge_old_archives(retention_days)
        await _log_cron_run("purge_old_chat_archives", status="success", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, items_processed=purged)
    except Exception:
        logger.exception("purge_old_chat_archives failed")
        await _log_cron_run("purge_old_chat_archives", status="error", started_at=started_at, duration_ms=(time.monotonic() - t0) * 1000, error=traceback.format_exc()[-500:])


async def _send_pledge_refund_email(db, funding) -> None:
    """Best-effort email after successful refund."""
    try:
        from app.repositories.funding_repo import funding_repo
        async with async_session_maker() as session:
            f = await funding_repo.get_funding_with_user_and_event(session, funding.id)

            if f and f.user and f.event:
                await email_notify.notify_unpledge_refund(
                    user_email=f.user.email,
                    user_name=f.user.display_name or "",
                    event_title=f.event.title or f"Event #{f.event_id}",
                    refunded_cents=f.amount_cents,
                    pledges_count=1,
                )
    except Exception:
        logger.exception("Failed to send refund email for funding %d", funding.id)
