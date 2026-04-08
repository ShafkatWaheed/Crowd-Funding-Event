# UI Polish — Comprehensive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Reduce visual clutter, consolidate the color system from 9 status colors to 4, simplify filter-heavy list screens, break apart the funding card, group form fields, and centralize hardcoded brand colors.

**Architecture:** 5 independent phases, each committable and testable on its own. Phase 1 (color) is the foundation — the rest can be done in any order. All changes are frontend-only (no backend changes).

**Tech Stack:** Flutter/Dart, AppTheme design tokens, AppIcons config, AppSpacing tokens.

---

## Phase 1: Color Consolidation (9 status colors → 4)

**Why:** Users can't memorize 9 distinct status colors. Consolidating to 4 semantic groups (active, positive, attention, inactive) makes the app instantly more scannable.

### Current 9-color mapping:

| Status | Current Color | Current Gradient |
|--------|--------------|-----------------|
| draft | Grey `#757575` | `[#616161, #424242]` |
| pending_approval | Amber `#F59E0B` | `[#F59E0B, #E65100]` |
| approved (Funding) | Blue `#276EF1` | `[#276EF1, #1A56D6]` |
| selling_tickets | Cyan `#0891B2` | `[#0891B2, #0E7490]` |
| waiting_event_date | Orange `#EA580C` | `[#EA580C, #C2410C]` |
| live | Green `#05944F` | `[#05944F, #0A7544]` |
| completed | Purple `#9333EA` | `[#9333EA, #7C3AED]` |
| cancelled | Red `#9B1C1C` | `[#9B1C1C, #7F1D1D]` |
| under_review | Yellow `#EAB308` | `[#EAB308, #CA8A04]` |

### New 4-group mapping:

| Group | Color Token | Statuses | Light | Dark |
|-------|------------|----------|-------|------|
| **Active** (things happening) | `accentColor` (Blue) | approved, selling_tickets, live | `#276EF1` | `#5B8DEF` |
| **Attention** (needs action/waiting) | `warningColor` (Amber) | pending_approval, waiting_event_date, under_review | `#FFC043` | `#FFB74D` |
| **Inactive** (done/stopped) | `textSecondary` (Grey) | draft, completed, cancelled | `#6B6B6B` | `#9E9E9E` |
| **Negative** (error state) | `errorColor` (Red) | cancelled | `#E11900` | `#EF5350` |

> Note: `cancelled` maps to **red** (negative), not grey, because it's an abnormal termination. `draft` and `completed` share grey because they're both "not active." `live` merges with `approved` and `selling_tickets` into blue because from a user's perspective, these are all "active events I can engage with."

---

### Task 1: Update `AppIcons.forEventStatus()` color mapping

**Files:**
- Modify: `FrontEnd/lib/config/app_icons.dart:44-110`

- [x] **Step 1: Replace color functions and gradients**

In `FrontEnd/lib/config/app_icons.dart`, update the `forEventStatus` switch to use 4 colors instead of 9. Keep `displayName` and `icon` unchanged — only change `color` and `gradientColors`:

```dart
static EventStatusMeta forEventStatus(EventStatus s) {
  switch (s) {
    case EventStatus.draft:
      return EventStatusMeta(
        displayName: 'Draft',
        icon: Icons.edit_note_rounded,
        color: (isDark) => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B6B6B),
        gradientColors: const [Color(0xFF6B6B6B), Color(0xFF4A4A4A)],
      );
    case EventStatus.pending_approval:
      return EventStatusMeta(
        displayName: 'Waiting Approval',
        icon: Icons.hourglass_top_rounded,
        color: (isDark) => isDark ? const Color(0xFFFFB74D) : const Color(0xFFD4940A),
        gradientColors: const [Color(0xFFFFC043), Color(0xFFD4940A)],
      );
    case EventStatus.approved:
      return EventStatusMeta(
        displayName: 'Funding',
        icon: Icons.rocket_launch_rounded,
        color: (isDark) => isDark ? const Color(0xFF5B8DEF) : AppTheme.accentColor,
        gradientColors: const [Color(0xFF276EF1), Color(0xFF1A56D6)],
      );
    case EventStatus.selling_tickets:
      return EventStatusMeta(
        displayName: 'Selling Tickets',
        icon: Icons.confirmation_number_rounded,
        color: (isDark) => isDark ? const Color(0xFF5B8DEF) : AppTheme.accentColor,
        gradientColors: const [Color(0xFF276EF1), Color(0xFF1A56D6)],
      );
    case EventStatus.waiting_event_date:
      return EventStatusMeta(
        displayName: 'Awaiting Date',
        icon: Icons.pending_actions_rounded,
        color: (isDark) => isDark ? const Color(0xFFFFB74D) : const Color(0xFFD4940A),
        gradientColors: const [Color(0xFFFFC043), Color(0xFFD4940A)],
      );
    case EventStatus.live:
      return EventStatusMeta(
        displayName: 'Live',
        icon: Icons.sensors_rounded,
        color: (isDark) => isDark ? const Color(0xFF5B8DEF) : AppTheme.accentColor,
        gradientColors: const [Color(0xFF276EF1), Color(0xFF1A56D6)],
      );
    case EventStatus.completed:
      return EventStatusMeta(
        displayName: 'Completed',
        icon: Icons.emoji_events_rounded,
        color: (isDark) => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF6B6B6B),
        gradientColors: const [Color(0xFF6B6B6B), Color(0xFF4A4A4A)],
      );
    case EventStatus.cancelled:
      return EventStatusMeta(
        displayName: 'Cancelled',
        icon: Icons.event_busy_rounded,
        color: (isDark) => isDark ? const Color(0xFFEF5350) : AppTheme.errorColor,
        gradientColors: const [Color(0xFFE11900), Color(0xFFB71400)],
      );
    case EventStatus.under_review:
      return EventStatusMeta(
        displayName: 'Under Review',
        icon: Icons.manage_search_rounded,
        color: (isDark) => isDark ? const Color(0xFFFFB74D) : const Color(0xFFD4940A),
        gradientColors: const [Color(0xFFFFC043), Color(0xFFD4940A)],
      );
  }
}
```

- [x] **Step 2: Update AppColors status getters in theme.dart**

In `FrontEnd/lib/config/theme.dart`, find the `// ─── Status colours` section (~line 528) and update to match the 4 groups:

```dart
  // ─── Status colours (pills, badges, lifecycle indicators) ───
  Color get statusDraft      => _dk ? const Color(0xFF9E9E9E) : const Color(0xFF6B6B6B);
  Color get statusPending    => _dk ? const Color(0xFFFFB74D) : const Color(0xFFD4940A);
  Color get statusApproved   => _dk ? const Color(0xFF5B8DEF) : const Color(0xFF276EF1);
  Color get statusLive       => _dk ? const Color(0xFF5B8DEF) : const Color(0xFF276EF1);
  Color get statusSelling    => _dk ? const Color(0xFF5B8DEF) : const Color(0xFF276EF1);
  Color get statusWaiting    => _dk ? const Color(0xFFFFB74D) : const Color(0xFFD4940A);
  Color get statusCompleted  => _dk ? const Color(0xFF9E9E9E) : const Color(0xFF6B6B6B);
  Color get statusCancelled  => _dk ? const Color(0xFFEF5350) : const Color(0xFFE11900);
```

- [x] **Step 3: Run tests**

Run: `cd FrontEnd && flutter test`
Expected: All pass (colors are visual-only, no logic depends on specific color values).

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/config/app_icons.dart FrontEnd/lib/config/theme.dart
git commit -m "refactor(color): consolidate 9 status colors to 4 semantic groups

- Active (blue): approved, selling_tickets, live
- Attention (amber): pending_approval, waiting_event_date, under_review
- Inactive (grey): draft, completed
- Negative (red): cancelled

