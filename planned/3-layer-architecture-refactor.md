# 3-Layer Architecture Refactor — Full Blueprint

## Context

The codebase has grown organically into a ~2-layer system on both sides. Backend API routes contain business logic and direct DB queries; services mix business rules with 15-37 `db.execute()` calls each. Frontend has a 1737-line, 213-method `ApiService` god class; 73 screens bypass the 6 providers and call API directly, managing their own loading/error/pagination state. This makes the code hard to test, hard to swap layers, and blocks any future move to microservices.

**Goal:** Separate into clean Data → Service → API layers on both backend and frontend, starting with Funding/Pledges as the template domain, then applying the pattern to all others.

**Strategy:** Write comprehensive tests FIRST (before any refactoring), then refactor with confidence — run tests after each step to catch regressions.

---

## Existing Test Infrastructure

| Component | Backend | Frontend |
|-----------|---------|----------|
| **Test dir** | `Backend/tests/` — 10 test files | `FrontEnd/test/` — 1 placeholder |
| **Config** | `pytest.ini` + `conftest.py` (265 lines) | None |
| **Mock auth** | Bearer token mock, Firebase override | None |
| **Test DB** | `TEST_DATABASE_URL` + TRUNCATE isolation | N/A |
| **Dependencies** | pytest, pytest-asyncio, httpx | flutter_test only (no mockito) |
| **Fixtures** | client, db_session, test_users, test_venue, test_event, test_event_approved, test_ticket_tier | None |

---

## Phase 0: Test Coverage (BEFORE any refactoring)

### 0A. Backend — Expand endpoint tests per domain

Existing `conftest.py` already provides: async client, test DB, mock auth fixtures, test entities.
Add/expand test files to cover every endpoint that will be touched during refactoring.

| Test File | Covers | Key Scenarios |
|-----------|--------|---------------|
| `tests/test_funding.py` (NEW) | `GET /me/pledges`, `POST /events/{id}/pledge`, `DELETE /events/{id}/pledge`, `GET /events/{id}/funding-summary`, `GET /events/{id}/pledge-preview`, `GET /me/pledges/{id}/receipt` | Pledge lifecycle: create, list (sorted), receipt, unpledge, refund status. Edge cases: insufficient funds, duplicate pledge, guest pledge, tier reservations |
| `tests/test_tickets.py` (EXPAND) | Existing file — add: purchase with reserved spots, refund flow, waitlist approve/reject, scan, receipt, sort/pagination | Multi-tier purchase, discount application, capacity limits, scan validation |
| `tests/test_events.py` (EXPAND) | Existing file — add: auto_transition_status, featured/trending/coming-soon queries, event clone, co-organizer, status filters, pagination | Status state machine transitions, keyset pagination, substantive change detection |
| `tests/test_registration.py` (NEW) | `POST /events/{id}/register`, `DELETE /events/{id}/register`, waitlist, capacity enforcement | Open vs closed registration, age restriction, waitlist approval |
| `tests/test_notifications.py` (NEW) | `GET /me/notifications`, `PATCH /me/notifications/{id}/read`, `PATCH /me/notifications/read-all`, device tokens | List, mark read, mark all read, register/unregister device token |
| `tests/test_sponsors.py` (NEW) | Bids, categories, templates, prerequisites | Place bid, accept, reject, withdraw, pay, refund, category CRUD |
| `tests/test_banking.py` (NEW) | Payment info, bank accounts, escrow endpoints | Encrypted storage, escrow stage release |

**Test pattern** (follows existing conftest.py conventions):
```python
# tests/test_funding.py
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_create_pledge(client: AsyncClient, test_event_approved, auth_headers_customer):
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/pledge",
        json={"amount_cents": 5000, "reserved_spots": 1},
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["amount_cents"] == 5000
    assert data["status"] == "pledged"

@pytest.mark.asyncio
async def test_list_pledges_sorted(client: AsyncClient, auth_headers_customer):
    resp = await client.get(
        "/api/v1/me/pledges?sort_by=newest&limit=10",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
```

