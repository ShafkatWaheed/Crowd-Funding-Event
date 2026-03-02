"""
Phase 4B event-support service-level tests.

Covers:
  - discount_strategy: CRUD, attach/detach, claim/unclaim, validation
  - schedule: CRUD, bulk create, overlap detection, time validation
  - ticket_crypto: encrypt/decrypt roundtrip, plaintext fallback, tampered payload
  - ticket_strategy: CRUD, tier management, apply-to-event
  - venue: CRUD, ownership/permission, capacity validation
  - post: CRUD, toggle posts, registration enforcement
"""
import pytest
from datetime import date, time, timedelta, datetime, timezone
from unittest.mock import patch, MagicMock

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models.discount_strategy import DiscountStrategy
from app.models.event import Event, EventStatus
from app.models.post import EventPost
from app.models.registration import Registration, RegistrationStatus
from app.models.schedule import EventScheduleItem
from app.models.ticket_strategy import TicketStrategy, TicketStrategyTier
from app.models.user import User
from app.models.venue import Venue


# ═══════════════════════════════════════════════════════════════════════════
# Discount Strategy Service
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_discount_list_strategies(db_session: AsyncSession, test_users, test_discount_strategy):
    """list_strategies returns strategies owned by the organizer."""
    from app.services.discount_strategy import list_strategies

    results = await list_strategies(db_session, organizer_id=test_users["organizer"].id)
    assert len(results) >= 1
    assert any(s.id == test_discount_strategy.id for s in results)


@pytest.mark.asyncio
async def test_discount_list_strategies_empty_for_other_user(db_session: AsyncSession, test_users, test_discount_strategy):
    """list_strategies returns empty for a user who owns nothing."""
    from app.services.discount_strategy import list_strategies

    results = await list_strategies(db_session, organizer_id=test_users["customer"].id)
    assert len(results) == 0


@pytest.mark.asyncio
async def test_discount_get_or_404(db_session: AsyncSession, test_discount_strategy):
    """get_or_404 returns existing strategy."""
    from app.services.discount_strategy import get_or_404

    s = await get_or_404(db_session, test_discount_strategy.id)
    assert s.id == test_discount_strategy.id


@pytest.mark.asyncio
async def test_discount_get_or_404_missing(db_session: AsyncSession, test_users):
    """get_or_404 raises NotFoundError for non-existent id."""
    from app.services.discount_strategy import get_or_404

    with pytest.raises(NotFoundError):
        await get_or_404(db_session, 999999)


@pytest.mark.asyncio
async def test_discount_create_strategy(db_session: AsyncSession, test_users):
    """create_strategy creates a valid discount strategy."""
    from app.services.discount_strategy import create_strategy

    s = await create_strategy(
        db_session,
        user=test_users["organizer"],
        name="New Discount",
        discount_type="ticket_percent",
        value=15,
        target="all",
    )
    assert s.id is not None
    assert s.name == "New Discount"
    assert s.discount_type == "ticket_percent"
    assert s.value == 15
    assert s.target == "all"
    assert s.organizer_id == test_users["organizer"].id


@pytest.mark.asyncio
async def test_discount_create_invalid_type(db_session: AsyncSession, test_users):
    """create_strategy rejects invalid discount_type."""
    from app.services.discount_strategy import create_strategy

    with pytest.raises(ConflictError, match="discount_type"):
        await create_strategy(
            db_session,
            user=test_users["organizer"],
            name="Bad",
            discount_type="invalid_type",
            value=10,
            target="all",
        )


@pytest.mark.asyncio
async def test_discount_create_invalid_value(db_session: AsyncSession, test_users):
    """create_strategy rejects value outside 1-100."""
    from app.services.discount_strategy import create_strategy

    with pytest.raises(ConflictError, match="Percent value"):
        await create_strategy(
            db_session,
            user=test_users["organizer"],
            name="Bad",
            discount_type="ticket_percent",
            value=0,
            target="all",
        )


