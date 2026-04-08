# UX & Performance Hardening — Design Spec

**Date:** 2026-04-07
**Goal:** Fix verified UX gaps and backend query inefficiencies across the crowd-funding event platform.

---

## Phase 1 — Backend: Merge Funding Aggregate Queries

**Problem:** Event list, featured, and detail endpoints each call `get_pledged_totals_for_events` and `get_total_reserved_spots_for_events` as separate queries. Both hit the `Funding` table with identical WHERE clauses (`event_id IN (...) AND status = pledged, GROUP BY event_id`).

**Fix:** Create a single `get_funding_aggregates_for_events(db, event_ids) -> dict[int, tuple[int, int]]` in `funding_repo.py` that returns `{event_id: (total_cents, reserved_spots)}` in one query. Update the 3 callers in `events/crud.py` (list, featured, detail) and the corresponding service methods.

**Files:**
- `Backend/app/repositories/funding_repo.py` — add combined method
- `Backend/app/services/funding/summary.py` — add service wrapper
- `Backend/app/services/funding/reservations.py` — update to use combined method (or deprecate)
- `Backend/app/api/v1/events/crud.py` — update 3 endpoints

---

## Phase 2 — Backend: Add Pagination to Unbounded Endpoints

**Problem:** Two list endpoints return all rows without offset/limit.

| Endpoint | File |
|----------|------|
| `GET /{event_id}/registrations` | `Backend/app/api/v1/events/registration.py:119` |
| `GET /{event_id}/posts` | `Backend/app/api/v1/events/posts.py:15` |

**Fix:** Add `offset: int = Query(0, ge=0)` and `limit: int = Query(20, ge=1, le=100)` to both endpoints. Pass through to service → repo. Return paginated results.

**Files:**
- `Backend/app/api/v1/events/registration.py`
- `Backend/app/services/registration.py` (or wherever `list_registrations` lives)
- `Backend/app/repositories/` (registration repo)
- `Backend/app/api/v1/events/posts.py`
- `Backend/app/services/post.py`
- `Backend/app/repositories/event_repo.py` (post listing method)

---

## Phase 3 — Frontend: Fix Silent Errors on Event Detail

**Problem:** `event_detail_screen.dart` has 7 async methods that catch errors with `debugPrint` only. The user gets no feedback.

**Fix:** Add `AppToast.error` to `_toggleBookmark` (user-initiated action that should show failure). Leave supplementary data loads (`_loadImages`, `_checkBookmark`, `_checkRegistration`, `_loadMyTicketCount`, `_loadMyReservedSpots`, `_loadRevenue`) silent since the screen works without them.

**File:** `FrontEnd/lib/screens/event/event_detail_screen.dart`

---

## Phase 4 — Frontend: Debounce Explore Tab Filters

**Problem:** Every filter chip tap immediately calls `loadEvents()`. Rapid tapping sends multiple API calls with no debounce.

**Fix:** Add a `Timer? _debounce` field. In `_applyFilters()`, cancel the previous timer and set a new 300ms timer that calls `loadEvents()`. Dispose the timer in `dispose()`.

**File:** `FrontEnd/lib/screens/home/tabs/explore_tab.dart`

---

## Phase 5 — Frontend: Fix Event Feed shrinkWrap Performance

**Problem:** Event feed renders all posts with `shrinkWrap: true` + `NeverScrollableScrollPhysics()` inside a CustomScrollView. With 200+ posts, all widgets are built eagerly.

**Fix:** Limit displayed posts to an initial batch (10). Add a "Show more posts" button at the bottom that reveals the next 10. This avoids rebuilding the scroll hierarchy while keeping memory bounded.

**File:** `FrontEnd/lib/screens/event/event_detail/event_feed_section.dart`

---

## Phase 6 — Frontend: Home Tab Empty State for Featured Sections

**Problem:** When all featured sections (trending, popular, coming soon) return empty after loading, the user sees a blank scroll area with no feedback.

**Fix:** After `_featuredLoading == false`, if all 3 lists are empty, show a centered empty state widget with message and refresh button.

**File:** `FrontEnd/lib/screens/home/tabs/home_tab.dart`

---

## Out of Scope

- Admin user detail unbounded nested lists (admin-only, low traffic)
- EventImage list pagination (images are capped by `event_max_images` setting)
- Provider unbounded list growth (theoretical — mobile users rarely scroll 1000+ items)
- Denormalizing aggregates onto Event model (large migration, separate effort)