**Fixtures to add** in `conftest.py`:
- `test_pledge` — pledge on approved event by customer
- `test_ticket_sale` — purchased ticket
- `test_registration` — registration on approved event
- `test_sponsor_profile` — sponsor user profile
- `test_sponsorship_category` — category on event
- `test_sponsor_bid` — bid on category

### 0B. Frontend — Set up test infrastructure from scratch

**Step 1: Add test dependencies** to `FrontEnd/pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4        # Mock generation (simpler than mockito, no codegen)
  network_image_mock: ^2.1.1  # Mock network images in widget tests
```

**Step 2: Create test helpers** `FrontEnd/test/helpers/`:
```
test/
├── helpers/
│   ├── test_helpers.dart      # pumpApp wrapper with providers, mock navigation
│   ├── mock_repositories.dart # Mock implementations of all repositories
│   └── fixtures.dart          # Test data factories (Event, Pledge, Ticket, User)
├── repositories/              # Unit tests for repositories
│   ├── funding_repository_test.dart
│   ├── ticket_repository_test.dart
│   └── event_repository_test.dart
├── providers/                 # Unit tests for providers
│   ├── pledge_provider_test.dart
│   ├── ticket_provider_test.dart
│   └── event_provider_test.dart
└── screens/                   # Widget tests for screens
    ├── my_pledges_screen_test.dart
    ├── my_tickets_screen_test.dart
    └── home_screen_test.dart
```

**Step 3: Write tests AFTER repositories/providers exist** (Phase 2+):
- Frontend tests are written alongside each new repository/provider
- Each domain phase: create repo → write repo test → create provider → write provider test → migrate screen → write widget test
- Tests validate the new layer works before migrating screens to use it

### 0C. Run baseline

```bash
# Backend — run all existing tests, record pass count
cd Backend && pytest -v --tb=short 2>&1 | tee test_baseline.txt

# Frontend — just verify it compiles
cd FrontEnd && flutter test
```

Save the baseline pass count. After every refactoring phase, run tests and confirm the count only goes up, never down.

---

## Target Folder Structure

### Backend

```
Backend/app/
├── api/v1/                    # API Layer — thin: auth, validation, response shaping
│   ├── events/
│   ├── users.py
│   ├── banking.py
│   ├── notifications.py
│   └── ...
├── services/                  # Service Layer — business logic only, NO db.execute()
│   ├── event/
│   ├── funding/
│   ├── ticket/
│   ├── sponsor/
│   ├── notification.py
│   ├── registration.py
│   └── ...
├── repositories/              # NEW — Data Layer: all SQLAlchemy queries
│   ├── base.py               # BaseRepository with common CRUD
│   ├── event_repo.py
│   ├── funding_repo.py
│   ├── ticket_repo.py
│   ├── registration_repo.py
│   ├── notification_repo.py
│   ├── user_repo.py
│   ├── sponsor_repo.py
│   ├── venue_repo.py
│   └── banking_repo.py
├── models/                    # Unchanged — pure ORM classes
├── schemas/                   # Unchanged — Pydantic response/request models
└── db/                        # Unchanged — engine, session setup
```

### Frontend