@pytest.mark.asyncio
async def test_discount_create_pledge_percent_non_pledger_conflict(db_session: AsyncSession, test_users):
    """pledge_percent discount cannot target non_pledgers."""
    from app.services.discount_strategy import create_strategy

    with pytest.raises(ConflictError, match="non-pledgers"):
        await create_strategy(
            db_session,
            user=test_users["organizer"],
            name="Bad Combo",
            discount_type="pledge_percent",
            value=10,
            target="non_pledgers",
        )


@pytest.mark.asyncio
async def test_discount_update_strategy(db_session: AsyncSession, test_users, test_discount_strategy):
    """Owner can update strategy name and value."""
    from app.services.discount_strategy import update_strategy

    updated = await update_strategy(
        db_session,
        strategy=test_discount_strategy,
        user=test_users["organizer"],
        name="Renamed",
        value=20,
    )
    assert updated.name == "Renamed"
    assert updated.value == 20


@pytest.mark.asyncio
async def test_discount_update_strategy_forbidden(db_session: AsyncSession, test_users, test_discount_strategy):
    """Non-owner/non-admin cannot update strategy."""
    from app.services.discount_strategy import update_strategy

    with pytest.raises(ForbiddenError):
        await update_strategy(
            db_session,
            strategy=test_discount_strategy,
            user=test_users["customer"],
            name="Hacked",
        )


@pytest.mark.asyncio
async def test_discount_delete_strategy(db_session: AsyncSession, test_users):
    """Owner can delete their own strategy."""
    from app.services.discount_strategy import create_strategy, delete_strategy, get_or_404

    s = await create_strategy(
        db_session,
        user=test_users["organizer"],
        name="Temp",
        discount_type="ticket_percent",
        value=5,
    )
    await delete_strategy(db_session, strategy=s, user=test_users["organizer"])
    with pytest.raises(NotFoundError):
        await get_or_404(db_session, s.id)


@pytest.mark.asyncio
async def test_discount_delete_strategy_forbidden(db_session: AsyncSession, test_users, test_discount_strategy):
    """Non-owner cannot delete strategy."""
    from app.services.discount_strategy import delete_strategy

    with pytest.raises(ForbiddenError):
        await delete_strategy(db_session, strategy=test_discount_strategy, user=test_users["customer"])


@pytest.mark.asyncio
async def test_discount_attach_and_list_event_strategies(
    db_session: AsyncSession, test_users, test_discount_strategy, test_event_approved
):
    """attach_to_event links strategy; list_event_strategies returns it."""
    from app.services.discount_strategy import attach_to_event, list_event_strategies

    link = await attach_to_event(
        db_session,
        event_id=test_event_approved.id,
        strategy_id=test_discount_strategy.id,
        user=test_users["organizer"],
        auto_apply=True,
    )
    assert link.event_id == test_event_approved.id
    assert link.auto_apply is True

    results = await list_event_strategies(db_session, event_id=test_event_approved.id)
    assert len(results) >= 1
    assert any(r["id"] == test_discount_strategy.id for r in results)


@pytest.mark.asyncio
async def test_discount_attach_duplicate_conflict(
    db_session: AsyncSession, test_users, test_discount_strategy, test_event_approved
):
    """Attaching same strategy twice raises ConflictError."""
    from app.services.discount_strategy import attach_to_event

    await attach_to_event(
        db_session,
        event_id=test_event_approved.id,
        strategy_id=test_discount_strategy.id,
        user=test_users["organizer"],
    )
    with pytest.raises(ConflictError, match="already attached"):
        await attach_to_event(
            db_session,
            event_id=test_event_approved.id,
            strategy_id=test_discount_strategy.id,
            user=test_users["organizer"],
        )


@pytest.mark.asyncio
async def test_discount_detach_from_event(
    db_session: AsyncSession, test_users, test_discount_strategy, test_event_approved
):
    """detach_from_event removes the link."""
    from app.services.discount_strategy import attach_to_event, detach_from_event, list_event_strategies

    await attach_to_event(
        db_session,
        event_id=test_event_approved.id,
        strategy_id=test_discount_strategy.id,
        user=test_users["organizer"],
    )
    await detach_from_event(
        db_session,
        event_id=test_event_approved.id,
        strategy_id=test_discount_strategy.id,
        user=test_users["organizer"],
    )
    results = await list_event_strategies(db_session, event_id=test_event_approved.id)
    assert not any(r["id"] == test_discount_strategy.id for r in results)


