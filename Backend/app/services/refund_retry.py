"""
Refund retry service: validates failed refund items and re-enqueues ARQ tasks.
"""
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.logger import get_logger
from app.models.funding import Funding, FundingStatus
from app.models.sponsor import SponsorBid, SponsorPayment, SponsorshipCategory, PaymentStatus
from app.models.ticket import TicketSale, TicketSaleStatus

logger = get_logger("refund_retry")


async def retry_ticket_refund(db: AsyncSession, ticket_sale_id: int) -> None:
    sale = (await db.execute(
        select(TicketSale).where(TicketSale.id == ticket_sale_id)
    )).scalar_one_or_none()
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.refund_failed:
        raise ConflictError(f"Ticket #{ticket_sale_id} is not in refund_failed status")

    sale.status = TicketSaleStatus.refund_processing
    await db.flush()

    from app.worker.redis_pool import enqueue
    await enqueue("process_ticket_refund", ticket_sale_id)
    logger.info("Ticket refund retried: %d", ticket_sale_id)


async def retry_pledge_refund(db: AsyncSession, funding_id: int) -> None:
    funding = (await db.execute(
        select(Funding).where(Funding.id == funding_id)
    )).scalar_one_or_none()
    if not funding:
        raise NotFoundError("Funding", funding_id)
    if funding.status != FundingStatus.refund_failed:
        raise ConflictError(f"Pledge #{funding_id} is not in refund_failed status")

    funding.status = FundingStatus.refund_processing
    await db.flush()

    from app.worker.redis_pool import enqueue
    await enqueue("process_pledge_refund", funding_id)
    logger.info("Pledge refund retried: %d", funding_id)


async def retry_sponsor_refund(db: AsyncSession, payment_id: int) -> None:
    payment = (await db.execute(
        select(SponsorPayment).where(SponsorPayment.id == payment_id)
    )).scalar_one_or_none()
    if not payment:
        raise NotFoundError("SponsorPayment", payment_id)
    if payment.status != PaymentStatus.refund_failed:
        raise ConflictError(f"SponsorPayment #{payment_id} is not in refund_failed status")

    payment.status = PaymentStatus.refund_processing
    await db.flush()

    from app.worker.redis_pool import enqueue
    await enqueue("process_sponsor_refund", payment_id)
    logger.info("Sponsor refund retried: %d", payment_id)


async def retry_all_for_event(db: AsyncSession, event_id: int) -> dict[str, int]:
    """Retry all refund_failed items for an event. Returns counts by type."""
    counts = {"tickets": 0, "pledges": 0, "sponsors": 0}

    ticket_ids = list((await db.execute(
        select(TicketSale.id).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.refund_failed,
        )
    )).scalars().all())
    for tid in ticket_ids:
        await retry_ticket_refund(db, tid)
    counts["tickets"] = len(ticket_ids)

    pledge_ids = list((await db.execute(
        select(Funding.id).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.refund_failed,
        )
    )).scalars().all())
    for pid in pledge_ids:
        await retry_pledge_refund(db, pid)
    counts["pledges"] = len(pledge_ids)

    payment_ids = list((await db.execute(
        select(SponsorPayment.id)
        .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorPayment.status == PaymentStatus.refund_failed,
        )
    )).scalars().all())
    for sid in payment_ids:
        await retry_sponsor_refund(db, sid)
    counts["sponsors"] = len(payment_ids)

    return counts


async def count_failed_refunds_for_event(db: AsyncSession, event_id: int) -> int:
    """Count all refund_failed items for an event."""
    tickets = (await db.execute(
        select(func.count()).select_from(TicketSale).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.refund_failed,
        )
    )).scalar_one()

    pledges = (await db.execute(
        select(func.count()).select_from(Funding).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.refund_failed,
        )
    )).scalar_one()

    sponsors = (await db.execute(
        select(func.count()).select_from(SponsorPayment)
        .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
        .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorshipCategory.event_id == event_id,
            SponsorPayment.status == PaymentStatus.refund_failed,
        )
    )).scalar_one()

    return tickets + pledges + sponsors
