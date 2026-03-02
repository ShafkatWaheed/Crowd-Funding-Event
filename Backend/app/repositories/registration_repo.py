"""
Registration data-access layer.

All SQLAlchemy queries for registrations, waitlist management, and related
event/funding lookups live here.  The service layer must call these methods
instead of db.execute() directly.
"""

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import Event
from app.models.registration import Registration, RegistrationStatus
from app.repositories.base import BaseRepository


class RegistrationRepository(BaseRepository[Registration]):
    model_class = Registration

    # ═══════════════════════════════════════════════════════════════════
    #  Locking helpers
    # ═══════════════════════════════════════════════════════════════════

    async def advisory_lock(self, db: AsyncSession, event_id: int) -> None:
        """Acquire a PostgreSQL advisory lock scoped to the transaction."""
        await db.execute(text("SELECT pg_advisory_xact_lock(:eid)"), {"eid": event_id})

    async def get_event_for_update(self, db: AsyncSession, event_id: int) -> Event | None:
        """SELECT ... FOR UPDATE on Event (used for capacity gating)."""
        q = select(Event).where(Event.id == event_id).with_for_update()
        result = await db.execute(q)
        return result.scalar_one_or_none()

    async def get_event(self, db: AsyncSession, event_id: int) -> Event | None:
        """Simple event fetch without lock."""
        q = select(Event).where(Event.id == event_id)
        result = await db.execute(q)
        return result.scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════════
    #  Registration queries
    # ═══════════════════════════════════════════════════════════════════

    async def get_existing_registration(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> Registration | None:
        """Check if user already has a registration (any status)."""
        q = select(Registration).where(
            Registration.event_id == event_id,
            Registration.user_id == user_id,
        )
        result = await db.execute(q)
        return result.scalar_one_or_none()

    async def count_registered(self, db: AsyncSession, event_id: int) -> int:
        """Count registrations with status=registered for an event."""
        q = select(func.count()).where(
            Registration.event_id == event_id,
            Registration.status == RegistrationStatus.registered,
        )
        return int((await db.execute(q)).scalar_one())

    async def count_waitlisted(self, db: AsyncSession, event_id: int) -> int:
        """Count registrations with status=waitlist for an event."""
        q = select(func.count()).where(
            Registration.event_id == event_id,
            Registration.status == RegistrationStatus.waitlist,
        )
        return int((await db.execute(q)).scalar_one())

    async def create_registration(
        self,
        db: AsyncSession,
        event_id: int,
        user_id: int,
        status: RegistrationStatus,
    ) -> Registration:
        """Create a new registration, flush + refresh, and return it."""
        reg = Registration(event_id=event_id, user_id=user_id, status=status)
        db.add(reg)
        await db.flush()
        await db.refresh(reg)
        return reg

    async def update_registration_status(
        self,
        db: AsyncSession,
        reg: Registration,
        new_status: RegistrationStatus,
        event: Event | None = None,
    ) -> Registration:
        """
        Update registration status, optionally adjust event.registration_count,
        flush + refresh.
        """
        old_status = reg.status
        reg.status = new_status

        if event is not None:
            # Increment if becoming registered, decrement if leaving registered
            if new_status == RegistrationStatus.registered and old_status != RegistrationStatus.registered:
                event.registration_count = (event.registration_count or 0) + 1
            elif old_status == RegistrationStatus.registered and new_status != RegistrationStatus.registered:
                event.registration_count = max(0, (event.registration_count or 1) - 1)

        await db.flush()
        await db.refresh(reg)
        return reg

    # ═══════════════════════════════════════════════════════════════════
    #  List / get helpers
    # ═══════════════════════════════════════════════════════════════════

    async def list_by_event(self, db: AsyncSession, event_id: int) -> list[Registration]:
        """List all registrations for an event, ordered by created_at."""
        q = (
            select(Registration)
            .where(Registration.event_id == event_id)
            .order_by(Registration.created_at.asc())
        )
        result = await db.execute(q)
        return list(result.scalars().all())

    async def get_by_id(  # type: ignore[override]
        self, db: AsyncSession, event_id: int, registration_id: int
    ) -> Registration | None:
        """Get registration by ID and event_id."""
        q = select(Registration).where(
            Registration.id == registration_id,
            Registration.event_id == event_id,
        )
        result = await db.execute(q)
        return result.scalar_one_or_none()

    async def get_by_id_for_update(
        self, db: AsyncSession, event_id: int, registration_id: int
    ) -> Registration | None:
        """Get registration with FOR UPDATE lock."""
        q = (
            select(Registration)
            .where(
                Registration.id == registration_id,
                Registration.event_id == event_id,
            )
            .with_for_update()
        )
        result = await db.execute(q)
        return result.scalar_one_or_none()

    async def get_user_registration(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> Registration | None:
        """Get user's registration for an event."""
        q = select(Registration).where(
            Registration.event_id == event_id,
            Registration.user_id == user_id,
        )
        result = await db.execute(q)
        return result.scalar_one_or_none()

    # ═══════════════════════════════════════════════════════════════════
    #  Funding / refund helpers
    # ═══════════════════════════════════════════════════════════════════

    async def get_pledges_for_refund(
        self, db: AsyncSession, event_id: int, user_id: int
    ) -> list:
        """Get pledged funding records for a user on an event (for refund calculation)."""
        from app.models.funding import Funding, FundingStatus

        q = select(Funding).where(
            Funding.event_id == event_id,
            Funding.user_id == user_id,
            Funding.status == FundingStatus.pledged,
        )
        result = await db.execute(q)
        return list(result.scalars().all())

    # ═══════════════════════════════════════════════════════════════════
    #  Waitlist management
    # ═══════════════════════════════════════════════════════════════════

    async def get_waitlist_to_approve(
        self, db: AsyncSession, event_id: int, limit: int
    ) -> list[Registration]:
        """Get first N waitlisted registrations ordered by created_at."""
        q = (
            select(Registration)
            .where(
                Registration.event_id == event_id,
                Registration.status == RegistrationStatus.waitlist,
            )
            .order_by(Registration.created_at.asc())
            .limit(limit)
        )
        result = await db.execute(q)
        return list(result.scalars().all())

    async def bulk_approve_waitlist(
        self, db: AsyncSession, registrations: list[Registration]
    ) -> None:
        """Set status=registered on multiple registrations, then flush."""
        for reg in registrations:
            reg.status = RegistrationStatus.registered
        if registrations:
            await db.flush()

    async def flush(self, db: AsyncSession) -> None:
        """Flush pending changes."""
        await db.flush()


# Module-level singleton
registration_repo = RegistrationRepository()
