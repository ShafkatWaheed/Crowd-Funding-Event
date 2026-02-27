# Feature Impact Analysis

This document maps the **blast radius** of each feature — every file touched, whether it is new or modified, and which other features it interacts with. Use this to understand risk, plan code reviews, and identify regression testing areas.

Legend: **[NEW]** = new file created, **[MOD]** = existing file modified, **[DEP]** = depends on another feature

---

## 0. Privacy Rules

**Scope:** Small, surgical. Only removes/changes specific fields. No new tables or screens.

| Layer | File | Change | Risk |
|-------|------|--------|------|
| Backend Model | — | No model changes | — |
| Backend Schema | `Backend/app/schemas/ticket.py` **[MOD]** | Remove `attendee_email` from `TicketReceiptResponse` and `PurchaseGroupReceiptResponse` | Low — field removal, frontend may show `null` briefly if not updated simultaneously |
| Backend API | `Backend/app/api/v1/events.py` **[MOD]** | Stop populating `attendee_email`, fix `organizer_name` fallback (3 receipt endpoints) | Low — receipt endpoints only |
| Backend API | `Backend/app/api/v1/users.py` **[MOD]** | Same: fix attendee_email + organizer_name fallback in `/me/tickets/{id}/receipt` | Low |
| Backend API | `Backend/app/api/v1/sponsors.py` **[MOD]** | Line 186: `display_name` instead of `email` in fallback. Line 634: same fix. | Low |
| Frontend | `ticket_receipt_screen.dart` **[MOD]** | Remove attendee email row | Low |
| Frontend | `purchase_group_receipt_screen.dart` **[MOD]** | Remove attendee email row, fix QR fallback | Low |

**Cross-feature impact:** None. Completely independent.

**Regression risk:** Low. Only receipt display and one sponsor name field change.

---

## Feature 1 — In-App Notification System

**Scope:** Large. Touches the most files of any feature — every endpoint that performs a user-facing action gets a notification call added.

### New files (5)

| Layer | File | Purpose |
|-------|------|---------|
| Backend Model | `Backend/app/models/notification.py` **[NEW]** | `Notification` table, `NotificationType` enum (22 values) |
| Backend Service | `Backend/app/services/notification_service.py` **[NEW]** | `create_notification()`, `create_bulk_notifications()`, `list_notifications()`, `unread_count()`, `mark_read()`, `mark_all_read()` |
| Backend API | `Backend/app/api/v1/notifications.py` **[NEW]** | 4 endpoints under `/me/notifications` |
| Frontend Provider | `FrontEnd/lib/providers/notification_provider.dart` **[NEW]** | Polls unread count every 30s, manages notification list state |
| Frontend Screen | `FrontEnd/lib/screens/notification/notification_screen.dart` **[NEW]** | Notification list UI with type icons, read/unread, tap-to-navigate |

### Modified files (13)

| Layer | File | Change |
|-------|------|--------|
| Backend Model | `Backend/app/models/__init__.py` **[MOD]** | Import `Notification`, `NotificationType` |
| Backend API | `Backend/app/api/v1/router.py` **[MOD]** | Mount `notifications.router` |
| Backend API | `Backend/app/api/v1/events.py` **[MOD]** | Add notification calls in: `register_event`, `unregister_event`, `cancel_event`, `purchase_ticket`, `approve_waitlisted_ticket`, `reject_waitlisted_ticket`, `publish_event`, pledge endpoint, schedule update endpoint (**9 endpoints**) |
| Backend API | `Backend/app/api/v1/sponsors.py` **[MOD]** | Add notification calls in: `place_bid` (notify organizer), `accept_bid` (notify sponsor), `reject_bid` (notify sponsor) (**3 endpoints**) |
| Backend API | `Backend/app/api/v1/admin.py` **[MOD]** | Add notification calls in: event approval, event rejection (**2 endpoints**) |
| Backend Service | `Backend/app/services/registration.py` **[MOD]** | Add notification in `approve_waitlist()`, `reject_waitlist()` |
| Backend Service | `Backend/app/services/event.py` **[MOD]** | Add notification on status transitions (if done in service layer) |
| Migration | `Backend/alembic/versions/ii60i0j1k2l3_notifications.py` **[NEW]** | `notifications` table + indexes |
| Frontend | `FrontEnd/lib/main.dart` **[MOD]** | Register `NotificationProvider` in `MultiProvider` |
| Frontend | `FrontEnd/lib/screens/home/home_screen.dart` **[MOD]** | Add notification bell icon with badge to AppBar |
| Frontend | `FrontEnd/lib/services/api_service.dart` **[MOD]** | (Optional) Add notification API methods if not using `dio` directly in provider |
| Frontend | `FrontEnd/lib/config/router.dart` **[MOD]** | (Optional) Add route for notification screen |

