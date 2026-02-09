# Crowd-Funded Event API (FastAPI)

Backend for the crowd-funded event app: Admin, Event Organizer, and Customer views; live events on map; open/closed events with capacity; Firebase Auth; funding with minimum pledge; tickets and discounts.

**Key features:** Organizers collect pledges until the funding deadline; they can cancel an event anytime or, after the deadline, extend the funding period and/or set the event date. Customers register (open = first-come, closed = approval); they can unregister and get pledges refunded only if more than 7 days before the funding deadline. Events can sell tickets to registered attendees, with organizer-defined tiers (e.g. Platinum, Diamond), common and pledge-based discounts, and selective per-user discounts; if discount exceeds ticket price, extra perks can be set on the ticket. Event listings include **funding progress** (`total_pledged_cents` and `funding_days_left`).

## Stack

- **FastAPI** — REST API with lifespan events and pure ASGI middleware
- **PostgreSQL** — via SQLAlchemy 2.0 (async) + asyncpg
- **Firebase Auth** — verify ID tokens; user/role stored in PostgreSQL
- **Pydantic V2** — request/response schemas with `SettingsConfigDict`

## Folder structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app, lifespan, ASGI logging middleware, CORS, router mount
│   ├── config.py            # Settings (Pydantic V2 SettingsConfigDict)
│   ├── dependencies.py      # get_db_session, get_current_user, require_role
│   ├── api/
│   │   └── v1/
│   │       ├── router.py    # Aggregates all v1 routes (map_ before events to avoid path conflict)
│   │       ├── auth.py      # POST /auth/verify
│   │       ├── users.py     # GET/PATCH /me, GET /me/pledges, GET /me/tickets
│   │       ├── events.py    # CRUD, pledge, register, unregister, cancel, extend-funding, ticket-tiers, tickets, scanned-tickets
│   │       ├── venues.py    # CRUD venues
│   │       ├── map_.py      # GET /events/map
│   │       └── admin.py     # Approve events, stats
│   ├── core/
│   │   ├── security.py      # Firebase token verify, get_current_user
│   │   ├── firebase.py      # Firebase init and verify_id_token
│   │   └── exceptions.py    # Custom HTTP exceptions
│   ├── db/
│   │   └── base.py          # Engine, session, init_db
│   ├── models/              # SQLAlchemy models
│   │   ├── user.py
│   │   ├── venue.py
│   │   ├── event.py
│   │   ├── funding.py
│   │   ├── registration.py
│   │   └── ticket.py        # TicketTier, TicketSale, UserEventDiscount
│   ├── schemas/             # Pydantic request/response schemas (API imports from here)
│   │   ├── event.py         # EventCreate, EventUpdate, EventResponse (+ funding progress), MapEventMarker
│   │   ├── user.py          # MeResponse, MeUpdate, VerifyBody, VerifyResponse
│   │   ├── venue.py         # VenueCreate, VenueUpdate, VenueResponse
│   │   ├── funding.py       # PledgeBody, PledgeResponse, FundingSummaryResponse, MyPledgeItem
│   │   ├── registration.py  # RegistrationResponse, RegistrationDecisionBody
│   │   ├── ticket.py        # TicketTierCreate/Update/Response, TicketSaleResponse, UserDiscountBody
│   │   └── admin.py         # ApproveBody, AdminEventItem, AdminStats
│   ├── services/            # Business logic (event, funding, registration, ticket, venue, auth, admin)
│   └── utils/
├── tests/                   # 89 tests (pytest-asyncio, session-scoped event loop)
│   ├── conftest.py          # Fixtures: mock auth, test users/venue/event, DB cleanup
│   ├── test_health.py
│   ├── test_auth.py
│   ├── test_users.py
│   ├── test_venues.py
│   ├── test_events.py
│   ├── test_tickets.py
│   ├── test_map.py
│   └── test_admin.py
├── pytest.ini               # asyncio session loop, warning filters
├── requirements.txt
├── .env.example
└── README.md
```

## Setup

1. **Python 3.12+**, virtualenv recommended.

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Environment:** copy `.env.example` to `.env` and set:
   - `DATABASE_URL` — PostgreSQL connection (use `postgresql+asyncpg://...`)
   - `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` for Firebase token verification

4. **Database:** you need a PostgreSQL database. One option is to run it with Docker:

   **Running PostgreSQL with Docker**

   ```bash
   docker run -d --name my-postgres -e POSTGRES_PASSWORD=yourpassword -e POSTGRES_USER=user -e POSTGRES_DB=event_db -p 5432:5432 postgres:16
   ```

   | Flag | Purpose |
   |------|--------|
   | `--name my-postgres` | Gives the container a friendly name. |
   | `-e POSTGRES_PASSWORD=...` | Sets the default postgres user password. |
   | `-e POSTGRES_USER=...` | Optional: custom user (default is `postgres`). |
   | `-e POSTGRES_DB=...` | Creates this database on first run. |
   | `-p 5432:5432` | Maps the container port to your localhost so you can connect from the app. |
   | `-d` | Runs the container in the background (detached mode). |

   Then set in `.env`: `DATABASE_URL=postgresql+asyncpg://user:yourpassword@localhost:5432/event_db`

   After the database is running, either:
   - **Alembic (recommended):** `alembic upgrade head`
   - **One-off:** `python -c "import asyncio; from app.db.base import init_db; asyncio.run(init_db())"`

