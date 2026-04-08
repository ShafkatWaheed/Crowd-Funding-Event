# Validation Hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add missing input validation (numeric bounds, string lengths) to backend Pydantic schemas, fix silent error swallowing in frontend event creation, and clear provider caches on logout to prevent cross-user data leakage.

**Architecture:** Three independent phases. Phase 1 adds Pydantic field validators to all backend schemas — pure schema changes with no route/service modifications. Phase 2 fixes the frontend event creation silent-fail catch blocks. Phase 3 adds logout cache clearing to providers. Each phase is independently testable.

**Tech Stack:** Pydantic v2 Field validators (backend), Flutter/Dart (frontend), pytest (backend tests)

---

## File Structure

### Phase 1 — Backend Schema Validation (7 files)
- Modify: `Backend/app/schemas/event.py` (add bounds to EventCreate, EventUpdate)
- Modify: `Backend/app/schemas/funding.py` (add bounds to PledgeBody, TierReservation)
- Modify: `Backend/app/schemas/sponsor.py` (add bounds to CategoryCreate, BidCreate, SponsorProfileCreate)
- Modify: `Backend/app/schemas/ticket_strategy.py` (add bounds to TicketStrategyTierInput)
- Modify: `Backend/app/schemas/discount_strategy.py` (add bounds to DiscountStrategyCreate)
- Test: `Backend/tests/test_schema_validation.py` (new)

### Phase 2 — Frontend Silent Error Fixes (1 file)
- Modify: `FrontEnd/lib/screens/event/create_event/create_event_submit.dart`

### Phase 3 — Logout Cache Clearing (3 files)
- Modify: `FrontEnd/lib/providers/auth_provider.dart`
- Modify: `FrontEnd/lib/providers/event_provider.dart`
- Modify: `FrontEnd/lib/providers/pledge_provider.dart`

### Phase 4 — Frontend Form Validators (4 files)
- Modify: `FrontEnd/lib/screens/event/create_event/step_funding.dart`
- Modify: `FrontEnd/lib/screens/venue/create_venue_screen.dart`
- Modify: `FrontEnd/lib/screens/sponsor/sponsorship_categories/place_bid_dialog.dart`
- Modify: `FrontEnd/lib/screens/event/create_event/funding_tier_section.dart`

---

## Phase 1: Backend Schema Validation

### Task 1: Add numeric bounds and string limits to EventCreate and EventUpdate

**Files:**
- Modify: `Backend/app/schemas/event.py:36-83` (EventCreate) and `:85-124` (EventUpdate)
- Test: `Backend/tests/test_schema_validation.py` (new)

- [x] **Step 1: Write failing tests**

Create `Backend/tests/test_schema_validation.py`:

```python
"""Tests for Pydantic schema field validators — no DB needed."""
import pytest
from pydantic import ValidationError

from app.schemas.event import EventCreate, EventUpdate, CancelBody


class TestEventCreateBounds:
    def test_title_too_long(self):
        with pytest.raises(ValidationError, match="title"):
            EventCreate(venue_id=1, title="x" * 201, max_capacity=100)

    def test_title_empty(self):
        with pytest.raises(ValidationError, match="title"):
            EventCreate(venue_id=1, title="", max_capacity=100)

    def test_description_too_long(self):
        with pytest.raises(ValidationError, match="description"):
            EventCreate(venue_id=1, title="OK", max_capacity=100, description="x" * 10_001)

    def test_max_capacity_zero(self):
        with pytest.raises(ValidationError, match="max_capacity"):
            EventCreate(venue_id=1, title="OK", max_capacity=0)

    def test_max_capacity_negative(self):
        with pytest.raises(ValidationError, match="max_capacity"):
            EventCreate(venue_id=1, title="OK", max_capacity=-1)

    def test_funding_goal_negative(self):
        with pytest.raises(ValidationError, match="funding_goal_cents"):
            EventCreate(venue_id=1, title="OK", max_capacity=100, funding_goal_cents=-1)

    def test_min_pledge_zero(self):
        with pytest.raises(ValidationError, match="min_pledge_cents"):
            EventCreate(venue_id=1, title="OK", max_capacity=100, min_pledge_cents=0)

    def test_discount_percent_over_100(self):
        with pytest.raises(ValidationError, match="common_discount_percent"):
            EventCreate(venue_id=1, title="OK", max_capacity=100, common_discount_percent=101)

    def test_pledge_discount_percent_negative(self):
        with pytest.raises(ValidationError, match="pledge_discount_percent"):
            EventCreate(venue_id=1, title="OK", max_capacity=100, pledge_discount_percent=-1)

    def test_min_age_negative(self):
        with pytest.raises(ValidationError, match="min_age"):
            EventCreate(venue_id=1, title="OK", max_capacity=100, min_age=-1)

    def test_min_age_over_120(self):
        with pytest.raises(ValidationError, match="min_age"):
            EventCreate(venue_id=1, title="OK", max_capacity=100, min_age=121)

    def test_valid_event_create(self):
        e = EventCreate(venue_id=1, title="My Event", max_capacity=100)
        assert e.title == "My Event"
        assert e.max_capacity == 100


class TestCancelBodyBounds:
    def test_reason_too_long(self):
        with pytest.raises(ValidationError, match="reason"):
            CancelBody(reason="x" * 2001)

    def test_reason_empty(self):
        with pytest.raises(ValidationError, match="reason"):
            CancelBody(reason="")
```

- [x] **Step 2: Run tests to verify they fail**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_schema_validation.py -v`
Expected: FAIL — no validators exist yet.

- [x] **Step 3: Add Field validators to EventCreate**

In `Backend/app/schemas/event.py`, update the import and field definitions:

```python
from pydantic import BaseModel, Field, model_validator

class EventCreate(BaseModel):
    venue_id: int
    title: str = Field(..., min_length=1, max_length=200)
    description: str | None = Field(None, max_length=10_000)
    start_time: str | None = None
    end_time: str | None = None
    funding_goal_cents: int | None = Field(None, ge=0)
    funding_end_at: str | None = None
    min_pledge_cents: int = Field(500, ge=1)
    registration_type: Literal["open", "closed"] = "open"
    max_capacity: int = Field(..., ge=1, le=1_000_000)
    max_reserved_spots_per_user: int = Field(0, ge=0)
    common_discount_percent: int = Field(0, ge=0, le=100)
    pledge_discount_percent: int = Field(0, ge=0, le=100)
    genre: str | None = None
    community_rules: bool = False
    posts_enabled: bool = True
    faq_enabled: bool = False
    refund_deadline_days: int | None = Field(None, ge=0)
    ticket_strategy_id: int | None = None
    parking_info: str | None = Field(None, max_length=2000)
    transit_info: str | None = Field(None, max_length=2000)
    rideshare_info: str | None = Field(None, max_length=2000)
    accessibility_info: str | None = Field(None, max_length=2000)
    has_schedule: bool = False
    link_funding_to_tiers: bool = False
    max_discount_percent: int = Field(100, ge=0, le=100)
    age_restricted: bool = False
    min_age: int = Field(18, ge=0, le=120)
    waitlist_max_size: int | None = Field(None, ge=1)
    waitlist_auto_approve: bool = True
    event_max_images: int | None = Field(None, ge=1)
    max_posts_per_day: int | None = Field(None, ge=1)
    max_co_organizers: int | None = Field(None, ge=1)
    refund_deadline_percent: int | None = Field(None, ge=0, le=100)
    reserved_spots_release_percent: int | None = Field(None, ge=0, le=100)
    release_tier_spot_limits: bool = False
    is_private: bool = False
    publish: bool = False

    # existing model_validator stays unchanged