```
FrontEnd/lib/
├── screens/                   # Screen Layer — UI only, reads from providers
│   └── (unchanged structure)
├── providers/                 # Provider Layer — state + business logic
│   ├── auth_provider.dart     # existing
│   ├── event_provider.dart    # existing (expand)
│   ├── notification_provider.dart  # existing (refactor)
│   ├── chat_provider.dart     # existing
│   ├── config_provider.dart   # existing
│   ├── theme_provider.dart    # existing
│   ├── pledge_provider.dart   # NEW
│   ├── ticket_provider.dart   # NEW
│   ├── bookmark_provider.dart # NEW
│   └── sponsor_provider.dart  # NEW
├── repositories/              # NEW — Data Layer: HTTP + typed models + caching
│   ├── base_repository.dart   # Shared Dio instance, error handling, PaginatedResult
│   ├── event_repository.dart
│   ├── funding_repository.dart
│   ├── ticket_repository.dart
│   ├── registration_repository.dart
│   ├── notification_repository.dart
│   ├── user_repository.dart
│   ├── sponsor_repository.dart
│   ├── admin_repository.dart
│   ├── bookmark_repository.dart
│   └── venue_repository.dart
├── models/                    # Unchanged — typed classes with fromJson
└── services/                  # Refactored
    ├── chat_socket_service.dart   # unchanged
    ├── sync_service.dart          # unchanged
    └── (api_service.dart DELETED after full migration)
```

---

## Shared Abstractions (build first)

### Backend: `repositories/base.py`

```python
from typing import TypeVar, Generic, Sequence
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

T = TypeVar("T")

class BaseRepository(Generic[T]):
    """Base with common CRUD — subclasses set model_class."""
    model_class: type[T]

    async def get_by_id(self, db: AsyncSession, id: int) -> T | None:
        return (await db.execute(select(self.model_class).where(self.model_class.id == id))).scalar_one_or_none()

    async def get_or_404(self, db: AsyncSession, id: int, label: str = "") -> T:
        obj = await self.get_by_id(db, id)
        if not obj:
            from app.core.exceptions import NotFoundError
            raise NotFoundError(label or self.model_class.__tablename__, id)
        return obj

    async def create(self, db: AsyncSession, obj: T) -> T:
        db.add(obj)
        await db.flush()
        await db.refresh(obj)
        return obj

    async def count(self, db: AsyncSession, *where) -> int:
        q = select(func.count()).select_from(self.model_class).where(*where)
        return int((await db.execute(q)).scalar_one())
```

### Frontend: `repositories/base_repository.dart`

```dart
import 'package:dio/dio.dart';
import '../services/api_service.dart';  // temporary, until ApiService is deleted

class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final int? total;

  PaginatedResult({required this.items, required this.hasMore, this.total});
}

class ApiError {
  final int statusCode;
  final String message;

  ApiError(this.statusCode, this.message);

  factory ApiError.fromDioException(DioException e) {
    final data = e.response?.data;
    String msg = 'Something went wrong';
    if (data is Map && data.containsKey('detail')) {
      final detail = data['detail'];
      if (detail is String) msg = detail;
      if (detail is List) msg = detail.map((d) => d['msg'] ?? d.toString()).join('; ');
    }
    return ApiError(e.response?.statusCode ?? 0, msg);
  }
}

abstract class BaseRepository {
  final Dio dio;
  BaseRepository(this.dio);
}
```

---

## Domain Implementation Order

Each domain follows the same 4-step pattern:
1. Create backend repository (extract queries from service)
2. Refactor backend service (replace db.execute with repo calls)
3. Create frontend repository (extract methods from ApiService, return typed models)
4. Create/expand frontend provider + migrate screens

### Phase 1: Foundation (shared abstractions)

| Step | File | What |
|------|------|------|
| 1.1 | `Backend/app/repositories/__init__.py` | Create package |
| 1.2 | `Backend/app/repositories/base.py` | BaseRepository with get_by_id, get_or_404, create, count |
| 1.3 | `FrontEnd/lib/repositories/base_repository.dart` | BaseRepository, PaginatedResult, ApiError |
| 1.4 | Register Dio in MultiProvider (main.dart) | So repositories can receive Dio directly |

### Phase 2: Funding/Pledges (template domain)

**Backend:**

