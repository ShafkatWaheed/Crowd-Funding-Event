# Admin Business Metrics Dashboard — Feature Plan

## Context

The platform currently has an admin dashboard with event approval, user management, and financial
escrow/dispute views. What is missing is a **business health dashboard** — a single screen that
shows the founder/admin the key startup metrics needed to understand platform growth, retention,
unit economics, and survival at both macro (company) and micro (per-event, per-organizer) scale.

This feature was planned based on the following metric categories identified as critical for
operating and growing the platform as a startup:

- Volume (GMV, events, tickets)
- Revenue (take rate, MRR)
- Retention (repeat organizer rate, churn)
- Growth (MoM and YoY)
- Unit economics (LTV, CAC, payback period, LTV:CAC ratio)
- Product health (event success rate, bid acceptance rate, escrow release rate)
- Company survival (burn rate, runway)
- Funnel (registration → pledge → ticket → sponsor conversion)

---

## Goal

Add a **Business Metrics** tab to the existing admin dashboard that gives the admin a real-time
view of all key startup metrics, drillable at both macro (company-wide) and micro (per-event,
per-organizer) scale.

---

## Metric Definitions

### Volume Metrics
| Metric | Definition | Formula |
|--------|-----------|---------|
| GMV | Total money processed through platform | SUM(ticket sales + pledges + sponsor payments) in period |
| Active Events | Events in selling_tickets or live status | COUNT(events WHERE status IN (...)) |
| Tickets Sold | Total ticket sales in period | COUNT(ticket_sales) in period |
| Active Organizers | Organizers who ran ≥1 event in period | COUNT(DISTINCT organizer_id) in period |

### Revenue Metrics
| Metric | Definition | Formula |
|--------|-----------|---------|
| Revenue | Platform commission kept | SUM(commission_cents + platform_cut_cents) in period |
| Take Rate | Revenue as % of GMV | revenue / GMV × 100 |
| MRR | Monthly recurring revenue from subscriptions | SUM(active subscription fees) — future when subscriptions added |

### Growth Metrics
| Metric | Definition | Formula |
|--------|-----------|---------|
| MoM GMV Growth | GMV change vs last month | (this_month - last_month) / last_month × 100 |
| YoY GMV Growth | GMV change vs same month last year | (this_month - same_month_last_year) / same_month_last_year × 100 |
| MoM Revenue Growth | Revenue change vs last month | same formula on revenue |
| MoM New Organizers | New organizers this month vs last | COUNT(first event created this month) |

### Retention Metrics
| Metric | Definition | Formula |
|--------|-----------|---------|
| Repeat Organizer Rate | % of organizers who ran a 2nd event | COUNT(organizers with ≥2 events) / COUNT(all organizers) × 100 |
| Monthly Organizer Churn | % of organizers who went inactive | COUNT(organizers with no event in last 60 days) / total × 100 |
| Avg Events per Organizer | How often organizers reuse platform | COUNT(events) / COUNT(distinct organizers) |

### Unit Economics
| Metric | Definition | Formula |
|--------|-----------|---------|
| LTV | Avg lifetime revenue per organizer | avg_monthly_revenue_per_organizer × avg_months_active |
| CAC | Cost to acquire one organizer | total_marketing_spend / new_organizers (manual input by admin) |
| LTV:CAC Ratio | Ratio of lifetime value to acquisition cost | LTV / CAC |
| Payback Period | Months to recover CAC | CAC / avg_monthly_revenue_per_organizer |

### Product Health
| Metric | Definition | Formula |
|--------|-----------|---------|
| Event Success Rate | % of events that hit funding goal | COUNT(events WHERE funding_goal_met) / COUNT(events) × 100 |
| Sponsor Bid Acceptance Rate | % of bids accepted by organizers | COUNT(bids WHERE status=accepted) / COUNT(bids) × 100 |
| Escrow Release Rate | % of completed events with full escrow release | COUNT(escrow WHERE stage=fully_released) / COUNT(completed events) × 100 |
| Avg Ticket Conversion | % of registrants who buy a ticket | COUNT(ticket_sales) / COUNT(registrations) × 100 |
| Avg Pledge Conversion | % of registrants who pledge | COUNT(fundings) / COUNT(registrations) × 100 |

### Survival Metrics (Manual Inputs by Admin)
| Metric | Definition | Input |
|--------|-----------|-------|
| Monthly Expenses | Total company expenses | Admin enters manually each month |
| Burn Rate | Monthly cash spent above revenue | expenses - revenue (auto-calculated) |
| Cash on Hand | Current bank balance | Admin enters manually |
| Runway | Months until cash runs out | cash_on_hand / burn_rate (auto-calculated) |

---

## Architecture Plan

### Backend

#### New Repository
`Backend/app/repositories/metrics_repo.py`

