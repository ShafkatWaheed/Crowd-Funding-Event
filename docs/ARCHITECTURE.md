# Crowd-Funded Event App — Architecture

**Target:** Small events in Ottawa, Canada → scale to larger events  
**Stack:** React Native | FastAPI | PostgreSQL | Firebase Auth

---

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLIENT (React Native)                              │
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────┐                     │
│  │   Admin     │  │ Event Organizer │  │   Customer  │                     │
│  │   View      │  │     View        │  │    View     │                     │
│  └──────┬──────┘  └────────┬────────┘  └──────┬──────┘                     │
│         │                  │                   │                            │
│         └──────────────────┼───────────────────┘                            │
│                            │                                                 │
│                    ┌───────▼───────┐                                         │
│                    │  Firebase     │  (Auth only)                            │
│                    │  Auth SDK     │                                         │
│                    └───────┬───────┘                                         │
└────────────────────────────┼───────────────────────────────────────────────┘
                             │
                             │  HTTPS / REST
                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        BACKEND (FastAPI)                                     │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│  │   Auth     │ │   Events   │ │  Funding   │ │   Map      │ │  Capacity  │ │
│  │   Module   │ │   Module   │ │  Module    │ │  Module    │ │  Module    │ │
│  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ └─────┬──────┘ │
│        │               │              │              │              │        │
│        └───────────────┴──────────────┴──────────────┴──────────────┘        │
│                                    │                                         │
│                            ┌───────▼───────┐                                 │
│                            │  SQLAlchemy   │                                 │
│                            │  + Pydantic   │                                 │
│                            └───────┬───────┘                                 │
└────────────────────────────────────┼─────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PostgreSQL                                           │
│  users | roles | events | venues | fundings | registrations | ...            │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Auth flow:** React Native uses Firebase Auth (sign-in, tokens). Backend validates **Firebase ID tokens** on each request and maps to your PostgreSQL user/role.

---

## 2. Three Views: Admin, Event Organizer, Customer

| Role | Purpose | Main capabilities |
|------|---------|-------------------|
| **Admin** | Platform oversight, Ottawa-first moderation | Approve/reject events, manage organizers, view analytics, moderate content |
| **Event Organizer** | Create and run crowd-funded events | Create events, set funding goal & capacity, see funding/registrations, manage one event or many |
| **Customer** | Discover, fund, and join events | Browse map, fund events, register (if capacity allows), open vs closed events |

---

## 3. Core Concepts

### 3.1 Open vs Closed Events

| Type | Meaning | Join rule |
|------|--------|-----------|
| **Open event** | Registration is first-come-first-served up to capacity also will have funding goals | Customer can register while spots remain. |
| **Closed event** | Registration is controlled (e.g. approval, invite-only, or after funding goal) | Customer can request/join only when organizer allows (e.g. after goal met). |

**Implementation:** Each event has `registration_type: open | closed` and `max_capacity`. Backend enforces capacity and registration rules per type.

### 3.2 Crowd Funding

- Organizer sets a **funding goal** and optional **deadline**.
- Customers **contribute** (pledge) to the event.
- When goal is met (and optionally deadline passed), event is **confirmed**; otherwise it can be cancelled or extended (business rule).
- Funding can be held in escrow or recorded as pledges (Ottawa MVP: record pledges; payment gateway later).

### 3.3 Map & Live Events

- Events have **location** (lat/lng + address, Ottawa-first).
- **Live** = event is currently happening (start_time ≤ now ≤ end_time).
- Map shows events (all or filtered: live, upcoming, by category). Clustering for many events.

---

## 4. Modules to Build

### 4.1 Backend (FastAPI) — Modules

| Module | Responsibility | Key endpoints / logic |
|--------|----------------|------------------------|
| **Auth** | Verify Firebase token, create/update user in DB, assign role | `POST /auth/verify`, `GET /me`, role in JWT or DB |
| **Users & roles** | CRUD users (Admin only for roles), profile | `GET/PATCH /users/me`, `GET /users` (admin), role: admin \| organizer \| customer |
| **Events** | CRUD events, status (draft → pending_approval → approved → live → ended), location | `GET/POST/PATCH/DELETE /events`, filters: city=Ottawa, live, open/closed |
| **Venues / halls** | Venue CRUD, capacity per venue | `GET/POST/PATCH /venues`, link event → venue (capacity source) |
| **Funding** | Pledges, goals, release when goal met | `POST /events/{id}/pledge`, `GET /events/{id}/funding`, goal checks |
| **Registrations** | Join event (respect open/closed + capacity) | `POST /events/{id}/register`, `GET /events/{id}/registrations` (organizer/admin) |
| **Map** | Events in bounding box or by city (Ottawa) | `GET /events/map?lat=&lng=&radius=&live=` |
| **Admin** | Approve/reject events, list organizers, simple analytics | `POST /events/{id}/approve`, `GET /admin/events`, `GET /admin/stats` |
| **Notifications** (optional v1) | In-app or push when event approved, goal met, etc. | Firestore or FCM later |