### Cross-feature dependencies

| Feature | How it uses notifications |
|---------|--------------------------|
| Feature 4 (Prerequisites) | Document review (approve/reject) triggers notification to sponsor |
| Feature 5 (Ratings) | New rating triggers `new_rating_received` notification to rated user |
| Feature 6 (Bookmarks) | (Optional) Bookmarked event status change triggers `bookmarked_event_update` |

**Regression risk:** MEDIUM-HIGH. The notification `create_notification()` calls are added inside 14+ existing endpoints. Each integration point must:
- Not break the endpoint's main return value
- Not throw if notification creation fails (wrap in try/except or ensure service is robust)
- Not significantly slow down the endpoint (single INSERT, should be <5ms)

**Testing strategy:** Each modified endpoint needs a test verifying (a) the main operation still works and (b) a notification row was created.

---

## Feature 2 — Organizer Public Profile

**Scope:** Small-Medium. One new backend file, one new frontend screen, one modification to event detail.

### New files (2)

| Layer | File | Purpose |
|-------|------|---------|
| Backend API | `Backend/app/api/v1/public_profiles.py` **[NEW]** | `GET /users/{id}/public-profile`, `GET /users/{id}/public-events` |
| Frontend Screen | `FrontEnd/lib/screens/profile/organizer_profile_screen.dart` **[NEW]** | Full organizer profile page |

### Modified files (4)

| Layer | File | Change |
|-------|------|--------|
| Backend API | `Backend/app/api/v1/router.py` **[MOD]** | Mount `public_profiles.router` |
| Frontend | `FrontEnd/lib/screens/event/event_detail_screen.dart` **[MOD]** | Make organizer name tappable (InkWell), add `_showOrganizerProfileSheet()` bottom sheet method |
| Frontend | `FrontEnd/lib/services/api_service.dart` **[MOD]** | Add `getPublicProfile()`, `getPublicEvents()` methods |
| Frontend | `FrontEnd/lib/config/router.dart` **[MOD]** | (Optional) Add route for organizer profile |

### Cross-feature dependencies

| Feature | Interaction |
|---------|-------------|
| Feature 5 (Ratings) **[DEP]** | Profile displays average rating once ratings exist |
| Feature 3 (Sponsor Info) | Shares `public_profiles.py` backend file |

**Regression risk:** LOW. The only modification to an existing screen is wrapping the organizer name in an InkWell on `event_detail_screen.dart`. No data flow changes.

---

## Feature 3 — Enhanced Sponsor Info for Organizers

**Scope:** Small-Medium. Extends Feature 2's backend file, adds one new screen, modifies two existing sponsor screens.

### New files (1)

| Layer | File | Purpose |
|-------|------|---------|
| Frontend Screen | `FrontEnd/lib/screens/profile/sponsor_profile_screen.dart` **[NEW]** | Full sponsor profile page (company, profession, bid stats) |

### Modified files (4)

| Layer | File | Change |
|-------|------|--------|
| Backend API | `Backend/app/api/v1/public_profiles.py` **[MOD]** | Add `GET /users/{id}/sponsor-public-profile` endpoint |
| Frontend | `FrontEnd/lib/screens/sponsor/bid_management_screen.dart` **[MOD]** | Make sponsor name tappable -> opens bottom sheet |
| Frontend | `FrontEnd/lib/screens/sponsor/organizer_sponsors_screen.dart` **[MOD]** | Make sponsor cards tappable -> opens bottom sheet |
| Frontend | `FrontEnd/lib/services/api_service.dart` **[MOD]** | Add `getSponsorPublicProfile()` method |

### Cross-feature dependencies

| Feature | Interaction |
|---------|-------------|
| Feature 2 (Organizer Profile) **[DEP]** | Shares `public_profiles.py` — must be created first |
| Feature 5 (Ratings) **[DEP]** | Profile displays average rating once ratings exist |

**Regression risk:** LOW. Modifications to existing screens are only adding tappable wrappers around existing text — no data flow changes.

---

## Feature 4 — Sponsorship Category Prerequisites