All raw SQL/SQLAlchemy queries for metric calculations:
- `get_gmv(db, start_date, end_date)` — sum ticket + pledge + sponsor payments
- `get_revenue(db, start_date, end_date)` — sum all commission fields
- `get_active_organizer_count(db, start_date, end_date)`
- `get_new_organizer_count(db, start_date, end_date)`
- `get_repeat_organizer_rate(db)`
- `get_organizer_churn(db, inactive_days=60)`
- `get_event_success_rate(db, start_date, end_date)`
- `get_bid_acceptance_rate(db, start_date, end_date)`
- `get_escrow_release_rate(db)`
- `get_conversion_funnel(db, event_id=None)` — registration → pledge → ticket → sponsor
- `get_avg_events_per_organizer(db)`
- `get_gmv_by_month(db, months=12)` — for chart data (MoM trend)
- `get_revenue_by_month(db, months=12)` — for chart data
- `get_micro_metrics(db, event_id)` — per-event P&L breakdown
- `get_organizer_metrics(db, organizer_id)` — per-organizer LTV estimate

#### New Service
`Backend/app/services/metrics.py`

Business logic layer — calls repo, computes derived values:
- `get_macro_dashboard(db, period)` — assembles full macro metrics response
- `get_micro_event_metrics(db, event_id)` — per-event breakdown
- `get_micro_organizer_metrics(db, organizer_id)` — per-organizer breakdown
- `compute_mom_growth(current, previous)` — growth rate calculation
- `compute_yoy_growth(current, year_ago)` — YoY calculation
- `compute_ltv_cac(db, cac_input)` — LTV:CAC ratio
- `compute_burn_and_runway(revenue, expenses_input, cash_input)` — survival metrics

#### New API Route
`Backend/app/api/v1/metrics.py`

```python
GET /api/v1/admin/metrics/macro?period=month|quarter|year
GET /api/v1/admin/metrics/micro/event/{event_id}
GET /api/v1/admin/metrics/micro/organizer/{organizer_id}
GET /api/v1/admin/metrics/funnel?event_id={optional}
GET /api/v1/admin/metrics/chart/gmv?months=12
GET /api/v1/admin/metrics/chart/revenue?months=12

POST /api/v1/admin/metrics/inputs
  Body: { monthly_expenses_cents, cash_on_hand_cents, cac_cents }
  — Admin manually sets these for burn/runway/CAC calculations
```

All endpoints: `admin` role only, `ReadDbSession`.

#### New Model (for manual inputs)
`Backend/app/models/metrics_input.py`

```
MetricsInput:
  id
  month (Date — first day of month)
  monthly_expenses_cents (BigInteger)
  cash_on_hand_cents (BigInteger)
  cac_cents (BigInteger, nullable)  -- cost to acquire one organizer
  created_at / updated_at
```

One row per month. Admin updates via admin panel.

#### Migration
`Backend/alembic/versions/xxx_add_metrics_input.py`
- Creates `metrics_inputs` table

---

### Frontend

#### New Repository
`FrontEnd/lib/repositories/metrics_repository.dart`

All HTTP calls for metrics:
- `getMacroDashboard(period)` → `MacroDashboard` model
- `getMicroEventMetrics(eventId)` → `MicroEventMetrics` model
- `getMicroOrganizerMetrics(organizerId)` → `MicroOrganizerMetrics` model
- `getFunnelMetrics({eventId})` → `FunnelMetrics` model
- `getGmvChart(months)` → `List<ChartPoint>`
- `getRevenueChart(months)` → `List<ChartPoint>`
- `saveMetricsInputs(expenses, cashOnHand, cac)` → void

#### New Models
`FrontEnd/lib/models/metrics.dart`

```dart
class MacroDashboard {
  // Volume
  final int gmvCents;
  final int revenueCents;
  final double takeRatePercent;
  final int activeEvents;
  final int ticketsSold;
  final int activeOrganizers;

  // Growth
  final double momGmvGrowth;
  final double yoyGmvGrowth;
  final double momRevenueGrowth;
  final int newOrganizers;

  // Retention
  final double repeatOrganizerRate;
  final double monthlyChurnRate;
  final double avgEventsPerOrganizer;

  // Unit Economics
  final int ltvCents;
  final int cacCents;
  final double ltvCacRatio;
  final double paybackMonths;

  // Product Health
  final double eventSuccessRate;
  final double bidAcceptanceRate;
  final double escrowReleaseRate;
  final double avgTicketConversion;
  final double avgPledgeConversion;

  // Survival (from manual inputs)
  final int monthlyExpensesCents;
  final int burnRateCents;
  final int cashOnHandCents;
  final double runwayMonths;
}

class ChartPoint {
  final DateTime month;
  final int valueCents;
}

class FunnelMetrics {
  final int registrations;
  final int pledges;
  final int ticketSales;
  final int sponsors;
  final double pledgeConversion;
  final double ticketConversion;
  final double sponsorConversion;
}

class MicroEventMetrics {
  final int eventId;
  final String eventTitle;
  final int gmvCents;
  final int revenueCents;
  final int stripeFeesCents;
  final int netProfitCents;
  final double profitMarginPercent;
  final int registrations;
  final int pledgers;
  final int ticketBuyers;
  final int sponsors;
  final bool fundingGoalMet;
}

class MicroOrganizerMetrics {
  final int organizerId;
  final String displayName;
  final int totalEventCount;
  final int gmvCents;
  final int revenueCents;
  final double avgRevenuePerEvent;
  final int monthsActive;
  final int estimatedLtvCents;
}
```