### 4.2 React Native App — Modules (by role)

| Module | Admin | Organizer | Customer |
|--------|--------|-----------|----------|
| **Auth** | Login (Firebase), role selection if needed | Same | Same |
| **Onboarding / role** | Redirect to Admin stack | Redirect to Organizer stack | Redirect to Customer stack |
| **Home / Dashboard** | Pending events, stats, quick actions | My events, funding status | Discover (map + list), “My events” |
| **Map** | Optional (all events) | Optional (my events) | **Primary**: live + upcoming events, filters |
| **Events list** | All events (filters) | My events (draft, active, past) | Browse by category, Ottawa |
| **Event detail** | Full detail + approve/reject | Edit, funding, registrations, capacity | View, fund, register (open/closed) |
| **Create / Edit event** | — | Create event, set venue, goal, capacity, open/closed | — |
| **Funding** | — | See pledges, goal progress | Pledge to event |
| **Registrations** | — | See list, capacity used | Register (open) or request (closed) |
| **Profile / Settings** | Profile, maybe invite organizers | Profile, my venues | Profile, my events & pledges |
| **Admin tools** | Approve events, users, stats | — | — |

---

## 5. Database (PostgreSQL) — Core Entities

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│    users     │       │   venues     │       │   events     │
├──────────────┤       ├──────────────┤       ├──────────────┤
│ id           │       │ id           │       │ id           │
│ firebase_uid │       │ name         │       │ organizer_id │──┐
│ email        │       │ address      │       │ venue_id     │  │
│ display_name │       │ lat, lng     │       │ title        │  │
│ role         │       │ max_capacity │       │ description  │  │
│ created_at   │       │ city (Ottawa)│       │ start_time   │  │
└──────┬───────┘       └──────┬───────┘       │ end_time    │  │
       │                      │               │ lat, lng    │  │
       │                      │               │ funding_goal│  │
       │                      │               │ funding_end │  │
       │                      │               │ status      │  │
       │                      │               │ registration_type │ open|closed
       │                      │               │ max_capacity│  │
       │                      │               └──────┬──────┘  │
       │                      │                      │         │
       │                      │               ┌──────▼──────┐  │
       │                      │               │  fundings   │  │
       │                      │               ├────────────┤  │
       │                      │               │ event_id   │  │
       │                      │               │ user_id    │◄─┘
       │                      │               │ amount     │
       │                      │               │ status     │
       │                      │               └────────────┘
       │                      │
       │                      │               ┌──────────────┐
       │                      │               │registrations│
       │                      │               ├──────────────┤
       │                      └──────────────►│ event_id     │
       │                                      │ user_id     │
       │                                      │ status      │
       │                                      │ (optional)  │
       └─────────────────────────────────────►│ requested_at│
                                              └──────────────┘
