# Project Audit Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Fix all bugs, architecture violations, dead code, and design-token violations identified in the 2026-03-31 comprehensive project audit.

**Architecture:** Three independent phases, each producing working/testable software on its own. Phase 1 fixes bugs and validation gaps. Phase 2 removes dead code and fixes architecture violations. Phase 3 fixes frontend design-token violations.

**Tech Stack:** FastAPI + SQLAlchemy (backend), Flutter/Dart (frontend), pytest (backend tests), flutter test (frontend tests)

---

## File Structure

### Phase 1 — Bug Fixes & Validation (Backend + Frontend)
- Modify: `Backend/app/api/v1/events/lifecycle.py` (add start < end validation)
- Modify: `Backend/app/api/v1/ratings.py` (add self-rating guard + direction validation)
- Modify: `FrontEnd/lib/config/router.dart` (fix tab mapping)
- Modify: `FrontEnd/lib/screens/home/home_screen.dart` (fix Tickets tab for customers)
- Test: `Backend/tests/api/test_lifecycle.py`
- Test: `Backend/tests/api/test_ratings.py`

### Phase 2 — Dead Code & Architecture Violations
- Modify: `Backend/app/api/v1/event_polls.py` (remove redundant db.refresh)
- Modify: `Backend/app/api/v1/organizer_faq.py` (remove redundant db.refresh)
- Delete: `FrontEnd/lib/screens/manage/customer_history_screen.dart`
- Delete: `FrontEnd/lib/screens/manage/global_ticket_waitlist_screen.dart`
- Delete: `FrontEnd/lib/screens/event/management/ticket_waitlist_screen.dart`

### Phase 3 — Design Token Compliance (Frontend)
- Modify: `FrontEnd/lib/config/design_tokens.dart` (add missing tokens)
- Modify: 16 screen/widget files (replace hardcoded Color(0x...) with AppTheme tokens)

---

## Phase 1: Bug Fixes & Validation

### Task 1: Fix start_time < end_time validation in lifecycle.py

**Files:**
- Modify: `Backend/app/api/v1/events/lifecycle.py:112-116`
- Test: existing lifecycle tests

- [x] **Step 1: Write the failing test**

Add to the existing lifecycle test file:

```python
async def test_set_event_date_rejects_start_after_end(
    client, org_headers, org_event_id
):
    """start_time must be before end_time."""
    resp = await client.post(
        f"/api/v1/events/{org_event_id}/set-event-date",
        json={
            "start_time": "2026-12-01T20:00:00Z",
            "end_time": "2026-12-01T18:00:00Z",  # before start
        },
        headers=org_headers,
    )
    assert resp.status_code == 400
    assert "start_time must be before end_time" in resp.json()["detail"]
```

- [x] **Step 2: Run the test to verify it fails**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/api/test_lifecycle.py::test_set_event_date_rejects_start_after_end -v`
Expected: FAIL — currently no such validation exists, the endpoint accepts any ordering.

- [x] **Step 3: Add the validation**

In `Backend/app/api/v1/events/lifecycle.py`, after line 116 (the null check), add:

```python
    if new_start >= new_end:
        logger.warning("Set event date rejected: start >= end", extra={"event_id": event_id})
        raise HTTPException(status_code=400, detail="start_time must be before end_time")
```

- [x] **Step 4: Run the test to verify it passes**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/api/test_lifecycle.py::test_set_event_date_rejects_start_after_end -v`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add Backend/app/api/v1/events/lifecycle.py Backend/tests/api/test_lifecycle.py
git commit -m "fix: reject set-event-date when start_time >= end_time"
```

---

### Task 2: Prevent self-rating and validate direction enum in ratings.py

**Files:**
- Modify: `Backend/app/api/v1/ratings.py:43-70`
- Test: existing ratings test file

- [x] **Step 1: Write the failing tests**

```python
async def test_create_rating_rejects_self_rating(
    client, auth_headers, completed_event_id, current_user_id,
):
    """User cannot rate themselves."""
    resp = await client.post(
        f"/api/v1/events/{completed_event_id}/ratings",
        json={
            "direction": "attendee_to_organizer",
            "rated_user_id": current_user_id,
            "stars": 5,
        },
        headers=auth_headers,
    )
    assert resp.status_code == 400
    assert "cannot rate yourself" in resp.json()["detail"].lower()


