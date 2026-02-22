# Crowd-Funded Event App — Architecture

**Stack:** Flutter Web | FastAPI (async) | PostgreSQL | Redis | Firebase Auth | ARQ  
**Roles:** Admin, Organizer, Customer, Sponsor

---

## 1. High-Level System Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         CLIENT (Flutter Web)                                 │
│                                                                              │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐  ┌──────────┐                  │
│  │  Admin   │  │ Organizer  │  │ Customer │  │ Sponsor  │                  │
│  │  View    │  │   View     │  │   View   │  │   View   │                  │
│  └────┬─────┘  └─────┬──────┘  └────┬─────┘  └────┬─────┘                  │
│       └───────────────┼──────────────┼──────────────┘                        │
│                       │              │                                        │
│               ┌───────▼──────────────▼───────┐                               │
│               │     Firebase Auth SDK        │                               │
│               │     (ID token generation)    │                               │
│               └──────────────┬───────────────┘                               │
└──────────────────────────────┼───────────────────────────────────────────────┘
                               │
                               │  HTTPS / REST (Bearer token)
                               ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                        BACKEND (FastAPI — async)                             │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │                     API Layer (14 routers)                           │    │
│  │  auth · events · funding · tickets · registration · sponsors        │    │
│  │  milestones · schedule · venues · admin · notifications · ratings   │    │
│  │  discount-strategies · ticket-strategies · public-profiles · map    │    │
│  └──────────────────────────────┬───────────────────────────────────────┘    │
│                                 │                                            │
│  ┌──────────────┐  ┌───────────▼──────────┐  ┌──────────────────────┐       │
│  │  Middleware   │  │   Service Layer      │  │   Background Tasks   │       │
│  │  ─────────── │  │   (21 services)      │  │   (ARQ + Redis)      │       │
│  │  Rate Limit  │  │   event, funding,    │  │   ──────────────     │       │
│  │  (slowapi)   │  │   ticket, sponsor,   │  │   13 tasks:          │       │
│  │  Request Log │  │   escrow, email,     │  │   • 8 email tasks    │       │
│  │  CORS        │  │   notification ...   │  │   • 5 refund tasks   │       │
│  └──────────────┘  └───────────┬──────────┘  └──────────┬───────────┘       │
│                                │                        │                    │
│                     ┌──────────▼──────────┐    ┌────────▼─────────┐          │
│                     │   SQLAlchemy ORM    │    │   Redis (ARQ)    │          │
│                     │   (async, pooled)   │    │   Task queue +   │          │
│                     │   40 models         │    │   future cache   │          │
│                     └──────────┬──────────┘    └──────────────────┘          │
│                                │                                             │
│  ┌─────────────┐  ┌───────────▼──────────┐  ┌───────────────────┐           │
│  │  Advisory   │  │  Connection Pool     │  │  Health Probes    │           │
│  │  Locks      │  │  pool_size=10        │  │  /healthz (live)  │           │
│  │  (per-event │  │  max_overflow=20     │  │  /health (ready)  │           │
│  │  capacity)  │  │  pool_recycle=1800   │  │  (checks DB)      │           │
│  └─────────────┘  └───────────┬──────────┘  └───────────────────┘           │
└────────────────────────────────┼─────────────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                          PostgreSQL                                          │
│  40 tables: users, events, venues, fundings, registrations, ticket_sales,   │
│  ticket_tiers, sponsor_bids, sponsor_payments, escrows, milestones,         │
│  notifications, ratings, bookmarks, schedules, discount_strategies ...       │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Four Roles

| Role | Purpose | Key capabilities |
|------|---------|-----------------|
| **Admin** | Platform oversight | Approve/reject events, manage settings, escrow control, view all users, feature flags |
| **Organizer** | Create and run events | Event CRUD, ticket tiers, discounts, milestones, schedule, co-organizers, scan tickets, manage waitlist/refunds |
| **Customer** | Discover, fund, attend | Browse/search/map, pledge, reserve spots, buy tickets, request refunds, rate, bookmark |
| **Sponsor** | Fund events for visibility | Create profile, browse categories, place bids, pay, get sponsor tickets |

---

## 3. Backend Architecture

### 3.1 Directory Structure

