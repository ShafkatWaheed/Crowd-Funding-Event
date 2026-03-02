# 3-Layer Architecture Refactor — Full Blueprint

## Context

The codebase has grown organically into a ~2-layer system on both sides. Backend API routes contain business logic and direct DB queries; 46 service files mix business rules with 368 `db.execute()` calls (top offenders: admin 36, ticket/sales 28, funding/pledges 24, event/lifecycle 16). Frontend has a 1737-line, 235-method `ApiService` god class; 80 of 54 screens use `context.read<ApiService>()` directly, bypassing the 6 providers and managing their own loading/error/pagination state. This makes the code hard to test, hard to swap layers, and blocks any future move to microservices.

**Goal:** Separate into clean Data → Service → API layers on both backend and frontend, starting with Funding/Pledges as the template domain, then applying the pattern to all others.

**Strategy:** Write comprehensive tests FIRST (before any refactoring), then refactor with confidence — run tests after each step to catch regressions.

---

## Architecture Reference

### The Problem (2-layer)

```
Backend (current):
  API Route ──→ Service (business logic + db.execute mixed together)

Frontend (current):
  Screen (UI + loading/error/pagination state + ApiService.method() calls all in one place)
```

A service like `pledges.py` does both "should this user be allowed to pledge?" (business logic) AND `db.execute(select(Funding).where(...))` (data access) in the same function. On the frontend, `my_pledges_screen.dart` manages its own `_loading`, `_hasMore`, `_pledges` state AND calls `context.read<ApiService>().getMyPledges()` directly.

### The Solution (3-layer)

#### Backend

```
Layer 1: API Route     (Backend/app/api/v1/)        → thin: auth, validate input, return response
Layer 2: Service       (Backend/app/services/)       → business logic ONLY, no db.execute
Layer 3: Repository    (Backend/app/repositories/)   → ALL database queries
```

**Example — creating a pledge:**

```python
# Layer 1: API Route (thin — auth + call service)
@router.post("/events/{id}/pledge")
async def create_pledge(body: PledgeRequest, db: DbSession, user: CurrentUser):
    return await pledge_service.create_pledge(db, user.id, body)

# Layer 2: Service (business logic only — no db.execute)
async def create_pledge(db, user_id, body):
    event = await event_repo.get_by_id(db, body.event_id)             # repo call
    existing = await funding_repo.get_by_user_and_event(db, user_id, event.id)  # repo call
    if existing:
        raise ConflictError("Already pledged")
    # Commission calc, validation, payment gateway — pure business logic
    gateway = await get_gateway(db)
    result = await gateway.charge(...)
    funding = Funding(user_id=user_id, amount_cents=body.amount, ...)
    return await funding_repo.create(db, funding)                      # repo call

# Layer 3: Repository (ALL queries here)
class FundingRepository(BaseRepository):
    async def get_by_user_and_event(self, db, user_id, event_id):
        result = await db.execute(
            select(Funding).where(Funding.user_id == user_id, Funding.event_id == event_id)
        )
        return result.scalar_one_or_none()
```

#### Frontend

```
Layer 1: Screen        (FrontEnd/lib/screens/)       → UI only, reads state from providers
Layer 2: Provider      (FrontEnd/lib/providers/)      → state management (loading, error, pagination, cache)
Layer 3: Repository    (FrontEnd/lib/repositories/)   → ALL HTTP calls, returns typed models
```

**Example — my pledges screen:**

