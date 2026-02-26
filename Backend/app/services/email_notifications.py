"""
High-level email notification functions.

Each function gathers the required context and sends the appropriate email.
All are safe to call directly or via BackgroundTasks — they never raise.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.services.email_service import send_email, send_email_bulk
from app.services import email_templates as tpl

logger = logging.getLogger("email_notifications")


def _format_date(dt: datetime | None) -> str | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.strftime("%b %d, %Y at %I:%M %p UTC")


# ═══════════════════════════════════════════════════════════
# 1. Event Cancelled — notify all affected users
# ═══════════════════════════════════════════════════════════

async def notify_event_cancelled(
    db: AsyncSession,
    *,
    event_id: int,
    event_title: str,
    reason: str | None,
    event_date: datetime | None = None,
) -> None:
    """
    Send cancellation emails to all registrants, pledgers, and ticket buyers.
    Pledgers receive a variant that mentions their refund.
    """
    try:
        from app.models.registration import Registration, RegistrationStatus
        from app.models.funding import Funding, FundingStatus
        from app.models.ticket import TicketSale, TicketSaleStatus

        date_str = _format_date(event_date)

        # 1. Pledgers (they get the refund variant)
        pledger_q = (
            select(Funding)
            .where(Funding.event_id == event_id)
            .where(Funding.status.in_([FundingStatus.refunded, FundingStatus.pledged]))
            .options(selectinload(Funding.user))
        )
        pledger_rows = (await db.execute(pledger_q)).scalars().all()

        # Build sets for deduplication
        pledger_emails: set[str] = set()
        pledger_recipients: list[dict[str, Any]] = []
        for f in pledger_rows:
            if f.user and f.user.email and f.user.email not in pledger_emails:
                pledger_emails.add(f.user.email)
                pledger_recipients.append({
                    "email": f.user.email,
                    "name": f.user.display_name or "",
                    "amount_cents": f.amount_cents,
                })

        # Send individual emails to pledgers (each has different refund amount)
        for pr in pledger_recipients:
            html = await tpl.cancellation_refund_template(
                event_title=event_title,
                reason=reason or "No reason provided.",
                refunded_cents=pr["amount_cents"],
                event_date=date_str,
                db=db,
            )
            await send_email(pr["email"], pr["name"], f"Event Cancelled — {event_title}", html)

        # 2. Registrants + ticket buyers (without refund — deduplicate against pledgers)
        reg_q = (
            select(Registration)
            .where(Registration.event_id == event_id)
            .where(Registration.status.in_([RegistrationStatus.registered, RegistrationStatus.waitlist]))
            .options(selectinload(Registration.user))
        )
        reg_rows = (await db.execute(reg_q)).scalars().all()

        ticket_q = (
            select(TicketSale)
            .where(TicketSale.event_id == event_id)
            .where(TicketSale.status == TicketSaleStatus.purchased)
            .options(selectinload(TicketSale.user))
        )
        ticket_rows = (await db.execute(ticket_q)).scalars().all()

        non_pledger_recipients: list[dict[str, str]] = []
        seen: set[str] = set(pledger_emails)
        for row in [*reg_rows, *ticket_rows]:
            u = row.user
            if u and u.email and u.email not in seen:
                seen.add(u.email)
                non_pledger_recipients.append({"email": u.email, "name": u.display_name or ""})

        if non_pledger_recipients:
            html = await tpl.event_cancelled_template(
                event_title=event_title,
                reason=reason or "No reason provided.",
                event_date=date_str,
                db=db,
            )
            await send_email_bulk(
                non_pledger_recipients,
                f"Event Cancelled — {event_title}",
                html,
            )

        logger.info(
            "Cancellation emails sent: %d pledgers, %d others for event %d",
            len(pledger_recipients), len(non_pledger_recipients), event_id,
        )
    except Exception:
        logger.exception("notify_event_cancelled failed for event %d", event_id)


# ═══════════════════════════════════════════════════════════
# 2. Ticket Purchased — receipt email to buyer
# ═══════════════════════════════════════════════════════════

async def notify_ticket_purchased(
    *,
    buyer_email: str,
    buyer_name: str,
    event_title: str,
    tier_name: str,
    ticket_code: str,
    receipt_number: str,
    amount_cents: int,
    quantity: int = 1,
    event_date: datetime | None = None,
    discount_cents: int = 0,
    commission_cents: int = 0,
) -> None:
    """Send ticket purchase confirmation/receipt to the buyer."""
    try:
        html = await tpl.ticket_purchased_template(
            event_title=event_title,
            tier_name=tier_name,
            ticket_code=ticket_code,
            receipt_number=receipt_number,
            amount_cents=amount_cents,
            quantity=quantity,
            event_date=_format_date(event_date),
            discount_cents=discount_cents,
            commission_cents=commission_cents,
        )
        await send_email(buyer_email, buyer_name, f"Ticket Confirmed — {event_title}", html)
    except Exception:
        logger.exception("notify_ticket_purchased failed for %s", buyer_email)


# ═══════════════════════════════════════════════════════════
# 3. Unpledge Refund
# ═══════════════════════════════════════════════════════════

async def notify_unpledge_refund(
    *,
    user_email: str,
    user_name: str,
    event_title: str,
    refunded_cents: int,
    pledges_count: int = 1,
) -> None:
    """Send unpledge refund confirmation to the user."""
    try:
        if refunded_cents <= 0:
            return
        html = await tpl.unpledge_refund_template(
            event_title=event_title,
            refunded_cents=refunded_cents,
            pledges_count=pledges_count,
        )
        await send_email(user_email, user_name, f"Pledge Refunded — {event_title}", html)
    except Exception:
        logger.exception("notify_unpledge_refund failed for %s", user_email)


# ═══════════════════════════════════════════════════════════
# 4. Unregister Refund
# ═══════════════════════════════════════════════════════════

async def notify_unregister_refund(
    *,
    user_email: str,
    user_name: str,
    event_title: str,
    refunded_cents: int,
) -> None:
    """Send unregister + refund confirmation to the user."""
    try:
        if refunded_cents <= 0:
            return
        html = await tpl.unregister_refund_template(
            event_title=event_title,
            refunded_cents=refunded_cents,
        )
        await send_email(user_email, user_name, f"Unregistered & Refunded — {event_title}", html)
    except Exception:
        logger.exception("notify_unregister_refund failed for %s", user_email)


# ═══════════════════════════════════════════════════════════
# 5. Waitlisted Ticket Rejected
# ═══════════════════════════════════════════════════════════

async def notify_waitlist_ticket_rejected(
    *,
    buyer_email: str,
    buyer_name: str,
    event_title: str,
    tier_name: str,
    amount_cents: int,
) -> None:
    """Send waitlisted ticket rejection notice to the buyer."""
    try:
        html = await tpl.waitlist_ticket_rejected_template(
            event_title=event_title,
            tier_name=tier_name,
            amount_cents=amount_cents,
        )
        await send_email(buyer_email, buyer_name, f"Ticket Not Approved — {event_title}", html)
    except Exception:
        logger.exception("notify_waitlist_ticket_rejected failed for %s", buyer_email)


# ═══════════════════════════════════════════════════════════
# 6. Ticket Refund Approved
# ═══════════════════════════════════════════════════════════

async def notify_ticket_refund_approved(
    *,
    buyer_email: str,
    buyer_name: str,
    event_title: str,
    tier_name: str,
    amount_cents: int,
    receipt_number: str | None = None,
) -> None:
    """Send ticket refund approval confirmation to the buyer."""
    try:
        html = await tpl.ticket_refund_approved_template(
            event_title=event_title,
            tier_name=tier_name,
            amount_cents=amount_cents,
            receipt_number=receipt_number,
        )
        await send_email(buyer_email, buyer_name, f"Ticket Refund Approved — {event_title}", html)
    except Exception:
        logger.exception("notify_ticket_refund_approved failed for %s", buyer_email)


# ═══════════════════════════════════════════════════════════
# 7. Waitlisted Ticket Approved
# ═══════════════════════════════════════════════════════════

async def notify_waitlist_ticket_approved(
    *,
    buyer_email: str,
    buyer_name: str,
    event_title: str,
    tier_name: str,
    amount_cents: int,
    ticket_code: str | None = None,
    event_date: datetime | None = None,
) -> None:
    """Send waitlisted ticket approval notice to the buyer."""
    try:
        html = await tpl.waitlist_ticket_approved_template(
            event_title=event_title,
            tier_name=tier_name,
            amount_cents=amount_cents,
            ticket_code=ticket_code,
            event_date=_format_date(event_date),
        )
        await send_email(buyer_email, buyer_name, f"Ticket Approved — {event_title}", html)
    except Exception:
        logger.exception("notify_waitlist_ticket_approved failed for %s", buyer_email)


# ═══════════════════════════════════════════════════════════
# 8. Sponsor Bid Approved
# ═══════════════════════════════════════════════════════════

async def notify_sponsor_bid_approved(
    *,
    sponsor_email: str,
    sponsor_name: str,
    event_title: str,
    category_name: str,
    bid_amount_cents: int,
) -> None:
    """Send bid acceptance email to the sponsor."""
    try:
        html = await tpl.sponsor_bid_approved_template(
            event_title=event_title,
            category_name=category_name,
            bid_amount_cents=bid_amount_cents,
        )
        await send_email(sponsor_email, sponsor_name, f"Bid Accepted — {event_title}", html)
    except Exception:
        logger.exception("notify_sponsor_bid_approved failed for %s", sponsor_email)


# ═══════════════════════════════════════════════════════════
# 9. Sponsor Bid Rejected
# ═══════════════════════════════════════════════════════════

async def notify_sponsor_bid_rejected(
    *,
    sponsor_email: str,
    sponsor_name: str,
    event_title: str,
    category_name: str,
    bid_amount_cents: int,
) -> None:
    """Send bid rejection email to the sponsor."""
    try:
        html = await tpl.sponsor_bid_rejected_template(
            event_title=event_title,
            category_name=category_name,
            bid_amount_cents=bid_amount_cents,
        )
        await send_email(sponsor_email, sponsor_name, f"Bid Not Accepted — {event_title}", html)
    except Exception:
        logger.exception("notify_sponsor_bid_rejected failed for %s", sponsor_email)


# ═══════════════════════════════════════════════════════════
# 10. Sponsor Payment Refunded
# ═══════════════════════════════════════════════════════════

async def notify_sponsor_refund(
    *,
    sponsor_email: str,
    sponsor_name: str,
    event_title: str,
    category_name: str,
    refunded_cents: int,
    receipt_number: str | None = None,
) -> None:
    """Send sponsorship refund confirmation to the sponsor."""
    try:
        html = await tpl.sponsor_refund_template(
            event_title=event_title,
            category_name=category_name,
            refunded_cents=refunded_cents,
            receipt_number=receipt_number,
        )
        await send_email(sponsor_email, sponsor_name, f"Sponsorship Refunded — {event_title}", html)
    except Exception:
        logger.exception("notify_sponsor_refund failed for %s", sponsor_email)
