# Monetization System

## Overview

The platform generates revenue through two independent commission streams and a set of trust
mechanisms that protect backers while incentivising organizers to deliver on their promises.

```
                        +---------------------+
                        |   Platform Revenue   |
                        +----------+----------+
                                   |
                  +----------------+----------------+
                  |                                 |
        +---------v----------+          +-----------v---------+
        | Ticket Commission  |          | Funding Commission  |
        |   (default 5%)     |          |    (default 3%)     |
        +--------------------+          +---------------------+
```

Every dollar that flows through the platform -- whether a ticket purchase or a
crowdfunding pledge -- is split into **platform commission** and **organizer net**.
Both rates are stored in `platform_settings` and can be changed by any admin at
any time without a code deploy.

---

## 1. Revenue Streams

### 1.1 Ticket Commission

Charged on every ticket sale at checkout time.

```
Customer pays       $20.00   (final_price_cents after discounts)
                       |
        +--------------+--------------+
        |                             |
  Commission (5%)                Organizer net
     $1.00                         $19.00
  commission_cents            net_to_organizer_cents
  (stored on ticket_sales)    (stored on ticket_sales)
```

**How it works:**

1. Customer selects a tier and clicks **Buy** (or **Get Ticket** for free tiers).
2. `ticket_service.compute_ticket_price()` calculates all discounts
   (common, selective, pledge-based, event/strategy discounts) and returns
   `final_price_cents`.
3. `ticket_service.purchase_ticket()` reads `ticket_commission_percent` from
   `PlatformSettings`, computes `commission_cents = final * pct // 100`,
   and stores it alongside `net_to_organizer_cents` on the `TicketSale` row.
4. Free tickets (`price_cents == 0`) skip discount computation and commission
   entirely -- zero cost, zero commission.

**Database columns (ticket_sales):**

| Column | Type | Description |
|--------|------|-------------|
| `amount_paid_cents` | int | What the customer paid after discounts |
| `commission_cents` | int | Platform's share |
| `net_to_organizer_cents` | int | Organizer's share (`amount_paid - commission`) |

### 1.2 Funding Commission

Charged on every pledge at the moment it is created.

```
Backer pledges      $100.00   (amount_cents)
                       |
        +--------------+--------------+
        |                             |
  Platform cut (3%)              Organizer net
     $3.00                         $97.00
  platform_cut_cents          net_to_organizer_cents
  (stored on fundings)        (stored on fundings)
```

**How it works:**

1. Customer pledges via the Funding Card.
2. `funding_service.create_pledge()` reads `funding_commission_percent` from
   `PlatformSettings`, computes `platform_cut_cents`, and stores both columns
   on the `Funding` row.
3. The organizer-facing funding summary (`GET /events/{id}/funding`) shows
   `total_pledged_cents`, `total_platform_cut_cents`, and
   `total_net_to_organizer_cents` so they know exactly what they will receive.

**Database columns (fundings):**

| Column | Type | Description |
|--------|------|-------------|
| `amount_cents` | int | Gross pledge amount |
| `platform_cut_cents` | int | Platform's share |
| `net_to_organizer_cents` | int | Net amount entering escrow for the organizer |

### 1.3 Community Event Listing Fee

Events with **genre = "community"** are subject to additional rules:

| Rule | Default | Setting Key |
|------|---------|-------------|
| Listing fee | $10 | `community_listing_fee_cents` |
| Max ticket price | $50 / tier | `community_max_ticket_price_cents` |
| Max duration | 14 days | `community_max_duration_days` |
| Funding commission override | _(uses global)_ | `community_funding_commission_override` |

These are enforced at event creation time and surfaced to organizers via an
info banner on the create-event form.

---

## 2. Where the Money Goes: Escrow System

Organizer funds are **never released immediately**. Every funded event has a
`FundEscrow` record that holds the organizer's net and releases it in three
stages tied to real-world milestones.

### 2.1 Three-Stage Release Pipeline

```
 PLEDGE ARRIVES
      |
      v
+--------------------------------------------------+
|              ESCROW (holding)                     |
|                                                   |
|   total_held_cents = SUM(net_to_organizer_cents)  |
|                                                   |
+-----+------------------+------------------+------+
      |                  |                  |
      v                  v                  v
  +-------+         +-------+         +-------+
  | S T 1 |         | S T 2 |         | S T 3 |
  |  30%  |         |  40%  |         |  30%  |
  +---+---+         +---+---+         +---+---+
      |                  |                  |
      v                  v                  v
  Goal met +         48 hours          Event done +
  date set +         before            >= 25%
  venue OK           event start       tickets scanned
```

| Stage | Default % | Trigger | Setting Key |
|-------|-----------|---------|-------------|
| **1 -- Planning** | 30% | Funding goal met **AND** event date set **AND** venue confirmed | `escrow_stage1_percent` |
| **2 -- Ready** | 40% | 48 hours before `start_time` **OR** admin manual release | `escrow_stage2_percent` |
| **3 -- Completed** | 30% | Event status = `completed` **AND** >= 25% of sold tickets scanned | `escrow_stage3_percent` |