```dart
// Layer 3: Repository (HTTP calls only — returns typed models)
class FundingRepository extends BaseRepository {
  FundingRepository(super.dio);

  Future<PaginatedResult<Pledge>> getMyPledges({int offset = 0, int limit = 20}) async {
    final r = await dio.get('/me/pledges', queryParameters: {'offset': offset, 'limit': limit});
    final items = (r.data['items'] as List).map((j) => Pledge.fromJson(j)).toList();
    return PaginatedResult(items: items, hasMore: r.data['has_more'] ?? false);
  }

  Future<Pledge> pledge(int eventId, int amountCents, {bool isGuest = false}) async {
    final r = await dio.post('/events/$eventId/pledge', data: {'amount_cents': amountCents, 'is_guest': isGuest});
    return Pledge.fromJson(r.data);
  }
}

// Layer 2: Provider (state management — loading, pagination, cache)
class PledgeProvider extends ChangeNotifier {
  final FundingRepository _repo;
  PledgeProvider(this._repo);

  List<Pledge> pledges = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  String? error;

  Future<void> load() async {
    loading = true; error = null; notifyListeners();
    try {
      final result = await _repo.getMyPledges();
      pledges = result.items;
      hasMore = result.hasMore;
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true; notifyListeners();
    final result = await _repo.getMyPledges(offset: pledges.length);
    pledges.addAll(result.items);
    hasMore = result.hasMore;
    loadingMore = false; notifyListeners();
  }
}

// Layer 1: Screen (UI only — no API calls, no local state for data)
class _MyPledgesScreenState extends State<MyPledgesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PledgeProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PledgeProvider>();
    if (p.loading) return const Center(child: CircularProgressIndicator());
    if (p.error != null) return ErrorView(p.error!, onRetry: p.load);
    return ListView.builder(
      itemCount: p.pledges.length + (p.hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == p.pledges.length) { p.loadMore(); return const LoadingTile(); }
        return PledgeTile(pledge: p.pledges[i]);
      },
    );
  }
}
```

### Architecture Rules

#### Backend

1. **Repositories own ALL SQLAlchemy** — `select`, `db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete` must ONLY appear in `Backend/app/repositories/`. Never in services or API routes.
2. **Services must NOT import `select` or `func`** — they call repository methods instead. Services contain: validation, business rules, commission calcs, payment orchestration, notification dispatch.
3. **API routes must be thin** — authenticate, parse input, call service, return response. No business logic, no direct DB queries.
4. **New domain = new repository file** — e.g., "polls" feature → `Backend/app/repositories/poll_repo.py`.
5. **Read/Write DB routing preserved** — repos accept `AsyncSession`, callers (services/routes) decide `DbSession` vs `ReadDbSession`.

```python
# ❌ BAD — db.execute in service
async def create_pledge(db, user_id, body):
    existing = await db.execute(select(Funding).where(Funding.user_id == user_id))

# ✅ GOOD — service calls repository
async def create_pledge(db, user_id, body):
    existing = await funding_repo.get_by_user_and_event(db, user_id, body.event_id)
```

#### Frontend

1. **Repositories own ALL Dio HTTP calls** — every `dio.get()`, `dio.post()` must live in `FrontEnd/lib/repositories/`. Never in providers, screens, or other files.
2. **Repositories return typed models** — never return raw `Map<String, dynamic>`. Parse JSON into model classes (`Pledge.fromJson()`).
3. **Providers own ALL state** — `loading`, `error`, `hasMore`, items lists, pagination offsets, filters, sort orders. Screens must NOT have local state for API data.
4. **Screens only read from providers** — `context.watch<Provider>()` to read state, `context.read<Provider>().method()` to dispatch actions. Never call repositories directly from screens.
5. **New domain = new repository + provider** — e.g., "polls" feature → `repositories/poll_repository.dart` + `providers/poll_provider.dart`.

```dart
// ❌ BAD — screen manages state and calls API directly
class _State extends State<MyScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  Future<void> _load() async {
    final api = context.read<ApiService>();
    final data = await api.getSomething();
    setState(() { _items = data['items']; _loading = false; });
  }
}

// ✅ GOOD — screen reads from provider, provider calls repository
class _State extends State<MyScreen> {
  @override
  void initState() { super.initState(); context.read<MyProvider>().load(); }
  @override
  Widget build(BuildContext context) {
    final p = context.watch<MyProvider>();
    if (p.loading) return const CircularProgressIndicator();
    return ListView(children: p.items.map((i) => ItemTile(item: i)).toList());
  }
}
```

### Why 3 Layers?

| Benefit | How |
|---------|-----|
| **Testable** | Mock the repo to test business logic without a DB. Test queries without HTTP by testing repo directly. |
| **Swappable** | Switch from PostgreSQL? Only change repositories. REST to GraphQL? Only change repositories. |
| **No duplication** | Same query ("get pledge by ID with eager loads") written once in repo, called from multiple services. |
| **Screens stay simple** | No loading/error/pagination state. Providers handle all of that. |
| **Cross-screen state** | Pledge on event detail → PledgeProvider notifies → pledge list screen auto-updates. No manual refresh. |
| **Single responsibility** | Each layer does exactly one thing. |

