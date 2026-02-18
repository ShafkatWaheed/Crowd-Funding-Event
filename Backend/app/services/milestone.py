"""
Milestone service: CRUD for funding milestones + per-milestone reactions.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError
from app.models.milestone import FundingMilestone, MilestoneReaction
from app.models.event import Event, EventStatus
from app.models.user import User
from app.schemas.milestone import MilestoneCreate, MilestoneUpdate, MilestoneResponse
from app.services import event as event_service
from app.services import funding as funding_service


async def _get_or_404(db: AsyncSession, milestone_id: int) -> FundingMilestone:
    q = select(FundingMilestone).where(FundingMilestone.id == milestone_id)
    ms = (await db.execute(q)).scalar_one_or_none()
    if not ms:
        raise NotFoundError("Milestone", milestone_id)
    return ms


async def _compute_funding_percent(db: AsyncSession, event: Event) -> float:
    """Current funding progress as a percentage (0-100+)."""
    if not event.funding_goal_cents or event.funding_goal_cents <= 0:
        return 0.0
    summary = await funding_service.get_summary(db, event_id=event.id)
    return summary["total_pledged_cents"] / event.funding_goal_cents * 100


def _milestone_to_response(ms: FundingMilestone, funding_percent: float) -> MilestoneResponse:
    return MilestoneResponse(
        id=ms.id,
        event_id=ms.event_id,
        title=ms.title,
        description=ms.description,
        unlock_percent=ms.unlock_percent,
        benefit_description=ms.benefit_description,
        sort_order=ms.sort_order,
        like_count=ms.like_count,
        dislike_count=ms.dislike_count,
        is_unlocked=funding_percent >= ms.unlock_percent,
        created_at=ms.created_at,
    )


async def list_milestones(db: AsyncSession, event_id: int) -> list[MilestoneResponse]:
    event = await event_service.get_or_404(db, event_id)
    pct = await _compute_funding_percent(db, event)
    q = (
        select(FundingMilestone)
        .where(FundingMilestone.event_id == event_id)
        .order_by(FundingMilestone.unlock_percent, FundingMilestone.sort_order)
    )
    rows = (await db.execute(q)).scalars().all()
    return [_milestone_to_response(ms, pct) for ms in rows]


async def create_milestone(
    db: AsyncSession, event_id: int, data: MilestoneCreate, user: User
) -> MilestoneResponse:
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        raise ForbiddenError("Only the organizer can manage milestones")
    if not event.funding_goal_cents:
        raise ConflictError("Milestones require a funding goal to be set")
    if event.status not in (
        EventStatus.draft,
        EventStatus.pending_approval,
        EventStatus.approved,
    ):
        raise ConflictError("Milestones can only be managed before funding ends")

    ms = FundingMilestone(
        event_id=event_id,
        title=data.title,
        description=data.description,
        unlock_percent=data.unlock_percent,
        benefit_description=data.benefit_description,
        sort_order=data.sort_order,
    )
    db.add(ms)
    await db.flush()
    await db.refresh(ms)
    pct = await _compute_funding_percent(db, event)
    return _milestone_to_response(ms, pct)


async def update_milestone(
    db: AsyncSession, milestone_id: int, data: MilestoneUpdate, user: User
) -> MilestoneResponse:
    ms = await _get_or_404(db, milestone_id)
    event = await event_service.get_or_404(db, ms.event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        raise ForbiddenError("Only the organizer can manage milestones")
    if event.status not in (
        EventStatus.draft,
        EventStatus.pending_approval,
        EventStatus.approved,
    ):
        raise ConflictError("Milestones can only be managed before funding ends")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(ms, field, value)
    await db.flush()
    await db.refresh(ms)
    pct = await _compute_funding_percent(db, event)
    return _milestone_to_response(ms, pct)


async def delete_milestone(db: AsyncSession, milestone_id: int, user: User) -> None:
    ms = await _get_or_404(db, milestone_id)
    event = await event_service.get_or_404(db, ms.event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        raise ForbiddenError("Only the organizer can manage milestones")
    if event.status not in (
        EventStatus.draft,
        EventStatus.pending_approval,
        EventStatus.approved,
    ):
        raise ConflictError("Milestones can only be managed before funding ends")
    await db.delete(ms)
    await db.flush()


async def react_to_milestone(
    db: AsyncSession, milestone_id: int, user_id: int, reaction: str
) -> dict:
    """Like/dislike a milestone. Toggle off if same reaction, switch if different."""
    if reaction not in ("like", "dislike"):
        raise ConflictError("reaction must be 'like' or 'dislike'")

    ms = await _get_or_404(db, milestone_id)

    q = select(MilestoneReaction).where(
        MilestoneReaction.milestone_id == milestone_id,
        MilestoneReaction.user_id == user_id,
    )
    existing = (await db.execute(q)).scalar_one_or_none()

    if existing:
        if existing.reaction == reaction:
            if reaction == "like":
                ms.like_count = max(0, ms.like_count - 1)
            else:
                ms.dislike_count = max(0, ms.dislike_count - 1)
            await db.delete(existing)
            await db.flush()
            return {
                "action": "removed",
                "reaction": reaction,
                "like_count": ms.like_count,
                "dislike_count": ms.dislike_count,
            }
        else:
            if existing.reaction == "like":
                ms.like_count = max(0, ms.like_count - 1)
            else:
                ms.dislike_count = max(0, ms.dislike_count - 1)
            existing.reaction = reaction
            if reaction == "like":
                ms.like_count += 1
            else:
                ms.dislike_count += 1
            await db.flush()
            return {
                "action": "switched",
                "reaction": reaction,
                "like_count": ms.like_count,
                "dislike_count": ms.dislike_count,
            }
    else:
        new_reaction = MilestoneReaction(
            milestone_id=milestone_id,
            user_id=user_id,
            reaction=reaction,
        )
        db.add(new_reaction)
        if reaction == "like":
            ms.like_count += 1
        else:
            ms.dislike_count += 1
        await db.flush()
        return {
            "action": "added",
            "reaction": reaction,
            "like_count": ms.like_count,
            "dislike_count": ms.dislike_count,
        }


async def get_my_reaction(
    db: AsyncSession, milestone_id: int, user_id: int
) -> dict:
    await _get_or_404(db, milestone_id)
    q = select(MilestoneReaction).where(
        MilestoneReaction.milestone_id == milestone_id,
        MilestoneReaction.user_id == user_id,
    )
    existing = (await db.execute(q)).scalar_one_or_none()
    return {"reaction": existing.reaction if existing else None}