```
Backend/
├── app/
│   ├── api/v1/              # 14 route modules
│   │   ├── auth.py          # Firebase token verify (rate limited: 10/min)
│   │   ├── events.py        # Event CRUD, lifecycle, tickets, pledges, refunds
│   │   ├── sponsors.py      # Sponsor marketplace (categories, bids, payments)
│   │   ├── admin.py         # Admin dashboard, approvals, settings
│   │   ├── milestones.py    # Funding milestones (feature-flagged)
│   │   ├── schedule.py      # Event schedule/agenda (feature-flagged)
│   │   └── ...              # venues, ratings, notifications, etc.
│   ├── models/              # 19 files, 40 SQLAlchemy models
│   ├── schemas/             # Pydantic request/response models
│   ├── services/            # 21 service modules (business logic)
│   ├── worker/              # ARQ background task system
│   │   ├── tasks.py         # 13 tasks (8 email + 5 refund)
│   │   ├── main.py          # WorkerSettings (entry point for arq CLI)
│   │   └── redis_pool.py    # Shared pool + enqueue() helper
│   ├── db/base.py           # Async engine + session (pooled)
│   ├── config.py            # Pydantic Settings from .env
│   ├── rate_limit.py        # slowapi config (user-id/IP key)
│   ├── dependencies.py      # DbSession, CurrentUser, require_role, require_feature
│   └── main.py              # FastAPI app, lifespan, middleware
├── alembic/                 # Database migrations
├── requirements.txt         # 19 dependencies
└── static/uploads/          # Local file storage (→ S3 in production)
```

### 3.2 Key Dependencies

| Category | Packages |
|----------|----------|
| Framework | `fastapi`, `uvicorn`, `pydantic`, `pydantic-settings` |
| Database | `sqlalchemy[asyncio]`, `asyncpg`, `alembic` |
| Auth | `firebase-admin` |
| Background tasks | `arq`, `redis[hiredis]` |
| Rate limiting | `slowapi` |
| Email | `sendgrid` |
| Security | `cryptography` (AES-256-GCM for ticket QR) |
| Export | `openpyxl` (Excel schedule export) |
| Upload | `python-multipart`, `aiofiles` |

### 3.3 Concurrency & Safety

- **Advisory locks**: `pg_advisory_xact_lock(event_id)` on `purchase_ticket()` and `create_pledge()` — serializes capacity-sensitive operations per-event; two purchases for different events run in parallel
- **Connection pooling**: `pool_size=10`, `max_overflow=20`, `pool_recycle=1800` — prevents connection exhaustion under load
- **Rate limiting**: Global 120/min, auth 10/min, purchase 15/min, pledge/register 20/min — user-id preferred, falls back to IP

### 3.4 Background Task System (ARQ + Redis)

```
API Request                          ARQ Worker (separate process)
───────────                          ────────────────────────────
1. Handle request                    4. Pick up job from Redis
2. enqueue("task_name", **kwargs)    5. Execute task (email/refund)
3. Return response immediately       6. Retry up to 3x on failure
                                     7. Log result
```

**13 registered tasks:**

| Type | Tasks |
|------|-------|
| Email (8) | event cancelled, ticket purchased, waitlist rejected, ticket refund approved, waitlist approved, sponsor bid approved, sponsor bid rejected, sponsor refunded |
| Refund (5) | pledge refund, bulk pledge refunds, ticket refund, sponsor refund, bulk sponsor refunds |

**Graceful degradation**: If Redis is unavailable, the app starts normally — emails are silently skipped, refunds complete inline (synchronous fallback).

---

## 4. Frontend Architecture (Flutter Web)

```
FrontEnd/
├── lib/
│   ├── config/
│   │   ├── router.dart          # GoRouter with role-based routes
│   │   └── theme.dart           # AppTheme (light + dark palettes)
│   ├── models/                  # Dart data classes (Event, User, Ticket, etc.)
│   ├── providers/               # State management (ThemeProvider, NotificationProvider)
│   ├── services/
│   │   └── api_service.dart     # HTTP client (all backend calls)
│   ├── screens/
│   │   ├── auth/                # Login, register, terms
│   │   ├── event/               # Create wizard, detail, management
│   │   ├── profile/             # My tickets, bookmarks, settings
│   │   ├── admin/               # Dashboard, approvals, escrow
│   │   ├── sponsor/             # Dashboard, bids, payments
│   │   └── manage/              # Waitlist, sales, discounts
│   └── widgets/                 # Reusable components
└── pubspec.yaml
```

**Key patterns:**
- **5-step event creation wizard** with `IndexedStack` for state persistence
- **Self-contained widgets** (FundingCard, ReactionBar, EventFeed) — refresh only themselves
- **Dark mode** with context-aware color helpers
- **Mapbox** integration (dark-v11 tiles, geocoding, venue markers)

---

