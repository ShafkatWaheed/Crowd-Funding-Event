# Backend Flow — How a Request Is Handled

This document explains how requests move through the Crowd-Funded Event API: routing, auth, dependencies, services, and database.

---

## 1. Request Entry

```
HTTP Request
    ↓
main.py  (FastAPI app)
    ↓  CORS middleware
    ↓  Router mounted at /api/v1
api_router  (router.py)
    ↓  Prefixes: /auth, /me, /events, /venues, /admin
Route handler  (e.g. auth.py, events.py, admin.py)
```

- Every request hits **`main.py`**.
- **CORS** runs first.
- **`api_router`** is mounted at **`/api/v1`**, so all API URLs look like:  
  `/api/v1/auth/...`, `/api/v1/me`, `/api/v1/events/...`, `/api/v1/admin/...`.
- The right **route handler** is chosen by method and path (e.g. `POST /api/v1/auth/verify`, `POST /api/v1/events/5/submit`).

So: **Request → main.py → CORS → router → route handler.**

---

## 2. Two Ways the Backend Handles “Who Is This User?”

### Path A: Login / First-Time Setup — `POST /api/v1/auth/verify`

Used when the client has just signed in with Firebase and wants to “register” with your backend and get profile info.

**Sign-up and password:** When a user signs up, they must give **email and password** on the **frontend**. The frontend uses **Firebase Authentication** (e.g. Email/Password sign-in): the user enters email + password there, and Firebase creates the account and stores the password securely. The backend **never sees or stores the password**; it only receives the **Firebase ID token** after sign-in and uses it to create or update the user in your DB (with the chosen role). So the flow is: **user enters email + password in your app → Firebase signs them in and returns an ID token → frontend calls POST /auth/verify with that token (and optional role) → backend creates/updates user and returns profile.**

```
Client sends:  POST /api/v1/auth/verify   body: { "id_token": "<firebase_id_token>", "role": "customer" }
    ↓
auth.py  →  verify(body, db)
    ↓
auth_service.verify_and_upsert_user(db, id_token)
    ↓
firebase.verify_id_token(id_token)   →  decoded claims (uid, email, name)
    ↓
DB: select User by firebase_uid
    →  If found: update email, display_name; flush
    →  If not found: insert new User (role=customer); flush
    ↓
Return  VerifyResponse(user_id, email, display_name, role)
```

- **No** `Authorization` header here; the token is in the **body**.
- Backend verifies the token with Firebase, then **creates or updates** the user in your DB and returns their profile (including **role**).
- After this, the client knows the user’s role and can call other endpoints using the **same** `id_token` in the **header** (Path B).

### Path B: Protected Routes — `Authorization: Bearer <token>`

Used for everything that requires “current user” (e.g. GET /me, create event, submit for approval, admin users).

```
Client sends:  Any method   Header:  Authorization: Bearer <firebase_id_token>
    ↓
Route declares:  current_user: CurrentUser  (or  require_role(Admin))
    ↓
FastAPI runs dependencies before the route:
    ↓
1) get_db_session()   →  new AsyncSession (same session for whole request)
    ↓
2) verify_firebase_token(credentials)
       →  Reads Bearer token from header
       →  firebase.verify_id_token(token)  →  decoded
       →  return decoded["uid"]
    ↓
3) get_current_user(db, firebase_uid)
       →  If no firebase_uid: 401 "Not authenticated"
       →  DB: select User where firebase_uid = uid
       →  If no user: 401 "User not found"
       →  return user
    ↓
4) If route used require_role(Admin):  check user.role in (admin); else 403
    ↓
Route handler runs  with  db, current_user  (and body/path params)
```

So for protected routes: **Bearer token → verify with Firebase → get `firebase_uid` → load `User` from DB → optional role check → then your handler runs.**

---

## 2b. Role-based access (who can do what)

The API enforces roles so the frontend can show or hide features by role.

