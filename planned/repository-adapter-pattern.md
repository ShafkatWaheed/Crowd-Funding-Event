# Plan: Decouple Data Layer with Repository + Unit of Work Pattern

## Context

The service layer (55 files, 13,500 LOC) is tightly coupled to SQLAlchemy — every service function accepts `db: AsyncSession` and directly uses `select()`, `db.add()`, `db.flush()`, `selectinload()`, `func.sum()`, etc. If a future database swap (e.g., MongoDB) is needed, every service file must be rewritten.

**Goal:** Introduce a Repository + Unit of Work abstraction so that services depend on interfaces, not SQLAlchemy. The database implementation becomes swappable without touching service logic.

---

## Architecture Overview

```
Before:  Route → Service(db: AsyncSession) → SQLAlchemy queries → PostgreSQL
After:   Route → Service(uow: AbstractUnitOfWork) → uow.events.get_by_id() → [SQLAlchemy impl] → PostgreSQL
                                                                              → [Motor impl]    → MongoDB (future)
```

Swapping backends is a one-line change in `dependencies.py` — point `get_uow()` at a different implementation.

---

## New Directory Structure

```
Backend/app/
├── domain/                          # NEW — pure Python, zero SQLAlchemy imports
│   ├── enums.py                     # All 18 enums extracted here
│   ├── entities/                    # Dataclass domain objects
│   │   ├── event.py                 # EventEntity, EventOrganizerEntity, etc.
│   │   ├── user.py                  # UserEntity
│   │   ├── funding.py               # FundingEntity, PledgeSpotReservationEntity
│   │   ├── ticket.py                # TicketSaleEntity, TicketTierEntity
│   │   ├── registration.py          # RegistrationEntity
│   │   ├── escrow.py                # FundEscrowEntity, TicketEscrowEntity, SponsorEscrowEntity
│   │   ├── sponsor.py               # SponsorBidEntity, SponsorPaymentEntity, etc.
│   │   ├── ledger.py                # LedgerEntryEntity
│   │   ├── notification.py          # NotificationEntity
│   │   ├── venue.py                 # VenueEntity
│   │   └── settings.py              # PlatformSettingEntity
│   ├── repositories/                # Abstract interfaces (ABCs)
│   │   ├── base.py                  # BaseRepository[T] — generic CRUD
│   │   ├── event.py                 # AbstractEventRepository
│   │   ├── funding.py               # AbstractFundingRepository
│   │   ├── ticket.py                # AbstractTicketRepository
│   │   ├── registration.py          # AbstractRegistrationRepository
│   │   ├── escrow.py                # AbstractEscrowRepository
│   │   ├── user.py                  # AbstractUserRepository
│   │   ├── venue.py                 # AbstractVenueRepository
│   │   ├── sponsor.py               # AbstractSponsorRepository
│   │   ├── ledger.py                # AbstractLedgerRepository
│   │   ├── notification.py          # AbstractNotificationRepository
│   │   ├── settings.py              # AbstractSettingsRepository
│   │   └── analytics.py             # AbstractAnalyticsRepository (dashboard/admin aggregations)
│   └── uow.py                      # AbstractUnitOfWork
├── infra/                           # NEW — implementation layer
│   └── sqlalchemy/
│       ├── repositories/            # Concrete SQLAlchemy implementations
│       │   ├── base.py              # SqlAlchemyBaseRepository[T, M]
│       │   ├── event.py             # SqlAlchemyEventRepository
│       │   ├── funding.py
│       │   ├── ticket.py
│       │   ├── registration.py
│       │   ├── escrow.py
│       │   ├── user.py
│       │   ├── venue.py
│       │   ├── sponsor.py
│       │   ├── ledger.py
│       │   ├── notification.py
│       │   ├── settings.py
│       │   └── analytics.py         # Complex SQL aggregation queries
│       ├── mappers/                  # ORM model ↔ domain entity conversion
│       │   ├── event.py
│       │   ├── user.py
│       │   ├── funding.py
│       │   └── ...                   # One per entity group
│       └── uow.py                   # SqlAlchemyUnitOfWork
├── models/                          # UNCHANGED — ORM models stay for Alembic
├── services/                        # MIGRATED incrementally
├── api/                             # MIGRATED incrementally
├── schemas/                         # UNCHANGED
└── dependencies.py                  # UPDATED — adds UoW/ReadUoW alongside existing
```

---

## Key Design Decisions

