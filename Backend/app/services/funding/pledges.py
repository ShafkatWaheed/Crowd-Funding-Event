"""
Create pledge, unpledge, refunds, and list pledges.
"""
from datetime import datetime, timezone
from typing import Sequence

from app.logger import get_logger, log_step
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError
from app.models.event import EventStatus
from app.models.funding import Funding, FundingStatus
from app.models.user import User
from app.repositories.funding_repo import funding_repo

logger = get_logger("svc.funding.pledges")


async def pledge_preview(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    amount_cents: int,
    reserved_spots: int = 0,
) -> dict:
    """Compute an invoice preview before confirming a pledge."""
    from app.services import event as event_service
    event = await event_service.get_or_404(db, event_id)

    from app.services import platform_settings as settings_svc
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")
    platform_cut = amount_cents * funding_pct // 100
    net_to_organizer = amount_cents - platform_cut

    user_existing = await funding_repo.get_user_reserved_spots(db, event_id, user.id)
    max_per_user = event.max_reserved_spots_per_user
    available_for_user = max(0, max_per_user - user_existing)

    event_total = await funding_repo.get_total_reserved_spots(db, event_id)

    tier_availability: list[dict] = []
    if event.link_funding_to_tiers:
        tiers = await funding_repo.get_tiers_for_event(db, event_id)
        reservable_ids = [t.id for t in tiers if t.max_reserved_spots > 0]
        reserved_map = await funding_repo.get_reserved_spots_for_tiers(db, event_id, reservable_ids)
        for t in tiers:
            if t.max_reserved_spots <= 0:
                continue
            reserved = reserved_map.get(t.id, 0)
            tier_availability.append({
                "tier_id": t.id,
                "tier_name": t.name,
                "price_cents": t.price_cents,
                "max_reserved_spots": t.max_reserved_spots,
                "reserved_so_far": reserved,
                "available": max(0, t.max_reserved_spots - reserved),
            })

    return {
        "amount_cents": amount_cents,
        "reserved_spots": reserved_spots,
        "cost_per_spot_cents": event.min_pledge_cents,
        "platform_cut_cents": platform_cut,
        "net_to_organizer_cents": net_to_organizer,
        "funding_commission_percent": funding_pct,
        "available_spots_for_user": available_for_user,
        "event_total_reserved_spots": event_total,
        "link_funding_to_tiers": event.link_funding_to_tiers,
        "tier_availability": tier_availability,
    }