### Cross-Screen State Sharing

The biggest frontend win. Currently each screen is isolated — stale state everywhere:

```
❌ Before: Bookmark on EventDetail → go to HomeTab → bookmark icon still empty (stale)
❌ Before: Purchase ticket on EventDetail → go to MyTickets → must manual refresh
❌ Before: Cancel event in EditEvent → go to MyEvents → still shows "active"
```

With shared providers:

```
✅ After: Bookmark on EventDetail → EventProvider.toggleBookmark() → notifyListeners()
          → EventDetail rebuilds with filled icon
          → HomeTab rebuilds with filled icon (same provider!)
          → BookmarkedEventsScreen rebuilds with event added

✅ After: Purchase ticket → TicketProvider.purchase() → notifyListeners()
          → MyTickets auto-refreshes with new ticket

✅ After: Cancel event → EventProvider.cancelEvent() → notifyListeners()
          → All screens watching this provider see "cancelled" immediately
```

### Adding a New Feature — Checklist

When adding any feature that involves API calls or DB queries:

**Backend:**
- [ ] Add query methods to the appropriate repository (or create a new one)
- [ ] Add business logic to the appropriate service (calls repo, not db.execute)
- [ ] Add thin API route (calls service)
- [ ] Classify endpoint as Read/Write and use correct DB session
- [ ] Add tests for the new repository methods

**Frontend:**
- [ ] Add HTTP methods to the appropriate repository (or create a new one)
- [ ] Add/update provider with state management
- [ ] Screen only uses `context.watch` / `context.read<Provider>()`
- [ ] No raw `Map<String, dynamic>` — use typed models
- [ ] Run `dart analyze` on changed files

---

## Existing Test Infrastructure

| Component | Backend | Frontend |
|-----------|---------|----------|
| **Test dir** | `Backend/tests/` — 30 test files | `FrontEnd/test/` — 51 test files |
| **Config** | `pytest.ini` + `conftest.py` (620 lines) | `flutter_test` + `mocktail` |
| **Mock auth** | Bearer token mock, Firebase override, test lifespan | Mock ApiService, mock providers, pumpApp helper |
| **Test DB** | `TEST_DATABASE_URL` + TRUNCATE isolation | N/A |
| **Dependencies** | pytest, pytest-asyncio, httpx, slowapi | flutter_test, mocktail, network_image_mock |
| **Fixtures** | client, db_session, test_users, test_venue, test_event, test_event_approved, test_ticket_tier, test_pledge, test_ticket_sale, test_registration, test_sponsor_profile, test_sponsorship_category, test_sponsor_bid | fixtures.dart with Event, User, Pledge, Ticket factories |
| **Test structure** | Flat: `tests/test_*.py` | Organized: `test/helpers/`, `test/models/` (14), `test/providers/` (6), `test/screens/` (26) |

---

## Phase 0: Test Coverage (BEFORE any refactoring)

### 0A. Backend — Expand endpoint tests per domain

`conftest.py` (620 lines) provides: async client, test DB with TRUNCATE isolation, mock Firebase auth, lightweight test lifespan, and fixtures for users, venues, events, tickets, pledges, registrations, sponsors, notifications, milestones, schedules, images, posts, ratings, strategies, and discounts.

30 test files already exist. Review coverage gaps and expand for domains that will be touched:

| Test File | Status | Key Gaps to Fill |
|-----------|--------|------------------|
| `tests/test_funding.py` | Check if exists | Pledge lifecycle edge cases: duplicate pledge, guest pledge, tier reservations, refund flow |
| `tests/test_tickets.py` | Exists | Add: purchase with reserved spots, multi-tier purchase, discount application, capacity limits |
| `tests/test_events.py` | Exists | Add: auto_transition_status, featured/trending queries, clone, co-organizer, keyset pagination |
| `tests/test_registration.py` | Check if exists | Open vs closed registration, age restriction, waitlist approval |
| `tests/test_notifications.py` | Check if exists | List, mark read, mark all read, register/unregister device token |
| `tests/test_sponsors.py` | Check if exists | Place bid, accept, reject, withdraw, pay, refund, category CRUD |
| `tests/test_banking.py` | Check if exists | Encrypted storage, Stripe conditional logic, escrow stage release |

