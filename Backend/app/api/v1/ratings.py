"""Rating endpoints."""
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, field_validator

from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.logger import get_logger, log_step

logger = get_logger("api.ratings")
from app.rate_limit import limiter, dynamic_limit
from app.models.event import EventStatus
from app.models.rating import Rating, RatingDirection
from app.repositories.rating_repo import rating_repo
from app.services import event as event_service

router = APIRouter()


class RatingCreate(BaseModel):
    direction: str
    rated_user_id: int | None = None
    stars: int
    description: str | None = None

    @field_validator("stars")
    @classmethod
    def stars_range(cls, v: int) -> int:
        if v < 1 or v > 5:
            raise ValueError("stars must be 1-5")
        return v


def _fmt_rating(r: Rating) -> dict:
    return {
        "id": r.id,
        "rater_name": r.rater.display_name if r.rater else "Anonymous",
        "direction": r.direction.value,
        "stars": r.stars,
        "description": r.description,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }


@router.post("/events/{event_id}/ratings", status_code=201)
@limiter.limit(dynamic_limit("content_create", "15/minute"))
async def create_rating(request: Request, event_id: int, body: RatingCreate, db: DbSession, current_user: CurrentUser):
    """Create a rating. Only allowed after event is completed."""
    log_step(logger, "Submitting rating", event_id=event_id, user_id=current_user.id, direction=body.direction)
    event = await event_service.get_or_404(db, event_id)
    if event.status != EventStatus.completed:
        raise HTTPException(status_code=400, detail="Ratings are only allowed for completed events")

    # Validate direction enum
    try:
        direction = RatingDirection(body.direction)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid direction: {body.direction}")

    # Prevent self-rating
    if body.rated_user_id and body.rated_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot rate yourself")

    existing = await rating_repo.get_existing(db, current_user.id, event_id, direction)
    if existing:
        raise HTTPException(status_code=409, detail="You have already rated for this direction")

    rating = Rating(
        rater_user_id=current_user.id,
        rated_user_id=body.rated_user_id,
        event_id=event_id,
        direction=direction,
        stars=body.stars,
        description=body.description,
    )
    rating = await rating_repo.create(db, rating)

    # TODO: Notify the rated user once notification_service is implemented (Batch A)

    return {"id": rating.id, "stars": rating.stars}


@router.get("/events/{event_id}/ratings/summary")
async def get_event_ratings_summary(event_id: int, db: ReadDbSession, current_user: CurrentUser):
    """
    Event rating summary: aggregate + top 5 best + top 5 worst reviews.
    Direction: customer_to_event only.
    """
    avg_stars, count = await rating_repo.get_event_aggregate(
        db, event_id, RatingDirection.customer_to_event,
    )
    best = await rating_repo.list_event_top(
        db, event_id, RatingDirection.customer_to_event, best=True,
    )
    worst = await rating_repo.list_event_top(
        db, event_id, RatingDirection.customer_to_event, best=False,
    )
    my_event_rating = await rating_repo.get_existing(
        db, current_user.id, event_id, RatingDirection.customer_to_event,
    )
    my_organizer_rating = await rating_repo.get_existing(
        db, current_user.id, event_id, RatingDirection.customer_to_organizer,
    )

    def _my(r: Rating | None) -> dict | None:
        return {"id": r.id, "stars": r.stars, "description": r.description} if r else None

    return {
        "avg_stars": avg_stars,
        "count": count,
        "top_reviews": [_fmt_rating(r) for r in best],
        "worst_reviews": [_fmt_rating(r) for r in worst],
        "my_rating": _my(my_event_rating),
        "my_organizer_rating": _my(my_organizer_rating),
    }


@router.get("/events/{event_id}/ratings")
async def list_event_ratings(
    event_id: int, db: ReadDbSession, current_user: CurrentUser,
    direction: str | None = Query(None),
):
    """List ALL individual ratings for an event. Organizer only."""
    from app.models.user import UserRole
    event = await event_service.get_or_404(db, event_id)
    if current_user.role != UserRole.admin and current_user.id != event.organizer_id:
        raise HTTPException(status_code=403, detail="Only the organizer can view the full review list")

    dir_filter = RatingDirection(direction) if direction else None
    items = await rating_repo.list_by_event(db, event_id, direction=dir_filter)
    return [_fmt_rating(r) for r in items]


@router.get("/users/{user_id}/ratings-received")
async def get_user_ratings_summary(user_id: int, db: ReadDbSession, current_user: CurrentUser):
    """
    User rating summary: aggregate + top 5 best + top 5 worst reviews.
    For organizer profiles: customer_to_organizer + sponsor_to_organizer.
    For sponsor profiles: organizer_to_sponsor.
    """
    avg_stars, count = await rating_repo.get_user_aggregate(db, user_id)
    best = await rating_repo.list_user_top(db, user_id, best=True)
    worst = await rating_repo.list_user_top(db, user_id, best=False)

    return {
        "avg_stars": avg_stars,
        "count": count,
        "top_reviews": [_fmt_rating(r) for r in best],
        "worst_reviews": [_fmt_rating(r) for r in worst],
    }
