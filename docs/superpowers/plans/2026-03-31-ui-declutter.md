# UI Declutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Reduce visual clutter across 3 critical screens by removing redundant elements, adding progressive disclosure, and standardizing design tokens.

**Architecture:** Pure frontend changes. No backend changes. Each task targets one file/screen and can be committed independently. Tasks are ordered by severity (CRITICAL first) and file grouping to minimize context switching.

**Tech Stack:** Flutter/Dart, AppTheme design tokens, AppSpacing tokens, AppRadius tokens.

---

## File Map

| File | Changes |
|------|---------|
| `FrontEnd/lib/config/design_tokens.dart` | Add `chipRowHeight` token |
| `FrontEnd/lib/screens/event/event_detail_screen.dart` | Remove 3 pills from title card, remove organizer pill |
| `FrontEnd/lib/widgets/event/event_card.dart` | Collapse hero chips, remove genre row, remove age badge, neutralize gradient |
| `FrontEnd/lib/screens/home/tabs/home_tab.dart` | Hide genre+city behind "Filters" toggle, use `chipRowHeight` token |
| `FrontEnd/lib/screens/home/tabs/explore_tab.dart` | Use `chipRowHeight` token, standardize button heights |
| `FrontEnd/lib/screens/profile/profile_screen.dart` | Replace hardcoded spacing with tokens |

---

### Task 1: Add `chipRowHeight` design token

**Files:**
- Modify: `FrontEnd/lib/config/design_tokens.dart`

- [x] **Step 1: Add token to AppSpacing**

In `FrontEnd/lib/config/design_tokens.dart`, add after line 17 (`static const double huge = 40;`):

```dart
  /// Standard height for horizontal chip scroll rows (genre, status, city).
  static const double chipRowHeight = 38;
```

- [x] **Step 2: Verify no compile errors**

Run: `cd FrontEnd && dart analyze lib/config/design_tokens.dart`
Expected: No issues found.

- [x] **Step 3: Commit**

```bash
git add FrontEnd/lib/config/design_tokens.dart
git commit -m "refactor: add chipRowHeight design token (38px)"
```

---

### Task 2: Reduce event detail title card from 7 pills to 3 (fixes #1, #4, #7)

**Files:**
- Modify: `FrontEnd/lib/screens/event/event_detail_screen.dart:559-612`

This is the highest-impact change. Remove 3 pills from the `Wrap` in the title card:
- **Engagement pill** (`event.registrationCount > 0 ...`) — redundant, count is visible in sections below
- **Trust badge pill** (`EventDetailHelpers.trustBadgePill`) — move to organizer bottom sheet (already accessible via organizer pill tap)
- **Revenue pill** (`_revenueCents > 0 ...`) — organizer-only metric that clutters the public view

Keep: status pill, genre pill, organizer pill (clickable, opens bottom sheet with trust info).

- [x] **Step 1: Remove engagement pill, trust badge pill, and revenue pill**

In `FrontEnd/lib/screens/event/event_detail_screen.dart`, find the `Wrap` block at ~line 559. Replace the entire `Wrap(...)` including its `.animate()` chain with:

```dart
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EventDetailHelpers.statusPill(context, event.status),
                if (event.genre != null && event.genre!.isNotEmpty)
                  EventDetailHelpers.tagPill(
                    icon: Icons.category_rounded,
                    label: event.genre![0].toUpperCase() +
                        event.genre!.substring(1),
                    color: AppTheme.secondaryColor,
                  ),
                if (event.organizerName != null &&
                    event.organizerName!.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showOrganizerBottomSheet(event),
                    child: EventDetailHelpers.tagPill(
                      icon: Icons.person_rounded,
                      label: event.organizerName!,
                      color: AppTheme.accentColor,
                    ),
                  ),
              ],
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: 80.ms)
                .slideX(begin: -0.04, duration: 300.ms),
```

- [x] **Step 2: Verify no compile errors**

Run: `cd FrontEnd && dart analyze lib/screens/event/event_detail_screen.dart`
Expected: No issues (or only pre-existing warnings).

- [x] **Step 3: Run tests**

Run: `cd FrontEnd && flutter test test/screens/event_detail_screen_test.dart -v`
Expected: All pass.

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/event/event_detail_screen.dart
git commit -m "fix(ui): reduce event detail title pills from 7 to 3

