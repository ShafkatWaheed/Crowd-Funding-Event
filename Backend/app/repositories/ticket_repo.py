"""
Ticket data-access layer.

All SQLAlchemy queries for tickets, tiers, waitlist, refunds, and pricing
live here.  Services must call these methods instead of db.execute() directly.
"""
from typing import Sequence

from sqlalchemy import func, select, text, update
from sqlalchemy import or_ as sql_or
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.discount_strategy import CustomerDiscountClaim, EventDiscountStrategyLink
from app.models.event import Event, EventDiscount, EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.milestone import EarlyBirdDiscount, FundingMilestoneSnapshot, FundingMilestoneUser
from app.models.registration import Registration, RegistrationStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier, UserEventDiscount
from app.models.user import User
from app.repositories.base import BaseRepository


# ── Sort maps ────────────────────────────────────────────────────────

_MY_TICKETS_SORT = {
    "newest": TicketSale.created_at.desc(),
    "oldest": TicketSale.created_at.asc(),
    "price_high": TicketSale.amount_paid_cents.desc(),
    "price_low": TicketSale.amount_paid_cents.asc(),
}


class TicketRepository(BaseRepository[TicketSale]):
    model_class = TicketSale

    # ═══════════════════════════════════════════════════════════════════
    #  Advisory lock
    # ═══════════════════════════════════════════════════════════════════

    async def advisory_lock(self, db: AsyncSession, event_id: int) -> None:
        await db.execute(text("SELECT pg_advisory_xact_lock(:eid)"), {"eid": event_id})

    # ═══════════════════════════════════════════════════════════════════
    #  Registration check (used by purchase flow)
    # ═══════════════════════════════════════════════════════════════════

    async def get_active_registration(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> Registration | None:
        q = select(Registration).where(
            Registration.event_id == event_id,
            Registration.user_id == user_id,
            Registration.status == RegistrationStatus.registered,
        )
        return (await db.execute(q)).scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════════
    #  Ticket sale CRUD
    # ═══════════════════════════════════════════════════════════════════

    async def create_sale(self, db: AsyncSession, sale: TicketSale) -> TicketSale:
        db.add(sale)
        await db.flush()
        await db.refresh(sale)
        return sale

    async def set_receipt_number(self, db: AsyncSession, sale: TicketSale, receipt_number: str) -> None:
        sale.receipt_number = receipt_number
        await db.flush()
        await db.refresh(sale)

    async def update_sale_status(
        self, db: AsyncSession, sale: TicketSale, new_status: TicketSaleStatus
    ) -> TicketSale:
        sale.status = new_status
        await db.flush()
        await db.refresh(sale)
        return sale

    async def mark_scanned(
        self, db: AsyncSession, sale: TicketSale, scanned_at, scanned_by_id: int
    ) -> None:
        sale.scanned_at = scanned_at
        sale.scanned_by_id = scanned_by_id
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Ticket sale lookups
    # ═══════════════════════════════════════════════════════════════════

    async def get_sale_with_relations(
        self, db: AsyncSession, sale_id: int
    ) -> TicketSale | None:
        q = (
            select(TicketSale)
            .where(TicketSale.id == sale_id)
            .options(
                selectinload(TicketSale.event),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.user),
            )
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def get_sale_for_event(
        self, db: AsyncSession, sale_id: int, event_id: int
    ) -> TicketSale | None:
        q = (
            select(TicketSale)
            .where(TicketSale.id == sale_id, TicketSale.event_id == event_id)
            .options(
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.event),
            )
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def get_sale_for_user(
        self, db: AsyncSession, sale_id: int, event_id: int, user_id: int
    ) -> TicketSale | None:
        q = (
            select(TicketSale)
            .where(
                TicketSale.id == sale_id,
                TicketSale.event_id == event_id,
                TicketSale.user_id == user_id,
            )
            .options(
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.event),
            )
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def get_sale_by_code(
        self, db: AsyncSession, event_id: int, ticket_code: str
    ) -> TicketSale | None:
        q = (
            select(TicketSale)
            .where(
                TicketSale.event_id == event_id,
                TicketSale.ticket_code == ticket_code.strip(),
                TicketSale.status == TicketSaleStatus.purchased,
            )
            .options(
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.event),
            )
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def reload_with_scanned_by(self, db: AsyncSession, sale_id: int) -> TicketSale:
        q = (
            select(TicketSale)
            .where(TicketSale.id == sale_id)
            .options(
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.event),
                selectinload(TicketSale.scanned_by),
            )
        )
        return (await db.execute(q)).scalar_one()

    async def load_sales_by_ids(
        self, db: AsyncSession, sale_ids: list[int]
    ) -> list[TicketSale]:
        q = (
            select(TicketSale)
            .where(TicketSale.id.in_(sale_ids))
            .options(
                selectinload(TicketSale.event),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.user),
            )
            .order_by(TicketSale.id.asc())
        )
        return list((await db.execute(q)).scalars().unique().all())

    async def get_purchase_group_sales(
        self, db: AsyncSession, purchase_group_id: str
    ) -> list[TicketSale]:
        q = (
            select(TicketSale)
            .where(TicketSale.purchase_group_id == purchase_group_id)
            .options(
                selectinload(TicketSale.event),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.user),
            )
            .order_by(TicketSale.id.asc())
        )
        return list((await db.execute(q)).scalars().unique().all())

    # ═══════════════════════════════════════════════════════════════════
    #  Aggregates
    # ═══════════════════════════════════════════════════════════════════

    async def count_purchased(self, db: AsyncSession, event_id: int) -> int:
        q = select(func.count()).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
        )
        return int((await db.execute(q)).scalar_one())

    async def count_scanned(self, db: AsyncSession, event_id: int) -> int:
        q = select(func.count()).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
            TicketSale.scanned_at.isnot(None),
        )
        return int((await db.execute(q)).scalar_one())

    async def get_sold_counts_for_events(
        self, db: AsyncSession, event_ids: list[int]
    ) -> dict[int, int]:
        if not event_ids:
            return {}
        q = (
            select(TicketSale.event_id, func.count().label("cnt"))
            .where(
                TicketSale.event_id.in_(event_ids),
                TicketSale.status == TicketSaleStatus.purchased,
            )
            .group_by(TicketSale.event_id)
        )
        result = await db.execute(q)
        return {int(row.event_id): int(row.cnt) for row in result.all()}

    # ═══════════════════════════════════════════════════════════════════
    #  List queries — customer
    # ═══════════════════════════════════════════════════════════════════

    async def list_my_tickets(
        self, db: AsyncSession, *, user_id: int, offset: int = 0, limit: int = 20,
        sort_by: str = "newest",
    ) -> Sequence[TicketSale]:
        q = (
            select(TicketSale)
            .where(
                TicketSale.user_id == user_id,
                TicketSale.status.in_([
                    TicketSaleStatus.purchased,
                    TicketSaleStatus.waitlisted,
                    TicketSaleStatus.refund_requested,
                    TicketSaleStatus.refund_processing,
                    TicketSaleStatus.refunded,
                    TicketSaleStatus.refund_failed,
                    TicketSaleStatus.cancelled,
                ]),
            )
            .options(
                selectinload(TicketSale.event),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.user),
            )
            .order_by(_MY_TICKETS_SORT.get(sort_by, TicketSale.created_at.desc()))
            .offset(offset)
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().unique().all())

    # ═══════════════════════════════════════════════════════════════════
    #  List queries — organizer / admin
    # ═══════════════════════════════════════════════════════════════════

    async def list_for_user_admin(
        self, db: AsyncSession, *, user_id: int, limit: int = 200,
    ) -> Sequence[TicketSale]:
        q = (
            select(TicketSale)
            .where(TicketSale.user_id == user_id)
            .options(
                selectinload(TicketSale.event),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.user),
            )
            .order_by(TicketSale.created_at.desc())
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().unique().all())

    async def list_event_sales(
        self, db: AsyncSession, *, event_id: int, offset: int = 0, limit: int = 20,
    ) -> Sequence[TicketSale]:
        q = (
            select(TicketSale)
            .where(TicketSale.event_id == event_id)
            .options(
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.scanned_by),
            )
            .order_by(TicketSale.scanned_at.desc().nulls_last(), TicketSale.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().unique().all())

    async def list_event_scanned_sales(
        self, db: AsyncSession, *, event_id: int, offset: int = 0, limit: int = 20,
    ) -> Sequence[TicketSale]:
        q = (
            select(TicketSale)
            .where(TicketSale.event_id == event_id, TicketSale.scanned_at.isnot(None))
            .options(
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.scanned_by),
            )
            .order_by(TicketSale.scanned_at.desc(), TicketSale.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().unique().all())

    async def list_organizer_sales(
        self, db: AsyncSession, *, organizer_id: int, scanned_only: bool = False,
        event_status: str | None = None, genre: str | None = None,
        event_id: int | None = None, offset: int = 0, limit: int = 20,
    ) -> Sequence[TicketSale]:
        conditions = [Event.organizer_id == organizer_id]
        if scanned_only:
            conditions.append(TicketSale.scanned_at.isnot(None))
        if event_status:
            try:
                conditions.append(Event.status == EventStatus(event_status))
            except ValueError:
                pass
        if genre:
            conditions.append(Event.genre == genre)
        if event_id:
            conditions.append(Event.id == event_id)
        q = (
            select(TicketSale)
            .join(Event, TicketSale.event_id == Event.id)
            .where(*conditions)
            .options(
                selectinload(TicketSale.event),
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.scanned_by),
            )
            .order_by(TicketSale.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().unique().all())

    async def list_organizer_refund_requests(
        self, db: AsyncSession, *, organizer_id: int,
        event_id: int | None = None, offset: int = 0, limit: int = 20,
    ) -> Sequence[TicketSale]:
        conditions = [
            Event.organizer_id == organizer_id,
            TicketSale.status == TicketSaleStatus.refund_requested,
        ]
        if event_id:
            conditions.append(Event.id == event_id)
        q = (
            select(TicketSale)
            .join(Event, TicketSale.event_id == Event.id)
            .where(*conditions)
            .options(
                selectinload(TicketSale.event),
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
            )
            .order_by(TicketSale.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().unique().all())

    async def list_all_for_admin(
        self, db: AsyncSession, *, offset: int = 0, limit: int = 20,
        search: str | None = None, status: str | None = None,
    ) -> tuple[Sequence[TicketSale], int]:
        base = select(TicketSale).join(Event, TicketSale.event_id == Event.id)
        if status:
            try:
                base = base.where(TicketSale.status == TicketSaleStatus(status))
            except ValueError:
                pass
        if search:
            pattern = f"%{search}%"
            base = base.outerjoin(User, TicketSale.user_id == User.id).where(
                sql_or(Event.title.ilike(pattern), User.display_name.ilike(pattern))
            )
        count_q = select(func.count()).select_from(base.subquery())
        total = (await db.execute(count_q)).scalar_one()
        q = (
            base
            .options(
                selectinload(TicketSale.event),
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
            )
            .order_by(TicketSale.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        res = await db.execute(q)
        return list(res.scalars().unique().all()), int(total)

    # ═══════════════════════════════════════════════════════════════════
    #  Waitlist
    # ═══════════════════════════════════════════════════════════════════

    async def list_event_waitlisted(
        self, db: AsyncSession, *, event_id: int
    ) -> Sequence[TicketSale]:
        q = (
            select(TicketSale)
            .where(TicketSale.event_id == event_id, TicketSale.status == TicketSaleStatus.waitlisted)
            .options(
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.scanned_by),
            )
            .order_by(TicketSale.created_at.asc())
        )
        return list((await db.execute(q)).scalars().unique().all())

    # ═══════════════════════════════════════════════════════════════════
    #  Refunds
    # ═══════════════════════════════════════════════════════════════════

    async def list_refund_requests(
        self, db: AsyncSession, *, event_id: int
    ) -> list[TicketSale]:
        q = (
            select(TicketSale)
            .where(
                TicketSale.event_id == event_id,
                TicketSale.status == TicketSaleStatus.refund_requested,
            )
            .options(
                selectinload(TicketSale.user),
                selectinload(TicketSale.ticket_tier),
                selectinload(TicketSale.event),
            )
            .order_by(TicketSale.created_at.desc())
        )
        return list((await db.execute(q)).scalars().all())

    async def bulk_mark_refund_processing(
        self, db: AsyncSession, event_id: int
    ) -> list[int]:
        await db.execute(
            update(TicketSale)
            .where(TicketSale.event_id == event_id, TicketSale.status == TicketSaleStatus.purchased)
            .values(status=TicketSaleStatus.refund_processing)
        )
        await db.flush()
        ids = (await db.execute(
            select(TicketSale.id).where(
                TicketSale.event_id == event_id,
                TicketSale.status == TicketSaleStatus.refund_processing,
            )
        )).scalars().all()
        return list(ids)

    # ═══════════════════════════════════════════════════════════════════
    #  Tier CRUD
    # ═══════════════════════════════════════════════════════════════════

    async def list_tiers(
        self, db: AsyncSession, *, event_id: int
    ) -> Sequence[TicketTier]:
        q = (
            select(TicketTier)
            .where(TicketTier.event_id == event_id)
            .order_by(TicketTier.display_order.asc(), TicketTier.id.asc())
        )
        return list((await db.execute(q)).scalars().all())

    async def get_tier(
        self, db: AsyncSession, *, event_id: int, tier_id: int
    ) -> TicketTier | None:
        q = select(TicketTier).where(
            TicketTier.id == tier_id,
            TicketTier.event_id == event_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def tier_has_sales(self, db: AsyncSession, tier_id: int) -> bool:
        result = await db.execute(
            select(func.count()).select_from(TicketSale).where(TicketSale.ticket_tier_id == tier_id)
        )
        return (result.scalar() or 0) > 0

    async def create_tier(self, db: AsyncSession, tier: TicketTier) -> TicketTier:
        db.add(tier)
        await db.flush()
        await db.refresh(tier)
        return tier

    async def update_tier(self, db: AsyncSession, tier: TicketTier) -> TicketTier:
        await db.flush()
        await db.refresh(tier)
        return tier

    async def delete_tier(self, db: AsyncSession, tier: TicketTier) -> None:
        await db.delete(tier)
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  User event discount (selective discount)
    # ═══════════════════════════════════════════════════════════════════

    async def get_user_event_discount(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> UserEventDiscount | None:
        q = select(UserEventDiscount).where(
            UserEventDiscount.event_id == event_id,
            UserEventDiscount.user_id == user_id,
        )
        return (await db.execute(q)).scalar_one_or_none()

    async def upsert_user_event_discount(
        self, db: AsyncSession, existing: UserEventDiscount | None,
        event_id: int, user_id: int, discount_type: str, value: int,
    ) -> UserEventDiscount:
        if existing:
            existing.discount_type = discount_type
            existing.value = value
            await db.flush()
            await db.refresh(existing)
            return existing
        ued = UserEventDiscount(
            event_id=event_id, user_id=user_id,
            discount_type=discount_type, value=value,
        )
        db.add(ued)
        await db.flush()
        await db.refresh(ued)
        return ued

    async def delete_user_event_discount(
        self, db: AsyncSession, ued: UserEventDiscount
    ) -> None:
        await db.delete(ued)
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Pricing queries (used by compute_ticket_price)
    # ═══════════════════════════════════════════════════════════════════

    async def get_user_pledged_total(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> int:
        q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(q)).scalar_one())

    async def get_event_discounts(
        self, db: AsyncSession, event_id: int
    ) -> list[EventDiscount]:
        q = select(EventDiscount).where(EventDiscount.event_id == event_id)
        return list((await db.execute(q)).scalars().all())

    async def get_discount_strategy_links(
        self, db: AsyncSession, event_id: int
    ) -> list[EventDiscountStrategyLink]:
        q = (
            select(EventDiscountStrategyLink)
            .options(selectinload(EventDiscountStrategyLink.strategy))
            .where(EventDiscountStrategyLink.event_id == event_id)
        )
        return list((await db.execute(q)).scalars().all())

    async def get_claimed_link_ids(
        self, db: AsyncSession, user_id: int, link_ids: list[int]
    ) -> set[int]:
        if not link_ids:
            return set()
        q = select(CustomerDiscountClaim.link_id).where(
            CustomerDiscountClaim.user_id == user_id,
            CustomerDiscountClaim.link_id.in_(link_ids),
        )
        return set((await db.execute(q)).scalars().all())

    async def get_user_milestone_snapshots(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> list[FundingMilestoneSnapshot]:
        q = (
            select(FundingMilestoneSnapshot)
            .join(FundingMilestoneUser, FundingMilestoneUser.snapshot_id == FundingMilestoneSnapshot.id)
            .where(
                FundingMilestoneSnapshot.event_id == event_id,
                FundingMilestoneUser.user_id == user_id,
            )
            .order_by(FundingMilestoneSnapshot.milestone_percent.desc())
        )
        return list((await db.execute(q)).scalars().unique().all())

    async def get_milestone_discounts(
        self, db: AsyncSession, event_id: int
    ) -> list[EventDiscount]:
        q = select(EventDiscount).where(
            EventDiscount.event_id == event_id,
            EventDiscount.discount_type == "funding_milestone",
            EventDiscount.milestone_percent.isnot(None),
        )
        return list((await db.execute(q)).scalars().all())

    async def get_early_bird_discounts(
        self, db: AsyncSession, event_id: int
    ) -> list[EarlyBirdDiscount]:
        q = select(EarlyBirdDiscount).where(EarlyBirdDiscount.event_id == event_id)
        return list((await db.execute(q)).scalars().all())

    async def has_early_bird_pledge(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> bool:
        q = select(func.count()).where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
            Funding.is_early_bird == True,  # noqa: E712
        )
        return int((await db.execute(q)).scalar_one()) > 0


    # ── Refund retry helpers ────────────────────────────────────────

    async def get_sale_by_id(
        self, db: AsyncSession, sale_id: int
    ) -> TicketSale | None:
        q = select(TicketSale).where(TicketSale.id == sale_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def list_refund_failed_ids(
        self, db: AsyncSession, event_id: int
    ) -> list[int]:
        q = select(TicketSale.id).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.refund_failed,
        )
        return list((await db.execute(q)).scalars().all())

    async def count_refund_failed(
        self, db: AsyncSession, event_id: int
    ) -> int:
        q = select(func.count()).select_from(TicketSale).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.refund_failed,
        )
        return int((await db.execute(q)).scalar_one())

    async def flush(self, db: AsyncSession) -> None:
        await db.flush()


# Module-level singleton
ticket_repo = TicketRepository()
