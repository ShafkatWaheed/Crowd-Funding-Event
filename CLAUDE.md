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
