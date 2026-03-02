"""
Service-level tests for app.services.milestone (Phase 3).

Tests milestone CRUD, reactions, snapshots, and early bird discounts
by calling service functions directly against the DB session.
"""
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.event import Event, EventStatus
from app.models.milestone import (
    EarlyBirdDiscount,
    FundingMilestone,
    FundingMilestoneSnapshot,
    FundingMilestoneUser,
)
from app.models.user import User
from app.schemas.milestone import (
    EarlyBirdDiscountCreate,
    EarlyBirdDiscountUpdate,
    MilestoneCreate,
    MilestoneUpdate,
)
from app.services.milestone import (
    create_early_bird_discount,
    create_milestone,
    delete_early_bird_discount,
    delete_milestone,
    get_my_reaction,
    list_early_bird_discounts,
    list_milestones,
    list_snapshots,
    react_to_milestone,
    update_early_bird_discount,
    update_milestone,
)
from tests.conftest import SKIP_DB

pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# =====================================================================
# list_milestones
# =====================================================================


async def test_list_milestones_empty(
    db_session: AsyncSession,
    test_event_approved: Event,
):
    """list_milestones returns an empty list when no milestones exist."""
    result = await list_milestones(db_session, test_event_approved.id)
    assert result == []


async def test_list_milestones_with_data(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_milestone: FundingMilestone,
    test_pledge,
):
    """list_milestones returns milestones with is_unlocked computed from funding progress.

    test_pledge is 2000 cents on a 10000-cent goal = 20%.
    Milestone unlock_percent is 50 so it should NOT be unlocked.
    """
    result = await list_milestones(db_session, test_event_approved.id)
    assert len(result) >= 1
    ms = result[0]
    assert ms.title == "50% Funded"
    assert ms.unlock_percent == 50
    # 20% funded < 50% threshold => not unlocked
    assert ms.is_unlocked is False


# =====================================================================
# create_milestone
# =====================================================================