### 1. Domain Entities = Mutable Dataclasses

Services need to mutate state (`event.status = EventStatus.live`), so entities are mutable `@dataclass` classes. Relationships are optional fields (`venue: VenueEntity | None = None`) populated on request via `load_relations`.

### 2. Enums Extracted to `domain/enums.py`

All 18 enums move to one file. Model files re-export them for backward compatibility:
```python
# models/event.py (keeps working during migration)
from app.domain.enums import EventStatus, RegistrationType
```

### 3. Unit of Work = Transaction Boundary + Repository Access

```python
class AbstractUnitOfWork(ABC):
    events: AbstractEventRepository
    users: AbstractUserRepository
    fundings: AbstractFundingRepository
    tickets: AbstractTicketRepository
    registrations: AbstractRegistrationRepository
    escrows: AbstractEscrowRepository
    sponsors: AbstractSponsorRepository
    ledger: AbstractLedgerRepository
    notifications: AbstractNotificationRepository
    settings: AbstractSettingsRepository
    analytics: AbstractAnalyticsRepository

    async def commit(self) -> None: ...
    async def rollback(self) -> None: ...
    async def flush(self) -> None: ...           # replaces db.flush()
    async def refresh(self, entity) -> None: ...  # replaces db.refresh()
    async def acquire_lock(self, resource_type: str, resource_id: int) -> None: ...
    # PG impl: pg_advisory_xact_lock(resource_id)
    # Mongo impl: Redis distributed lock or lock collection
```

### 4. Relationship Loading via Explicit Methods (not strings)

```python
# Separate methods — explicit, type-safe, IDE-friendly
event = await uow.events.get_by_id(event_id)                          # bare entity (only scalar fields)
event = await uow.events.get_with_venue(event_id)                     # + venue populated
event = await uow.events.get_with_details(event_id)                   # + venue + organizer + tiers

sale = await uow.tickets.get_by_id(sale_id)                           # bare
sale = await uow.tickets.get_with_relations(sale_id)                  # + event + tier + user

# List methods bake in the relations they always need
pledges = await uow.fundings.list_organizer_pledges(organizer_id)     # each has .event + .user
sales = await uow.tickets.list_by_event(event_id)                     # each has .user + .tier
```

Each repo defines only the combinations actually used in the codebase — no unused permutations. The PG implementation uses `selectinload()` internally. A MongoDB implementation would use separate lookups or `$lookup` aggregation.

### 5. Concurrency Abstractions

| Current (SQLAlchemy) | New (Abstract) |
|---|---|
| `text("SELECT pg_advisory_xact_lock(:eid)")` | `uow.acquire_lock("event", event_id)` |
| `.with_for_update()` | `uow.events.get_for_update(event_id)` |
| `pg_insert(...).on_conflict_do_nothing(...)` | `uow.escrows.get_or_create_fund_escrow(event_id, total)` |

### 6. Analytics Repository for Complex Queries

Dashboard (`func.sum(case(...))`, `union_all`, `date_trunc`) and admin analytics don't fit CRUD repos. They get a dedicated `AbstractAnalyticsRepository` that returns dicts — each DB implementation builds queries its own way.

### 7. Dependency Injection

```python
# dependencies.py — new aliases coexist with old ones
UoW = Annotated[AbstractUnitOfWork, Depends(get_uow)]        # write
ReadUoW = Annotated[AbstractUnitOfWork, Depends(get_read_uow)] # read-only
```

---

## Before/After Example: `registration.py`

**Before** (`Backend/app/services/registration.py`):
```python
async def register(db: AsyncSession, *, event_id: int, user: User) -> Registration:
    await db.execute(text("SELECT pg_advisory_xact_lock(:eid)"), {"eid": event_id})
    event = (await db.execute(select(Event).where(Event.id == event_id).with_for_update())).scalar_one_or_none()
    existing = (await db.execute(select(Registration).where(...))).scalar_one_or_none()
    reg = Registration(event_id=event_id, user_id=user.id, status=target_status)
    db.add(reg)
    await db.flush()
```

**After:**
```python
async def register(uow: AbstractUnitOfWork, *, event_id: int, user: UserEntity) -> RegistrationEntity:
    await uow.acquire_lock("event", event_id)
    event = await uow.events.get_for_update(event_id)
    existing = await uow.registrations.get_by_event_and_user(event_id, user.id)
    reg = RegistrationEntity(event_id=event_id, user_id=user.id, status=target_status)
    reg = await uow.registrations.create(reg)
    await uow.flush()
```

