"""DM conversation routes."""
from __future__ import annotations

import shutil
import uuid
from pathlib import Path

from fastapi import APIRouter, HTTPException, UploadFile

from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.logger import get_logger, log_step
from app.schemas.chat import (
    ConversationCreateRequest,
    ConversationListItem,
    ConversationResponse,
)
from app.services.chat import conversation_service

logger = get_logger("api.chat_conversations")

router = APIRouter()

UPLOAD_DIR = Path("static/uploads/chat")


@router.post(
    "/chat/conversations",
    response_model=ConversationResponse,
    status_code=201,
)
async def initiate_conversation(
    body: ConversationCreateRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Initiate conversation", user_id=current_user.id)
    conv = await conversation_service.initiate_conversation(
        db, user_id=current_user.id, event_id=body.event_id
    )
    await db.commit()
    return conv


@router.get("/chat/conversations", response_model=list[ConversationListItem])
async def list_my_conversations(
    db: ReadDbSession,
    current_user: CurrentUser,
):
    return await conversation_service.get_conversations_for_user(
        db, user_id=current_user.id
    )


@router.get(
    "/chat/conversations/event/{event_id}",
    response_model=list[ConversationListItem],
)
async def list_event_conversations(
    event_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
    type_filter: str | None = None,
):
    return await conversation_service.get_conversations_for_event(
        db,
        event_id=event_id,
        organizer_id=current_user.id,
        type_filter=type_filter,
    )


@router.post("/chat/conversations/{conv_id}/upload")
async def upload_dm_image(
    conv_id: str,
    file: UploadFile,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Upload DM image", conv_id=conv_id)
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    ext = Path(file.filename or "img.jpg").suffix
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = UPLOAD_DIR / filename
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)
    image_url = f"/static/uploads/chat/{filename}"

    from app.repositories.firebase_chat_repo import firebase_chat_repo

    firebase_chat_repo.update_message_image(conv_id, "latest", image_url)
    await db.commit()
    return {"image_url": image_url}


@router.post("/chat/conversations/{conv_id}/close")
async def close_conversation(
    conv_id: str,
    db: DbSession,
    current_user: CurrentUser,
):
    log_step(logger, "Close conversation", conv_id=conv_id)
    from app.repositories.chat_repo import chat_conversation_repo
    from app.repositories.firebase_chat_repo import firebase_chat_repo

    conv = await chat_conversation_repo.get_by_conv_id(db, conv_id)
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if conv.organizer_user_id != current_user.id:
        raise HTTPException(
            status_code=403, detail="Only the organizer can close conversations"
        )

    await chat_conversation_repo.update_status(db, conv_id, "read_only")
    firebase_chat_repo.update_conversation_status(conv_id, "read_only")
    await db.commit()
    return {"status": "read_only"}