async def create_pledge(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
    amount_cents: int,
    reserved_spots: int = 0,
    tier_reservations: list[dict] | None = None,
) -> Funding:
    """Create a pledge with optional spot reservations.

    tier_reservations: list of {"tier_id": int, "spots": int} when
    event.link_funding_to_tiers is True.
    """
    log_step(logger, "Creating pledge", event_id=event_id, user_id=user.id, amount_cents=amount_cents, reserved_spots=reserved_spots)
    logger.debug("create_pledge params", extra={"tier_reservations": tier_reservations})
    if amount_cents <= 0:
        logger.warning("Pledge rejected: invalid amount", extra={"event_id": event_id, "user_id": user.id, "amount_cents": amount_cents})
        raise ConflictError("amount_cents must be greater than 0")
    if reserved_spots < 0:
        raise ConflictError("reserved_spots cannot be negative")

    from app.services import event as event_service
    event = await event_service.get_or_404(db, event_id)
    if event.status == EventStatus.cancelled:
        logger.warning("Pledge rejected: event cancelled", extra={"event_id": event_id, "user_id": user.id})
        raise ConflictError("Cannot pledge to a cancelled event")
    if event.status == EventStatus.completed:
        logger.warning("Pledge rejected: event ended", extra={"event_id": event_id, "user_id": user.id})
        raise ConflictError("Cannot pledge to an ended event")

    from app.services.age_verification import enforce_age_limit
    enforce_age_limit(user.birthday, event.age_restricted, event.min_age, "back this event")

    await funding_repo.advisory_lock(db, event_id)

    is_registered = await funding_repo.is_user_registered(db, event_id, user.id)
    is_guest = not is_registered

    if event.link_funding_to_tiers and tier_reservations:
        if is_guest:
            raise ConflictError("Only registered users can reserve spots. Please register first.")

        total_tier_spots = 0
        min_required_cents = 0

        tier_ids_needed = [tr["tier_id"] for tr in tier_reservations]
        tiers_map = await funding_repo.get_tiers_by_ids(db, event_id, tier_ids_needed)
        reserved_map = await funding_repo.get_reserved_spots_for_tiers(db, event_id, tier_ids_needed)

        for tr in tier_reservations:
            tid, spots = tr["tier_id"], tr["spots"]
            if spots <= 0:
                raise ConflictError(f"Spots must be >= 1 for tier {tid}")

            tier = tiers_map.get(tid)
            if tier is None:
                raise ConflictError(f"Ticket tier {tid} not found for this event")
            if tier.max_reserved_spots <= 0:
                raise ConflictError(f"Tier '{tier.name}' does not allow spot reservations")

            already_reserved = reserved_map.get(tid, 0)
            if already_reserved + spots > tier.max_reserved_spots:
                avail = max(0, tier.max_reserved_spots - already_reserved)
                raise ConflictError(
                    f"Tier '{tier.name}' only has {avail} reservable spot(s) left "
                    f"(limit {tier.max_reserved_spots}, already reserved {already_reserved})"
                )

            min_required_cents += spots * tier.price_cents
            total_tier_spots += spots

        reserved_spots = total_tier_spots

        if amount_cents < min_required_cents:
            raise ConflictError(
                f"Pledge amount must be at least {min_required_cents} cents "
                f"to cover the selected tier reservations"
            )

        total_reserved = await funding_repo.get_total_reserved_spots(db, event_id)
        tickets_sold = await funding_repo.count_tickets_sold(db, event_id)
        occupied = tickets_sold + total_reserved
        if occupied + reserved_spots > event.max_capacity:
            available = max(0, event.max_capacity - occupied)
            raise ConflictError(
                f"Not enough capacity to reserve {reserved_spots} spot(s). "
                f"Only {available} spot(s) available."
            )

    elif reserved_spots > 0:
        if is_guest:
            raise ConflictError("Only registered users can reserve spots. Please register first.")

        if event.max_reserved_spots_per_user <= 0:
            raise ConflictError("Spot reservation is not enabled for this event")

        min_required = reserved_spots * event.min_pledge_cents
        if amount_cents < min_required:
            raise ConflictError(
                f"Pledge amount must be at least {min_required} cents "
                f"to reserve {reserved_spots} spot(s) ({event.min_pledge_cents} cents/spot)"
            )

        user_existing_spots = await funding_repo.get_user_reserved_spots(db, event_id, user.id)
        if user_existing_spots + reserved_spots > event.max_reserved_spots_per_user:
            raise ConflictError(
                f"Cannot reserve {reserved_spots} more spot(s). "
                f"You already have {user_existing_spots} and the limit is {event.max_reserved_spots_per_user}."
            )

        total_reserved = await funding_repo.get_total_reserved_spots(db, event_id)
        tickets_sold = await funding_repo.count_tickets_sold(db, event_id)
        occupied = tickets_sold + total_reserved
        if occupied + reserved_spots > event.max_capacity:
            available = max(0, event.max_capacity - occupied)
            raise ConflictError(
                f"Not enough capacity to reserve {reserved_spots} spot(s). "
                f"Only {available} spot(s) available."
            )
    else:
        if amount_cents < event.min_pledge_cents:
            raise ConflictError(
                f"Pledge amount must be at least {event.min_pledge_cents} cents (event minimum)"
            )

    from app.services import platform_settings as settings_svc
    funding_pct = await settings_svc.get_int(db, "funding_commission_percent")
    if getattr(event, "community_rules", False):
        override = await settings_svc.get_str(db, "community_funding_commission_percent")
        if override is not None and override != "":
            funding_pct = int(override)
    platform_cut = amount_cents * funding_pct // 100
    net_to_organizer = amount_cents - platform_cut

    gateway_txn_id: str | None = None
    gateway_auth: str | None = None
    if amount_cents > 0:
        try:
            from app.services.payment_gateway import get_gateway
            gw = await get_gateway(db)
            result = await gw.charge(
                db,
                user_id=user.id,
                amount_cents=amount_cents,
                description=f"Pledge for event {event_id}",
                idempotency_key=f"pledge-{event_id}-{user.id}-{amount_cents}",
                commission_cents=platform_cut,
            )
            if result.status == "failed":
                reason = getattr(result, "failure_reason", "card declined")
                logger.warning("Pledge payment failed", extra={"event_id": event_id, "user_id": user.id, "amount_cents": amount_cents, "reason": reason})
                raise ConflictError(f"Payment failed: {reason}")
            gateway_txn_id = result.transaction_id
            gateway_auth = result.authorization_code
        except ConflictError:
            raise
        except Exception as exc:
            logger.warning("Pledge payment processing error", extra={"event_id": event_id, "user_id": user.id, "error": str(exc)})
            raise ConflictError(f"Payment processing error: {exc}")

    pledge = Funding(
        event_id=event_id,
        user_id=user.id,
        amount_cents=amount_cents,
        platform_cut_cents=platform_cut,
        net_to_organizer_cents=net_to_organizer,
        status=FundingStatus.pledged,
        is_guest=is_guest,
        reserved_spots=reserved_spots,
        gateway_transaction_id=gateway_txn_id,
        gateway_auth_code=gateway_auth,
    )
    pledge = await funding_repo.create_pledge(db, pledge)

    if event.link_funding_to_tiers and tier_reservations:
        await funding_repo.create_spot_reservations(db, pledge.id, tier_reservations)

    await funding_repo.set_receipt_number(db, pledge, event_id)

    try:
        eb_disc = await funding_repo.get_early_bird_discount(db, event_id)
        if eb_disc:
            now = datetime.now(timezone.utc)
            window_start = eb_disc.window_start or event.created_at
            if window_start <= now <= eb_disc.window_end:
                await funding_repo.set_early_bird(db, pledge)
    except Exception:
        pass

    try:
        await _check_milestone_snapshots(db, event)
    except Exception:
        pass

    try:
        from app.services import escrow as escrow_svc
        await escrow_svc.check_and_release_stage1(db, event_id=event_id)
    except Exception:
        pass

    logger.info("Pledge created", extra={"event_id": event_id, "user_id": user.id, "pledge_id": pledge.id, "amount_cents": amount_cents})

    # Add pledger to customer announcement channel (idempotent)
    try:
        from app.services.chat import channel_service
        await channel_service.add_member(db, event_id=event_id, user_id=user.id, channel_type="customer")
    except Exception:
        logger.debug("Could not add pledger to chat channel", extra={"event_id": event_id, "user_id": user.id})

    return pledge