**Scope:** Medium. Two new models, one migration, 4 new API endpoints, modifications to sponsor and bid screens.

### New files (2)

| Layer | File | Purpose |
|-------|------|---------|
| Backend Model | `Backend/app/models/prerequisite.py` **[NEW]** | `CategoryPrerequisite`, `BidPrerequisiteUpload` tables, `UploadStatus` enum |
| Migration | `Backend/alembic/versions/kk80k2l3m4n5_prerequisites.py` **[NEW]** | Two new tables + indexes |

### Modified files (6)

| Layer | File | Change |
|-------|------|--------|
| Backend Model | `Backend/app/models/__init__.py` **[MOD]** | Import new models |
| Backend API | `Backend/app/api/v1/sponsors.py` **[MOD]** | Add 4 endpoints: create prerequisite, list prerequisites, upload document, review document |
| Backend Service | `Backend/app/services/sponsor.py` **[MOD]** | Add prerequisite check in `accept_bid()` — **blocks bid acceptance** if required docs not approved |
| Frontend | `FrontEnd/lib/screens/sponsor/sponsorship_categories_screen.dart` **[MOD]** | Organizer adds requirements when creating/editing categories |
| Frontend | `FrontEnd/lib/screens/sponsor/bid_management_screen.dart` **[MOD]** | Show uploaded documents, approve/reject buttons for organizer |
| Frontend | `FrontEnd/lib/services/api_service.dart` **[MOD]** | Add prerequisite CRUD + upload + review methods |

### Cross-feature dependencies

| Feature | Interaction |
|---------|-------------|
| Feature 1 (Notifications) **[DEP]** | Document review triggers notification to sponsor |

**Regression risk:** MEDIUM. The critical change is in `accept_bid()` — adding a prerequisite check **before** changing bid status. If prerequisites aren't loaded correctly, it could block all bid acceptances. Must be guarded: if no prerequisites are defined for a category, the check should pass (empty list = all satisfied).

**Edge cases to test:**
- Category with 0 prerequisites -> bid acceptance should work as before
- Category with prerequisites, all approved -> bid acceptance works
- Category with prerequisites, one pending -> bid acceptance blocked with clear error
- Category with optional (non-required) prerequisites -> should not block

---

## Feature 5 — Multi-Directional Rating System

**Scope:** Medium. One new model, one new API file, modifications to event detail and profile screens.

### New files (3)

| Layer | File | Purpose |
|-------|------|---------|
| Backend Model | `Backend/app/models/rating.py` **[NEW]** | `Rating` table, `RatingDirection` enum |
| Backend API | `Backend/app/api/v1/ratings.py` **[NEW]** | `POST /events/{id}/ratings`, `GET /events/{id}/ratings`, `GET /users/{id}/ratings-received` |
| Migration | `Backend/alembic/versions/ll90l3m4n5o6_ratings.py` **[NEW]** | `ratings` table + unique constraint + indexes |

### Modified files (7)

| Layer | File | Change |
|-------|------|--------|
| Backend Model | `Backend/app/models/__init__.py` **[MOD]** | Import new models |
| Backend API | `Backend/app/api/v1/router.py` **[MOD]** | Mount `ratings.router` |
| Frontend | `FrontEnd/lib/screens/event/event_detail_screen.dart` **[MOD]** | Add "Rate this event" card for completed events (customer view). Star picker + description field + submit button |
| Frontend | `FrontEnd/lib/screens/profile/organizer_profile_screen.dart` **[MOD]** | Display average rating from API **[DEP Feature 2]** |
| Frontend | `FrontEnd/lib/screens/profile/sponsor_profile_screen.dart` **[MOD]** | Display average rating from API **[DEP Feature 3]** |
| Frontend | `FrontEnd/lib/services/api_service.dart` **[MOD]** | Add rating methods |
| Frontend | (New widget) `FrontEnd/lib/widgets/star_rating.dart` **[NEW]** | Reusable star rating input/display widget |

### Cross-feature dependencies

| Feature | Interaction |
|---------|-------------|
| Feature 1 (Notifications) **[DEP]** | New rating triggers `new_rating_received` notification |
| Feature 2 (Organizer Profile) **[DEP]** | Ratings displayed on organizer profile |
| Feature 3 (Sponsor Info) **[DEP]** | Ratings displayed on sponsor profile |