| Step | File | What |
|------|------|------|
| 2.1 | `Backend/app/repositories/funding_repo.py` | Extract from `services/funding/pledges.py`: get_pledge, list_by_user, list_by_event, count_by_event, get_pledged_total, create_pledge, update_status, get_user_reserved_spots, advisory_lock |
| 2.2 | `Backend/app/services/funding/pledges.py` | Replace all db.execute calls with funding_repo.xxx calls. Service keeps: validation, commission calc, payment orchestration, notification dispatch |

**Frontend:**

| Step | File | What |
|------|------|------|
| 2.3 | `FrontEnd/lib/repositories/funding_repository.dart` | Own Dio instance. Methods: getMyPledges, getPledgeReceipt, getFundingSummary, getPledgePreview, pledge, unpledge, getRefundStatus, getOrganizerPledges. All return typed models (Pledge, FundingSummary, PaginatedResult<Pledge>) |
| 2.4 | `FrontEnd/lib/providers/pledge_provider.dart` | State: pledges, loading, loadingMore, hasMore, error, sortBy, filterStatus. Methods: load, loadMore, setSortBy, setFilter. Calls FundingRepository |
| 2.5 | `FrontEnd/lib/screens/profile/my_pledges_screen.dart` | Remove all ApiService calls, loading/pagination state. Use `context.watch<PledgeProvider>()`. Screen becomes ~50% smaller |
| 2.6 | Delete methods from ApiService | Remove: getMyPledges, getOrganizerPledges, pledge, unpledge, getPledgePreview, getPledgeReceipt, getMyPledgeReceipt, getFundingSummary, getRefundStatus |

### Phase 3: Tickets

**Backend:**

| Step | File | What |
|------|------|------|
| 3.1 | `Backend/app/repositories/ticket_repo.py` | Extract from `services/ticket/sales.py`: count_purchased, get_tier, list_tiers, create_sale, get_by_user, get_sales_for_event, get_waitlisted, update_status, count_by_tier |
| 3.2 | `Backend/app/services/ticket/sales.py` | Replace db.execute with repo calls. Service keeps: pricing logic, spot consumption, payment, advisory locks, receipt generation |

**Frontend:**

| Step | File | What |
|------|------|------|
| 3.3 | `FrontEnd/lib/repositories/ticket_repository.dart` | Methods: getMyTickets, getTicketTiers, purchaseTickets, getTicketReceipt, requestRefund, getRefundRequests, approveRefund, rejectRefund, scanTicket, getWaitlisted, approveWaitlisted, rejectWaitlisted, getTicketPrice, startSellingTickets, getTicketSalesStats |
| 3.4 | `FrontEnd/lib/providers/ticket_provider.dart` | State: myTickets, loading, hasMore, sortBy. Methods: load, loadMore |
| 3.5 | Migrate screens | my_tickets_screen.dart, ticket_tiers_section.dart, ticket_receipt_screen.dart, refund_requests_screen.dart, ticket_scanner_screen.dart, ticket_waitlist_screen.dart, ticket_sales_screen.dart |
| 3.6 | Delete methods from ApiService | ~35 ticket methods |

### Phase 4: Events

**Backend:**

| Step | File | What |
|------|------|------|
| 4.1 | `Backend/app/repositories/event_repo.py` | Extract from `services/event/crud.py` + `queries.py`: get_event, list_events, list_featured, list_trending, list_coming_soon, create_event, update_event, update_status, get_by_organizer, count_by_organizer, get_with_relations |
| 4.2 | `Backend/app/services/event/crud.py` | Replace db.execute with repo. Service keeps: auto_transition_status state machine, substantive_change detection, approval logic |

**Frontend:**