@pytest.mark.asyncio
async def test_discount_detach_nonexistent(
    db_session: AsyncSession, test_users, test_event_approved
):
    """Detaching a non-existent link raises NotFoundError."""
    from app.services.discount_strategy import detach_from_event

    with pytest.raises(NotFoundError):
        await detach_from_event(
            db_session,
            event_id=test_event_approved.id,
            strategy_id=999999,
            user=test_users["organizer"],
        )


# ═══════════════════════════════════════════════════════════════════════════
# Schedule Service
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_schedule_list(db_session: AsyncSession, test_event_approved, test_schedule_item):
    """list_schedule returns day groups with items."""
    from app.services.schedule import list_schedule

    groups = await list_schedule(db_session, test_event_approved.id)
    assert len(groups) >= 1
    assert any(
        item.id == test_schedule_item.id
        for group in groups
        for item in group.items
    )


@pytest.mark.asyncio
async def test_schedule_create_item(db_session: AsyncSession, test_event_approved, test_users):
    """create_item adds a schedule item to the event."""
    from app.services.schedule import create_item
    from app.schemas.schedule import ScheduleItemCreate

    event_date = test_event_approved.start_time.date().isoformat()
    data = ScheduleItemCreate(
        date=event_date,
        start_time="14:00",
        end_time="15:00",
        title="Workshop",
        description="A cool workshop",
    )
    resp = await create_item(db_session, test_event_approved.id, data, test_users["organizer"])
    assert resp.title == "Workshop"
    assert resp.start_time == "14:00"
    assert resp.end_time == "15:00"
    assert resp.event_id == test_event_approved.id


@pytest.mark.asyncio
async def test_schedule_create_invalid_times(db_session: AsyncSession, test_event_approved, test_users):
    """create_item rejects end_time <= start_time."""
    from app.services.schedule import create_item
    from app.schemas.schedule import ScheduleItemCreate

    event_date = test_event_approved.start_time.date().isoformat()
    data = ScheduleItemCreate(
        date=event_date,
        start_time="15:00",
        end_time="14:00",
        title="Bad",
    )
    with pytest.raises(ConflictError, match="end_time must be after"):
        await create_item(db_session, test_event_approved.id, data, test_users["organizer"])


@pytest.mark.asyncio
async def test_schedule_create_forbidden_for_non_organizer(
    db_session: AsyncSession, test_event_approved, test_users
):
    """Customer cannot create schedule items."""
    from app.services.schedule import create_item
    from app.schemas.schedule import ScheduleItemCreate

    event_date = test_event_approved.start_time.date().isoformat()
    data = ScheduleItemCreate(
        date=event_date,
        start_time="10:00",
        end_time="11:00",
        title="Unauthorized",
    )
    with pytest.raises(ForbiddenError):
        await create_item(db_session, test_event_approved.id, data, test_users["customer"])


@pytest.mark.asyncio
async def test_schedule_update_item(db_session: AsyncSession, test_event_approved, test_schedule_item, test_users):
    """Organizer can update a schedule item title."""
    from app.services.schedule import update_item
    from app.schemas.schedule import ScheduleItemUpdate

    data = ScheduleItemUpdate(title="Updated Title")
    resp = await update_item(db_session, test_schedule_item.id, data, test_users["organizer"])
    assert resp.title == "Updated Title"


@pytest.mark.asyncio
async def test_schedule_delete_item(db_session: AsyncSession, test_event_approved, test_users):
    """Organizer can delete a schedule item."""
    from app.services.schedule import create_item, delete_item
    from app.schemas.schedule import ScheduleItemCreate

    event_date = test_event_approved.start_time.date().isoformat()
    data = ScheduleItemCreate(
        date=event_date,
        start_time="16:00",
        end_time="17:00",
        title="To Delete",
    )
    created = await create_item(db_session, test_event_approved.id, data, test_users["organizer"])
    await delete_item(db_session, created.id, test_users["organizer"])
    # Verify it's gone
    from app.services.schedule import _get_or_404
    with pytest.raises(NotFoundError):
        await _get_or_404(db_session, created.id)