async def test_create_rating_rejects_invalid_direction(
    client, auth_headers, completed_event_id,
):
    """Invalid direction string should return 400, not 500."""
    resp = await client.post(
        f"/api/v1/events/{completed_event_id}/ratings",
        json={"direction": "invalid_direction", "stars": 3},
        headers=auth_headers,
    )
    assert resp.status_code == 400
    assert "direction" in resp.json()["detail"].lower()
```

- [x] **Step 2: Run tests to verify they fail**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/api/test_ratings.py::test_create_rating_rejects_self_rating tests/api/test_ratings.py::test_create_rating_rejects_invalid_direction -v`
Expected: FAIL

- [x] **Step 3: Add both validations**

In `Backend/app/api/v1/ratings.py`, in `create_rating()`, after the event status check (around line 50) and before the `RatingDirection(body.direction)` call, add:

```python
    # Validate direction enum
    try:
        direction = RatingDirection(body.direction)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid direction: {body.direction}")

    # Prevent self-rating
    if body.rated_user_id and body.rated_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot rate yourself")
```

Remove the old `direction = RatingDirection(body.direction)` line that was previously after the duplicate check.

- [x] **Step 4: Run tests to verify they pass**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/api/test_ratings.py -v`
Expected: ALL PASS

- [x] **Step 5: Commit**

```bash
git add Backend/app/api/v1/ratings.py Backend/tests/api/test_ratings.py
git commit -m "fix: validate rating direction enum and prevent self-rating"
```

---

### Task 3: Fix router tab mapping and customer Tickets tab

**Files:**
- Modify: `FrontEnd/lib/config/router.dart:124`
- Modify: `FrontEnd/lib/screens/home/home_screen.dart:201-204`

- [x] **Step 1: Fix the router tab mapping**

In `FrontEnd/lib/config/router.dart` line 124, remove the 'profile' key (profile has its own `/profile` route — it should not map to a tab):

```dart
// Before:
final idx = {'explore': 1, 'manage': 2, 'channel': 3, 'profile': 3}[tab] ?? 0;

// After:
final idx = {'explore': 1, 'manage': 2, 'channel': 3, 'tickets': 3}[tab] ?? 0;
```

This maps `?tab=tickets` to index 3 for customers, and `?tab=channel` to index 3 for org/sponsors.

- [x] **Step 2: Fix the customer Tickets tab content**

In `FrontEnd/lib/screens/home/home_screen.dart`, the IndexedStack child at index 3 currently shows `SizedBox.shrink()` for customers. Replace lines 201-204:

```dart
// Before:
if (hasChatTab)
  const ConversationsScreen(embedded: true)
else
  const SizedBox.shrink(),

// After:
if (hasChatTab)
  const ConversationsScreen(embedded: true)
else
  MyEventsTab(
    bookmarkedIds: _bookmarkedIds,
    onToggleBookmark: _toggleBookmark,
    onBookmarksSynced: (ids) =>
        setState(() => _bookmarkedIds.addAll(ids)),
    genres: _genres,
    headerIcons: _buildHeaderIcons(hasChatTab),
    initialTab: 1, // Start on Tickets sub-tab
  ),
```

Note: Check if `MyEventsTab` supports an `initialTab` parameter. If it does, use `1` to open on the tickets sub-tab. If not, you may need to add this parameter or use a dedicated tickets-only widget.

**Alternative (simpler):** If `MyEventsTab` already exists at index 2 for customers, and index 3 "Tickets" is meant to be a distinct view, check whether a dedicated `MyTicketsTab` or similar widget should be used instead. The key point is: index 3 must NOT be `SizedBox.shrink()` when the nav bar says "Tickets".

- [x] **Step 3: Run flutter analyze**

Run: `cd FrontEnd && flutter analyze lib/config/router.dart lib/screens/home/home_screen.dart`
Expected: No errors

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/config/router.dart FrontEnd/lib/screens/home/home_screen.dart
git commit -m "fix: router tab mapping and customer Tickets tab shows real content"
```

---

## Phase 2: Dead Code & Architecture Violations

