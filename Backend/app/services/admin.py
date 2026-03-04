"""
Admin: list events for moderation, approve/reject, platform stats, validation warnings,
and the consolidated dashboard endpoint.
"""
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger, log_step
from app.models.event import Event, EventStatus
from app.models.notification import NotificationType
from app.models.user import UserRole
from app.repositories.admin_repo import admin_repo, _period_cutoff
from app.repositories.event_repo import event_repo
from app.repositories.user_repo import user_repo
from app.services import event as event_service
from app.services import notification_service as notif_svc
from app.services import audit as audit_svc

logger = get_logger("svc.admin")


async def list_users(
    db: AsyncSession,
    *,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
) -> tuple[list, int]:
    """List users (admin) with pagination + search. Returns (items, total)."""
    return await admin_repo.list_users(db, offset=offset, limit=limit, search=search)


async def list_events_for_admin(
    db: AsyncSession,
    *,
    status: str | None = None,
    offset: int = 0,
    limit: int = 20,
    search: str | None = None,
) -> tuple[list, int]:
    """List events for admin view with pagination + search. Returns (items, total)."""
    log_step(logger, "List events for admin", status=status, offset=offset, limit=limit, search=search)
    return await admin_repo.list_events(db, status=status, offset=offset, limit=limit, search=search)


async def approve_or_reject_event(
    db: AsyncSession,
    event_id: int,
    approved: bool,
) -> Event:
    """
    Approve event (set status to approved) or reject (set back to draft).
    Returns the updated event. Raises NotFoundError if event not found.
    """
    log_step(logger, "Approve or reject event", event_id=event_id, approved=approved)
    from app.core.exceptions import ConflictError
    from app.services.escrow_base import organizer_has_verified_bank

    event = await event_service.get_or_404(db, event_id)
    if approved:
        if not await organizer_has_verified_bank(db, event.organizer_id):
            logger.warning("Approve rejected: organizer lacks verified bank", extra={"event_id": event_id, "organizer_id": event.organizer_id})
            raise ConflictError(
                "Organizer must have a verified bank account before the event can be approved"
            )
        # Event must have a funding goal or at least one ticket tier
        has_funding = event.funding_goal_cents is not None and event.funding_goal_cents > 0
        tier_count = await admin_repo.count_tiers(db, event.id)
        if not has_funding and tier_count == 0:
            logger.warning("Approve rejected: no funding goal or ticket tiers", extra={"event_id": event_id})
            raise ConflictError(
                "Event must have a funding goal or at least one ticket tier before approval"
            )
        await event_repo.update_fields(db, event, status=EventStatus.approved)
        logger.info("Event approved", extra={"event_id": event_id})
    else:
        await event_repo.update_fields(db, event, status=EventStatus.draft)
        logger.info("Event rejected", extra={"event_id": event_id})
    return event


async def resolve_review(
    db: AsyncSession,
    event: Event,
    *,
    target_status: str,
    notes: str | None,
    admin_email: str,
) -> dict:
    """Resolve an under_review event — set new status, update review log, send notification."""
    from app.core.exceptions import ConflictError
    if event.status != EventStatus.under_review:
        raise ConflictError(f"Event is not under review (current: {event.status.value})")
    allowed = {s.value for s in EventStatus} - {"under_review"}
    if target_status not in allowed:
        raise ConflictError(f"Invalid target status '{target_status}'")

    await event_repo.update_fields(
        db, event,
        status=EventStatus(target_status),
        review_notes=notes or f"Resolved by admin → {target_status}",
        review_log=(event.review_log or []) + [{
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "actor": f"admin:{admin_email}",
            "action": "resolved",
            "from_status": "under_review",
            "to_status": target_status,
            "message": notes or f"Resolved → {target_status}",
        }],
    )

    notif_msg = f'Your event "{event.title}" has been reviewed and moved to {target_status.replace("_", " ")}.'
    if notes:
        notif_msg += f" Admin notes: {notes}"
    await notif_svc.create_notification(
        db, user_id=event.organizer_id,
        type=NotificationType.event_approved,
        title="Event Review Resolved",
        message=notif_msg,
        data={"event_id": event.id},
    )
    return {"ok": True, "event_id": event.id, "status": event.status.value}