@pytest.mark.asyncio
async def test_schedule_delete_not_found(db_session: AsyncSession, test_users, test_event_approved):
    """Deleting non-existent item raises NotFoundError."""
    from app.services.schedule import delete_item

    with pytest.raises(NotFoundError):
        await delete_item(db_session, 999999, test_users["organizer"])


@pytest.mark.asyncio
async def test_schedule_bulk_create(db_session: AsyncSession, test_event_approved, test_users):
    """bulk_create adds multiple items at once."""
    from app.services.schedule import bulk_create
    from app.schemas.schedule import ScheduleItemCreate

    event_date = test_event_approved.start_time.date().isoformat()
    items = [
        ScheduleItemCreate(date=event_date, start_time="09:00", end_time="10:00", title="Talk A"),
        ScheduleItemCreate(date=event_date, start_time="10:00", end_time="11:00", title="Talk B"),
    ]
    results = await bulk_create(db_session, test_event_approved.id, items, test_users["organizer"])
    assert len(results) == 2
    assert results[0].title == "Talk A"
    assert results[1].title == "Talk B"


@pytest.mark.asyncio
async def test_schedule_overlap_detection(db_session: AsyncSession, test_event_approved, test_users):
    """Overlapping items on the same date are flagged."""
    from app.services.schedule import bulk_create, list_schedule
    from app.schemas.schedule import ScheduleItemCreate

    event_date = test_event_approved.start_time.date().isoformat()
    items = [
        ScheduleItemCreate(date=event_date, start_time="13:00", end_time="14:30", title="Overlap A"),
        ScheduleItemCreate(date=event_date, start_time="14:00", end_time="15:00", title="Overlap B"),
    ]
    await bulk_create(db_session, test_event_approved.id, items, test_users["organizer"])
    groups = await list_schedule(db_session, test_event_approved.id)

    overlap_titles = set()
    for group in groups:
        for item in group.items:
            if item.overlaps:
                overlap_titles.add(item.title)
    assert "Overlap A" in overlap_titles
    assert "Overlap B" in overlap_titles


# ═══════════════════════════════════════════════════════════════════════════
# Ticket Crypto Service
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_crypto_roundtrip_plaintext():
    """Encrypt/decrypt roundtrip in plaintext mode (no key)."""
    from app.services.ticket_crypto import _get_key_bytes

    # Clear lru_cache to ensure fresh state
    _get_key_bytes.cache_clear()

    from app.services.ticket_crypto import encrypt_ticket_qr, decrypt_ticket_qr

    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = ""
        _get_key_bytes.cache_clear()

        encrypted = encrypt_ticket_qr("TKT-PLAIN-001", 42, 99)
        decrypted = decrypt_ticket_qr(encrypted)
        assert decrypted["tc"] == "TKT-PLAIN-001"
        assert decrypted["eid"] == 42
        assert decrypted["sid"] == 99
        assert decrypted["v"] == 1

    _get_key_bytes.cache_clear()


@pytest.mark.asyncio
async def test_crypto_roundtrip_encrypted():
    """Encrypt/decrypt roundtrip with a real AES key."""
    from app.services.ticket_crypto import _get_key_bytes, encrypt_ticket_qr, decrypt_ticket_qr

    _get_key_bytes.cache_clear()
    # 32-byte key = 64 hex chars
    test_key = "a" * 64

    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = test_key
        _get_key_bytes.cache_clear()

        encrypted = encrypt_ticket_qr("TKT-ENC-001", 10, 20)
        # Should be base64, not plain JSON
        assert "{" not in encrypted

        decrypted = decrypt_ticket_qr(encrypted)
        assert decrypted["tc"] == "TKT-ENC-001"
        assert decrypted["eid"] == 10
        assert decrypted["sid"] == 20

    _get_key_bytes.cache_clear()


