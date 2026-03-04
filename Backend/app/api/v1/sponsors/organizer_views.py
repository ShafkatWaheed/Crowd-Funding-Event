"""Organizer and public sponsor views: bid events, sponsorship-available, organizers, prerequisites, uploads, review, event sponsors."""
import os
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Form, HTTPException, Query, Request, UploadFile, File

from app.dependencies import DbSession, ReadDbSession, CurrentUser, require_feature
from app.rate_limit import limiter, dynamic_limit
from app.services.upload_validation import validate_upload
from app.models.user import UserRole
from app.models.prerequisite import CategoryPrerequisite, BidPrerequisiteUpload, UploadStatus
from app.models.sponsor import BidStatus
from app.repositories.sponsor_repo import sponsor_repo
from app.services import sponsor as sponsor_svc
from app.services import funding as funding_service
from app.api.v1.events import _event_to_response, _get_first_images

router = APIRouter(dependencies=[Depends(require_feature("feature_sponsors_enabled"))])


@router.get("/me/sponsor-bid-events")
async def list_sponsor_bid_events(db: ReadDbSession, current_user: CurrentUser):
    events = await sponsor_svc.get_sponsor_bid_events(db, current_user.id)
    event_ids = [e.id for e in events]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids) if event_ids else {}
    first_images = await _get_first_images(db, event_ids) if event_ids else {}
    now = datetime.now(timezone.utc)
    result = []
    for e in events:
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        resp = _event_to_response(
            e,
            total_pledged_cents=total_cents,
            funding_days_left=days_left,
            first_image_url=first_images.get(e.id),
        )
        summary = await sponsor_svc.get_sponsor_bid_summary_for_event(db, e.id, current_user.id)
        result.append({
            **resp.model_dump(mode="json"),
            "bid_summary": summary,
        })
    return result


@router.get("/events/sponsorship-available")
async def list_sponsorship_available_events(
    db: ReadDbSession,
    current_user: CurrentUser,
    exclude_my_bids: bool = Query(False),
):
    items = await sponsor_svc.get_events_with_sponsorship_available(
        db,
        sponsor_user_id=current_user.id,
        exclude_my_bids=exclude_my_bids,
    )
    if not items:
        return []
    event_ids = [it["event"].id for it in items]
    pledged = await funding_service.get_pledged_totals_for_events(db, event_ids=event_ids)
    first_images = await _get_first_images(db, event_ids)
    now = datetime.now(timezone.utc)
    result = []
    for it in items:
        e = it["event"]
        total_cents = pledged.get(e.id, 0)
        days_left = None
        if e.funding_end_at is not None:
            end = e.funding_end_at if e.funding_end_at.tzinfo else e.funding_end_at.replace(tzinfo=timezone.utc)
            delta = (end - now).days
            days_left = max(0, delta) if delta > 0 else 0
        resp = _event_to_response(
            e,
            total_pledged_cents=total_cents,
            funding_days_left=days_left,
            first_image_url=first_images.get(e.id),
        )
        result.append({
            **resp.model_dump(mode="json"),
            "categories_summary": it["categories_summary"],
        })
    return result