## 5. Database Schema (40 tables)

### Core Domain

```
users ──────────┐
                │
events ─────────┼──── registrations
  │             │
  ├── fundings ─┘──── pledge_spot_reservations
  │
  ├── ticket_tiers ── ticket_sales
  │
  ├── event_discounts
  ├── event_images
  ├── event_posts
  ├── event_schedule_items
  │
  ├── funding_milestones ── milestone_reactions
  │                      ── funding_milestone_snapshots
  │                      ── funding_milestone_users
  │
  ├── early_bird_discounts
  │
  ├── sponsorship_categories ── sponsor_bids ── sponsor_payments
  │                          ── category_prerequisites
  │                                           ── bid_prerequisite_uploads
  │
  ├── fund_escrows ── escrow_releases
  │
  ├── event_organizers (co-organizers)
  ├── event_reactions
  └── bookmarks
```

### Supporting

```
venues
ticket_strategies ── ticket_strategy_tiers
discount_strategies ── event_discount_strategy_links ── customer_discount_claims
sponsor_profiles
sponsor_tickets
organizer_customer_history
notifications
ratings
platform_settings
```

### Key Enum Types

| Enum | Values |
|------|--------|
| `EventStatus` | draft, pending_approval, approved, selling_tickets, waiting_event_date, live, completed, cancelled |
| `FundingStatus` | pledged, collected, refund_processing, refunded, refund_failed |
| `TicketSaleStatus` | purchased, waitlisted, refund_requested, refund_processing, refunded, refund_failed, cancelled |
| `PaymentStatus` | pending, completed, refund_processing, refunded, refund_failed |
| `UserRole` | admin, organizer, customer, sponsor |

---

## 6. Auth Flow

```
Flutter App                    Firebase                    FastAPI Backend
───────────                    ────────                    ──────────────
1. Email/password sign-in  ──► 2. Returns ID token
                                                    ◄──── 3. POST /auth/verify
                                                           { id_token, role? }
                               4. firebase-admin
                                  verifies token    ──────►
                                                           5. Upsert user in DB
                                                              (firebase_uid → user)
                                                    ◄──── 6. Return user_id, role
7. Store token, call APIs
   with Authorization:
   Bearer <idToken>        ──────────────────────────────► 8. Dependency extracts
                                                              user from token on
                                                              every request
```

No passwords stored in PostgreSQL — only `firebase_uid`, email, display_name, role.

---

## 7. Scaling Architecture (Kubernetes)

### Current State (Development)

```
┌──────────┐     ┌──────────────┐     ┌────────────┐     ┌───────────┐
│  Flutter  │────►│  FastAPI     │────►│ PostgreSQL │     │   Redis   │
│  Web      │     │  (uvicorn)   │     │            │     │  (Docker) │
└──────────┘     │              │     └────────────┘     └─────┬─────┘
                 │  + rate limit │                              │
                 │  + adv. locks │                        ┌─────▼─────┐
                 └──────────────┘                        │ ARQ Worker│
                                                         └───────────┘
```

### Production Target (Kubernetes)

```
                    ┌─────────────────┐
                    │  nginx-ingress   │
                    │  (rate limiting)  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌────────────┐  ┌────────────┐  ┌────────────┐
     │  Read Pods  │  │ Write Pods │  │ Worker Pods │
     │  HPA: 5-15  │  │  HPA: 3-5  │  │  (ARQ)     │
     │             │  │             │  │  2-3 pods   │
     │ GET /events │  │ POST pledge │  │             │
     │ GET /detail │  │ POST ticket │  │ Emails     │
     │ GET /search │  │ POST refund │  │ Refunds    │
     └──────┬──────┘  └──────┬──────┘  └──────┬─────┘
            │                │                │
            ▼                ▼                ▼
     ┌────────────┐  ┌────────────┐  ┌────────────┐
     │ DB Replica  │  │ DB Primary │  │   Redis    │
     │ (read-only) │  │  (writes)  │  │  (queue +  │
     └────────────┘  └────────────┘  │   cache)   │
                                      └────────────┘
```

**Read Pods** (scale aggressively):
- Handle all GET requests (event list, detail, featured, search, map)
- Connect to PostgreSQL read replica
- Redis cache for featured events (TTL 60s) and event detail (TTL 30s)
- Stateless, cheap to scale

**Write Pods** (scale moderately):
- Handle all POST/PATCH/DELETE requests (pledge, ticket purchase, refund, registration, event CRUD)
- Connect to primary DB with advisory locks for per-event serialization
- Rate limited at both ingress and application level