**Regression risk:** LOW-MEDIUM. The main risk is the modification to `event_detail_screen.dart` (already a large file at 6000+ lines). The rating card should only appear when `event.status == completed`, so it won't affect other event states.

**Edge cases:**
- User tries to rate a non-completed event -> API returns 400
- User tries to rate the same direction twice -> API returns 409
- Organizer rates sponsor who has no profile -> `rated_user_id` still works (FK to users, not sponsor_profiles)

---

## Feature 6 — Event Bookmarks

**Scope:** Small. One new model, two new endpoints, UI changes to event cards and Manage tab.

### New files (2)

| Layer | File | Purpose |
|-------|------|---------|
| Backend Model | `Backend/app/models/bookmark.py` **[NEW]** | `Bookmark` table with unique constraint |
| Migration | `Backend/alembic/versions/jj70j1k2l3m4_bookmarks.py` **[NEW]** | `bookmarks` table + indexes |

### Modified files (5)

| Layer | File | Change |
|-------|------|--------|
| Backend Model | `Backend/app/models/__init__.py` **[MOD]** | Import `Bookmark` |
| Backend API | `Backend/app/api/v1/events.py` **[MOD]** | Add `POST /{event_id}/bookmark` toggle endpoint |
| Backend API | `Backend/app/api/v1/users.py` **[MOD]** | Add `GET /me/bookmarks` list endpoint |
| Frontend | `FrontEnd/lib/screens/home/home_screen.dart` **[MOD]** | Add bookmark icon to event cards (Home, Explore, Manage tabs). Add "Bookmarks" quick action in Manage for all roles. Maintain local `Set<int>` for bookmarked event IDs |
| Frontend | `FrontEnd/lib/screens/event/event_detail_screen.dart` **[MOD]** | Add bookmark icon in AppBar actions |
| Frontend Screen | `FrontEnd/lib/screens/bookmark/bookmarked_events_screen.dart` **[NEW]** | Bookmarked events list with search bar and event state filter chips |
| Frontend | `FrontEnd/lib/services/api_service.dart` **[MOD]** | Add `toggleBookmark()`, `getMyBookmarks()` methods |

### Cross-feature dependencies

| Feature | Interaction |
|---------|-------------|
| Feature 1 (Notifications) | (Optional) Bookmarked event status change can trigger notification |

**Regression risk:** LOW. The bookmark icon is additive — it doesn't change any existing event card layout, just adds an icon button. The toggle endpoint is a simple create/delete.

---

## Feature 7 — Multi-Role System

**Scope:** LARGE. Most structurally impactful feature. Touches auth, user model, dependency injection, and potentially every screen that checks `user.role`.

### New files (1)

| Layer | File | Purpose |
|-------|------|---------|
| Migration | `Backend/alembic/versions/mm00m4n5o6p7_multirole.py` **[NEW]** | Add `roles` JSON column to `users`, populate from existing `role` |

### Modified files (12+)

| Layer | File | Change | Risk |
|-------|------|--------|------|
| Backend Model | `Backend/app/models/user.py` **[MOD]** | Add `roles: JSON` column | LOW |
| Backend Model | `Backend/app/models/__init__.py` **[MOD]** | No new imports needed (User already imported) | LOW |
| Backend API | `Backend/app/api/v1/users.py` **[MOD]** | Add `POST /me/roles/add`, `PATCH /me/roles/switch`, update `_me_response` to include `roles` | MEDIUM |
| Backend | `Backend/app/dependencies.py` **[MOD]** | Update `require_role()` to also check `user.roles` list | **HIGH** |
| Backend Schema | `Backend/app/schemas/__init__.py` or similar **[MOD]** | Add `roles` to `MeResponse` | LOW |
| Frontend Model | `FrontEnd/lib/models/user.dart` **[MOD]** | Add `roles: List<String>?` field, update `fromJson` | LOW |
| Frontend | `FrontEnd/lib/screens/profile/profile_screen.dart` **[MOD]** | Add role switcher (ChoiceChip row) and "Add Role" button | MEDIUM |
| Frontend | `FrontEnd/lib/providers/auth_provider.dart` **[MOD]** | Add `refreshUser()` method after role switch, update user state | MEDIUM |
| Frontend | `FrontEnd/lib/screens/home/home_screen.dart` **[MOD]** | Manage tab content may need to adapt based on active role | MEDIUM |
| Frontend | `FrontEnd/lib/screens/sponsor/sponsor_onboarding_screen.dart` **[MOD]** | May need to handle "adding sponsor role" flow vs "initial signup as sponsor" | MEDIUM |
| Frontend | `FrontEnd/lib/services/api_service.dart` **[MOD]** | Add `addRole()`, `switchRole()` methods | LOW |
| Frontend | `FrontEnd/lib/config/router.dart` **[MOD]** | Route guards may need to consider multi-role | MEDIUM |

