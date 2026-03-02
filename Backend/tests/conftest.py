"""
Pytest fixtures: async client, mock auth, test users/venue/event.

- Use a separate test DB: set TEST_DATABASE_URL in .env (e.g. event_db_test) so tests never
  truncate your real data. If unset, tests use DATABASE_URL and will wipe all tables.
- Auth: use Authorization: Bearer test-admin | test-organizer | test-customer (no real Firebase).
- DB: each test runs inside a transaction that is rolled back -- no TRUNCATE needed.
"""
import os
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool

from app.main import app as fastapi_app
from app.db.base import async_engine, read_engine, Base, get_db_session, get_read_db_session
import app.models  # noqa: F401  -- register models for metadata
from app.config import settings
from app.core import security
from app.models.user import User, UserRole
from app.models.venue import Venue
from app.models.event import Event, EventOrganizer, EventStatus, RegistrationType
from app.models.ticket import TicketTier, TicketSale, TicketSaleStatus
from app.models.funding import Funding, FundingStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.notification import Notification, NotificationType
from app.models.device_token import DeviceToken
from app.models.sponsor import SponsorProfile, SponsorshipCategory, SponsorBid, BidStatus
from app.models.milestone import FundingMilestone, EarlyBirdDiscount
from app.models.schedule import EventScheduleItem
from app.models.image import EventImage
from app.models.post import EventPost
from app.models.rating import Rating, RatingDirection
from app.models.ticket_strategy import TicketStrategy, TicketStrategyTier
from app.models.discount_strategy import DiscountStrategy
from app.models.payment_info import UserPaymentInfo, OrganizerBankAccount

# ---------------------------------------------------------------------------
# Skip DB-dependent tests when requested (e.g. in CI without DB)
# ---------------------------------------------------------------------------
SKIP_DB = os.environ.get("SKIP_DB_TESTS", "").lower() in ("1", "true", "yes")

# ---------------------------------------------------------------------------
# Test engine (NullPool -- one fresh connection per checkout, no conflicts)
# ---------------------------------------------------------------------------
TEST_DATABASE_URL = (
    getattr(settings, "TEST_DATABASE_URL", None)
    or os.environ.get("TEST_DATABASE_URL")
)
_test_engine = create_async_engine(
    TEST_DATABASE_URL or settings.DATABASE_URL,
    poolclass=NullPool,
)


@pytest_asyncio.fixture(scope="session", autouse=True)
async def _reset_engine_pool():
    """Dispose production engine pools, kill stale connections, and clean test DB."""
    await async_engine.dispose()
    await read_engine.dispose()

    if not SKIP_DB:
        # Kill any leftover connections from previous crashed test runs first
        async with _test_engine.connect() as conn:
            await conn.execute(
                text(
                    "SELECT pg_terminate_backend(pid) "
                    "FROM pg_stat_activity "
                    "WHERE datname = current_database() "
                    "AND pid <> pg_backend_pid()"
                )
            )
            await conn.commit()

        # Clean any leftover data from a previous crashed test run
        _all_tables = ", ".join(
            f'"{t.name}"' for t in Base.metadata.sorted_tables
        )
        async with _test_engine.begin() as conn:
            await conn.execute(text(f"TRUNCATE {_all_tables} CASCADE"))
    yield


# ---------------------------------------------------------------------------
# Mock auth: Bearer test-admin / test-organizer / test-customer
# ---------------------------------------------------------------------------
_test_bearer = HTTPBearer(auto_error=False)


async def _mock_verify_firebase(
    credentials: HTTPAuthorizationCredentials | None = Depends(_test_bearer),
) -> str | None:
    if not credentials:
        return None
    valid = {
        "test-admin",
        "test-organizer",
        "test-organizer2",
        "test-customer",
        "test-sponsor",
    }
    if credentials.credentials in valid:
        return credentials.credentials
    from fastapi import HTTPException

    raise HTTPException(status_code=401, detail="Invalid or expired token")


