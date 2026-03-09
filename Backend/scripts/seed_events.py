"""
Pre-prod event seed script.

Creates 1000 events per EventStatus (9000 total) with logically consistent
date/field configurations for each status. All seeded rows are identified by the
``[SEED]`` title prefix and a dedicated seed organiser account.

Usage::

    # Seed all 9 statuses (1000 events each)
    python scripts/seed_events.py --seed

    # Seed with custom count
    python scripts/seed_events.py --seed --count 50

    # Seed a single status only
    python scripts/seed_events.py --seed --status live

    # Remove all seeded data (events + seed organiser + seed venue)
    python scripts/seed_events.py --clear

    # Remove only a specific status
    python scripts/seed_events.py --clear --status live

Remote pre-prod via SSH tunnel::

    ssh -L 5433:localhost:5432 deploy -N &
    DATABASE_URL=postgresql+asyncpg://postgres:pw@localhost:5433/event_db \\
        python scripts/seed_events.py --seed --count 1000
"""
import argparse
import asyncio
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import delete, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.models.event import Event, EventStatus, RegistrationType
from app.models.ticket import TicketTier
from app.models.user import User, UserRole
from app.models.venue import Venue

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SEED_MARKER = "[SEED]"
SEED_ORGANIZER_EMAIL = "seed.organizer@seed.local"
SEED_ORGANIZER_UID = "seed-organizer-firebase-uid"

DEFAULT_COUNT = 1000
BATCH_SIZE = 500

GENRES = [
    "music", "tech", "sports", "arts", "food",
    "charity", "education", "business", "community", "other",
]

# World-spanning seed venues — one per city, cycled across all events.
# (name, address, city, province_or_state, max_capacity, lat, lng)
SEED_VENUES: list[tuple] = [
    ("[SEED] The Roundhouse",          "101 Roundhouse Way",          "London",        "England",          5_000,   51.5337,   -0.1760),
    ("[SEED] Palais des Congrès",      "2 Place de la Porte Maillot", "Paris",         "Île-de-France",    3_500,   48.8784,    2.2833),
    ("[SEED] Tempodrom",               "Möckernstraße 10",            "Berlin",        "Berlin",           3_000,   52.5023,   13.3757),
    ("[SEED] Hammersmith Apollo",      "45 Queen Caroline St",        "London",        "England",          5_039,   51.4929,   -0.2242),
    ("[SEED] Madison Square Garden",   "4 Pennsylvania Plaza",        "New York",      "NY",              20_789,   40.7505,  -73.9934),
    ("[SEED] The Fillmore",            "1805 Geary Blvd",             "San Francisco", "CA",               1_150,   37.7842, -122.4328),
    ("[SEED] Rogers Centre",           "1 Blue Jays Way",             "Toronto",       "ON",              55_000,   43.6414,  -79.3894),
    ("[SEED] Olympic Stadium",         "4141 Pierre-De Coubertin",    "Montreal",      "QC",              61_004,   45.5626,  -73.5514),
    ("[SEED] Saitama Super Arena",     "8 Shintoshin",                "Saitama",       "Saitama",         37_000,   35.8951,  139.6306),
    ("[SEED] Tokyo Dome",              "1-3-61 Koraku",               "Tokyo",         "Tokyo",           55_000,   35.7056,  139.7519),
    ("[SEED] Marvel Stadium",          "740 Bourke St",               "Melbourne",     "VIC",             53_359,  -37.8162,  144.9475),
    ("[SEED] Accor Stadium",           "Edwin Flack Ave",             "Sydney",        "NSW",             83_500,  -33.8473,  151.0633),
    ("[SEED] Coca-Cola Arena",         "City Walk",                   "Dubai",         "Dubai",           17_000,   25.1855,   55.2398),
    ("[SEED] Allianz Parque",          "Av. Francisco Matarazzo 1705","São Paulo",     "SP",              43_713,  -23.5274,  -46.6681),
    ("[SEED] Foro Sol",                "Av. Viaducto Río de la Piedad","Mexico City",  "CDMX",            65_000,   19.3592,  -99.0864),
    ("[SEED] DY Patil Stadium",        "Sector 4, Nerul",             "Mumbai",        "Maharashtra",     55_000,   19.0468,   73.0157),
    ("[SEED] Cape Town Stadium",       "Fritz Sonnenberg Rd",         "Cape Town",     "Western Cape",    64_500,  -33.9034,   18.4106),
    ("[SEED] Johannesburg Stadium",    "Nasrec Rd",                   "Johannesburg",  "Gauteng",         94_700,  -26.2343,   27.9826),
    ("[SEED] Azteca Stadium",          "Calzada de Tlalpan 3465",     "Mexico City",   "CDMX",           105_000,   19.3030,  -99.1500),
    ("[SEED] Rod Laver Arena",         "Melbourne Park",              "Melbourne",     "VIC",             14_820,  -37.8215,  144.9789),
]