```

Apply the same `Field()` constraints to `EventUpdate` for all optional fields (use `Field(None, ...)` pattern).

Update `CancelBody`:
```python
class CancelBody(BaseModel):
    reason: str = Field(..., min_length=1, max_length=2000)
```

- [x] **Step 4: Run tests to verify they pass**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_schema_validation.py -v`
Expected: ALL PASS

- [x] **Step 5: Run full backend test suite to check for regressions**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest -v --tb=short`
Expected: ALL PASS — existing tests that create events/venues should still work since we're only adding lower/upper bounds, not changing defaults.

**IMPORTANT:** If any existing tests break because they use values outside the new bounds (e.g., a test that creates an event with `max_capacity=0`), fix those test values to be within bounds.

- [x] **Step 6: Commit**

```bash
git add Backend/app/schemas/event.py Backend/tests/test_schema_validation.py
git commit -m "fix: add numeric bounds and string length limits to EventCreate/EventUpdate schemas"
```

---

### Task 2: Add bounds to funding, sponsor, ticket, and discount schemas

**Files:**
- Modify: `Backend/app/schemas/funding.py:7-15`
- Modify: `Backend/app/schemas/sponsor.py:9-84`
- Modify: `Backend/app/schemas/ticket_strategy.py:6-11`
- Modify: `Backend/app/schemas/discount_strategy.py:5-8`
- Test: `Backend/tests/test_schema_validation.py` (append)

- [x] **Step 1: Write failing tests**

Append to `Backend/tests/test_schema_validation.py`:

```python
from app.schemas.funding import PledgeBody, TierReservation
from app.schemas.sponsor import (
    SponsorProfileCreate, CategoryCreate, BidCreate,
)
from app.schemas.ticket_strategy import TicketStrategyTierInput
from app.schemas.discount_strategy import DiscountStrategyCreate


class TestPledgeBodyBounds:
    def test_amount_negative(self):
        with pytest.raises(ValidationError, match="amount_cents"):
            PledgeBody(amount_cents=-1)

    def test_amount_zero(self):
        with pytest.raises(ValidationError, match="amount_cents"):
            PledgeBody(amount_cents=0)

    def test_reserved_spots_negative(self):
        with pytest.raises(ValidationError, match="reserved_spots"):
            PledgeBody(amount_cents=500, reserved_spots=-1)

    def test_tier_spots_zero(self):
        with pytest.raises(ValidationError, match="spots"):
            TierReservation(tier_id=1, spots=0)

    def test_valid_pledge(self):
        p = PledgeBody(amount_cents=1000, reserved_spots=2)
        assert p.amount_cents == 1000


class TestSponsorBounds:
    def test_company_name_empty(self):
        with pytest.raises(ValidationError, match="company_name"):
            SponsorProfileCreate(
                company_name="", contact_name="A", profession="B"
            )

    def test_company_name_too_long(self):
        with pytest.raises(ValidationError, match="company_name"):
            SponsorProfileCreate(
                company_name="x" * 201, contact_name="A", profession="B"
            )

    def test_category_spots_zero(self):
        with pytest.raises(ValidationError, match="total_spots"):
            CategoryCreate(name="Gold", total_spots=0, min_bid_cents=100)

    def test_category_min_bid_negative(self):
        with pytest.raises(ValidationError, match="min_bid_cents"):
            CategoryCreate(name="Gold", total_spots=5, min_bid_cents=-1)

    def test_bid_amount_zero(self):
        with pytest.raises(ValidationError, match="amount_cents"):
            BidCreate(amount_cents=0)

    def test_bid_proposal_too_long(self):
        with pytest.raises(ValidationError, match="proposal_text"):
            BidCreate(amount_cents=1000, proposal_text="x" * 5001)


class TestTicketStrategyBounds:
    def test_tier_price_negative(self):
        with pytest.raises(ValidationError, match="price_cents"):
            TicketStrategyTierInput(name="VIP", price_cents=-1)

    def test_tier_name_empty(self):
        with pytest.raises(ValidationError, match="name"):
            TicketStrategyTierInput(name="", price_cents=1000)


