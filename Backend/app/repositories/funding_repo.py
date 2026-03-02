"""
Funding / pledge data-access layer.

All SQLAlchemy queries for the funding domain live here.
Services must call these methods instead of db.execute() directly.
"""
from datetime import datetime, timezone
from typing import Sequence

from sqlalchemy import func, select, text, update
from sqlalchemy import or_ as sql_or
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.event import Event, EventStatus
from app.models.funding import Funding, FundingStatus, PledgeSpotReservation
from app.models.milestone import (
    EarlyBirdDiscount,
    FundingMilestone,
    FundingMilestoneSnapshot,
    FundingMilestoneUser,
)
from app.models.event import EventDiscount
from app.models.registration import Registration, RegistrationStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
from app.models.user import User
from app.repositories.base import BaseRepository


_MY_PLEDGES_SORT = {
    "newest": Funding.created_at.desc(),
    "oldest": Funding.created_at.asc(),
    "amount_high": Funding.amount_cents.desc(),
    "amount_low": Funding.amount_cents.asc(),
}


class FundingRepository(BaseRepository[Funding]):
    model_class = Funding

    # ── Advisory lock ───────────────────────────────────────────────

    async def advisory_lock(self, db: AsyncSession, event_id: int) -> None:
        await db.execute(text("SELECT pg_advisory_xact_lock(:eid)"), {"eid": event_id})

    # ── Single-row lookups ──────────────────────────────────────────

    async def get_by_id_and_event(
        self, db: AsyncSession, funding_id: int, event_id: int
    ) -> Funding | None:
        result = await db.execute(
            select(Funding).where(Funding.id == funding_id, Funding.event_id == event_id)
        )
        return result.scalar_one_or_none()

    # ── Registration check (cross-domain read) ──────────────────────

    async def is_user_registered(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> bool:
        result = await db.execute(
            select(Registration).where(
                Registration.event_id == event_id,
                Registration.user_id == user_id,
                Registration.status == RegistrationStatus.registered,
            )
        )
        return result.scalar_one_or_none() is not None

    # ── Tier queries (cross-domain read for pledge validation) ──────

    async def get_tiers_for_event(
        self, db: AsyncSession, event_id: int
    ) -> list[TicketTier]:
        q = (
            select(TicketTier)
            .where(TicketTier.event_id == event_id)
            .order_by(TicketTier.display_order)
        )
        return list((await db.execute(q)).scalars().all())

    async def get_tiers_by_ids(
        self, db: AsyncSession, event_id: int, tier_ids: list[int]
    ) -> dict[int, TicketTier]:
        result = await db.execute(
            select(TicketTier).where(
                TicketTier.id.in_(tier_ids),
                TicketTier.event_id == event_id,
            )
        )
        return {t.id: t for t in result.scalars().all()}

    async def count_tickets_sold(self, db: AsyncSession, event_id: int) -> int:
        q = select(func.count()).where(
            TicketSale.event_id == event_id,
            TicketSale.status == TicketSaleStatus.purchased,
        )
        return int((await db.execute(q)).scalar_one())

    # ── Create / update ─────────────────────────────────────────────

    async def create_pledge(self, db: AsyncSession, pledge: Funding) -> Funding:
        db.add(pledge)
        await db.flush()
        await db.refresh(pledge)
        return pledge

    async def create_spot_reservations(
        self,
        db: AsyncSession,
        funding_id: int,
        tier_reservations: list[dict],
    ) -> None:
        for tr in tier_reservations:
            db.add(
                PledgeSpotReservation(
                    funding_id=funding_id,
                    ticket_tier_id=tr["tier_id"],
                    spots=tr["spots"],
                )
            )
        await db.flush()

    async def set_receipt_number(
        self, db: AsyncSession, pledge: Funding, event_id: int
    ) -> None:
        now = datetime.now(timezone.utc)
        pledge.receipt_number = f"PLG-{now.strftime('%Y%m%d')}-{event_id}-{pledge.id}"
        await db.flush()
        await db.refresh(pledge)

    async def set_early_bird(self, db: AsyncSession, pledge: Funding) -> None:
        pledge.is_early_bird = True
        await db.flush()

    # ── Early bird discount check ───────────────────────────────────

    async def get_early_bird_discount(
        self, db: AsyncSession, event_id: int
    ) -> EarlyBirdDiscount | None:
        q = select(EarlyBirdDiscount).where(
            EarlyBirdDiscount.event_id == event_id,
            EarlyBirdDiscount.applies_to == "funding",
        )
        return (await db.execute(q)).scalar_one_or_none()

    # ── Unpledge queries ────────────────────────────────────────────

    async def get_refundable_pledges(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> list[Funding]:
        q = select(Funding).where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
            Funding.is_guest == False,  # noqa: E712
        )
        return list((await db.execute(q)).scalars().all())

    async def get_guest_pledged_total(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> int:
        q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
            Funding.is_guest == True,  # noqa: E712
        )
        return int((await db.execute(q)).scalar_one())

    async def mark_refund_processing(
        self, db: AsyncSession, pledges: list[Funding]
    ) -> None:
        for f in pledges:
            f.status = FundingStatus.refund_processing
        await db.flush()

    async def mark_refunded(self, db: AsyncSession, pledges: list[Funding]) -> None:
        for f in pledges:
            f.status = FundingStatus.refunded
        await db.flush()

    # ── Bulk refund ─────────────────────────────────────────────────

    async def bulk_refund_event(
        self, db: AsyncSession, event_id: int, *, guest_refund: bool = True
    ) -> int:
        conditions = [
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        ]
        if not guest_refund:
            conditions.append(Funding.is_guest == False)  # noqa: E712
        await db.execute(
            update(Funding).where(*conditions).values(status=FundingStatus.refund_processing)
        )
        result = await db.execute(
            update(Funding)
            .where(
                Funding.event_id == event_id,
                Funding.status == FundingStatus.refund_processing,
            )
            .values(status=FundingStatus.refunded)
        )
        return result.rowcount or 0

    async def bulk_refund_user_event(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> int:
        await db.execute(
            update(Funding)
            .where(
                Funding.event_id == event_id,
                Funding.user_id == user_id,
                Funding.status == FundingStatus.pledged,
            )
            .values(status=FundingStatus.refund_processing)
        )
        result = await db.execute(
            update(Funding)
            .where(
                Funding.event_id == event_id,
                Funding.user_id == user_id,
                Funding.status == FundingStatus.refund_processing,
            )
            .values(status=FundingStatus.refunded)
        )
        return result.rowcount or 0

    async def refund_single(
        self, db: AsyncSession, funding_id: int, event_id: int
    ) -> int:
        existing = await self.get_by_id_and_event(db, funding_id, event_id)
        if not existing:
            return 0
        if existing.status in (FundingStatus.refunded, FundingStatus.refund_processing):
            return 1
        result = await db.execute(
            update(Funding)
            .where(
                Funding.id == funding_id,
                Funding.event_id == event_id,
                Funding.status == FundingStatus.pledged,
            )
            .values(status=FundingStatus.refunded)
        )
        return result.rowcount or 0

    # ── List queries ────────────────────────────────────────────────

    async def list_by_user(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        offset: int = 0,
        limit: int = 20,
        sort_by: str = "newest",
    ) -> Sequence[Funding]:
        q = (
            select(Funding)
            .where(Funding.user_id == user_id)
            .options(selectinload(Funding.event))
            .order_by(_MY_PLEDGES_SORT.get(sort_by, Funding.created_at.desc()))
            .offset(offset)
            .limit(limit)
        )
        return (await db.execute(q)).scalars().unique().all()

    async def list_organizer_pledges(
        self,
        db: AsyncSession,
        *,
        organizer_id: int,
        status_filter: str | None = None,
        event_status: str | None = None,
        genre: str | None = None,
        event_id: int | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> Sequence[Funding]:
        conditions = [Event.organizer_id == organizer_id]
        if event_status:
            try:
                conditions.append(Event.status == EventStatus(event_status))
            except ValueError:
                pass
        if genre:
            conditions.append(Event.genre == genre)
        if event_id:
            conditions.append(Event.id == event_id)
        if status_filter and status_filter != "all":
            if status_filter == "donation":
                conditions.append(Funding.is_guest == True)  # noqa: E712
            else:
                conditions.append(Funding.status == status_filter)
                conditions.append(Funding.is_guest == False)  # noqa: E712
        q = (
            select(Funding)
            .join(Event, Funding.event_id == Event.id)
            .where(*conditions)
            .options(selectinload(Funding.event), selectinload(Funding.user))
            .order_by(Funding.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().unique().all())

    async def list_all_admin(
        self,
        db: AsyncSession,
        *,
        offset: int = 0,
        limit: int = 20,
        search: str | None = None,
        status: str | None = None,
        is_donation: bool | None = None,
    ) -> tuple[Sequence[Funding], int]:
        base = select(Funding).join(Event, Funding.event_id == Event.id)
        if status:
            try:
                base = base.where(Funding.status == FundingStatus(status))
            except ValueError:
                pass
        if is_donation is True:
            base = base.where(Funding.is_guest == True)  # noqa: E712
        elif is_donation is False:
            base = base.where(Funding.is_guest == False)  # noqa: E712
        if search:
            pattern = f"%{search}%"
            base = base.outerjoin(User, Funding.user_id == User.id).where(
                sql_or(Event.title.ilike(pattern), User.display_name.ilike(pattern))
            )
        count_q = select(func.count()).select_from(base.subquery())
        total = (await db.execute(count_q)).scalar_one()
        q = (
            base.options(selectinload(Funding.event), selectinload(Funding.user))
            .order_by(Funding.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return list((await db.execute(q)).scalars().unique().all()), int(total)

    # ── Reservation queries ─────────────────────────────────────────

    async def get_user_reserved_spots(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> int:
        q = select(func.coalesce(func.sum(Funding.reserved_spots), 0)).where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(q)).scalar_one())

    async def get_total_reserved_spots(
        self, db: AsyncSession, event_id: int
    ) -> int:
        q = select(func.coalesce(func.sum(Funding.reserved_spots), 0)).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(q)).scalar_one())

    async def get_total_reserved_spots_for_events(
        self, db: AsyncSession, event_ids: list[int]
    ) -> dict[int, int]:
        if not event_ids:
            return {}
        q = (
            select(
                Funding.event_id,
                func.coalesce(func.sum(Funding.reserved_spots), 0).label("total"),
            )
            .where(
                Funding.event_id.in_(event_ids),
                Funding.status == FundingStatus.pledged,
            )
            .group_by(Funding.event_id)
        )
        return {int(r.event_id): int(r.total) for r in (await db.execute(q)).all()}

    async def consume_one_reserved_spot(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> None:
        from app.core.exceptions import ConflictError

        q = (
            select(Funding)
            .where(
                Funding.event_id == event_id,
                Funding.user_id == user_id,
                Funding.status == FundingStatus.pledged,
                Funding.reserved_spots > 0,
            )
            .order_by(Funding.created_at.asc())
            .limit(1)
            .with_for_update()
        )
        pledge = (await db.execute(q)).scalar_one_or_none()
        if pledge is None:
            raise ConflictError("No reserved spots available to consume")
        pledge.reserved_spots -= 1
        await db.flush()

    async def get_reserved_spots_for_tiers(
        self, db: AsyncSession, event_id: int, tier_ids: list[int]
    ) -> dict[int, int]:
        if not tier_ids:
            return {}
        q = (
            select(
                PledgeSpotReservation.ticket_tier_id,
                func.coalesce(func.sum(PledgeSpotReservation.spots), 0).label("total"),
            )
            .join(Funding, PledgeSpotReservation.funding_id == Funding.id)
            .where(
                Funding.event_id == event_id,
                Funding.status == FundingStatus.pledged,
                PledgeSpotReservation.ticket_tier_id.in_(tier_ids),
            )
            .group_by(PledgeSpotReservation.ticket_tier_id)
        )
        return {int(r.ticket_tier_id): int(r.total) for r in (await db.execute(q)).all()}

    async def get_reserved_spots_for_tier(
        self, db: AsyncSession, event_id: int, tier_id: int
    ) -> int:
        q = (
            select(func.coalesce(func.sum(PledgeSpotReservation.spots), 0))
            .join(Funding, PledgeSpotReservation.funding_id == Funding.id)
            .where(
                Funding.event_id == event_id,
                Funding.status == FundingStatus.pledged,
                PledgeSpotReservation.ticket_tier_id == tier_id,
            )
        )
        return int((await db.execute(q)).scalar_one())

    async def get_user_reserved_spots_for_tier(
        self, db: AsyncSession, event_id: int, user_id: int, tier_id: int
    ) -> int:
        q = (
            select(func.coalesce(func.sum(PledgeSpotReservation.spots), 0))
            .join(Funding, PledgeSpotReservation.funding_id == Funding.id)
            .where(
                Funding.event_id == event_id,
                Funding.user_id == user_id,
                Funding.status == FundingStatus.pledged,
                PledgeSpotReservation.ticket_tier_id == tier_id,
            )
        )
        return int((await db.execute(q)).scalar_one())

    async def consume_reserved_spots_for_tier(
        self, db: AsyncSession, event_id: int, user_id: int, tier_id: int, count: int
    ) -> None:
        remaining = count
        q = (
            select(PledgeSpotReservation)
            .join(Funding, PledgeSpotReservation.funding_id == Funding.id)
            .where(
                Funding.event_id == event_id,
                Funding.user_id == user_id,
                Funding.status == FundingStatus.pledged,
                PledgeSpotReservation.ticket_tier_id == tier_id,
                PledgeSpotReservation.spots > 0,
            )
            .order_by(Funding.created_at.asc())
            .with_for_update()
        )
        rows = list((await db.execute(q)).scalars().all())
        for row in rows:
            if remaining <= 0:
                break
            take = min(remaining, row.spots)
            row.spots -= take
            remaining -= take
            pledge = await db.get(Funding, row.funding_id)
            if pledge:
                pledge.reserved_spots = max(0, pledge.reserved_spots - take)
        await db.flush()

    # ── Summary / aggregate queries ─────────────────────────────────

    async def get_total_pledged(self, db: AsyncSession, event_id: int) -> int:
        q = select(func.coalesce(func.sum(Funding.amount_cents), 0)).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(q)).scalar_one())

    async def get_total_platform_cut(self, db: AsyncSession, event_id: int) -> int:
        q = select(func.coalesce(func.sum(Funding.platform_cut_cents), 0)).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(q)).scalar_one())

    async def get_total_net_to_organizer(self, db: AsyncSession, event_id: int) -> int:
        q = select(func.coalesce(func.sum(Funding.net_to_organizer_cents), 0)).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(q)).scalar_one())

    async def get_backers_count(self, db: AsyncSession, event_id: int) -> int:
        q = select(func.count(func.distinct(Funding.user_id))).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        )
        return int((await db.execute(q)).scalar_one())

    async def get_pledged_totals_for_events(
        self, db: AsyncSession, event_ids: list[int]
    ) -> dict[int, int]:
        if not event_ids:
            return {}
        q = (
            select(
                Funding.event_id,
                func.coalesce(func.sum(Funding.amount_cents), 0).label("total"),
            )
            .where(
                Funding.event_id.in_(event_ids),
                Funding.status == FundingStatus.pledged,
            )
            .group_by(Funding.event_id)
        )
        return {int(r.event_id): int(r.total) for r in (await db.execute(q)).all()}

    # ── Milestone queries ───────────────────────────────────────────

    async def get_event_discounts_for_milestones(
        self, db: AsyncSession, event_id: int
    ) -> list[EventDiscount]:
        q = select(EventDiscount).where(
            EventDiscount.event_id == event_id,
            EventDiscount.discount_type == "funding_milestone",
            EventDiscount.milestone_percent.isnot(None),
        )
        return list((await db.execute(q)).scalars().all())

    async def get_funding_milestones(
        self, db: AsyncSession, event_id: int
    ) -> list[FundingMilestone]:
        q = select(FundingMilestone).where(FundingMilestone.event_id == event_id)
        return list((await db.execute(q)).scalars().all())

    async def get_existing_snapshot_percents(
        self, db: AsyncSession, event_id: int
    ) -> set[int]:
        q = select(FundingMilestoneSnapshot.milestone_percent).where(
            FundingMilestoneSnapshot.event_id == event_id,
        )
        return set((await db.execute(q)).scalars().all())

    async def get_pledger_ids(self, db: AsyncSession, event_id: int) -> list[int]:
        q = select(func.distinct(Funding.user_id)).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.pledged,
        )
        return list((await db.execute(q)).scalars().all())

    async def create_milestone_snapshot(
        self,
        db: AsyncSession,
        event_id: int,
        milestone_percent: int,
        pledger_ids: list[int],
    ) -> None:
        snapshot = FundingMilestoneSnapshot(
            event_id=event_id,
            milestone_percent=milestone_percent,
        )
        db.add(snapshot)
        await db.flush()
        await db.refresh(snapshot)
        for uid in pledger_ids:
            db.add(FundingMilestoneUser(snapshot_id=snapshot.id, user_id=uid))
        await db.flush()


    # ── Refund retry helpers ────────────────────────────────────────

    async def get_funding_by_id(
        self, db: AsyncSession, funding_id: int
    ) -> Funding | None:
        q = select(Funding).where(Funding.id == funding_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def list_refund_failed_ids(
        self, db: AsyncSession, event_id: int
    ) -> list[int]:
        q = select(Funding.id).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.refund_failed,
        )
        return list((await db.execute(q)).scalars().all())

    async def count_refund_failed(
        self, db: AsyncSession, event_id: int
    ) -> int:
        q = select(func.count()).select_from(Funding).where(
            Funding.event_id == event_id,
            Funding.status == FundingStatus.refund_failed,
        )
        return int((await db.execute(q)).scalar_one())

    async def flush(self, db: AsyncSession) -> None:
        await db.flush()


# Module-level singleton
funding_repo = FundingRepository()
