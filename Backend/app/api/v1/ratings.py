"""Rating endpoints."""
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, field_validator
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.dependencies import CurrentUser, DbSession, ReadDbSession
from app.rate_limit import limiter, dynamic_limit
from app.models.event import Event, EventStatus
from app.models.rating import Rating, RatingDirection

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
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.status != EventStatus.completed:
        raise HTTPException(status_code=400, detail="Ratings are only allowed for completed events")

    direction = RatingDirection(body.direction)

    existing = (await db.execute(
        select(Rating).where(
            Rating.rater_user_id == current_user.id,
            Rating.event_id == event_id,
            Rating.direction == direction,
        )
    )).scalar_one_or_none()
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
    db.add(rating)
    await db.flush()

    # TODO: Notify the rated user once notification_service is implemented (Batch A)

    return {"id": rating.id, "stars": rating.stars}


@router.get("/events/{event_id}/ratings/summary")
async def get_event_ratings_summary(event_id: int, db: ReadDbSession, current_user: CurrentUser):
    """
    Event rating summary: aggregate + top 5 best + top 5 worst reviews.
    Direction: customer_to_event only.
    """
    base = select(Rating).where(
        Rating.event_id == event_id,
        Rating.direction == RatingDirection.customer_to_event,
    ).options(selectinload(Rating.rater))

    agg_q = select(
        func.avg(Rating.stars).label("avg_stars"),
        func.count(Rating.id).label("count"),
    ).where(
        Rating.event_id == event_id,
        Rating.direction == RatingDirection.customer_to_event,
    )
    agg = (await db.execute(agg_q)).one()

    best = (await db.execute(
        base.order_by(Rating.stars.desc(), Rating.created_at.desc()).limit(5)
    )).scalars().all()

    worst = (await db.execute(
        base.order_by(Rating.stars.asc(), Rating.created_at.desc()).limit(5)
    )).scalars().all()

    my_event_rating = (await db.execute(
        select(Rating).where(
            Rating.rater_user_id == current_user.id,
            Rating.event_id == event_id,
            Rating.direction == RatingDirection.customer_to_event,
        )
    )).scalar_one_or_none()

    my_organizer_rating = (await db.execute(
        select(Rating).where(
            Rating.rater_user_id == current_user.id,
            Rating.event_id == event_id,
            Rating.direction == RatingDirection.customer_to_organizer,
        )
    )).scalar_one_or_none()

    def _my(r: Rating | None) -> dict | None:
        return {"id": r.id, "stars": r.stars, "description": r.description} if r else None

    return {
        "avg_stars": round(float(agg.avg_stars), 1) if agg.avg_stars else None,
        "count": agg.count,
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
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if current_user.role != UserRole.admin and current_user.id != event.organizer_id:
        raise HTTPException(status_code=403, detail="Only the organizer can view the full review list")

    q = (
        select(Rating)
        .where(Rating.event_id == event_id)
        .options(selectinload(Rating.rater))
    )
    if direction:
        q = q.where(Rating.direction == RatingDirection(direction))
    q = q.order_by(Rating.created_at.desc())
    items = (await db.execute(q)).scalars().all()
    return [_fmt_rating(r) for r in items]


@router.get("/users/{user_id}/ratings-received")
async def get_user_ratings_summary(user_id: int, db: ReadDbSession, current_user: CurrentUser):
    """
    User rating summary: aggregate + top 5 best + top 5 worst reviews.
    For organizer profiles: customer_to_organizer + sponsor_to_organizer.
    For sponsor profiles: organizer_to_sponsor.
    """
    base = select(Rating).where(
        Rating.rated_user_id == user_id,
    ).options(selectinload(Rating.rater))

    agg_q = select(
        func.avg(Rating.stars).label("avg_stars"),
        func.count(Rating.id).label("count"),
    ).where(Rating.rated_user_id == user_id)
    agg = (await db.execute(agg_q)).one()

    best = (await db.execute(
        base.order_by(Rating.stars.desc(), Rating.created_at.desc()).limit(5)
    )).scalars().all()

    worst = (await db.execute(
        base.order_by(Rating.stars.asc(), Rating.created_at.desc()).limit(5)
    )).scalars().all()

    return {
        "avg_stars": round(float(agg.avg_stars), 1) if agg.avg_stars else None,
        "count": agg.count,
        "top_reviews": [_fmt_rating(r) for r in best],
        "worst_reviews": [_fmt_rating(r) for r in worst],
    }
