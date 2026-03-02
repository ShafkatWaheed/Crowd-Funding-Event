"""
Sponsor data-access layer.

All SQLAlchemy queries for sponsor profiles, categories, bids, payments,
tickets, delegates, prerequisites, and organizer queries live here.
Services must call these methods instead of db.execute() directly.
"""
from __future__ import annotations

from typing import Any, Sequence

from sqlalchemy import delete as sa_delete, distinct, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased, selectinload

from app.models.event import Event, EventStatus
from app.models.prerequisite import BidPrerequisiteUpload, CategoryPrerequisite
from app.models.sponsor import (
    BidStatus,
    PaymentStatus,
    SponsorBid,
    SponsorDelegate,
    SponsorPayment,
    SponsorProfile,
    SponsorTicket,
    SponsorshipCategory,
)
from app.models.user import User
from app.repositories.base import BaseRepository


class SponsorRepository(BaseRepository[SponsorBid]):
    model_class = SponsorBid

    # ═══════════════════════════════════════════════════════════════════
    #  Profile
    # ═══════════════════════════════════════════════════════════════════

    async def get_sponsor_profile(
        self, db: AsyncSession, user_id: int
    ) -> SponsorProfile | None:
        q = select(SponsorProfile).where(SponsorProfile.user_id == user_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def create_sponsor_profile(
        self, db: AsyncSession, profile: SponsorProfile
    ) -> SponsorProfile:
        db.add(profile)
        await db.flush()
        await db.refresh(profile)
        return profile

    async def update_sponsor_profile(
        self, db: AsyncSession, profile: SponsorProfile
    ) -> SponsorProfile:
        await db.flush()
        await db.refresh(profile)
        return profile

    async def add_and_flush(self, db: AsyncSession, obj: Any) -> None:
        """Generic add + flush (e.g. for updating a User role)."""
        db.add(obj)
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Category
    # ═══════════════════════════════════════════════════════════════════

    async def get_category(
        self, db: AsyncSession, cat_id: int
    ) -> SponsorshipCategory | None:
        return (
            await db.execute(
                select(SponsorshipCategory).where(SponsorshipCategory.id == cat_id)
            )
        ).scalar_one_or_none()

    async def list_categories(
        self, db: AsyncSession, event_id: int
    ) -> list[SponsorshipCategory]:
        q = (
            select(SponsorshipCategory)
            .where(SponsorshipCategory.event_id == event_id)
            .order_by(SponsorshipCategory.sort_order, SponsorshipCategory.id)
        )
        return list((await db.execute(q)).scalars().all())

    async def create_category(
        self, db: AsyncSession, cat: SponsorshipCategory
    ) -> SponsorshipCategory:
        db.add(cat)
        await db.flush()
        await db.refresh(cat)
        return cat

    async def update_category(
        self, db: AsyncSession, cat: SponsorshipCategory
    ) -> SponsorshipCategory:
        await db.flush()
        await db.refresh(cat)
        return cat

    async def delete_category(
        self, db: AsyncSession, cat: SponsorshipCategory
    ) -> None:
        await db.delete(cat)
        await db.flush()

    async def get_event(
        self, db: AsyncSession, event_id: int
    ) -> Event | None:
        return (
            await db.execute(select(Event).where(Event.id == event_id))
        ).scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════════
    #  Template
    # ═══════════════════════════════════════════════════════════════════

    async def list_templates(
        self, db: AsyncSession, user_id: int
    ) -> list[SponsorshipCategory]:
        q = (
            select(SponsorshipCategory)
            .where(
                SponsorshipCategory.is_template == True,
                SponsorshipCategory.organizer_id == user_id,
            )
            .order_by(SponsorshipCategory.name)
        )
        return list((await db.execute(q)).scalars().all())

    async def get_template(
        self, db: AsyncSession, template_id: int
    ) -> SponsorshipCategory | None:
        return (
            await db.execute(
                select(SponsorshipCategory).where(
                    SponsorshipCategory.id == template_id,
                    SponsorshipCategory.is_template == True,
                )
            )
        ).scalar_one_or_none()

    async def create_template(
        self, db: AsyncSession, cat: SponsorshipCategory
    ) -> SponsorshipCategory:
        db.add(cat)
        await db.flush()
        await db.refresh(cat)
        return cat

    async def update_template(
        self, db: AsyncSession, cat: SponsorshipCategory
    ) -> SponsorshipCategory:
        await db.flush()
        await db.refresh(cat)
        return cat

    async def delete_template(
        self, db: AsyncSession, cat: SponsorshipCategory
    ) -> None:
        await db.delete(cat)
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Bid
    # ═══════════════════════════════════════════════════════════════════

    async def get_bid(
        self, db: AsyncSession, bid_id: int
    ) -> SponsorBid | None:
        return (
            await db.execute(select(SponsorBid).where(SponsorBid.id == bid_id))
        ).scalar_one_or_none()

    async def list_bids_for_category(
        self, db: AsyncSession, cat_id: int
    ) -> list[SponsorBid]:
        q = (
            select(SponsorBid)
            .where(SponsorBid.category_id == cat_id)
            .order_by(SponsorBid.amount_cents.desc())
        )
        return list((await db.execute(q)).scalars().all())

    async def count_active_bids_by_user(
        self,
        db: AsyncSession,
        cat_id: int,
        user_id: int,
        statuses: list[BidStatus] | None = None,
    ) -> list[SponsorBid]:
        """Return active bids for a user on a category (to count or inspect)."""
        if statuses is None:
            statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
        q = select(SponsorBid).where(
            SponsorBid.category_id == cat_id,
            SponsorBid.sponsor_user_id == user_id,
            SponsorBid.status.in_(statuses),
        )
        return list((await db.execute(q)).scalars().all())

    async def create_bid(
        self, db: AsyncSession, bid: SponsorBid
    ) -> SponsorBid:
        db.add(bid)
        await db.flush()
        await db.refresh(bid)
        return bid

    async def update_bid(self, db: AsyncSession, bid: SponsorBid) -> SponsorBid:
        await db.flush()
        await db.refresh(bid)
        return bid

    async def get_category_for_update(
        self, db: AsyncSession, cat_id: int
    ) -> SponsorshipCategory | None:
        """SELECT … FOR UPDATE on a category row (used during bid acceptance)."""
        return (
            await db.execute(
                select(SponsorshipCategory)
                .where(SponsorshipCategory.id == cat_id)
                .with_for_update()
            )
        ).scalar_one_or_none()

    async def advisory_lock(self, db: AsyncSession, lock_id: int) -> None:
        """Acquire a PostgreSQL transaction-scoped advisory lock."""
        await db.execute(
            text("SELECT pg_advisory_xact_lock(:lock_id)"),
            {"lock_id": lock_id},
        )

    async def flush_and_refresh_bid(
        self, db: AsyncSession, bid: SponsorBid
    ) -> SponsorBid:
        await db.flush()
        await db.refresh(bid)
        return bid

    # ═══════════════════════════════════════════════════════════════════
    #  Bid stats
    # ═══════════════════════════════════════════════════════════════════

    async def get_bid_stats(
        self, db: AsyncSession, cat_id: int
    ) -> list[SponsorBid]:
        """Return active bids (pending/accepted/paid) for a category."""
        q = select(SponsorBid).where(
            SponsorBid.category_id == cat_id,
            SponsorBid.status.in_([BidStatus.pending, BidStatus.accepted, BidStatus.paid]),
        )
        return list((await db.execute(q)).scalars().all())

    async def get_my_bids(
        self, db: AsyncSession, cat_id: int, user_id: int
    ) -> list[SponsorBid]:
        """Return non-withdrawn bids for a user on a category."""
        q = (
            select(SponsorBid)
            .where(
                SponsorBid.category_id == cat_id,
                SponsorBid.sponsor_user_id == user_id,
                SponsorBid.status != BidStatus.withdrawn,
            )
            .order_by(SponsorBid.id.desc())
        )
        return list((await db.execute(q)).scalars().all())

    # ═══════════════════════════════════════════════════════════════════
    #  Delegate
    # ═══════════════════════════════════════════════════════════════════

    async def get_sponsor_ticket_by_id(
        self, db: AsyncSession, ticket_id: int
    ) -> SponsorTicket | None:
        return (
            await db.execute(
                select(SponsorTicket).where(SponsorTicket.id == ticket_id)
            )
        ).scalar_one_or_none()

    async def list_delegates(
        self, db: AsyncSession, ticket_id: int
    ) -> list[SponsorDelegate]:
        q = (
            select(SponsorDelegate)
            .where(SponsorDelegate.sponsor_ticket_id == ticket_id)
            .order_by(SponsorDelegate.created_at.asc())
        )
        return list((await db.execute(q)).scalars().all())

    async def count_delegates(
        self, db: AsyncSession, ticket_id: int
    ) -> int:
        return int(
            (
                await db.execute(
                    select(func.count()).where(
                        SponsorDelegate.sponsor_ticket_id == ticket_id
                    )
                )
            ).scalar_one()
        )

    async def get_delegate_by_email(
        self, db: AsyncSession, ticket_id: int, email: str
    ) -> SponsorDelegate | None:
        return (
            await db.execute(
                select(SponsorDelegate).where(
                    SponsorDelegate.sponsor_ticket_id == ticket_id,
                    SponsorDelegate.email == email,
                )
            )
        ).scalar_one_or_none()

    async def get_delegate(
        self, db: AsyncSession, delegate_id: int
    ) -> SponsorDelegate | None:
        return (
            await db.execute(
                select(SponsorDelegate).where(SponsorDelegate.id == delegate_id)
            )
        ).scalar_one_or_none()

    async def add_delegate(
        self, db: AsyncSession, delegate: SponsorDelegate
    ) -> SponsorDelegate:
        db.add(delegate)
        await db.flush()
        return delegate

    async def remove_delegate(
        self, db: AsyncSession, delegate: SponsorDelegate
    ) -> None:
        await db.delete(delegate)
        await db.flush()

    async def flush(self, db: AsyncSession) -> None:
        """Flush pending session changes."""
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Payment
    # ═══════════════════════════════════════════════════════════════════

    async def get_payment_by_bid(
        self, db: AsyncSession, bid_id: int
    ) -> SponsorPayment | None:
        return (
            await db.execute(
                select(SponsorPayment).where(SponsorPayment.bid_id == bid_id)
            )
        ).scalar_one_or_none()

    async def create_sponsor_payment(
        self, db: AsyncSession, payment: SponsorPayment
    ) -> SponsorPayment:
        db.add(payment)
        await db.flush()
        await db.refresh(payment)
        return payment

    async def update_bid_status(
        self, db: AsyncSession, bid: SponsorBid
    ) -> SponsorBid:
        """Flush after modifying a bid's status."""
        await db.flush()
        await db.refresh(bid)
        return bid

    async def count_other_active_bids_for_event(
        self,
        db: AsyncSession,
        sponsor_user_id: int,
        event_id: int,
        exclude_bid_id: int,
    ) -> int:
        """Count accepted/paid bids by sponsor on an event, excluding one bid."""
        return int(
            (
                await db.execute(
                    select(func.count())
                    .select_from(SponsorBid)
                    .where(
                        SponsorBid.sponsor_user_id == sponsor_user_id,
                        SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid]),
                        SponsorBid.id != exclude_bid_id,
                        SponsorBid.category_id.in_(
                            select(SponsorshipCategory.id).where(
                                SponsorshipCategory.event_id == event_id
                            )
                        ),
                    )
                )
            ).scalar_one()
        )

    async def count_refunded_bids_for_event(
        self,
        db: AsyncSession,
        sponsor_user_id: int,
        event_id: int,
    ) -> int:
        """Count bids with refund_processing/refunded payments for an event."""
        return int(
            (
                await db.execute(
                    select(func.count())
                    .select_from(SponsorBid)
                    .join(SponsorPayment, SponsorPayment.bid_id == SponsorBid.id)
                    .where(
                        SponsorBid.sponsor_user_id == sponsor_user_id,
                        SponsorPayment.status.in_(
                            [PaymentStatus.refunded, PaymentStatus.refund_processing]
                        ),
                        SponsorBid.category_id.in_(
                            select(SponsorshipCategory.id).where(
                                SponsorshipCategory.event_id == event_id
                            )
                        ),
                    )
                )
            ).scalar_one()
        )

    async def delete_sponsor_tickets_for_event(
        self,
        db: AsyncSession,
        event_id: int,
        sponsor_user_id: int | None = None,
    ) -> None:
        """Delete sponsor tickets. If sponsor_user_id given, scope to that user."""
        conditions = [SponsorTicket.event_id == event_id]
        if sponsor_user_id is not None:
            conditions.append(SponsorTicket.sponsor_user_id == sponsor_user_id)
        await db.execute(sa_delete(SponsorTicket).where(*conditions))

    async def get_paid_bids_for_categories(
        self, db: AsyncSession, cat_ids: list[int]
    ) -> list[SponsorBid]:
        q = select(SponsorBid).where(
            SponsorBid.category_id.in_(cat_ids),
            SponsorBid.status == BidStatus.paid,
        )
        return list((await db.execute(q)).scalars().all())

    async def get_accepted_bids_for_categories(
        self, db: AsyncSession, cat_ids: list[int]
    ) -> list[SponsorBid]:
        q = select(SponsorBid).where(
            SponsorBid.category_id.in_(cat_ids),
            SponsorBid.status == BidStatus.accepted,
        )
        return list((await db.execute(q)).scalars().all())

    # ═══════════════════════════════════════════════════════════════════
    #  Sponsor Ticket
    # ═══════════════════════════════════════════════════════════════════

    async def get_sponsor_ticket(
        self, db: AsyncSession, event_id: int, sponsor_user_id: int
    ) -> SponsorTicket | None:
        return (
            await db.execute(
                select(SponsorTicket).where(
                    SponsorTicket.event_id == event_id,
                    SponsorTicket.sponsor_user_id == sponsor_user_id,
                )
            )
        ).scalar_one_or_none()

    async def list_sponsor_tickets(
        self, db: AsyncSession, sponsor_user_id: int
    ) -> list[SponsorTicket]:
        q = (
            select(SponsorTicket)
            .where(SponsorTicket.sponsor_user_id == sponsor_user_id)
            .options(selectinload(SponsorTicket.event).selectinload(Event.venue))
            .order_by(SponsorTicket.created_at.desc())
        )
        return list((await db.execute(q)).scalars().all())

    async def create_sponsor_ticket(
        self, db: AsyncSession, ticket: SponsorTicket
    ) -> SponsorTicket:
        db.add(ticket)
        await db.flush()
        await db.refresh(ticket)
        return ticket

    async def update_sponsor_ticket(
        self, db: AsyncSession, ticket: SponsorTicket
    ) -> SponsorTicket:
        await db.flush()
        await db.refresh(ticket)
        return ticket

    async def get_sponsor_ticket_with_delegates(
        self, db: AsyncSession, ticket_id: int
    ) -> SponsorTicket | None:
        return (
            await db.execute(
                select(SponsorTicket)
                .options(selectinload(SponsorTicket.delegates))
                .where(SponsorTicket.id == ticket_id)
            )
        ).scalar_one_or_none()

    async def get_won_category_rows(
        self, db: AsyncSession, event_id: int, sponsor_user_id: int
    ) -> Sequence:
        """Return (category_id, name, bid_id, amount_cents, status) rows."""
        q = (
            select(
                SponsorshipCategory.id,
                SponsorshipCategory.name,
                SponsorBid.id.label("bid_id"),
                SponsorBid.amount_cents,
                SponsorBid.status,
            )
            .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorshipCategory.event_id == event_id,
                SponsorBid.sponsor_user_id == sponsor_user_id,
                SponsorBid.status.in_(
                    [BidStatus.accepted, BidStatus.paid, BidStatus.rejected]
                ),
            )
        )
        return (await db.execute(q)).all()

    # ═══════════════════════════════════════════════════════════════════
    #  Prerequisite
    # ═══════════════════════════════════════════════════════════════════

    async def list_prerequisites(
        self, db: AsyncSession, category_id: int
    ) -> list[CategoryPrerequisite]:
        q = select(CategoryPrerequisite).where(
            CategoryPrerequisite.category_id == category_id
        )
        return list((await db.execute(q)).scalars().all())

    async def list_required_prerequisites(
        self, db: AsyncSession, category_id: int
    ) -> list[CategoryPrerequisite]:
        q = select(CategoryPrerequisite).where(
            CategoryPrerequisite.category_id == category_id,
            CategoryPrerequisite.is_required == True,
        )
        return list((await db.execute(q)).scalars().all())

    async def get_prerequisite(
        self, db: AsyncSession, prereq_id: int
    ) -> CategoryPrerequisite | None:
        return (
            await db.execute(
                select(CategoryPrerequisite).where(
                    CategoryPrerequisite.id == prereq_id
                )
            )
        ).scalar_one_or_none()

    async def get_prerequisite_for_category(
        self, db: AsyncSession, prereq_id: int, category_id: int
    ) -> CategoryPrerequisite | None:
        return (
            await db.execute(
                select(CategoryPrerequisite).where(
                    CategoryPrerequisite.id == prereq_id,
                    CategoryPrerequisite.category_id == category_id,
                )
            )
        ).scalar_one_or_none()

    async def create_prerequisite(
        self, db: AsyncSession, prereq: CategoryPrerequisite
    ) -> CategoryPrerequisite:
        db.add(prereq)
        await db.flush()
        await db.refresh(prereq)
        return prereq

    async def delete_prerequisite(
        self, db: AsyncSession, prereq: CategoryPrerequisite
    ) -> None:
        await db.delete(prereq)
        await db.flush()

    async def get_prereq_counts(
        self, db: AsyncSession, category_ids: list[int]
    ) -> dict[int, int]:
        """Return {category_id: count} for prerequisites."""
        if not category_ids:
            return {}
        q = (
            select(
                CategoryPrerequisite.category_id,
                func.count(CategoryPrerequisite.id),
            )
            .where(CategoryPrerequisite.category_id.in_(category_ids))
            .group_by(CategoryPrerequisite.category_id)
        )
        rows = (await db.execute(q)).all()
        return {cat_id: cnt for cat_id, cnt in rows}

    # ═══════════════════════════════════════════════════════════════════
    #  Prerequisite Uploads
    # ═══════════════════════════════════════════════════════════════════

    async def get_bid_prerequisite_upload(
        self, db: AsyncSession, bid_id: int, prereq_id: int
    ) -> BidPrerequisiteUpload | None:
        return (
            await db.execute(
                select(BidPrerequisiteUpload).where(
                    BidPrerequisiteUpload.bid_id == bid_id,
                    BidPrerequisiteUpload.prerequisite_id == prereq_id,
                )
            )
        ).scalar_one_or_none()

    async def list_bid_prerequisite_uploads(
        self, db: AsyncSession, bid_id: int
    ) -> list[BidPrerequisiteUpload]:
        q = select(BidPrerequisiteUpload).where(
            BidPrerequisiteUpload.bid_id == bid_id
        )
        return list((await db.execute(q)).scalars().all())

    async def create_prerequisite_upload(
        self, db: AsyncSession, upload: BidPrerequisiteUpload
    ) -> BidPrerequisiteUpload:
        db.add(upload)
        await db.flush()
        await db.refresh(upload)
        return upload

    async def update_prerequisite_upload(
        self, db: AsyncSession, upload: BidPrerequisiteUpload
    ) -> BidPrerequisiteUpload:
        await db.flush()
        await db.refresh(upload)
        return upload

    async def delete_prerequisite_upload(
        self, db: AsyncSession, upload: BidPrerequisiteUpload
    ) -> None:
        await db.delete(upload)
        await db.flush()

    # ═══════════════════════════════════════════════════════════════════
    #  Organizer Queries
    # ═══════════════════════════════════════════════════════════════════

    async def get_sponsor_bid_events(
        self, db: AsyncSession, sponsor_user_id: int
    ) -> list[Event]:
        """Distinct events where sponsor has active bids."""
        active_statuses = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
        event_ids_q = (
            select(distinct(SponsorshipCategory.event_id))
            .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorBid.sponsor_user_id == sponsor_user_id,
                SponsorBid.status.in_(active_statuses),
            )
        )
        q = (
            select(Event)
            .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
            .where(Event.id.in_(event_ids_q))
            .order_by(Event.created_at.desc())
        )
        return list((await db.execute(q)).scalars().all())

    async def get_sponsor_bids_detail_rows(
        self,
        db: AsyncSession,
        event_ids: list[int],
        sponsor_user_id: int,
    ) -> Sequence:
        """Return (event_id, cat_id, cat_name, bid_id, amount_cents, status) rows."""
        return (
            await db.execute(
                select(
                    SponsorshipCategory.event_id.label("event_id"),
                    SponsorshipCategory.id.label("cat_id"),
                    SponsorshipCategory.name.label("cat_name"),
                    SponsorBid.id.label("bid_id"),
                    SponsorBid.amount_cents,
                    SponsorBid.status,
                )
                .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
                .where(
                    SponsorshipCategory.event_id.in_(event_ids),
                    SponsorBid.sponsor_user_id == sponsor_user_id,
                    SponsorBid.status.in_(
                        [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
                    ),
                )
            )
        ).all()

    async def get_sponsor_bid_summary_rows(
        self,
        db: AsyncSession,
        event_id: int,
        sponsor_user_id: int,
    ) -> Sequence:
        """Return (status, bid_id) rows for summarisation."""
        q = (
            select(SponsorBid.status, SponsorBid.id)
            .join(
                SponsorshipCategory,
                SponsorBid.category_id == SponsorshipCategory.id,
            )
            .where(
                SponsorshipCategory.event_id == event_id,
                SponsorBid.sponsor_user_id == sponsor_user_id,
            )
        )
        return (await db.execute(q)).all()

    async def get_events_with_open_sponsorship(
        self,
        db: AsyncSession,
        sponsor_user_id: int | None = None,
        exclude_my_bids: bool = False,
    ) -> list[Event]:
        """Events with at least one category that has open spots."""
        open_cat_q = (
            select(distinct(SponsorshipCategory.event_id))
            .where(
                SponsorshipCategory.event_id.isnot(None),
                SponsorshipCategory.is_template == False,
                SponsorshipCategory.filled_spots < SponsorshipCategory.total_spots,
            )
        )
        if exclude_my_bids and sponsor_user_id:
            already_bid_event_ids = (
                select(distinct(SponsorshipCategory.event_id))
                .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
                .where(
                    SponsorBid.sponsor_user_id == sponsor_user_id,
                    SponsorBid.status.in_(
                        [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
                    ),
                )
            )
            open_cat_q = open_cat_q.where(
                SponsorshipCategory.event_id.notin_(already_bid_event_ids)
            )
        q = (
            select(Event)
            .options(
                selectinload(Event.venue),
                selectinload(Event.ticket_strategy),
                selectinload(Event.sponsorship_categories),
            )
            .where(
                Event.id.in_(open_cat_q),
                Event.status.notin_(["cancelled", "completed"]),
            )
            .order_by(Event.created_at.desc())
        )
        return list((await db.execute(q)).scalars().all())

    async def get_organizer_sponsor_rows(
        self,
        db: AsyncSession,
        organizer_id: int,
        *,
        event_status: str | None = None,
        genre: str | None = None,
        event_id: int | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> Sequence:
        """Return (sponsor_user_id, total_bids, total_amount_cents) rows."""
        active = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
        conditions: list = [
            Event.organizer_id == organizer_id,
            SponsorBid.status.in_(active),
        ]
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
            select(
                SponsorBid.sponsor_user_id,
                func.count(SponsorBid.id).label("total_bids"),
                func.sum(SponsorBid.amount_cents).label("total_amount_cents"),
            )
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .join(Event, SponsorshipCategory.event_id == Event.id)
            .where(*conditions)
            .group_by(SponsorBid.sponsor_user_id)
            .order_by(func.sum(SponsorBid.amount_cents).desc())
            .offset(offset)
            .limit(limit)
        )
        return (await db.execute(q)).all()

    async def get_sponsor_profiles_by_user_ids(
        self, db: AsyncSession, user_ids: list[int]
    ) -> dict[int, SponsorProfile]:
        if not user_ids:
            return {}
        profiles = (
            await db.execute(
                select(SponsorProfile).where(SponsorProfile.user_id.in_(user_ids))
            )
        ).scalars().all()
        return {p.user_id: p for p in profiles}

    async def get_users_by_ids(
        self, db: AsyncSession, user_ids: list[int]
    ) -> dict[int, User]:
        if not user_ids:
            return {}
        users = (
            await db.execute(select(User).where(User.id.in_(user_ids)))
        ).scalars().all()
        return {u.id: u for u in users}

    async def get_sponsor_events_for_organizer_events(
        self,
        db: AsyncSession,
        organizer_id: int,
        sponsor_user_id: int,
    ) -> list[Event]:
        """Events where a sponsor has active bids, for this organizer."""
        active = [BidStatus.pending, BidStatus.accepted, BidStatus.paid]
        event_ids_q = (
            select(distinct(SponsorshipCategory.event_id))
            .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
            .join(Event, SponsorshipCategory.event_id == Event.id)
            .where(
                Event.organizer_id == organizer_id,
                SponsorBid.sponsor_user_id == sponsor_user_id,
                SponsorBid.status.in_(active),
            )
        )
        return list(
            (
                await db.execute(
                    select(Event)
                    .options(
                        selectinload(Event.venue),
                        selectinload(Event.ticket_strategy),
                    )
                    .where(Event.id.in_(event_ids_q))
                    .order_by(Event.created_at.desc())
                )
            )
            .scalars()
            .all()
        )

    async def get_sponsor_bids_for_events(
        self,
        db: AsyncSession,
        event_ids: list[int],
        sponsor_user_id: int,
    ) -> Sequence:
        """Return (event_id, category_name, amount_cents, status) rows."""
        return (
            await db.execute(
                select(
                    SponsorshipCategory.event_id.label("event_id"),
                    SponsorshipCategory.name,
                    SponsorBid.amount_cents,
                    SponsorBid.status,
                )
                .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
                .where(
                    SponsorshipCategory.event_id.in_(event_ids),
                    SponsorBid.sponsor_user_id == sponsor_user_id,
                )
            )
        ).all()

    async def get_paid_sponsors(
        self, db: AsyncSession, event_id: int
    ) -> Sequence:
        """Return (sponsor_user_id, company_name, logo_url, website_url) rows."""
        q = (
            select(
                SponsorBid.sponsor_user_id,
                SponsorProfile.company_name,
                SponsorProfile.logo_url,
                SponsorProfile.website_url,
            )
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .join(SponsorProfile, SponsorBid.sponsor_user_id == SponsorProfile.user_id)
            .where(
                SponsorshipCategory.event_id == event_id,
                SponsorBid.status == BidStatus.paid,
            )
            .group_by(
                SponsorBid.sponsor_user_id,
                SponsorProfile.company_name,
                SponsorProfile.logo_url,
                SponsorProfile.website_url,
            )
        )
        return (await db.execute(q)).all()

    # ═══════════════════════════════════════════════════════════════════
    #  API-level helpers (used by organizer_views / templates routes)
    # ═══════════════════════════════════════════════════════════════════

    async def get_bid_for_category_by_sponsor(
        self,
        db: AsyncSession,
        cat_id: int,
        sponsor_user_id: int,
    ) -> SponsorBid | None:
        """Latest non-rejected bid for a sponsor on a category."""
        return (
            await db.execute(
                select(SponsorBid)
                .where(
                    SponsorBid.category_id == cat_id,
                    SponsorBid.sponsor_user_id == sponsor_user_id,
                    SponsorBid.status.notin_([BidStatus.rejected]),
                )
                .order_by(SponsorBid.created_at.desc())
            )
        ).scalars().first()


    # ── Refund retry helpers ────────────────────────────────────────

    async def get_payment_by_id(
        self, db: AsyncSession, payment_id: int
    ) -> SponsorPayment | None:
        q = select(SponsorPayment).where(SponsorPayment.id == payment_id)
        return (await db.execute(q)).scalar_one_or_none()

    async def list_refund_failed_payment_ids_for_event(
        self, db: AsyncSession, event_id: int
    ) -> list[int]:
        q = (
            select(SponsorPayment.id)
            .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorshipCategory.event_id == event_id,
                SponsorPayment.status == PaymentStatus.refund_failed,
            )
        )
        return list((await db.execute(q)).scalars().all())

    async def count_refund_failed_payments_for_event(
        self, db: AsyncSession, event_id: int
    ) -> int:
        q = (
            select(func.count()).select_from(SponsorPayment)
            .join(SponsorBid, SponsorPayment.bid_id == SponsorBid.id)
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .where(
                SponsorshipCategory.event_id == event_id,
                SponsorPayment.status == PaymentStatus.refund_failed,
            )
        )
        return int((await db.execute(q)).scalar_one())


    # ── Chat conversation queries ───────────────────────────────────

    async def list_chat_conversations(
        self, db: AsyncSession, user_id: int
    ) -> list:
        """Return rows of (SponsorBid, SponsorshipCategory, Event, SponsorUser, OrganizerUser)
        for bids with chat relevance."""
        from sqlalchemy import and_, or_
        from app.models.event import Event, EventStatus
        from app.models.user import User

        SponsorUser = aliased(User)
        OrganizerUser = aliased(User)

        q = (
            select(SponsorBid, SponsorshipCategory, Event, SponsorUser, OrganizerUser)
            .join(SponsorshipCategory, SponsorBid.category_id == SponsorshipCategory.id)
            .join(Event, SponsorshipCategory.event_id == Event.id)
            .join(SponsorUser, SponsorBid.sponsor_user_id == SponsorUser.id)
            .join(OrganizerUser, Event.organizer_id == OrganizerUser.id)
            .where(
                or_(
                    SponsorBid.sponsor_user_id == user_id,
                    and_(
                        Event.organizer_id == user_id,
                        SponsorBid.last_message_at.isnot(None),
                    ),
                ),
            )
            .order_by(SponsorBid.last_message_at.desc().nullslast())
        )
        return list((await db.execute(q)).all())


# Module-level singleton
sponsor_repo = SponsorRepository()