### Cross-feature dependencies

| Feature | Interaction |
|---------|-------------|
| ALL features | Every `require_role()` call in the backend is affected by the `dependencies.py` change |
| Feature 2, 3 (Profiles) | Profile screens need to adapt to active role |

**Regression risk:** **HIGH**. This is the riskiest feature because:

1. **`require_role()` change is global** — every protected endpoint (40+ endpoints) goes through this dependency. If the logic is wrong, it could either lock users out or grant unauthorized access.

2. **Data migration** — the `UPDATE users SET roles = json_build_array(role::text)` must run correctly. If it fails or produces malformed JSON, auth breaks for all users.

3. **Frontend role switching** — switching roles changes what the user sees in Manage tab, profile, event actions. Every `if (user.isOrganizer)` / `if (user.isSponsor)` check in the frontend needs to be verified against the **active role** (not just role list).

4. **Sponsor onboarding** — currently, becoming a sponsor requires signing up as a sponsor. With multi-role, an existing customer adds the sponsor role, which needs to trigger onboarding (company name, profession, etc.) without creating a new account.

**Testing strategy:**
- Test every `require_role` endpoint with a multi-role user to ensure access works
- Test role switching and verify UI updates correctly
- Test that a customer-only user cannot access organizer endpoints even after multi-role migration
- Test adding sponsor role triggers onboarding

---

## Sponsor Ticket Scan Count (Addendum)

**Scope:** Small. One column addition, one service method change.

### New files (1)

| Layer | File | Purpose |
|-------|------|---------|
| Migration | `Backend/alembic/versions/nn10n5o6p7q8_sponsor_scan_count.py` **[NEW]** | Add `scan_count` column to `sponsor_tickets` |

### Modified files (3)

| Layer | File | Change | Risk |
|-------|------|--------|------|
| Backend Model | `Backend/app/models/sponsor.py` **[MOD]** | Add `scan_count: Integer` to `SponsorTicket` | LOW |
| Backend Service | `Backend/app/services/sponsor.py` **[MOD]** | `scan_sponsor_ticket()`: increment `scan_count` on every scan, change `already_scanned` logic | LOW |
| Frontend | `FrontEnd/lib/screens/sponsor/sponsor_ticket_screen.dart` **[MOD]** | Display `scan_count` (entries) on ticket detail | LOW |
| Frontend | Scan result UI (ticket scanner or event detail) **[MOD]** | Show `scan_count` in scan response | LOW |

**Cross-feature impact:** None.

**Regression risk:** LOW. The only behavioral change is that scanning no longer no-ops after the first scan — it increments the counter. `scanned_at` still set once.

---

## Recently Implemented (Organizer UX, Performance, Caching)

### Structured JSON logging (stdout, OpenSearch-ready)

**Scope:** Large. Cross-cutting: one new module, config change, and logging added or migrated across ~45 API/service/core files. Output is stdout-only; OpenSearch/Fluent Bit is a later upgrade.