Stage 1 is checked automatically after every pledge and every event update.
Stage 3 is checked automatically when an event transitions to `completed`.
Stage 2 can be triggered by a cron job or released manually by admin.

### 2.2 Escrow Lifecycle

```
                     +----------+
                     | holding  |  <-- initial state
                     +----+-----+
                          |
              Stage 1 released
                          |
                          v
               +-------------------+
               | partially_released|
               +----+---------+----+
                    |         |
        Stage 2 released   Admin freezes
                    |         |
                    v         v
               +--------+ +--------+
               |partial | | frozen |
               +----+---+ +---+----+
                    |          |
        Stage 3 released   Admin unfreezes
                    |          |
                    v          v
              +----------------+
              | fully_released |  <-- terminal happy path
              +----------------+

         (If event cancelled at any point)
                    |
                    v
              +----------+
              | refunded |
              +----------+
```

### 2.3 Escrow Data Model

**`fund_escrows` table:**

| Column | Type | Description |
|--------|------|-------------|
| `event_id` | FK (unique) | One escrow per event |
| `total_held_cents` | int | Sum of all `net_to_organizer_cents` from pledges |
| `stage1_released_cents` | int | Amount released at stage 1 |
| `stage1_released_at` | datetime | When stage 1 was released |
| `stage2_released_cents` | int | Amount released at stage 2 |
| `stage2_released_at` | datetime | When stage 2 was released |
| `stage3_released_cents` | int | Amount released at stage 3 |
| `stage3_released_at` | datetime | When stage 3 was released |
| `status` | enum | `holding`, `partially_released`, `fully_released`, `refunded`, `frozen` |

**`escrow_releases` table (immutable audit log):**

| Column | Type | Description |
|--------|------|-------------|
| `escrow_id` | FK | Which escrow |
| `stage` | int | 1, 2, or 3 |
| `amount_cents` | int | How much was released |
| `released_by` | string | `"system"` or `"admin"` |
| `reason` | text | Human-readable reason |

---

## 3. Trust & Safety Mechanisms

### 3.1 Cancellation Gate

When an organizer tries to cancel an event that has reached >= 80% of its
funding goal, the cancellation is **blocked** and routed to an admin approval
queue instead.

```
Organizer clicks "Cancel Event"
           |
           v
    Is pledge% >= 80%?
      /           \
    YES            NO
     |              |
     v              v
  Create           Cancel
  pending_         immediately,
  cancellation     refund all
  JSON on Event    pledges
     |
     v
  Admin sees it
  in "Requests" tab
     |
     +----> Approve  --> cancel + refund
     +----> Reject   --> keep event alive
```

**Setting:** `cancel_approval_threshold_percent` (default 80)

This protects backers from organizers who raise most of the money and then
disappear. The admin can investigate before releasing a cancellation.

### 3.2 Payout Freeze

Admins can freeze payouts at two levels:

| Level | Action | Effect |
|-------|--------|--------|
| **Per-event** | `POST /admin/escrows/{event_id}/freeze` | Sets escrow status to `frozen`; no stage releases possible |
| **Per-organizer** | `POST /admin/organizers/{id}/freeze-payouts` | Sets `payout_frozen = true` on all their events |

Unfreezing is also available via the admin dashboard.

### 3.3 Scan Threshold

Stage 3 funds are only released if at least 25% of sold tickets were actually
scanned at the event (proving the event took place and people attended).

**Setting:** `scan_threshold_percent` (default 25)

If an organizer sells 100 tickets but only 10 are scanned, Stage 3 is held
and the admin can investigate.

---

## 4. Platform Settings Reference

All monetization parameters are stored in the `platform_settings` table and
editable via the admin dashboard Settings tab (`PATCH /admin/settings/{key}`).

### Commission Settings

| Key | Default | Description |
|-----|---------|-------------|
| `ticket_commission_percent` | `5` | % taken from each ticket sale |
| `funding_commission_percent` | `3` | % taken from each pledge |

### Escrow Settings

| Key | Default | Description |
|-----|---------|-------------|
| `escrow_stage1_percent` | `30` | % released at Stage 1 (planning) |
| `escrow_stage2_percent` | `40` | % released at Stage 2 (48h before) |
| `escrow_stage3_percent` | `30` | % released at Stage 3 (completed) |
| `scan_threshold_percent` | `25` | Min % tickets scanned for Stage 3 |
| `new_organizer_deposit_cents` | `5000` | Deposit for first-time organizers ($50) |
| `stage3_grace_days` | `14` | Days Stage 3 is held for review |
| `event_date_deadline_days` | `30` | Days to set event date after goal met |

### Cancellation Settings

| Key | Default | Description |
|-----|---------|-------------|
| `cancel_approval_threshold_percent` | `80` | Pledge % that triggers admin gate |

### Community Event Settings

