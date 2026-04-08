"""
Organizer FAQ library: GET/POST/PATCH/DELETE /me/faqs
"""
from fastapi import APIRouter, Depends

from app.dependencies import CurrentUser, DbSession, ReadDbSession, require_role
from app.models.user import User, UserRole
from app.schemas.organizer_faq import OrganizerFaqCreate, OrganizerFaqResponse, OrganizerFaqUpdate
from app.services import organizer_faq as faq_service

router = APIRouter()


@router.get("/faqs", response_model=list[OrganizerFaqResponse])
async def list_my_faqs(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Return all FAQs for the current organizer (active and inactive)."""
    faqs = await faq_service.list_faqs(db, current_user.id)
    return [OrganizerFaqResponse.model_validate(f) for f in faqs]


@router.post("/faqs", response_model=OrganizerFaqResponse, status_code=201)
async def create_faq(
    body: OrganizerFaqCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Create a new FAQ item for the current organizer."""
    faq = await faq_service.create(db, current_user.id, body)
    await db.commit()
    return OrganizerFaqResponse.model_validate(faq)


@router.patch("/faqs/{faq_id}", response_model=OrganizerFaqResponse)
async def update_faq(
    faq_id: int,
    body: OrganizerFaqUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Update an FAQ item. Only the owning organizer (or admin) may update."""
    faq = await faq_service.get_or_404(db, faq_id)
    faq_service.check_ownership(faq, current_user.id, current_user.role == UserRole.admin)
    faq = await faq_service.update(db, faq, body)
    await db.commit()
    return OrganizerFaqResponse.model_validate(faq)


@router.delete("/faqs/{faq_id}", status_code=204)
async def delete_faq(
    faq_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    """Delete an FAQ item. Only the owning organizer (or admin) may delete."""
    faq = await faq_service.get_or_404(db, faq_id)
    faq_service.check_ownership(faq, current_user.id, current_user.role == UserRole.admin)
    await faq_service.delete(db, faq)
    await db.commit()