# ---------------------------------------------------------------------------
# Replace the app lifespan with a lightweight test version
# ---------------------------------------------------------------------------
@asynccontextmanager
async def _test_lifespan(application):
    yield


fastapi_app.router.lifespan_context = _test_lifespan

# Apply mock auth for all tests (so we don't need real Firebase)
fastapi_app.dependency_overrides[security.verify_firebase_token] = (
    _mock_verify_firebase
)

# Disable rate limiting for tests so tests don't hit 429s
from app.rate_limit import limiter  # noqa: E402

limiter.enabled = False

# ---------------------------------------------------------------------------
# Savepoint / rollback test isolation
# ---------------------------------------------------------------------------
# Each test gets a single DB connection with an outer transaction.
# Both fixture code and app code share this connection.
# session.commit() becomes a savepoint release (not a real COMMIT) thanks to
# join_transaction_mode="create_savepoint".
# After the test, we rollback the outer transaction -- undoing everything.

# Module-level holder for the per-test session maker (set by _test_txn)
_current_test_sm: async_sessionmaker | None = None


@pytest_asyncio.fixture(autouse=True)
async def _test_txn():
    """Per-test transaction isolation via savepoints."""
    global _current_test_sm

    if SKIP_DB:
        yield
        return

    async with _test_engine.connect() as connection:
        transaction = await connection.begin()

        _current_test_sm = async_sessionmaker(
            bind=connection,
            class_=AsyncSession,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        )

        # Per-request session state -- reuse the same session within a single
        # HTTP request so get_db_session and get_read_db_session don't create
        # overlapping savepoints (PostgreSQL savepoints are ordered; rolling
        # back an earlier one invalidates later ones).
        _req_session: dict = {"session": None, "refcount": 0}

        async def _override_db_session() -> AsyncGenerator[AsyncSession, None]:
            if _req_session["session"] is None or not _req_session["session"].is_active:
                _req_session["session"] = _current_test_sm()
            _req_session["refcount"] += 1
            try:
                yield _req_session["session"]
                if _req_session["refcount"] <= 1:
                    await _req_session["session"].commit()
            except Exception:
                if _req_session["session"].is_active:
                    await _req_session["session"].rollback()
                raise
            finally:
                _req_session["refcount"] -= 1
                if _req_session["refcount"] <= 0:
                    await _req_session["session"].close()
                    _req_session["session"] = None
                    _req_session["refcount"] = 0

        fastapi_app.dependency_overrides[get_db_session] = _override_db_session
        fastapi_app.dependency_overrides[get_read_db_session] = _override_db_session

        yield

        # Rollback the outer transaction -- all test data vanishes
        await transaction.rollback()

    _current_test_sm = None


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=fastapi_app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def db_session(_test_txn) -> AsyncGenerator[AsyncSession, None]:
    """Provide a DB session for fixture data setup (shares the test transaction)."""
    if SKIP_DB:
        yield None  # type: ignore[misc]
        return
    async with _current_test_sm() as session:
        yield session


@pytest_asyncio.fixture
async def test_users(db_session: AsyncSession) -> dict[str, User]:
    """Create admin, organizer, customer users."""
    users = [
        User(
            firebase_uid="test-admin",
            email="admin@test.com",
            display_name="Admin",
            role=UserRole.admin,
        ),
        User(
            firebase_uid="test-organizer",
            email="organizer@test.com",
            display_name="Organizer",
            role=UserRole.organizer,
        ),
        User(
            firebase_uid="test-organizer2",
            email="organizer2@test.com",
            display_name="Organizer Two",
            role=UserRole.organizer,
        ),
        User(
            firebase_uid="test-customer",
            email="customer@test.com",
            display_name="Customer",
            role=UserRole.customer,
        ),
    ]
    for u in users:
        db_session.add(u)
    await db_session.commit()
    return {
        "admin": users[0],
        "organizer": users[1],
        "organizer2": users[2],
        "customer": users[3],
    }


@pytest_asyncio.fixture
async def auth_headers_admin() -> dict[str, str]:
    return _auth_headers("test-admin")