#### New Provider
`FrontEnd/lib/providers/metrics_provider.dart`

State management for the metrics dashboard:
- `loadMacroDashboard(period)` — fetches and stores macro metrics
- `loadFunnel({eventId})` — fetches funnel metrics
- `loadGmvChart(months)` — fetches chart data
- `loadRevenueChart(months)` — fetches chart data
- `saveInputs(expenses, cashOnHand, cac)` — saves manual inputs
- State: `loading`, `error`, `macroDashboard`, `funnelMetrics`, `gmvChart`, `revenueChart`
- Period selector state: `month | quarter | year`

#### New Screen
`FrontEnd/lib/screens/admin/tabs/admin_metrics_tab.dart`

Tab added to existing admin dashboard. Sections:

**1. Period Selector**
- Segmented button: This Month / This Quarter / This Year
- Drives all metric queries

**2. KPI Cards Row — Volume & Revenue**
- GMV (with MoM trend arrow)
- Revenue (with MoM trend arrow)
- Take Rate
- Active Events

**3. KPI Cards Row — Growth**
- MoM GMV Growth %
- YoY GMV Growth %
- New Organizers this period
- Repeat Organizer Rate

**4. GMV & Revenue Chart**
- Line chart — 12-month trend
- Two lines: GMV (blue) and Revenue (green)
- X-axis: months, Y-axis: dollar amounts

**5. Conversion Funnel**
- Visual funnel: Registrations → Pledges → Tickets → Sponsors
- Shows count and % conversion at each step
- Optional: filter by specific event

**6. Unit Economics Panel**
- LTV / CAC / LTV:CAC Ratio / Payback Period
- CAC input field (admin enters manually — e.g., monthly ad spend ÷ new organizers)

**7. Product Health Panel**
- Event Success Rate (with benchmark: target 65%+)
- Bid Acceptance Rate (target 70%+)
- Escrow Release Rate (target 90%+)

**8. Survival Panel**
- Monthly Expenses input (admin editable)
- Cash on Hand input (admin editable)
- Auto-calculated: Burn Rate, Runway (shown with color — green >6mo, yellow 3-6mo, red <3mo)

**9. Micro Drill-Down**
- "View by Event" button → opens list of events with per-event P&L
- "View by Organizer" button → opens list of organizers with per-organizer LTV data

---

## Micro P&L Drill-Down Screens

### Per-Event Metrics Screen
`FrontEnd/lib/screens/admin/admin_event_metrics_screen.dart`

Opened from Micro Drill-Down. Shows for one event:
- GMV breakdown (tickets vs pledges vs sponsors)
- Platform revenue
- Estimated Stripe fees
- Net profit
- Funnel: registrations → pledges → tickets → sponsors
- Funding goal met? (yes/no + % reached)

### Per-Organizer Metrics Screen
`FrontEnd/lib/screens/admin/admin_organizer_metrics_screen.dart`

Opened from Micro Drill-Down. Shows for one organizer:
- Total events run
- Lifetime GMV + revenue generated for platform
- Avg revenue per event
- Months active
- Estimated LTV
- List of their events with individual GMV

---

## Implementation Phases

### Phase 1 — Backend Foundation
1. Create `MetricsInput` model + migration
2. Create `metrics_repo.py` with all query methods
3. Create `metrics.py` service
4. Create `metrics.py` API route, register in router
5. Write backend tests for repo queries

### Phase 2 — Frontend Models & Repository
1. Create `metrics.dart` models
2. Create `metrics_repository.dart`
3. Create `metrics_provider.dart`

### Phase 3 — Macro Dashboard Tab
1. Build `admin_metrics_tab.dart`
2. Add to existing admin dashboard tab list
3. Implement KPI cards, charts, funnel, survival panel
4. Connect to provider

### Phase 4 — Micro Drill-Down
1. Build `admin_event_metrics_screen.dart`
2. Build `admin_organizer_metrics_screen.dart`
3. Add routes in `router.dart`

### Phase 5 — Tests
1. Widget tests for metrics tab
2. Provider unit tests
3. Repository unit tests (mock HTTP)

---

## Dependencies

- **Chart library**: `fl_chart` (already likely in pubspec or easy to add) — for GMV/revenue trend lines
- **No new backend dependencies** — pure SQLAlchemy aggregation queries

---

## Notes

- All monetary values stored and transmitted in **cents** (integers) — consistent with rest of platform
- CAC and expense inputs are **manually entered by admin** — no automated tracking (too complex for v1)
- MRR section is a **placeholder** until subscription tiers are implemented
- Runway color coding: green = safe (>6 months), yellow = warning (3-6 months), red = critical (<3 months)
- All admin metrics endpoints use `ReadDbSession` — no writes except `POST /metrics/inputs`
- YoY metrics will show `N/A` in year 1 (no prior year data)
- Benchmark targets shown next to each metric so admin knows what "good" looks like