ALL_STATUSES = [s.value for s in EventStatus]

# Statuses that require ticket tiers (tickets are actively being sold)
TICKETED_STATUSES = {EventStatus.selling_tickets, EventStatus.live}

# Tiers inserted for every event in a TICKETED_STATUS
SEED_TIERS = [
    {"name": "General Admission", "price_cents": 2500, "display_order": 0, "max_reserved_spots": 500},
    {"name": "VIP",               "price_cents": 7500, "display_order": 1, "max_reserved_spots": 100},
    {"name": "Early Bird",        "price_cents": 1500, "display_order": 2, "max_reserved_spots": 200},
]

# ---------------------------------------------------------------------------
# Engine setup (mirrors manage_users.py)
# ---------------------------------------------------------------------------

_db_url = os.environ.get("DATABASE_URL")
if _db_url:
    engine = create_async_engine(_db_url, echo=False)
else:
    from app.db.base import async_engine as engine  # type: ignore[assignment]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _chunks(lst: list, n: int):
    for i in range(0, len(lst), n):
        yield lst[i : i + n]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _event_fields(status: EventStatus, i: int, now: datetime) -> dict:
    """Return date/field dict appropriate for *status* at index *i*."""
    genre = GENRES[i % len(GENRES)]
    base: dict = {
        "title": f"{SEED_MARKER} {genre.capitalize()} Event #{i + 1} ({status.value})",
        "description": (
            f"Seeded pre-prod event #{i + 1} for status={status.value!r}. "
            "Safe to delete — run 'seed_events.py --clear' to remove."
        ),
        "min_pledge_cents": 500,
        "max_capacity": 100 + (i % 900),
        "registration_type": RegistrationType.open,
        "genre": genre,
        "status": status,
    }

    # Spread dates so events don't all land at exactly the same timestamp
    day_jitter = i % 30
    hour_jitter = i % 6

    if status == EventStatus.draft:
        base.update(
            funding_goal_cents=100_000 + i * 100,
            funding_end_at=now + timedelta(days=30 + day_jitter),
            start_time=now + timedelta(days=65 + day_jitter),
            end_time=now + timedelta(days=65 + day_jitter, hours=4 + hour_jitter),
        )

    elif status == EventStatus.pending_approval:
        base.update(
            funding_goal_cents=100_000 + i * 100,
            funding_end_at=now + timedelta(days=30 + day_jitter),
            start_time=now + timedelta(days=65 + day_jitter),
            end_time=now + timedelta(days=65 + day_jitter, hours=4 + hour_jitter),
        )

    elif status == EventStatus.approved:
        base.update(
            funding_goal_cents=100_000 + i * 100,
            funding_end_at=now + timedelta(days=30 + day_jitter),
            start_time=now + timedelta(days=65 + day_jitter),
            end_time=now + timedelta(days=65 + day_jitter, hours=4 + hour_jitter),
        )

    elif status == EventStatus.selling_tickets:
        # Funding ended; event date is in the future
        base.update(
            funding_goal_cents=100_000,
            funding_end_at=now - timedelta(days=5 + i % 10),
            start_time=now + timedelta(days=20 + day_jitter),
            end_time=now + timedelta(days=20 + day_jitter, hours=4 + hour_jitter),
        )

    elif status == EventStatus.waiting_event_date:
        # Funding ended; organiser has not set the event date yet
        base.update(
            funding_goal_cents=100_000,
            funding_end_at=now - timedelta(days=5 + i % 10),
        )

    elif status == EventStatus.live:
        # Currently happening — no funding component
        base.update(
            start_time=now - timedelta(hours=1 + i % 3),
            end_time=now + timedelta(hours=3 + i % 5),
        )

    elif status == EventStatus.completed:
        # Everything in the past
        base.update(
            funding_goal_cents=100_000,
            funding_end_at=now - timedelta(days=60 + day_jitter),
            start_time=now - timedelta(days=30 + day_jitter),
            end_time=now - timedelta(days=30 + day_jitter) + timedelta(hours=4),
        )

    elif status == EventStatus.cancelled:
        # Future event that was cancelled
        base.update(
            funding_goal_cents=100_000,
            funding_end_at=now + timedelta(days=30 + day_jitter),
            start_time=now + timedelta(days=65 + day_jitter),
            end_time=now + timedelta(days=65 + day_jitter, hours=4 + hour_jitter),
            cancellation_reason="Seeded test event — cancelled for pre-prod testing.",
        )

    elif status == EventStatus.under_review:
        # Funding ended; auto-transition failed → admin must investigate
        base.update(
            funding_goal_cents=100_000,
            funding_end_at=now - timedelta(days=5 + i % 10),
            review_notes=(
                "Seeded event: simulated auto-transition failure — "
                "admin review required (pre-prod testing)."
            ),
        )

    return base