async def set_policy_overrides(
    db: AsyncSession,
    event: Event,
    *,
    body,
    admin_id: int,
) -> dict:
    """Set or clear admin per-event policy overrides. Returns effective policy."""
    changes: dict[str, dict] = {}
    for field in [
        "admin_override_waitlist_max_size",
        "admin_override_event_max_images",
        "admin_override_max_posts_per_day",
        "admin_override_max_co_organizers",
        "admin_override_refund_deadline_percent",
    ]:
        new_val = getattr(body, field)
        old_val = getattr(event, field, None)
        if new_val != old_val:
            changes[field] = {"old": old_val, "new": new_val}

    if changes:
        await event_repo.update_fields(db, event, **{f: c["new"] for f, c in changes.items()})
        await audit_svc.log_action(
            db,
            admin_id=admin_id,
            action="admin_policy_override",
            target_type="event",
            target_id=event.id,
            details=changes,
        )
        await event_repo.flush_and_refresh(db, event)

    policy = await event_service.get_effective_policy(db, event)
    return {
        "event_id": event.id,
        "overrides": {
            "admin_override_waitlist_max_size": event.admin_override_waitlist_max_size,
            "admin_override_event_max_images": event.admin_override_event_max_images,
            "admin_override_max_posts_per_day": event.admin_override_max_posts_per_day,
            "admin_override_max_co_organizers": event.admin_override_max_co_organizers,
            "admin_override_refund_deadline_percent": event.admin_override_refund_deadline_percent,
        },
        "effective_policy": policy,
    }


def compute_event_warnings(event: Event) -> list[str]:
    """Inspect an Event and return a list of human-readable warning strings."""
    now = datetime.now(timezone.utc)
    warnings: list[str] = []

    if not event.description or len(event.description.strip()) < 20:
        warnings.append("Description is missing or too short")
    if not event.funding_goal_cents and event.funding_end_at:
        warnings.append("Funding deadline set but goal is $0")
    if event.funding_goal_cents and not event.funding_end_at:
        warnings.append("Funding goal set but no funding deadline")
    if event.max_capacity == 0:
        warnings.append("Capacity is 0")
    if (
        not event.ticket_strategy_id
        and event.status in (EventStatus.selling_tickets, EventStatus.approved)
        and not event.funding_end_at
    ):
        warnings.append("No ticket tier assigned")

    def _tz(dt: datetime | None) -> datetime | None:
        if dt is None:
            return None
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)

    if event.start_time and _tz(event.start_time) < now:
        if event.status in (EventStatus.draft, EventStatus.pending_approval, EventStatus.under_review):
            warnings.append("Event start date is in the past")
    if event.end_time and event.start_time and _tz(event.end_time) <= _tz(event.start_time):
        warnings.append("End time is before or equal to start time")
    if event.funding_end_at and _tz(event.funding_end_at) < now:
        if event.status in (EventStatus.draft, EventStatus.pending_approval):
            warnings.append("Funding deadline already passed")
    if not event.genre:
        warnings.append("No genre/category set")

    return warnings


