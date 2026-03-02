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

## 3-Layer Architecture

> Applies to: ALL new features, endpoints, screens, and modifications.

The codebase follows a strict **3-layer separation**: Data → Service/Provider → API/Screen. Every new feature or modification MUST maintain this architecture.

### Backend Layers

```
Layer 1: API Route     (Backend/app/api/v1/)        → thin: auth, validate, return response
Layer 2: Service       (Backend/app/services/)       → business logic ONLY, no db.execute
Layer 3: Repository    (Backend/app/repositories/)   → ALL database queries
```

**Rules:**

1. **Repositories own ALL SQLAlchemy** — `select`, `db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete` must ONLY appear in `Backend/app/repositories/`. Never in services or API routes.
2. **Services must NOT import `select` or `func`** — they call repository methods instead of writing queries. Services contain: validation, business rules, commission calculations, payment orchestration, notification dispatch.
3. **API routes must be thin** — authenticate, parse input, call service, return response. No business logic, no direct DB queries.
4. **New domain = new repository file** — e.g., adding a "polls" feature → create `Backend/app/repositories/poll_repo.py`.

```python
# ❌ BAD — db.execute in service
async def create_pledge(db, user_id, body):
    existing = await db.execute(select(Funding).where(Funding.user_id == user_id))
    ...

# ✅ GOOD — service calls repository
async def create_pledge(db, user_id, body):
    existing = await funding_repo.get_by_user_and_event(db, user_id, body.event_id)
    ...
```

### Frontend Layers

```
Layer 1: Screen        (FrontEnd/lib/screens/)       → UI only, reads from providers
Layer 2: Provider      (FrontEnd/lib/providers/)      → state management (loading, error, pagination)
Layer 3: Repository    (FrontEnd/lib/repositories/)   → ALL HTTP calls, returns typed models
```

**Rules:**

1. **Repositories own ALL Dio HTTP calls** — every `dio.get()`, `dio.post()`, etc. must live in `FrontEnd/lib/repositories/`. Never in providers, screens, or other files.
2. **Repositories return typed models** — never return raw `Map<String, dynamic>`. Parse JSON into model classes (e.g., `Pledge.fromJson()`).
3. **Providers own ALL state** — `loading`, `error`, `hasMore`, `items` lists, pagination offsets, filters, sort orders. Screens must NOT have local state for data fetched from the API.
4. **Screens only read from providers** — use `context.watch<Provider>()` to read state and `context.read<Provider>().method()` to dispatch actions. Never call repositories directly from screens.
5. **New domain = new repository + provider** — e.g., adding a "polls" feature → create `repositories/poll_repository.dart` + `providers/poll_provider.dart`.

```dart
// ❌ BAD — screen manages state and calls API directly
class _MyScreenState extends State<MyScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  Future<void> _load() async {
    final api = context.read<ApiService>();
    final data = await api.getSomething();
    setState(() { _items = data['items']; _loading = false; });
  }
}

// ✅ GOOD — screen reads from provider
class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MyProvider>().load();
  }
  @override
  Widget build(BuildContext context) {
    final p = context.watch<MyProvider>();
    if (p.loading) return const CircularProgressIndicator();
    return ListView(children: p.items.map((i) => ItemTile(item: i)).toList());
  }
}
```

### Adding a New Feature — Checklist

When adding any feature that involves API calls or DB queries:

1. **Backend:**
   - [ ] Add query methods to the appropriate repository (or create a new one)
   - [ ] Add business logic to the appropriate service (calls repo, not db.execute)
   - [ ] Add thin API route (calls service)
   - [ ] Classify endpoint as Read/Write and use correct DB session (see Read/Write rules above)

2. **Frontend:**
   - [ ] Add HTTP methods to the appropriate repository (or create a new one)
   - [ ] Add/update provider with state management
   - [ ] Screen only uses `context.watch` / `context.read<Provider>()`
   - [ ] No raw `Map<String, dynamic>` returned from repository — use typed models

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