### 0B. Frontend — Test infrastructure already exists

Test infrastructure is already set up with 51 test files:

```
test/
├── helpers/          (4 files: fixtures.dart, mock_api_service.dart, mock_providers.dart, pump_app.dart)
├── models/           (14 files: all major models tested)
├── providers/        (6 files: all 6 existing providers tested)
└── screens/          (26 files: major screens tested)
```

Dependencies already installed: `flutter_test`, `mocktail`, `network_image_mock`.

**Phase 0B work:** Add `mock_repositories.dart` to `test/helpers/` and a `test/repositories/` directory as new repos are created. Update `mock_api_service.dart` to also mock new repository interfaces.

### 0C. Run baseline

```bash
# Backend — run all existing tests, record pass count
cd Backend && pytest -v --tb=short 2>&1 | tee test_baseline.txt

# Frontend — run all existing tests, record pass count
cd FrontEnd && flutter test 2>&1 | tee test_baseline.txt
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
| 2.1 | `Backend/app/repositories/funding_repo.py` | Extract 24 db.execute calls from `services/funding/pledges.py` + 8 from `services/funding/reservations.py`: get_pledge, list_by_user, list_by_event, count_by_event, get_pledged_total, create_pledge, update_status, get_user_reserved_spots, advisory_lock |
| 2.2 | `Backend/app/services/funding/pledges.py` | Replace all 32 db.execute calls with funding_repo.xxx calls. Service keeps: validation, commission calc, payment orchestration, notification dispatch |

**Frontend:**

| Step | File | What |
|------|------|------|
| 2.3 | `FrontEnd/lib/repositories/funding_repository.dart` | Own Dio instance. Methods: getMyPledges, getPledgeReceipt, getFundingSummary, getPledgePreview, pledge, unpledge, getRefundStatus, getOrganizerPledges. All return typed models (Pledge, FundingSummary, PaginatedResult<Pledge>) |
| 2.4 | `FrontEnd/lib/providers/pledge_provider.dart` | State: pledges, loading, loadingMore, hasMore, error, sortBy, filterStatus. Methods: load, loadMore, setSortBy, setFilter. Calls FundingRepository |
| 2.5 | `FrontEnd/lib/screens/profile/my_pledges_screen.dart` | Remove all ApiService calls, loading/pagination state. Use `context.watch<PledgeProvider>()`. Screen becomes ~50% smaller |
| 2.6 | Delete methods from ApiService | Remove ~12 funding/pledge methods (getMyPledges, getOrganizerPledges, pledge, unpledge, getPledgePreview, getPledgeReceipt, getMyPledgeReceipt, getFundingSummary, getRefundStatus, etc.) |

### Phase 3: Tickets

**Backend:**

| Step | File | What |
|------|------|------|
| 3.1 | `Backend/app/repositories/ticket_repo.py` | Extract 28 db.execute calls from `services/ticket/sales.py` + 9 from `services/ticket/pricing.py`: count_purchased, get_tier, list_tiers, create_sale, get_by_user, get_sales_for_event, get_waitlisted, update_status, count_by_tier |
| 3.2 | `Backend/app/services/ticket/sales.py` | Replace all 37 db.execute calls with repo calls. Service keeps: pricing logic, spot consumption, payment, advisory locks, receipt generation |

**Frontend:**

| Step | File | What |
|------|------|------|
| 3.3 | `FrontEnd/lib/repositories/ticket_repository.dart` | Methods: getMyTickets, getTicketTiers, purchaseTickets, getTicketReceipt, requestRefund, getRefundRequests, approveRefund, rejectRefund, scanTicket, getWaitlisted, approveWaitlisted, rejectWaitlisted, getTicketPrice, startSellingTickets, getTicketSalesStats |
| 3.4 | `FrontEnd/lib/providers/ticket_provider.dart` | State: myTickets, loading, hasMore, sortBy. Methods: load, loadMore |
| 3.5 | Migrate screens | my_tickets_screen.dart, ticket_tiers_section.dart, ticket_receipt_screen.dart, refund_requests_screen.dart, ticket_scanner_screen.dart, ticket_waitlist_screen.dart, ticket_sales_screen.dart |
| 3.6 | Delete methods from ApiService | ~48 ticket/refund/waitlist/discount methods |

### Phase 4: Events

**Backend:**

| Step | File | What |
|------|------|------|
| 4.1 | `Backend/app/repositories/event_repo.py` | Extract 15 db.execute calls from `services/event/crud.py` + 16 from `services/event/lifecycle.py`: get_event, list_events, list_featured, list_trending, list_coming_soon, create_event, update_event, update_status, get_by_organizer, count_by_organizer, get_with_relations |
| 4.2 | `Backend/app/services/event/crud.py` + `lifecycle.py` | Replace all 31 db.execute calls with repo. Service keeps: auto_transition_status state machine, substantive_change detection, approval logic |

**Frontend:**

| Step | File | What |
|------|------|------|
| 4.3 | `FrontEnd/lib/repositories/event_repository.dart` | Methods: getEvents, getEvent, getFeaturedEvents, getMapEvents, createEvent, updateEvent, deleteEvent, publishEvent, cancelEvent, reactivateEvent, cloneEvent, setEventDate, getEventCities, getGenres, getEventImages, addEventImage, uploadEventImage, deleteEventImage, getEventPosts, createEventPost, deleteEventPost, getEventRatings, getRatingsSummary, createRating, getMyReaction, reactToEvent |
| 4.4 | Expand `EventProvider` | Add image, post, rating methods. Move loading logic from screens |
| 4.5 | Migrate screens | home_tab.dart, explore_tab.dart, event_detail_screen.dart, create_event_screen.dart, edit_event_screen.dart, my_events_tab.dart, organizer_dashboard_tab.dart + all event_detail/ sub-screens |
| 4.6 | Delete methods from ApiService | ~65 event/image/post/rating/schedule/milestone methods |

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
| 5.6 | Delete methods from ApiService | ~20 user/profile/kyc/bank/payment methods |

### Phase 6: Registration

**Backend:**

| Step | File | What |
|------|------|------|
| 6.1 | `Backend/app/repositories/registration_repo.py` | Extract 15 db.execute calls from `services/registration.py`: get_registration, count_registered, create, update_status, list_by_event |
| 6.2 | `Backend/app/services/registration.py` | Replace all 15 db.execute calls with repo calls |

**Frontend:**

| Step | File | What |
|------|------|------|
| 6.3 | `FrontEnd/lib/repositories/registration_repository.dart` | Methods: register, unregister, getMyRegistration, getRegistrations, decideRegistration |
| 6.4 | Integrate into EventProvider | Registration is part of event detail flow |
| 6.5 | Delete methods from ApiService | ~5 registration methods |

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
| 7.5 | Delete methods from ApiService | ~8 notification/device token methods |

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
| 8.6 | Delete methods from ApiService | ~44 sponsor/bid/category/template/ticket/delegate methods |

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

Each domain follows this safe incremental pattern — **only run tests for the phase you changed**:

```
Step A: Write/expand backend tests for this domain's endpoints
         ↓  run domain pytest → all pass
