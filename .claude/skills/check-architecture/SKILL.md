---
name: check-architecture
description: >
  Scan the codebase (or specific files) for 3-layer architecture violations.
  Detects direct DB operations in services/routes/worker, direct Dio calls
  outside repositories, business logic in routes, and state management
  in screens. Use when reviewing code, after writing a feature, or as
  a periodic health check. Invoke: /check-architecture [path-or-scope]
argument-hint: "[path | backend | frontend | all]"
allowed-tools: Grep, Glob, Read, Bash
---

# 3-Layer Architecture Violation Scanner

You are a strict architecture auditor. Scan the codebase for violations of the
3-layer separation and report every finding. **Never skip a check.** When
`$ARGUMENTS` is empty, scan everything (`all`).

Scope: `$ARGUMENTS` (default: `all`)

---

## Scan Procedure

### Step 1 — Determine scope

| Argument | Backend scan | Frontend scan |
|----------|-------------|---------------|
| `all` or empty | Yes | Yes |
| `backend` | Yes | No |
| `frontend` | No | Yes |
| A file/dir path | Yes if under `Backend/` | Yes if under `FrontEnd/` |

When a specific file path is given, scan that file **and** any files it
imports/calls that cross layer boundaries.

---

### Step 2 — Backend: Repository rule (CRITICAL)

There are two categories of DB operations:

**A) Data operations** — MUST only appear in repositories:
`db.execute`, `db.add`, `db.flush`, `db.refresh`, `db.delete`

**B) Transaction management** — allowed in routes and worker tasks:
`db.commit()` and `db.rollback()` are transaction boundaries. Routes and worker
tasks own the transaction lifecycle (call service → commit or rollback). This is
the standard FastAPI pattern.

**Rules:**
- **Services:** ZERO `db.*` calls of any kind (no data ops, no transaction mgmt)
- **Routes:** `db.commit()` / `db.rollback()` OK. Data ops (`db.execute`, `db.add`, etc.) BANNED.
- **Worker tasks:** Same as routes — commit/rollback OK, data ops BANNED.
- **Repositories:** Only place for data ops. Should NOT call `db.commit()` (caller's job).

Run these Grep scans:

```
# Services — must have ZERO hits for ALL db operations
grep -rn "db\.execute\|db\.add\|db\.flush\|db\.delete\|db\.refresh\|db\.commit\|db\.rollback" Backend/app/services/ --include="*.py" | grep -v __pycache__

# Routes — must have ZERO hits for data operations (commit/rollback are OK)
grep -rn "db\.execute\|db\.add\|db\.flush\|db\.delete\|db\.refresh" Backend/app/api/ --include="*.py" | grep -v __pycache__

# Worker — must have ZERO hits for data operations (commit/rollback are OK)
grep -rn "db\.execute\|db\.add\|db\.flush\|db\.delete\|db\.refresh" Backend/app/worker/ --include="*.py" | grep -v __pycache__
```

Also check for `select` and `func` imports outside repositories:

```
grep -rn "from sqlalchemy.*import.*\bselect\b\|from sqlalchemy.*import.*\bfunc\b" Backend/app/services/ Backend/app/api/ Backend/app/worker/ --include="*.py" | grep -v __pycache__
```

**Severity: CRITICAL** — any hit is a hard violation.

---

### Step 3 — Backend: Thin routes rule

**Rule:** API routes must NOT contain business logic. They authenticate,
validate input, call a service (or simple repo CRUD), and return a response.

Scan `Backend/app/api/v1/` for suspicious patterns:

```
# Multi-step logic — if/else chains with db calls or complex orchestration
# Commission/fee calculations, notification dispatch, email sending
# Anything beyond: parse → service call → return
```

Use Grep to look for:
- `commission` or `fee` calculations in route files
- `send_email` or `send_push` calls directly in routes (should be in services)
- More than 2 `await` calls to different services/repos in a single route
  handler (suggests business logic leaking into the route)

**Severity: WARNING** — flag for review.

---

### Step 4 — Frontend: Repository rule (CRITICAL)

**Rule:** ALL `dio.get()`, `dio.post()`, `dio.put()`, `dio.patch()`,
`dio.delete()` calls must live in `FrontEnd/lib/repositories/`. Never in
providers, screens, services, or widgets.

Exceptions:
- `FrontEnd/lib/services/sync_service.dart` — owns its own Dio instance for
  offline sync (private `_fetch*` / `_post*` methods are intentional).
- `FrontEnd/lib/services/chat_socket_service.dart` — WebSocket/SSE transport.

```
grep -rn "dio\.\(get\|post\|put\|patch\|delete\)" FrontEnd/lib/ --include="*.dart" | grep -v "/repositories/" | grep -v "sync_service.dart" | grep -v "chat_socket_service.dart"
```

**Severity: CRITICAL** — any hit outside allowed files is a violation.

---

### Step 5 — Frontend: Provider/state rule

**Rule:** Screens must NOT hold API-fetched state in local `setState()`.
They read from providers via `context.watch` / `context.read`.

Scan `FrontEnd/lib/screens/` for:

```
# Direct repo usage from screens (should go through providers)
grep -rn "context\.read<.*Repository>" FrontEnd/lib/screens/ --include="*.dart"
```

Known exceptions (simple receipt/detail screens that fetch once and display):
- `pledge_receipt_screen.dart` — fetches a single receipt, displays it
- `ticket_receipt_screen.dart` — same pattern
- Screens using `FundingRepository` or `TicketRepository` directly for
  one-shot fetches are acceptable IF they don't manage list/pagination state.

Flag any screen that:
- Creates a `List<T>` field and populates it from a repository call
- Has pagination logic (`offset`, `hasMore`, `loadMore`)
- Calls repository methods in `initState` and stores results in `setState`

**Severity: WARNING** for one-shot fetches, **CRITICAL** for list/pagination state.

---

### Step 6 — Frontend: No raw Maps from repositories

**Rule:** Repositories must return typed models, not `Map<String, dynamic>`.

```
grep -rn "Future<Map<String, dynamic>>" FrontEnd/lib/repositories/ --include="*.dart"
```

Known exceptions:
- `payment_repository.dart` — Stripe responses are pass-through Maps
  (schema owned by Stripe, not our domain models)
- `funding_repository.dart` — receipt endpoints return Maps (legacy, acceptable)

**Severity: WARNING** — flag new occurrences for typing.

---

### Step 7 — Report

Output a structured report:

```
## Architecture Scan Report

### CRITICAL Violations
(list each with file:line, the offending code, and which rule it breaks)

### Warnings
(list each with file:line, the offending code, and the recommendation)

### Summary
- Backend services: X violations
- Backend routes: X violations
- Backend worker: X violations
- Frontend repos: X violations
- Frontend screens: X violations
- Total: X critical, Y warnings

### Status: PASS / FAIL
(FAIL if any CRITICAL violations exist)
```

If `$ARGUMENTS` is a specific file, also include:
- What layer the file belongs to
- What it should/shouldn't import
- Specific fix suggestions for each violation

---

## Important Notes

- Do NOT auto-fix violations. Report them and let the user decide.
- When scanning a specific file, also check its imports to catch indirect violations.
- Ignore test files (`test/`, `tests/`) — they may legitimately use DB or Dio directly.
- Ignore migration files (`alembic/`, `migrations/`).
- Count each unique file:line as one violation (not each pattern match).
