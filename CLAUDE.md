# Claude Code Rules

> Imported from `.cursor/rules/` — applies to all Claude Code sessions in this project.

---

## Backend: N+1 Prevention & Read/Write DB Routing

> Applies to: `Backend/app/**/*.py`

### 1. Avoid N+1 Queries

When writing SQLAlchemy queries that return rows with relationships accessed in the response:

- **Eager load relationships** using `selectinload`, `joinedload`, or `subqueryload` — never let lazy loading trigger per-row queries.
- **Identify needed relations** before building the query: if the response schema includes nested data (e.g. `event.venue`, `ticket_sale.user`), load them in the query.

```python
# ❌ BAD — N+1: each event.venue access triggers another query
result = await session.execute(select(Event).where(...))
events = result.scalars().all()
# Later: event.venue for each event → N extra queries

# ✅ GOOD
result = await session.execute(
    select(Event)
    .options(selectinload(Event.venue), selectinload(Event.ticket_strategy))
    .where(...)
)
events = result.scalars().all()
```

**When to use which:**
- `selectinload`: one-to-many or many-to-many (separate IN query)
- `joinedload`: many-to-one or one-to-one (single JOIN)
- `subqueryload`: one-to-many when joinedload would cause row duplication

---

### 2. Read/Write Analysis for New Endpoints

Before implementing a new API endpoint, perform this analysis:

#### Step 1: Classify the endpoint

| Type | Use case | Example |
|------|----------|---------|
| **Read-only** | List, get-by-id, search, export | `GET /events`, `GET /events/{id}`, `GET /users/{id}/ratings` |
| **Write** | Create, update, delete | `POST /events`, `PATCH /events/{id}`, `DELETE /bookmarks/{id}` |
| **Coupled** | Read then write in same request | Purchase ticket (read capacity → write sale), conditional updates |

#### Step 2: Route to the correct session

| Classification | Use | From `app.dependencies` |
|----------------|-----|-------------------------|
| Read-only | Replica (or primary if no replica) | `ReadDbSession` |
| Write or coupled | Primary (writer) | `DbSession` |

```python
# Read-only: list events, get event, search
@router.get("/events")
async def list_events(db: ReadDbSession): ...

# Write: create, update, delete
@router.post("/events")
async def create_event(db: DbSession): ...

# Coupled: read capacity then write sale
@router.post("/events/{id}/tickets/purchase")
async def purchase_ticket(db: DbSession): ...
```

#### Step 3: Service layer

- Services called from **read-only** endpoints should accept a session and perform **no mutations** — use `ReadDbSession`.
- Services called from **write** or **coupled** endpoints need the primary session — use `DbSession`.

Do not mix: a single request should use either `ReadDbSession` (all reads) or `DbSession` (reads + writes).

---

## 3-Layer Architecture — STRICT ENFORCEMENT

> **BLOCKING REQUIREMENT** — applies to ALL new features, endpoints, screens, and modifications.
> Violations of these rules must be caught and fixed BEFORE writing code. If you are about to write code that crosses a layer boundary, STOP and restructure.

The codebase follows a strict **3-layer separation**: Data → Service/Provider → API/Screen.

### Backend Layers

```
Layer 1: API Route     (Backend/app/api/v1/)        → thin: auth, validate, return response
Layer 2: Service       (Backend/app/services/)       → business logic ONLY, no db.execute
Layer 3: Repository    (Backend/app/repositories/)   → ALL database queries
```

### Frontend Layers

```
Layer 1: Screen        (FrontEnd/lib/screens/)       → UI only, reads from providers
Layer 2: Provider      (FrontEnd/lib/providers/)      → state management (loading, error, pagination)
Layer 3: Repository    (FrontEnd/lib/repositories/)   → ALL HTTP calls, returns typed models
```

---

### Pre-Write Validation Gate

**BEFORE writing or editing any file, classify it by layer and enforce the corresponding constraints.** This is not optional — it is a hard gate.

#### If the file is a **backend service** (`Backend/app/services/**/*.py`):

- **REJECT** any line containing: `db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete`, `db.commit`, `db.rollback` — services must have ZERO `db.*` calls of any kind
- **REJECT** any import of `select`, `func`, `text`, `insert`, `update`, `delete` from `sqlalchemy`
- **REJECT** any import from `sqlalchemy.orm` (e.g., `selectinload`, `joinedload`) — those belong in repos
- **MUST** call repository methods instead. If no suitable repo method exists, create one first.