Icons and display names unchanged — only colors and gradients simplified."
```

---

## Phase 2: Filter Declutter on List Screens

**Why:** Three list screens show 8-10 filter/sort/stat controls before any content. Collapsing secondary filters behind toggles reduces cognitive load.

### Task 2: Simplify Organizer Pledges screen filters

**Files:**
- Modify: `FrontEnd/lib/screens/manage/organizer_pledges_screen.dart`

**Current:** 5 status filter chips + 3-4 stat chips + refresh button = 9-10 controls
**Target:** Search + 3 primary filter chips ("All", "Active", "Refunded") + "More" toggle → expanded shows full 5 statuses + stats

- [x] **Step 1: Add `_showMore` state variable**

Add alongside existing state variables (~line 34):

```dart
  bool _showMore = false;
```

- [x] **Step 2: Reduce visible statuses and wrap stats in toggle**

Find the filter chips section (~line 209). Replace the filter chips `SizedBox` and stat chips `Padding` with:

```dart
SizedBox(
  height: AppSpacing.chipRowHeight,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    itemCount: 4, // All, Pledged, Refunded, More toggle
    separatorBuilder: (_, __) => AppSpacing.hSm,
    itemBuilder: (_, i) {
      if (i == 3) {
        return ActionChip(
          avatar: Icon(
            _showMore ? Icons.expand_less : Icons.expand_more,
            size: AppIconSize.sm,
          ),
          label: Text(_showMore ? 'Less' : 'More', style: AppTypography.chip),
          side: BorderSide(
            color: _showMore
                ? AppTheme.accentColor
                : AppTheme.dividerOf(context),
          ),
          backgroundColor: _showMore
              ? AppTheme.accentColor.withValues(alpha: 0.12)
              : AppTheme.cardOf(context),
          onPressed: () => setState(() => _showMore = !_showMore),
        );
      }
      final statuses = ['all', 'pledged', 'refunded'];
      final s = statuses[i];
      final active = _statusFilter == s;
      return AppChip(
        label: s[0].toUpperCase() + s.substring(1),
        selected: active,
        onSelected: (_) {
          setState(() => _statusFilter = s);
          _load();
        },
        chipColor: context.fundingAccent,
      );
    },
  ),
),
AnimatedCrossFade(
  firstChild: const SizedBox.shrink(),
  secondChild: Column(
    children: [
      AppSpacing.vSm,
      SizedBox(
        height: AppSpacing.chipRowHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: 2,
          separatorBuilder: (_, __) => AppSpacing.hSm,
          itemBuilder: (_, i) {
            final extras = ['donation', 'collected'];
            final s = extras[i];
            final active = _statusFilter == s;
            return AppChip(
              label: s[0].toUpperCase() + s.substring(1),
              selected: active,
              onSelected: (_) {
                setState(() => _statusFilter = s);
                _load();
              },
              chipColor: context.fundingAccent,
            );
          },
        ),
      ),
      // Move stat chips here (inside the expandable)
      // ... existing stat chips Padding widget ...
    ],
  ),
  crossFadeState: _showMore
      ? CrossFadeState.showSecond
      : CrossFadeState.showFirst,
  duration: AppDuration.normal,
),
```

Note: The existing stat chips `Padding` (lines 234-274) should be moved inside the `secondChild` Column, after the extra filter row.

- [x] **Step 3: Run tests and verify**

Run: `cd FrontEnd && flutter test`
Expected: All pass.

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/manage/organizer_pledges_screen.dart
git commit -m "fix(ui): collapse pledge filters — show 3 primary + 'More' toggle

9 controls visible → 4 by default. Donation, Collected filters and stat
chips hidden behind 'More' toggle with AnimatedCrossFade."
```

---

### Task 3: Simplify My Tickets screen filters

**Files:**
- Modify: `FrontEnd/lib/screens/profile/my_tickets_screen.dart`

**Current:** 4 sort chips + 6 filter chips = 10 controls
**Target:** Search + 3 primary filter chips ("All", "Purchased", "Refunded") + "Sort & Filter" toggle → expanded shows sort row + full status filters

- [x] **Step 1: Add `_showFilters` state variable**

Add alongside existing state variables (~line 48):

```dart
  bool _showFilters = false;
```

