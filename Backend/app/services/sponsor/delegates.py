"""Sponsor delegate management: add, remove, list, check-in."""
from datetime import datetime, timezone

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.sponsor import SponsorDelegate, SponsorTicket
from app.repositories.sponsor_repo import sponsor_repo

logger = get_logger("svc.sponsor.delegates")


async def _get_ticket_owned_by(
    db: AsyncSession, ticket_id: int, sponsor_user_id: int,
) -> SponsorTicket:
    ticket = await sponsor_repo.get_sponsor_ticket_by_id(db, ticket_id)
    if not ticket:
        raise NotFoundError("SponsorTicket", ticket_id)
    if ticket.sponsor_user_id != sponsor_user_id:
        raise ForbiddenError("You do not own this sponsor ticket")
    return ticket


async def list_delegates(
    db: AsyncSession, ticket_id: int, sponsor_user_id: int,
) -> list[SponsorDelegate]:
    await _get_ticket_owned_by(db, ticket_id, sponsor_user_id)
    return await sponsor_repo.list_delegates(db, ticket_id)


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

    count = await sponsor_repo.count_delegates(db, ticket_id)
    if count >= max_delegates:
        logger.warning("Add delegate rejected: max exceeded", extra={"ticket_id": ticket_id, "count": count})
        raise ConflictError(f"Maximum of {max_delegates} delegates allowed per ticket")

    if email:
        existing = await sponsor_repo.get_delegate_by_email(db, ticket_id, email)
        if existing:
            logger.warning("Add delegate rejected: email already added", extra={"ticket_id": ticket_id, "email": email})
            raise ConflictError(f"Delegate with email {email} already added")

    delegate = SponsorDelegate(
        sponsor_ticket_id=ticket_id,
        name=name.strip(),
        email=email.strip() if email else None,
        phone=phone.strip() if phone else None,
    )
    delegate = await sponsor_repo.add_delegate(db, delegate)
    logger.info("Delegate added", extra={"delegate_id": delegate.id, "ticket_id": ticket_id})
    return delegate


async def remove_delegate(
    db: AsyncSession, delegate_id: int, sponsor_user_id: int,
) -> None:
    log_step(logger, "Remove delegate", delegate_id=delegate_id, sponsor_user_id=sponsor_user_id)
    delegate = await sponsor_repo.get_delegate(db, delegate_id)
    if not delegate:
        raise NotFoundError("SponsorDelegate", delegate_id)

    await _get_ticket_owned_by(db, delegate.sponsor_ticket_id, sponsor_user_id)

    if delegate.checked_in:
        logger.warning("Remove delegate rejected: already checked in", extra={"delegate_id": delegate_id})
        raise ConflictError("Cannot remove a delegate who has already checked in")

    await sponsor_repo.remove_delegate(db, delegate)
    logger.info("Delegate removed", extra={"delegate_id": delegate_id})


async def check_in_delegate(
    db: AsyncSession, delegate_id: int,
) -> dict:
    delegate = await sponsor_repo.get_delegate(db, delegate_id)
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

    ticket = await sponsor_repo.get_sponsor_ticket_by_id(db, delegate.sponsor_ticket_id)
    ticket.scan_count = (ticket.scan_count or 0) + 1
    if not ticket.scanned_at:
        ticket.scanned_at = delegate.checked_in_at

    await sponsor_repo.flush(db)
    return {
        "already_checked_in": False,
        "name": delegate.name,
        "checked_in_at": delegate.checked_in_at.isoformat(),
        "scan_count": ticket.scan_count,
    }