Step B: Create backend repository (new file, nothing breaks)
         ↓  run domain pytest → all pass
Step C: Refactor backend service to use repo (internal change, API unchanged)
         ↓  run domain pytest → all pass (this is the critical check)
Step D: Create frontend repository (new file, nothing breaks)
         ↓  dart analyze on new file → 0 issues
Step E: Write frontend repo + provider tests
         ↓  run domain flutter test → all pass
Step F: Create/expand frontend provider
         ↓  run domain flutter test → all pass
Step G: Migrate screens one-by-one to use provider
         ↓  run domain flutter test + dart analyze on changed files → all pass
Step H: Delete migrated methods from ApiService (only after all callers removed)
         ↓  run domain flutter test + grep for deleted methods → zero hits
```

At every step the app compiles, runs, and tests pass. No big-bang switchover.

### Per-Phase Test Commands

**Phase 1 (Foundation):** New files only — no existing tests to run.
```bash
# Backend: just verify import works
cd Backend && python -c "from app.repositories.base import BaseRepository; print('OK')"
# Frontend: static analysis only
cd FrontEnd && dart analyze lib/repositories/base_repository.dart
```

**Phase 2 (Funding/Pledges):**
```bash
# Backend
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_funding_coverage.py tests/test_funding_extended.py tests/test_phase5_domain_gaps.py tests/test_milestone_phase3.py tests/test_fund_escrow_phase2.py -v --tb=short