**Worker Pods** (ARQ):
- Process background tasks from Redis queue
- Email sending (11 types), refund processing (5 tasks)
- 3 retries per task, `refund_failed` status for admin investigation

**Routing** (nginx-ingress by HTTP method):
- `GET /api/*` → read-pods service
- `POST|PATCH|PUT|DELETE /api/*` → write-pods service
- `/health`, `/healthz` → both (independent health checks)

### Infrastructure Roadmap

| Priority | Component | Status | Purpose |
|----------|-----------|--------|---------|
| ✅ Done | Advisory locks | Implemented | Per-event capacity serialization |
| ✅ Done | Connection pooling | Implemented | DB connection management |
| ✅ Done | Rate limiting (slowapi) | Implemented | Abuse prevention |
| ✅ Done | Health probes | Implemented | K8s readiness/liveness |
| ✅ Done | ARQ + Redis | Implemented | Background task queue |
| ⏳ Next | Dockerfile | Planned | Multi-stage build for deployment |
| ⏳ Next | K8s manifests | Planned | Deployments, HPA, PDB, Ingress |
| ⏳ Next | S3 storage | Planned | Multi-pod file sharing |
| ⏳ Later | Redis caching | Planned | Read scaling |
| ⏳ Later | Observability | Planned | Prometheus, structured logging |

### Why Not Microservices

- **Tight transactional coupling**: A single ticket purchase touches tickets, funding (reserved spots), escrow, events (capacity), platform settings (commission), and registration — all in one DB transaction
- **Small codebase**: ~7,000 lines across 21 service files. Microservices add value at 50k+ lines with multiple teams
- **Advisory locks solve the bottleneck**: The scaling problem is DB write contention on capacity checks, not service-level scaling
- **Revisit when**: 3+ teams deploying independently, 50k+ users, or a module with 10x different scaling needs

---

## 8. Email System

```
API Endpoint                     Redis (ARQ)                  Email Provider
────────────                     ───────────                  ──────────────
1. Business logic completes
2. arq_enqueue("send_*_email",   3. Job queued    ──────────►
   buyer_email=..., ...)                                      4. ARQ worker picks up
                                                              5. email_notifications.py
                                                                 builds HTML template
                                                              6. email_service.py sends
                                                                 via SendGrid (or console)
```

**11 email types** with Uber-themed HTML templates (inline CSS, mobile-friendly):
- Event cancelled, cancellation + refund, ticket purchased, unpledge refund, unregister refund
- Waitlist rejected, waitlist approved, ticket refund approved
- Sponsor bid approved, sponsor bid rejected, sponsor payment refunded

**Provider-agnostic**: `EmailBackend` ABC with `SendGrid` and `Console` backends. Swap via `EMAIL_PROVIDER` env var.

---

## 9. Refund Processing

```
Customer                    API                         ARQ Worker
────────                    ───                         ──────────
Request refund ──────────► Set refund_requested
                           (ticket only)

Organizer approves ──────► Set refund_processing
                           → Set refunded (inline)      (Future: payment gateway
                           Return response               call goes here, with
                                                         3 retries on failure)

Event cancelled ─────────► Bulk: all pledges,
                           tickets, sponsor payments
                           → refund_processing
                           → refunded (inline)
```

**States**: `refund_processing` → `refunded` | `refund_failed`  
**Ticket-specific**: `refund_requested` (customer asks) → organizer approves/rejects  
**Bulk**: Automatic on event cancellation for all pledges, tickets, and sponsor payments

---

## 10. Development Setup

| Component | Command | Port |
|-----------|---------|------|
| PostgreSQL | Docker or system install | 5432 |
| Redis | `sudo docker run -d --name redis -p 6379:6379 --restart unless-stopped redis:7-alpine` | 6379 |
| Backend | `cd Backend && source venv/bin/activate && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000` | 8000 |
| ARQ Worker | `cd Backend && source venv/bin/activate && arq app.worker.main.WorkerSettings` | — |
| Frontend | `cd FrontEnd && flutter run -d web-server --web-port=8080` | 8080 |
| Migrations | `cd Backend && source venv/bin/activate && alembic upgrade head` | — |

**Config**: All settings via `Backend/.env` — `DATABASE_URL`, `REDIS_URL`, `FIREBASE_PROJECT_ID`, `EMAIL_PROVIDER`, `TICKET_ENCRYPTION_KEY`

**Without Redis**: App works — emails silently skipped, refunds complete inline. Redis required for background email delivery and future payment gateway integration.