async def test_create_milestone_success(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Organizer can create a milestone on an approved event with a funding goal."""
    organizer = test_users["organizer"]
    data = MilestoneCreate(
        title="25% Funded",
        unlock_percent=25,
        description="Quarter way!",
    )
    result = await create_milestone(db_session, test_event_approved.id, data, organizer)
    assert result.title == "25% Funded"
    assert result.unlock_percent == 25
    assert result.event_id == test_event_approved.id
    assert result.description == "Quarter way!"


async def test_create_milestone_forbidden_not_organizer(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Non-organizer user cannot create a milestone (ForbiddenError)."""
    customer = test_users["customer"]
    data = MilestoneCreate(title="Nope", unlock_percent=10)
    with pytest.raises(ForbiddenError):
        await create_milestone(db_session, test_event_approved.id, data, customer)


async def test_create_milestone_no_funding_goal(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Creating a milestone on an event with no funding goal raises ConflictError."""
    organizer = test_users["organizer"]
    # Remove the funding goal
    test_event_approved.funding_goal_cents = None
    await db_session.flush()

    data = MilestoneCreate(title="No Goal", unlock_percent=10)
    with pytest.raises(ConflictError, match="funding goal"):
        await create_milestone(db_session, test_event_approved.id, data, organizer)


async def test_create_milestone_wrong_event_status(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Creating a milestone on an event with status selling_tickets raises ConflictError."""
    organizer = test_users["organizer"]
    test_event_approved.status = EventStatus.selling_tickets
    await db_session.flush()

    data = MilestoneCreate(title="Too Late", unlock_percent=50)
    with pytest.raises(ConflictError, match="before funding ends"):
        await create_milestone(db_session, test_event_approved.id, data, organizer)


# =====================================================================
# update_milestone
# =====================================================================


async def test_update_milestone_success(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Organizer can update an existing milestone."""
    organizer = test_users["organizer"]
    data = MilestoneUpdate(title="Updated Title", unlock_percent=60)
    result = await update_milestone(db_session, test_milestone.id, data, organizer)
    assert result.title == "Updated Title"
    assert result.unlock_percent == 60


async def test_update_milestone_not_found(
    db_session: AsyncSession,
    test_users: dict[str, User],
):
    """Updating a non-existent milestone raises NotFoundError."""
    organizer = test_users["organizer"]
    data = MilestoneUpdate(title="Ghost")
    with pytest.raises(NotFoundError):
        await update_milestone(db_session, 999999, data, organizer)


async def test_update_milestone_forbidden(
    db_session: AsyncSession,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Non-organizer cannot update a milestone."""
    customer = test_users["customer"]
    data = MilestoneUpdate(title="Nope")
    with pytest.raises(ForbiddenError):
        await update_milestone(db_session, test_milestone.id, data, customer)


async def test_update_milestone_wrong_status(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Updating a milestone when event is in selling_tickets status raises ConflictError."""
    organizer = test_users["organizer"]
    test_event_approved.status = EventStatus.selling_tickets
    await db_session.flush()

    data = MilestoneUpdate(title="Too Late")
    with pytest.raises(ConflictError, match="before funding ends"):
        await update_milestone(db_session, test_milestone.id, data, organizer)


# =====================================================================
# delete_milestone
# =====================================================================


async def test_delete_milestone_success(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Organizer can delete a milestone."""
    organizer = test_users["organizer"]
    await delete_milestone(db_session, test_milestone.id, organizer)
    # Verify it's gone
    result = await list_milestones(db_session, test_event_approved.id)
    assert all(m.id != test_milestone.id for m in result)


async def test_delete_milestone_not_found(
    db_session: AsyncSession,
    test_users: dict[str, User],
):
    """Deleting a non-existent milestone raises NotFoundError."""
    organizer = test_users["organizer"]
    with pytest.raises(NotFoundError):
        await delete_milestone(db_session, 999999, organizer)


async def test_delete_milestone_forbidden(
    db_session: AsyncSession,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Non-organizer cannot delete a milestone."""
    customer = test_users["customer"]
    with pytest.raises(ForbiddenError):
        await delete_milestone(db_session, test_milestone.id, customer)


async def test_delete_milestone_wrong_status(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Deleting a milestone when event is in selling_tickets status raises ConflictError."""
    organizer = test_users["organizer"]
    test_event_approved.status = EventStatus.selling_tickets
    await db_session.flush()

    with pytest.raises(ConflictError, match="before funding ends"):
        await delete_milestone(db_session, test_milestone.id, organizer)


# =====================================================================
# react_to_milestone
# =====================================================================


async def test_react_add_like(
    db_session: AsyncSession,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Adding a like reaction returns action='added' and increments like_count."""
    user = test_users["customer"]
    result = await react_to_milestone(db_session, test_milestone.id, user.id, "like")
    assert result["action"] == "added"
    assert result["reaction"] == "like"
    assert result["like_count"] == 1
    assert result["dislike_count"] == 0


async def test_react_add_dislike(
    db_session: AsyncSession,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Adding a dislike reaction returns action='added' and increments dislike_count."""
    user = test_users["customer"]
    result = await react_to_milestone(db_session, test_milestone.id, user.id, "dislike")
    assert result["action"] == "added"
    assert result["reaction"] == "dislike"
    assert result["like_count"] == 0
    assert result["dislike_count"] == 1


async def test_react_toggle_off(
    db_session: AsyncSession,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Reacting with the same reaction again removes it (toggle off)."""
    user = test_users["customer"]
    # First: add the like
    await react_to_milestone(db_session, test_milestone.id, user.id, "like")
    # Second: same reaction again => remove
    result = await react_to_milestone(db_session, test_milestone.id, user.id, "like")
    assert result["action"] == "removed"
    assert result["like_count"] == 0


async def test_react_switch_reaction(
    db_session: AsyncSession,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """Switching from like to dislike returns action='switched'."""
    user = test_users["customer"]
    # Add a like first
    await react_to_milestone(db_session, test_milestone.id, user.id, "like")
    # Switch to dislike
    result = await react_to_milestone(db_session, test_milestone.id, user.id, "dislike")
    assert result["action"] == "switched"
    assert result["reaction"] == "dislike"
    assert result["like_count"] == 0
    assert result["dislike_count"] == 1


# =====================================================================
# get_my_reaction
# =====================================================================


async def test_get_my_reaction_none(
    db_session: AsyncSession,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """get_my_reaction returns None when the user has no reaction."""
    user = test_users["customer"]
    result = await get_my_reaction(db_session, test_milestone.id, user.id)
    assert result["reaction"] is None


async def test_get_my_reaction_with_reaction(
    db_session: AsyncSession,
    test_milestone: FundingMilestone,
    test_users: dict[str, User],
):
    """get_my_reaction returns the reaction type when the user has reacted."""
    user = test_users["customer"]
    await react_to_milestone(db_session, test_milestone.id, user.id, "like")
    result = await get_my_reaction(db_session, test_milestone.id, user.id)
    assert result["reaction"] == "like"


# =====================================================================
# list_snapshots
# =====================================================================


async def test_list_snapshots_empty(
    db_session: AsyncSession,
    test_event_approved: Event,
):
    """list_snapshots returns an empty list when no snapshots exist."""
    result = await list_snapshots(db_session, test_event_approved.id)
    assert result == []


async def test_list_snapshots_with_data(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """list_snapshots returns snapshots with user_count."""
    # Create a snapshot manually
    snap = FundingMilestoneSnapshot(
        event_id=test_event_approved.id,
        milestone_percent=50,
        reached_at=datetime.now(timezone.utc),
    )
    db_session.add(snap)
    await db_session.flush()

    # Add a user to the snapshot
    snap_user = FundingMilestoneUser(
        snapshot_id=snap.id,
        user_id=test_users["customer"].id,
    )
    db_session.add(snap_user)
    await db_session.flush()

    result = await list_snapshots(db_session, test_event_approved.id)
    assert len(result) == 1
    assert result[0].milestone_percent == 50
    assert result[0].user_count == 1


# =====================================================================
# list_early_bird_discounts
# =====================================================================


async def test_list_early_bird_discounts_empty(
    db_session: AsyncSession,
    test_event_approved: Event,
):
    """list_early_bird_discounts returns an empty list when no discounts exist."""
    result = await list_early_bird_discounts(db_session, test_event_approved.id)
    assert result == []


async def test_list_early_bird_discounts_with_data(
    db_session: AsyncSession,
    test_event_approved: Event,
):
    """list_early_bird_discounts returns discounts for the event."""
    # Create discount with explicit window_start (timezone-aware) to avoid the
    # naive-vs-aware comparison bug in _eb_to_response when window_start is None.
    now = datetime.now(timezone.utc)
    eb = EarlyBirdDiscount(
        event_id=test_event_approved.id,
        applies_to="funding",
        window_start=now - timedelta(days=1),
        window_end=now + timedelta(days=7),
        discount_type="percent",
        value=10,
    )
    db_session.add(eb)
    await db_session.flush()

    result = await list_early_bird_discounts(db_session, test_event_approved.id)
    assert len(result) >= 1
    assert result[0].applies_to == "funding"
    assert result[0].discount_type == "percent"
    assert result[0].value == 10


# =====================================================================
# create_early_bird_discount
# =====================================================================


async def test_create_early_bird_discount_funding(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Organizer can create a funding early bird discount."""
    organizer = test_users["organizer"]
    # window_end must be <= funding_end_at
    window_end = test_event_approved.funding_end_at - timedelta(days=1)
    data = EarlyBirdDiscountCreate(
        applies_to="funding",
        window_end=window_end.isoformat(),
        discount_type="percent",
        value=15,
    )
    result = await create_early_bird_discount(
        db_session, test_event_approved.id, data, organizer
    )
    assert result.applies_to == "funding"
    assert result.discount_type == "percent"
    assert result.value == 15
    assert result.event_id == test_event_approved.id


async def test_create_early_bird_discount_tickets(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Organizer can create a tickets early bird discount."""
    organizer = test_users["organizer"]
    # window_end must be before start_time
    window_end = test_event_approved.start_time - timedelta(days=1)
    data = EarlyBirdDiscountCreate(
        applies_to="tickets",
        window_end=window_end.isoformat(),
        discount_type="fixed_cents",
        value=500,
    )
    result = await create_early_bird_discount(
        db_session, test_event_approved.id, data, organizer
    )
    assert result.applies_to == "tickets"
    assert result.discount_type == "fixed_cents"
    assert result.value == 500


async def test_create_early_bird_discount_forbidden(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Non-organizer cannot create an early bird discount."""
    customer = test_users["customer"]
    window_end = test_event_approved.funding_end_at - timedelta(days=1)
    data = EarlyBirdDiscountCreate(
        applies_to="funding",
        window_end=window_end.isoformat(),
        discount_type="percent",
        value=10,
    )
    with pytest.raises(ForbiddenError):
        await create_early_bird_discount(
            db_session, test_event_approved.id, data, customer
        )


async def test_create_early_bird_discount_percent_over_100(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Percent discount value > 100 raises ConflictError."""
    organizer = test_users["organizer"]
    window_end = test_event_approved.funding_end_at - timedelta(days=1)
    data = EarlyBirdDiscountCreate(
        applies_to="funding",
        window_end=window_end.isoformat(),
        discount_type="percent",
        value=150,
    )
    with pytest.raises(ConflictError, match="0-100"):
        await create_early_bird_discount(
            db_session, test_event_approved.id, data, organizer
        )


async def test_create_early_bird_discount_window_past_funding_deadline(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
):
    """Funding discount with window_end after funding_end_at raises ConflictError."""
    organizer = test_users["organizer"]
    window_end = test_event_approved.funding_end_at + timedelta(days=5)
    data = EarlyBirdDiscountCreate(
        applies_to="funding",
        window_end=window_end.isoformat(),
        discount_type="percent",
        value=10,
    )
    with pytest.raises(ConflictError, match="funding deadline"):
        await create_early_bird_discount(
            db_session, test_event_approved.id, data, organizer
        )


# =====================================================================
# update_early_bird_discount
# =====================================================================


async def test_update_early_bird_discount_success(
    db_session: AsyncSession,
    test_early_bird_discount: EarlyBirdDiscount,
    test_users: dict[str, User],
):
    """Organizer can update an existing early bird discount."""
    organizer = test_users["organizer"]
    data = EarlyBirdDiscountUpdate(value=20)
    result = await update_early_bird_discount(
        db_session, test_early_bird_discount.id, data, organizer
    )
    assert result.value == 20


async def test_update_early_bird_discount_not_found(
    db_session: AsyncSession,
    test_users: dict[str, User],
):
    """Updating a non-existent early bird discount raises NotFoundError."""
    organizer = test_users["organizer"]
    data = EarlyBirdDiscountUpdate(value=5)
    with pytest.raises(NotFoundError):
        await update_early_bird_discount(db_session, 999999, data, organizer)


async def test_update_early_bird_discount_forbidden(
    db_session: AsyncSession,
    test_early_bird_discount: EarlyBirdDiscount,
    test_users: dict[str, User],
):
    """Non-organizer cannot update an early bird discount."""
    customer = test_users["customer"]
    data = EarlyBirdDiscountUpdate(value=5)
    with pytest.raises(ForbiddenError):
        await update_early_bird_discount(
            db_session, test_early_bird_discount.id, data, customer
        )


async def test_update_early_bird_discount_percent_over_100(
    db_session: AsyncSession,
    test_early_bird_discount: EarlyBirdDiscount,
    test_users: dict[str, User],
):
    """Updating discount_type=percent with value>100 raises ConflictError."""
    organizer = test_users["organizer"]
    data = EarlyBirdDiscountUpdate(discount_type="percent", value=150)
    with pytest.raises(ConflictError, match="0-100"):
        await update_early_bird_discount(
            db_session, test_early_bird_discount.id, data, organizer
        )


# =====================================================================
# delete_early_bird_discount
# =====================================================================


async def test_delete_early_bird_discount_success(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_early_bird_discount: EarlyBirdDiscount,
    test_users: dict[str, User],
):
    """Organizer can delete an early bird discount."""
    organizer = test_users["organizer"]
    await delete_early_bird_discount(
        db_session, test_early_bird_discount.id, organizer
    )
    # Verify it's gone
    result = await list_early_bird_discounts(db_session, test_event_approved.id)
    assert all(d.id != test_early_bird_discount.id for d in result)


async def test_delete_early_bird_discount_not_found(
    db_session: AsyncSession,
    test_users: dict[str, User],
):
    """Deleting a non-existent early bird discount raises NotFoundError."""
    organizer = test_users["organizer"]
    with pytest.raises(NotFoundError):
        await delete_early_bird_discount(db_session, 999999, organizer)


async def test_delete_early_bird_discount_forbidden(
    db_session: AsyncSession,
    test_early_bird_discount: EarlyBirdDiscount,
    test_users: dict[str, User],
):
    """Non-organizer cannot delete an early bird discount."""
    customer = test_users["customer"]
    with pytest.raises(ForbiddenError):
        await delete_early_bird_discount(
            db_session, test_early_bird_discount.id, customer
        )