class TestDiscountStrategyBounds:
    def test_value_zero(self):
        with pytest.raises(ValidationError, match="value"):
            DiscountStrategyCreate(name="10off", discount_type="ticket_percent", value=0)

    def test_name_empty(self):
        with pytest.raises(ValidationError, match="name"):
            DiscountStrategyCreate(name="", discount_type="ticket_percent", value=10)
```

- [x] **Step 2: Run tests to verify they fail**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_schema_validation.py -v -k "not TestEventCreate and not TestCancelBody"`
Expected: FAIL

- [x] **Step 3: Add Field validators to all schemas**

**`Backend/app/schemas/funding.py`:**
```python
from pydantic import BaseModel, Field

class TierReservation(BaseModel):
    tier_id: int
    spots: int = Field(..., ge=1)

class PledgeBody(BaseModel):
    amount_cents: int = Field(..., ge=1)
    reserved_spots: int = Field(0, ge=0)
    tier_reservations: list[TierReservation] | None = None
```

**`Backend/app/schemas/sponsor.py`:**
```python
from pydantic import BaseModel, ConfigDict, Field

class SponsorProfileCreate(BaseModel):
    company_name: str = Field(..., min_length=1, max_length=200)
    contact_name: str = Field(..., min_length=1, max_length=200)
    profession: str = Field(..., min_length=1, max_length=200)
    logo_url: str | None = Field(None, max_length=2000)
    description: str | None = Field(None, max_length=5000)
    website_url: str | None = Field(None, max_length=2000)

class SponsorProfileUpdate(BaseModel):
    company_name: str | None = Field(None, min_length=1, max_length=200)
    contact_name: str | None = Field(None, min_length=1, max_length=200)
    profession: str | None = Field(None, min_length=1, max_length=200)
    logo_url: str | None = Field(None, max_length=2000)
    description: str | None = Field(None, max_length=5000)
    website_url: str | None = Field(None, max_length=2000)

class CategoryCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str | None = Field(None, max_length=5000)
    image_url: str | None = Field(None, max_length=2000)
    total_spots: int = Field(..., ge=1)
    min_bid_cents: int = Field(..., ge=0)
    sort_order: int = 0

class CategoryUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = Field(None, max_length=5000)
    image_url: str | None = Field(None, max_length=2000)
    total_spots: int | None = Field(None, ge=1)
    min_bid_cents: int | None = Field(None, ge=0)
    sort_order: int | None = None

class BidCreate(BaseModel):
    amount_cents: int = Field(..., ge=1)
    proposal_text: str | None = Field(None, max_length=5000)

class BidUpdate(BaseModel):
    amount_cents: int | None = Field(None, ge=1)
    proposal_text: str | None = Field(None, max_length=5000)
```

**`Backend/app/schemas/ticket_strategy.py`:**
```python
from pydantic import BaseModel, Field

class TicketStrategyTierInput(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str | None = Field(None, max_length=2000)
    price_cents: int = Field(..., ge=0)  # 0 = free tier
    display_order: int = 0

class TicketStrategyCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    tiers: list[TicketStrategyTierInput]

class TicketStrategyUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    tiers: list[TicketStrategyTierInput] | None = None
```

**`Backend/app/schemas/discount_strategy.py`:**
```python
from pydantic import BaseModel, Field

class DiscountStrategyCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    discount_type: str
    value: int = Field(..., ge=1)
    target: str = "all"

class DiscountStrategyUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    discount_type: str | None = None
    value: int | None = Field(None, ge=1)
    target: str | None = None
```