### Task 4: Remove redundant db.refresh() from organizer_faq.py routes

**Files:**
- Modify: `Backend/app/api/v1/organizer_faq.py:32-33,48-49`

The FAQ repository already calls `db.refresh(faq)` internally in both `create()` (line 42) and `update()` (line 48). The route calls at lines 33 and 49 are redundant double-refreshes.

- [x] **Step 1: Run existing tests to establish baseline**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/api/test_organizer_faq.py -v`
Expected: ALL PASS

- [x] **Step 2: Remove the redundant refreshes**

In `Backend/app/api/v1/organizer_faq.py`:

Line 33 — remove `await db.refresh(faq)` from `create_faq()`:
```python
# Before (lines 31-34):
    faq = await faq_service.create(db, current_user.id, body)
    await db.commit()
    await db.refresh(faq)
    return OrganizerFaqResponse.model_validate(faq)

# After:
    faq = await faq_service.create(db, current_user.id, body)
    await db.commit()
    return OrganizerFaqResponse.model_validate(faq)
```

Line 49 — remove `await db.refresh(faq)` from `update_faq()`:
```python
# Before (lines 47-50):
    faq = await faq_service.update(db, faq, body)
    await db.commit()
    await db.refresh(faq)
    return OrganizerFaqResponse.model_validate(faq)

# After:
    faq = await faq_service.update(db, faq, body)
    await db.commit()
    return OrganizerFaqResponse.model_validate(faq)
```

- [x] **Step 3: Run tests to verify nothing broke**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/api/test_organizer_faq.py -v`
Expected: ALL PASS

- [x] **Step 4: Commit**

```bash
git add Backend/app/api/v1/organizer_faq.py
git commit -m "fix: remove redundant db.refresh in FAQ routes (repo already refreshes)"
```

---

### Task 5: Remove redundant db.refresh() from event_polls.py routes

**Files:**
- Modify: `Backend/app/api/v1/event_polls.py:70,96,116`

The poll repository already calls `db.refresh()` inside `create()` (line 61) and `close()` (line 70). The route refreshes at lines 70, 96, and 116 are redundant.

For `cast_vote` (line 96): the route calls `poll_service.vote()` which delegates to `event_poll_repo.cast_vote()` — that refreshes the **vote**, not the **poll**. The route then refreshes the poll to pick up the new vote count. However, the next lines immediately call `get_tally()` and `get_vote()` which query fresh data anyway. So the refresh is unnecessary.

- [x] **Step 1: Run existing tests to establish baseline**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/api/test_event_polls.py -v`
Expected: ALL PASS

- [x] **Step 2: Remove the redundant refreshes**

In `Backend/app/api/v1/event_polls.py`:

Line 70 — remove from `create_poll()`:
```python
# Before (lines 68-70):
    poll = await poll_service.create_poll(db, event, current_user.id, body)
    await db.commit()
    await db.refresh(poll)

# After:
    poll = await poll_service.create_poll(db, event, current_user.id, body)
    await db.commit()
```

Line 96 — remove from `cast_vote()`:
```python
# Before (lines 94-96):
    await poll_service.vote(db, poll, current_user.id, body)
    await db.commit()
    await db.refresh(poll)

# After:
    await poll_service.vote(db, poll, current_user.id, body)
    await db.commit()
```

Line 116 — remove from `close_poll()`:
```python
# Before (lines 114-116):
    poll = await poll_service.close_poll(db, poll)
    await db.commit()
    await db.refresh(poll)

# After:
    poll = await poll_service.close_poll(db, poll)
    await db.commit()
```

- [x] **Step 3: Run tests to verify nothing broke**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/api/test_event_polls.py -v`
Expected: ALL PASS

- [x] **Step 4: Commit**

```bash
git add Backend/app/api/v1/event_polls.py
git commit -m "fix: remove redundant db.refresh in poll routes (repo already refreshes)"
```

---

### Task 6: Delete dead screens

**Files:**
- Delete: `FrontEnd/lib/screens/manage/customer_history_screen.dart`
- Delete: `FrontEnd/lib/screens/manage/global_ticket_waitlist_screen.dart`
- Delete: `FrontEnd/lib/screens/event/management/ticket_waitlist_screen.dart`

