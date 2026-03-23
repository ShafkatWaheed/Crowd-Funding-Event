"""
OrganizerFaq data-access layer.

All SQLAlchemy queries for organizer FAQ items live here.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.organizer_faq import OrganizerFaq
from app.repositories.base import BaseRepository


class OrganizerFaqRepository(BaseRepository[OrganizerFaq]):
    model_class = OrganizerFaq

    async def list_by_organizer(
        self,
        db: AsyncSession,
        organizer_id: int,
        *,
        active_only: bool = False,
    ) -> list[OrganizerFaq]:
        """Return FAQs for an organizer ordered by display_order then id."""
        q = select(OrganizerFaq).where(OrganizerFaq.organizer_id == organizer_id)
        if active_only:
            q = q.where(OrganizerFaq.is_active.is_(True))
        q = q.order_by(OrganizerFaq.display_order.asc(), OrganizerFaq.id.asc())
        return list((await db.execute(q)).scalars().all())

    async def get_by_id(self, db: AsyncSession, faq_id: int) -> OrganizerFaq | None:
        """Get a FAQ by primary key or None."""
        return (
            await db.execute(
                select(OrganizerFaq).where(OrganizerFaq.id == faq_id)
            )
        ).scalar_one_or_none()

    async def create(self, db: AsyncSession, faq: OrganizerFaq) -> OrganizerFaq:
        """Persist a new FAQ item."""
        db.add(faq)
        await db.flush()
        await db.refresh(faq)
        return faq

    async def update(self, db: AsyncSession, faq: OrganizerFaq) -> OrganizerFaq:
        """Flush attribute changes and refresh from the database."""
        await db.flush()
        await db.refresh(faq)
        return faq

    async def delete(self, db: AsyncSession, faq: OrganizerFaq) -> None:
        """Hard-delete a FAQ item."""
        await db.delete(faq)
        await db.flush()

    async def get_active_for_event_organizer(
        self, db: AsyncSession, organizer_id: int
    ) -> list[OrganizerFaq]:
        """Return active FAQs for the organizer — used by the public event FAQ endpoint."""
        return await self.list_by_organizer(db, organizer_id, active_only=True)


organizer_faq_repo = OrganizerFaqRepository()