- [x] **Step 4: Run all schema tests**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest tests/test_schema_validation.py -v`
Expected: ALL PASS

- [x] **Step 5: Run full backend test suite**

Run: `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest -v --tb=short`
Expected: ALL PASS. Fix any tests that use out-of-bounds values.

- [x] **Step 6: Commit**

```bash
git add Backend/app/schemas/funding.py Backend/app/schemas/sponsor.py Backend/app/schemas/ticket_strategy.py Backend/app/schemas/discount_strategy.py Backend/tests/test_schema_validation.py
git commit -m "fix: add numeric bounds and string limits to funding, sponsor, ticket, discount schemas"
```

---

## Phase 2: Frontend Silent Error Fixes

### Task 3: Replace silent catch blocks in create_event_submit.dart with error collection

**Files:**
- Modify: `FrontEnd/lib/screens/event/create_event/create_event_submit.dart`

The file has 10+ `catch (e) { debugPrint(e.toString()); }` blocks that silently swallow errors during event creation. If tier creation, milestone upload, or image upload fails, the user gets no feedback.

- [x] **Step 1: Read the full file to understand the submission flow**

Read `FrontEnd/lib/screens/event/create_event/create_event_submit.dart` to understand all helper functions and where they're called from.

- [x] **Step 2: Add error collection pattern**

Instead of silently catching, collect errors and return them. Modify each helper function to accept a `List<String> errors` parameter and append errors instead of swallowing them:

```dart
Future<void> _attachDiscounts(
    TicketProvider ticketRepo, int eventId,
    Map<int, bool> selectedDiscounts, List<String> errors) async {
  for (final entry in selectedDiscounts.entries) {
    try {
      await ticketRepo.attachDiscountStrategy(eventId, entry.key,
          autoApply: entry.value);
    } catch (e) {
      errors.add('Failed to attach discount #${entry.key}');
      debugPrint(e.toString());
    }
  }
}
```

Apply the same pattern to all helper functions:
- `_attachDiscounts` — add `List<String> errors` param
- `_createTiers` — add `List<String> errors` param
- `_createMilestones` — add `List<String> errors` param
- `_createEarlyBirdDiscounts` — add `List<String> errors` param
- `_createSchedule` — add `List<String> errors` param
- `_createSponsorCategories` — add `List<String> errors` param
- `_uploadImages` — add `List<String> errors` param

Error messages should be user-friendly (not raw exception strings):
- `'Failed to create tier "$name"'`
- `'Failed to create milestone "$title"'`
- `'Failed to upload image ${i + 1}'`
- `'Failed to create schedule'`
- `'Failed to create sponsor category "$name"'`

- [x] **Step 3: Update the main submission function to collect and return errors**

The main `submitCreateEvent` function (or whatever calls these helpers) should:
1. Create `final errors = <String>[];`
2. Pass `errors` to each helper
3. Return the errors list to the caller

```dart
// At the call site (the screen that calls submitCreateEvent):
final errors = result.errors; // or however errors are returned
if (errors.isNotEmpty) {
  AppToast.show(context,
    '${errors.length} issue(s) during event setup:\n${errors.join('\n')}',
    isError: true,
  );
}
```

- [x] **Step 4: Run flutter analyze**

Run: `cd FrontEnd && flutter analyze lib/screens/event/create_event/create_event_submit.dart`
Expected: No errors

- [x] **Step 5: Commit**

```bash
git add FrontEnd/lib/screens/event/create_event/
git commit -m "fix: collect and surface errors during event creation instead of silently swallowing"
```

---

## Phase 3: Logout Cache Clearing

### Task 4: Clear provider caches on logout

**Files:**
- Modify: `FrontEnd/lib/providers/auth_provider.dart:215-230`
- Modify: `FrontEnd/lib/providers/event_provider.dart`
- Modify: `FrontEnd/lib/providers/pledge_provider.dart`

When User A logs out and User B logs in, cached data from providers (events, pledges, tickets) can leak across sessions.

- [x] **Step 1: Add clearCache() method to EventProvider**

Read `FrontEnd/lib/providers/event_provider.dart` to find the state fields. Add a `clearCache()` method that resets all state:

```dart
void clearCache() {
  _events = [];
  _isLoading = false;
  _isLoadingMore = false;
  _error = null;
  // Reset any other cached fields (bookmarks, search state, etc.)
  notifyListeners();
}
```

- [x] **Step 2: Add clearCache() method to PledgeProvider**

Read `FrontEnd/lib/providers/pledge_provider.dart` to find the state fields. Add:

```dart
void clearCache() {
  pledges = [];
  loading = false;
  loadingMore = false;
  hasMore = true;
  error = null;
  notifyListeners();
}
```

- [x] **Step 3: Call clearCache on logout in AuthProvider**

In `FrontEnd/lib/providers/auth_provider.dart`, the `signOut()` method needs to clear other providers. But AuthProvider shouldn't depend on other providers directly.

Instead, add a callback mechanism. AuthProvider already has `_onBeforeSignOut`. Add a similar `_onAfterSignOut`:

```dart
// In AuthProvider constructor or via setter:
VoidCallback? _onAfterSignOut;
void setOnAfterSignOut(VoidCallback cb) => _onAfterSignOut = cb;