5. **Run:**
   ```bash
   uvicorn app.main:app --reload
   ```
   API: `http://localhost:8000`. Docs: `http://localhost:8000/api/v1/docs`.

## Running in WSL

1. **Open your project in WSL** (e.g. from Windows path `C:\Users\16136\Desktop\Crowd_Funding_Event`):
   ```bash
   cd /mnt/c/Users/16136/Desktop/Crowd_Funding_Event/Backend
   ```

2. **Use Linux-style paths in `.env`.** `.env.example` already uses a WSL path for the Firebase key:
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=/mnt/c/Users/16136/Desktop/Crowd_Funding_Event/cred/crowd-funding-event-firebase-adminsdk-fbsvc-21d60f7baf.json
   ```
   Copy `.env.example` to `.env` in WSL and keep or adjust that path.

3. **PostgreSQL in WSL:** either install Postgres inside WSL (`sudo apt install postgresql postgresql-contrib`) or run it in Docker from WSL. Then set `DATABASE_URL` in `.env` to `postgresql+asyncpg://user:password@localhost:5432/event_db`.

4. **Create a venv and run:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   cp .env.example .env   # if you don't have .env yet
   alembic upgrade head
   uvicorn app.main:app --reload
   ```
   API: `http://localhost:8000`. From Windows browser use the same URL (WSL2 forwards localhost).

## API prefix

All v1 routes are under **`/api/v1`**:

**Auth & profile**
- `POST /api/v1/auth/verify` — verify Firebase token, upsert user
- `GET /api/v1/me`, `PATCH /api/v1/me` — current user (Bearer required)
- `GET /api/v1/me/pledges` — current user's pledges (customer only)
- `GET /api/v1/me/tickets` — current user's purchased tickets (customer only)

**Events**
- `GET /api/v1/events` — list with search and filters: `search` (title/description), `city`, `status`, `live`, `registration_type`, `organizer_id`, `date_from` / `date_to` (ISO date or datetime), `has_funding`, `has_tickets`, `min_capacity`, `max_capacity`. Response includes **funding progress**: `total_pledged_cents` and `funding_days_left` (null when no funding goal).
- `POST /api/v1/events`, `GET/PATCH/DELETE /api/v1/events/{id}`
- `GET /api/v1/events/{id}/calendar.ics` — add to calendar: returns iCalendar (.ics) file (public)
- `POST /api/v1/events/{id}/submit` — submit draft for approval
- `POST /api/v1/events/{id}/cancel` — cancel event (organizer/admin, anytime)
- `POST /api/v1/events/{id}/extend-funding` — after deadline: extend funding period and/or set event date (body: `funding_end_at`, `start_time`, `end_time`; at least one)
- `GET /api/v1/events/{id}/organizers` — list main + co-organizers
- `POST /api/v1/events/{id}/organizers` — add co-organizer (main organizer only); body `{ "user_id": int }`
- `DELETE /api/v1/events/{id}/organizers/{user_id}` — remove co-organizer (main organizer only)
- `POST /api/v1/events/{id}/pledge`, `GET /api/v1/events/{id}/funding`
- `POST /api/v1/events/{id}/register`, `POST /api/v1/events/{id}/unregister` — unregister refunds pledges only if >7 days before funding deadline
- `GET /api/v1/events/{id}/registrations`, `POST /api/v1/events/{id}/registrations/{id}/decision` — list/approve/reject (organizer/admin)
- `GET /api/v1/events/map` — map markers (city, lat/lng, live)

**Tickets** (events can sell tickets to registered attendees)
- `GET /api/v1/events/{id}/ticket-tiers` — list ticket tiers (public)
- `POST /api/v1/events/{id}/ticket-tiers`, `PATCH /api/v1/events/{id}/ticket-tiers/{tier_id}`, `DELETE /api/v1/events/{id}/ticket-tiers/{tier_id}` — manage ticket tiers (organizer/admin)
- `GET /api/v1/events/{id}/ticket-price?ticket_tier_id=` — preview price with discounts (customer)
- `POST /api/v1/events/{id}/purchase-ticket` — purchase ticket (customer, must be registered); response includes `ticket_code` for QR
- `POST /api/v1/events/{id}/scan-ticket` — scan ticket by QR code (organizer/admin); body `{ "ticket_code": "..." }`; returns `already_scanned` and ticket (scanned tickets show as already scanned)
- `GET /api/v1/events/{id}/ticket-sales` — list all ticket sales for event with `scanned_at` / `scanned_by` (organizer/admin)
- `GET /api/v1/events/{id}/scanned-tickets` — list only scanned tickets for event (organizer/admin)
- `POST /api/v1/events/{id}/discounts`, `DELETE /api/v1/events/{id}/discounts/{user_id}` — set/remove selective user discount (organizer/admin)

