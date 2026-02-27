"""Sponsor delegate management: add, remove, list, check-in."""
from datetime import datetime, timezone

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.sponsor import SponsorDelegate, SponsorTicket


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
    await _get_ticket_owned_by(db, ticket_id, sponsor_user_id)

    count = (await db.execute(
        select(func.count()).where(SponsorDelegate.sponsor_ticket_id == ticket_id)
    )).scalar_one()
    if count >= max_delegates:
        raise ConflictError(f"Maximum of {max_delegates} delegates allowed per ticket")

    if email:
        existing = (await db.execute(
            select(SponsorDelegate).where(
                SponsorDelegate.sponsor_ticket_id == ticket_id,
                SponsorDelegate.email == email,
            )
        )).scalar_one_or_none()
        if existing:
            raise ConflictError(f"Delegate with email {email} already added")

    delegate = SponsorDelegate(
        sponsor_ticket_id=ticket_id,
        name=name.strip(),
        email=email.strip() if email else None,
        phone=phone.strip() if phone else None,
    )
    db.add(delegate)
    await db.flush()
    return delegate


async def remove_delegate(
    db: AsyncSession, delegate_id: int, sponsor_user_id: int,
) -> None:
    delegate = (await db.execute(
        select(SponsorDelegate).where(SponsorDelegate.id == delegate_id)
    )).scalar_one_or_none()
    if not delegate:
        raise NotFoundError("SponsorDelegate", delegate_id)

    await _get_ticket_owned_by(db, delegate.sponsor_ticket_id, sponsor_user_id)

    if delegate.checked_in:
        raise ConflictError("Cannot remove a delegate who has already checked in")

    await db.delete(delegate)
    await db.flush()


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