#### If the file is a **backend route** (`Backend/app/api/v1/**/*.py`):

- **ALLOW** `db.commit()` and `db.rollback()` — routes own the transaction boundary (call service → commit)
- **REJECT** data operations: `db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete` — those belong in repositories
- **REJECT** any import of `select`, `func` from `sqlalchemy`
- **REJECT** business logic: commission calculations, fee computations, multi-step orchestration, notification dispatch
- **REJECT** more than one service/repo call for simple endpoints (complex flows must go through a service)
- **MUST** be thin: authenticate → validate input → call service → commit → return response

#### If the file is a **backend worker task** (`Backend/app/worker/**/*.py`):

- **ALLOW** `db.commit()` and `db.rollback()` — worker tasks own transaction boundaries
- **REJECT** data operations: `db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete`
- **MUST** call services or repositories for all data access

#### If the file is a **frontend screen** (`FrontEnd/lib/screens/**/*.dart`):

- **REJECT** any `dio.get()`, `dio.post()`, `dio.put()`, `dio.patch()`, `dio.delete()` call
- **REJECT** direct repository instantiation or `context.read<*Repository>()`
- **REJECT** local state that manages API-fetched lists with pagination (`offset`, `hasMore`, `loadMore`)
- **MUST** use `context.watch<*Provider>()` for reading state and `context.read<*Provider>().method()` for actions
- **Exception:** Simple one-shot receipt/detail screens (e.g., `PledgeReceiptScreen`, `TicketReceiptScreen`) may use a repository directly for a single fetch-and-display pattern. This is acceptable ONLY when there is no list, no pagination, and no shared state.

#### If the file is a **frontend provider** (`FrontEnd/lib/providers/**/*.dart`):

- **REJECT** any `dio.get()`, `dio.post()`, etc. — providers call repositories, not Dio
- **MUST** own all state: `loading`, `error`, `items`, `hasMore`, pagination, filters, sort

#### If the file is a **frontend repository** (`FrontEnd/lib/repositories/**/*.dart`):

- **REJECT** any mutable state (`notifyListeners`, `ChangeNotifier`) — repos are stateless
- **MUST** return typed models (e.g., `Event.fromJson()`), not raw `Map<String, dynamic>`
- **Exception:** `PaymentRepository` returns Maps for Stripe pass-through responses

#### If the file is a **backend repository** (`Backend/app/repositories/**/*.py`):

- This is the ONLY place `select`, `func`, `db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete` are allowed
- **MUST** use eager loading (`selectinload`/`joinedload`/`subqueryload`) when returning models whose relationships will be accessed by the caller
- **MUST** accept `AsyncSession` as first parameter — never create sessions internally

---

### Banned Patterns — Instant Rejection

These patterns must NEVER appear. If you catch yourself writing any of them, stop immediately and restructure.

```python
# ❌ BANNED — any db call in service (services must have ZERO db.* calls)
# File: Backend/app/services/*.py
await db.execute(select(Funding).where(...))        # → Use funding_repo.get_by_*()
await db.commit()                                    # → Caller (route/worker) commits
from sqlalchemy import select, func                  # → Import repo instead

# ❌ BANNED — data operations in route (commit/rollback are OK)
# File: Backend/app/api/v1/*.py
await db.execute(select(Event).where(...))           # → Use event_repo.*()
db.add(event)                                        # → Use event_repo.create()
commission = amount * Decimal("0.05")                # → Move to service
await notif_svc.create_notification(db, ...)         # → Call from service, not route

# ✅ OK in routes — transaction boundary
await db.commit()
await db.rollback()

# ❌ BANNED — data operations in worker (commit/rollback are OK)
# File: Backend/app/worker/tasks.py
await db.execute(select(Event).where(...))           # → Use event_repo.*()
```

```dart
// ❌ BANNED — Dio in screen
// File: FrontEnd/lib/screens/*.dart
final resp = await dio.get('/events');                // → Use provider

// ❌ BANNED — Repository in screen (for list/pagination state)
// File: FrontEnd/lib/screens/*.dart
final events = await eventRepo.getEvents();          // → Use EventProvider
setState(() { _events = events; _loading = false; }); // → Provider owns state

// ❌ BANNED — Dio in provider
// File: FrontEnd/lib/providers/*.dart
final resp = await dio.get('/events');                // → Use EventRepository

// ❌ BANNED — Mutable state in repository
// File: FrontEnd/lib/repositories/*.dart
bool isEnabled = false;                               // → State goes in provider
void notifyListeners() { ... }                        // → Repos are stateless
```