| Role | Can do | Cannot do |
|------|--------|-----------|
| **Customer** | View events (list, detail, funding). **Pledge** to events. **Register** for events (open or waitlist). **Unregister** (pledges refunded only if &gt;7 days before funding deadline). **Purchase tickets** (must be registered). View **my pledges** (GET /me/pledges) and **my tickets** (GET /me/tickets). Update own profile (GET/PATCH /me). | Create, update, delete, submit, cancel, or extend events. Manage event registrations or ticket tiers/discounts. Admin endpoints. |
| **Organizer** | Same as below for any event where they are **main organizer** or **co-organizer**. Main organizer can **add co-organizers** (POST /events/{id}/organizers) and **remove** them (DELETE .../organizers/{user_id}); only users with organizer role can be added. Co-organizers can do everything the main organizer can for that event (update, cancel, extend, registrations, ticket tiers/discounts, scan) **except** add/remove co-organizers. **Create** events (creator is main organizer). **Update/delete** own events. **Cancel** event anytime. **Extend funding** after deadline. **Submit** events for approval. **List and manage** registrations. **Ticket tiers** and **discounts**. **List** ticket sales. Create venues. | **Pledge** to any event. **Register** or **unregister** for any event. **Purchase** tickets. Admin-only endpoints. |
| **Admin** | Everything organizers can, plus: approve/reject events, list all users/events, stats, create users. Can manage any event’s tiers/discounts (not only own events). | Pledge, register, unregister, and purchase tickets are **customer-only** (admin is not treated as customer for those). |

Summary for the app:

- **Organizers** see and use: event listing, detail, create/update/delete/cancel, extend funding, submit for approval, manage registrations, ticket tiers and discounts, ticket sales, venues. They do **not** see or call: pledge, register, unregister, purchase ticket, my pledges, my tickets.
- **Customers** see and use: event listing, detail, pledge, register, unregister, ticket price preview, purchase ticket, my pledges, my tickets, profile. They do **not** see or call: create/update/delete/cancel/extend events, submit for approval, manage registrations or ticket tiers/discounts/sales.
- **Public** (no auth): list events, get event by id, get event funding summary, list ticket tiers for an event.

The backend returns **403** if a user calls an endpoint their role is not allowed to use (e.g. organizer calling `POST /events/{id}/pledge` or `POST /events/{id}/register`).

---

## 2c. Event and registration flows

**Organizer — funding and cancellation**

- Pledges are collected until the **funding period deadline** (`funding_end_at`).
- Organizer can **cancel** the event **anytime** (except already cancelled or ended) via `POST /events/{id}/cancel`. When an event is cancelled, **all pledged amounts for that event are refunded** (every pledge’s status is set to refunded).
- The same refund-on-cancel behavior applies when the organizer uses **delete** on a live/approved event (soft cancel).
- **After the funding deadline**, organizer can call `POST /events/{id}/extend-funding` with one or more of: `funding_end_at`, `start_time`, `end_time`. This gives customers a new window to unregister (and get refunds if &gt;7 days before the new deadline) or commit; setting event date is done via `start_time`/`end_time`.

**Customer — registration and unregister**

- **Open events:** first-come registration up to capacity; over capacity goes to waitlist.
- **Closed events:** registration creates a waitlist entry; organizer approves or rejects via `POST /events/{id}/registrations/{id}/decision`.
- If the organizer **changes the event from closed to open**, waitlist entries are **auto-approved** in order until capacity is reached.
- **Unregister:** `POST /events/{id}/unregister`. Registration is set to cancelled. **Pledges are refunded only if** the current time is more than **7 days before** the event’s `funding_end_at`; otherwise the customer can still unregister but does not get pledge refunds.

**Tickets**

- Events can sell **tickets** to **registered** attendees only (status = registered).
- Organizer defines **ticket tiers** (e.g. Platinum, Diamond) with name and price. Discounts apply at purchase:
  - **Common discount:** event-level percentage off for everyone.
  - **Pledge-based discount:** percentage of the user’s total pledges to that event, applied as ticket discount.
  - **Selective discount:** organizer sets a per-user discount (percent or fixed cents) via `POST /events/{id}/discounts`.
- If total discount is greater than or equal to the tier price, the organizer can set **extra perks** on the ticket (or leave blank). Price paid is never negative (capped at 0).
- Customer: `GET /events/{id}/ticket-price?tier_id=` to preview price; `POST /events/{id}/purchase-ticket` to buy. Customer can list their tickets at `GET /me/tickets`.

---

## 3. How a Protected Route Uses DB and Services

Most protected routes follow this pattern:

```
Route handler  (e.g. submit_event_for_approval)
    ↓  Has:  db (DbSession),  current_user (CurrentUser),  path/body
    ↓
Service function  (e.g. event_service.submit_for_approval(db, event_id, user))
    ↓  Loads/updates models, enforces rules, raises AppException if invalid
    ↓
DB (same session):  select / add / update / delete
    ↓
Return model(s)  to route
    ↓
Route builds response  (e.g. EventResponse from schema)
    ↓
FastAPI serializes  →  JSON response
```