@pytest.mark.asyncio
async def test_crypto_decrypt_tampered_payload():
    """Decrypting tampered ciphertext raises ValueError."""
    from app.services.ticket_crypto import _get_key_bytes, encrypt_ticket_qr, decrypt_ticket_qr
    import base64

    _get_key_bytes.cache_clear()
    test_key = "b" * 64

    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = test_key
        _get_key_bytes.cache_clear()

        encrypted = encrypt_ticket_qr("TKT-TAMPER", 1, 1)
        # Tamper with the payload
        raw = base64.urlsafe_b64decode(encrypted)
        tampered = raw[:-1] + bytes([raw[-1] ^ 0xFF])
        tampered_b64 = base64.urlsafe_b64encode(tampered).decode()

        with pytest.raises(ValueError, match="Decryption failed"):
            decrypt_ticket_qr(tampered_b64)

    _get_key_bytes.cache_clear()


@pytest.mark.asyncio
async def test_crypto_encryption_enabled_flag():
    """encryption_enabled reflects whether a key is configured."""
    from app.services.ticket_crypto import _get_key_bytes, encryption_enabled

    _get_key_bytes.cache_clear()

    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = ""
        _get_key_bytes.cache_clear()
        assert encryption_enabled() is False

    _get_key_bytes.cache_clear()

    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = "c" * 64
        _get_key_bytes.cache_clear()
        assert encryption_enabled() is True

    _get_key_bytes.cache_clear()


@pytest.mark.asyncio
async def test_crypto_invalid_key_length():
    """Non-32-byte hex key disables encryption."""
    from app.services.ticket_crypto import _get_key_bytes, encryption_enabled

    _get_key_bytes.cache_clear()

    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = "aa"  # 1 byte
        _get_key_bytes.cache_clear()
        assert encryption_enabled() is False

    _get_key_bytes.cache_clear()


@pytest.mark.asyncio
async def test_crypto_decrypt_no_key_invalid_payload():
    """Decrypting non-JSON payload without a key raises ValueError."""
    from app.services.ticket_crypto import _get_key_bytes, decrypt_ticket_qr

    _get_key_bytes.cache_clear()

    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = ""
        _get_key_bytes.cache_clear()

        with pytest.raises(ValueError, match="not configured"):
            decrypt_ticket_qr("not-valid-json!!!")

    _get_key_bytes.cache_clear()


# ═══════════════════════════════════════════════════════════════════════════
# Ticket Strategy Service
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_ticket_strategy_list(db_session: AsyncSession, test_users, test_ticket_strategy):
    """list_strategies returns organizer's strategies."""
    from app.services.ticket_strategy import list_strategies

    results = await list_strategies(db_session, organizer_id=test_users["organizer"].id)
    assert len(results) >= 1
    assert any(s.id == test_ticket_strategy.id for s in results)


@pytest.mark.asyncio
async def test_ticket_strategy_list_empty(db_session: AsyncSession, test_users, test_ticket_strategy):
    """list_strategies returns empty for unrelated user."""
    from app.services.ticket_strategy import list_strategies

    results = await list_strategies(db_session, organizer_id=test_users["customer"].id)
    assert len(results) == 0


@pytest.mark.asyncio
async def test_ticket_strategy_get_or_404(db_session: AsyncSession, test_ticket_strategy):
    """get_or_404 returns the strategy with tiers loaded."""
    from app.services.ticket_strategy import get_or_404

    s = await get_or_404(db_session, test_ticket_strategy.id)
    assert s.id == test_ticket_strategy.id
    assert len(s.tiers) >= 1


@pytest.mark.asyncio
async def test_ticket_strategy_get_or_404_missing(db_session: AsyncSession, test_users):
    """get_or_404 raises NotFoundError for non-existent id."""
    from app.services.ticket_strategy import get_or_404

    with pytest.raises(NotFoundError):
        await get_or_404(db_session, 999999)


@pytest.mark.asyncio
async def test_ticket_strategy_create(db_session: AsyncSession, test_users):
    """create builds strategy + tiers."""
    from app.services.ticket_strategy import create

    s = await create(
        db_session,
        organizer_id=test_users["organizer"].id,
        name="VIP Tiers",
        tiers=[
            {"name": "Gold", "price_cents": 5000},
            {"name": "Silver", "price_cents": 3000, "description": "Budget option"},
        ],
    )
    assert s.name == "VIP Tiers"
    assert len(s.tiers) == 2
    tier_names = {t.name for t in s.tiers}
    assert "Gold" in tier_names
    assert "Silver" in tier_names


