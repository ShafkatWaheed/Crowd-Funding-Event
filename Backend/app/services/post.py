"""
Event posts: CRUD for feed/wall on events. Only registered users can post.
"""
from typing import Sequence

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.post import EventPost
from app.models.user import User
from app.repositories.event_repo import event_repo
from app.services import event as event_service


async def list_posts(db: AsyncSession, *, event_id: int) -> Sequence[EventPost]:
    """List posts for an event, newest first."""
    return await event_repo.list_posts(db, event_id)


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
        reg = await event_repo.check_registration(db, event_id, user.id)
        if not reg:
            raise ForbiddenError("You must be registered for this event to post")

    policy = await event_service.get_effective_policy(db, event)
    max_posts = policy.get("max_posts_per_day")
    if max_posts and max_posts > 0:
        from datetime import datetime, timezone
        today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        posts_today = await event_repo.count_posts_today(db, event_id, today_start)
        if posts_today >= max_posts:
            raise ConflictError(f"Max {max_posts} posts per day for this event")

    post = EventPost(event_id=event_id, user_id=user.id, content=content.strip())
    return await event_repo.create_post(db, post)


async def delete_post(
    db: AsyncSession,
    *,
    event_id: int,
    post_id: int,
    user: User,
) -> None:
    """Delete a post. Author, event organizer, or admin can delete."""
    post = await event_repo.get_post(db, post_id, event_id)
    if not post:
        raise NotFoundError("Post", post_id)

    # Author can delete their own; organizer/admin can delete any
    if post.user_id != user.id:
        event = await event_service.get_or_404(db, event_id)
        if not await event_service.user_can_edit_event(db, event, user):
            raise ForbiddenError("You cannot delete this post")

    await event_repo.delete_post(db, post)


async def toggle_posts(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    enabled: bool,
) -> "Event":
    """Organizer/admin toggles posts on/off for the event."""
    event = await event_service.get_or_404(db, event_id)
    if not await event_service.user_can_edit_event(db, event, user):
        raise ForbiddenError("You cannot manage this event")
    event.posts_enabled = enabled
    return await event_repo.flush_and_refresh(db, event)