async def get_user_detail(db: AsyncSession, user_id: int):
    """Fetch role-based user detail for admin view. Returns AdminUserDetailResponse."""
    from collections import defaultdict
    from app.core.exceptions import NotFoundError
    from app.models.sponsor import BidStatus
    from app.repositories.sponsor_repo import sponsor_repo
    from app.repositories.ticket_repo import ticket_repo
    from app.services import ticket as ticket_service
    from app.services import funding as funding_service
    from app.services import sponsor as sponsor_svc
    from app.schemas.admin import (
        AdminUserDetailResponse,
        AdminUserDetailTicketItem,
        AdminUserDetailPledgeItem,
        AdminUserDetailEventItem,
        AdminUserDetailSponsorItem,
        AdminUserDetailDiscountItem,
        AdminSponsorshipBidItem,
        AdminSponsorshipEventItem,
    )

    user = await user_repo.get_by_id(db, user_id)
    if not user:
        raise NotFoundError("User", user_id)

    base = {
        "id": user.id,
        "email": user.email,
        "display_name": user.display_name,
        "role": user.role.value,
        "created_at": user.created_at,
    }

    if user.role == UserRole.customer:
        tickets = await ticket_service.list_tickets_for_user_admin(db, user_id=user_id)
        pledges = await funding_service.list_pledges_by_user(db, user_id=user_id, limit=200)
        events = await event_repo.list_events_for_customer_registrations(db, user_id)

        ticket_counts: dict[int, int] = {}
        for t in tickets:
            ticket_counts[t.event_id] = ticket_counts.get(t.event_id, 0) + 1
        pledge_counts: dict[int, int] = {}
        pledge_totals: dict[int, int] = {}
        reserved_spots: dict[int, int] = {}
        donation_counts: dict[int, int] = {}
        donation_totals: dict[int, int] = {}
        for p in pledges:
            if getattr(p, "is_guest", False):
                donation_counts[p.event_id] = donation_counts.get(p.event_id, 0) + 1
                donation_totals[p.event_id] = donation_totals.get(p.event_id, 0) + p.amount_cents
            else:
                pledge_counts[p.event_id] = pledge_counts.get(p.event_id, 0) + 1
                pledge_totals[p.event_id] = pledge_totals.get(p.event_id, 0) + p.amount_cents
                spots = getattr(p, "reserved_spots", 0) or 0
                reserved_spots[p.event_id] = reserved_spots.get(p.event_id, 0) + spots

        return AdminUserDetailResponse(
            **base,
            tickets=[
                AdminUserDetailTicketItem(
                    id=t.id, event_id=t.event_id,
                    event_title=t.event.title if t.event else None,
                    tier_name=t.ticket_tier.name if t.ticket_tier else None,
                    amount_paid_cents=t.amount_paid_cents, status=t.status.value,
                    created_at=t.created_at,
                )
                for t in tickets
            ],
            pledges=[
                AdminUserDetailPledgeItem(
                    id=p.id, event_id=p.event_id,
                    event_title=p.event.title if p.event else None,
                    user_display_name=user.display_name,
                    amount_cents=p.amount_cents, status=p.status.value,
                    is_guest=getattr(p, "is_guest", False),
                    reserved_spots=getattr(p, "reserved_spots", 0) or 0,
                    created_at=p.created_at,
                )
                for p in pledges
            ],
            events=[
                AdminUserDetailEventItem(
                    id=e.id, title=e.title, status=e.status.value,
                    organizer_id=e.organizer_id, description=e.description,
                    genre=e.genre, max_capacity=e.max_capacity,
                    registration_type=e.registration_type.value if e.registration_type else None,
                    registration_count=e.registration_count or 0,
                    funding_goal_cents=e.funding_goal_cents,
                    min_pledge_cents=e.min_pledge_cents or 0,
                    ticket_strategy_name=e.ticket_strategy.name if e.ticket_strategy else None,
                    venue_name=e.venue.name if e.venue else None,
                    venue_address=f"{e.venue.address}, {e.venue.city}" if e.venue and e.venue.address else (e.venue.name if e.venue else None),
                    created_at=e.created_at, start_time=e.start_time,
                    end_time=e.end_time, funding_end_at=e.funding_end_at,
                    has_schedule=e.has_schedule or False,
                    community_rules=e.community_rules or False,
                    ticket_tiers_count=len(e.ticket_tiers) if e.ticket_tiers else 0,
                    sponsorship_categories_count=len(e.sponsorship_categories) if e.sponsorship_categories else 0,
                    milestones_count=len(e.milestones) if e.milestones else 0,
                    user_ticket_count=ticket_counts.get(e.id, 0),
                    user_pledge_count=pledge_counts.get(e.id, 0),
                    user_pledge_total_cents=pledge_totals.get(e.id, 0),
                    user_reserved_spots=reserved_spots.get(e.id, 0),
                    user_donation_count=donation_counts.get(e.id, 0),
                    user_donation_total_cents=donation_totals.get(e.id, 0),
                )
                for e in events
            ],
        )

    if user.role == UserRole.organizer:
        events = await event_repo.list_events_for_organizer_admin(db, user_id)
        ticket_sales = await ticket_service.list_organizer_ticket_sales(
            db, organizer_id=user_id, limit=200,
        )
        pledges = await funding_service.list_organizer_pledges(
            db, organizer_id=user_id, limit=200,
        )
        sponsors = await sponsor_svc.get_organizer_sponsors(db, organizer_id=user_id, limit=100)
        discounts = await ticket_repo.list_discounts_for_organizer(db, user_id)

        event_ids = [e.id for e in events]
        sponsor_bids_list: list[AdminSponsorshipEventItem] = []
        if event_ids:
            bid_rows = await sponsor_repo.get_admin_sponsor_bids_for_events(db, event_ids)
            events_by_id = {e.id: e for e in events}
            grouped: dict[int, list] = defaultdict(list)
            for r in bid_rows:
                grouped[r.event_id].append(
                    AdminSponsorshipBidItem(
                        bid_id=r.bid_id, category_id=r.cat_id,
                        category_name=r.cat_name, amount_cents=r.amount_cents,
                        status=r.status.value if hasattr(r.status, "value") else str(r.status),
                        can_refund=r.status == BidStatus.paid,
                    )
                )
            for eid, bids in grouped.items():
                evt = events_by_id.get(eid)
                sponsor_bids_list.append(
                    AdminSponsorshipEventItem(
                        event_id=eid,
                        event_title=evt.title if evt else None,
                        bids=bids,
                    )
                )

        escrows_list: list[dict] = []
        if event_ids:
            event_title_map = {e.id: e.title for e in events}
            escrow_rows = await sponsor_repo.get_fund_escrows_for_events(db, event_ids)
            for esc in escrow_rows:
                total_released = esc.stage1_released_cents + esc.stage2_released_cents + esc.stage3_released_cents
                escrows_list.append({
                    "id": esc.id,
                    "event_id": esc.event_id,
                    "event_title": event_title_map.get(esc.event_id),
                    "organizer_name": user.display_name,
                    "organizer_email": user.email,
                    "total_held_cents": esc.total_held_cents,
                    "total_released_cents": total_released,
                    "remaining_cents": max(0, esc.total_held_cents - total_released),
                    "status": esc.status.value,
                    "stage1_released_at": esc.stage1_released_at.isoformat() if esc.stage1_released_at else None,
                    "stage2_released_at": esc.stage2_released_at.isoformat() if esc.stage2_released_at else None,
                    "stage3_released_at": esc.stage3_released_at.isoformat() if esc.stage3_released_at else None,
                })

        return AdminUserDetailResponse(
            **base,
            events=[
                AdminUserDetailEventItem(
                    id=e.id, title=e.title, status=e.status.value,
                    organizer_id=e.organizer_id, description=e.description,
                    genre=e.genre, max_capacity=e.max_capacity,
                    registration_type=e.registration_type.value if e.registration_type else None,
                    registration_count=e.registration_count or 0,
                    funding_goal_cents=e.funding_goal_cents,
                    min_pledge_cents=e.min_pledge_cents or 0,
                    ticket_strategy_name=e.ticket_strategy.name if e.ticket_strategy else None,
                    venue_name=e.venue.name if e.venue else None,
                    venue_address=f"{e.venue.address}, {e.venue.city}" if e.venue and e.venue.address else (e.venue.name if e.venue else None),
                    review_notes=e.review_notes,
                    review_log=e.review_log or [],
                    validation_warnings=compute_event_warnings(e),
                    cancellation_reason=e.cancellation_reason,
                    pending_extension=e.pending_extension,
                    pending_cancellation=e.pending_cancellation,
                    created_at=e.created_at, start_time=e.start_time,
                    end_time=e.end_time, funding_end_at=e.funding_end_at,
                    has_schedule=e.has_schedule or False,
                    community_rules=e.community_rules or False,
                    ticket_tiers_count=len(e.ticket_tiers) if e.ticket_tiers else 0,
                    sponsorship_categories_count=len(e.sponsorship_categories) if e.sponsorship_categories else 0,
                    milestones_count=len(e.milestones) if e.milestones else 0,
                )
                for e in events
            ],
            ticket_sales=[
                AdminUserDetailTicketItem(
                    id=s.id, event_id=s.event_id,
                    event_title=s.event.title if s.event else None,
                    tier_name=s.ticket_tier.name if s.ticket_tier else None,
                    amount_paid_cents=s.amount_paid_cents, status=s.status.value,
                    created_at=s.created_at,
                    attendee_display_name=s.user.display_name if s.user else None,
                )
                for s in ticket_sales
            ],
            pledges=[
                AdminUserDetailPledgeItem(
                    id=p.id, event_id=p.event_id,
                    event_title=p.event.title if p.event else None,
                    user_display_name=p.user.display_name if p.user else None,
                    amount_cents=p.amount_cents, status=p.status.value,
                    is_guest=getattr(p, "is_guest", False),
                    reserved_spots=getattr(p, "reserved_spots", 0) or 0,
                    created_at=p.created_at,
                )
                for p in pledges
            ],
            sponsors=[
                AdminUserDetailSponsorItem(
                    sponsor_user_id=s["sponsor_user_id"],
                    company_name=s.get("company_name"),
                    contact_name=s.get("contact_name"),
                    total_bids=s.get("total_bids", 0),
                    total_amount_cents=s.get("total_amount_cents", 0),
                )
                for s in sponsors
            ],
            discounts=[
                AdminUserDetailDiscountItem(
                    event_id=d.event_id,
                    event_title=d.event.title if d.event else None,
                    user_id=d.user_id,
                    user_display_name=d.user.display_name if d.user else None,
                    discount_type=d.discount_type, value=d.value,
                )
                for d in discounts
            ],
            sponsor_bids=sponsor_bids_list if sponsor_bids_list else None,
            escrows=escrows_list if escrows_list else None,
        )

    if user.role == UserRole.sponsor:
        sponsorships = await sponsor_svc.get_sponsor_bids_detail_for_admin(db, sponsor_user_id=user_id)
        tickets = await ticket_service.list_tickets_for_user_admin(db, user_id=user_id)
        pledges = await funding_service.list_pledges_by_user(db, user_id=user_id, limit=200)
        return AdminUserDetailResponse(
            **base,
            sponsorships=[
                AdminSponsorshipEventItem(
                    event_id=sp["event_id"],
                    event_title=sp["event_title"],
                    bids=[
                        AdminSponsorshipBidItem(
                            bid_id=b["bid_id"], category_id=b["category_id"],
                            category_name=b["category_name"],
                            amount_cents=b["amount_cents"],
                            status=b["status"], can_refund=b["can_refund"],
                        )
                        for b in sp["bids"]
                    ],
                )
                for sp in sponsorships
            ],
            tickets=[
                AdminUserDetailTicketItem(
                    id=t.id, event_id=t.event_id,
                    event_title=t.event.title if t.event else None,
                    tier_name=t.ticket_tier.name if t.ticket_tier else None,
                    amount_paid_cents=t.amount_paid_cents, status=t.status.value,
                    created_at=t.created_at,
                )
                for t in tickets
            ],
            pledges=[
                AdminUserDetailPledgeItem(
                    id=p.id, event_id=p.event_id,
                    event_title=p.event.title if p.event else None,
                    user_display_name=user.display_name,
                    amount_cents=p.amount_cents, status=p.status.value,
                    is_guest=getattr(p, "is_guest", False),
                    reserved_spots=getattr(p, "reserved_spots", 0) or 0,
                    created_at=p.created_at,
                )
                for p in pledges
            ],
        )

    return AdminUserDetailResponse(**base)