async def unpledge(
    db: AsyncSession,
    *,
    event_id: int,
    user: User,
) -> dict:
    """
    Unpledge: mark all pledged fundings for this user+event as refund_processing,
    release reserved spots immediately, and enqueue ARQ jobs for completion.
    """
    log_step(logger, "Unpledging", event_id=event_id, user_id=user.id)

    refundable = await funding_repo.get_refundable_pledges(db, event_id, user.id)
    refunded_cents = sum(f.amount_cents for f in refundable)

    await funding_repo.mark_refund_processing(db, refundable)
    guest_total = await funding_repo.get_guest_pledged_total(db, event_id, user.id)
    await funding_repo.mark_refunded(db, refundable)

    logger.info("Unpledge completed", extra={"event_id": event_id, "user_id": user.id, "refunded_cents": refunded_cents, "pledges_refunded": len(refundable)})
    return {
        "refunded_cents": refunded_cents,
        "pledges_refunded": len(refundable),
        "guest_non_refundable_cents": int(guest_total),
        "status": "refund_processing" if refundable else "completed",
    }


async def _check_milestone_snapshots(db: AsyncSession, event) -> None:
    """Create snapshots for any milestones newly crossed by the current funding level."""
    if not event.funding_goal_cents or event.funding_goal_cents <= 0:
        return

    total_pledged = await funding_repo.get_total_pledged(db, event.id)
    current_pct = total_pledged / event.funding_goal_cents * 100

    milestone_discounts = await funding_repo.get_event_discounts_for_milestones(db, event.id)
    display_milestones = await funding_repo.get_funding_milestones(db, event.id)

    all_percents: set[int] = set()
    for d in milestone_discounts:
        if d.milestone_percent is not None:
            all_percents.add(d.milestone_percent)
    for m in display_milestones:
        all_percents.add(m.unlock_percent)

    if not all_percents:
        return

    existing_percents = await funding_repo.get_existing_snapshot_percents(db, event.id)
    pledger_ids = await funding_repo.get_pledger_ids(db, event.id)

    for pct in sorted(all_percents):
        if pct in existing_percents:
            continue
        if current_pct < pct:
            continue
        log_step(logger, "Milestone crossed", event_id=event.id, milestone_percent=pct, current_pct=round(current_pct, 2))
        await funding_repo.create_milestone_snapshot(db, event.id, pct, pledger_ids)


