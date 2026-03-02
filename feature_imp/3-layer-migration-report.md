# 3-Layer Architecture Migration — Comprehensive Report

## 1. Current Architecture

```
┌──────────────────────────────────────────────┐
│  API Layer         41 files │  9,703 LOC     │
│  (FastAPI routers, schemas, auth deps)       │
└────────────────────┬─────────────────────────┘
                     │ direct calls
┌────────────────────▼─────────────────────────┐
│  Service Layer     56 files │ 13,626 LOC     │
│  (business logic + SQL queries + externals)  │
└────────────────────┬─────────────────────────┘
                     │ SQLAlchemy ORM
┌────────────────────▼─────────────────────────┐
│  PostgreSQL + Redis/ARQ + Firebase + Stripe  │
└──────────────────────────────────────────────┘
```

**Problem:** Services own business logic, data access, AND external integrations — making them hard to test, hard to refactor, and tightly coupled to the ORM.

## 2. Target Architecture

```
┌──────────────────────────────────────────────┐
│  API Layer         (thin — validation, auth) │
└────────────────────┬─────────────────────────┘
                     │
┌────────────────────▼─────────────────────────┐
│  Service Layer     (pure business logic)     │
│  - No direct select()/insert()/update()      │
│  - Calls repositories for data access        │
│  - Calls abstractions for externals          │
└────────┬──────────────────────┬──────────────┘
         │                      │
┌────────▼──────────┐  ┌───────▼──────────────┐
│  Repository Layer │  │  External Adapters   │
│  (SQLAlchemy ORM) │  │  (Stripe, Redis,     │
│                   │  │   Firebase, Email)    │
└────────┬──────────┘  └───────┬──────────────┘
         │                      │
┌────────▼──────────────────────▼──────────────┐
│  PostgreSQL + Redis + Firebase + Stripe       │
└──────────────────────────────────────────────┘
```

---

## 3. Test Coverage Status — All Phases

### Phase 1 + 2 (COMPLETED) — 1,100 tests passing

| Service | Before | After | Status |
|---------|--------|-------|--------|
| `payment_gateway.py` | 36% | **97%** | READY |
| `sponsor/payments.py` | 14% | **92%** | READY |
| `escrow.py` | 50% | **91%** | READY |
| `event/lifecycle.py` | 42% | **91%** | READY |
| `ticket/tiers.py` | 27% | **88%** | READY |
| `dashboard.py` | 27% | **88%** | READY |
| `registration.py` | 23% | **85%** | READY |
| `event/organizers.py` | 25% | **85%** | READY |
| `event/discounts.py` | 29% | **85%** | READY |
| `escrow_base.py` | 36% | **82%** | READY |
| `ticket/pricing.py` | 10% | **81%** | READY |
| `event/attendance.py` | — | **79%** | READY |
| `event/crud.py` | 49% | **70%** | READY |

**12 services migration-ready at 70%+**

### Phase 3 (PENDING) — ~87 new tests

| Service | Current | Target | Est. Tests | Priority |
|---------|---------|--------|------------|----------|
| `ticket_escrow.py` | 63% | 70%+ | ~10 | Financial |
| `funding/pledges.py` | 61% | 70%+ | ~12 | Financial |
| `milestone.py` | 62% | 70%+ | ~10 | Feature |
| `ticket/sales.py` | 60% | 70%+ | ~15 | Financial |
| `sponsor_escrow.py` | 58% | 70%+ | ~10 | Financial |
| `chat_service.py` | 28% | 70%+ | ~20 | Feature |
| `sponsor/bids.py` | 25% | 70%+ | ~20 | Financial |

**After Phase 3: 19 services at 70%+, overall ~70%**

### Phase 4A (PENDING) — Financial & Sponsor Core (~73 tests)

| Service | Current | Target | Est. Tests |
|---------|---------|--------|------------|
| `refund_retry.py` | 30% | 70%+ | ~10 |
| `reconciliation.py` | 39% | 70%+ | ~8 |
| `notification_service.py` | 60% | 70%+ | ~8 |
| `platform_settings.py` | 67% | 70%+ | ~5 |
| `sponsor/tickets.py` | 21% | 70%+ | ~12 |
| `sponsor/delegates.py` | 31% | 70%+ | ~10 |
| `sponsor/organizer_queries.py` | 34% | 70%+ | ~12 |
| `sponsor/profile.py` | 45% | 70%+ | ~8 |
| `sponsor/categories.py` | 46% | 70%+ | ~10 |

**After Phase 4A: 28 services at 70%+, overall ~75%**