These screens are not referenced in `router.dart`, not pushed via `Navigator` from any other screen, and have been superseded:
- `GlobalTicketWaitlistScreen` → superseded by `GlobalWaitlistScreen(initialTicketView: true)`
- `TicketWaitlistScreen` → superseded by `WaitlistScreen(initialTicketView: true)`
- `CustomerHistoryScreen` → no references anywhere

**Important:** `SplashScreen`, `NotificationScreen`, `VenuePickerScreen`, `StrategyPickerScreen`, and `SponsorPaymentReceiptScreen` are NOT dead — they are used via `MaterialPageRoute` pushes from other screens. Do NOT delete them.

- [x] **Step 1: Verify no references exist (besides self-references)**

Run:
```bash
cd FrontEnd && grep -rn "CustomerHistoryScreen\|GlobalTicketWaitlistScreen\|TicketWaitlistScreen" lib/ --include="*.dart" | grep -v "customer_history_screen.dart" | grep -v "global_ticket_waitlist_screen.dart" | grep -v "ticket_waitlist_screen.dart"
```
Expected: Zero results (no references from other files)

- [x] **Step 2: Delete the files**

```bash
rm FrontEnd/lib/screens/manage/customer_history_screen.dart
rm FrontEnd/lib/screens/manage/global_ticket_waitlist_screen.dart
rm FrontEnd/lib/screens/event/management/ticket_waitlist_screen.dart
```

- [x] **Step 3: Run flutter analyze to confirm no broken imports**

Run: `cd FrontEnd && flutter analyze`
Expected: No errors related to the deleted files

- [x] **Step 4: Commit**

```bash
git add -A FrontEnd/lib/screens/manage/customer_history_screen.dart FrontEnd/lib/screens/manage/global_ticket_waitlist_screen.dart FrontEnd/lib/screens/event/management/ticket_waitlist_screen.dart
git commit -m "chore: remove 3 dead screens superseded by unified waitlist views"
```

---

## Phase 3: Design Token Compliance

### Task 7: Audit and fix hardcoded colors in funding_card.dart

**Files:**
- Modify: `FrontEnd/lib/screens/event/event_detail/funding_card.dart`
- Modify: `FrontEnd/lib/config/design_tokens.dart` (if new tokens needed)

This file has ~15 hardcoded `Color(0x...)` values. Many are purple/violet variants used for a "premium" funding card aesthetic.

- [x] **Step 1: Read the file and identify all violations**

Read `FrontEnd/lib/screens/event/event_detail/funding_card.dart` and list every `Color(0x...)` usage with its purpose.

- [x] **Step 2: Map each violation to an existing AppTheme token or define new ones**

Mapping guide:
| Hardcoded | Replacement |
|-----------|-------------|
| `Color(0xFF8B5CF6)` / `Color(0xFF7C3AED)` / `Color(0xFF6D28D9)` | `AppTheme.purpleColor` (already exists) |
| `Color(0xFFF5F3FF)` (light purple bg) | `AppTheme.purpleSurface` (already exists) |
| `Color(0xFF0E0B1C)` (dark purple bg) | `AppTheme._dkPurpleSurface` — use `AppTheme.purpleSurfaceOf(context)` |
| `Color(0xFF1C1C1E)` (dark text) | `AppTheme.textPrimaryOf(context)` |
| `Color(0xFFE4E4F0)` (light border) | `Theme.of(context).dividerColor` |

If `AppTheme.purpleSurfaceOf(context)` doesn't exist, add it to `theme.dart`:
```dart
static Color purpleSurfaceOf(BuildContext context) =>
    isDark(context) ? _dkPurpleSurface : purpleSurface;
```

- [x] **Step 3: Replace all hardcoded colors with tokens**

Replace each `Color(0x...)` with the mapped AppTheme token. Use `AppTheme.isDark(context)` ternaries only where theme helpers don't exist.

- [x] **Step 4: Run flutter analyze**

Run: `cd FrontEnd && flutter analyze lib/screens/event/event_detail/funding_card.dart`
Expected: No errors

- [x] **Step 5: Commit**