Zero SQLAlchemy imports. Swappable backend.

---

## Scope Decision
- **Scope:** Full migration (all 5 phases — 55 service files, workers, cleanup)
- **Return types:** Domain entities (full decoupling) — services return dataclasses, NOT ORM models
- **Schema mapping:** Pydantic schemas will use `from_attributes=True` on dataclass entities (works natively since dataclasses have attributes)

---

## Implementation Phases with Step-by-Step Verification

### Phase 1: Foundation (no behavior change)

**Step 1.1: Extract enums**
- [ ] Create `Backend/app/domain/__init__.py`
- [ ] Create `Backend/app/domain/enums.py` with all 18 enums
- [ ] Update each model file to re-export from `domain.enums` instead of defining locally
- **Verify:** Start the server (`uvicorn app.main:app`), hit `GET /events` — should return 200 with same data

**Step 1.2: Create domain entities**
- [ ] Create `Backend/app/domain/entities/__init__.py`
- [ ] Create entity dataclasses: `event.py`, `user.py`, `funding.py`, `ticket.py`, `registration.py`, `escrow.py`, `sponsor.py`, `ledger.py`, `notification.py`, `venue.py`, `settings.py`
- **Verify:** `python -c "from app.domain.entities.event import EventEntity; print('OK')"` — no import errors

**Step 1.3: Create repository interfaces**
- [ ] Create `Backend/app/domain/repositories/__init__.py`
- [ ] Create `Backend/app/domain/repositories/base.py` — `BaseRepository[T]` with `get_by_id`, `create`, `update`, `delete`, `exists`
- [ ] Create abstract repos: `event.py`, `funding.py`, `ticket.py`, `registration.py`, `escrow.py`, `user.py`, `venue.py`, `sponsor.py`, `ledger.py`, `notification.py`, `settings.py`, `analytics.py`
- [ ] Create `Backend/app/domain/uow.py` — `AbstractUnitOfWork`
- **Verify:** `python -c "from app.domain.uow import AbstractUnitOfWork; print('OK')"` — no import errors

**Step 1.4: Create ORM ↔ entity mappers**
- [ ] Create `Backend/app/infra/__init__.py`
- [ ] Create `Backend/app/infra/sqlalchemy/__init__.py`
- [ ] Create `Backend/app/infra/sqlalchemy/mappers/` — one mapper per entity group with `to_entity()` and `to_model()` methods
- **Verify:** Write a quick script that loads an Event from DB, converts to EventEntity and back — data preserved

**Step 1.5: Create SQLAlchemy repository implementations**
- [ ] Create `Backend/app/infra/sqlalchemy/repositories/__init__.py`
- [ ] Create `Backend/app/infra/sqlalchemy/repositories/base.py` — `SqlAlchemyBaseRepository[T, M]`
- [ ] Create concrete repos: `event.py`, `funding.py`, `ticket.py`, `registration.py`, `escrow.py`, `user.py`, `venue.py`, `sponsor.py`, `ledger.py`, `notification.py`, `settings.py`, `analytics.py`
- **Verify:** Start server, hit `GET /events` — still 200 (nothing uses repos yet, but they import cleanly)

**Step 1.6: Create SqlAlchemyUnitOfWork + DI wiring**
- [ ] Create `Backend/app/infra/sqlalchemy/uow.py` — `SqlAlchemyUnitOfWork` with `.session` bridge property
- [ ] Add `get_uow()`, `get_read_uow()`, `UoW`, `ReadUoW` to `Backend/app/dependencies.py`
- **Verify:** Start server — all existing endpoints work unchanged. New `UoW` dependency is available but unused.

---

### Phase 2: Migrate simple services

**Step 2.1: Migrate `venue.py`**
- [ ] Change `Backend/app/services/venue.py`: `db: AsyncSession` → `uow: AbstractUnitOfWork`
- [ ] Replace `select(Venue)` → `uow.venues.get_by_id()`, `db.add()` → `uow.venues.create()`, etc.
- [ ] Update `Backend/app/api/v1/venues.py`: `db: DbSession` → `uow: UoW`, `db: ReadDbSession` → `uow: ReadUoW`
- **Verify:**
  - `POST /venues` — create a venue → 201
  - `GET /venues/{id}` — read it back → 200, correct data
  - `PATCH /venues/{id}` — update name → 200, name changed
  - `DELETE /venues/{id}` — delete → 204