---

### Correct Patterns — What To Write Instead

```python
# ✅ Backend: Route → Service → Repository
# Route (thin):
@router.post("/events/{event_id}/pledges")
async def create_pledge(event_id: int, body: PledgeCreate, db: DbSession, user: CurrentUser):
    pledge = await pledge_service.create_pledge(db, user.id, event_id, body)
    return PledgeResponse.model_validate(pledge)

# Service (business logic):
async def create_pledge(db, user_id, event_id, body):
    existing = await funding_repo.get_by_user_and_event(db, user_id, event_id)
    if existing:
        raise ConflictError("Already pledged")
    pledge = await funding_repo.create(db, user_id=user_id, event_id=event_id, amount=body.amount)
    await notif_svc.notify_pledge(db, pledge)
    return pledge

# Repository (all DB):
async def get_by_user_and_event(self, db, user_id, event_id):
    q = select(Funding).where(Funding.user_id == user_id, Funding.event_id == event_id)
    return (await db.execute(q)).scalar_one_or_none()
```

```dart
// ✅ Frontend: Screen → Provider → Repository
// Repository (HTTP):
Future<List<Pledge>> getMyPledges({int offset = 0, int limit = 20}) async {
  final r = await dio.get('/me/pledges', queryParameters: {'offset': offset, 'limit': limit});
  return (r.data['items'] as List).map((j) => Pledge.fromJson(j)).toList();
}

// Provider (state):
class PledgeProvider extends ChangeNotifier {
  final FundingRepository _repo;
  List<Pledge> pledges = [];
  bool loading = false;
  Future<void> load() async {
    loading = true; notifyListeners();
    pledges = await _repo.getMyPledges();
    loading = false; notifyListeners();
  }
}

// Screen (UI only):
Widget build(BuildContext context) {
  final p = context.watch<PledgeProvider>();
  if (p.loading) return const ShimmerList();
  return ListView(children: p.pledges.map((pl) => PledgeTile(pledge: pl)).toList());
}
```

---

### Adding a New Feature — Mandatory Checklist

When adding any feature that involves API calls or DB queries, you MUST complete ALL items. Do not skip steps.

**Backend:**
1. [ ] Identify the repository — does one exist for this domain? If not, create `Backend/app/repositories/<domain>_repo.py`
2. [ ] Add query methods to the repository (all `select`/`db.execute` here)
3. [ ] Add business logic to the service (`Backend/app/services/`) — calls repo methods, ZERO db imports
4. [ ] Add thin API route — authenticate, validate, call service, return response
5. [ ] Classify endpoint as Read/Write and use correct DB session (`ReadDbSession` vs `DbSession`)
6. [ ] Eager-load relationships needed by the response schema

**Frontend:**
1. [ ] Identify the repository — does one exist? If not, create `FrontEnd/lib/repositories/<domain>_repository.dart`
2. [ ] Add HTTP methods to the repository — return typed models
3. [ ] Add/update provider with state management (`loading`, `error`, items, pagination)
4. [ ] Screen uses ONLY `context.watch<Provider>()` / `context.read<Provider>().method()`
5. [ ] Register new providers in `main.dart` MultiProvider if needed
6. [ ] Add new routes to `router.dart` if new screens are created

**Verification:**
- [ ] Run `/check-architecture` to confirm zero violations
- [ ] Run backend tests: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest -v --tb=short`
- [ ] Run frontend tests: `cd FrontEnd && flutter test`

---

## MCP Validation Rules

### Frontend: Validate with Dart MCP Server

After making any changes to Flutter/Dart files (`FrontEnd/lib/**/*.dart`):

- Use the **Dart MCP server** (`dart tooling-daemon`) to run `dart analyze` on the changed files.
- Fix all errors and warnings before considering the task complete.
- This catches type mismatches, missing imports, deprecated APIs, and other static analysis issues at edit time rather than at build time.

### Database: Validate with PostgreSQL MCP Server

After making any changes that affect the database (new migrations, model changes, query changes):

- Use the **PostgreSQL MCP server** to validate the change against the live database schema.
- For new migrations: verify the table/column exists after running the migration.
- For query changes: spot-check that the query executes without errors.
- For model changes: confirm the referenced tables and columns exist in the database.
