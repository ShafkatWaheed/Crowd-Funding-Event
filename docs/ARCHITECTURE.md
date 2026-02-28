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
│  ┌────────────────────┤              │                                        │
│  │ Drift/SQLite       │   ┌─────────▼──────────────┐                        │
│  │ (12 tables,        │   │  Firebase Auth SDK     │                        │
│  │  offline cache)    │   │  (ID token generation) │                        │
│  └────────────────────┘   └─────────┬──────────────┘                        │
└─────────────────────────────────────┼───────────────────────────────────────┘
                                      │
                         HTTPS/REST   │   WebSocket
                        (Bearer token)│   (chat)
                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                        BACKEND (FastAPI — async)                             │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │               API Layer (18 top-level routers)                       │    │
│  │  auth · events/* · sponsors/* · chat (WS) · admin · banking         │    │
│  │  milestones · schedule · venues · notifications · ratings · config  │    │
│  │  discount-strategies · ticket-strategies · public-profiles · map    │    │
│  │  users · webhooks                                                   │    │
│  └──────────────────────────────┬───────────────────────────────────────┘    │
│                                 │                                            │
│  ┌──────────────┐  ┌───────────▼──────────┐  ┌──────────────────────┐       │
│  │  Middleware   │  │   Service Layer      │  │   Background Tasks   │       │
│  │  ─────────── │  │   (32 services)      │  │   (ARQ + Redis)      │       │
│  │  Rate Limit  │  │   event, funding,    │  │   ──────────────     │       │
│  │  (slowapi)   │  │   ticket, sponsor,   │  │   • 9 email tasks    │       │
│  │  Request Log │  │   escrow, email,     │  │   • 5 refund tasks   │       │
│  │  CORS        │  │   chat, push, ...    │  │   • 8 cron tasks     │       │
│  └──────────────┘  └───────────┬──────────┘  │   • 2 push notif     │       │
│                                │              │   • 2 bank mock      │       │
│                     ┌──────────▼──────────┐   └──────────┬───────────┘       │
│                     │   SQLAlchemy ORM    │              │                   │
│                     │   (async, pooled)   │   ┌──────────▼───────────┐       │
│                     │   40+ models        │   │   Redis               │       │
│                     └──────────┬──────────┘   │   • ARQ task queue    │       │
│                                │              │   • Server-side cache  │       │
│  ┌─────────────┐  ┌───────────▼──────────┐   │   • Chat Streams      │       │
│  │  Advisory   │  │  Connection Pool     │   │   • Chat Pub/Sub      │       │
│  │  Locks      │  │  pool_size=10        │   └───────────────────────┘       │
│  │  (per-event │  │  max_overflow=20     │  ┌───────────────────┐           │
│  │  capacity)  │  │  pool_recycle=1800   │  │  Health Probes    │           │
│  └─────────────┘  └───────────┬──────────┘  │  /healthz (live)  │           │
│                                │             │  /health (ready)  │           │
└────────────────────────────────┼─────────────└───────────────────┘───────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                          PostgreSQL                                          │
│  40+ tables: users, events, venues, fundings, registrations, ticket_sales,  │
│  ticket_tiers, sponsor_bids (+ chat metadata), sponsor_payments, escrows,   │
│  milestones, notifications, ratings, bookmarks, schedules,                   │
│  organizer_bank_accounts, discount_strategies ...                            │
│                                                                              │
│  Note: Chat messages stored in Redis Streams, NOT PostgreSQL                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Four Roles

| Role | Purpose | Key capabilities |
|------|---------|-----------------|
| **Admin** | Platform oversight | Approve/reject events, manage settings, escrow control, view all users, feature flags |
| **Organizer** | Create and run events | Event CRUD, ticket tiers, discounts, milestones, schedule, co-organizers, scan tickets, manage waitlist/refunds, chat with sponsors |
| **Customer** | Discover, fund, attend | Browse/search/map, pledge, reserve spots, buy tickets, request refunds, rate, bookmark, offline ticket QR |
| **Sponsor** | Fund events for visibility | Create profile, browse categories, place bids, negotiate via real-time chat, pay, get sponsor tickets, offline ticket QR + delegates |

---

## 3. Backend Architecture

### 3.1 Directory Structure

```
Backend/
├── app/
│   ├── api/v1/                    # 18 top-level route modules
│   │   ├── auth.py                # Firebase token verify (rate limited: 10/min)
│   │   ├── events/                # Event subpackage (11 modules)
│   │   │   ├── crud.py            #   Create, read, update, delete
│   │   │   ├── lifecycle.py       #   Status transitions, cancellation
│   │   │   ├── tickets.py         #   Purchase, scan, refund
│   │   │   ├── pledge.py          #   Pledge, unpledge, collect
│   │   │   ├── registration.py    #   Register, waitlist
│   │   │   ├── images.py          #   Event image upload
│   │   │   ├── posts.py           #   Event posts/updates
│   │   │   ├── reactions.py       #   Reactions (likes, etc.)
│   │   │   └── discounts.py       #   Event discount management
│   │   ├── sponsors/              # Sponsor subpackage (10 modules)
│   │   │   ├── profile.py         #   Sponsor profile CRUD
│   │   │   ├── categories.py      #   Sponsorship categories
│   │   │   ├── bids.py            #   Bid placement, approval
│   │   │   ├── payments.py        #   Sponsor payments
│   │   │   ├── tickets.py         #   Sponsor ticket management
│   │   │   ├── delegates.py       #   Delegate add/remove
│   │   │   ├── templates.py       #   Category templates
│   │   │   └── organizer_views.py #   Organizer sponsor management
│   │   ├── chat.py                # WebSocket + REST chat (sponsor ↔ organizer)
│   │   ├── banking.py             # Bank account management (Canadian fields)
│   │   ├── admin.py               # Admin dashboard, approvals, settings
│   │   ├── webhooks.py            # External webhook handlers
│   │   ├── milestones.py          # Funding milestones (feature-flagged)
│   │   ├── schedule.py            # Event schedule/agenda (feature-flagged)
│   │   └── ...                    # venues, ratings, notifications, users, map, config
│   ├── models/                    # 31 files, 40+ SQLAlchemy models
│   ├── schemas/                   # Pydantic request/response models
│   ├── services/                  # 32 service modules (business logic)
│   │   ├── chat_service.py        #   Redis Streams CRUD, Pub/Sub, archive
│   │   ├── push_notification.py   #   FCM push notifications
│   │   ├── payment_gateway.py     #   Payment processing (mock)
│   │   ├── reconciliation.py      #   Ledger reconciliation
│   │   └── ...                    #   event, funding, ticket, sponsor, escrow, email, ...
│   ├── worker/                    # ARQ background task system
│   │   ├── tasks.py               # 32 task functions (see §3.4)
│   │   ├── main.py                # WorkerSettings (entry point for arq CLI)
│   │   └── redis_pool.py          # Shared pool + enqueue() helper
│   ├── db/base.py                 # Async engine + session (pooled, read/write split)
│   ├── config.py                  # Pydantic Settings from .env
│   ├── rate_limit.py              # slowapi config (user-id/IP key)
│   ├── dependencies.py            # DbSession, ReadDbSession, CurrentUser, require_role
│   └── main.py                    # FastAPI app, lifespan, middleware
├── alembic/                       # Database migrations
├── requirements.txt               # Dependencies
└── static/
    ├── uploads/                   # File storage (event images, chat images → S3 in prod)
    └── archives/chat/             # Gzipped chat archives (.json.gz)
```

### 3.2 Key Dependencies

| Category | Packages |
|----------|----------|
| Framework | `fastapi`, `uvicorn`, `pydantic`, `pydantic-settings` |
| Database | `sqlalchemy[asyncio]`, `asyncpg`, `alembic` |
| Auth & Push | `firebase-admin` (token verify + FCM push notifications) |
| Background tasks | `arq`, `redis[hiredis]` |
| Real-time | `websockets` (chat WebSocket), Redis Streams + Pub/Sub |
| Rate limiting | `slowapi` |
| Email | `sendgrid` |
| Security | `cryptography` (AES-256-GCM for ticket QR, bank field encryption) |
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

**32 registered task functions:**

| Type | Tasks |
|------|-------|
| Email (9) | event cancelled, ticket purchased, waitlist rejected, ticket refund approved, waitlist approved, sponsor bid approved, sponsor bid rejected, sponsor refunded, pledge refund |
| Refund (5) | pledge refund, bulk pledge refunds, ticket refund, sponsor refund, bulk sponsor refunds |
| Cron (8) | escrow release, scheduled payouts, daily reconciliation, ticket escrow check, sponsor escrow check, chat archive, chat purge, cleanup old records |
| Push (2) | send push notification, send push notification bulk (FCM) |
| Bank Mock (2) | mock verify bank account, mock auto settle |

**Graceful degradation**: If Redis is unavailable, the app starts normally — emails are silently skipped, refunds complete inline (synchronous fallback).

---

## 4. Frontend Architecture (Flutter Web)

```
FrontEnd/
├── lib/
│   ├── config/
│   │   ├── router.dart              # GoRouter (~40 routes, role-based)
│   │   ├── theme.dart               # AppTheme (light + dark palettes)
│   │   └── design_tokens.dart       # Spacing, radius, elevation tokens
│   ├── db/
│   │   ├── app_database.dart        # Drift schema (12 tables, schema v3)
│   │   └── app_database.g.dart      # Generated Drift code
│   ├── models/                      # 14 Dart data classes
│   │   ├── chat_message.dart        #   ChatMessage, ChatConversation
│   │   ├── sponsor.dart             #   SponsorProfile, SponsorBid, SponsorTicketModel, ...
│   │   └── ...                      #   Event, User, Ticket, Venue, Milestone, etc.
│   ├── providers/                   # State management (ThemeProvider, NotificationProvider)
│   ├── services/
│   │   ├── api_service.dart         # Dio HTTP client (all REST calls)
│   │   ├── sync_service.dart        # Offline sync: pull/push/cache (10 methods)
│   │   ├── chat_socket_service.dart # WebSocket for real-time chat
│   │   ├── location_helper.dart     # Geolocation utilities
│   │   └── mapbox_geocoding_service.dart
│   ├── screens/                     # 16 screen directories
│   │   ├── auth/                    # Login, register, terms
│   │   ├── chat/                    # Conversations list, bid chat (WebSocket)
│   │   ├── event/                   # Create wizard, detail, edit, scan, waitlist
│   │   ├── home/                    # Home + tabs (explore, manage, channel)
│   │   ├── profile/                 # My tickets, bookmarks, settings
│   │   ├── admin/                   # Dashboard, payouts, transactions, escrow
│   │   ├── sponsor/                 # Dashboard, bids, payments, ticket receipts
│   │   ├── manage/                  # Ticket sales, refunds, sponsors, pledges
│   │   └── ...                      # bookmark, notification, pledges, venue, etc.
│   └── widgets/                     # Reusable components
└── pubspec.yaml
```

**Key patterns:**
- **5-step event creation wizard** with `IndexedStack` for state persistence
- **Self-contained widgets** (FundingCard, ReactionBar, EventFeed) — refresh only themselves
- **Dark mode** with context-aware color helpers
- **Mapbox** integration (dark-v11 tiles, geocoding, venue markers)
- **Offline-first** via Drift (SQLite, 12 tables at schema v3) for ticket QR display, event browsing, bookmarks, sponsor tickets, schedules, delegates
- **Real-time chat** via WebSocket with auto-reconnect, typing indicators, delivery/read receipts

---

## 5. Database Schema (40+ tables)

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
  │   sponsor_bids also has: last_message_at, unread_count_organizer,
  │   unread_count_sponsor (chat metadata — messages in Redis, not PG)
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
organizer_bank_accounts        ← Canadian banking (encrypted fields)
organizer_customer_history
device_tokens                  ← FCM push notification tokens
notifications                  ← includes chat_message type
ratings
platform_settings
audit_logs
ledger_entries
```

### Key Enum Types

| Enum | Values |
|------|--------|
| `EventStatus` | draft, pending_approval, approved, selling_tickets, waiting_event_date, live, completed, cancelled |
| `FundingStatus` | pledged, collected, refund_processing, refunded, refund_failed |
| `TicketSaleStatus` | purchased, waitlisted, refund_requested, refund_processing, refunded, refund_failed, cancelled |
| `PaymentStatus` | pending, completed, refund_processing, refunded, refund_failed |
| `NotificationType` | ...includes `chat_message` for offline chat push |
| `BankVerificationStatus` | pending, verified, rejected |
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
| ✅ Done | Redis caching | Implemented | Read scaling (stampede prevention, cascade invalidation, circuit breaker) |
| ✅ Done | Embedded DB (Drift) | Implemented | Offline: ticket QR, events, bookmarks, schedules, sponsor tickets, delegates (12 tables, schema v3) |
| ✅ Done | Real-time chat | Implemented | Sponsor ↔ organizer WebSocket chat (Redis Streams + Pub/Sub) |
| ✅ Done | Push notifications | Implemented | FCM push for offline chat messages |
| ✅ Done | Canadian banking | Implemented | Encrypted bank fields, verification workflow |
| ⏳ Next | Dockerfile | Planned | Multi-stage build for deployment |
| ⏳ Next | K8s manifests | Planned | Deployments, HPA, PDB, Ingress |
| ⏳ Next | S3 storage | Planned | Multi-pod file sharing |
| ⏳ Later | Observability | Planned | Prometheus, structured logging |

### Why Not Microservices

- **Tight transactional coupling**: A single ticket purchase touches tickets, funding (reserved spots), escrow, events (capacity), platform settings (commission), and registration — all in one DB transaction
- **Small codebase**: 32 service files in a single deployable. Microservices add value at 50k+ lines with multiple teams
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

**Without Redis**: App partially works — emails silently skipped, refunds complete inline. Redis is **required** for: background email delivery, real-time chat (Streams + Pub/Sub), server-side response caching, and future payment gateway integration.

---

## 11. Caching Architecture (Two-Tier)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         CLIENT (Flutter)                                     │
│                                                                              │
│  ┌──────────────────┐  ┌───────────────────┐  ┌──────────────────────────┐  │
│  │  Drift / SQLite  │  │  Sync Service      │  │  Connectivity Monitor   │  │
│  │  (12 tables,     │  │  (10 methods)      │  │  (connectivity_plus)    │  │
│  │   schema v3)     │  │                    │  │  online → API           │  │
│  │                  │  │  pull: events,     │  │  offline → local DB     │  │
│  │  cached_events   │  │    my_tickets,     │  │                          │  │
│  │  cached_my_tix   │  │    sponsor_tix,    │  │                          │  │
│  │  cached_sponsor  │  │    bookmarks       │  │                          │  │
│  │  cached_schedule │  │  cache: schedule,  │  │                          │  │
│  │  cached_delegates│  │    transport,      │  │                          │  │
│  │  offline_tickets │  │    delegates       │  │                          │  │
│  │  offline_scans   │  │  push: offline     │  │                          │  │
│  │  cached_bookmarks│  │    scans           │  │                          │  │
│  │  + 4 more ...    │  │                    │  │                          │  │
│  └──────────────────┘  └────────┬───────────┘  └──────────────────────────┘  │
│                                 │                                            │
└─────────────────────────────────┼────────────────────────────────────────────┘
                                  │  HTTPS / REST
                                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                         BACKEND (FastAPI)                                    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                     Redis Cache Layer                                  │  │
│  │                                                                        │  │
│  │  Stampede prevention: PER (Probabilistic Early Recomputation)          │  │
│  │                     + SETNX lock (cold-start serialization)            │  │
│  │  Circuit breaker:    skip Redis after N failures for M seconds         │  │
│  │  Invalidation:       invalidate_event_cascade() on any event mutation  │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─────────────────┐                          ┌────────────────────────┐    │
│  │  Read Pods       │───── cache hit ─────────►│  Redis                 │    │
│  │  GET /events/*   │◄──── cached response ────│                        │    │
│  │                  │                          │  Keys:                 │    │
│  │  cache miss ─────┼──── query ──────────────►│  featured:{bool}       │    │
│  │                  │                          │  event:{id}            │    │
│  └────────┬─────────┘                          │  map:{city}:{genre}... │    │
│           │                                    │  cities                │    │
│           ▼                                    │  admin_dash:{...}      │    │
│  ┌─────────────────┐                          │  dashboard:{...}       │    │
│  │  DB Replica      │                          │  settings:{key}        │    │
│  └─────────────────┘                          └────────────────────────┘    │
│                                                                              │
│  ┌─────────────────┐     invalidate_event_cascade()                         │
│  │  Write Pods      │────► cache_delete event:{id}                          │
│  │  POST/PATCH/DEL  │────► cache_delete_pattern featured:*                  │
│  └─────────────────┘────► cache_delete_pattern map:*                        │
│                      ────► cache_delete cities                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Redis Cache Matrix

| Endpoint | Cache Key | TTL | Beta | Invalidation |
|----------|-----------|-----|------|--------------|
| `GET /events/featured` | `featured:{bool}` | 60s | 2.0 | Event create/update/delete, status change |
| `GET /events/{id}` | `event:{id}` | 30s | 1.0 | Event update/delete |
| `GET /events/cities` | `cities` | 600s | 0.5 | Event create/update/delete (venue change) |
| `GET /events/map` | `map:{city}:{genre}:{status}:{live}` | 45s | 1.5 | Event create/update/delete |
| `GET /admin/dashboard` | `admin_dash:{period}:{genre}:{status}` | 30s | 1.0 | Short TTL (natural expiry) |
| `GET /me/organizer-dashboard` | `dashboard:{user}:{...}` | 15s | 1.0 | Short TTL |
| `GET /config` (settings) | `settings:{key}` | 300s | — | Admin setting change |
| `GET /events` (list/search) | **NOT CACHED** | — | — | Infinite filter combos; use DB replica |
| Ticket availability | **NOT CACHED** | — | — | Must be real-time from primary DB |

### Embedded DB (Drift/SQLite) — 12 Tables, Schema v3

| Local Table | Synced From | Sync Trigger | Offline Use |
|-------------|-------------|-------------|-------------|
| `cached_events` | `GET /events` | App launch + pull-to-refresh | Browse events, local search |
| `cached_venues` | Event data (denormalized) | With event sync | Map lookups |
| `cached_ticket_tiers` | Event detail | On event view | Tier display |
| `cached_my_tickets` | `GET /me/tickets` | App launch | **Customer ticket QR display** |
| `cached_schedule_items` | `GET /events/{id}/schedule` | On schedule view | Event agenda offline |
| `cached_sponsor_tickets` | `GET /me/sponsor-tickets` | App launch | **Sponsor ticket QR display** |
| `cached_sponsor_delegates` | `GET /sponsor-tickets/{id}/delegates` | On delegate view | Delegate list offline |
| `offline_tickets` | `GET /events/{id}/ticket-sales` | Manual "Download for Offline" | QR scan validation at venue |
| `offline_scans` | — (local writes) | Push on connectivity restored | Queued scan records |
| `cached_bookmarks` | `GET /me/bookmarks` | App launch | Offline access to saved events |
| `cached_transport` | Event detail response | On event detail view | Directions at venue |
| `sync_metadata` | — (local) | — | Track last sync cursor/timestamp |

**Schema migrations:** v1 → v2 (added my_tickets, schedule_items) → v3 (added sponsor_tickets, sponsor_delegates)

### Key Design Rules

1. **Never cache ticket availability** — stale capacity = customers see "available" when sold out
2. **Server is source of truth** — embedded DB is a read cache + write queue, never authoritative
3. **Offline scans are idempotent** — `scan_ticket()` returns `already_scanned: true` on duplicates
4. **Circuit breaker** — after 5 consecutive Redis failures, skip Redis for 30s (admin-configurable)
5. **PER beta tuning** — hot paths (featured) use beta=2.0 for aggressive early refresh; long-TTL keys use beta=0.5

### Admin Settings (19 keys)

All cache and chat behavior is controlled via platform settings (admin dashboard):

| Group | Settings |
|-------|----------|
| Cache TTLs | `cache_ttl_cities`, `cache_ttl_genres`, `cache_ttl_map`, `cache_ttl_admin_dashboard` |
| Stampede / PER | `cache_stampede_lock_ttl`, `cache_stampede_retry_ms`, `cache_beta_featured`, `cache_beta_event_detail`, `cache_beta_map`, `cache_beta_dashboard` |
| Circuit Breaker | `cache_circuit_breaker_threshold`, `cache_circuit_breaker_cooldown` |
| Client Offline | `offline_scan_enabled`, `offline_scan_max_queue`, `offline_scan_sync_interval`, `client_event_cache_max_age_hours`, `client_sync_on_launch` |
| Chat | `chat_enabled`, `chat_max_message_length`, `chat_stream_maxlen`, `chat_archive_retention_days` |

---

## 12. Real-Time Chat Architecture

Sponsor ↔ organizer negotiation chat per sponsorship bid. Messages live in Redis (zero PostgreSQL bloat), with real-time delivery via WebSocket + Redis Pub/Sub.

```
Flutter Client                     FastAPI Backend                   Redis
──────────────                     ──────────────                   ─────
WebSocket connect ─────────────► /api/v1/chat/ws/chat?token=JWT
                                   │ verify Firebase token
                                   │ load user from DB
                                   │
join {bid_id}     ─────────────► validate participant
                  ◄───────────── joined {bid_id, is_writable}
                                   │ subscribe Pub/Sub channel
                                   │
send {bid_id,     ─────────────► validate writable + length ──────► XADD chat:bid:{id}
      body,                        │                                 PUBLISH chat:bid:{id}
      client_id}                   │
                  ◄───────────── sent {client_id, message_id}
                                   │
                                   │ Pub/Sub listener ◄──────────── message from other process
                  ◄───────────── new_message {message}
                                   │
ack {message_id}  ─────────────► broadcast delivered ──────────────►
                  ◄───────────── delivered {message_id, by}
                                   │
read {message_id} ─────────────► HSET read cursor ────────────────► chat:read:{bid_id}
                  ◄───────────── read {message_id, by}
                                   │
typing {is_typing}─────────────► broadcast to other participant
```

### WebSocket Protocol

| Client → Server | Fields | Purpose |
|-----------------|--------|---------|
| `join` | `bid_id` | Subscribe to bid channel |
| `leave` | `bid_id` | Unsubscribe |
| `send` | `bid_id, body, client_id` | Send text message (max 2000 chars) |
| `ack` | `bid_id, message_id` | Delivery acknowledgement |
| `read` | `bid_id, message_id` | Mark messages as read |
| `typing` | `bid_id, is_typing` | Typing indicator |
| `pong` | — | Heartbeat response |

| Server → Client | Fields | Purpose |
|-----------------|--------|---------|
| `joined` | `bid_id, is_writable` | Channel joined confirmation |
| `sent` | `client_id, message_id, created_at` | Send confirmation |
| `new_message` | `message{id, bid_id, sender_id, body, msg_type, created_at}` | Incoming message |
| `delivered` | `message_id, by` | Single grey tick → double grey tick |
| `read` | `message_id, bid_id, by` | Double grey tick → blue double tick |
| `typing` | `bid_id, user_id, is_typing` | Typing indicator |
| `ping` | — | Server heartbeat (30s interval) |
| `error` | `detail` | Validation/permission error |

### Message Delivery Status (WhatsApp-style)

| Status | Visual | Trigger |
|--------|--------|---------|
| Sending | spinner | Client sends, awaiting `sent` event |
| Sent | 1 grey tick | Server returns `sent` with message_id |
| Delivered | 2 grey ticks | Recipient device sends `ack` |
| Read | 2 blue ticks | Recipient sends `read` |

### Chat Lifecycle

- **Writable** when: bid status ∈ {pending, accepted, paid} AND event status ∈ {approved, selling_tickets, waiting_event_date, live}
- **Read-only** when: bid is rejected/withdrawn OR event is completed/cancelled
- **Offline delivery**: If recipient has no active WebSocket → FCM push notification via existing notification pipeline

### Storage & Retention

```
Active Chat (Redis Streams: chat:bid:{id})
    max 500 messages per bid (MAXLEN trim)
    │
    ▼  event completed/cancelled + 30 days
Archive (static/archives/chat/bid_{id}_{date}.json.gz)
    │
    ▼  30 days after archival
Purged (permanent deletion)
```

**No chat message content is stored in PostgreSQL.** Only metadata on `sponsor_bids`: `last_message_at`, `unread_count_organizer`, `unread_count_sponsor`.

### REST Fallback Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/chat/bids/{bid_id}/messages` | Paginated history (cursor-based via Redis Stream IDs) |
| GET | `/chat/conversations` | List conversations with unread counts |
| POST | `/chat/bids/{bid_id}/upload` | Image upload (saved to `static/uploads/chat/`) |
| POST | `/chat/bids/{bid_id}/read` | Mark-read fallback when WebSocket unavailable |

---

## 13. Banking & Payments

### Canadian Banking Fields

Organizer bank accounts use Canadian banking format with all sensitive fields encrypted at rest.

| Field | Type | Description |
|-------|------|-------------|
| `institution_number_encrypted` | LargeBinary | 3-digit Canadian financial institution ID |
| `transit_number_encrypted` | LargeBinary | 5-digit branch transit number |
| `account_number_encrypted` | LargeBinary | Account number |
| `account_holder_encrypted` | LargeBinary | Account holder name |

### Verification Workflow

```
Organizer submits bank details ──► status: pending
                                       │
Admin reviews ─────────────────────────┤
                                       │
                            ┌──────────┴──────────┐
                            ▼                     ▼
                     status: verified       status: rejected
                     verified: true         rejection_reason: "..."
```

### Payout Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `payout_schedule` | weekly | Frequency of payouts |
| `payout_day` | 1 | Day of week/month for payout |
| `min_payout_cents` | 2500 | Minimum balance to trigger payout ($25) |
