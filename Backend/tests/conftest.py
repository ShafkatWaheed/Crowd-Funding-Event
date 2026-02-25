"""
Pytest fixtures: async client, mock auth, test users/venue/event.

- Use a separate test DB: set TEST_DATABASE_URL in .env (e.g. event_db_test) so tests never
  truncate your real data. If unset, tests use DATABASE_URL and will wipe all tables.
- Auth: use Authorization: Bearer test-admin | test-organizer | test-customer (no real Firebase).
- DB: test data is committed; tables are truncated after each test for isolation.
"""
import os
from datetime import datetime, timedelta, timezone
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

from app.main import app as fastapi_app
from app.db.base import async_engine, async_session_maker, Base, get_db_session
import app.models  # noqa: F401 - register models for metadata
from app.config import settings
from app.core import security
from app.models.user import User, UserRole
from app.models.venue import Venue
from app.models.event import Event, EventStatus, RegistrationType
from app.models.ticket import TicketTier


# Skip DB-dependent tests when requested (e.g. in CI without DB)
SKIP_DB = os.environ.get("SKIP_DB_TESTS", "").lower() in ("1", "true", "yes")

# Use separate test DB when set so pytest never truncates real data
TEST_DATABASE_URL = getattr(settings, "TEST_DATABASE_URL", None) or os.environ.get("TEST_DATABASE_URL")
if TEST_DATABASE_URL:
    _test_engine = create_async_engine(TEST_DATABASE_URL, pool_size=5, max_overflow=5)
    _test_session_maker = async_sessionmaker(
        _test_engine, class_=AsyncSession, expire_on_commit=False, autocommit=False, autoflush=False
    )
else:
    _test_engine = async_engine
    _test_session_maker = async_session_maker


async def _get_test_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with _test_session_maker() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


@pytest_asyncio.fixture(scope="session", autouse=True)
async def _reset_engine_pool():
    """Dispose engine pool at session start so all connections are created on the test event loop."""
    target = _test_engine if TEST_DATABASE_URL else async_engine
    await target.dispose()
    yield
    await target.dispose()


# ----- Mock auth: Bearer test-admin / test-organizer / test-customer -----
_test_bearer = HTTPBearer(auto_error=False)


async def _mock_verify_firebase(
    credentials: HTTPAuthorizationCredentials | None = Depends(_test_bearer),
) -> str | None:
    if not credentials:
        return None
    if credentials.credentials in ("test-admin", "test-organizer", "test-organizer2", "test-customer"):
        return credentials.credentials
    from fastapi import HTTPException
    raise HTTPException(status_code=401, detail="Invalid or expired token")


# Apply mock auth for all tests (so we don't need real Firebase)
fastapi_app.dependency_overrides[security.verify_firebase_token] = _mock_verify_firebase

# Use test DB for app when TEST_DATABASE_URL is set so requests hit test DB, not real data
if TEST_DATABASE_URL:
    fastapi_app.dependency_overrides[get_db_session] = _get_test_db_session


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=fastapi_app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


def _auth_headers(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide a normal DB session (committed) for fixture data setup."""
    async with _test_session_maker() as session:
        yield session


@pytest_asyncio.fixture(autouse=True)
async def _cleanup_db() -> AsyncGenerator[None, None]:
    """Truncate all tables after each test for isolation (skip if SKIP_DB_TESTS)."""
    if SKIP_DB:
        yield
        return
    yield
    async with _test_engine.begin() as conn:
        for table in reversed(Base.metadata.sorted_tables):
            await conn.execute(text(f'TRUNCATE TABLE "{table.name}" RESTART IDENTITY CASCADE'))


@pytest_asyncio.fixture
async def test_users(db_session: AsyncSession) -> dict[str, User]:
    """Create admin, organizer, customer with firebase_uid = test-admin, test-organizer, test-customer."""
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
async def test_venue(db_session: AsyncSession, test_users: dict[str, User]) -> Venue:
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
async def test_event_approved(db_session: AsyncSession, test_event: Event) -> Event:
    """Same as test_event but status = approved (for pledge/register tests)."""
    test_event.status = EventStatus.approved
    await db_session.commit()
    return test_event


@pytest_asyncio.fixture
async def test_event_pending(db_session: AsyncSession, test_event: Event) -> Event:
    """Same as test_event but status = pending_approval (for admin approve/reject tests, no submit endpoint)."""
    test_event.status = EventStatus.pending_approval
    await db_session.commit()
    return test_event


@pytest_asyncio.fixture
async def test_ticket_tier(
    db_session: AsyncSession,
    test_event_approved: Event,
) -> TicketTier:
    """One ticket tier for test_event_approved (for ticket purchase/scan tests)."""
    tier = TicketTier(
        event_id=test_event_approved.id,
        name="General",
        price_cents=2500,
        display_order=0,
    )
    db_session.add(tier)
    await db_session.commit()
    return tier