@pytest.mark.asyncio
async def test_ticket_strategy_update_name(db_session: AsyncSession, test_users, test_ticket_strategy):
    """Owner can update strategy name."""
    from app.services.ticket_strategy import update, get_or_404

    # Reload with tiers
    strategy = await get_or_404(db_session, test_ticket_strategy.id)
    updated = await update(db_session, strategy, test_users["organizer"], name="Renamed Strategy")
    assert updated.name == "Renamed Strategy"


@pytest.mark.asyncio
async def test_ticket_strategy_update_tiers(db_session: AsyncSession, test_users):
    """Updating tiers replaces all existing tiers."""
    from app.services.ticket_strategy import create, update
    from sqlalchemy import select

    # Create a fresh strategy to avoid stale identity-map issues with the fixture
    strategy = await create(
        db_session,
        organizer_id=test_users["organizer"].id,
        name="Tier Replace Test",
        tiers=[{"name": "OldTier", "price_cents": 1000}],
    )
    assert len(strategy.tiers) == 1

    updated = await update(
        db_session,
        strategy,
        test_users["organizer"],
        tiers=[
            {"name": "Platinum", "price_cents": 10000},
            {"name": "Diamond", "price_cents": 15000},
            {"name": "Basic", "price_cents": 1000},
        ],
    )
    # Verify via direct DB query to avoid session identity-map caching
    q = select(TicketStrategyTier).where(TicketStrategyTier.strategy_id == updated.id)
    db_tiers = list((await db_session.execute(q)).scalars().all())
    assert len(db_tiers) == 3
    tier_names = {t.name for t in db_tiers}
    assert "Platinum" in tier_names
    assert "Diamond" in tier_names
    assert "Basic" in tier_names


@pytest.mark.asyncio
async def test_ticket_strategy_update_forbidden(db_session: AsyncSession, test_users, test_ticket_strategy):
    """Non-owner cannot update strategy."""
    from app.services.ticket_strategy import update, get_or_404

    strategy = await get_or_404(db_session, test_ticket_strategy.id)
    with pytest.raises(ForbiddenError):
        await update(db_session, strategy, test_users["customer"], name="Hacked")


@pytest.mark.asyncio
async def test_ticket_strategy_delete(db_session: AsyncSession, test_users):
    """Owner can delete their strategy."""
    from app.services.ticket_strategy import create, delete, get_or_404

    s = await create(
        db_session,
        organizer_id=test_users["organizer"].id,
        name="Temp Strategy",
        tiers=[{"name": "T1", "price_cents": 1000}],
    )
    await delete(db_session, s, test_users["organizer"])
    with pytest.raises(NotFoundError):
        await get_or_404(db_session, s.id)


@pytest.mark.asyncio
async def test_ticket_strategy_delete_forbidden(db_session: AsyncSession, test_users, test_ticket_strategy):
    """Non-owner cannot delete strategy."""
    from app.services.ticket_strategy import delete, get_or_404

    strategy = await get_or_404(db_session, test_ticket_strategy.id)
    with pytest.raises(ForbiddenError):
        await delete(db_session, strategy, test_users["customer"])


@pytest.mark.asyncio
async def test_ticket_strategy_apply_to_event(db_session: AsyncSession, test_users, test_ticket_strategy, test_event_approved):
    """apply_strategy_to_event copies tiers into TicketTier rows."""
    from app.services.ticket_strategy import apply_strategy_to_event
    from app.models.ticket import TicketTier
    from sqlalchemy import select

    await apply_strategy_to_event(db_session, strategy_id=test_ticket_strategy.id, event_id=test_event_approved.id)

    q = select(TicketTier).where(TicketTier.event_id == test_event_approved.id)
    tiers = (await db_session.execute(q)).scalars().all()
    # The conftest already creates a "General" tier from test_ticket_strategy
    tier_names = {t.name for t in tiers}
    assert "General" in tier_names


