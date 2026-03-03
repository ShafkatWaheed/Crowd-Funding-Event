"""Event reaction logic: like/dislike toggle."""
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.event import EventReaction
from app.repositories.event_repo import event_repo

from app.services.event.crud import get_or_404


async def react_to_event(
    db: AsyncSession, event_id: int, user_id: int, reaction: str
) -> dict:
    """
    Like or dislike an event. Toggles: same reaction again removes it;
    different reaction switches it. Returns action, reaction, counts.
    """
    event = await get_or_404(db, event_id)
    existing = await event_repo.get_user_reaction(db, event_id, user_id)

    if existing:
        if existing.reaction == reaction:
            if reaction == "like":
                event.like_count = max(0, event.like_count - 1)
            else:
                event.dislike_count = max(0, event.dislike_count - 1)
            await event_repo.delete_reaction(db, existing)
            return {
                "action": "removed",
                "reaction": reaction,
                "like_count": event.like_count,
                "dislike_count": event.dislike_count,
            }
        else:
            if existing.reaction == "like":
                event.like_count = max(0, event.like_count - 1)
            else:
                event.dislike_count = max(0, event.dislike_count - 1)
            existing.reaction = reaction
            if reaction == "like":
                event.like_count += 1
            else:
                event.dislike_count += 1
            await event_repo.flush(db)
            return {
                "action": "switched",
                "reaction": reaction,
                "like_count": event.like_count,
                "dislike_count": event.dislike_count,
            }
    else:
        new_reaction = EventReaction(
            event_id=event_id,
            user_id=user_id,
            reaction=reaction,
        )
        await event_repo.create_reaction(db, new_reaction)
        if reaction == "like":
            event.like_count += 1
        else:
            event.dislike_count += 1
        await event_repo.flush(db)
        return {
            "action": "added",
            "reaction": reaction,
            "like_count": event.like_count,
            "dislike_count": event.dislike_count,
        }
