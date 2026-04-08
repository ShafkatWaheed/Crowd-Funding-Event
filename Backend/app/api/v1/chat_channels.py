"""Announcement channel routes."""
from __future__ import annotations

import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, UploadFile

from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.logger import get_logger, log_step
from app.schemas.chat import (
    ChannelCreateRequest,
    ChannelResponse,
    PostCreateRequest,
    PostResponse,
)
from app.services.chat import channel_service

logger = get_logger("api.chat_channels")

router = APIRouter()

UPLOAD_DIR = Path("static/uploads/chat")


@router.post("/chat/channels", response_model=ChannelResponse, status_code=201)
async def create_channel(
    body: ChannelCreateRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Create channel", user_id=current_user.id)
    channel = await channel_service.create_channel(
        db,
        organizer_id=current_user.id,
        event_id=body.event_id,
        channel_type=body.channel_type,
    )
    await db.commit()
    return channel


@router.get("/chat/channels/{channel_id}/posts", response_model=list[PostResponse])
async def list_posts(
    channel_id: str,
    db: ReadDbSession,
    current_user: CurrentUser,
    limit: int = 50,
    before: str | None = None,
):
    from app.repositories.firebase_chat_repo import firebase_chat_repo

    posts = firebase_chat_repo.get_posts(channel_id, limit=limit, before_key=before)
    return [
        PostResponse(
            post_id=p["post_id"],
            channel_id=channel_id,
            sender_id=p.get("sender_id", 0),
            body=p.get("body", ""),
            msg_type=p.get("msg_type", "text"),
            image_url=p.get("image_url"),
            created_at=p.get("created_at", 0),
            reaction_counts=p.get("reaction_counts", {"like": 0, "dislike": 0}),
        )
        for p in posts
    ]


@router.post(
    "/chat/channels/{channel_id}/posts",
    response_model=PostResponse,
    status_code=201,
)
async def create_post(
    channel_id: str,
    body: PostCreateRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Create post", channel_id=channel_id, user_id=current_user.id)
    post = await channel_service.create_post(
        db,
        organizer_id=current_user.id,
        channel_id=channel_id,
        body=body.body,
        msg_type=body.msg_type,
    )
    await db.commit()
    return PostResponse(**post)


@router.post("/chat/channels/{channel_id}/posts/{post_id}/upload")
async def upload_post_image(
    channel_id: str,
    post_id: str,
    file: UploadFile,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Upload post image", channel_id=channel_id, post_id=post_id)
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    ext = Path(file.filename or "img.jpg").suffix
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = UPLOAD_DIR / filename
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)
    image_url = f"/static/uploads/chat/{filename}"

    await channel_service.attach_image(
        db,
        organizer_id=current_user.id,
        channel_id=channel_id,
        post_id=post_id,
        image_url=image_url,
    )
    await db.commit()
    return {"image_url": image_url}