// In signOut(), after clearing _user:
Future<void> signOut() async {
  _log('signOut: signing out...');
  if (_onBeforeSignOut != null) {
    try { await _onBeforeSignOut!(); } catch (e) {
      _log('signOut: pre-signout hook error (continuing): $e');
    }
  }
  await _firebaseAuth.signOut();
  _user = null;
  _errorMessage = null;
  _onAfterSignOut?.call();
  notifyListeners();
}
```

Then in `FrontEnd/lib/main.dart` (where providers are wired up), register the callback:

```dart
// In the MultiProvider setup, after all providers are created:
final auth = context.read<AuthProvider>();
auth.setOnAfterSignOut(() {
  context.read<EventProvider>().clearCache();
  context.read<PledgeProvider>().clearCache();
});
```

**Alternative (simpler):** If `main.dart` already has a listener on AuthProvider that detects logout, add the cache clearing there.

- [x] **Step 4: Run flutter analyze**

Run: `cd FrontEnd && flutter analyze`
Expected: No errors

- [x] **Step 5: Commit**

```bash
git add FrontEnd/lib/providers/auth_provider.dart FrontEnd/lib/providers/event_provider.dart FrontEnd/lib/providers/pledge_provider.dart FrontEnd/lib/main.dart
git commit -m "fix: clear provider caches on logout to prevent cross-user data leakage"
```

---

## Phase 4: Frontend Form Validators

### Task 5: Add validators to financial input fields

**Files:**
- Modify: `FrontEnd/lib/screens/event/create_event/step_funding.dart:83-122`
- Modify: `FrontEnd/lib/screens/venue/create_venue_screen.dart:299-309`
- Modify: `FrontEnd/lib/screens/sponsor/sponsorship_categories/place_bid_dialog.dart:125-135`
- Modify: `FrontEnd/lib/screens/event/create_event/funding_tier_section.dart:314-325`

- [x] **Step 1: Add validator to funding goal field**

In `step_funding.dart`, add a `validator` to the funding goal `TextFormField` (around line 83):

```dart
TextFormField(
  controller: fundingGoalCtrl,
  decoration: const InputDecoration(
      labelText: 'Funding Goal (\$)',
      prefixIcon: Icon(Icons.flag_rounded, size: 20),
      prefixText: '\$ '),
  keyboardType: TextInputType.number,
  validator: (v) {
    if (v == null || v.isEmpty) return null; // optional field
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n < 0) return 'Must be positive';
    return null;
  },
),
```

- [x] **Step 2: Add validator to min pledge field**

In `step_funding.dart`, add a `validator` to the min pledge `TextFormField` (around line 115):

```dart
TextFormField(
  controller: minPledgeCtrl,
  decoration: const InputDecoration(
      labelText: 'Minimum Pledge (\$)',
      prefixIcon: Icon(Icons.savings_rounded, size: 20),
      prefixText: '\$ '),
  keyboardType: TextInputType.number,
  validator: (v) {
    if (v == null || v.isEmpty) return null; // has default
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n <= 0) return 'Must be greater than \$0';
    return null;
  },
),
```

- [x] **Step 3: Add range check to venue max capacity**

In `create_venue_screen.dart`, enhance the existing validator (line 304):

```dart
validator: (v) {
  if (v == null || v.isEmpty) return 'Required';
  final n = int.tryParse(v);
  if (n == null) return 'Enter a number';
  if (n < 1) return 'Must be at least 1';
  if (n > 1000000) return 'Maximum 1,000,000';
  return null;
},
```

- [x] **Step 4: Add validator to bid amount in place_bid_dialog.dart**

Change the `TextField` to `TextFormField` with a validator (line 125):

```dart
TextFormField(
  controller: _amountCtrl,
  decoration: const InputDecoration(
    labelText: 'Bid Amount (\$)',
    prefixText: '\$ ',
  ),
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  onChanged: (_) => setState(() {}),
  validator: (v) {
    if (v == null || v.isEmpty) return 'Required';
    final n = double.tryParse(v);
    if (n == null) return 'Enter a valid number';
    if (n <= 0) return 'Must be greater than \$0';
    return null;
  },
),
```

Note: If the dialog uses a `Form` widget, the validator will auto-run. If not, wrap the dialog content in a `Form` with a `GlobalKey<FormState>` and call `_formKey.currentState!.validate()` in the submit handler.

- [x] **Step 5: Add validator to max reserved spots field**

In `funding_tier_section.dart`, add a validator (line 314):

```dart
TextFormField(
  controller: widget.maxReservedSpotsCtrl,
  decoration: const InputDecoration(
    labelText: 'Max Spots Per Pledger',
    prefixIcon: Icon(Icons.event_seat_rounded, size: 20),
    helperText: 'Total spots one person can reserve across all tiers',
    isDense: true,
  ),
  keyboardType: TextInputType.number,
  onChanged: (_) => setState(() {}),
  validator: (v) {
    if (v == null || v.isEmpty) return null; // 0 = disabled
    final n = int.tryParse(v);
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Must be 0 or greater';
    return null;
  },
),
```

- [x] **Step 6: Run flutter analyze**

Run: `cd FrontEnd && flutter analyze`
Expected: No errors

- [x] **Step 7: Commit**

```bash
git add FrontEnd/lib/screens/event/create_event/step_funding.dart FrontEnd/lib/screens/venue/create_venue_screen.dart FrontEnd/lib/screens/sponsor/sponsorship_categories/place_bid_dialog.dart FrontEnd/lib/screens/event/create_event/funding_tier_section.dart
git commit -m "fix: add validators to financial input fields (funding goal, pledge, bid, capacity)"
```

---

## Verification (run after each phase)

- [x] **Backend tests:** `cd Backend && RATELIMIT_STORAGE_URL=memory:// pytest -v --tb=short`
- [x] **Frontend analyze:** `cd FrontEnd && flutter analyze`
- [x] **Frontend tests:** `cd FrontEnd && flutter test`

---

## Out of Scope (tracked for future plans)

These were identified in the second-pass audit but are larger efforts:

1. **Race condition protection** — DB-level locking for ticket purchase, pledge creation, bid acceptance (requires `SELECT ... FOR UPDATE` in repos)
2. **Idempotency keys** — Add idempotency key support to purchase/pledge/bid endpoints
3. **401 interceptor enhancement** — Detect session expiry in Dio and trigger logout + redirect to login
4. **Ownership checks** — Verify ticket_strategies, discount_strategies, sponsor categories belong to current user in routes
5. **Future-date validation** — Enforce start_time/end_time/funding_end_at are in the future at schema or service level
6. **Offline form submission detection** — Show "No internet" banner before form submission attempts
7. **Empty state CTAs** — Add action buttons to empty list states across screens