async def refund_all_pledges_for_event(db: AsyncSession, *, event_id: int, guest_refund: bool = True) -> int:
    """When an event is cancelled, mark all pledged fundings as refunded. Returns count."""
    log_step(logger, "Refunding all pledges for event", event_id=event_id, guest_refund=guest_refund)
    count = await funding_repo.bulk_refund_event(db, event_id, guest_refund=guest_refund)
    logger.info("Refund all pledges completed", extra={"event_id": event_id, "count": count})
    return count


async def refund_pledges_for_user_event(
    db: AsyncSession,
    *,
    event_id: int,
    user_id: int,
) -> int:
    """Mark all pledged fundings for this user+event as refunded. Returns count."""
    log_step(logger, "Refunding pledges for user", event_id=event_id, user_id=user_id)
    count = await funding_repo.bulk_refund_user_event(db, event_id, user_id)

    # Revoke chat access if no remaining financial ties
    try:
        from app.services.chat import conversation_service
        await conversation_service.revoke_access(db, user_id=user_id, event_id=event_id)
    except Exception:
        logger.debug("Could not revoke chat access after pledge refund", extra={"user_id": user_id, "event_id": event_id})

    return count


async def list_pledges_by_user(
    db: AsyncSession,
    *,
    user_id: int,
    offset: int = 0,
    limit: int = 20,
    sort_by: str = "newest",
) -> Sequence[Funding]:
    """List all pledges for a user."""
    return await funding_repo.list_by_user(db, user_id, offset=offset, limit=limit, sort_by=sort_by)


async def list_organizer_pledges(
    db: AsyncSession,
    *,
    organizer_id: int,
    status_filter: str | None = None,
    event_status: str | None = None,
    genre: str | None = None,
    event_id: int | None = None,
    offset: int = 0,
    limit: int = 20,
) -> Sequence[Funding]:
    """List all pledges made to events owned by organizer_id."""
    return await funding_repo.list_organizer_pledges(
        db,
        organizer_id=organizer_id,
        status_filter=status_filter,
        event_status=event_status,
        genre=genre,
        event_id=event_id,
        offset=offset,
        limit=limit,
    )


async def list_all_pledges_for_admin(
    db: AsyncSession,
    *,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
    status: str | None = None,
    is_donation: bool | None = None,
) -> tuple[Sequence[Funding], int]:
    """List fundings across events for admin, optionally filtered by status/donation. Returns (items, total)."""
    return await funding_repo.list_all_admin(
        db,
        offset=offset,
        limit=limit,
        search=search,
        status=status,
        is_donation=is_donation,
    )


async def refund_pledge_by_id(
    db: AsyncSession, *, event_id: int, funding_id: int,
) -> int:
    """Admin-only: mark a single pledge as refunded. Returns 1 if found and refunded.

    Idempotent: returns 1 if the pledge is already refunded or in refund_processing.
    """
    log_step(logger, "Refunding pledge by id", event_id=event_id, funding_id=funding_id)
    return await funding_repo.refund_single(db, funding_id, event_id)