# ═══════════════════════════════════════════════════════════════════════════
# Venue Service
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_venue_list_all(db_session: AsyncSession, test_venue):
    """list_venues with no filters returns all venues."""
    from app.services.venue import list_venues

    results = await list_venues(db_session)
    assert len(results) >= 1
    assert any(v.id == test_venue.id for v in results)


@pytest.mark.asyncio
async def test_venue_list_by_organizer(db_session: AsyncSession, test_users, test_venue):
    """list_venues filtered by organizer_id."""
    from app.services.venue import list_venues

    results = await list_venues(db_session, organizer_id=test_users["organizer"].id)
    assert len(results) >= 1
    assert all(v.organizer_id == test_users["organizer"].id for v in results)


@pytest.mark.asyncio
async def test_venue_list_by_city(db_session: AsyncSession, test_venue):
    """list_venues filtered by city."""
    from app.services.venue import list_venues

    results = await list_venues(db_session, city="Ottawa")
    assert len(results) >= 1
    assert all(v.city == "Ottawa" for v in results)


@pytest.mark.asyncio
async def test_venue_get_or_404(db_session: AsyncSession, test_venue):
    """get_or_404 returns existing venue."""
    from app.services.venue import get_or_404

    v = await get_or_404(db_session, test_venue.id)
    assert v.id == test_venue.id


@pytest.mark.asyncio
async def test_venue_get_or_404_missing(db_session: AsyncSession, test_users):
    """get_or_404 raises NotFoundError for non-existent id."""
    from app.services.venue import get_or_404

    with pytest.raises(NotFoundError):
        await get_or_404(db_session, 999999)


@pytest.mark.asyncio
async def test_venue_create(db_session: AsyncSession, test_users):
    """create builds a new venue."""
    from app.services.venue import create

    v = await create(
        db_session,
        organizer_id=test_users["organizer"].id,
        name="New Arena",
        address="456 Arena Blvd",
        city="Toronto",
        province="ON",
        lat=43.65,
        lng=-79.38,
        max_capacity=500,
    )
    assert v.id is not None
    assert v.name == "New Arena"
    assert v.city == "Toronto"
    assert v.max_capacity == 500


@pytest.mark.asyncio
async def test_venue_create_invalid_capacity(db_session: AsyncSession, test_users):
    """create rejects capacity <= 0."""
    from app.services.venue import create

    with pytest.raises(ConflictError, match="max_capacity"):
        await create(
            db_session,
            organizer_id=test_users["organizer"].id,
            name="Bad Venue",
            address="1 Fail St",
            city="Nowhere",
            province=None,
            lat=None,
            lng=None,
            max_capacity=0,
        )


@pytest.mark.asyncio
async def test_venue_update(db_session: AsyncSession, test_venue):
    """update modifies venue fields."""
    from app.services.venue import update

    updated = await update(db_session, test_venue, name="Renamed Hall", max_capacity=200)
    assert updated.name == "Renamed Hall"
    assert updated.max_capacity == 200


@pytest.mark.asyncio
async def test_venue_update_invalid_capacity(db_session: AsyncSession, test_venue):
    """update rejects capacity <= 0."""
    from app.services.venue import update

    with pytest.raises(ConflictError, match="max_capacity"):
        await update(db_session, test_venue, max_capacity=-1)


@pytest.mark.asyncio
async def test_venue_can_edit_permission(test_users, test_venue):
    """can_edit_venue returns True for owner, False for others."""
    from app.services.venue import can_edit_venue

    assert can_edit_venue(test_users["organizer"].id, test_venue, is_admin=False) is True
    assert can_edit_venue(test_users["customer"].id, test_venue, is_admin=False) is False
    assert can_edit_venue(test_users["customer"].id, test_venue, is_admin=True) is True


# ═══════════════════════════════════════════════════════════════════════════
# Post Service
# ═══════════════════════════════════════════════════════════════════════════


@pytest.mark.asyncio
async def test_post_list(db_session: AsyncSession, test_event_approved, test_event_post):
    """list_posts returns posts for the event."""
    from app.services.post import list_posts

    results = await list_posts(db_session, event_id=test_event_approved.id)
    assert len(results) >= 1
    assert any(p.id == test_event_post.id for p in results)