# Frontend
cd FrontEnd && flutter test test/models/funding_test.dart test/screens/my_pledges_screen_test.dart test/screens/funding_card_test.dart
cd FrontEnd && dart analyze lib/repositories/funding_repository.dart lib/providers/pledge_provider.dart lib/screens/profile/my_pledges_screen.dart
```

**Phase 3 (Tickets):**
```bash
# Backend
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_ticket_pricing_coverage.py tests/test_ticket_services_coverage.py tests/test_tickets_extended.py tests/test_ticket_sales_phase3.py tests/test_phase5_ticket_sales.py tests/test_strategies.py tests/test_discounts.py -v --tb=short

# Frontend
cd FrontEnd && flutter test test/models/ticket_test.dart test/models/ticket_strategy_test.dart test/screens/my_tickets_screen_test.dart test/screens/ticket_scanner_screen_test.dart test/screens/ticket_tiers_section_test.dart test/screens/ticket_sales_screen_test.dart test/screens/waitlist_screen_test.dart
cd FrontEnd && dart analyze lib/repositories/ticket_repository.dart lib/providers/ticket_provider.dart
```

**Phase 4 (Events):**
```bash
# Backend
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_events.py tests/test_events_public.py tests/test_event_crud_phase2.py tests/test_lifecycle.py tests/test_phase4b_event_support.py tests/test_images.py tests/test_posts.py tests/test_organizers.py -v --tb=short

# Frontend
cd FrontEnd && flutter test test/models/event_test.dart test/models/event_form_models_test.dart test/models/event_image_test.dart test/screens/event_detail_screen_test.dart test/screens/create_event_screen_test.dart test/screens/edit_event_screen_test.dart test/screens/home_screen_test.dart test/providers/event_provider_test.dart test/screens/organizer_dashboard_test.dart
cd FrontEnd && dart analyze lib/repositories/event_repository.dart lib/providers/
```

**Phase 5 (Users & Auth):**
```bash
# Backend
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_auth.py tests/test_auth_extended.py tests/test_users.py tests/test_public_profiles.py -v --tb=short

# Frontend
cd FrontEnd && flutter test test/models/user_test.dart test/screens/login_screen_test.dart test/screens/register_screen_test.dart test/screens/profile_screen_test.dart test/providers/auth_provider_test.dart
cd FrontEnd && dart analyze lib/repositories/user_repository.dart lib/providers/auth_provider.dart
```

**Phase 6 (Registration):**
```bash
# Backend
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_registration.py -v --tb=short

# Frontend
cd FrontEnd && flutter test test/screens/register_screen_test.dart
cd FrontEnd && dart analyze lib/repositories/registration_repository.dart
```

**Phase 7 (Notifications):**
```bash
# Backend
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_notifications.py -v --tb=short

# Frontend
cd FrontEnd && flutter test test/providers/notification_provider_test.dart
cd FrontEnd && dart analyze lib/repositories/notification_repository.dart lib/providers/notification_provider.dart
```

**Phase 8 (Sponsors):**
```bash
# Backend
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_sponsors.py tests/test_sponsors_coverage.py tests/test_sponsors_extended.py tests/test_sponsor_bids_phase3.py tests/test_sponsor_payments_coverage.py tests/test_sponsor_services_coverage.py tests/test_phase4a_sponsor.py tests/test_sponsor_escrow_coverage.py -v --tb=short

# Frontend
cd FrontEnd && flutter test test/models/sponsor_test.dart test/screens/sponsor_ticket_screen_test.dart test/screens/sponsor_dashboard_test.dart test/screens/sponsor_payment_receipt_test.dart test/screens/sponsor_category_templates_test.dart test/screens/sponsorship_categories_screen_test.dart test/screens/bid_management_test.dart test/screens/bid_chat_screen_test.dart
cd FrontEnd && dart analyze lib/repositories/sponsor_repository.dart lib/providers/sponsor_provider.dart
```

**Phase 9 (Remaining — Admin, Venues, Bookmarks, Escrow, Dashboard):**
```bash
# Backend
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_admin_extended.py tests/test_phase5_push_admin.py tests/test_venues.py tests/test_escrow_coverage.py tests/test_escrow_extended_coverage.py tests/test_dashboard_milestone_coverage.py tests/test_map.py tests/test_banking.py tests/test_payment_gateway_coverage.py -v --tb=short