| Key | Default | Description |
|-----|---------|-------------|
| `community_max_duration_days` | `14` | Max total days |
| `community_listing_fee_cents` | `1000` | Listing fee ($10) |
| `community_max_ticket_price_cents` | `5000` | Max per-tier price ($50) |
| `community_funding_commission_override` | _(empty)_ | Override global funding % |

---

## 5. End-to-End Money Flow

Below is the full lifecycle of money flowing through the platform for a typical
funded event with ticket sales.

```
 BACKER                    PLATFORM                   ORGANIZER
   |                          |                          |
   |--- Pledge $100 --------->|                          |
   |                          |-- Take 3% ($3) -------->REVENUE
   |                          |-- Hold $97 in escrow     |
   |                          |                          |
   |--- Pledge $200 --------->|                          |
   |                          |-- Take 3% ($6) -------->REVENUE
   |                          |-- Hold $194 in escrow    |
   |                          |                          |
   |                     [Goal met + date + venue]       |
   |                          |                          |
   |                          |-- Release S1 (30%) ----->| $87.30
   |                          |                          |
   |                     [48h before event]              |
   |                          |                          |
   |                          |-- Release S2 (40%) ----->| $116.40
   |                          |                          |
 CUSTOMER                     |                          |
   |                          |                          |
   |--- Buy ticket $50 ------>|                          |
   |                          |-- Take 5% ($2.50) ----->REVENUE
   |                          |-- Credit $47.50 -------->|
   |                          |                          |
   |--- Get FREE ticket ----->|                          |
   |                          |-- $0 commission          |
   |                          |                          |
   |                     [Event completed + scans OK]    |
   |                          |                          |
   |                          |-- Release S3 (30%) ----->| $87.30
   |                          |                          |
                         FULLY RELEASED
```

**Platform total revenue from this example:**

| Source | Amount |
|--------|--------|
| Funding commission (3% of $300) | $9.00 |
| Ticket commission (5% of $50) | $2.50 |
| **Total** | **$11.50** |

**Organizer total received:**

| Source | Amount |
|--------|--------|
| Escrow Stage 1 (30% of $291) | $87.30 |
| Escrow Stage 2 (40% of $291) | $116.40 |
| Escrow Stage 3 (30% of $291) | $87.30 |
| Ticket net (95% of $50) | $47.50 |
| **Total** | **$338.50** |

---

## 6. API Endpoints

### Admin

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/admin/stats` | Platform stats including total commission earned |
| `GET` | `/admin/settings` | List all platform settings |
| `PATCH` | `/admin/settings/{key}` | Update a setting value |
| `GET` | `/admin/escrows` | List all escrow records |
| `POST` | `/admin/escrows/{event_id}/release/{stage}` | Manually release a stage (1, 2, 3) |
| `POST` | `/admin/escrows/{event_id}/freeze` | Freeze escrow payouts |
| `POST` | `/admin/escrows/{event_id}/unfreeze` | Unfreeze escrow payouts |
| `POST` | `/admin/organizers/{id}/freeze-payouts` | Freeze all payouts for an organizer |
| `POST` | `/events/{id}/cancellation/approve` | Approve or reject pending cancellation |

### Public / Organizer

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/events/{id}/funding` | Funding summary with commission breakdown |
| `GET` | `/events/{id}/escrow` | Escrow summary (stage statuses, amounts) |
| `GET` | `/events/{id}/ticket-price` | Price preview including commission |

---

## 7. Frontend Visibility

| Who | What they see |
|-----|---------------|
| **Admin** | Settings tab (edit commission rates), Overview stats (total commission earned), Escrow tab (stage timeline, freeze/release controls), Requests tab (pending cancellations) |
| **Organizer** | Ticket sales show "Net $X.XX" per sale, total net revenue chip on sales pages, funding commission % on funding card |
| **Customer** | "FREE" badge on $0 tiers, "Get Ticket" button for free tiers, platform fee note on pledge dialog, escrow trust indicator ("Pledges held in platform escrow until milestones are met"), commission included in purchase receipt snackbar |

---

## 8. Database Schema (New Tables)

```
platform_settings
+-----------+-----------+-------------+
| id (PK)   | key (UQ)  | value       |
|           |           | description |
+-----------+-----------+-------------+

fund_escrows
+-----------+----------+-------------------+
| id (PK)   | event_id | total_held_cents  |
|           | (FK, UQ) |                   |
|           |          | stage1_released_* |
|           |          | stage2_released_* |
|           |          | stage3_released_* |
|           |          | status (enum)     |
+-----------+----------+-------------------+

escrow_releases
+-----------+-----------+-------+--------------+
| id (PK)   | escrow_id | stage | amount_cents |
|           | (FK)      |       | released_by  |
|           |           |       | reason       |
+-----------+-----------+-------+--------------+

ticket_sales (new columns)
  + commission_cents
  + net_to_organizer_cents

fundings (new columns)
  + platform_cut_cents
  + net_to_organizer_cents

events (new columns)
  + pending_cancellation (JSON)
  + terms_accepted_at
  + payout_frozen (bool)
```