**Venues & admin**
- `GET/POST/PATCH/DELETE /api/v1/venues` — venues (organizer: own only; admin: any)
- `GET /api/v1/admin/users` — list all users (admin)
- `GET /api/v1/admin/events`, `POST /api/v1/admin/events/{id}/approve`, `GET /api/v1/admin/stats`

**Multiple organizers:** The **main organizer** (event owner) can add **co-organizers** via `POST /events/{id}/organizers`; only users with organizer role can be added. Co-organizers have the same event management rights as the main organizer (update, cancel, extend, registrations, tickets, scan). Only the main organizer can add or remove co-organizers.

**Roles (who can do what):** Organizers can create/update/delete/cancel events, extend funding, manage registrations and ticket tiers/discounts, but **cannot** pledge or register. Only **customers** can pledge, register, unregister, and purchase tickets. See **Role-based access** in `BACKEND_FLOW.md` for the full matrix.

- **Backend flow:** See `BACKEND_FLOW.md` in this folder for how requests, auth, and DB flow work.
- **Full design:** See `docs/ARCHITECTURE.md` for full design.

## Architecture notes

- **Middleware:** Request logging uses a **pure ASGI middleware** (`LogRequestsMiddleware`) instead of Starlette's `BaseHTTPMiddleware`. This avoids a known issue where `BaseHTTPMiddleware` spawns tasks on a different event loop, causing `asyncpg` errors like "attached to a different loop."
- **Lifespan:** App startup/shutdown logic uses FastAPI's `lifespan` async context manager (the deprecated `@app.on_event` decorator is not used).
- **Config:** Uses Pydantic V2 `SettingsConfigDict` (not the deprecated inner `class Config`).
- **Router order:** `map_.router` is registered **before** `events.router` (both at `/events` prefix) so that `/events/map` matches the literal route before `/{event_id}` tries to parse "map" as an integer.
- **Funding progress:** `EventResponse` includes `total_pledged_cents` and `funding_days_left`. The list endpoint uses a batch query (`get_pledged_totals_for_events`) to avoid N+1 problems.

## Tests

**89 tests**, all passing. Async tests use a **session-scoped event loop** so all tests and the DB engine share a single loop.

```bash
cd Backend
pip install -r requirements.txt
# With PostgreSQL running and migrations applied (alembic upgrade head):
pytest
# Verbose:
pytest -v
# Run only tests that don't need DB (health, OpenAPI):
SKIP_DB_TESTS=1 pytest
# Show all warnings (third-party deprecation warnings are filtered by default in pytest.ini):
pytest -v -W all
```

**Test suite coverage (89 tests across 8 files):**

| File | Covers |
|------|--------|
| `test_health.py` | `/health`, `/api/v1/health` (no DB) |
| `test_auth.py` | `POST /auth/verify` (missing token, invalid token) |
| `test_users.py` | `GET/PATCH /me`, `GET /me/pledges`, `GET /me/tickets` (auth, role checks, empty body) |
| `test_venues.py` | List, create, get, update, delete venues (public, organizer auth, 404) |
| `test_events.py` | List, get, create, patch, calendar.ics, submit, cancel, delete, extend-funding, funding, pledge, register, unregister, registrations, registration decision, co-organizers (list, add, remove) |
| `test_tickets.py` | Ticket-tiers CRUD, ticket-price preview, purchase-ticket (auth, role, registered, success), scan-ticket (success, already scanned, invalid code), ticket-sales, scanned-tickets, discounts (set, remove) |
| `test_map.py` | `GET /events/map` (public, city filter, live filter) |
| `test_admin.py` | List users/events, approve/reject event, stats (401 without auth, 403 as organizer, admin-only) |

**How tests work:**

- **DB isolation:** Tables are truncated after each test via an `autouse` fixture. The engine pool is disposed at session start so connections are created on the test event loop.
- **Mock auth:** `verify_firebase_token` is overridden so tests use `Authorization: Bearer test-admin`, `test-organizer`, `test-organizer2`, or `test-customer` without real Firebase.
- **Fixtures:** `test_users` creates admin/organizer/customer users; `test_venue`, `test_event`, `test_event_approved`, `test_ticket_tier` build on top with committed data.
- **Warning filters:** `pytest.ini` suppresses `DeprecationWarning` from third-party packages (sqlalchemy, google, asyncpg) so test output stays clean.

## Migrations (Alembic)

- Create a new migration after model changes: `alembic revision --autogenerate -m "description"`.
- Apply migrations: `alembic upgrade head` (run from the **Backend** directory with venv activated).
- `alembic.ini` is preconfigured; the app's `DATABASE_URL` from `.env` is used automatically.
- Migrations include: initial schema, venue `organizer_id`, event `min_pledge_cents`, and tickets/discounts (`ticket_tiers`, `ticket_sales`, `user_event_discounts`, event `common_discount_percent` / `pledge_discount_percent`).
