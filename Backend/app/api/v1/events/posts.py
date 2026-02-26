"""
Event posts: list, create, delete, toggle.
"""
from fastapi import APIRouter, Depends

from app.dependencies import DbSession, ReadDbSession, require_role
from app.models.user import User, UserRole
from app.schemas import EventPostCreate, EventPostResponse
from app.services import post as post_service

router = APIRouter()


@router.get("/{event_id}/posts", response_model=list[EventPostResponse])
async def list_event_posts(event_id: int, db: ReadDbSession):
    posts = await post_service.list_posts(db, event_id=event_id)
    return [
        EventPostResponse(
            id=p.id,
            event_id=p.event_id,
            user_id=p.user_id,
            author_name=p.user.display_name if p.user else None,
            content=p.content,
            created_at=p.created_at,
        )
        for p in posts
    ]


@router.post("/{event_id}/posts", response_model=EventPostResponse)
async def create_event_post(
    event_id: int,
    body: EventPostCreate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    post = await post_service.create_post(
        db, event_id=event_id, user=current_user, content=body.content,
    )
    return EventPostResponse(
        id=post.id,
        event_id=post.event_id,
        user_id=post.user_id,
        author_name=post.user.display_name if post.user else None,
        content=post.content,
        created_at=post.created_at,
    )


@router.delete("/{event_id}/posts/{post_id}")
async def delete_event_post(
    event_id: int,
    post_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.customer, UserRole.organizer, UserRole.admin)),
):
    await post_service.delete_post(
        db, event_id=event_id, post_id=post_id, user=current_user,
    )
    return {"ok": True}


@router.post("/{event_id}/toggle-posts")
async def toggle_event_posts(
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer, UserRole.admin)),
):
    from app.services import event as event_service
    event = await event_service.get_or_404(db, event_id)
    new_val = not event.posts_enabled
    await post_service.toggle_posts(db, event_id=event_id, user=current_user, enabled=new_val)
    return {"posts_enabled": new_val}