@pytest.mark.asyncio
async def test_post_create_by_organizer(db_session: AsyncSession, test_event_approved, test_users):
    """Organizer can create a post (no registration needed)."""
    from app.services.post import create_post

    post = await create_post(
        db_session,
        event_id=test_event_approved.id,
        user=test_users["organizer"],
        content="Hello from organizer!",
    )
    assert post.content == "Hello from organizer!"
    assert post.user_id == test_users["organizer"].id
    assert post.event_id == test_event_approved.id


@pytest.mark.asyncio
async def test_post_create_empty_content_rejected(db_session: AsyncSession, test_event_approved, test_users):
    """Empty content is rejected."""
    from app.services.post import create_post

    with pytest.raises(ConflictError, match="empty"):
        await create_post(
            db_session,
            event_id=test_event_approved.id,
            user=test_users["organizer"],
            content="   ",
        )


@pytest.mark.asyncio
async def test_post_create_unregistered_customer_forbidden(
    db_session: AsyncSession, test_event_approved, test_users
):
    """Unregistered customer cannot post."""
    from app.services.post import create_post

    with pytest.raises(ForbiddenError, match="registered"):
        await create_post(
            db_session,
            event_id=test_event_approved.id,
            user=test_users["customer"],
            content="I want to post!",
        )


@pytest.mark.asyncio
async def test_post_create_registered_customer(
    db_session: AsyncSession, test_event_approved, test_users, test_registration
):
    """Registered customer can post."""
    from app.services.post import create_post

    post = await create_post(
        db_session,
        event_id=test_event_approved.id,
        user=test_users["customer"],
        content="Customer post!",
    )
    assert post.content == "Customer post!"


@pytest.mark.asyncio
async def test_post_delete_by_author(
    db_session: AsyncSession, test_event_approved, test_users, test_event_post
):
    """Author can delete their own post."""
    from app.services.post import delete_post

    await delete_post(
        db_session,
        event_id=test_event_approved.id,
        post_id=test_event_post.id,
        user=test_users["organizer"],  # the author
    )
    # Verify it's gone
    from sqlalchemy import select
    q = select(EventPost).where(EventPost.id == test_event_post.id)
    result = (await db_session.execute(q)).scalar_one_or_none()
    assert result is None


@pytest.mark.asyncio
async def test_post_delete_not_found(db_session: AsyncSession, test_event_approved, test_users):
    """Deleting non-existent post raises NotFoundError."""
    from app.services.post import delete_post

    with pytest.raises(NotFoundError):
        await delete_post(
            db_session,
            event_id=test_event_approved.id,
            post_id=999999,
            user=test_users["organizer"],
        )


@pytest.mark.asyncio
async def test_post_toggle_disable(db_session: AsyncSession, test_event_approved, test_users):
    """Organizer can disable posts on event."""
    from app.services.post import toggle_posts

    event = await toggle_posts(
        db_session,
        event_id=test_event_approved.id,
        user=test_users["organizer"],
        enabled=False,
    )
    assert event.posts_enabled is False


@pytest.mark.asyncio
async def test_post_create_when_disabled(db_session: AsyncSession, test_event_approved, test_users):
    """Cannot create post when posts are disabled."""
    from app.services.post import toggle_posts, create_post

    await toggle_posts(
        db_session,
        event_id=test_event_approved.id,
        user=test_users["organizer"],
        enabled=False,
    )
    with pytest.raises(ConflictError, match="disabled"):
        await create_post(
            db_session,
            event_id=test_event_approved.id,
            user=test_users["organizer"],
            content="Should fail",
        )


@pytest.mark.asyncio
async def test_post_toggle_forbidden_for_non_organizer(
    db_session: AsyncSession, test_event_approved, test_users
):
    """Customer cannot toggle posts."""
    from app.services.post import toggle_posts

    with pytest.raises(ForbiddenError):
        await toggle_posts(
            db_session,
            event_id=test_event_approved.id,
            user=test_users["customer"],
            enabled=False,
        )