**Step 2.2: Migrate `platform_settings.py`**
- [ ] Migrate service: `db` → `uow`, SQLAlchemy → repo calls
- [ ] Update `Backend/app/api/v1/config.py` route
- [ ] Update `require_feature()` and `require_kyc()` in `dependencies.py` to use UoW
- **Verify:**
  - `GET /config` — returns platform settings → 200
  - `PATCH /admin/config/{key}` — update a setting → 200
  - Feature gates still work (test a gated endpoint)

**Step 2.3: Migrate `notification_service.py`**
- [ ] Migrate service
- [ ] Update `Backend/app/api/v1/notifications.py` route
- **Verify:**
  - `GET /notifications` — returns user notifications → 200
  - `PATCH /notifications/{id}/read` — mark read → 200
  - Trigger a notification (e.g., register for event) — notification appears in list

**Step 2.4: Migrate `post.py`**
- [ ] Migrate service
- [ ] Update `Backend/app/api/v1/events/posts.py` route
- **Verify:**
  - `POST /events/{id}/posts` — create post → 201
  - `GET /events/{id}/posts` — list posts → 200
  - `DELETE /events/{id}/posts/{id}` — delete → 204

**Step 2.5: Migrate `schedule.py`**
- [ ] Migrate service
- [ ] Update `Backend/app/api/v1/schedule.py` route
- **Verify:**
  - `POST /events/{id}/schedule` — add item → 201
  - `GET /events/{id}/schedule` — list items → 200
  - `PATCH /events/{id}/schedule/{id}` — update → 200
  - `DELETE /events/{id}/schedule/{id}` — delete → 204

---

### Phase 3: Migrate financial/concurrency services

**Step 3.1: Migrate `ledger.py`**
- [ ] Move aggregation queries to `SqlAlchemyAnalyticsRepository`
- [ ] Migrate record_entries/record_charge to use `uow.ledger.create()`
- [ ] Update `Backend/app/api/v1/banking.py` (ledger endpoints)
- **Verify:**
  - `GET /banking/ledger/balance` — returns balanced debits/credits
  - Purchase a ticket → check ledger entries created correctly
  - `total_debits == total_credits` after operations

**Step 3.2: Migrate `registration.py`**
- [ ] Replace `pg_advisory_xact_lock` → `uow.acquire_lock("event", event_id)`
- [ ] Replace `select(Event).with_for_update()` → `uow.events.get_for_update(event_id)`
- [ ] Replace all SQLAlchemy queries with repo calls
- [ ] Update `Backend/app/api/v1/events/registration.py` route
- **Verify:**
  - `POST /events/{id}/register` — register → 201
  - `DELETE /events/{id}/register` — unregister → 200
  - Capacity enforcement: set max_capacity=1, register 2 users → second gets waitlisted
  - Concurrency: 10 parallel register requests → no overselling

**Step 3.3: Migrate `funding/reservations.py`**
- [ ] Replace FOR UPDATE with `uow.fundings.get_oldest_with_spots_for_update()`
- [ ] Update calling services
- **Verify:**
  - Pledge with reserved spots → spots counted correctly
  - Purchase ticket consuming reserved spot → spot decremented
  - No double-consumption under concurrent requests

**Step 3.4: Migrate `funding/pledges.py`**
- [ ] Replace advisory lock + all SQLAlchemy queries
- [ ] Milestone snapshot logic uses repo methods
- [ ] Update `Backend/app/api/v1/events/pledge.py` route
- **Verify:**
  - `POST /events/{id}/pledge` — create pledge → 201
  - `POST /events/{id}/unpledge` — remove pledge → 200
  - `GET /events/{id}/pledge/preview` — returns correct amounts
  - Milestone: pledge enough to cross threshold → snapshot created
  - `GET /me/pledges` — paginated list → 200

**Step 3.5: Migrate `ticket/tiers.py`**
- [ ] Simple CRUD migration
- [ ] Update `Backend/app/api/v1/events/tickets.py` (tier endpoints)
- **Verify:**
  - `POST /events/{id}/ticket-tiers` — create tier → 201
  - `GET /events/{id}/ticket-tiers` — list → 200
  - `PATCH /events/{id}/ticket-tiers/{id}` — update → 200