async def get_stats(db: AsyncSession) -> dict:
    """
    Return platform stats: events_total, events_pending, events_live, users_total,
    total_ticket_commission_cents, total_funding_commission_cents, total_escrow_held_cents.
    """
    return await admin_repo.get_stats(db)


# ---------------------------------------------------------------------------
# Dashboard (admin home tab) -- consolidated, filterable
# ---------------------------------------------------------------------------

async def get_dashboard(
    db: AsyncSession,
    period: str = "30d",
    genre: str | None = None,
    status: str | None = None,
) -> dict:
    now = datetime.now(timezone.utc)
    cutoff = _period_cutoff(period)

    # Build shared event filter
    event_filter = admin_repo._build_event_filter(cutoff, genre, status)

    # Subquery: filtered event ids
    filtered_events_sq = admin_repo.build_filtered_events_sq(cutoff, genre, status)

    # 1. KPIs
    ticket_agg = await admin_repo.get_dashboard_ticket_agg(db, filtered_events_sq)
    funding_agg = await admin_repo.get_dashboard_funding_agg(db, filtered_events_sq)
    escrow_agg = await admin_repo.get_dashboard_escrow_agg(db, filtered_events_sq)

    events_total, events_live, users_total = await admin_repo.get_dashboard_event_counts(
        db, event_filter, now
    )

    total_tickets = int(ticket_agg.cnt)
    total_refunded = int(ticket_agg.refunded)
    refund_rate = (total_refunded / total_tickets * 100) if total_tickets > 0 else 0.0
    avg_ticket = int(ticket_agg.ts) // total_tickets if total_tickets > 0 else 0

    funded_events_count, goal_total, goal_hit = await admin_repo.get_dashboard_funding_goal_stats(
        db, event_filter, filtered_events_sq
    )
    avg_funding = int(funding_agg.fa) // int(funded_events_count) if funded_events_count > 0 else 0
    goal_hit_rate = (goal_hit / goal_total * 100) if goal_total > 0 else 0.0

    kpis = {
        "total_revenue_cents": int(ticket_agg.tc) + int(funding_agg.fc),
        "ticket_commission_cents": int(ticket_agg.tc),
        "funding_commission_cents": int(funding_agg.fc),
        "total_ticket_sales_cents": int(ticket_agg.ts),
        "total_funding_cents": int(funding_agg.fa),
        "escrow_held_cents": int(escrow_agg.held),
        "escrow_released_cents": int(escrow_agg.released),
        "tickets_sold": total_tickets,
        "pledges_made": int(funding_agg.cnt),
        "events_total": events_total,
        "events_live": events_live,
        "users_total": users_total,
        "avg_ticket_price_cents": avg_ticket,
        "avg_funding_per_event_cents": avg_funding,
        "refund_rate_percent": round(refund_rate, 1),
        "funding_goal_hit_rate_percent": round(goal_hit_rate, 1),
    }

    # 2. Available filters
    avail_genres, avail_statuses = await admin_repo.get_dashboard_available_filters(
        db, cutoff, genre
    )

    # 3-5. Breakdowns
    by_genre = await admin_repo.get_dashboard_by_genre(db, filtered_events_sq)
    by_status = await admin_repo.get_dashboard_by_status(db, filtered_events_sq)
    by_escrow_status = await admin_repo.get_dashboard_by_escrow_status(db, filtered_events_sq)

    # 6. Time series
    time_series = await admin_repo.get_dashboard_time_series(db, filtered_events_sq, cutoff)

    # 7. Top events
    top_events = await admin_repo.get_dashboard_top_events(db, filtered_events_sq)

    # 8. Action items
    action_items = await admin_repo.get_dashboard_action_items(db)

    return {
        "kpis": kpis,
        "available_filters": {
            "genres": avail_genres,
            "statuses": avail_statuses,
        },
        "by_genre": by_genre,
        "by_status": by_status,
        "by_escrow_status": by_escrow_status,
        "time_series": time_series,
        "top_events": top_events,
        "action_items": action_items,
    }
