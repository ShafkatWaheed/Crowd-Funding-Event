"""
Milestone service: CRUD for funding milestones + per-milestone reactions,
milestone snapshots, and early bird discounts.
"""
from datetime import datetime, timezone

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundError, ForbiddenError, ConflictError
from app.models.milestone import (
    FundingMilestone,
    MilestoneReaction,
    EarlyBirdDiscount,
)
from app.models.event import Event, EventStatus
from app.models.user import User
from app.repositories.milestone_repo import milestone_repo
from app.schemas.milestone import (
    MilestoneCreate,
    MilestoneUpdate,
    MilestoneResponse,
    MilestoneSnapshotResponse,
    EarlyBirdDiscountCreate,
    EarlyBirdDiscountUpdate,
    EarlyBirdDiscountResponse,
)
from app.services import event as event_service
from app.services import funding as funding_service

logger = get_logger("svc.milestone")


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
    rows = await milestone_repo.list_by_event(db, event_id)
    return [_milestone_to_response(ms, pct) for ms in rows]


async def create_milestone(
    db: AsyncSession, event_id: int, data: MilestoneCreate, user: User
) -> MilestoneResponse:
    log_step(logger, "Create milestone", event_id=event_id, user_id=user.id)
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        logger.warning("Create milestone: forbidden", extra={"event_id": event_id})
        raise ForbiddenError("Only the organizer can manage milestones")
    if not event.funding_goal_cents:
        logger.warning("Create milestone: no funding goal", extra={"event_id": event_id})
        raise ConflictError("Milestones require a funding goal to be set")
    if event.status not in (
        EventStatus.draft,
        EventStatus.pending_approval,
        EventStatus.approved,
    ):
        logger.warning("Create milestone: invalid event status", extra={"event_id": event_id, "status": event.status.value})
        raise ConflictError("Milestones can only be managed before funding ends")

    ms = FundingMilestone(
        event_id=event_id,
        title=data.title,
        description=data.description,
        unlock_percent=data.unlock_percent,
        benefit_description=data.benefit_description,
        sort_order=data.sort_order,
    )
    ms = await milestone_repo.create(db, ms)
    pct = await _compute_funding_percent(db, event)
    logger.info("Milestone created", extra={"milestone_id": ms.id, "event_id": event_id})
    return _milestone_to_response(ms, pct)