- [x] **Step 2: Collapse sort row and extra filters behind toggle**

Find the sort chips section (~line 298). Replace the sort `SingleChildScrollView` and filter `SingleChildScrollView` with:

Primary row: 3 key filters + toggle chip:

```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      _filterChip('All', 'all'),
      AppSpacing.hSm,
      _filterChip('Purchased', 'purchased'),
      AppSpacing.hSm,
      _filterChip('Refunded', 'refunded'),
      AppSpacing.hSm,
      ActionChip(
        avatar: Icon(
          _showFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
          size: AppIconSize.sm,
        ),
        label: Text('Sort & Filter', style: AppTypography.chip),
        side: BorderSide(
          color: _showFilters
              ? AppTheme.accentColor
              : AppTheme.dividerOf(context),
        ),
        backgroundColor: _showFilters
            ? AppTheme.accentColor.withValues(alpha: 0.12)
            : AppTheme.cardOf(context),
        onPressed: () => setState(() => _showFilters = !_showFilters),
      ),
    ],
  ),
),
AnimatedCrossFade(
  firstChild: const SizedBox.shrink(),
  secondChild: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSpacing.vSm,
      // Sort row (existing sort chips code)
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Builder(builder: (context) {
          final (sortBg, sortLabel) = AppTheme.chipActive(AppTheme.accentColor);
          return Row(
            children: [
              Icon(Icons.sort_rounded, size: 18, color: AppTheme.textSecondaryOf(context)),
              AppSpacing.hSm,
              // ... existing sort chip map code ...
            ],
          );
        }),
      ),
      AppSpacing.vSm,
      // Extra filter chips
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('Refund Pending', 'refund_pending'),
            AppSpacing.hSm,
            _filterChip('Waitlisted', 'waitlisted'),
            AppSpacing.hSm,
            _filterChip('Cancelled', 'cancelled'),
          ],
        ),
      ),
    ],
  ),
  crossFadeState: _showFilters
      ? CrossFadeState.showSecond
      : CrossFadeState.showFirst,
  duration: AppDuration.normal,
),
```

- [x] **Step 3: Run tests and verify**

Run: `cd FrontEnd && flutter test`
Expected: All pass.

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/profile/my_tickets_screen.dart
git commit -m "fix(ui): collapse ticket sort + extra filters behind toggle

10 controls visible → 4 by default. Sort options and rare status filters
(refund pending, waitlisted, cancelled) hidden behind 'Sort & Filter'
toggle with AnimatedCrossFade."
```

---

### Task 4: Simplify Ticket Sales screen stat chips

**Files:**
- Modify: `FrontEnd/lib/screens/event/management/ticket_sales_screen.dart`

**Current:** 3 filter chips + 2-4 stat chips + refresh = 6-8 controls
**Target:** Keep filter chips (only 3, already reasonable). Collapse stat chips into a single summary line.

- [x] **Step 1: Replace stat chip row with compact summary**

Find the stat chips Row (~line 279). Replace the `Row` of individual `_statChip` widgets with a single compact text summary:

```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
  child: Row(
    children: [
      Expanded(
        child: Text(
          [
            '${_all.length} ${widget.scannedOnly ? 'scanned' : 'sold'}',
            '\$${(_totalRevenue / 100).toStringAsFixed(2)} revenue',
            if (_totalCommission > 0)
              'Net \$${(_totalNetToOrganizer / 100).toStringAsFixed(2)}',
            if (_searchCtrl.text.isNotEmpty)
              '${filtered.length} match${filtered.length == 1 ? '' : 'es'}',
          ].join(' · '),
          style: AppTypography.caption.copyWith(
            color: AppTheme.textSecondaryOf(context),
          ),
        ),
      ),
      IconButton(
        icon: Icon(Icons.refresh, size: AppIconSize.md,
            color: AppTheme.textSecondaryOf(context)),
        onPressed: _load,
        tooltip: 'Refresh',
      ),
    ],
  ),
),
```

This replaces 4 colorful stat chips with a single subdued text line, reducing visual noise significantly.

- [x] **Step 2: Run tests and verify**

Run: `cd FrontEnd && flutter test`
Expected: All pass.

- [x] **Step 3: Commit**

```bash
git add FrontEnd/lib/screens/event/management/ticket_sales_screen.dart
git commit -m "fix(ui): replace ticket sales stat chips with compact text summary