| Step | File | What |
|------|------|------|
| 4.3 | `FrontEnd/lib/repositories/event_repository.dart` | Methods: getEvents, getEvent, getFeaturedEvents, getMapEvents, createEvent, updateEvent, deleteEvent, publishEvent, cancelEvent, reactivateEvent, cloneEvent, setEventDate, getEventCities, getGenres, getEventImages, addEventImage, uploadEventImage, deleteEventImage, getEventPosts, createEventPost, deleteEventPost, getEventRatings, getRatingsSummary, createRating, getMyReaction, reactToEvent |
| 4.4 | Expand `EventProvider` | Add image, post, rating methods. Move loading logic from screens |
| 4.5 | Migrate screens | home_tab.dart, explore_tab.dart, event_detail_screen.dart, create_event_screen.dart, edit_event_screen.dart, my_events_tab.dart, organizer_dashboard_tab.dart + all event_detail/ sub-screens |
| 4.6 | Delete methods from ApiService | ~60 event methods |

### Phase 5: Users & Auth

**Backend:**

| Step | File | What |
|------|------|------|
| 5.1 | `Backend/app/repositories/user_repo.py` | Extract from `api/v1/users.py` direct queries: get_by_firebase_uid, get_by_id, update_user, get_payment_info, update_payment_info |
| 5.2 | Clean up `api/v1/users.py` | Move receipt building, venue lookup into service |

**Frontend:**

| Step | File | What |
|------|------|------|
| 5.3 | `FrontEnd/lib/repositories/user_repository.dart` | Methods: getMe, updateMe, verifyToken, getPaymentInfo, updatePaymentInfo, getBankAccount, updateBankAccount, getPublicProfile, getUserRatingsSummary, getKycStatus, uploadKycDocument, submitKyc |
| 5.4 | Refactor `AuthProvider` | Use UserRepository instead of ApiService |
| 5.5 | Migrate screens | profile_screen.dart, profile_payment_section.dart, profile_bank_section.dart |
| 5.6 | Delete methods from ApiService | ~15 user methods |

### Phase 6: Registration

**Backend:**

| Step | File | What |
|------|------|------|
| 6.1 | `Backend/app/repositories/registration_repo.py` | Extract from registration.py: get_registration, count_registered, create, update_status, list_by_event |
| 6.2 | `Backend/app/services/registration.py` | Replace db.execute with repo calls |

**Frontend:**

| Step | File | What |
|------|------|------|
| 6.3 | `FrontEnd/lib/repositories/registration_repository.dart` | Methods: register, unregister, getMyRegistration, getRegistrations, decideRegistration |
| 6.4 | Integrate into EventProvider | Registration is part of event detail flow |
| 6.5 | Delete methods from ApiService | ~4 registration methods |

### Phase 7: Notifications

**Backend:**

| Step | File | What |
|------|------|------|
| 7.1 | `Backend/app/repositories/notification_repo.py` | Extract: list_for_user, unread_count, mark_read, mark_all_read, create, bulk_create, delete, create_device_token, delete_device_token |
| 7.2 | `Backend/app/services/notification.py` | Replace db.execute with repo calls |

**Frontend:**

| Step | File | What |
|------|------|------|
| 7.3 | `FrontEnd/lib/repositories/notification_repository.dart` | Methods: getNotifications, getUnreadCount, markRead, markAllRead, deleteNotification, registerDevice, unregisterDevice |
| 7.4 | Refactor `NotificationProvider` | Replace direct Dio calls with repository |
| 7.5 | Delete methods from ApiService | ~6 notification methods |

### Phase 8: Sponsors

**Backend:**

| Step | File | What |
|------|------|------|
| 8.1 | `Backend/app/repositories/sponsor_repo.py` | Extract from sponsor/bids.py, categories.py: get_bid, list_bids, create_bid, update_bid, get_category, list_categories, create_category |
| 8.2 | `Backend/app/services/sponsor/bids.py` | Replace db.execute with repo calls |

**Frontend:**

| Step | File | What |
|------|------|------|
| 8.3 | `FrontEnd/lib/repositories/sponsor_repository.dart` | Methods: all 30+ sponsor/bid/category/template/ticket/delegate methods |
| 8.4 | `FrontEnd/lib/providers/sponsor_provider.dart` | State for sponsor dashboard, bids, tickets |
| 8.5 | Migrate screens | All 15 sponsor screens |
| 8.6 | Delete methods from ApiService | ~30 sponsor methods |

