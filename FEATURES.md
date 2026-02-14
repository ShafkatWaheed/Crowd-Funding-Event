# Crowd Funding Event — Features

This document lists **implemented features**, **unused endpoints**, **completed phases**, and **unimplemented items**.

---

## Currently Implemented

### Authentication & Users
- Firebase Auth (email/password), backend token verify, login/register screens
- Roles: admin, organizer, customer
- Profile (GET/PATCH /me): display name, phone, username (mandatory)
- Email hidden everywhere except admin dashboard

### Venues
- CRUD for organizers (create, read, update, delete)
- List: organizers see own; customers see all
- Inline venue creation on the Create Event page
- **Search bar** on Venues page — filter by name, address, or capacity

### Events — CRUD & Lifecycle
- Create event (organizer/admin) with genre (required), posts toggle, funding fields
- **Community rules toggle** on create/edit (draft only) — applies platform community rules to any event regardless of genre; locked once event leaves draft
- **Two-date system:** Event Date (start/end) and Funding Deadline are independent — at least one must be set before publishing
- **Publish validation:** Cannot publish without setting at least one of `funding_end_at` or `start_time`; frontend shows inline hint and disables button until satisfied
- **Mandatory funding goal:** When a funding deadline is set, a funding goal is required (enforced on both create and update)
- **Edit event:** Draft and unpublished (pending_approval) events edit freely; only **substantive field changes** (title, description, dates, funding settings, genre, etc.) on approved/waiting events move to `pending_approval` for re-approval. **Operational changes** (venue, capacity, ticket strategy, posts toggle) never trigger re-approval. Admin edits bypass approval entirely.
- **Delete event:** Only `draft` or `cancelled` events can be permanently deleted
- Cancel event (with mandatory reason) — available for unpublished, approved, and waiting_event_date events (direct cancel); **selling_tickets requires admin approval** (organizer sends cancellation request, admin reviews and approves/rejects)
- Reactivate cancelled event (cancelled -> draft)
- Publish draft event (draft -> approved); status label shows **"Under Review"** instead of "Unpublished" for `pending_approval`
- **Clone completed events** into a new draft with **editable title** (dialog prompts for new title, defaults to "Original Title (Copy)"), all parameters pre-filled (no dates, preserves community rules)
- **Venue picker** — full-page searchable screen for selecting a venue (highlights current selection)
- **Strategy picker** — full-page searchable screen for selecting a ticket strategy (shows tier details, highlights current selection)

### Event Lifecycle State Machine
- **Statuses:** `draft` → `pending_approval` → `approved` → `selling_tickets` / `waiting_event_date` → `live` → `completed`
- **Both Fund + Event date set:** After funding deadline passes → `selling_tickets` (pledge/unregister blocked, buy tickets only) → at event start → `live` → at event end → `completed`
- **Only Fund date set:** After funding deadline → `waiting_event_date` (organizer has configurable grace period to set event date, default 7 days via `event_date_grace_days` admin setting). If deadline passes without date → auto-cancel + refund registered users (guest pledges held for admin). Once date set → `selling_tickets` → `live` → `completed`
- **Only Event date set:** Goes to `selling_tickets` (no funding phase) → `live` → `completed`
- **Auto-transition:** Status transitions are checked automatically on every event fetch (no cron jobs)
- **State restrictions:** Pledge and unregister blocked in `selling_tickets`, `waiting_event_date`, `live`, `completed`
- **Terminal state:** `completed` is the only true dead-end — no transition out; only action is to clone into a new draft
- **Near-terminal:** `live` can only transition to `completed` (automatic on end_time) or `cancelled`
- **Status-aware organizer actions:**
  - **Funding phase** (`approved`): increase capacity, change venue, change ticket strategy
  - **Waiting for event date** (`waiting_event_date`): increase capacity, change venue, change ticket strategy, set event date, extend funding
  - **Selling tickets** (`selling_tickets`): increase capacity, increase ticket price; cannot change venue or edit event details
  - **Live** (`live`): increase capacity, increase ticket price; venue and event details locked
  - **Completed** (`completed`): read-only summary; clone only

### Refund Policy
- Refund deadline auto-calculated as **20% of funding duration** (organizer can customize within that range)
- **Backend enforces max 20% cap** on both create and update — returns error if exceeded
- Refund deadline shown as an interactive **slider** (not text field) capped at the calculated max
- Refund deadline field only appears in create/edit when funding deadline is set
- Customers refunded if they unregister before the refund cutoff; no refund after

