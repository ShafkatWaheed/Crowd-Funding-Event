"""Sponsor delegate management: add, remove, list, check-in."""
from datetime import datetime, timezone

from sqlalchemy import select, func

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.sponsor import SponsorDelegate, SponsorTicket

logger = get_logger("svc.sponsor.delegates")


async def _get_ticket_owned_by(
    db: AsyncSession, ticket_id: int, sponsor_user_id: int,
) -> SponsorTicket:
    ticket = (await db.execute(
        select(SponsorTicket).where(SponsorTicket.id == ticket_id)
    )).scalar_one_or_none()
    if not ticket:
        raise NotFoundError("SponsorTicket", ticket_id)
    if ticket.sponsor_user_id != sponsor_user_id:
        raise ForbiddenError("You do not own this sponsor ticket")
    return ticket


async def list_delegates(
    db: AsyncSession, ticket_id: int, sponsor_user_id: int,
) -> list[SponsorDelegate]:
    await _get_ticket_owned_by(db, ticket_id, sponsor_user_id)
    q = (
        select(SponsorDelegate)
        .where(SponsorDelegate.sponsor_ticket_id == ticket_id)
        .order_by(SponsorDelegate.created_at.asc())
    )
    return list((await db.execute(q)).scalars().all())


async def add_delegate(
    db: AsyncSession,
    ticket_id: int,
    sponsor_user_id: int,
    name: str,
    email: str | None = None,
    phone: str | None = None,
    max_delegates: int = 5,
) -> SponsorDelegate:
    log_step(logger, "Add delegate", ticket_id=ticket_id, sponsor_user_id=sponsor_user_id)
    await _get_ticket_owned_by(db, ticket_id, sponsor_user_id)

    count = (await db.execute(
        select(func.count()).where(SponsorDelegate.sponsor_ticket_id == ticket_id)
    )).scalar_one()
    if count >= max_delegates:
        logger.warning("Add delegate rejected: max exceeded", extra={"ticket_id": ticket_id, "count": count})
        raise ConflictError(f"Maximum of {max_delegates} delegates allowed per ticket")

    if email:
        existing = (await db.execute(
            select(SponsorDelegate).where(
                SponsorDelegate.sponsor_ticket_id == ticket_id,
                SponsorDelegate.email == email,
            )
        )).scalar_one_or_none()
        if existing:
            logger.warning("Add delegate rejected: email already added", extra={"ticket_id": ticket_id, "email": email})
            raise ConflictError(f"Delegate with email {email} already added")

    delegate = SponsorDelegate(
        sponsor_ticket_id=ticket_id,
        name=name.strip(),
        email=email.strip() if email else None,
        phone=phone.strip() if phone else None,
    )
    db.add(delegate)
    await db.flush()
    logger.info("Delegate added", extra={"delegate_id": delegate.id, "ticket_id": ticket_id})
    return delegate


async def remove_delegate(
    db: AsyncSession, delegate_id: int, sponsor_user_id: int,
) -> None:
    log_step(logger, "Remove delegate", delegate_id=delegate_id, sponsor_user_id=sponsor_user_id)
    delegate = (await db.execute(
        select(SponsorDelegate).where(SponsorDelegate.id == delegate_id)
    )).scalar_one_or_none()
    if not delegate:
        raise NotFoundError("SponsorDelegate", delegate_id)

    await _get_ticket_owned_by(db, delegate.sponsor_ticket_id, sponsor_user_id)

    if delegate.checked_in:
        logger.warning("Remove delegate rejected: already checked in", extra={"delegate_id": delegate_id})
        raise ConflictError("Cannot remove a delegate who has already checked in")

    await db.delete(delegate)
    await db.flush()
    logger.info("Delegate removed", extra={"delegate_id": delegate_id})


async def check_in_delegate(
    db: AsyncSession, delegate_id: int,
) -> dict:
    delegate = (await db.execute(
        select(SponsorDelegate).where(SponsorDelegate.id == delegate_id)
    )).scalar_one_or_none()
    if not delegate:
        raise NotFoundError("SponsorDelegate", delegate_id)

    if delegate.checked_in:
        return {
            "already_checked_in": True,
            "name": delegate.name,
            "checked_in_at": delegate.checked_in_at.isoformat() if delegate.checked_in_at else None,
        }

    delegate.checked_in = True
    delegate.checked_in_at = datetime.now(timezone.utc)

    ticket = (await db.execute(
        select(SponsorTicket).where(SponsorTicket.id == delegate.sponsor_ticket_id)
    )).scalar_one()
    ticket.scan_count = (ticket.scan_count or 0) + 1
    if not ticket.scanned_at:
        ticket.scanned_at = delegate.checked_in_at

    await db.flush()
    return {
        "already_checked_in": False,
        "name": delegate.name,
        "checked_in_at": delegate.checked_in_at.isoformat(),
        "scan_count": ticket.scan_count,
    }
