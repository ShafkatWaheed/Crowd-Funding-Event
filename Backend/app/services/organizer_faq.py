"""
Organizer FAQ service: business logic for managing FAQ library items.

Zero db.* calls — all data access goes through organizer_faq_repo.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError, ForbiddenError
from app.models.organizer_faq import OrganizerFaq
from app.repositories.organizer_faq_repo import organizer_faq_repo
from app.schemas.organizer_faq import OrganizerFaqCreate, OrganizerFaqUpdate


async def list_faqs(db: AsyncSession, organizer_id: int) -> list[OrganizerFaq]:
    """Return all FAQs for an organizer."""
    return await organizer_faq_repo.list_by_organizer(db, organizer_id)


async def get_or_404(db: AsyncSession, faq_id: int) -> OrganizerFaq:
    """Fetch a FAQ or raise NotFoundError."""
    faq = await organizer_faq_repo.get_by_id(db, faq_id)
    if faq is None:
        raise NotFoundError("FAQ", faq_id)
    return faq


def check_ownership(faq: OrganizerFaq, user_id: int, is_admin: bool) -> None:
    """Raise ForbiddenError if the caller does not own this FAQ."""
    if not is_admin and faq.organizer_id != user_id:
        raise ForbiddenError("You do not have permission to modify this FAQ")


async def create(
    db: AsyncSession, organizer_id: int, body: OrganizerFaqCreate
) -> OrganizerFaq:
    """Create a new FAQ item for an organizer."""
    faq = OrganizerFaq(
        organizer_id=organizer_id,
        question=body.question,
        answer=body.answer,
        display_order=body.display_order,
    )
    return await organizer_faq_repo.create(db, faq)


async def update(
    db: AsyncSession, faq: OrganizerFaq, body: OrganizerFaqUpdate
) -> OrganizerFaq:
    """Apply partial updates to a FAQ item."""
    if body.question is not None:
        faq.question = body.question
    if body.answer is not None:
        faq.answer = body.answer
    if body.display_order is not None:
        faq.display_order = body.display_order
    if body.is_active is not None:
        faq.is_active = body.is_active
    return await organizer_faq_repo.update(db, faq)


async def delete(db: AsyncSession, faq: OrganizerFaq) -> None:
    """Hard-delete a FAQ item."""
    await organizer_faq_repo.delete(db, faq)
