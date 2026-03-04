"""
Refund retry service: validates failed refund items and re-enqueues ARQ tasks.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, NotFoundError
from app.logger import get_logger
from app.models.funding import FundingStatus
from app.models.sponsor import PaymentStatus
from app.models.ticket import TicketSaleStatus
from app.repositories.ticket_repo import ticket_repo
from app.repositories.funding_repo import funding_repo
from app.repositories.sponsor_repo import sponsor_repo

logger = get_logger("refund_retry")


async def retry_ticket_refund(db: AsyncSession, ticket_sale_id: int) -> None:
    sale = await ticket_repo.get_sale_by_id(db, ticket_sale_id)
    if not sale:
        raise NotFoundError("TicketSale", ticket_sale_id)
    if sale.status != TicketSaleStatus.refund_failed:
        raise ConflictError(f"Ticket #{ticket_sale_id} is not in refund_failed status")

    await ticket_repo.update_sale_status(db, sale, TicketSaleStatus.refund_processing)

    from app.worker.redis_pool import enqueue
    await enqueue("process_ticket_refund", ticket_sale_id)
    logger.info("Ticket refund retried: %d", ticket_sale_id)


async def retry_pledge_refund(db: AsyncSession, funding_id: int) -> None:
    funding = await funding_repo.get_funding_by_id(db, funding_id)
    if not funding:
        raise NotFoundError("Funding", funding_id)
    if funding.status != FundingStatus.refund_failed:
        raise ConflictError(f"Pledge #{funding_id} is not in refund_failed status")

    await funding_repo.update_status(db, funding, FundingStatus.refund_processing)

    from app.worker.redis_pool import enqueue
    await enqueue("process_pledge_refund", funding_id)
    logger.info("Pledge refund retried: %d", funding_id)


async def retry_sponsor_refund(db: AsyncSession, payment_id: int) -> None:
    payment = await sponsor_repo.get_payment_by_id(db, payment_id)
    if not payment:
        raise NotFoundError("SponsorPayment", payment_id)
    if payment.status != PaymentStatus.refund_failed:
        raise ConflictError(f"SponsorPayment #{payment_id} is not in refund_failed status")

    await sponsor_repo.update_payment_status(db, payment, PaymentStatus.refund_processing)

    from app.worker.redis_pool import enqueue
    await enqueue("process_sponsor_refund", payment_id)
    logger.info("Sponsor refund retried: %d", payment_id)


async def retry_all_for_event(db: AsyncSession, event_id: int) -> dict[str, int]:
    """Retry all refund_failed items for an event. Returns counts by type."""
    counts = {"tickets": 0, "pledges": 0, "sponsors": 0}

    ticket_ids = await ticket_repo.list_refund_failed_ids(db, event_id)
    for tid in ticket_ids:
        await retry_ticket_refund(db, tid)
    counts["tickets"] = len(ticket_ids)

    pledge_ids = await funding_repo.list_refund_failed_ids(db, event_id)
    for pid in pledge_ids:
        await retry_pledge_refund(db, pid)
    counts["pledges"] = len(pledge_ids)

    payment_ids = await sponsor_repo.list_refund_failed_payment_ids_for_event(db, event_id)
    for sid in payment_ids:
        await retry_sponsor_refund(db, sid)
    counts["sponsors"] = len(payment_ids)

    return counts


async def count_failed_refunds_for_event(db: AsyncSession, event_id: int) -> int:
    """Count all refund_failed items for an event."""
    tickets = await ticket_repo.count_refund_failed(db, event_id)
    pledges = await funding_repo.count_refund_failed(db, event_id)
    sponsors = await sponsor_repo.count_refund_failed_payments_for_event(db, event_id)
    return tickets + pledges + sponsors