# ---------------------------------------------------------------------------
# Seed infrastructure
# ---------------------------------------------------------------------------

async def _get_or_create_organizer(session: AsyncSession) -> User:
    result = await session.execute(
        select(User).where(User.email == SEED_ORGANIZER_EMAIL)
    )
    user = result.scalar_one_or_none()
    if user:
        return user

    user = User(
        firebase_uid=SEED_ORGANIZER_UID,
        email=SEED_ORGANIZER_EMAIL,
        display_name="[SEED] Pre-prod Organizer",
        role=UserRole.organizer,
    )
    session.add(user)
    await session.flush()
    print(f"  Created seed organizer (id={user.id})")
    return user


async def _get_or_create_venues(session: AsyncSession, organizer_id: int) -> list[Venue]:
    """Return all seed venues, creating any that don't exist yet."""
    seed_names = [v[0] for v in SEED_VENUES]
    result = await session.execute(
        select(Venue).where(Venue.name.in_(seed_names))
    )
    existing = {v.name: v for v in result.scalars().all()}

    venues: list[Venue] = []
    created = 0
    for name, address, city, province, capacity, lat, lng in SEED_VENUES:
        if name in existing:
            venues.append(existing[name])
        else:
            v = Venue(
                organizer_id=organizer_id,
                name=name,
                address=address,
                city=city,
                province=province,
                max_capacity=capacity,
                lat=lat,
                lng=lng,
            )
            session.add(v)
            await session.flush()
            venues.append(v)
            created += 1

    if created:
        print(f"  Created {created} seed venue(s) across {created} cities")
    return venues


# ---------------------------------------------------------------------------
# Seed
# ---------------------------------------------------------------------------

async def run_seed(statuses: list[str], count: int) -> None:
    now = _now()
    t0 = time.monotonic()
    total_inserted = 0

    async with AsyncSession(engine) as session:
        organizer = await _get_or_create_organizer(session)
        venues = await _get_or_create_venues(session, organizer.id)

        for status_str in statuses:
            status = EventStatus(status_str)
            rows = [
                {
                    "organizer_id": organizer.id,
                    # Cycle through all world venues so events are geographically spread
                    "venue_id": venues[i % len(venues)].id,
                    # Copy venue coordinates onto the event so map pins work
                    "lat": venues[i % len(venues)].lat,
                    "lng": venues[i % len(venues)].lng,
                    **_event_fields(status, i, now),
                }
                for i in range(count)
            ]

            inserted = 0
            for batch in _chunks(rows, BATCH_SIZE):
                result = await session.execute(
                    pg_insert(Event).values(batch).returning(Event.id)
                )
                event_ids = [row[0] for row in result.fetchall()]
                inserted += len(event_ids)

                # Bulk-insert ticket tiers for statuses that sell tickets
                if status in TICKETED_STATUSES:
                    tier_rows = [
                        {"event_id": eid, **tier}
                        for eid in event_ids
                        for tier in SEED_TIERS
                    ]
                    for tier_batch in _chunks(tier_rows, BATCH_SIZE):
                        await session.execute(pg_insert(TicketTier).values(tier_batch))

            total_inserted += inserted
            tiers_note = f" + {len(SEED_TIERS)} tiers/event" if status in TICKETED_STATUSES else ""
            print(f"  [{status_str:<22}] inserted {inserted:>5} events{tiers_note}")

        await session.commit()

    elapsed = time.monotonic() - t0
    print(f"\nDone. {total_inserted} events seeded in {elapsed:.1f}s.")


# ---------------------------------------------------------------------------
# Clear
# ---------------------------------------------------------------------------