async def update_milestone(
    db: AsyncSession, milestone_id: int, data: MilestoneUpdate, user: User
) -> MilestoneResponse:
    log_step(logger, "Update milestone", milestone_id=milestone_id, user_id=user.id)
    ms = await milestone_repo.get_or_404(db, milestone_id, "Milestone")
    event = await event_service.get_or_404(db, ms.event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        logger.warning("Update milestone: forbidden", extra={"milestone_id": milestone_id})
        raise ForbiddenError("Only the organizer can manage milestones")
    if event.status not in (
        EventStatus.draft,
        EventStatus.pending_approval,
        EventStatus.approved,
    ):
        logger.warning("Update milestone: invalid event status", extra={"milestone_id": milestone_id})
        raise ConflictError("Milestones can only be managed before funding ends")

    update_data = data.model_dump(exclude_unset=True)
    ms = await milestone_repo.update_fields(db, ms, update_data)
    pct = await _compute_funding_percent(db, event)
    logger.info("Milestone updated", extra={"milestone_id": ms.id})
    return _milestone_to_response(ms, pct)


async def delete_milestone(db: AsyncSession, milestone_id: int, user: User) -> None:
    log_step(logger, "Delete milestone", milestone_id=milestone_id, user_id=user.id)
    ms = await milestone_repo.get_or_404(db, milestone_id, "Milestone")
    event = await event_service.get_or_404(db, ms.event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        logger.warning("Delete milestone: forbidden", extra={"milestone_id": milestone_id})
        raise ForbiddenError("Only the organizer can manage milestones")
    if event.status not in (
        EventStatus.draft,
        EventStatus.pending_approval,
        EventStatus.approved,
    ):
        logger.warning("Delete milestone: invalid event status", extra={"milestone_id": milestone_id})
        raise ConflictError("Milestones can only be managed before funding ends")
    await milestone_repo.delete(db, ms)
    logger.info("Milestone deleted", extra={"milestone_id": milestone_id})


async def react_to_milestone(
    db: AsyncSession, milestone_id: int, user_id: int, reaction: str
) -> dict:
    """Like/dislike a milestone. Toggle off if same reaction, switch if different."""
    if reaction not in ("like", "dislike"):
        raise ConflictError("reaction must be 'like' or 'dislike'")

    ms = await milestone_repo.get_or_404(db, milestone_id, "Milestone")
    existing = await milestone_repo.get_reaction(db, milestone_id, user_id)

    if existing:
        if existing.reaction == reaction:
            if reaction == "like":
                ms.like_count = max(0, ms.like_count - 1)
            else:
                ms.dislike_count = max(0, ms.dislike_count - 1)
            await milestone_repo.delete_reaction(db, existing)
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
            await milestone_repo.delete_reaction(db, existing)
            new_reaction = MilestoneReaction(
                milestone_id=milestone_id,
                user_id=user_id,
                reaction=reaction,
            )
            await milestone_repo.create_reaction(db, new_reaction)
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
        await milestone_repo.create_reaction(db, new_reaction)
        if reaction == "like":
            ms.like_count += 1
        else:
            ms.dislike_count += 1
        return {
            "action": "added",
            "reaction": reaction,
            "like_count": ms.like_count,
            "dislike_count": ms.dislike_count,
        }


async def get_my_reaction(
    db: AsyncSession, milestone_id: int, user_id: int
) -> dict:
    await milestone_repo.get_or_404(db, milestone_id, "Milestone")
    existing = await milestone_repo.get_reaction(db, milestone_id, user_id)
    return {"reaction": existing.reaction if existing else None}


# ─── Milestone Snapshots ─────────────────────────────────


async def list_snapshots(db: AsyncSession, event_id: int) -> list[MilestoneSnapshotResponse]:
    await event_service.get_or_404(db, event_id)
    rows = await milestone_repo.list_snapshots(db, event_id)
    result = []
    for snap in rows:
        user_count = await milestone_repo.count_snapshot_users(db, snap.id)
        result.append(MilestoneSnapshotResponse(
            id=snap.id,
            event_id=snap.event_id,
            milestone_percent=snap.milestone_percent,
            reached_at=snap.reached_at,
            user_count=user_count,
        ))
    return result


# ─── Early Bird Discounts ────────────────────────────────


def _eb_to_response(eb: EarlyBirdDiscount) -> EarlyBirdDiscountResponse:
    now = datetime.now(timezone.utc)
    window_start = eb.window_start or eb.created_at
    is_active = window_start <= now <= eb.window_end
    return EarlyBirdDiscountResponse(
        id=eb.id,
        event_id=eb.event_id,
        applies_to=eb.applies_to,
        window_start=eb.window_start,
        window_end=eb.window_end,
        discount_type=eb.discount_type,
        value=eb.value,
        is_active=is_active,
        created_at=eb.created_at,
    )


async def list_early_bird_discounts(
    db: AsyncSession, event_id: int
) -> list[EarlyBirdDiscountResponse]:
    await event_service.get_or_404(db, event_id)
    rows = await milestone_repo.list_early_bird_by_event(db, event_id)
    return [_eb_to_response(eb) for eb in rows]


async def create_early_bird_discount(
    db: AsyncSession, event_id: int, data: EarlyBirdDiscountCreate, user: User
) -> EarlyBirdDiscountResponse:
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        raise ForbiddenError("Only the organizer can manage early bird discounts")

    if data.applies_to not in ("funding", "tickets"):
        raise ConflictError("applies_to must be 'funding' or 'tickets'")
    if data.discount_type not in ("percent", "fixed_cents"):
        raise ConflictError("discount_type must be 'percent' or 'fixed_cents'")
    if data.discount_type == "percent" and data.value > 100:
        raise ConflictError("Percent value must be 0-100")

    window_end = datetime.fromisoformat(data.window_end.replace("Z", "+00:00"))
    window_start = (
        datetime.fromisoformat(data.window_start.replace("Z", "+00:00"))
        if data.window_start
        else None
    )

    # Validate window_end against event dates
    if data.applies_to == "funding":
        if not event.funding_end_at:
            raise ConflictError("Early Pledge requires a funding deadline on the event")
        if window_end > event.funding_end_at:
            raise ConflictError("Early Pledge window must end on or before the funding deadline")
    elif data.applies_to == "tickets":
        if event.start_time and window_end > event.start_time:
            raise ConflictError("Early Ticket window must end before the event starts")

    eb = EarlyBirdDiscount(
        event_id=event_id,
        applies_to=data.applies_to,
        window_start=window_start,
        window_end=window_end,
        discount_type=data.discount_type,
        value=data.value,
    )
    eb = await milestone_repo.create_early_bird(db, eb)
    return _eb_to_response(eb)


async def update_early_bird_discount(
    db: AsyncSession, discount_id: int, data: EarlyBirdDiscountUpdate, user: User
) -> EarlyBirdDiscountResponse:
    eb = await milestone_repo.get_early_bird(db, discount_id)
    if not eb:
        raise NotFoundError("EarlyBirdDiscount", discount_id)

    event = await event_service.get_or_404(db, eb.event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        raise ForbiddenError("Only the organizer can manage early bird discounts")

    update_data = data.model_dump(exclude_unset=True)
    if "window_end" in update_data and update_data["window_end"] is not None:
        update_data["window_end"] = datetime.fromisoformat(
            update_data["window_end"].replace("Z", "+00:00")
        )
    if "discount_type" in update_data and update_data["discount_type"] == "percent":
        if "value" in update_data and update_data["value"] > 100:
            raise ConflictError("Percent value must be 0-100")
    eb = await milestone_repo.update_early_bird(db, eb, update_data)
    return _eb_to_response(eb)


async def delete_early_bird_discount(
    db: AsyncSession, discount_id: int, user: User
) -> None:
    eb = await milestone_repo.get_early_bird(db, discount_id)
    if not eb:
        raise NotFoundError("EarlyBirdDiscount", discount_id)

    event = await event_service.get_or_404(db, eb.event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        raise ForbiddenError("Only the organizer can manage early bird discounts")

    await milestone_repo.delete_early_bird(db, eb)
