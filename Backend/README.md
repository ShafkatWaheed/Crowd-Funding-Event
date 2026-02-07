# Crowd-Funded Event API (FastAPI)

Backend for the crowd-funded event app: Admin, Event Organizer, and Customer views; live events on map; open/closed events with capacity; Firebase Auth.

## Stack

- **FastAPI** — REST API
- **PostgreSQL** — via SQLAlchemy (async) + asyncpg
- **Firebase Auth** — verify ID tokens; user/role stored in PostgreSQL

## Folder structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI app, CORS, router mount
│   ├── config.py            # Settings (env)
│   ├── dependencies.py      # get_db_session, get_current_user, require_role
│   ├── api/
│   │   └── v1/
│   │       ├── router.py    # Aggregates all v1 routes
│   │       ├── auth.py      # POST /auth/verify
│   │       ├── users.py     # GET/PATCH /me
│   │       ├── events.py    # CRUD, pledge, register, registrations
│   │       ├── venues.py    # CRUD venues
│   │       ├── map_.py      # GET /events/map
│   │       └── admin.py     # Approve events, stats
│   ├── core/
│   │   ├── security.py      # Firebase token verify, get_current_user
│   │   └── exceptions.py    # Custom HTTP exceptions
│   ├── db/
│   │   └── base.py          # Engine, session, init_db
│   ├── models/              # SQLAlchemy models
│   │   ├── user.py
│   │   ├── venue.py
│   │   ├── event.py
│   │   ├── funding.py
│   │   └── registration.py
│   ├── schemas/             # Pydantic request/response schemas (API imports from here)
│   │   ├── event.py         # EventCreate, EventUpdate, EventResponse, MapEventMarker
│   │   ├── user.py          # MeResponse, MeUpdate, VerifyBody, VerifyResponse
│   │   ├── venue.py         # VenueCreate, VenueUpdate, VenueResponse
│   │   ├── funding.py       # PledgeBody, PledgeResponse, FundingSummaryResponse
│   │   ├── registration.py  # RegistrationResponse, RegistrationDecisionBody
│   │   └── admin.py         # ApproveBody, AdminEventItem, AdminStats
│   ├── services/            # Business logic
│   └── utils/
├── tests/
├── requirements.txt
├── .env.example
└── README.md
```

## Setup

1. **Python 3.11+**, virtualenv recommended.

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Environment:** copy `.env.example` to `.env` and set:
   - `DATABASE_URL` — PostgreSQL connection (use `postgresql+asyncpg://...`)
   - `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` for Firebase token verification

4. **Database:** create the PostgreSQL database, then either:
   - **Alembic (recommended):** `alembic upgrade head`
   - **One-off:** `python -c "import asyncio; from app.db.base import init_db; asyncio.run(init_db())"`

5. **Run:**
   ```bash
   uvicorn app.main:app --reload
   ```
   API: `http://localhost:8000`. Docs: `http://localhost:8000/api/v1/docs`.

## API prefix

All v1 routes are under **`/api/v1`**:

- `POST /api/v1/auth/verify` — verify Firebase token, upsert user
- `GET /api/v1/me`, `PATCH /api/v1/me` — current user (Bearer required)
- `GET/POST /api/v1/events`, `GET/PATCH/DELETE /api/v1/events/{id}`
- `POST /api/v1/events/{id}/pledge`, `GET /api/v1/events/{id}/funding`
- `POST /api/v1/events/{id}/register`, `GET /api/v1/events/{id}/registrations`
- `GET /api/v1/events/map` — map markers (city, lat/lng, live)
- `GET/POST/PATCH /api/v1/venues`
- `GET /api/v1/admin/users` — list all users (admin)
- `GET /api/v1/admin/events`, `POST /api/v1/admin/events/{id}/approve`, `GET /api/v1/admin/stats`
- `POST /api/v1/events/{id}/submit` — submit draft event for approval (draft → pending_approval)

- **Backend flow:** See `BACKEND_FLOW.md` in this folder for how requests, auth, and DB flow work.
- **Full design:** See `docs/ARCHITECTURE.md` for full design.

## Tests

```bash
pip install -r requirements.txt
pytest
```

- `test_health` and `test_openapi_json` need no DB.
- `test_list_events_*` needs a running PostgreSQL (same `DATABASE_URL`). Skip DB tests: `SKIP_DB_TESTS=1 pytest`.

## Migrations (Alembic)

- Create a new migration after model changes: `alembic revision --autogenerate -m "description"`.
- Apply migrations: `alembic upgrade head`.
- `alembic.ini` is preconfigured; the app’s `DATABASE_URL` from `.env` is used automatically.
