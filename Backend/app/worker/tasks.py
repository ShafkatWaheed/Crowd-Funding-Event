"""
ARQ background tasks for refund processing and other async work.

Each task gets its own DB session (not tied to the HTTP request lifecycle).
The pattern: API sets status to *_processing -> enqueues task -> task completes the refund.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select, update

from app.db.base import async_session_maker
from app.models.funding import Funding, FundingStatus
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.sponsor import SponsorBid, SponsorPayment, PaymentStatus, BidStatus, SponsorshipCategory
from app.services import email_notifications as email_notify

logger = logging.getLogger("arq.tasks")


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
