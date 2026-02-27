"""
Centralized upload validation using admin-configurable limits from platform settings.
"""
from __future__ import annotations

from fastapi import HTTPException, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.services import platform_settings as ps


async def validate_upload(
    db: AsyncSession,
    file: UploadFile,
    category: str = "image",
) -> bytes:
    """Read file, validate type and size against platform settings.

    Args:
        db: async DB session (for reading settings)
        file: the uploaded file
        category: "image" or "document"

    Returns:
        The validated file bytes.

    Raises:
        HTTPException(400) if type or size is invalid.
    """
    if category == "image":
        max_mb = await ps.get_int(db, "upload_max_image_size_mb")
        allowed_raw = await ps.get_str(db, "upload_allowed_image_types")
    else:
        max_mb = await ps.get_int(db, "upload_max_document_size_mb")
        allowed_raw = await ps.get_str(db, "upload_allowed_document_types")

    allowed_types = {t.strip() for t in allowed_raw.split(",") if t.strip()}

    if allowed_types and file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file.content_type}. Allowed: {', '.join(sorted(allowed_types))}",
        )

    contents = await file.read()
    max_bytes = max_mb * 1024 * 1024
    if len(contents) > max_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"File too large ({len(contents) / 1024 / 1024:.1f} MB). Maximum: {max_mb} MB",
        )

    return contents
