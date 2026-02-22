"""
ARQ background tasks for refund processing, email sending, and other async work.

Each task gets its own DB session (not tied to the HTTP request lifecycle).
The pattern: API sets status to *_processing -> enqueues task -> task completes the refund.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select, update

from app.db.base import async_session_maker
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.sponsor import SponsorBid, SponsorPayment, PaymentStatus, BidStatus, SponsorshipCategory
from app.services import email_notifications as email_notify

logger = logging.getLogger("arq.tasks")


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
