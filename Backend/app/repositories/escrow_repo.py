"""
Escrow data-access layer.

Shared and type-specific SQLAlchemy queries for fund, ticket, and sponsor
escrow records. Services must call these methods instead of db.execute()
directly.
"""
from sqlalchemy import func, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.escrow import (
    EscrowRelease,
    EscrowStatus,
    FundEscrow,
    SponsorEscrow,
    TicketEscrow,
)
from app.models.event import Event
from app.models.funding import Funding, FundingStatus
from app.models.payment_info import OrganizerBankAccount
from app.models.ticket import TicketSale, TicketSaleStatus
from app.models.user import User, UserRole


class EscrowRepository:
    """Pure data-access for all escrow types."""

    # ===================================================================
    #  Generic helpers (any escrow model)
    # ===================================================================

    async def get_escrow_by_event(self, db: AsyncSession, model_class, event_id: int):
        """Return the escrow record for (model_class, event_id) or None."""
        q = select(model_class).where(model_class.event_id == event_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def upsert_escrow(
        self, db: AsyncSession, model_class, *, event_id: int, total_held_cents: int
    ):
        """Insert-on-conflict-do-nothing, flush, and return the escrow."""
        stmt = pg_insert(model_class).values(
            event_id=event_id, total_held_cents=total_held_cents,
        ).on_conflict_do_nothing(index_elements=["event_id"])
        await db.execute(stmt)
        await db.flush()
        q = select(model_class).where(model_class.event_id == event_id)
        return (await db.execute(q)).scalar_one()

    async def flush(self, db: AsyncSession) -> None:
        """Flush pending changes."""
        await db.flush()

    async def flush_and_refresh(self, db: AsyncSession, obj) -> None:
        """Flush and refresh a model instance."""
        await db.flush()
        await db.refresh(obj)

    async def add_release_log(self, db: AsyncSession, log: EscrowRelease) -> None:
        """Add an escrow release log entry."""
        db.add(log)

    # ===================================================================
    #  Paginated list (admin view)
    # ===================================================================

    async def list_all_admin(
        self,
        db: AsyncSession,
        model_class,
        *,
        offset: int = 0,
        limit: int = 20,
        search: str | None = None,
    ) -> tuple[list, int]:
        """Paginated list of escrows with event + organizer info. Returns (rows, total)."""
        base = (
            select(
                model_class,
                Event.title.label("event_title"),
                User.display_name.label("organizer_name"),
                User.email.label("organizer_email"),
            )
            .join(Event, model_class.event_id == Event.id)
            .join(User, Event.organizer_id == User.id)
        )
        if search:
            filters = [Event.title.ilike(f"%{search}%")]
            try:
                filters.append(model_class.event_id == int(search))
            except ValueError:
                pass
            base = base.where(or_(*filters))

        total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar_one()
        rows = (await db.execute(
            base.order_by(model_class.updated_at.desc()).offset(offset).limit(limit)
        )).all()

        return rows, int(total)

    # ===================================================================
    #  Bank account / organizer helpers
    # ===================================================================

    async def organizer_has_verified_bank(self, db: AsyncSession, organizer_id: int) -> bool:
        """True if the organizer has a bank account with verified == True."""
        q = select(OrganizerBankAccount).where(
            OrganizerBankAccount.user_id == organizer_id,
            OrganizerBankAccount.verified == True,  # noqa: E712
        )
        return (await db.execute(q)).scalar_one_or_none() is not None

    async def get_organizer_for_event(self, db: AsyncSession, event_id: int) -> int | None:
        """Return the organizer_id for a given event, or None."""
        q = select(Event.organizer_id).where(Event.id == event_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def get_all_admin_ids(self, db: AsyncSession) -> list[int]:
        """Return IDs of all admin users."""
        q = select(User.id).where(User.role == UserRole.admin)
        return list((await db.execute(q)).scalars().all())

    async def has_active_escrow(self, db: AsyncSession, organizer_id: int) -> bool:
        """True if organizer has any event with escrow in holding/partially_released."""
        from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow

        event_ids_q = select(Event.id).where(Event.organizer_id == organizer_id)
        for model in (FundEscrow, TicketEscrow, SponsorEscrow):
            q = select(func.count()).select_from(model).where(
                model.event_id.in_(event_ids_q),
                model.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]),
            )
            if (await db.execute(q)).scalar_one() > 0:
                return True
        return False

    # ===================================================================
    #  Fund escrow specifics
    # ===================================================================

    async def calc_fund_total(self, db: AsyncSession, event_id: int) -> int:
        """Sum of pledged fundings net_to_organizer_cents for the event."""
        total_q = select(func.coalesce(func.sum(Funding.net_to_organizer_cents), 0)).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(total_q)).scalar_one())

    async def get_event_by_id(self, db: AsyncSession, event_id: int):
        """Fetch an Event by id."""
        return (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()

    # ===================================================================
    #  Ticket escrow specifics
    # ===================================================================

    async def calc_ticket_total(self, db: AsyncSession, event_id: int) -> int:
        """Sum of net ticket revenue (amount_paid - commission) for purchased tickets."""
        result = (await db.execute(
            select(func.coalesce(
                func.sum(TicketSale.amount_paid_cents - TicketSale.commission_cents), 0
            )).where(
                TicketSale.event_id == event_id,
                TicketSale.status == TicketSaleStatus.purchased,
            )
        )).scalar_one()
        return int(result)

    # ===================================================================
    #  Sponsor escrow specifics
    # ===================================================================

    async def calc_sponsor_total(self, db: AsyncSession, event_id: int) -> int:
        """Sum of net sponsor payments for this event."""
        from app.models.sponsor import SponsorBid, SponsorPayment, SponsorshipCategory, PaymentStatus

        result = (await db.execute(
            select(func.coalesce(func.sum(SponsorPayment.net_to_organizer_cents), 0))
            .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorshipCategory.event_id == event_id,
                SponsorPayment.status == PaymentStatus.completed,
            )
        )).scalar_one()
        return int(result)

    # ===================================================================
    #  Ticket count helpers (used by auto-triggers)
    # ===================================================================

    async def count_purchased_tickets(self, db: AsyncSession, event_id: int) -> int:
        """Count purchased tickets for an event."""
        return int((await db.execute(
            select(func.count()).select_from(TicketSale).where(
                TicketSale.event_id == event_id,
                TicketSale.status == TicketSaleStatus.purchased,
            )
        )).scalar_one())

    async def count_scanned_tickets(self, db: AsyncSession, event_id: int) -> int:
        """Count purchased + scanned tickets for an event."""
        return int((await db.execute(
            select(func.count()).select_from(TicketSale).where(
                TicketSale.event_id == event_id,
                TicketSale.status == TicketSaleStatus.purchased,
                TicketSale.scanned_at.isnot(None),
            )
        )).scalar_one())

    async def count_sold_and_refunded_tickets(
        self, db: AsyncSession, event_id: int
    ) -> tuple[int, int]:
        """Return (total_sold, total_refunds) for ticket escrow stage 2 check."""
        total_sold = int((await db.execute(
            select(func.count()).select_from(TicketSale).where(
                TicketSale.event_id == event_id,
                TicketSale.status.in_([
                    TicketSaleStatus.purchased,
                    TicketSaleStatus.refunded,
                    TicketSaleStatus.refund_processing,
                ]),
            )
        )).scalar_one())
        total_refunds = int((await db.execute(
            select(func.count()).select_from(TicketSale).where(
                TicketSale.event_id == event_id,
                TicketSale.status.in_([
                    TicketSaleStatus.refunded,
                    TicketSaleStatus.refund_processing,
                ]),
            )
        )).scalar_one())
        return total_sold, total_refunds

    async def count_open_disputes(self, db: AsyncSession, event_id: int) -> int:
        """Count open/evidence_submitted disputes for an event."""
        from app.models.dispute import Dispute, DisputeStatus

        return int((await db.execute(
            select(func.count()).select_from(Dispute).where(
                Dispute.event_id == event_id,
                Dispute.status.in_([DisputeStatus.open, DisputeStatus.evidence_submitted]),
            )
        )).scalar_one())

    # ═══════════════════════════════════════════════════════════════════
    #  Dispute
    # ═══════════════════════════════════════════════════════════════════

    async def get_dispute_by_stripe_id(
        self, db: AsyncSession, stripe_dispute_id: str,
    ):
        from app.models.dispute import Dispute
        q = select(Dispute).where(Dispute.stripe_dispute_id == stripe_dispute_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def create_dispute(self, db: AsyncSession, dispute) -> None:
        db.add(dispute)
        await db.flush()

    async def freeze_escrows_for_event(self, db: AsyncSession, event_id: int) -> None:
        """Freeze all escrow types for an event."""
        from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow
        for model in (FundEscrow, TicketEscrow, SponsorEscrow):
            esc = (await db.execute(
                select(model).where(model.event_id == event_id)
            )).scalar_one_or_none()
            if esc and esc.status not in (EscrowStatus.frozen, EscrowStatus.fully_released):
                esc.status = EscrowStatus.frozen

    async def unfreeze_escrows_for_event(self, db: AsyncSession, event_id: int) -> None:
        """Unfreeze all escrow types for an event."""
        from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow
        for model in (FundEscrow, TicketEscrow, SponsorEscrow):
            esc = (await db.execute(
                select(model).where(model.event_id == event_id)
            )).scalar_one_or_none()
            if esc and esc.status == EscrowStatus.frozen:
                if esc.stage3_released_at:
                    esc.status = EscrowStatus.fully_released
                elif esc.stage1_released_at:
                    esc.status = EscrowStatus.partially_released
                else:
                    esc.status = EscrowStatus.holding

    async def get_all_escrows_for_event(self, db: AsyncSession, event_id: int) -> dict:
        """Return {fund, ticket, sponsor} escrow records for an event."""
        from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow
        fund = (await db.execute(select(FundEscrow).where(FundEscrow.event_id == event_id))).scalar_one_or_none()
        ticket = (await db.execute(select(TicketEscrow).where(TicketEscrow.event_id == event_id))).scalar_one_or_none()
        sponsor = (await db.execute(select(SponsorEscrow).where(SponsorEscrow.event_id == event_id))).scalar_one_or_none()
        return {"fund": fund, "ticket": ticket, "sponsor": sponsor}

    async def flush(self, db: AsyncSession) -> None:
        await db.flush()

    async def flush_and_refresh(self, db: AsyncSession, obj) -> None:
        await db.flush()
        await db.refresh(obj)

    # ── Worker task helpers ────────────────────────────────────────

    async def get_escrow_by_type_and_id(
        self, db: AsyncSession, escrow_type: str, escrow_id: int,
    ):
        """Get an escrow record by type ('fund'/'ticket'/'sponsor') and primary key."""
        model_map = {
            "fund": FundEscrow,
            "ticket": TicketEscrow,
            "sponsor": SponsorEscrow,
        }
        model = model_map.get(escrow_type)
        if not model:
            return None
        q = select(model).where(model.id == escrow_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def get_active_ticket_escrow_event_ids(self, db: AsyncSession) -> list[int]:
        """Event IDs with active ticket escrows (holding or partially_released)."""
        q = select(TicketEscrow.event_id).where(
            TicketEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released])
        )
        return list((await db.execute(q)).scalars().all())

    async def get_active_sponsor_escrow_event_ids(self, db: AsyncSession) -> list[int]:
        """Event IDs with active sponsor escrows (holding or partially_released)."""
        q = select(SponsorEscrow.event_id).where(
            SponsorEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released])
        )
        return list((await db.execute(q)).scalars().all())


# Module-level singleton
escrow_repo = EscrowRepository()