- **One request = one DB session.**  
  `get_db_session()` creates a session, yields it to all dependencies and the route, then commits on success or rolls back on exception, then closes the session.
- **Route** = HTTP and schema (request/response).
- **Service** = business rules and DB access; raises `NotFoundError`, `ForbiddenError`, `ConflictError` when something is wrong.
- **Schemas** = what goes in/out of the API (e.g. `EventResponse`, `AdminUserItem`).

So: **Route → service → DB (same session) → back to route → JSON.**

---

## 4. One Full Example: Submit for Approval

End-to-end for **POST /api/v1/events/5/submit**:

1. **Request**  
   `POST /api/v1/events/5/submit`  
   `Authorization: Bearer <organizer_or_admin_firebase_token>`

2. **Router**  
   Matches `events.py` → `submit_event_for_approval(event_id=5, db, current_user)`.

3. **Dependencies (in order)**  
   - `get_db_session()` → `db`.  
   - `verify_firebase_token()` → validates Bearer token with Firebase, returns `firebase_uid`.  
   - `get_current_user(db, firebase_uid)` → loads `User` from DB.  
   - `require_role(organizer, admin)` → ensures `current_user.role` is organizer or admin.

4. **Handler**  
   Calls `event_service.submit_for_approval(db, event_id=5, user=current_user)`.

5. **Service**  
   - `get_or_404(db, 5)` → load event; 404 if missing.  
   - Check `_event_can_edit(user, event)` (owner or admin); else 403.  
   - Check `event.status == draft`; else 409.  
   - Set `event.status = pending_approval`, flush, refresh.

6. **Back to route**  
   Build `EventResponse` from the updated event and return it.

7. **After route**  
   Session commits (from `get_db_session`), then closes. Response is sent as JSON.

So: **Bearer → Firebase → User from DB → role check → service enforces rules and updates DB → route returns schema → commit → response.**

---

## 5. Where Each Piece Lives

| Layer        | Role |
|-------------|------|
| **main.py** | App, CORS, mount router, `/health`. |
| **api/v1/router.py** | Splits by prefix: auth, me, events, venues, admin. |
| **api/v1/*.py** | Route handlers: parse path/body, call services, return schemas. |
| **dependencies.py** | `DbSession`, `CurrentUser`, `require_role`. |
| **core/security.py** | Bearer + Firebase verify → `firebase_uid`; load user → `CurrentUser`. |
| **core/firebase.py** | Firebase init and `verify_id_token(token)`. |
| **services/*.py** | Business logic and DB access; raise app exceptions. |
| **db/base.py** | Engine, session factory, `get_db_session()`, `init_db()`. |
| **models/*.py** | SQLAlchemy tables (User, Event, Venue, Funding, Registration, TicketTier, TicketSale, UserEventDiscount). |
| **schemas/*.py** | Pydantic request/response (e.g. EventResponse, TicketTierResponse, TicketSaleResponse, UserDiscountBody). |

---

## 6. Short Summary

- **Unauthenticated:** Only `POST /auth/verify` (token in body); backend verifies with Firebase and creates/updates the user, returns profile (including role). Public can list events, get event detail, funding summary, and ticket tiers.
- **Authenticated:** Other routes send **Bearer** token; security verifies token and loads **User** from DB; **require_role** can restrict to admin/organizer/customer; then **route → service → DB → schema → response**.
- **Event lifecycle:** Organizer can cancel anytime; after funding deadline can extend funding and/or set event date. Customers can unregister; pledges are refunded only if more than 7 days before funding deadline. When event is switched from closed to open, waitlist is auto-approved up to capacity.
- **Tickets:** Only registered attendees can purchase. Each ticket has a unique **ticket_code** (for QR). Customer shows the code as a QR on their phone; organizer **scans** via `POST /events/{id}/scan-ticket` with the code. First scan sets `scanned_at` and `scanned_by`; later scans return `already_scanned: true` and the ticket. **List view** `GET /events/{id}/ticket-sales` includes `scanned_at` and `scanned_by_display_name` so the organizer can see who was scanned. Price is tier price minus common, selective, and pledge-based discounts.
- **DB:** One session per request; commit on success, rollback on error.