async def run_clear(status: str | None) -> None:
    t0 = time.monotonic()

    async with AsyncSession(engine) as session:
        if status:
            # Single-status clear — leave organiser and venue in place
            result = await session.execute(
                delete(Event)
                .where(Event.title.like(f"{SEED_MARKER}%"))
                .where(Event.status == EventStatus(status))
                .returning(Event.id)
            )
            deleted = len(result.fetchall())
            await session.commit()
            print(f"Deleted {deleted} [{status}] seed events.")

        else:
            # Full clear: cascade through all child tables first
            await session.execute(text("""
                DO $$
                DECLARE seed_ids INT[];
                BEGIN
                    SELECT ARRAY(
                        SELECT id FROM events WHERE title LIKE '[SEED]%'
                    ) INTO seed_ids;

                    IF array_length(seed_ids, 1) IS NULL THEN
                        RAISE NOTICE 'No seed events found.';
                        RETURN;
                    END IF;

                    -- Level-3: tables that reference child-of-event tables
                    DELETE FROM milestone_reactions
                        WHERE milestone_id IN (
                            SELECT id FROM funding_milestones
                            WHERE event_id = ANY(seed_ids)
                        );
                    DELETE FROM pledge_spot_reservations
                        WHERE funding_id IN (
                            SELECT id FROM fundings WHERE event_id = ANY(seed_ids)
                        );
                    DELETE FROM escrow_releases
                        WHERE escrow_id IN (
                            SELECT id FROM fund_escrows WHERE event_id = ANY(seed_ids)
                        );

                    -- Level-2: tables with direct event_id FK
                    DELETE FROM funding_milestones          WHERE event_id = ANY(seed_ids);
                    DELETE FROM funding_milestone_snapshots WHERE event_id = ANY(seed_ids);
                    DELETE FROM early_bird_discounts        WHERE event_id = ANY(seed_ids);
                    DELETE FROM fund_escrows                WHERE event_id = ANY(seed_ids);
                    DELETE FROM ticket_escrows              WHERE event_id = ANY(seed_ids);
                    DELETE FROM sponsor_escrows             WHERE event_id = ANY(seed_ids);
                    DELETE FROM sponsor_tickets             WHERE event_id = ANY(seed_ids);
                    DELETE FROM sponsorship_categories      WHERE event_id = ANY(seed_ids);
                    DELETE FROM user_event_discounts        WHERE event_id = ANY(seed_ids);
                    DELETE FROM ticket_sales                WHERE event_id = ANY(seed_ids);
                    DELETE FROM ticket_tiers                WHERE event_id = ANY(seed_ids);
                    DELETE FROM fundings                    WHERE event_id = ANY(seed_ids);
                    DELETE FROM registrations               WHERE event_id = ANY(seed_ids);
                    DELETE FROM event_organizers            WHERE event_id = ANY(seed_ids);
                    DELETE FROM event_schedule_items        WHERE event_id = ANY(seed_ids);
                    DELETE FROM event_images                WHERE event_id = ANY(seed_ids);
                    DELETE FROM event_posts                 WHERE event_id = ANY(seed_ids);
                    DELETE FROM bookmarks                   WHERE event_id = ANY(seed_ids);
                    DELETE FROM ratings                     WHERE event_id = ANY(seed_ids);
                    DELETE FROM disputes                    WHERE event_id = ANY(seed_ids);
                    DELETE FROM event_discounts             WHERE event_id = ANY(seed_ids);
                    DELETE FROM organizer_customer_history  WHERE event_id = ANY(seed_ids);
                    DELETE FROM event_reactions             WHERE event_id = ANY(seed_ids);
                    DELETE FROM event_discount_strategy_links WHERE event_id = ANY(seed_ids);

                    -- Finally, remove the seed events themselves
                    DELETE FROM events WHERE id = ANY(seed_ids);
                END $$;
            """))

            # Remove all seed venues (FK organizer_id RESTRICT → delete before user)
            await session.execute(
                delete(Venue).where(Venue.name.like(f"{SEED_MARKER}%"))
            )
            # Remove seed organizer
            result = await session.execute(
                delete(User)
                .where(User.email == SEED_ORGANIZER_EMAIL)
                .returning(User.id)
            )
            removed_user = result.fetchone() is not None
            await session.commit()

            elapsed = time.monotonic() - t0
            print(
                f"All seed events cleared"
                + (" (seed organiser removed)" if removed_user else "")
                + f" in {elapsed:.1f}s."
            )


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Seed or clear pre-prod event data.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument("--seed", action="store_true", help="Create seed events")
    mode.add_argument("--clear", action="store_true", help="Remove seed events")

    p.add_argument(
        "--status",
        choices=ALL_STATUSES,
        default=None,
        metavar="STATUS",
        help=f"Operate on a single status only. Choices: {', '.join(ALL_STATUSES)}",
    )
    p.add_argument(
        "--count",
        type=int,
        default=DEFAULT_COUNT,
        metavar="N",
        help=f"Events per status when seeding (default: {DEFAULT_COUNT})",
    )
    return p.parse_args()


def main() -> None:
    args = _parse_args()
    statuses = [args.status] if args.status else ALL_STATUSES

    if args.seed:
        label = args.status or f"all {len(statuses)} statuses"
        print(f"Seeding {args.count} events × {label}…")
        asyncio.run(run_seed(statuses, args.count))

    elif args.clear:
        label = args.status or "all statuses"
        print(f"Clearing seed events ({label})…")
        asyncio.run(run_clear(args.status))


if __name__ == "__main__":
    main()