Remove engagement count, trust badge, and revenue pills from the title
card Wrap. Status + genre + organizer remain. Trust info is accessible
via the organizer pill tap (bottom sheet). Reduces visual density from
9/10 to 4/10 and color count from ~18 to ~10."
```

---

### Task 3: Declutter event card header (fixes #2, #5)

**Files:**
- Modify: `FrontEnd/lib/widgets/event/event_card.dart:88-299`

Four changes in this file:
1. Collapse 3 hero chips (Pledged/Attending/Sponsored) into a single "Your Activity" chip
2. Remove age restriction badge (keep on detail screen only)
3. Remove genre info row from body (already shown in filters and on detail screen)
4. Replace status-specific gradient with neutral dark gradient

- [x] **Step 1: Replace hero chips with single activity indicator**

In `_buildHeader`, find the hero chips block (~line 134-152). Replace:

```dart
                    if ((widget.myPledgeAmountCents ?? 0) > 0 ||
                        (widget.myTicketCount ?? 0) > 0 ||
                        widget.showSponsorBadge) ...[
                      AppSpacing.vSm,
                      Row(
                        children: [
                          if ((widget.myPledgeAmountCents ?? 0) > 0) ...[
                            const _HeroChip(label: 'Pledged'),
                            AppSpacing.hXs,
                          ],
                          if ((widget.myTicketCount ?? 0) > 0) ...[
                            const _HeroChip(label: 'Attending'),
                            AppSpacing.hXs,
                          ],
                          if (widget.showSponsorBadge)
                            const _HeroChip(label: 'Sponsored'),
                        ],
                      ),
                    ],
```

With:

```dart
                    if ((widget.myPledgeAmountCents ?? 0) > 0 ||
                        (widget.myTicketCount ?? 0) > 0 ||
                        widget.showSponsorBadge) ...[
                      AppSpacing.vSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: AppRadius.pill,
                          border: Border.all(
                              color: AppTheme.successColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 12, color: AppTheme.successColor),
                            const SizedBox(width: 4),
                            Text(
                              'Your Activity',
                              style: AppTypography.badge.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
```

- [x] **Step 2: Remove age restriction badge**

In the same `_buildHeader`, find the age badge block (~line 164-180). Remove:

```dart
                              if (event.ageRestricted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor.withValues(alpha: 0.7),
                                    borderRadius: AppRadius.pill,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Text(
                                    '${event.minAge}+',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
```

- [x] **Step 3: Remove genre info row from body**

In `_buildBody` (~line 236-243), remove the genre section:

```dart
          if (event.genre != null && event.genre!.isNotEmpty) ...[
            Divider(height: 1, thickness: 0.5, color: AppTheme.dividerOf(context).withValues(alpha: 0.6)),
            _InfoRow(
              icon: AppIcons.genreIcon(event.genre!),
              text: event.genre![0].toUpperCase() + event.genre!.substring(1),
              color: AppIcons.genreColor(event.genre!, isDark: Theme.of(context).brightness == Brightness.dark),
            ),
          ],
```

- [x] **Step 4: Neutralize status gradient**

Replace the `_statusGradient` method (~line 296-299):

```dart
  LinearGradient _statusGradient(EventStatus status) {
    final colors = AppIcons.forEventStatus(status).gradientColors;
    return LinearGradient(colors: colors);
  }
```

With a neutral dark gradient:

```dart
  LinearGradient _statusGradient(EventStatus _) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B1B2F), Color(0xFF162447)],
    );
  }
```

Note: parameter renamed to `_` to suppress unused-parameter analyzer hint.

- [x] **Step 5: Remove dead `_HeroChip` class**

After step 1, the `_HeroChip` widget is no longer used. Find and delete the entire `_HeroChip` class (around lines 304-323).

- [x] **Step 6: Update tests**

Two tests in `FrontEnd/test/widgets/event_card_test.dart` will fail because:
- The "renders genre when present" test (line 65-75) expects `find.text('Jazz')` — genre info row is removed.
- The "renders age restriction badge" test (line 113-126) expects `find.text('21+')` — age badge is removed.

Remove both test cases from the file.

- [x] **Step 7: Verify no compile errors**

Run: `cd FrontEnd && dart analyze lib/widgets/event/event_card.dart`
Expected: No issues.

- [x] **Step 8: Run tests**

Run: `cd FrontEnd && flutter test test/widgets/event_card_test.dart -v`
Expected: All pass.

- [x] **Step 9: Commit**

```bash
git add FrontEnd/lib/widgets/event/event_card.dart FrontEnd/test/widgets/event_card_test.dart
git commit -m "fix(ui): declutter event card header

- Collapse 3 hero chips into single 'Your Activity' indicator
- Remove age restriction badge (visible on detail screen)
- Remove genre info row (visible in filters)
- Replace status-specific gradient with neutral dark gradient
  (frosted badge alone carries status info)
- Remove dead _HeroChip class
- Update tests: remove genre/age badge assertions"
```

---

### Task 4: Collapse home tab filters behind toggle (fix #3)

**Files:**
- Modify: `FrontEnd/lib/screens/home/tabs/home_tab.dart:495-605`

Keep search bar + status chips visible. Wrap genre + city rows inside an `AnimatedCrossFade` toggle controlled by a new `_showFilters` state variable.

- [x] **Step 1: Add `_showFilters` state variable**

Find the state class (search for `class _HomeTabState` or equivalent). Add alongside other state variables:

```dart
  bool _showFilters = false;