### Event Discovery & Search
- Multi-parameter search: text, status, registration type, date range, city, has-funding, has-tickets, min/max capacity, genre
- **Home tab search:** Real search bar on the home tab searches events by name, venue, or genre — results displayed as a grid directly on the home tab
- **Genre chip filter:** Tapping a genre chip on the home tab filters events by that genre in-place (toggle on/off); combinable with text search
- Genre filter on Explore tab (community, music, tech, sports, arts, food, charity, education, business, other)
- Featured sections: Trending (by registration count), Popular (by pledge amount), Coming Soon (future approved), **Community Events** (events with community rules enabled)
- "My Events" tab for logged-in customers (events they're registered to, including cancelled); **auto-reloads** when switching to the tab or pull-to-refresh; genre chips + text search
- Status filter hides draft/pending/cancelled for customers; shows all for organizers/admins
- When searching/filtering on home tab, featured sections are replaced by search results grid with filter banner and "Clear" button

### Co-Organizer Management
- Main organizer can **add/remove co-organizers** for their event
- **Permission levels:** `read` (view info, management stats, scan tickets) or `full` (all organizer actions including edit, discounts, etc.)
- Dedicated **Co-Organizers screen** (`/events/{id}/co-organizers`) with add form, permission selector (ChoiceChip), and team list
- Main organizer always has `full` permission; co-organizers cannot modify the organizer team
- `user_can_edit_event` enforced server-side — only `full` co-organizers can write; `read` co-organizers can only view via `user_can_read_event_mgmt`

### Registration & Waitlist
- Open/closed (waitlist) registration
- Register, unregister, check registration status
- Capacity checks, waitlist auto-promote on type change
- Registration count denormalized on event model
- **Two distinct waitlist types:**
  - **Fund Waitlist** — registrations placed on waitlist when event is at capacity during funding phase
  - **Ticket Waitlist** — tickets purchased after capacity is reached are placed on a ticket waitlist (`TicketSaleStatus.waitlisted`)
- **Unified Waitlist screen** with segmented toggle filter to switch between Fund Waitlist and Ticket Waitlist views, with live count badges on each tab
- **Per-event Waitlist** (`/events/{id}/waitlist`) — shows both fund and ticket waitlist for that specific event with approve/reject actions
- **Global Waitlist** (`/manage/waitlist`) — aggregates both fund and ticket waitlists across all organiser events with search, accessible from Manage tab
- Both waitlist views support search, count badges, and approve/reject actions

### Funding & Pledges
- Pledge money to event (customer) — only during `approved` (funding active) status
- **Unregistered customers** trying to pledge see a "Please register first" disclaimer
- Unpledge with refund (non-guest pledges)
- Guest pledge with non-refundable disclaimer
- Funding goal (mandatory when funding deadline is set), min pledge, funding deadline
- **Detailed time remaining:** Funding cards show days + hours + minutes left (e.g. "2d 5h 30m left"), with color-coded urgency (green → orange → red); deadline displays include date AND time
- Total pledged & time left displayed on event detail and event cards
- Pledging blocked after funding ends (selling_tickets / waiting / live / completed)
- **Pledge/unpledge buttons hidden for organizers and admins** — only customers see pledge actions in the Funding Card
- **Self-contained Funding Card** — pledge/unpledge actions only refresh the funding section (not the entire page); card loads its own data via `getFundingSummary()` and shows backers count, progress bar, deadline, and min pledge

### Ticket Strategies (Reusable Templates)
- **Separate reusable object** (like venues) — organizers create ticket strategies with named tiers
- Each strategy has tiers (e.g. "Platinum", "Diamond", "General") with name, description, price, and display order
- **No per-tier quantity** — capacity is enforced at the event level via `max_capacity`; excess purchases go to ticket waitlist
- Strategies linked to events via **full-page searchable picker** on create/edit/event-detail screens
- **Required when no funding deadline is set;** optional when funding deadline is set (can be added later during `waiting_event_date`)
- Inline strategy creation form on the Create Event page
- Tier descriptions explain what each ticket tier provides
- **Re-selecting the same strategy** re-populates tiers if they were manually deleted
- **Tier deletion prevented** during `selling_tickets` and `live` states (active sales exist)
- CRUD endpoints: list, create, get, update, delete strategies
- **Search bar** on Ticket Strategies page — filter by strategy name, tier name, or tier description

### Event Discounts
- **EventDiscount rules** attached to events — organizers create discount rules from the dedicated Discounts screen
- **Three discount types:** `ticket_percent` (% off ticket price), `pledge_percent` (% of customer's pledge amount as discount), `fixed_cents` (flat amount off)
- **Three targeting modes:** `all` (everyone), `pledgers` (only customers who pledged), `non_pledgers` (only customers who did NOT pledge)
- **Discount cap:** total discount (common + selective + pledge + event discounts) cannot exceed the ticket price
- **Customer view:** "Your Discounts" section on event detail shows applicable discount rules with calculated amounts
- Discounts stack with existing `common_discount_percent`, `pledge_discount_percent`, and `UserEventDiscount` (per-user selective)
- CRUD: `GET /events/{id}/discounts/rules`, `POST /events/{id}/discounts/rules`, `DELETE /events/{id}/discounts/rules/{discount_id}`
- Customer endpoint: `GET /events/{id}/my-discounts` returns applicable discounts with computed amounts

### Reusable Discount Strategies
- **Global discount strategies** — organizers create reusable discount templates from the Manage tab's Discounts page
- Two types: `ticket_percent` (% off ticket) and `pledge_percent` (% of pledge amount)
- Targeting: `all`, `pledgers`, `non_pledgers` (pledge_percent auto-excludes non_pledgers)
- **Attach to events:** searchable dropdown on event detail and create event pages (max 3 results)
- **Two attach modes:** "Add + Apply" (auto-applied to all eligible customers) or "Add" (customers must manually claim)
- **Customer-facing Discount Page** — customers browse and claim non-auto-apply discounts per event
- Discounts applied during ticket price computation; auto-apply and claimed discounts both considered
- Discount cap: total discount cannot exceed ticket price
- Discounts can be edited/attached without admin approval

### Customer Loyalty Tracking
- **OrganizerCustomerHistory** — auto-populated when a ticket is scanned (records organizer, customer, event, scan time)
- **Dedicated Customers screen** (`/manage/customers`) accessible from the Manage tab
- Lists all unique customers who attended the organizer's events, with **event count** and **"Loyal" badge** for repeat attendees (2+ events)
- Search bar + stats (total customers, repeat customers)
- Endpoint: `GET /me/customers`

### Organizer Trust Score
- **Trust score** = completed events / total published events (approved or beyond) for the organizer
- **Labels:** New (no completed events), Low (< 20%), Fair (20–49%), Good (50–79%), Excellent (80%+)
- **Trust badge pill** in event detail hero header — color-coded pill with icon (verified checkmark for Excellent, shield for Fair, warning for Low, person for New), shows label + percentage, tooltip shows "X completed / Y published events"
- **Funding Card trust indicator** — escrow banner includes trust score line with colored badge alongside the escrow message
- **Escrow Stage 1 bump** — organizers with trust score > 0.8 get 40% released at Stage 1 instead of the default 30%
- **Endpoints:** `GET /events/{id}/organizer-trust` (standalone), also included as `organizer_trust` in every `EventResponse`
- Backend: `get_organizer_trust_score()` in event service; integrated into `release_stage1()` in escrow service

### Tickets
- Ticket tiers copied from strategy to event on creation
- Ticket tier list on event detail screen with name, description, and price
- **Ticket tier edit & delete** — organizer can update name, description, price or delete tiers via edit/delete icons on the Manage Ticket Tiers section
- **Detailed discount breakdown** — each ticket tier shows a line-by-line price calculation: base price, common discount, selective discount, pledge discount, event-strategy discount, total discount, and final price; displayed for both customers (in ticket tiers section) and organizers (in manage ticket tiers section)
- **Free tickets from overwhelming discounts** — if combined discounts exceed the ticket price, final price is clamped to $0.00 and displayed as "FREE" (no negative prices)
- Price preview with discounts (common + pledge-based + selective + event discounts, capped at ticket price)
- Purchase ticket dialog with tier selection showing actual discounted prices per tier; "FREE" label for $0 tiers; "Get Ticket" instead of "Buy" for free tiers
- Scan ticket by QR code (organizer/admin) — **auto-records customer attendance** for loyalty tracking
- **Per-event Ticket Sales page** — full-page view with search, stats (total sold, revenue), per-sale detail (attendee, tier, code, amount, scan status)
- **Per-event Scanned Tickets page** — full-page filtered view showing only scanned tickets with search and "scanned by" info
- **Global All Ticket Sales page** (`/manage/ticket-sales`) — aggregates sales across all organiser events with search, accessible from Manage tab
- **Global Scanned Tickets page** (`/manage/scanned-tickets`) — aggregates scanned tickets across all events with search, accessible from Manage tab
- **Ticket Waitlist** — tickets purchased after event capacity is reached get `waitlisted` status; organizer can approve/reject from unified waitlist screen
- **Live management stat chips** on event detail — status-aware 2×2 grid of clickable chips; early phases show registered count, fund waitlist, capacity badge; selling/live phases show tickets sold, scanned, ticket waitlist, revenue; completed shows all as read-only summary
- **Capacity badge** — "Registered/Max Capacity" visual indicator with color coding (green → orange → red)

### Like / Dislike System
- Users (customers/organizers) see like & dislike buttons, can toggle reactions
- Like count visible to everyone (event detail + event cards)
- Dislike count hidden from users; admin sees both like & dislike counts (read-only, no buttons)
- One reaction per user per event; toggle off or switch
- **Self-contained `_ReactionBar` widget** — tapping like/dislike only refreshes the reaction counts, not the entire page
- Backend returns both `like_count` and `dislike_count` in react response for local state update

### Event Posts / Feed
- Registered users can post on event wall; **unregistered users see a "Please register first" disclaimer**
- Organizer can toggle posts on/off per event
- Posts listed with author name, time-ago display
- Delete option for post author, organizer, or admin
- **Self-contained `_EventFeed` widget** — posting/deleting only refreshes the feed section, not the entire page
- **Refresh button** in feed header — tap to manually reload posts

### Event Images / Gallery
- Add images by URL with optional caption
- Horizontal scrollable gallery on event detail
- Organizer/admin can add/delete images

### Sharing & Calendar
- Share event link (copy to clipboard)
- **Add to Calendar** — copies the `.ics` download URL for import into any calendar app
- Both actions now live in the **Quick Action Bar** on event detail (not in AppBar)

### Extend Funding (with Admin Approval)
- Organizer can request to extend funding deadline and/or funding goal from `waiting_event_date` events
- **Admin approval required** — organizer's request is stored as `pending_extension` on the event (includes new funding deadline and/or new funding goal)
- Admin approves/rejects via the **Extensions tab** in the Admin Dashboard or inline on event detail
- When approved, funding parameters are applied and status reverts from `waiting_event_date` to `approved` (re-opens funding)
- Admins can apply extensions directly (no pending state)
- Dialog with fields for new funding deadline and new funding goal

### Set Event Date (Direct Action)
- Organizer can set event start/end times directly from `waiting_event_date` status — **no admin approval needed**
- Setting the event date transitions the event from `waiting_event_date` → `selling_tickets`
- Separate dialog from Extend Funding with start time and end time pickers
- "Set Event Date By" deadline label shown on event detail

### Admin Dashboard
- Overview tab: platform stats (total users, events, revenue)
- Pending Approval tab: events edited by organizers needing re-approval (approve/reject)
- **Extensions tab:** events with pending funding extension requests (new deadline + goal) — admin approve/reject with details
- Drafts tab: draft events list with publish/delete actions
- Users tab: full user list with email visible (masked for non-admin)
- **Settings tab:** all platform settings displayed with distinct icons/colors and intelligent formatting (cents → dollars, percents, days); includes commission rates, community rules thresholds, escrow percentages, grace period days — all admin-editable
- **Escrow tab:** events with held funds, stage timeline, freeze/unfreeze
- **Requests tab:** pending cancellation requests from organizers (for events ≥80% funded OR events in selling_tickets status); context label shows funding % or event status as applicable

### Frontend Screens & UX
- **Uber-inspired UI** — black/white/green accent, Inter font, rounded containers, subtle shadows
- **Bottom navigation bar** with 4 tabs: Home, Explore, Manage (organizer/admin) / My Events (customer), Profile
- **Manage tab** — quick-action cards: Row 1 (Create Event, Venues, Tickets, Admin); Row 2 (All Sales, Scanned, Waitlist); Row 3 (Discounts) — each opens a global management page; Waitlist card opens unified screen with fund/ticket toggle
- **Profile tab** embedded directly in the bottom nav — shows user avatar, name, phone, role badge, grouped menu sections (Account, Management), sign-out button. Bottom bar persists.
- **Close (X) icon** on all inner screens — uses safe pop navigation: returns to the tab/page the user came from (falls back to home if no history)
- Login screen: Uber-styled with custom "CF" logo, bold headings, grey-filled inputs, full-width black sign-in button
- Home tab: hero header with user greeting, real search bar, genre chips, featured event carousels
- Explore tab: dedicated search + advanced filters, events in grid
- **Uber-style lifecycle bar** on every event card and detail screen showing progress through stages
- **Event Detail — Modern Layout:**
  - **Hero header:** large bold title (28px), inline status pill with color dot, genre pill, "X joined" pill
  - **Quick Action Bar:** pill-shaped container with Register/Registered, Share, and Calendar buttons side-by-side; registered state shows green "Registered" with checkmark; unregister by tapping it
  - **Self-contained reaction bar** (like/dislike) — updates only itself
  - **About card** — description in a white bordered card with "About" section header
  - **Funding Card** — self-contained widget with progress bar, raised/goal, backers, deadline, min pledge, inline Pledge/Unpledge buttons; refreshes only itself
  - **Details card** — icon-badge rows with small label + bold value for dates, capacity, registration type, refund policy; color-coded values
  - **Event Feed** — self-contained widget with refresh button; post/delete only updates the feed
  - Ticket tiers, discounts, state banners, buy tickets, organizer actions, management section
  - **Transparent AppBar** with circular close button
  - State-dependent actions (register/pledge only during funding; buy tickets during selling_tickets/live)
  - **Cancel flow:** direct cancel for pre-selling statuses; "Request Cancellation" button for organizer during selling_tickets (sends to admin queue, shows pending banner); admin can cancel selling_tickets directly
  - Clone button for completed events with editable title dialog, "Set Event Date" & "Extend Funding" for waiting_event_date
  - Co-Organizers & Discounts management links, pending extension banner (admin approve/reject inline)
  - "Your Discounts" section for customers
  - **Status-aware organizer actions** — modern card-based UI with `_primaryActionCard` (publish, reactivate, start selling, clone), `_setupTile` grid (event date, venue, strategy, capacity), and `_menuTile` list (edit, toggle posts, change venue, increase capacity, extend funding, cancel, delete) — all conditionally shown based on event status
- **Create Event form layout:** Title/Description/Genre → Community Rules toggle → Dates & Funding Deadline (with refund slider) → Max Capacity & Registration Type → Venue (searchable picker) → Ticket Strategy (searchable picker + inline create) → Funding Settings (if applicable) → Posts/Publish toggles
- Edit Event: pre-filled form with date pickers, warning banner for live/approved events; **Community Rules toggle visible only in draft state** (locked after leaving draft)
- **Modern error/success toasts** (`AppToast`) — floating rounded snackbar with icon, color-coded (red error, green success, orange warning, blue info), auto-dismisses, swipe to dismiss; replaces all raw `SnackBar` calls across the entire app
- **Backend error extraction** (`ApiService.extractError`) — automatically pulls `detail` message from FastAPI error responses, handles Pydantic validation arrays, connection timeouts, and auth errors; used by all provider catch blocks and `AppToast.fromError()`
- Profile, Venues, Admin Dashboard

### API Documentation
- Swagger at `/api/v1/docs`, redirect from `/docs`

---

## Completed Features (by Phase)

| Phase | Features |
|-------|----------|
| Phase 1 | Display names (hide email), phone field, share button, mandatory username |
| Phase 2 | Cancel reason, unpledge/refund, guest pledge disclaimer, multi-param search, trending/popular/coming-soon |
| Phase 3 | Event post/feed system, event genres/categories, event image gallery |
| Post-Phase 3 | Edit event with approval rules (draft=free, live=needs approval), like/dislike system, edit event screen, admin pending-approval tab |
| Phase 4 | Two-date event lifecycle (fund datetime + event datetime), new statuses (selling_tickets, waiting_event_date, completed), auto-transition engine, clone completed events, refund deadline as 20% of funding duration, state-dependent UI actions, Uber-style lifecycle progress bar, funding deadline picker on create/edit |
| Phase 5 | Reusable ticket strategies with tiers (name, description, price), inline creation, event linkage, ticket-strategy CRUD endpoints, ticket tier display & purchase on event detail |
| Phase 6 — UI Polish | Uber-inspired UI overhaul (theme, login, home, event cards, bottom nav), profile tab in bottom bar, close (X) icon on all inner screens, home-tab search & genre filter, form layout reorder (dates before venue/tickets), refund slider with 20% cap enforcement, edit/cancel/delete for unpublished events, ticket tier URL fixes |
| Phase 7 — Event Mgmt Tools | Add-to-Calendar button, Waitlist Approve/Reject UI, Ticket Tier Edit & Delete, Ticket Sales Dashboard with stats, Scanned Tickets sub-tab, backend `description` passthrough for tier create/update |
| Phase 7b — Global Mgmt & Search | Per-event sales/scanned/waitlist as full pages with search; Global aggregated pages (/manage/ticket-sales, /manage/scanned-tickets, /manage/waitlist) accessible from Manage tab; Live 2×2 stat chips on event detail (sold, scanned, waitlisted, revenue); Search bars on Venues and Ticket Strategies pages; Close (X) uses safe pop navigation to return to source tab |
| Phase 8 — Organizer Tools | **Co-Organizer Management** with read/full permissions; **Event Discounts** (pledge %, ticket %, fixed, targeting pledgers/non-pledgers/all, capped at ticket price); **Reusable Discount Strategies** (global templates, attach with auto-apply or customer-claim modes, customer discount page); **Customer Loyalty Tracking** (auto-records attendance on ticket scan, Customers page with repeat badges); **Extend Funding with Admin Approval** (pending extension → admin approve/reject in Dashboard + inline); Admin Dashboard Extensions tab; Manage tab Discounts quick-action |
| Phase 8b — Reactive UI & UX | **Self-contained widgets:** Funding Card (pledge/unpledge refresh only card), Reaction Bar (like/dislike refresh only itself), Event Feed (post/delete refresh only feed + refresh button); **Registration gate:** unregistered users see "Please register first" for pledge and feed post; **Modern event detail redesign:** hero header with status/genre/joined pills, Quick Action Bar (register + share + calendar), About card, Details grid with icon badges, transparent AppBar; **My Events tab auto-reload** on tab switch + pull-to-refresh |
| Phase 9c — Post-Business Polish | **Mandatory funding goal** when funding deadline is set; **Detailed funding time display** (days+hours+minutes with color-coded urgency); **Configurable grace period** for setting event date after funding ends (`event_date_grace_days` admin setting, default 7 days); **Delete restricted** to draft/cancelled only; **Pledge/unpledge hidden** from organizers/admins on Funding Card; **Refactored Extend Funding** into separate "Extend Funding" (deadline + goal, needs admin approval) and "Set Event Date" (direct, no approval); **Detailed discount breakdown** per ticket tier (base, common, selective, pledge, event-strategy, total, final price) for customers and organizers; **Free tickets** from overwhelming discounts (clamped to $0, displayed as FREE); **Community event rules** decoupled from genre — toggle switch on create/edit (draft only), backend enforced, `community_rules` boolean on Event model, admin-configurable thresholds, "Community Events" section on home page; **Navigation fix** — proper pop/refresh after event creation |
| Phase 9d — Event Management & UX Polish | **Status-aware event management UI** — modernized organizer actions on event detail with card-based layout (`_primaryActionCard`, `_setupTile`, `_menuTile`) that adapts to event lifecycle status; **Status-aware live management stats** (`_LiveMgmtStats`) showing different metrics per phase (registered/waitlist/capacity in early phases, sold/scanned/revenue in selling/live); **Capacity badge** (registered/max with color coding); **Ticket waitlist system** — purchases exceeding capacity get `waitlisted` status with approve/reject flow; **Unified waitlist screens** — per-event and global waitlist screens combined with segmented Fund/Ticket toggle filter and live count badges; **Removed tier quantity** — capacity enforced at event level only, no per-tier quantity; **Searchable venue & strategy pickers** — full-page screens with search, current selection highlighting; **Selective re-approval** — only substantive field changes trigger `pending_approval` (operational changes like venue/capacity/strategy bypass re-approval); **Strategy re-application** — re-selecting same strategy recreates tiers if manually deleted; **Tier deletion prevention** during selling_tickets/live; **Clone with editable title** — dialog prompts for new title; **"Under Review" label** for pending_approval status; **Publish validation** — requires at least one of event date or funding deadline; **Modern error toasts** (`AppToast`) — floating, color-coded, icon-bearing snackbar replacing all raw SnackBar calls across 18 screens; **Backend error extraction** (`ApiService.extractError`) — auto-pulls `detail` from FastAPI responses for all provider catch blocks; **Organizer Trust Score** — score = completed/published events ratio, labels (New/Low/Fair/Good/Excellent), color-coded badge pill in event hero header + funding card escrow banner, trusted organizers (>0.8) get Stage 1 escrow bumped to 40% |

---

## Unimplemented Features (To Do)

### Backend Ready — Needs Frontend UI

These features have **working backend endpoints** but no frontend screen/button yet. Sorted by priority.

| # | Feature | Description | Backend Endpoints | Priority |
|---|---------|-------------|-------------------|----------|
| 1 | **Map View** | Show events on an interactive map, filter by bounding box, radius, or city | `GET /events/map` | High |

### No Backend Yet — Needs Full Implementation

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| 1 | **Cancellation Email** | When an event is cancelled, send email to all registered users with the cancellation reason | High |
| 2 | **Unpledge Confirmation Email** | Send email when a user successfully unpledges | Medium |
| 3 | **Organizer Verification** | Verification flow for organizers (identity/contact check before they can publish events) | Medium |
| 4 | **File Upload for Images** | Replace URL-based image adding with actual file upload to cloud storage (S3/GCS) | Medium |
| 5 | **Ticket Encryption** | Encrypt QR codes / ticket data so they cannot be forged | Medium |
| 6 | **Location-Based Discovery** | Show events near the user based on browser geolocation or saved location | Medium |
| 7 | **Parking / Transport Info** | Structured fields in event description for parking, transit, Uber-style directions | Low |
| 8 | **Verify Organizer via External Apps** | Use third-party verification service or app for organizer identity | Low |
| 9 | **Chatbot for Support** | In-app chatbot for user support and FAQ | Low |
| 10 | **Newcomer / Trending Badges** | Newcomer badge for new organizers, trending indicator on tickets/events | Low |

### Phase 9 — Business Logic (COMPLETED)

| # | Feature | Status |
|---|---------|--------|
| 9.1 | **Platform Commission (Tickets + Funding)** | Done — `PlatformSettings` model, `ticket_commission_percent` (5%), `funding_commission_percent` (3%), commission on every ticket sale & pledge, admin Settings tab, commission displayed on receipts, ticket sales pages, funding card |
| 9.2 | **Admin Approval at 80% Pledge + Selling Tickets** | Done — `pending_cancellation` JSON on Event, cancel blocked when ≥80% funded OR when event is in `selling_tickets` status (non-admin), routes to admin approval queue, admin dashboard Requests tab shows cancellations with context (funding % or event status), organizer sees "Cancellation Pending" banner, "Request Cancellation" button with reason dialog for selling_tickets organizers |
| 9.3 | **Free Tickets / Flexible Pricing** | Done — Schema validates `price_cents >= 0`, "FREE" badge on tiers, "Get Ticket" button, discount/commission skipped on $0 tickets |
| 9.4 | **Community Event Rules** | Done — Decoupled from genre: `community_rules` boolean toggle on create/edit (draft only). Rules: max 14-day duration, max $50/tier, $10 listing fee. All thresholds admin-configurable in `PlatformSettings`. "Community Events" featured section on home page |
| 9.5 | **Fund Escrow & Release Gates** | Done — `FundEscrow` + `EscrowRelease` models, 3-stage release (30/40/30), auto Stage 1 on goal+date+venue, admin Escrow tab with stage timeline + freeze/unfreeze, escrow trust indicator on Funding Card |
| 9.6 | **Organizer Trust Score** | Done — Score = completed / published events. Labels: New/Low/Fair/Good/Excellent. Color-coded badge pill on event detail header + Funding Card. Trusted organizers (>80%) get Stage 1 escrow bumped to 40%. Endpoint: `GET /events/{id}/organizer-trust` + included in `EventResponse` |

---

## Planned Phases (Upcoming)

### Phase 9 — Business Logic (Backend + Frontend)

Core money and platform rules. Estimated: **2–3 sessions**.

#### 9.1 — Platform Commission (Tickets + Funding)

**Goal:** The platform takes a configurable percentage on **both** ticket sales and funding (pledge) amounts as revenue. Two separate rates so admin can tune them independently.

**Commission on Tickets**

| Layer | What to Build |
|-------|---------------|
| **Model** | New `PlatformSettings` table (key-value) — `ticket_commission_percent` (default 5%), stored as integer (e.g. 5 = 5%) |
| **Migration** | Create `platform_settings` table, seed with `ticket_commission_percent = 5` |
| **Admin API** | `GET /admin/settings` — returns all settings; `PATCH /admin/settings` — update a setting (admin only) |
| **Ticket Purchase** | In `ticket_service.purchase_ticket()`, after computing `final_price_cents`: calculate `commission_cents = final_price_cents * ticket_commission_percent // 100`. Store on `TicketSale`. Net to organizer = `final_price_cents - commission_cents` |
| **TicketSale model** | Add columns: `commission_cents` (int, default 0), `net_to_organizer_cents` (int) |
| **Customer View** | Receipt in purchase snackbar: "Paid $X.XX (includes $Y.YY platform fee)" |

**Commission on Funding (Pledges)**

| Layer | What to Build |
|-------|---------------|
| **PlatformSettings** | `funding_commission_percent` (default 3%), stored as integer |
| **Migration** | Seed `funding_commission_percent = 3` alongside ticket commission |
| **Pledge Service** | In `create_pledge()`: calculate `platform_cut_cents = pledge_amount * funding_commission_percent // 100`. Store on the Funding record. Net to organizer = `pledge_amount - platform_cut_cents` |
| **Funding model** | Add columns: `platform_cut_cents` (int, default 0), `net_to_organizer_cents` (int) |
| **Unpledge** | On unpledge: refund the full pledge amount to customer (platform absorbs the cut loss, or recalculate — admin-configurable policy) |
| **Funding Card** | Show "Raised $X (platform fee: Y%)" subtle text under the progress bar |
| **Organizer View** | Funding summary shows: Total Pledged, Platform Fee, Net to You |

**Shared Admin & Reporting**

| Layer | What to Build |
|-------|---------------|
| **Admin Dashboard** | New "Settings" tab — cards for ticket commission % (1–20%) and funding commission % (1–10%) with save buttons. Overview tab: add "Total Ticket Commission" and "Total Funding Commission" stat cards |
| **Organizer View** | In manage pages, show combined platform fees: ticket commission total + funding commission total. Per-sale breakdown in ticket lists |
| **Event Detail** | Revenue stat chip shows gross; sub-text shows "after X% ticket + Y% funding commission" |

#### 9.2 — Admin Approval at 80% Pledge

**Goal:** When an event reaches ≥80% of its funding goal, the organizer can no longer cancel or delete it without admin approval — protects backers from losing a nearly-funded event.

| Layer | What to Build |
|-------|---------------|
| **Backend Check** | In `cancel_event()` and `delete_event()` services: if `total_pledged / funding_goal >= 0.80`, block the action and create a pending cancellation request instead |
| **Event Model** | Add `pending_cancellation` JSON column (like `pending_extension`) — stores `{ reason, requested_at, requested_by }` |
| **Migration** | Add `pending_cancellation` column to events |
| **Admin API** | `POST /admin/events/{id}/cancellation/approve` and `POST /admin/events/{id}/cancellation/reject` |
| **Admin Dashboard** | New "Cancellations" sub-section in Pending Approval tab (or its own tab) showing events with pending cancellation — approve/reject buttons |
| **Organizer UX** | When cancel is blocked: show dialog "This event is 82% funded. Your cancellation request has been sent to admin for approval." Event detail shows "Cancellation Pending" banner |
| **Threshold** | Use `PlatformSettings` key `cancel_approval_threshold_percent` (default 80) so admin can adjust |

#### 9.3 — Free Tickets / Flexible Pricing

**Goal:** Support $0 ticket tiers for free events, RSVP-only events, or free-tier + paid-tier combos.

| Layer | What to Build |
|-------|---------------|
| **Backend** | Remove any `price_cents > 0` validation on `TicketTier` creation/update (currently not enforced, just allow `0`) |
| **Frontend** | In ticket tier display: if `price_cents == 0`, show "FREE" badge instead of "$0.00". In purchase dialog: "Get Ticket" instead of "Buy" for free tiers. Skip commission on $0 tickets |
| **Discount Logic** | If base price is 0, skip all discount computation (no negative prices) |
| **Validation** | `price_cents >= 0` enforced in schema (no negative values) |

#### 9.4 — Community Event Rules (Decoupled from Genre)

**Goal:** Community events have special restrictions to keep them accessible. Rules are applied via a `community_rules` toggle (not tied to any genre), configurable by admin.

| Rule | Community Rules ON | Community Rules OFF |
|------|-------------------|---------------------|
| **Max duration** | 14 days (funding + event combined) | No limit |
| **Listing fee** | $10 flat fee charged to organizer on publish | No fee |
| **Funding commission override** | Uses global `funding_commission_percent` from 9.1 (or higher community override if configured) | Uses global `funding_commission_percent` from 9.1 |
| **Max ticket price** | $50 per tier | No limit |

| Layer | What Was Built |
|-------|---------------|
| **Event Model** | `community_rules` boolean field (default false), independent of `genre` |
| **Backend Validation** | In `create_event()` / `update_event()`: if `community_rules == true`, enforce max duration, max tier price. On publish, deduct listing fee. `community_rules` can only be changed while event is in `draft` status |
| **PlatformSettings** | Keys: `community_max_duration_days=14`, `community_listing_fee_cents=1000`, `community_max_ticket_price_cents=5000`, `community_funding_commission_override=null` (null = use global rate) — all admin-configurable |
| **Frontend Create** | Toggle switch "Community Event Rules" with description — available on create and edit (draft only); shows info banner with active rules when enabled |
| **Frontend Edit** | Toggle visible only when event status is `draft`; hidden and locked for all other statuses |
| **Home Page** | "Community Events" featured section showing events with `community_rules=true` |
| **Backend Filter** | `GET /events?community_rules=true` query parameter to list community events |
| **Admin** | Settings tab shows community-specific rules alongside other platform settings |

#### 9.5 — Fund Escrow & Release Gates

**Goal:** Never release pledged money to organizers in one lump sum upfront. Hold it in escrow and release in stages tied to real proof that the event is progressing and will actually happen. This is the platform's core leverage.

**How it works — 3-stage release:**

| Stage | Trigger | % Released | What It Proves |
|-------|---------|------------|----------------|
| **Stage 1 — Planning** | Funding goal met + event date confirmed + venue confirmed | **30%** | Organizer committed to a real date and place — not vapourware |
| **Stage 2 — Ready** | 48 hours before event start (auto) OR admin manual release | **40%** | Event is imminent; organizer needs funds for final logistics (vendors, setup, etc.) |
| **Stage 3 — Completed** | Event marked `completed` + minimum scan threshold met (e.g. ≥25% of tickets scanned) | **30%** | Event actually happened — we have ticket-scan proof of attendance |

**If the organizer fails at any stage:**

| Scenario | What Happens |
|----------|-------------|
| Goal met but no event date set within X days | Admin notified → warning to organizer → if no response, auto-refund all backers, organizer flagged |
| Event cancelled before Stage 2 | Unreleased funds returned to backers (minus any already-released Stage 1) |
| Event cancelled after Stage 2 | Admin reviews case — partial refund from Stage 1+2 if organizer cooperates, or platform insurance pool covers it |
| Event happens but scan threshold not met | Stage 3 held for 14 days → admin reviews → can manually release or refund |
| Organizer never marks event completed | Auto-check: if `end_time` has passed + 7 days with no completion, admin notified to investigate |

**Additional leverage mechanisms:**

| Mechanism | Description |
|-----------|-------------|
| **Organizer Deposit** | First-time organizers must place a refundable deposit (e.g. $50) before publishing a funded event. Returned after first successful event (Stage 3 complete). Stored in `PlatformSettings` as `new_organizer_deposit_cents` |
| **Trust Score** | **IMPLEMENTED** — Computed as completed events / published events. Labels: New (0), Low (<20%), Fair (20–49%), Good (50–79%), Excellent (80%+). Displayed as color-coded badge pill in event detail header + inside Funding Card escrow indicator. Organizers with score > 0.8 get escrow Stage 1 bumped from 30% to 40%. Endpoint: `GET /events/{id}/organizer-trust`. Also included in `EventResponse.organizer_trust` on every event fetch. |
| **Payout Freeze** | Admin can freeze any organizer's pending payouts with one click if fraud is suspected. New admin action: `POST /admin/organizers/{id}/freeze-payouts` |
| **Terms Agreement** | On publish, organizer must accept terms: "I agree that funds are held in escrow and released upon meeting milestones. Failure to deliver the event may result in fund clawback and account suspension." Stored as `terms_accepted_at` on Event |

**Data model:**

| Model | Fields |
|-------|--------|
| **FundEscrow** (new) | `event_id`, `total_held_cents`, `stage1_released_cents`, `stage1_released_at`, `stage2_released_cents`, `stage2_released_at`, `stage3_released_cents`, `stage3_released_at`, `status` (holding / partially_released / fully_released / refunded / frozen) |
| **EscrowRelease** (new, audit log) | `escrow_id`, `stage` (1/2/3), `amount_cents`, `released_at`, `released_by` (system/admin), `reason` |
| **Event** (updated) | `terms_accepted_at`, `payout_frozen` (bool) |
| **PlatformSettings** | `escrow_stage1_percent=30`, `escrow_stage2_percent=40`, `escrow_stage3_percent=30`, `scan_threshold_percent=25`, `new_organizer_deposit_cents=5000`, `stage3_grace_days=14`, `event_date_deadline_days=30` |

**Admin Dashboard additions:**

- "Escrow" tab showing all events with held funds, current stage, amounts, and release/freeze buttons
- Per-event escrow timeline: visual progress (Stage 1 ✓ → Stage 2 pending → Stage 3 locked)
- "Frozen Payouts" section with organizer details and investigation notes

**Organizer Dashboard additions:**

- "My Earnings" section showing: Total Pledged → Platform Fee → Escrow Breakdown (released / pending / locked)
- Clear milestone checklist: "Set event date ✓ → Confirm venue ✓ → 48h before event → Complete event"
- Banner: "30% of funds released — next release: 48 hours before your event"

**Customer Funding Card:**

- "Your pledge is held in platform escrow until the event is confirmed and completed"
- Trust indicator based on organizer's score

#### Phase 9 Summary & Dependencies

```
PlatformSettings (new model)
    ├── ticket_commission_percent → 9.1 (tickets)
    ├── funding_commission_percent → 9.1 (pledges)
    ├── cancel_approval_threshold_percent → 9.2
    ├── community_* settings → 9.4 (community rules, decoupled from genre)
    ├── event_date_grace_days → 9c (configurable grace period)
    ├── escrow_stage*_percent → 9.5
    ├── scan_threshold_percent → 9.5
    ├── new_organizer_deposit_cents → 9.5
    └── stage3_grace_days, event_date_deadline_days → 9.5

TicketSale (updated)
    ├── commission_cents → 9.1
    └── net_to_organizer_cents → 9.1

Funding (updated)
    ├── platform_cut_cents → 9.1 (applied to ALL events with funding)
    └── net_to_organizer_cents → 9.1

FundEscrow (new) → 9.5
    └── tracks held / released / frozen funds per event

EscrowRelease (new, audit log) → 9.5
    └── immutable record of every release

Event (updated)
    ├── pending_cancellation (JSON) → 9.2
    ├── community_rules (bool) → 9.4 (decoupled from genre)
    ├── terms_accepted_at → 9.5
    └── payout_frozen → 9.5

Recommended build order: 9.3 (smallest) → 9.1 (revenue) → 9.2 (cancel protection) → 9.5 (escrow — the big one) → 9.4 (genre rules)
```

### Phase 10 — Notifications & Email

Estimated: **1–2 sessions**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 1 | **Cancellation Email** | Medium | Backend: email service (SendGrid/SES), send on cancel with reason to all registered users. Template design |
| 2 | **Unpledge Confirmation Email** | Small | Backend: trigger email on successful unpledge with refund details |

### Phase 11 — Media & Maps

Estimated: **2 sessions**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 1 | **Map View** | Large | Frontend: integrate map library (Leaflet/Google Maps), plot events by lat/lng, connect to `GET /events/map` |
| 2 | **Location-Based Discovery** | Medium | Frontend: browser geolocation API, pass coords to backend map endpoint, "Near Me" section on home tab |
| 3 | **File Upload for Images** | Large | Backend: S3/GCS integration, upload endpoint. Frontend: file picker replacing URL input |

### Phase 12 — Trust & Security

Estimated: **2 sessions**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 1 | **Organizer Verification** | Large | Backend: verification request model, document upload, admin review queue. Frontend: verification status badge, submission form |
| 2 | **Ticket Encryption** | Medium | Backend: encrypt ticket codes with a secret key, verify on scan |
| 3 | **Feature Flags / Admin Controls** | Medium | Backend: settings table with key-value pairs. Frontend: admin panel to toggle features |

### Phase 13 — Nice to Have

Lowest priority. Estimated: **1–2 sessions**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 1 | **Parking / Transport Info** | Small | New fields on event model, display section on detail |
| 2 | **Newcomer / Trending Badges** | Small | Backend: badge logic based on organizer age / event stats. Frontend: badge display on cards |
| 3 | **Verify Organizer via External Apps** | Large | Third-party API integration — scope TBD |
| 4 | **Chatbot for Support** | Large | Standalone feature — could use an off-the-shelf widget or build custom |

**Recommended order:** Phase 9 → 10 → 11 → 12 → 13. Phase 9 adds real business value (commission = revenue). Phase 10 adds trust (users get notified). Phases 11–13 are enhancements.

---

## File Location

- **Path:** `Crowd_Funding_Event/FEATURES.md`
- Update this file as features are implemented or new requests are added.