@router.get("/me/organizer-sponsors")
async def list_organizer_sponsors(
    db: ReadDbSession,
    current_user: CurrentUser,
    event_status: str | None = Query(None, description="Filter to events with this status"),
    genre: str | None = Query(None, description="Filter to events with this genre"),
    event_id: int | None = Query(None, description="Filter to a single event"),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    if current_user.role not in (UserRole.organizer, UserRole.admin):
        raise HTTPException(status_code=403, detail="Only organizers can view their sponsors")
    return await sponsor_svc.get_organizer_sponsors(db, current_user.id, event_status=event_status, genre=genre, event_id=event_id, offset=offset, limit=limit)


@router.get("/me/organizer-sponsors/{sponsor_user_id}/events")
async def list_sponsor_events_for_organizer(
    sponsor_user_id: int,
    db: ReadDbSession,
    current_user: CurrentUser,
):
    if current_user.role not in (UserRole.organizer, UserRole.admin):
        raise HTTPException(status_code=403, detail="Only organizers can view their sponsors")
    return await sponsor_svc.get_sponsor_events_for_organizer(db, current_user.id, sponsor_user_id)


@router.post("/events/{event_id}/sponsorships/{cat_id}/prerequisites", status_code=201)
async def create_prerequisite(
    event_id: int,
    cat_id: int,
    name: str = Form(...),
    description: str | None = Form(None),
    is_required: bool = Form(True),
    requires_document: bool = Form(False),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    cat = await sponsor_svc._get_category(db, cat_id)
    await sponsor_svc._require_organizer(db, cat.event_id, current_user)
    prereq = CategoryPrerequisite(
        category_id=cat_id,
        name=name,
        description=description,
        is_required=is_required,
        requires_document=requires_document,
    )
    prereq = await sponsor_repo.create_prerequisite(db, prereq)
    return {
        "id": prereq.id,
        "name": prereq.name,
        "description": prereq.description,
        "is_required": prereq.is_required,
        "requires_document": prereq.requires_document,
    }


@router.get("/events/{event_id}/sponsorships/{cat_id}/prerequisites")
async def list_prerequisites(
    event_id: int,
    cat_id: int,
    db: ReadDbSession = None,
    current_user: CurrentUser = None,
):
    items = await sponsor_repo.list_prerequisites(db, cat_id)
    return [
        {"id": p.id, "name": p.name, "description": p.description, "is_required": p.is_required, "requires_document": p.requires_document}
        for p in items
    ]


@router.delete("/events/{event_id}/sponsorships/{cat_id}/prerequisites/{prereq_id}", status_code=204)
async def delete_prerequisite(
    event_id: int,
    cat_id: int,
    prereq_id: int,
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    cat = await sponsor_svc._get_category(db, cat_id)
    await sponsor_svc._require_organizer(db, cat.event_id, current_user)
    prereq = await sponsor_repo.get_prerequisite(db, prereq_id)
    if not prereq:
        raise HTTPException(status_code=404, detail="Prerequisite not found")
    await sponsor_repo.delete_prerequisite(db, prereq)


@router.post("/bids/{bid_id}/prerequisites/{prereq_id}/upload")
@limiter.limit(dynamic_limit("file_upload", "10/minute"))
async def upload_prerequisite_document(
    request: Request,
    bid_id: int,
    prereq_id: int,
    file: UploadFile = File(...),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    bid = await sponsor_repo.get_bid(db, bid_id)
    if not bid or bid.sponsor_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your bid")
    content = await validate_upload(db, file, "document")
    upload_dir = "static/uploads/prerequisites"
    os.makedirs(upload_dir, exist_ok=True)
    ext = os.path.splitext(file.filename)[1] if file.filename else ".pdf"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(upload_dir, filename)
    with open(filepath, "wb") as f:
        f.write(content)
    upload = BidPrerequisiteUpload(
        bid_id=bid_id,
        prerequisite_id=prereq_id,
        file_url=f"/static/uploads/prerequisites/{filename}",
    )
    upload = await sponsor_repo.create_prerequisite_upload(db, upload)
    return {"id": upload.id, "file_url": upload.file_url, "status": upload.status.value}


@router.post("/events/{event_id}/sponsorships/{cat_id}/upload-prerequisite/{prereq_id}")
@limiter.limit(dynamic_limit("file_upload", "10/minute"))
async def upload_category_prerequisite(
    request: Request,
    event_id: int,
    cat_id: int,
    prereq_id: int,
    file: UploadFile = File(...),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    prereq = await sponsor_repo.get_prerequisite_for_category(db, prereq_id, cat_id)
    if not prereq:
        raise HTTPException(status_code=404, detail="Prerequisite not found")
    bid = await sponsor_repo.get_bid_for_category_by_sponsor(db, cat_id, current_user.id)
    if not bid:
        raise HTTPException(status_code=400, detail="You have no active bid for this category")
    existing = await sponsor_repo.get_bid_prerequisite_upload(db, bid.id, prereq_id)
    if existing:
        await sponsor_repo.delete_prerequisite_upload(db, existing)
    content = await validate_upload(db, file, "document")
    upload_dir = "static/uploads/prerequisites"
    os.makedirs(upload_dir, exist_ok=True)
    ext = os.path.splitext(file.filename)[1] if file.filename else ".pdf"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(upload_dir, filename)
    with open(filepath, "wb") as f:
        f.write(content)
    upload = BidPrerequisiteUpload(
        bid_id=bid.id,
        prerequisite_id=prereq_id,
        file_url=f"/static/uploads/prerequisites/{filename}",
    )
    upload = await sponsor_repo.create_prerequisite_upload(db, upload)
    return {"id": upload.id, "file_url": upload.file_url, "status": upload.status.value}


@router.get("/bids/{bid_id}/prerequisites")
async def list_bid_prerequisite_uploads(
    bid_id: int,
    db: ReadDbSession = None,
    current_user: CurrentUser = None,
):
    items = await sponsor_repo.list_bid_prerequisite_uploads(db, bid_id)
    return [
        {
            "id": u.id,
            "bid_id": u.bid_id,
            "prerequisite_id": u.prerequisite_id,
            "file_url": u.file_url,
            "status": u.status.value,
            "reviewed_at": u.reviewed_at.isoformat() if u.reviewed_at else None,
            "reviewer_note": u.reviewer_note,
        }
        for u in items
    ]


@router.patch("/bids/{bid_id}/prerequisites/{prereq_id}/review")
async def review_prerequisite_upload(
    bid_id: int,
    prereq_id: int,
    status: str = Form(...),
    reviewer_note: str | None = Form(None),
    db: DbSession = None,
    current_user: CurrentUser = None,
):
    bid = await sponsor_repo.get_bid(db, bid_id)
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")
    cat = await sponsor_svc._get_category(db, bid.category_id)
    await sponsor_svc._require_organizer(db, cat.event_id, current_user)
    upload = await sponsor_repo.get_bid_prerequisite_upload(db, bid_id, prereq_id)
    if not upload:
        raise HTTPException(status_code=404, detail="Upload not found")
    upload = await sponsor_repo.update_prerequisite_upload(
        db, upload,
        status=UploadStatus(status),
        reviewed_at=datetime.now(timezone.utc),
        reviewer_note=reviewer_note,
    )
    return {"id": upload.id, "status": upload.status.value, "reviewer_note": upload.reviewer_note}


@router.get("/events/{event_id}/sponsors")
async def list_event_sponsors(event_id: int, db: ReadDbSession):
    sponsors = await sponsor_svc.get_paid_sponsors(db, event_id)
    return sponsors