# Frontend
cd FrontEnd && flutter test test/models/venue_test.dart test/models/milestone_test.dart test/models/schedule_test.dart test/screens/venue_screens_test.dart test/screens/bookmarked_events_test.dart test/screens/admin_dashboard_test.dart test/screens/organizer_sponsors_screen_test.dart test/screens/manage_screens_test.dart test/screens/receipt_screens_test.dart
cd FrontEnd && dart analyze lib/repositories/
```

---

## Key Rules During Migration

### Layer Ownership

1. **Backend repos** own ALL SQLAlchemy: `select`, `db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete`
2. **Backend services** must NOT import `select`, `func`, or call `db.execute` — only call repo methods
3. **Frontend repos** own ALL Dio HTTP calls and return typed models (never raw Maps)
4. **Frontend providers** own ALL state (loading, error, pagination, cache) — screens never manage these
5. **Frontend screens** only call `context.watch<Provider>()` to read and `context.read<Provider>().method()` to dispatch
6. **ApiService methods** are deleted only after ALL callers are migrated — grep to verify

### Dio Sharing

All frontend repositories use the **same Dio instance** that ApiService currently configures (base URL, Firebase auth headers, token refresh interceptor). In Phase 1, extract the configured Dio from ApiService and register it in MultiProvider as `Provider<Dio>.value()`. Repositories receive this Dio via constructor injection. ApiService continues to use its internal `_dio` during migration — both point to the same instance so auth headers stay in sync.

```dart
// main.dart — Phase 1
final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
// ... add auth interceptor, error interceptor (same ones ApiService uses)

MultiProvider(
  providers: [
    Provider<Dio>.value(value: dio),
    ChangeNotifierProvider(create: (_) => ApiService(dio)),  // ApiService uses same Dio
    Provider(create: (ctx) => FundingRepository(ctx.read<Dio>())),  // repos use same Dio
    // ...
  ],
)
```

### Mixed-Mode Screens

During migration, screens can have **both** `context.read<ApiService>()` and `context.watch<Provider>()` calls simultaneously. This is expected and OK — e.g., `event_detail_screen.dart` will use PledgeProvider (Phase 2) alongside ApiService for tickets (until Phase 3). Clean up the remaining ApiService calls when that screen's domain is migrated. No special handling needed.

### EventProvider Split

`EventProvider` is too large for a single ChangeNotifier (browse + detail + images + posts + ratings + schedule + milestones). Split into:

- **`EventBrowseProvider`** — browse list, featured, filters, pagination (used by home_tab, explore)
- **`EventDetailProvider`** — single event + images + posts + ratings + schedule + milestones (used by event_detail and sub-screens)

This prevents `notifyListeners()` on the detail screen from rebuilding the browse list and vice versa. Both share the same `EventRepository`.

### Transaction Boundaries

Repositories NEVER create their own database session. They always receive `db: AsyncSession` from the caller (service or route). This ensures multi-step operations (advisory lock → check → create → charge → ledger) all run in the same transaction. The route's session middleware handles commit/rollback.

```python
# ❌ BAD — repo creates its own session
class FundingRepository:
    async def create(self):
        async with get_session() as db:  # NEVER DO THIS
            db.add(obj)

# ✅ GOOD — repo uses caller's session
class FundingRepository:
    async def create(self, db: AsyncSession, obj):  # caller passes session
        db.add(obj)
        await db.flush()