@pytest_asyncio.fixture
async def auth_headers_organizer() -> dict[str, str]:
    return _auth_headers("test-organizer")


@pytest_asyncio.fixture
async def auth_headers_customer() -> dict[str, str]:
    return _auth_headers("test-customer")


@pytest_asyncio.fixture
async def auth_headers_organizer2() -> dict[str, str]:
    return _auth_headers("test-organizer2")


@pytest_asyncio.fixture
async def test_venue(
    db_session: AsyncSession, test_users: dict[str, User]
) -> Venue:
    """One venue owned by the test organizer."""
    organizer = test_users["organizer"]
    venue = Venue(
        organizer_id=organizer.id,
        name="Test Hall",
        address="123 Test St",
        city="Ottawa",
        province="ON",
        lat=45.42,
        lng=-75.69,
        max_capacity=100,
    )
    db_session.add(venue)
    await db_session.commit()
    return venue


@pytest_asyncio.fixture
async def test_event(
    db_session: AsyncSession,
    test_users: dict[str, User],
    test_venue: Venue,
) -> Event:
    """One draft event (organizer's)."""
    organizer = test_users["organizer"]
    start = datetime.now(timezone.utc) + timedelta(days=30)
    end = start + timedelta(hours=2)
    funding_end = start - timedelta(days=1)
    event = Event(
        organizer_id=organizer.id,
        venue_id=test_venue.id,
        title="Test Event",
        description="A test event",
        start_time=start,
        end_time=end,
        funding_goal_cents=10000,
        funding_end_at=funding_end,
        min_pledge_cents=500,
        status=EventStatus.draft,
        registration_type=RegistrationType.open,
        max_capacity=50,
        common_discount_percent=0,
        pledge_discount_percent=10,
        lat=test_venue.lat,
        lng=test_venue.lng,
    )
    db_session.add(event)
    await db_session.commit()
    return event


@pytest_asyncio.fixture
async def test_event_approved(
    db_session: AsyncSession, test_event: Event
) -> Event:
    """Same as test_event but status = approved."""
    test_event.status = EventStatus.approved
    await db_session.commit()
    return test_event


@pytest_asyncio.fixture
async def test_event_pending(
    db_session: AsyncSession, test_event: Event
) -> Event:
    """Same as test_event but status = pending_approval."""
    test_event.status = EventStatus.pending_approval
    await db_session.commit()
    return test_event


@pytest_asyncio.fixture
async def test_ticket_tier(
    db_session: AsyncSession,
    test_event_approved: Event,
) -> TicketTier:
    """One ticket tier for test_event_approved."""
    tier = TicketTier(
        event_id=test_event_approved.id,
        name="General",
        price_cents=2500,
        display_order=0,
    )
    db_session.add(tier)
    await db_session.commit()
    return tier


# -- Sponsor user & fixtures --


@pytest_asyncio.fixture
async def test_users_with_sponsor(
    db_session: AsyncSession, test_users: dict[str, User]
) -> dict[str, User]:
    """Extend test_users with a sponsor user."""
    sponsor = User(
        firebase_uid="test-sponsor",
        email="sponsor@test.com",
        display_name="Sponsor",
        role=UserRole.sponsor,
    )
    db_session.add(sponsor)
    await db_session.commit()
    return {**test_users, "sponsor": sponsor}


@pytest_asyncio.fixture
async def auth_headers_sponsor() -> dict[str, str]:
    return _auth_headers("test-sponsor")


# -- Funding fixtures --


@pytest_asyncio.fixture
async def test_pledge(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
) -> Funding:
    """A pledge by the customer on the approved event."""
    pledge = Funding(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        amount_cents=2000,
        platform_cut_cents=200,
        net_to_organizer_cents=1800,
        status=FundingStatus.pledged,
        receipt_number="PLG-TEST-001",
    )
    db_session.add(pledge)
    await db_session.commit()
    return pledge


# -- Ticket sale fixture --