### Phase 4B (PENDING) — Event Support & Infrastructure (~128 tests)

| Service | Current | Target | Est. Tests |
|---------|---------|--------|------------|
| `discount_strategy.py` | 35% | 70%+ | ~12 |
| `schedule.py` | 41% | 70%+ | ~10 |
| `ticket_crypto.py` | 43% | 70%+ | ~8 |
| `ticket_strategy.py` | 45% | 70%+ | ~8 |
| `venue.py` | 67% | 70%+ | ~4 |
| `post.py` | 36% | 70%+ | ~8 |
| `push_notification.py` | 19% | 70%+ | ~10 |
| `email_notifications.py` | 23% | 70%+ | ~12 |
| `email_templates.py` | 23% | 70%+ | ~10 |
| `email_service.py` | 54% | 70%+ | ~8 |
| `admin.py` | 39% | 70%+ | ~15 |
| `kyc_verification.py` | 35% | 70%+ | ~10 |
| `funding/reservations.py` | 39% | 70%+ | ~8 |
| `upload_validation.py` | 39% | 70%+ | ~5 |

**After Phase 4B: 42 services at 70%+, overall ~82%**

---

## 4. Service Dependency Complexity

### Dependency Tiers

```
Tier 0 — Infrastructure (no service deps, migrate first)
├── platform_settings.py    ← imported by 25+ services
├── ledger.py               ← imported by payment_gateway
├── encryption.py           ← utility
├── ticket_crypto.py        ← utility
├── audit.py                ← logging
├── auth.py                 ← Firebase wrapper
├── email_service.py        ← SMTP abstraction
├── email_templates.py      ← templates only
├── push_notification.py    ← Firebase FCM
├── age_verification.py     ← pure validation
└── upload_validation.py    ← pure validation

Tier 1 — Core Domain (1-2 deps, migrate after Tier 0)
├── event/permissions.py    → (nothing)
├── event/queries.py        → event.permissions
├── event/attendance.py     → (nothing)
├── funding/reservations.py → (nothing)
├── funding/summary.py      → funding.reservations
├── ticket/tiers.py         → event
├── sponsor/categories.py   → (nothing)
├── sponsor/profile.py      → (nothing)
├── notification_service.py → (nothing, uses Redis)
├── chat_service.py         → (nothing)
├── venue.py                → (nothing)
├── ticket_strategy.py      → (nothing)
└── discount_strategy.py    → (nothing)

Tier 2 — Complex Multi-Dependency (migrate after Tier 1)
├── escrow_base.py          → (generic helper)
├── event/crud.py           → permissions, settings, funding, email
├── event/lifecycle.py      → permissions, settings, funding, email
├── event/organizers.py     → event.crud, event.permissions
├── event/discounts.py      → event.crud, event.permissions
├── ticket/pricing.py       → event, ticket.tiers
├── ticket_escrow.py        → escrow_base, settings
├── sponsor_escrow.py       → escrow_base, settings
├── escrow.py               → escrow_base, settings, event, funding, notif
├── funding/pledges.py      → reservations, event, settings
├── sponsor/bids.py         → categories, payments
├── sponsor/payments.py     → categories, settings
├── sponsor/delegates.py    → settings
├── registration.py         → funding
├── milestone.py            → event, funding
├── refund_retry.py         → (payment retry)
└── reconciliation.py       → ledger, settings

Tier 3 — Highest Complexity (migrate last)
├── ticket/sales.py         → event, pricing, tiers, funding, gateway,
│                              ticket_escrow, escrow (8 deps)
├── payment_gateway.py      → settings, ledger (+ Stripe external)
├── email_notifications.py  → email_service, email_templates
├── dashboard.py            → (read-heavy, many model joins)
└── admin.py                → event, escrow, funding, sponsor, etc.
```

### Cross-Service Dependency Count

| Service | Inbound Deps | Outbound Deps | Risk |
|---------|-------------|---------------|------|
| `platform_settings.py` | 25+ | 0 | LOW (migrate first) |
| `event/*` (package) | 15+ | 3 | MEDIUM |
| `ticket/sales.py` | 3 | 8 | HIGH (most complex) |
| `escrow.py` | 5 | 5 | HIGH (financial) |
| `payment_gateway.py` | 8 | 2 | HIGH (financial) |
| `funding/pledges.py` | 4 | 3 | MEDIUM |
| `notification_service.py` | 10+ | 0 | LOW |

---

## 5. SQLAlchemy Query Extraction Scope

Every service uses direct SQLAlchemy queries. Repository extraction required for all 46 query-using services.