```bash
git add FrontEnd/lib/screens/event/event_detail/funding_card.dart FrontEnd/lib/config/theme.dart
git commit -m "refactor: replace hardcoded colors in funding_card with AppTheme tokens"
```

---

### Task 8: Fix hardcoded colors in funding_card_helpers.dart

**Files:**
- Modify: `FrontEnd/lib/screens/event/event_detail/funding_card_helpers.dart`

- [x] **Step 1: Read the file and identify violations (~8 hardcoded colors)**

Milestone colors around lines 171-215.

- [x] **Step 2: Replace with AppTheme tokens**

| Hardcoded | Replacement |
|-----------|-------------|
| `Color(0xFF10B981)` / `Color(0xFF34D399)` (greens) | `AppTheme.secondaryColor` / `AppTheme.successColor` |
| `Color(0xFF6D28D9)` / `Color(0xFFA78BFA)` (purples) | `AppTheme.purpleColor` |

- [x] **Step 3: Run flutter analyze**

Run: `cd FrontEnd && flutter analyze lib/screens/event/event_detail/funding_card_helpers.dart`
Expected: No errors

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/event/event_detail/funding_card_helpers.dart
git commit -m "refactor: replace hardcoded colors in funding_card_helpers with AppTheme tokens"
```

---

### Task 9: Fix hardcoded colors in getting_there_card.dart

**Files:**
- Modify: `FrontEnd/lib/screens/event/event_detail/getting_there_card.dart`

This file has ~12 hardcoded colors for a map placeholder. These are decorative/illustrative, but should still use tokens where possible.

- [x] **Step 1: Read the file and categorize violations**

- [x] **Step 2: Replace with tokens**

| Hardcoded | Replacement |
|-----------|-------------|
| `Color(0xFF1C1C1E)` | `AppTheme.textPrimaryOf(context)` |
| `Color(0xFFEF5350)` (red) | `AppTheme.errorColor` |
| Map colors (water, park, road) | These are illustrative — add a `_MapColors` class at the top of the file to consolidate, or accept as-is since they're visual constants for a static illustration |

- [x] **Step 3: Run flutter analyze, commit**

```bash
git add FrontEnd/lib/screens/event/event_detail/getting_there_card.dart
git commit -m "refactor: consolidate hardcoded colors in getting_there_card"
```

---

### Task 10: Fix hardcoded colors in remaining files

**Files (do in one pass):**
- Modify: `FrontEnd/lib/screens/sponsor/sponsor_ticket/sponsor_ticket_card.dart`
- Modify: `FrontEnd/lib/widgets/event/event_bottom_strip.dart`
- Modify: `FrontEnd/lib/screens/event/management/ticket_sales_screen.dart`
- Modify: `FrontEnd/lib/screens/auth/login_screen.dart`
- Modify: `FrontEnd/lib/screens/auth/register_screen.dart`
- Modify: `FrontEnd/lib/widgets/calendar_bottom_sheet.dart`
- Modify: `FrontEnd/lib/screens/sponsor/sponsor_ticket/receipt_header_card.dart`
- Modify: `FrontEnd/lib/screens/sponsor/sponsorship_categories/bid_leaderboard.dart`
- Modify: `FrontEnd/lib/screens/event/event_detail/funding_results_card.dart`
- Modify: `FrontEnd/lib/screens/profile/profile_contact_section.dart`
- Modify: `FrontEnd/lib/screens/profile/organizer_profile_screen.dart`
- Modify: `FrontEnd/lib/screens/profile/sponsor_profile_screen.dart`

- [x] **Step 1: For each file, read and identify Color(0x...) violations**

- [x] **Step 2: Replace with AppTheme tokens per the mapping guide**

General mapping:
| Hardcoded | Replacement |
|-----------|-------------|
| `Color(0xFF276EF1)` | `AppTheme.accentColor` |
| `Color(0xFFE11900)` | `AppTheme.errorColor` |
| `Color(0xFF05944F)` | `AppTheme.secondaryColor` |
| `Color(0xFFFFC043)` | `AppTheme.warningColor` |
| `Color(0xFF9333EA)` | `AppTheme.purpleColor` |
| `Color(0xFFFF8C00)` | `AppTheme.orangeColor` |
| `Color(0xFF0D3B66)` / `Color(0xFF1B5E8A)` (dark blues) | `AppTheme.accentColor` variant or add `AppTheme.navyColor` |
| `Color(0xFF4285F4)` (Google blue) | Keep — brand-specific color for Google Calendar |
| `Color(0xFFEA4335)` (Google red) | Keep — brand-specific color for Gmail |
| `Color(0xFF25D366)` (WhatsApp green) | Keep — brand-specific color for WhatsApp |
| `Color(0xFF1A1A2E)` (dark bg) | `AppTheme.isDark(context) ? ... : ...` pattern with existing tokens |
| `Color(0xFFF0F0F0)` / `Color(0xFF0F0F0F)` | `AppTheme.frostedBg(isDark)` |
| `Color(0xFF5C3000)` (custom brown) | `AppTheme.warningColor` dark variant or add to theme |

Note: Social media brand colors (Google, WhatsApp) are exceptions — they're externally-defined brand identities. Move them to a `_BrandColors` class within `share_bottom_sheet.dart` with a comment explaining why.

- [x] **Step 3: Run flutter analyze on all modified files**

Run: `cd FrontEnd && flutter analyze`
Expected: No errors

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/ FrontEnd/lib/widgets/ FrontEnd/lib/config/
git commit -m "refactor: replace hardcoded colors across 12 files with AppTheme tokens"
```