@pytest_asyncio.fixture
async def test_ticket_sale(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_ticket_tier: TicketTier,
    test_users: dict[str, User],
) -> TicketSale:
    """A purchased ticket by the customer."""
    sale = TicketSale(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        ticket_tier_id=test_ticket_tier.id,
        ticket_code="TKT-TEST-001",
        receipt_number="TKT-REC-001",
        amount_paid_cents=2500,
        status=TicketSaleStatus.purchased,
    )
    db_session.add(sale)
    await db_session.commit()
    return sale


# -- Registration fixture --


@pytest_asyncio.fixture
async def test_registration(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
) -> Registration:
    """A registration by the customer on the approved event."""
    reg = Registration(
        event_id=test_event_approved.id,
        user_id=test_users["customer"].id,
        status=RegistrationStatus.registered,
    )
    db_session.add(reg)
    await db_session.commit()
    return reg


# -- Notification fixtures --


@pytest_asyncio.fixture
async def test_notification(
    db_session: AsyncSession,
    test_users: dict[str, User],
) -> Notification:
    """A notification for the customer."""
    notif = Notification(
        user_id=test_users["customer"].id,
        type=NotificationType.pledge_confirmed,
        title="Test Notification",
        message="This is a test notification.",
        data={"test": True},
    )
    db_session.add(notif)
    await db_session.commit()
    return notif


@pytest_asyncio.fixture
async def test_device_token(
    db_session: AsyncSession,
    test_users: dict[str, User],
) -> DeviceToken:
    """A device token for the customer."""
    dt = DeviceToken(
        user_id=test_users["customer"].id,
        token="fcm-test-token-12345",
        platform="web",
    )
    db_session.add(dt)
    await db_session.commit()
    return dt


# -- Sponsor profile & bid fixtures --


@pytest_asyncio.fixture
async def test_sponsor_profile(
    db_session: AsyncSession,
    test_users_with_sponsor: dict[str, User],
) -> SponsorProfile:
    """A sponsor profile for the sponsor user."""
    profile = SponsorProfile(
        user_id=test_users_with_sponsor["sponsor"].id,
        company_name="Test Corp",
        contact_name="Sponsor Person",
        profession="Marketing",
    )
    db_session.add(profile)
    await db_session.commit()
    return profile


@pytest_asyncio.fixture
async def test_sponsorship_category(
    db_session: AsyncSession,
    test_event_approved: Event,
) -> SponsorshipCategory:
    """A sponsorship category on the approved event."""
    cat = SponsorshipCategory(
        event_id=test_event_approved.id,
        name="Gold Sponsor",
        total_spots=3,
        min_bid_cents=5000,
    )
    db_session.add(cat)
    await db_session.commit()
    return cat


@pytest_asyncio.fixture
async def test_sponsor_bid(
    db_session: AsyncSession,
    test_sponsorship_category: SponsorshipCategory,
    test_users_with_sponsor: dict[str, User],
) -> SponsorBid:
    """A pending bid on the sponsorship category."""
    bid = SponsorBid(
        category_id=test_sponsorship_category.id,
        sponsor_user_id=test_users_with_sponsor["sponsor"].id,
        amount_cents=10000,
        proposal_text="We want to sponsor this event.",
        status=BidStatus.pending,
    )
    db_session.add(bid)
    await db_session.commit()
    return bid


# -- Milestone fixtures --


@pytest_asyncio.fixture
async def test_milestone(
    db_session: AsyncSession,
    test_event_approved: Event,
) -> FundingMilestone:
    """A milestone on the approved event."""
    ms = FundingMilestone(
        event_id=test_event_approved.id,
        title="50% Funded",
        unlock_percent=50,
        description="Halfway there!",
    )
    db_session.add(ms)
    await db_session.commit()
    return ms


@pytest_asyncio.fixture
async def test_early_bird_discount(
    db_session: AsyncSession,
    test_event_approved: Event,
) -> EarlyBirdDiscount:
    """An early-bird discount on the approved event."""
    ebd = EarlyBirdDiscount(
        event_id=test_event_approved.id,
        applies_to="funding",
        window_end=datetime.now(timezone.utc) + timedelta(days=7),
        discount_type="percent",
        value=10,
    )
    db_session.add(ebd)
    await db_session.commit()
    return ebd