### Phase 9: Remaining Domains

| Domain | Backend Repo | Frontend Repo | Screens |
|--------|-------------|---------------|---------|
| Venues | venue_repo.py | venue_repository.dart | venue_list_screen, create_venue_screen, venue_picker_screen |
| Bookmarks | (part of event_repo) | bookmark_repository.dart + BookmarkProvider | bookmarked_events_screen, home_screen |
| Banking | banking_repo.py | (part of admin_repository.dart) | admin banking tabs |
| Admin | (uses existing repos) | admin_repository.dart | All 13 admin screens |
| Milestones | (part of event_repo) | (part of event_repository.dart) | milestone_timeline, schedule_milestone_dialogs |
| Schedule | (part of event_repo) | (part of event_repository.dart) | event_schedule_section, edit_schedule_section |
| Discounts | (part of ticket_repo) | (part of ticket_repository.dart) | global_discounts_screen |
| Config | (none needed) | (part of base or config_provider) | — |
| Chat | (none needed — Redis) | (keep ChatSocketService) | bid_chat_screen |

### Phase 10: Cleanup

| Step | What |
|------|------|
| 10.1 | Delete `FrontEnd/lib/services/api_service.dart` |
| 10.2 | Remove ApiService from MultiProvider in main.dart |
| 10.3 | Update SyncService to use EventRepository |
| 10.4 | Grep for any remaining `context.read<ApiService>()` — should be zero |
| 10.5 | Run `dart analyze` on entire project |

---

## Migration Strategy (per domain)

Each domain follows this safe incremental pattern:

```
Step A: Write/expand backend tests for this domain's endpoints
         ↓  run pytest → all pass
Step B: Create backend repository (new file, nothing breaks)
         ↓  run pytest → all pass
Step C: Refactor backend service to use repo (internal change, API unchanged)
         ↓  run pytest → all pass (this is the critical check)
Step D: Create frontend repository (new file, nothing breaks)
         ↓
Step E: Write frontend repo + provider tests
         ↓  run flutter test → all pass
Step F: Create/expand frontend provider
         ↓  run flutter test → all pass
Step G: Migrate screens one-by-one to use provider
         ↓  run flutter test + dart analyze → all pass
Step H: Delete migrated methods from ApiService (only after all callers removed)
         ↓  run flutter test + grep for deleted methods → zero hits
```

At every step the app compiles, runs, and tests pass. No big-bang switchover.

---

## Key Rules During Migration

1. **Backend repos** own ALL SQLAlchemy: `select`, `db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete`
2. **Backend services** must NOT import `select`, `func`, or call `db.execute` — only call repo methods
3. **Frontend repos** own ALL Dio HTTP calls and return typed models (never raw Maps)
4. **Frontend providers** own ALL state (loading, error, pagination, cache) — screens never manage these
5. **Frontend screens** only call `context.watch<Provider>()` to read and `context.read<Provider>().method()` to dispatch
6. **ApiService methods** are deleted only after ALL callers are migrated — grep to verify

---

## Verification

After each phase:
```bash
# Backend — must never decrease from baseline
cd Backend && pytest -v --tb=short

# Frontend — must pass all tests + static analysis
cd FrontEnd && flutter test && dart analyze lib/

# Migration completeness — grep for old patterns
grep -r "context.read<ApiService>()" FrontEnd/lib/   # decreases each phase
grep -r "db\.execute" Backend/app/services/           # decreases each phase
```

**Final (Phase 10):**
- `grep -r "context.read<ApiService>()" FrontEnd/lib/` → zero matches
- `grep -r "db\.execute" Backend/app/services/` → zero matches (all moved to repos)
- `pytest` → all backend tests pass
- `flutter test` → all frontend tests pass
- Manual smoke test: login → browse events → pledge → buy ticket → check profile lists