**Step 3.6: Migrate `ticket/pricing.py`**
- [ ] Replace discount/milestone queries with repo calls
- **Verify:**
  - Purchase ticket with various discounts → correct price calculated
  - Early bird discount applies within window
  - Milestone discount applies when milestone reached

**Step 3.7: Migrate `ticket/sales.py`**
- [ ] Replace advisory lock → `uow.acquire_lock()`
- [ ] Replace all 60+ selectinload calls with `load_relations`
- [ ] Escrow interaction via `uow.escrows`
- [ ] Update `Backend/app/api/v1/events/tickets.py` (sales endpoints)
- **Verify:**
  - `POST /events/{id}/tickets/purchase` — buy ticket → 201
  - Receipt number generated correctly
  - Escrow updated after purchase
  - `POST /events/{id}/tickets/{id}/scan` — scan QR → 200
  - `POST /events/{id}/tickets/refund` — request refund → 200
  - `GET /events/{id}/ticket-sales` — organizer sees sales → 200
  - `GET /me/tickets` — customer sees tickets → 200
  - Concurrent purchase of last ticket → only one succeeds

**Step 3.8: Migrate `escrow.py` + `ticket_escrow.py` + `sponsor_escrow.py`**
- [ ] Replace `pg_insert().on_conflict_do_nothing()` → `uow.escrows.get_or_create_*()`
- [ ] Replace release logic with repo update methods
- [ ] Update `Backend/app/api/v1/banking.py` (escrow endpoints)
- **Verify:**
  - Create pledge → fund escrow created/updated
  - Purchase ticket → ticket escrow created/updated
  - Stage release triggers at correct thresholds
  - `GET /banking/escrow/{event_id}` — returns correct escrow state

---

### Phase 4: Migrate remaining services

**Step 4.1: Migrate `event/crud.py`**
- [ ] Replace 850 lines of SQLAlchemy with repo calls
- [ ] `list_events` with 20+ filters → `uow.events.list_events()`
- [ ] Auto-transition logic → `uow.events.get_for_update()` + status updates
- [ ] Update `Backend/app/api/v1/events/crud.py` route
- **Verify:**
  - `POST /events` — create event → 201
  - `GET /events` — list with filters (search, city, status, genre, date range, cursor) → 200
  - `GET /events/{id}` — single event with relations → 200
  - `PATCH /events/{id}` — update → 200
  - `DELETE /events/{id}` — cancel → 200
  - Auto-transition: event past start_time → status becomes live

**Step 4.2: Migrate `event/lifecycle.py`**
- [ ] Status transitions use repo methods
- [ ] Update route
- **Verify:**
  - Admin approve event → status changes
  - Start ticket selling → status changes
  - Event cancellation → all pledges refunded, all tickets refunded

**Step 4.3: Migrate `event/queries.py`**
- [ ] Replace subquery-based filters
- [ ] Update routes (`/me/events`, `/co-organized-events`)
- **Verify:**
  - `GET /me/events` — user's registered events → 200
  - `GET /co-organized-events` — co-organizer events → 200
  - Sponsorship-only event listing filter works

**Step 4.4: Migrate `event/permissions.py`**
- [ ] Replace permission-check queries
- **Verify:** Permission checks still block unauthorized users

**Step 4.5: Migrate `event/organizers.py`**
- [ ] Replace co-organizer CRUD queries
- [ ] Update route
- **Verify:**
  - Invite co-organizer → 201
  - Accept/decline invitation → 200
  - Remove co-organizer → 200

**Step 4.6: Migrate `event/discounts.py`**
- [ ] Replace discount CRUD
- [ ] Update route
- **Verify:**
  - Create/update/delete event discounts → correct responses

**Step 4.7: Migrate `event/attendance.py`**
- [ ] Replace customer history queries
- [ ] Update route
- **Verify:**
  - `GET /customers` — organizer's customer list → 200

**Step 4.8: Migrate all `sponsor/` services**
- [ ] `bids.py`, `payments.py`, `categories.py`, `tickets.py`, `delegates.py`, `organizer_queries.py`, `templates.py`
- [ ] Update all routes in `Backend/app/api/v1/sponsors/`
- **Verify:**
  - Full sponsor flow: create category → submit bid → accept bid → pay → generate ticket → add delegate → check-in
  - `GET /sponsors/bids` — list bids → 200
  - `POST /sponsors/bids/{id}/pay` — payment → 201