4 colorful stat chips → single caption line with dot separators.
Reduces visual noise while keeping all the same data visible."
```

---

## Phase 3: Funding Card Simplification

**Why:** The active funding card (~1425 lines) tries to show everything at once: amount, progress, backers, time, milestones, early bird, and CTA. Splitting into primary + expandable details reduces cognitive load.

### Task 5: Split funding card into primary + expandable

**Files:**
- Modify: `FrontEnd/lib/screens/event/event_detail/funding_card.dart`

This is the most complex task. The card currently shows everything in a flat layout. We add an expandable section that hides milestones and backer stats by default.

- [x] **Step 1: Add `_showDetails` state to the card**

Find the state class in `funding_card.dart`. Add:

```dart
  bool _showDetails = false;
```

- [x] **Step 2: Wrap secondary content in expandable**

Identify the sections in the card's build method. Keep visible by default:
- Total pledged amount (large number)
- Progress bar with shimmer
- Goal amount text
- CTA button (pledge/unpledge)

Wrap in an expandable `AnimatedCrossFade`:
- Backer count + average pledge
- Time remaining countdown
- Early bird discount section
- Milestone progress tracker

Add a "Show details" / "Hide details" text button between the CTA and the expandable section:

```dart
// After the CTA button:
Center(
  child: TextButton.icon(
    onPressed: () => setState(() => _showDetails = !_showDetails),
    icon: Icon(
      _showDetails ? Icons.expand_less : Icons.expand_more,
      size: AppIconSize.sm,
    ),
    label: Text(
      _showDetails ? 'Hide details' : 'Show details',
      style: AppTypography.caption.copyWith(
        color: AppTheme.textSecondaryOf(context),
      ),
    ),
  ),
),
AnimatedCrossFade(
  firstChild: const SizedBox.shrink(),
  secondChild: Column(
    children: [
      // ... backer stats, time remaining, early bird, milestones ...
    ],
  ),
  crossFadeState: _showDetails
      ? CrossFadeState.showSecond
      : CrossFadeState.showFirst,
  duration: AppDuration.normal,
),
```

- [x] **Step 3: Run tests and verify**

Run: `cd FrontEnd && flutter test test/screens/funding_card_test.dart -v`
Expected: All pass (tests tap "Show details" if they need to verify hidden content).

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/event/event_detail/funding_card.dart
git commit -m "fix(ui): split funding card into primary + expandable details

Amount, progress bar, and CTA stay visible. Backer stats, milestones,
early bird, and time remaining hidden behind 'Show details' toggle.
Reduces initial visual density from 7/10 to 4/10."
```

---

## Phase 4: Form Grouping with Collapsible Sections

**Why:** The edit/create forms show 12+ fields in a flat scroll. Grouping into collapsible sections makes them scannable.

### Task 6: Group edit_basic_info fields into collapsible sections

**Files:**
- Modify: `FrontEnd/lib/screens/event/edit_sections/edit_basic_info_section.dart`

- [x] **Step 1: Create a `_CollapsibleSection` helper widget**

Add a private widget at the bottom of the file:

```dart
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    this.initiallyExpanded = false,
    required this.children,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: AppRadius.md,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(widget.icon, size: AppIconSize.md,
                    color: AppTheme.textSecondaryOf(context)),
                AppSpacing.hSm,
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.titleSmall,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondaryOf(context),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(children: widget.children),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: AppDuration.normal,
        ),
      ],
    );
  }
}
```

- [x] **Step 2: Wrap fields into 3 sections**

Replace the flat field list with:

```dart
_CollapsibleSection(
  title: 'Basic Info',
  icon: Icons.info_outline_rounded,
  initiallyExpanded: true,
  children: [
    // title field, description field, genre dropdown, max capacity
  ],
),
Divider(height: 1, color: AppTheme.dividerOf(context)),
_CollapsibleSection(
  title: 'Dates & Registration',
  icon: Icons.calendar_today_rounded,
  children: [
    // start date, end date, funding deadline, registration type, private toggle
  ],
),
Divider(height: 1, color: AppTheme.dividerOf(context)),
_CollapsibleSection(
  title: 'Venue & Transport',
  icon: Icons.place_rounded,
  children: [
    // venue dropdown, parking, transit, rideshare, accessibility, posts toggle, FAQ toggle
  ],
),
```

- [x] **Step 3: Run tests**

Run: `cd FrontEnd && flutter test`
Expected: All pass.

- [x] **Step 4: Commit**

```bash
git add FrontEnd/lib/screens/event/edit_sections/edit_basic_info_section.dart
git commit -m "fix(ui): group edit form into 3 collapsible sections

12 flat fields → 3 collapsible groups (Basic Info, Dates & Registration,
Venue & Transport). Only Basic Info expanded by default."
```

---

### Task 7: Clarify discount step button labels

**Files:**
- Modify: `FrontEnd/lib/screens/event/create_event/step_discounts_milestones.dart`

**Current:** Two confusing buttons: "Add + Apply" vs "Add"
**Target:** Rename to "Apply to Event" vs "Save for Later"

- [x] **Step 1: Find and rename the button labels**

Search for "Add + Apply" and "Add" button labels in the file. Rename:
- "Add + Apply" → "Apply to Event"
- "Add" (the standalone one) → "Save for Later"

Also add a small helper text below each button explaining the difference:
- "Apply to Event" → applied immediately to this event's tickets
- "Save for Later" → saved to your strategy library for future use

- [x] **Step 2: Run tests**

Run: `cd FrontEnd && flutter test`
Expected: All pass.

- [x] **Step 3: Commit**

```bash
git add FrontEnd/lib/screens/event/create_event/step_discounts_milestones.dart
git commit -m "fix(ux): rename confusing discount buttons

'Add + Apply' → 'Apply to Event' with helper text
'Add' → 'Save for Later' with helper text"
```

---

## Phase 5: Brand Color Centralization

**Why:** Social brand colors, auth gradients, and medal colors are duplicated across multiple files. Centralizing them prevents drift and makes the app easier to theme.

### Task 8: Extract brand colors and auth gradient to AppTheme

**Files:**
- Modify: `FrontEnd/lib/config/theme.dart`
- Modify: `FrontEnd/lib/screens/profile/profile_contact_section.dart`
- Modify: `FrontEnd/lib/screens/profile/organizer_profile_screen.dart`
- Modify: `FrontEnd/lib/screens/profile/sponsor_profile_screen.dart`
- Modify: `FrontEnd/lib/screens/auth/login_screen.dart`
- Modify: `FrontEnd/lib/screens/auth/register_screen.dart`
- Modify: `FrontEnd/lib/screens/auth/splash_screen.dart`
- Modify: `FrontEnd/lib/screens/sponsor/sponsorship_categories/bid_leaderboard.dart`

- [x] **Step 1: Add brand colors and gradients to AppTheme**

In `FrontEnd/lib/config/theme.dart`, add after the existing gradient definitions (~line 70):

```dart
  // ─── Third-party brand colours (social media, auth) ───
  static const Color brandInstagram = Color(0xFFE1306C);
  static const Color brandFacebook  = Color(0xFF1877F2);
  static const Color brandLinkedIn  = Color(0xFF0A66C2);
  static const Color brandYouTube   = Color(0xFFFF0000);
  static const Color brandIndigo    = Color(0xFF4F46E5);  // website/email accent

  // ─── Medal colours (leaderboards) ───
  static const Color medalGold   = Color(0xFFD4A017);
  static const Color medalSilver = Color(0xFF9E9E9E);
  static const Color medalBronze = Color(0xFFCD7F32);

  // ─── Auth screen gradient ───
  static LinearGradient authGradient(bool isDark) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? [const Color(0xFF0A0A1A), const Color(0xFF121228)]
        : [const Color(0xFFF0F4FF), const Color(0xFFF8FAFF)],
  );

  // ─── Social/contact section header gradient ───
  static LinearGradient socialHeaderGradient(bool isDark) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? [const Color(0xFF1A1035), const Color(0xFF0D1B3E)]
        : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
  );
```