```

### Worker Tasks

Worker tasks (`Backend/app/worker/tasks.py`) also call services that use `db.execute`. After refactoring services to use repos, worker tasks continue to call services the same way — no changes needed to task code itself. However, **verify worker-related tests pass** after each backend phase:

- **Phase 2 (Funding):** Verify `process_pledge_refund` still works (calls pledge service → funding repo)
- **Phase 3 (Tickets):** Verify `process_ticket_refund` still works (calls ticket service → ticket repo)
- **Phase 4 (Events):** Verify `auto_transition_status` cron still works (calls lifecycle service → event repo)
- **Phase 8 (Sponsors):** Verify `process_sponsor_refund` still works (calls sponsor service → sponsor repo)
- **Phase 9 (Remaining):** Verify escrow release tasks (`release_stage_1/2/3`) still work (calls escrow service → multiple repos)

Add to each phase's verification checklist:
```bash
# After backend refactor step — verify worker tasks aren't broken
pytest tests/test_funding.py -k "refund" -v  # Phase 2
pytest tests/test_tickets.py -k "refund" -v  # Phase 3
pytest tests/test_events.py -k "transition" -v  # Phase 4
```

### Git Branching

Each phase = one git branch off `main`. Branch naming: `refactor/phase-N-domain-name` (e.g., `refactor/phase-2-funding`). Merge to main only after all tests pass. If a phase goes wrong halfway, `git checkout main` reverts everything cleanly.

```bash
git checkout -b refactor/phase-2-funding
# ... do all Phase 2 work, test after each step ...
# When all Phase 2 tests pass:
git checkout main && git merge refactor/phase-2-funding
```

---

## Current Metrics (as of 2026-03-02)

### Backend: 368 db.execute calls across 46 service files

| Service File | db.execute | Phase |
|-------------|-----------|-------|
| `services/admin.py` | 36 | 9 (Admin) |
| `services/ticket/sales.py` | 28 | 3 |
| `services/funding/pledges.py` | 24 | 2 |
| `services/event/lifecycle.py` | 16 | 4 |
| `services/registration.py` | 15 | 6 |
| `services/event/crud.py` | 15 | 4 |
| `services/sponsor/payments.py` | 14 | 8 |
| `services/sponsor/categories.py` | 14 | 8 |
| `services/dashboard.py` | 12 | 9 |
| `services/escrow.py` | 11 | 9 |
| `services/discount_strategy.py` | 11 | 9 |
| `services/ticket_escrow.py` | 10 | 9 |
| `services/sponsor/organizer_queries.py` | 10 | 8 |
| `services/sponsor/bids.py` | 10 | 8 |
| `services/ticket/pricing.py` | 9 | 3 |
| `services/refund_retry.py` | 9 | 9 |
| `services/milestone.py` | 9 | 9 |
| `services/sponsor_escrow.py` | 8 | 9 |
| `services/sponsor/tickets.py` | 8 | 8 |
| `services/funding/reservations.py` | 8 | 2 |
| Other 26 files | ~71 | Various |

### Frontend: 235 ApiService methods, 80 screens using context.read<ApiService>()

| Phase | Domain | ApiService Methods | Screens to Migrate |
|-------|--------|-------------------|-------------------|
| 2 | Funding/Pledges | ~12 | 2 |
| 3 | Tickets | ~48 | 7 |
| 4 | Events | ~65 | 12+ |
| 5 | Users & Auth | ~20 | 3 |
| 6 | Registration | ~5 | 1 |
| 7 | Notifications | ~8 | 1 |
| 8 | Sponsors | ~44 | 15 |
| 9 | Remaining | ~33 | ~13 |
| **Total** | | **235** | **54** |

---

## Verification

### Per-Phase: Run only the domain's tests

After each phase, run **only the tests listed in "Per-Phase Test Commands" above** for that domain. Do NOT run the full test suite after every phase — it's slow and unnecessary. The domain tests catch regressions in the code you touched.

Also check migration progress after each phase:
```bash
# Migration completeness — grep for old patterns
grep -rc "context.read<ApiService>()" FrontEnd/lib/screens/ | grep -v ':0$' | wc -l   # starts at 80, decreases each phase
grep -rc "db\.execute" Backend/app/services/ | grep -v ':0$' | wc -l                  # starts at 46 files, decreases each phase
```

### Final (Phase 10): Full test suite — the ONLY time we run everything

```bash
# Backend — full suite, must pass all tests
cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest -v --tb=short

# Frontend — full suite + full static analysis
cd FrontEnd && flutter test && dart analyze lib/

# Zero old patterns remaining
grep -r "context.read<ApiService>()" FrontEnd/lib/  # → zero matches
grep -r "db\.execute" Backend/app/services/          # → zero matches (all 368 moved to repos)
```

- Manual smoke test: login → browse events → pledge → buy ticket → check profile lists