```

**Suggested tables (minimal for v1):**

- **users** — id, firebase_uid (unique), email, display_name, role (enum: admin, organizer, customer), created_at, updated_at
- **venues** — id, name, address, city, province, lat, lng, max_capacity, created_at
- **events** — id, organizer_id, venue_id, title, description, start_time, end_time, lat, lng, funding_goal, funding_end_at, status (draft, pending_approval, approved, live, ended, cancelled), registration_type (open, closed), max_capacity, created_at, updated_at
- **fundings** — id, event_id, user_id, amount_cents, status (pledged, collected, refunded), created_at
- **registrations** — id, event_id, user_id, status (registered, waitlist, cancelled), created_at

Add indexes on: `events(city, status, start_time)`, `events(lat, lng)` or PostGIS for map, `registrations(event_id)`, `fundings(event_id)`.

---

## 6. API Structure (FastAPI) — Layout

```
/api
├── v1/
│   ├── auth/
│   │   └── verify          # POST: body { id_token } → create/update user, return app token or session
│   ├── me/                 # GET/PATCH current user (role, profile)
│   ├── events/
│   │   ├── GET             # list (query: city, status, live, registration_type, organizer_id)
│   │   ├── POST            # create (organizer)
│   │   └── /{id}/
│   │       ├── GET         # detail
│   │       ├── PATCH       # update (organizer owner or admin)
│   │       ├── DELETE      # (organizer or admin)
│   │       ├── pledge      # POST fundings (customer)
│   │       ├── register    # POST registrations (customer, check capacity & open/closed)
│   │       ├── registrations  # GET (organizer/admin)
│   │       └── approve     # POST (admin)
│   ├── events/map/
│   │   └── GET             # ?lat=&lng=&radius=&live=&city=Ottawa
│   ├── venues/
│   │   └── GET, POST, PATCH
│   ├── admin/
│   │   ├── events          # GET list (pending, all)
│   │   ├── events/{id}/approve   # POST
│   │   └── stats           # GET
│   └── ...
├── health
└── ...
```

Use **dependency injection** for “current user” and “require role” (admin, organizer, customer). Validate Firebase token in a middleware or dependency and load user from PostgreSQL.

**Request/response schemas:** All API request and response bodies are defined as Pydantic models in `app/schemas/` (event, user, venue, funding, registration, admin). Route handlers import these schemas from `app.schemas` so validation and OpenAPI docs stay in one place.

---

## 7. React Native App — Layout & Navigation

### 7.1 Suggested folder structure

```
mobile/
├── src/
│   ├── api/              # API client (axios/fetch), auth header (Firebase token)
│   ├── auth/             # Firebase Auth, token refresh, role persistence
│   ├── navigation/       # Root navigator + role-based stacks
│   ├── screens/
│   │   ├── auth/         # Login, Register, ForgotPassword
│   │   ├── admin/        # Dashboard, PendingEvents, EventDetail, Stats
│   │   ├── organizer/    # Dashboard, CreateEvent, EditEvent, EventFunding, EventRegistrations
│   │   └── customer/     # Home, Map, EventList, EventDetail, FundEvent, RegisterEvent, MyEvents
│   ├── components/       # Shared: EventCard, MapMarkers, FundingBar, CapacityBadge
│   ├── context/          # AuthContext (user, role), Theme
│   ├── hooks/            # useEvents, useMapEvents, useFunding
│   ├── types/            # Event, User, Venue, RegistrationType
│   └── utils/
├── App.tsx
├── app.json
└── package.json
```

### 7.2 Navigation layout (conceptual)

- **Unauthenticated:** Auth stack (Login, Register).
- **Authenticated:** Role resolved from `/me` (or cached). Single place to switch stacks:
  - **Admin:** Tab or Drawer — Dashboard, Pending events, Events (list), Stats, Profile.
  - **Organizer:** Tab — Dashboard (my events), Create event, Map (optional), Profile.
  - **Customer:** Tab — **Map** (default), List, My events, Profile.

**Map tab (customer):** Full-screen map (e.g. React Native Maps) with markers for events; filter by “Live”, “Upcoming”, “Ottawa”. Tapping marker → bottom sheet or navigate to Event detail. List view can sit in another tab or as a list overlay on map.

### 7.3 Key screens to bring forward (MVP)

| Priority | Screen | Role | Purpose |
|----------|--------|------|---------|
| 1 | Login / Register | All | Firebase Auth, then fetch `/me` for role |
| 2 | Map (events) | Customer | Show live/upcoming events in Ottawa on map |
| 3 | Event detail | Customer | See event, funding progress, “Pledge” and “Register” (if open/closed allows) |
| 4 | Organizer dashboard | Organizer | List my events, funding status, capacity |
| 5 | Create event | Organizer | Form: venue, dates, funding goal, capacity, open/closed |
| 6 | Pending events + Approve | Admin | List pending, approve/reject |
| 7 | Register / Pledge flows | Customer | Complete registration and pledge from Event detail |

---

## 8. Auth: Firebase + FastAPI

1. **React Native:** User signs in with Firebase Auth (email/password or Google, etc.). Get `idToken` after sign-in.
2. **Every API request:** Send `Authorization: Bearer <idToken>` (or refresh token server-side if you add your own JWT).
3. **FastAPI:**  
   - Dependency: decode Firebase ID token (use `firebase-admin` or a JWT library with Firebase’s public keys).  
   - Get `firebase_uid` from token → lookup or create user in PostgreSQL, attach `user` and `role` to request.  
   - Protect routes by role (e.g. only admin can hit `POST /admin/events/{id}/approve`).

No need to store passwords in PostgreSQL; only `firebase_uid`, email, display_name, role.

---

## 9. Ottawa-First, Then Scale

- **Phase 1 (Ottawa small events):**  
  - City filter default “Ottawa”; venues and events in Ottawa.  
  - Simple map (no clustering) and list.  
  - Open/closed and capacity for small halls.

- **Phase 2:**  
  - More cities (e.g. Ontario then Canada).  
  - Map clustering, better search/filters.  
  - Payments (Stripe) for pledges, escrow, refunds.

- **Phase 3:**  
  - Larger venues, multi-day events, tickets, notifications (FCM), analytics.

---

## 10. Summary: What to Build First

| Order | Module | Delivers |
|-------|--------|----------|
| 1 | **Auth** (Firebase + FastAPI verify, users table, role) | Login and role-based access |
| 2 | **Events + Venues** (CRUD, status, capacity, open/closed) | Organizers can create events |
| 3 | **Map API + Map screen** (Ottawa, live/upcoming) | Customers see events on map |
| 4 | **Funding** (pledges, goal) | Crowd-funded flow |
| 5 | **Registrations** (capacity, open/closed) | Customers join events |
| 6 | **Admin** (approve events, stats) | Safe rollout in Ottawa |

This gives you a clear **architecture**, **modules**, and **layout** for the crowd-funded, event-based app with Admin, Organizer, and Customer views, live events on map, and open/closed capacity-based joining, using React Native, FastAPI, PostgreSQL, and Firebase Auth.