---

### Task 11: Merge duplicate stat card widgets

**Files:**
- Modify: `FrontEnd/lib/widgets/admin/admin_stat_card.dart`
- Delete: `FrontEnd/lib/widgets/admin/admin_kpi_card.dart`
- Modify: `FrontEnd/lib/widgets/animated_stat_card.dart`
- Modify: All files that import `admin_kpi_card.dart`

`AdminStatCard` and `AdminKpiCard` serve nearly identical purposes (icon + value + label with left border accent). Merge `AdminKpiCard` into `AdminStatCard` by adding a `layout` parameter.

- [x] **Step 1: Find all usages of AdminKpiCard**

```bash
cd FrontEnd && grep -rn "AdminKpiCard" lib/ --include="*.dart"
```

- [x] **Step 2: Add a `horizontal` parameter to AdminStatCard**

```dart
class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final bool horizontal; // NEW — when true, renders in horizontal row layout
  const AdminStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.horizontal = false,
  });
  // ...
}
```

- [x] **Step 3: Update all AdminKpiCard usages to use AdminStatCard(horizontal: true)**

- [x] **Step 4: Delete admin_kpi_card.dart**

- [x] **Step 5: Run flutter analyze, commit**

```bash
git add FrontEnd/lib/widgets/admin/
git commit -m "refactor: merge AdminKpiCard into AdminStatCard with horizontal layout option"
```

---

## Verification (run after each phase)

- [x] **Backend tests:** `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest -v --tb=short`
- [x] **Frontend analyze:** `cd FrontEnd && flutter analyze`
- [x] **Frontend tests:** `cd FrontEnd && flutter test`
- [x] **Architecture check:** Run `/check-architecture` to confirm zero violations
- [x] **Color check:** Run `/check-colors` to confirm reduced violations

---

## Out of Scope (tracked for future plans)

These were identified in the audit but are lower priority or require more design discussion:

1. **Extract paginated list mixin** for 5+ frontend manage screens (~1000 lines of duplicate pagination boilerplate) — needs design for what the mixin API looks like
2. **Extract authorization helper** for 40+ backend route checks — needs agreement on dependency injection approach
3. **Replace hardcoded spacing with AppSpacing tokens** — ~2,250 instances, very large mechanical change
4. **Add deep linking support** — requires Flutter deep link configuration + backend URL handling
5. **Standardize provider state** — TicketProvider, SponsorProvider, AdminProvider are pass-through; needs design for what state to add
6. **Merge EmptyState and AdminEmptyState** — low priority, small impact
7. **Add missing API endpoints** — DELETE for polls, bulk mark-read for notifications, sponsor category detail GET
8. **Consolidate escrow services** — release_stage2/3 across escrow.py, ticket_escrow.py, sponsor_escrow.py could use generic_release_stage (stage 1 in fund escrow has unique trust-score logic)