**Step 4.9: Migrate `dashboard.py` → analytics repo**
- [ ] Move all aggregation queries to `SqlAlchemyAnalyticsRepository.get_organizer_dashboard()`
- [ ] Service becomes thin wrapper calling `uow.analytics`
- [ ] Update `Backend/app/api/v1/users.py` (dashboard endpoint)
- **Verify:**
  - `GET /me/dashboard` — returns KPIs, status breakdown, time series → 200
  - Numbers match previous output (compare before/after)

**Step 4.10: Migrate `admin.py` → analytics repo**
- [ ] Move admin analytics to `SqlAlchemyAnalyticsRepository.get_admin_platform_stats()`
- [ ] Service becomes thin wrapper
- [ ] Update `Backend/app/api/v1/admin.py`
- **Verify:**
  - `GET /admin/stats` — platform stats → 200
  - `GET /admin/users` — paginated user list → 200
  - `GET /admin/events` — paginated event list → 200
  - Admin approve/reject event → 200

**Step 4.11: Migrate remaining services**
- [ ] `auth.py` — user upsert from Firebase token
- [ ] `kyc_verification.py` — KYC document CRUD
- [ ] `rating.py` — rating CRUD
- [ ] `bookmark.py` — bookmark CRUD
- [ ] `email_service.py`, `email_templates.py`, `email_notifications.py`
- [ ] `push_notification.py`
- [ ] `audit.py`
- [ ] `reconciliation.py`
- [ ] `payment_gateway.py`
- [ ] `ticket_crypto.py`, `upload_validation.py`, `age_verification.py`
- [ ] Any remaining services
- **Verify:**
  - `POST /auth/verify` — Firebase auth still works → 200
  - `POST /kyc/documents` — upload works → 201
  - `POST /events/{id}/ratings` — create rating → 201
  - Bookmarks, emails, push notifications all functional

---

### Phase 5: Worker migration + cleanup

**Step 5.1: Migrate `worker/tasks.py`**
- [ ] Replace `async with async_session_maker() as db:` → `async with SqlAlchemyUnitOfWork(async_session_maker) as uow:`
- [ ] All task functions use repo methods
- **Verify:**
  - Trigger pledge refund → background task processes correctly
  - Trigger ticket refund → background task processes correctly
  - Auto-transition cron job → events transition correctly
  - Escrow auto-release cron → releases at correct thresholds

**Step 5.2: Remove legacy bridge**
- [ ] Remove `.session` property from `SqlAlchemyUnitOfWork`
- [ ] Remove `DbSession` / `ReadDbSession` from `dependencies.py`
- [ ] Remove `get_db_session()` / `get_read_db_session()` from `db/base.py`
- **Verify:** `grep -r "from sqlalchemy" Backend/app/services/` → zero matches
- **Verify:** `grep -r "DbSession\|ReadDbSession" Backend/app/api/` → zero matches
- **Verify:** Start server, hit every major endpoint category — all working

**Step 5.3: Final verification**
- [ ] Start server: `cd Backend && uvicorn app.main:app --reload`
- [ ] Run full API flow:
  1. Auth: `POST /auth/verify` → get token
  2. Create venue: `POST /venues`
  3. Create event: `POST /events`
  4. Register: `POST /events/{id}/register`
  5. Pledge: `POST /events/{id}/pledge`
  6. Purchase ticket: `POST /events/{id}/tickets/purchase`
  7. Check dashboard: `GET /me/dashboard`
  8. Admin approve: `POST /admin/events/{id}/approve`
  9. Check ledger balance: `GET /banking/ledger/balance` → balanced
- [ ] `grep -r "from sqlalchemy" Backend/app/services/` → zero matches
- [ ] `grep -r "AsyncSession" Backend/app/services/` → zero matches
- [ ] Frontend: `dart analyze FrontEnd/lib/` → no issues (API contracts unchanged)

---

## Critical Files

| File | Role |
|------|------|
| `Backend/app/dependencies.py` | Add `UoW`/`ReadUoW` dependency aliases |
| `Backend/app/db/base.py` | `async_session_maker` consumed by `SqlAlchemyUnitOfWork` |
| `Backend/app/services/registration.py` | Best test case — uses advisory lock + FOR UPDATE |
| `Backend/app/services/ticket/sales.py` | Most complex transaction flow |
| `Backend/app/services/dashboard.py` | Proves analytics repo handles non-CRUD queries |
| `Backend/app/services/escrow.py` | Proves upsert abstraction |
| All 16 files in `models/` | Enum re-exports (minor edit) |
