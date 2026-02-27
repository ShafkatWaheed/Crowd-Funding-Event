"""
Event posts: CRUD for feed/wall on events. Only registered users can post.
"""
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from sqlalchemy import func as sa_func

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.event import Event
from app.models.post import EventPost
from app.models.registration import Registration, RegistrationStatus
from app.models.user import User
from app.services import event as event_service


async def list_posts(db: AsyncSession, *, event_id: int) -> Sequence[EventPost]:
    """List posts for an event, newest first."""
    q = (
        select(EventPost)
        .where(EventPost.event_id == event_id)
        .options(selectinload(EventPost.user))
        .order_by(EventPost.created_at.desc())
    )
    result = await db.execute(q)
    return result.scalars().unique().all()


async def create_post(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    content: str,
) -> EventPost:
    """Create a post. User must be registered for the event. Posts must be enabled."""
    event = await event_service.get_or_404(db, event_id)
    if not event.posts_enabled:
        raise ConflictError("Posts are disabled for this event")
    if not content.strip():
        raise ConflictError("Post content cannot be empty")

    # Check registration (organizers/admins can always post)
    if user.role.value == "customer":
        reg_q = select(Registration).where(
            Registration.event_id == event_id,
            Registration.user_id == user.id,
            Registration.status == RegistrationStatus.registered,
        )
        reg = (await db.execute(reg_q)).scalar_one_or_none()
        if not reg:
            raise ForbiddenError("You must be registered for this event to post")

    policy = await event_service.get_effective_policy(db, event)
    max_posts = policy.get("max_posts_per_day")
    if max_posts and max_posts > 0:
        from datetime import datetime, timezone, timedelta
        today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        posts_today = (await db.execute(
            select(sa_func.count()).where(
                EventPost.event_id == event_id,
                EventPost.created_at >= today_start,
            )
        )).scalar_one()
        if int(posts_today) >= max_posts:
            raise ConflictError(f"Max {max_posts} posts per day for this event")

    post = EventPost(event_id=event_id, user_id=user.id, content=content.strip())
    db.add(post)
    await db.flush()
    await db.refresh(post, attribute_names=["user"])
    return post


async def delete_post(
    db: AsyncSession,
    *,
    event_id: int,
    post_id: int,
    user: User,
) -> None:
    """Delete a post. Author, event organizer, or admin can delete."""
    q = select(EventPost).where(EventPost.id == post_id, EventPost.event_id == event_id)
    result = await db.execute(q)
    post = result.scalar_one_or_none()
    if not post:
        raise NotFoundError("Post", post_id)

    # Author can delete their own; organizer/admin can delete any
    if post.user_id != user.id:
        event = await event_service.get_or_404(db, event_id)
        if not await event_service.user_can_edit_event(db, event, user):
            raise ForbiddenError("You cannot delete this post")

    await db.delete(post)
    await db.flush()


async def toggle_posts(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    enabled: bool,
) -> Event:
    """Organizer/admin toggles posts on/off for the event."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot manage this event")
    event.posts_enabled = enabled
    await db.flush()
    await db.refresh(event)
    return event