### Query Complexity by Service

| Service | Lines | Queries | Patterns Used |
|---------|-------|---------|---------------|
| `ticket/sales.py` | 776 | 50+ | select, insert, update, advisory_lock, func, selectinload |
| `event/crud.py` | 897 | 40+ | select, exists, func, selectinload, joinedload, complex joins |
| `escrow.py` | 465 | 30+ | select, func, pg_insert, on_conflict_do_nothing |
| `funding/pledges.py` | 638 | 25+ | select, insert, update, func |
| `payment_gateway.py` | 445 | 20+ | select, insert (ledger entries) |
| `sponsor/payments.py` | 289 | 20+ | select, insert, update |
| `ticket_escrow.py` | 273 | 20+ | select, func, pg_insert |
| `sponsor_escrow.py` | 290 | 20+ | select, func, pg_insert |
| `admin.py` | 625 | 20+ | complex aggregation queries |
| `email_notifications.py` | 368 | 15+ | select with selectinload (read-only) |

### Repositories to Create

```
Backend/app/repositories/
├── __init__.py
├── base.py                    # Generic CRUD (get, list, create, update, delete)
├── event_repo.py              # Event, EventStatus transitions
├── ticket_sale_repo.py        # TicketSale + advisory lock
├── ticket_tier_repo.py        # TicketTier CRUD
├── funding_repo.py            # Funding + Reservation
├── escrow_repo.py             # FundEscrow + EscrowRelease
├── ticket_escrow_repo.py      # TicketEscrow
├── sponsor_escrow_repo.py     # SponsorEscrow
├── sponsor_repo.py            # Bids, Payments, Categories, Tickets
├── payment_repo.py            # Gateway transaction log
├── ledger_repo.py             # Ledger entries
├── user_repo.py               # User queries
├── notification_repo.py       # Notification CRUD
├── chat_repo.py               # Conversation + Message
├── registration_repo.py       # Registration
├── milestone_repo.py          # Milestone
└── settings_repo.py           # PlatformSettings
```

**Estimated new code: ~2,500-3,500 LOC for repository layer**

---

## 6. External Integration Abstractions

| Integration | Current Pattern | Services Using | Abstraction Needed |
|-------------|----------------|---------------|--------------------|
| **Redis/ARQ** | `from app.worker.redis_pool import enqueue` | 6 services | `QueueService` interface |
| **Email** | `email_service.send_email()` | 3 services | Already semi-abstracted |
| **Firebase Auth** | Direct `firebase_admin` | `auth.py` | `AuthProvider` interface |
| **Firebase FCM** | Direct FCM calls | `push_notification.py` | `PushProvider` interface |
| **Stripe** | `PaymentGateway` ABC | `payment_gateway.py` | Already abstracted |
| **Settings** | `platform_settings.*` | 25+ services | Already abstracted |

---

## 7. Migration Execution Order

### Wave 1 — Foundation (Tier 0 + Repositories Base)
**Goal:** Create repository layer foundation, migrate zero-dependency services

1. Create `repositories/base.py` with generic CRUD
2. Create `repositories/settings_repo.py` → migrate `platform_settings.py`
3. Create `repositories/ledger_repo.py` → migrate `ledger.py`
4. Migrate utility services: `encryption`, `audit`, `auth`, `ticket_crypto`
5. Create `QueueService` abstraction for Redis/ARQ

**Risk:** LOW — these services have no inbound dependencies from other services
**Test impact:** Minimal — utility services already well-tested

### Wave 2 — Core Domain (Tier 1)
**Goal:** Migrate single-dependency domain services

1. `repositories/event_repo.py` → migrate `event/permissions`, `event/queries`, `event/attendance`
2. `repositories/ticket_tier_repo.py` → migrate `ticket/tiers`
3. `repositories/funding_repo.py` → migrate `funding/reservations`, `funding/summary`
4. `repositories/sponsor_repo.py` → migrate `sponsor/categories`, `sponsor/profile`
5. `repositories/notification_repo.py` → migrate `notification_service`
6. `repositories/chat_repo.py` → migrate `chat_service`
7. Migrate: `venue`, `ticket_strategy`, `discount_strategy`

**Risk:** LOW-MEDIUM — single dependencies, well-defined boundaries
**Test impact:** Need to update service tests to inject repository mocks

### Wave 3 — Business Logic Core (Tier 2)
**Goal:** Migrate the complex multi-dependency services (highest value)