- [x] **Step 2: Update profile_contact_section.dart**

Replace the `_k` constants (lines 10-15) with `AppTheme.brand*` references. Replace the gradient hex codes (lines 70-71) with `AppTheme.socialHeaderGradient(isDark)`.

- [x] **Step 3: Update organizer_profile_screen.dart**

Replace hex colors in `_socialChip` calls (~lines 568-582) with `AppTheme.brand*` tokens. Replace gradient (~line 522-523) with `AppTheme.socialHeaderGradient(isDark)`.

- [x] **Step 4: Update sponsor_profile_screen.dart**

Same changes as organizer_profile_screen — replace hex colors and gradient.

- [x] **Step 5: Update auth screens**

In `login_screen.dart`, `register_screen.dart`, `splash_screen.dart`: replace hardcoded gradient `colors:` arrays with `AppTheme.authGradient(isDark).colors` or use `AppTheme.authGradient(isDark)` directly.

- [x] **Step 6: Update bid_leaderboard.dart**

Replace `Color(0xFFD4A017)` → `AppTheme.medalGold`, `Color(0xFF9E9E9E)` → `AppTheme.medalSilver`, `Color(0xFFCD7F32)` → `AppTheme.medalBronze`.

- [x] **Step 7: Run tests**

Run: `cd FrontEnd && flutter test`
Expected: All pass.

- [x] **Step 8: Commit**

```bash
git add FrontEnd/lib/config/theme.dart \
       FrontEnd/lib/screens/profile/profile_contact_section.dart \
       FrontEnd/lib/screens/profile/organizer_profile_screen.dart \
       FrontEnd/lib/screens/profile/sponsor_profile_screen.dart \
       FrontEnd/lib/screens/auth/login_screen.dart \
       FrontEnd/lib/screens/auth/register_screen.dart \
       FrontEnd/lib/screens/auth/splash_screen.dart \
       FrontEnd/lib/screens/sponsor/sponsorship_categories/bid_leaderboard.dart
git commit -m "refactor: centralize brand colors, auth gradient, medal colors in AppTheme

- Social brand colors (Instagram, Facebook, LinkedIn, YouTube) → AppTheme.brand*
- Auth gradient → AppTheme.authGradient(isDark)
- Social header gradient → AppTheme.socialHeaderGradient(isDark)
- Medal colors → AppTheme.medalGold/Silver/Bronze
- Eliminates 50+ duplicated hex literals across 8 files"
```

---

## Final Verification

### Task 9: Full test suite + visual smoke test

- [x] **Step 1: Run full test suite**

Run: `cd FrontEnd && flutter test`
Expected: All 658+ tests pass.

- [x] **Step 2: Run dart analyze**

Run: `cd FrontEnd && dart analyze lib/`
Expected: No new errors.

- [x] **Step 3: Visual smoke test checklist**

Launch the app and verify:
- [x] Event cards in home feed: status badges all use 4 colors (blue/amber/grey/red)
- [x] Home tab: status chip colors match the 4-group system
- [x] Explore tab: same 4 colors
- [x] Organizer pledges: 3 primary filters + "More" toggle
- [x] My tickets: 3 primary filters + "Sort & Filter" toggle
- [x] Ticket sales: compact text summary instead of stat chips
- [x] Funding card: amount + progress visible, details behind "Show details"
- [x] Edit event: 3 collapsible sections, Basic Info expanded
- [x] Discount step: buttons say "Apply to Event" / "Save for Later"
- [x] Auth screens: gradient still looks correct in both modes
- [x] Organizer/sponsor profiles: social chips use same colors as before
- [x] Bid leaderboard: gold/silver/bronze still look correct