# -- Schedule fixture --


@pytest_asyncio.fixture
async def test_schedule_item(
    db_session: AsyncSession,
    test_event_approved: Event,
) -> EventScheduleItem:
    """A schedule item on the approved event."""
    from datetime import date, time

    item = EventScheduleItem(
        event_id=test_event_approved.id,
        date=date.today() + timedelta(days=30),
        start_time=time(10, 0),
        end_time=time(11, 0),
        title="Opening Ceremony",
    )
    db_session.add(item)
    await db_session.commit()
    return item


# -- Image & Post fixtures --


@pytest_asyncio.fixture
async def test_event_image(
    db_session: AsyncSession,
    test_event_approved: Event,
) -> EventImage:
    """An image on the approved event."""
    img = EventImage(
        event_id=test_event_approved.id,
        image_url="https://example.com/test.jpg",
        caption="Test image",
    )
    db_session.add(img)
    await db_session.commit()
    return img


@pytest_asyncio.fixture
async def test_event_post(
    db_session: AsyncSession,
    test_event_approved: Event,
    test_users: dict[str, User],
) -> EventPost:
    """A post on the approved event."""
    post = EventPost(
        event_id=test_event_approved.id,
        user_id=test_users["organizer"].id,
        content="Test post content",
    )
    db_session.add(post)
    await db_session.commit()
    return post


# -- Rating fixtures --


@pytest_asyncio.fixture
async def test_event_completed(
    db_session: AsyncSession, test_event: Event
) -> Event:
    """Event with status=completed (for rating tests)."""
    test_event.status = EventStatus.completed
    await db_session.commit()
    return test_event


@pytest_asyncio.fixture
async def test_rating(
    db_session: AsyncSession,
    test_event_completed: Event,
    test_users: dict[str, User],
) -> Rating:
    """A rating on a completed event."""
    rating = Rating(
        rater_user_id=test_users["customer"].id,
        event_id=test_event_completed.id,
        direction=RatingDirection.customer_to_event,
        stars=4,
        description="Great event!",
    )
    db_session.add(rating)
    await db_session.commit()
    return rating


# -- Strategy fixtures --


@pytest_asyncio.fixture
async def test_ticket_strategy(
    db_session: AsyncSession,
    test_users: dict[str, User],
) -> TicketStrategy:
    """A ticket strategy owned by the organizer."""
    strategy = TicketStrategy(
        organizer_id=test_users["organizer"].id,
        name="Concert Standard",
    )
    db_session.add(strategy)
    await db_session.flush()
    tier = TicketStrategyTier(
        strategy_id=strategy.id,
        name="General",
        price_cents=2500,
    )
    db_session.add(tier)
    await db_session.commit()
    return strategy


@pytest_asyncio.fixture
async def test_discount_strategy(
    db_session: AsyncSession,
    test_users: dict[str, User],
) -> DiscountStrategy:
    """A discount strategy owned by the organizer."""
    ds = DiscountStrategy(
        organizer_id=test_users["organizer"].id,
        name="Early Bird 10%",
        discount_type="ticket_percent",
        value=10,
    )
    db_session.add(ds)
    await db_session.commit()
    return ds


# -- Organizer bank account fixture --


@pytest_asyncio.fixture
async def test_organizer_bank(
    db_session: AsyncSession,
    test_users: dict[str, User],
) -> OrganizerBankAccount:
    """A verified bank account for the test organizer (for event approval)."""
    bank = OrganizerBankAccount(
        user_id=test_users["organizer"].id,
        institution_number_encrypted=b"encrypted_inst",
        transit_number_encrypted=b"encrypted_transit",
        account_number_encrypted=b"encrypted_acct",
        account_holder_encrypted=b"encrypted_holder",
        verified=True,
    )
    db_session.add(bank)
    await db_session.commit()
    return bank