1. `event/crud.py` + `event/lifecycle.py` + `event/organizers.py` + `event/discounts.py`
2. `escrow_base.py` + `escrow.py` + `ticket_escrow.py` + `sponsor_escrow.py`
3. `ticket/pricing.py`
4. `funding/pledges.py`
5. `sponsor/bids.py` + `sponsor/payments.py` + `sponsor/delegates.py`
6. `registration.py`, `milestone.py`
7. `refund_retry.py`, `reconciliation.py`

**Risk:** HIGH — these are the financially critical services
**Prerequisite:** Phase 3 tests must pass (70%+ coverage on all)

### Wave 4 — High Complexity (Tier 3)
**Goal:** Migrate the most interconnected services

1. `ticket/sales.py` (8 dependencies — largest refactor)
2. `payment_gateway.py` (+ Stripe implementation)
3. `email_notifications.py`
4. `dashboard.py`
5. `admin.py`

**Risk:** HIGHEST — most cross-cutting concerns
**Prerequisite:** Phase 4A+4B tests must pass

---

## 8. Risk Assessment

### What could go wrong

| Risk | Impact | Mitigation |
|------|--------|------------|
| Broken financial calculations during migration | CRITICAL | 91% escrow coverage, 92% sponsor payments coverage |
| N+1 queries introduced in repository layer | HIGH | Existing selectinload patterns documented in CLAUDE.md |
| Transaction boundary issues (service → repo) | HIGH | Keep `db: AsyncSession` passed through, don't create new sessions in repos |
| Test suite breaks during migration | MEDIUM | 1,100 tests as safety net; migrate one service at a time |
| `ticket/sales.py` migration (8 deps) | HIGH | Do this LAST; all dependencies migrated first |
| Advisory lock semantics lost | HIGH | Keep `pg_advisory_xact_lock` in repository, not service |

### Services NOT safe to migrate yet (below 60%)

| Service | Coverage | Blocks Migration? |
|---------|----------|-------------------|
| `sponsor/bids.py` | 25% | YES — sponsor flow |
| `chat_service.py` | 28% | No — isolated feature |
| `refund_retry.py` | 30% | YES — financial |
| `sponsor/delegates.py` | 31% | No — secondary |
| `sponsor/organizer_queries.py` | 34% | No — read-only |
| `discount_strategy.py` | 35% | No — secondary |
| `kyc_verification.py` | 35% | No — isolated |
| `post.py` | 36% | No — isolated |
| `admin.py` | 39% | No — migrate last |
| `reconciliation.py` | 39% | YES — financial |
| `funding/reservations.py` | 39% | YES — funding flow |
| `schedule.py` | 41% | No — secondary |
| `ticket_crypto.py` | 43% | No — utility |
| `sponsor/profile.py` | 45% | No — secondary |
| `ticket_strategy.py` | 45% | No — secondary |
| `sponsor/categories.py` | 46% | Partial — sponsor flow |

---

## 9. Effort Estimates

| Phase | New Tests | New Repo Code | Services Migrated | Coverage After |
|-------|-----------|--------------|-------------------|----------------|
| Phase 1+2 (DONE) | ~420 tests | — | — | 62% |
| Phase 3 | ~87 tests | — | — | ~70% |
| Phase 4A+4B | ~201 tests | — | — | ~82% |
| Wave 1 (repos) | — | ~500 LOC | 11 services | — |
| Wave 2 (repos) | ~50 repo tests | ~800 LOC | 13 services | — |
| Wave 3 (repos) | ~80 repo tests | ~1,200 LOC | 15 services | — |
| Wave 4 (repos) | ~40 repo tests | ~600 LOC | 5 services | — |

**Total migration scope:**
- **~708 new test functions** (across all testing phases)
- **~3,100 LOC** new repository layer
- **~170 repo-level tests**
- **44 services** to migrate across 4 waves
- **Overall coverage target: 82%+** before Wave 3 begins

---

## 10. Recommended Path Forward

```
NOW          Phase 3 tests (87 tests)         → 70% coverage, 19 services ready
             ↓
NEXT         Wave 1 migration (Tier 0)        → repository foundation + utilities
             ↓
THEN         Phase 4A tests (73 tests)        → 75% coverage, 28 services ready
             ↓
             Wave 2 migration (Tier 1)        → core domain repos
             ↓
LATER        Phase 4B tests (128 tests)       → 82% coverage, 42 services ready
             ↓
             Wave 3 migration (Tier 2)        → business logic core
             ↓
FINALLY      Wave 4 migration (Tier 3)        → highest complexity
```

**Key rule:** Never migrate a service below 70% coverage. Write tests FIRST, then extract repositories.