| Layer | File | Change |
|-------|------|--------|
| Backend | `Backend/app/logger.py` **[NEW]** | `JSONFormatter`, `setup_logging(level)`, `get_logger(name)`, `log_step(logger, msg, *args, **extra)`; single JSON line per record to stdout |
| Backend | `Backend/app/config.py` **[MOD]** | Add `LOG_LEVEL` (default INFO) |
| Backend | `Backend/app/main.py` **[MOD]** | Replace `logging.basicConfig` with `setup_logging(settings.LOG_LEVEL)`; use `get_logger("app")` |
| Backend | `Backend/app/core/firebase.py`, `core/security.py` **[MOD]** | Add logger, log_step and debug/warning for init and token verification |
| Backend | `Backend/app/dependencies.py` **[MOD]** | Add logger; log permission denials and feature-gate blocks |
| Backend | `Backend/app/db/base.py` **[MOD]** | Add logger; debug on session rollback |
| Backend | `Backend/app/worker/main.py` **[MOD]** | Call `setup_logging(settings.LOG_LEVEL)`; add logger; warning when cron config load fails |
| Backend API | `Backend/app/api/v1/auth.py`, `admin.py`, `banking.py`, `milestones.py`, `users.py`, `ratings.py`, `notifications.py` **[MOD]** | Add `get_logger`, `log_step`; step at mutation entry, warning on errors |
| Backend API | `Backend/app/api/v1/events/*.py` (crud, lifecycle, pledge, tickets, registration, images, organizers) **[MOD]** | Same: step + warning/debug |
| Backend API | `Backend/app/api/v1/sponsors/*.py` (bids, payments, delegates, profile, tickets) **[MOD]** | Same |
| Backend Service | auth, admin, registration, ledger, reconciliation, event/lifecycle, attendance, permissions, queries; funding/pledges, reservations; ticket/sales, pricing, tiers; sponsor/bids, payments, delegates, profile; milestone, discount_strategy, audit, venue **[MOD]** | Add get_logger/log_step; step at mutations, info/warning/debug as appropriate |
| Backend | cache, rate_limit, email_*, escrow*, kyc_verification, notification_service, payment_gateway, push_notification, refund_retry, ticket_crypto, ticket_escrow, sponsor_escrow; event/organizers, event/crud; worker/tasks, worker/redis_pool; api/v1/webhooks **[MOD]** | Migrate from `logging.getLogger` to `get_logger` from `app.logger` |

**Log format:** One JSON object per line: `time`, `level`, `logger`, `msg`, plus `extra` fields (e.g. `user_id`, `event_id`) and optional `exception`. Ready for Fluent Bit → OpenSearch.

**Regression risk:** LOW. Additive logging; no change to request/response or business logic. LOG_LEVEL=DEBUG can increase volume.

---

### Organizer dashboard filters (genre + event_id)

**Scope:** Medium. Full-stack filter propagation so KPI cards and manage screens respect dashboard genre/event selection.

| Layer | File | Change |
|-------|------|--------|
| Backend API | `Backend/app/api/v1/users.py` **[MOD]** | `get_my_organizer_ticket_sales`, `get_organizer_pledges`: add `genre`, `event_id` query params; filter via Event join |
| Backend API | `Backend/app/api/v1/sponsors/organizer_views.py` **[MOD]** | `list_organizer_sponsors`: add `genre`, `event_id`; filter via Event.genre / Event.id |
| Backend Service | `Backend/app/services/ticket/sales.py`, `pledges.py`, `sponsor/organizer_queries.py` **[MOD]** | Pass genre/event_id into list queries, filter on Event |
| Frontend API | `FrontEnd/lib/services/api_service.dart` **[MOD]** | `getOrganizerTicketSales`, `getOrganizerPledges`, `getOrganizerSponsors`: optional `genre`, `eventId` params |
| Frontend Router | `FrontEnd/lib/config/router.dart` **[MOD]** | Extract `genre`, `event_id`, `event_title` from query params for ticket-sales, pledges, sponsors routes |
| Frontend Screens | `global_ticket_sales_screen.dart`, `organizer_pledges_screen.dart`, `organizer_sponsors_screen.dart` **[MOD]** | Add genre/eventId/eventTitle to constructors; pass to API; show in subtitle |
| Frontend Home | `FrontEnd/lib/screens/home/home_screen.dart` **[MOD]** | KPI card onTap: include genre + event_id in nav URLs; Total Events card: navigate to event detail when single event selected, else explore with filters |

**Regression risk:** LOW. Additive query params and UI; backward compatible.

---

### Sign-out animation

**Scope:** Small. Replace static "Not signed in" text with an animated sign-out state (icon, "Signing out…", "See you next time!", progress indicator) using `flutter_animate`.

| Layer | File | Change |
|-------|------|--------|
| Frontend | `FrontEnd/lib/screens/home/home_screen.dart` **[MOD]** | In `_buildProfileTab()`, when `user == null` show animated Column (scale/fade/slide) instead of plain text |

**Regression risk:** LOW. Visual only.

---

### Redis caching layer

**Scope:** Medium. Cache-aside for high-traffic read paths; graceful degradation when Redis unavailable.