```

- [x] **Step 2: Add "Filters" toggle chip at end of status row and wrap genre+city in collapsible**

Replace the filter section (from the genre `SizedBox(height: 38, ...)` through the end of the city chips section) with:

```dart
                  AppSpacing.vXl,
                  SizedBox(
                    height: AppSpacing.chipRowHeight,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._visibleStatuses.map((s) {
                          final isActive = _homeStatus == s.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: AppChip(
                              label: statusDisplayName(s),
                              selected: isActive,
                              onSelected: (selected) {
                                setState(
                                    () => _homeStatus = selected ? s.name : null);
                                _homeSearch();
                              },
                              chipColor: statusChipColor(context, s),
                              avatarIcon: statusChipIcon(s),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ActionChip(
                            avatar: Icon(
                              _showFilters
                                  ? Icons.filter_list_off_rounded
                                  : Icons.filter_list_rounded,
                              size: AppIconSize.sm,
                            ),
                            label: Text(
                              'Filters',
                              style: AppTypography.chip,
                            ),
                            side: BorderSide(
                              color: _showFilters
                                  ? AppTheme.accentColor
                                  : AppTheme.dividerOf(context),
                            ),
                            backgroundColor: _showFilters
                                ? AppTheme.accentColor.withValues(alpha: 0.12)
                                : AppTheme.cardOf(context),
                            onPressed: () =>
                                setState(() => _showFilters = !_showFilters),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        AppSpacing.vSm,
                        SizedBox(
                          height: AppSpacing.chipRowHeight,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: widget.genres.map((g) {
                              final isActive = _homeGenre == g;
                              final isDark =
                                  Theme.of(context).brightness == Brightness.dark;
                              final genreColor =
                                  AppIcons.genreColor(g, isDark: isDark);
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.sm),
                                child: AppChip(
                                  label: g[0].toUpperCase() + g.substring(1),
                                  selected: isActive,
                                  onSelected: (selected) {
                                    setState(
                                        () => _homeGenre = selected ? g : null);
                                    _homeSearch();
                                  },
                                  chipColor: genreColor,
                                  avatarIcon: AppIcons.genreIcon(g),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (widget.cities.isNotEmpty) ...[
                          AppSpacing.vSm,
                          SizedBox(
                            height: AppSpacing.chipRowHeight,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: AppSpacing.sm),
                                  child: ChoiceChip(
                                    label: const Text('All Cities'),
                                    selected: _homeCityFilter == null,
                                    onSelected: (_) {
                                      setState(() => _homeCityFilter = null);
                                      _homeSearch();
                                    },
                                    selectedColor: AppTheme.accentColor,
                                    backgroundColor: AppTheme.cardOf(context),
                                    side: BorderSide(
                                      color: _homeCityFilter == null
                                          ? AppTheme.accentColor
                                          : AppTheme.dividerOf(context),
                                    ),
                                    labelStyle: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _homeCityFilter == null
                                          ? Colors.white
                                          : AppTheme.textPrimaryOf(context),
                                    ),
                                  ),
                                ),
                                ...widget.cities.map((c) {
                                  final isActive = _homeCityFilter == c;
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        right: AppSpacing.sm),
                                    child: ChoiceChip(
                                      label: Text(c),
                                      selected: isActive,
                                      onSelected: (selected) {
                                        setState(() => _homeCityFilter =
                                            selected ? c : null);
                                        _homeSearch();
                                      },
                                      selectedColor: AppTheme.accentColor,
                                      backgroundColor: AppTheme.cardOf(context),
                                      side: BorderSide(
                                        color: isActive
                                            ? AppTheme.accentColor
                                            : AppTheme.dividerOf(context),
                                      ),
                                      labelStyle: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? Colors.white
                                            : AppTheme.textPrimaryOf(context),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    crossFadeState: _showFilters
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: AppDuration.normal,
                  ),
```

- [x] **Step 3: Verify no compile errors**

Run: `cd FrontEnd && dart analyze lib/screens/home/tabs/home_tab.dart`
Expected: No issues.

- [x] **Step 4: Run full test suite** (no dedicated home_tab test file exists)

Run: `cd FrontEnd && flutter test`
Expected: All pass.

- [x] **Step 5: Commit**

```bash
git add FrontEnd/lib/screens/home/tabs/home_tab.dart
git commit -m "fix(ui): collapse genre and city filters behind toggle

Status chips stay visible. Genre and city filters hidden behind a
'Filters' ActionChip toggle with AnimatedCrossFade. Reduces default
filter height from ~200px to ~80px (60% reduction)."
```

---

### Task 5: Standardize explore tab chip heights (fix #8)

**Files:**
- Modify: `FrontEnd/lib/screens/home/tabs/explore_tab.dart`

Replace hardcoded `height: 36` (status chip row) and `height: 34` (filter button + Go button) with `AppSpacing.chipRowHeight` (38).

- [x] **Step 1: Replace heights**

In `FrontEnd/lib/screens/home/tabs/explore_tab.dart`:

Find `height: 36` (~line 368) in the status chips SizedBox and replace with `height: AppSpacing.chipRowHeight`.

Find `height: 34` (~line 398) for the filter toggle button and replace with `height: AppSpacing.chipRowHeight`.

Find `height: 34` (~line 421) for the Go button SizedBox and replace with `height: AppSpacing.chipRowHeight`.

- [x] **Step 2: Verify no compile errors**

Run: `cd FrontEnd && dart analyze lib/screens/home/tabs/explore_tab.dart`
Expected: No issues.

- [x] **Step 3: Run tests**

Run: `cd FrontEnd && flutter test test/screens/explore_tab_test.dart -v`
Expected: All pass.

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/home/tabs/explore_tab.dart
git commit -m "refactor: standardize explore tab chip row heights to 38px token"
```

---

### Task 6: Replace hardcoded spacing in profile screen (fix #6 partial)

**Files:**
- Modify: `FrontEnd/lib/screens/profile/profile_screen.dart`

Replace 4 hardcoded SizedBox values:
- `SizedBox(height: 28)` (line ~368) -> `AppSpacing.vXxl` (24px, closest standard token)
- `SizedBox(height: 16)` (line ~435) -> `AppSpacing.vLg` (16px, exact match)
- `SizedBox(height: 28)` (line ~502) -> `AppSpacing.vXxl` (24px)
- `SizedBox(height: 40)` (line ~506) -> `SizedBox(height: AppSpacing.huge)` (40px, exact match)

**Note:** The 28px -> 24px change is a 4px spacing reduction (not just a token swap). These SizedBoxes separate major sections. Visually verify section separation still looks appropriate after the change.

- [x] **Step 1: Replace all 4 values**

In `FrontEnd/lib/screens/profile/profile_screen.dart`:

Replace each `const SizedBox(height: 28)` with `AppSpacing.vXxl`.
Replace `const SizedBox(height: 16)` with `AppSpacing.vLg`.
Replace `const SizedBox(height: 40)` with `const SizedBox(height: AppSpacing.huge)`.

- [x] **Step 2: Verify no compile errors**

Run: `cd FrontEnd && dart analyze lib/screens/profile/profile_screen.dart`
Expected: No issues.

- [x] **Step 3: Run tests**

Run: `cd FrontEnd && flutter test test/screens/profile_screen_test.dart -v`
Expected: All pass.

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/profile/profile_screen.dart
git commit -m "refactor: replace hardcoded spacing with AppSpacing tokens in profile screen"
```

---

### Task 7: Replace hardcoded spacing in event detail screen (fix #6 partial)

**Files:**
- Modify: `FrontEnd/lib/screens/event/event_detail_screen.dart`

Replace hardcoded spacing values:
- `const SizedBox(width: 8)` (~line 421 in AppBar) -> `AppSpacing.hSm`
- `const SizedBox(height: 16)` (~line 613 after pills) -> `AppSpacing.vLg`

- [x] **Step 1: Replace values**

In `FrontEnd/lib/screens/event/event_detail_screen.dart`:

Find `const SizedBox(width: 8),` in the AppBar title Row and replace with `AppSpacing.hSm,`.
Find `const SizedBox(height: 16),` after the pills Wrap animation and replace with `AppSpacing.vLg,`.

- [x] **Step 2: Verify no compile errors**

Run: `cd FrontEnd && dart analyze lib/screens/event/event_detail_screen.dart`
Expected: No issues.

- [x] **Step 3: Run tests**

Run: `cd FrontEnd && flutter test test/screens/event_detail_screen_test.dart -v`
Expected: All pass.

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/event/event_detail_screen.dart
git commit -m "refactor: replace hardcoded spacing with AppSpacing tokens in event detail"
```

---

### Task 8: Final verification

- [x] **Step 1: Run full flutter test suite**

Run: `cd FrontEnd && flutter test`
Expected: All 660+ tests pass.

- [x] **Step 2: Run flutter analyze on all changed files**

Run: `cd FrontEnd && dart analyze lib/`
Expected: No new errors or warnings.

- [x] **Step 3: Visual smoke test**

Launch the app and verify:
- Event detail screen: only 3 pills (status, genre, organizer) in title card
- Event card: single "Your Activity" chip instead of 3 hero chips, no genre row, no age badge, neutral gradient
- Home tab: only search + status chips visible; "Filters" toggle reveals genre + city
- Explore tab: chip row heights match home tab (38px)
- Profile screen: spacing looks identical (tokens match original values)