| Layer | File | Change |
|-------|------|--------|
| Backend | `Backend/app/cache.py` **[NEW]** | Async Redis client: `cache_get`/`cache_set`/`cache_delete`/`cache_delete_pattern`, `cache_json_get`/`cache_json_set`; `init_cache`/`close_cache`; `_enabled` flag + `set_cache_enabled()` |
| Backend | `Backend/app/main.py` **[MOD]** | Lifespan: call `init_cache()` after ARQ pool, `close_cache()` before teardown; bootstrap `cache_enabled` from DB |
| Backend | `Backend/app/config.py` **[MOD]** | Add `CACHE_DEFAULT_TTL` |
| Backend | `Backend/app/services/platform_settings.py` **[MOD]** | `_get_raw()`: cache-aside with `settings:{key}`, TTL from DEFAULTS; `set_value()` invalidate + `set_cache_enabled()` when key is `cache_enabled` |
| Backend | `Backend/app/api/v1/events/crud.py` **[MOD]** | `get_featured_events`: cache JSON by `featured:{sponsorship_only}` (TTL from setting); `get_event`: cache by `event:{id}` (TTL from setting), skip cache for admin; invalidate on PATCH + lifecycle |
| Backend | `Backend/app/api/v1/events/lifecycle.py` **[MOD]** | After each status change: `_invalidate_event_cache(event_id)` (delete `event:{id}` + `featured:*`) |
| Backend | `Backend/app/api/v1/users.py` **[MOD]** | `get_organizer_dashboard`: cache JSON by `dashboard:{organizer_id}:{filters}` (TTL from setting) |

**Cached:** Platform settings (per-key, 5 min), featured events (1 min), event detail (30 s), organizer dashboard (15 s). Admin settings list (`get_all_with_descriptions`) is **not** cached.

**Regression risk:** LOW. Cache misses fall back to DB; invalidation on write.

---

### Cache TTL and enable/disable in admin settings

**Scope:** Small. All TTLs and a master cache toggle configurable in admin panel.

| Layer | File | Change |
|-------|------|--------|
| Backend | `Backend/app/services/platform_settings.py` **[MOD]** | DEFAULTS: `cache_enabled`, `cache_ttl_settings`, `cache_ttl_featured`, `cache_ttl_event_detail`, `cache_ttl_dashboard`; DESCRIPTIONS; `_get_raw()` uses `DEFAULTS["cache_ttl_settings"]` |
| Backend | `Backend/app/api/v1/events/crud.py` **[MOD]** | Featured and event-detail endpoints: TTL from `get_int(db, "cache_ttl_*")` |
| Backend | `Backend/app/api/v1/users.py` **[MOD]** | Dashboard endpoint: TTL from `get_int(db, "cache_ttl_dashboard")` |

**Regression risk:** LOW. Admin-only settings; no frontend change (admin UI auto-renders keys).

---

### Backend query improvements

**Scope:** Medium. Fewer queries and no N+1 on dashboard and organizer flows.

| Layer | File | Change |
|-------|------|--------|
| Backend Models | `ticket.py`, `funding.py`, `sponsor.py`, `bookmark.py` **[MOD]** | Add indexes on status, FKs, composite (event_id, status), (event_id, created_at) |
| Backend | `alembic/versions/yy02y1z2a3b4_add_missing_indexes.py` **[NEW]** | Migration for new indexes |
| Backend | `Backend/app/services/dashboard.py` **[MOD]** | Consolidate ~30 dashboard queries into ~8–10 using conditional aggregation (TicketSale, Funding, SponsorPayment, sponsors, events) |
| Backend | `Backend/app/services/ticket/sales.py` **[MOD]** | `purchase_ticket`: batch reload sales with `TicketSale.id.in_(sale_ids)` + selectinload |
| Backend | `Backend/app/services/funding/pledges.py` **[MOD]** | `get_reserved_spots_for_tiers()` batch helper; `pledge_preview`/`create_pledge` use batch fetches |
| Backend | `Backend/app/services/funding/reservations.py` **[MOD]** | New `get_reserved_spots_for_tiers()` |
| Backend | `Backend/app/services/sponsor/organizer_queries.py` **[MOD]** | `get_organizer_sponsors`: batch profiles + users; `get_sponsor_events_for_organizer` and `get_sponsor_bids_detail_for_admin`: batch bids/categories |

**Regression risk:** LOW–MEDIUM. Logic unchanged; fewer round-trips and better index usage.

---

## Impact Summary Table

| Feature | Status | New Files | Modified Files | New DB Tables | Endpoints Added | Endpoints Modified | Risk Level |
|---------|--------|-----------|---------------|---------------|-----------------|-------------------|------------|
| 0. Privacy | DONE | 0 | 5 | 0 | 0 | 3 | LOW |
| 1. Notifications | DONE | 5 | 8 | 1 | 4 | 13 | MED-HIGH |
| 2. Organizer Profile | DONE | 2 | 4 | 0 | 2 | 0 | LOW |
| 3. Sponsor Info | DONE | 1 | 4 | 0 | 1 | 0 | LOW |
| 4. Prerequisites | DONE | 2 | 6 | 2 | 4 | 1 | MEDIUM |
| 5. Ratings | DONE | 4 | 7 | 1 | 3 | 0 | LOW-MED |
| 6. Bookmarks | DONE | 2 | 5 | 1 | 2 | 0 | LOW |
| 7. Multi-Role | **TODO** | 1 | 12+ | 0 | 2 | 1 (dependencies.py) | **HIGH** |
| Scan Count | DONE | 1 | 3 | 0 | 0 | 1 | LOW |

---

## File Modification Heatmap

Files sorted by how many features touch them:

| File | Features that modify it | Total touches |
|------|------------------------|---------------|
| `Backend/app/api/v1/events.py` | Privacy, F1, F6 | 3 |
| `Backend/app/api/v1/sponsors.py` | Privacy, F1, F4 | 3 |
| `Backend/app/api/v1/users.py` | Privacy, F6, F7 | 3 |
| `Backend/app/api/v1/router.py` | F1, F2, F5 | 3 |
| `Backend/app/models/__init__.py` | F1, F4, F5, F6 | 4 |
| `FrontEnd/lib/services/api_service.dart` | F2, F3, F5, F6, F7 | 5 |
| `FrontEnd/lib/screens/event/event_detail_screen.dart` | F2, F5, F6 | 3 |
| `FrontEnd/lib/screens/home/home_screen.dart` | F1, F6, F7 | 3 |
| `FrontEnd/lib/screens/sponsor/bid_management_screen.dart` | F3, F4 | 2 |
| `FrontEnd/lib/main.dart` | F1 | 1 |
| `FrontEnd/lib/providers/auth_provider.dart` | F7 | 1 |
| `FrontEnd/lib/screens/profile/profile_screen.dart` | F7 | 1 |
| `Backend/app/dependencies.py` | F7 | 1 |

**Hottest files** (most risky due to multiple feature touches):
1. `api_service.dart` — 5 features add methods (low risk, additive only)
2. `models/__init__.py` — 4 features add imports (low risk, additive only)
3. `events.py` backend — 3 features modify (medium risk, notification integration + bookmark endpoint + privacy fix)
4. `event_detail_screen.dart` — 3 features add UI (medium risk, already 6000+ lines)

---

## Implementation Status

```
DONE — BATCH A (Low risk, foundation):
  [x] Step 0: Privacy rules                      (5 files, LOW risk)
  [x] Step 1: Feature 6 — Bookmarks              (7 files, LOW risk)
  [x] Step 2: Feature 2 — Organizer Profile      (6 files, LOW risk)
  [x] Step 3: Scan Count addendum                (4 files, LOW risk)

DONE — BATCH B (Profiles & Prerequisites):
  [x] Step 4: Feature 3 — Sponsor Info           (5 files, LOW risk)
  [x] Step 5: Feature 4 — Prerequisites          (8 files, MED risk)

DONE — BATCH C (Social):
  [x] Step 6: Feature 5 — Ratings                (11 files, LOW-MED risk)

DONE — BATCH D (Notifications):
  [x] Step 7: Feature 1 — Notifications          (13+ files, MED-HIGH risk)
           -> 13 integration points wired, migration applied, frontend complete

DONE — UI/UX Improvements:
  [x] Event creation wizard redesign (5-step multi-step form)
  [x] Unsaved changes dialog, step error indicators, loading states,
      real-time date validation, character count, contextual Next button

DONE — Organizer UX and performance:
  [x] Organizer dashboard filters (genre + event_id) — KPI cards and manage screens
  [x] Sign-out animation (replace "Not signed in" in profile tab)
  [x] Redis caching — platform settings, featured events, event detail, organizer dashboard
  [x] Cache TTL and cache_enabled in admin settings
  [x] Backend query improvements — indexes, consolidated dashboard queries, N+1 fixes

REMAINING — BATCH E (High risk, do last):
  [ ] Step 8: Feature 7 — Multi-Role             (13+ files, HIGH risk)
           -> Full regression test of all role-gated endpoints
```
