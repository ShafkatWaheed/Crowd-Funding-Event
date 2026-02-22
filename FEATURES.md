r# Crowd Funding Event — Features

This document lists **implemented features**, **unused endpoints**, **completed phases**, and **unimplemented items**.

---

## Currently Implemented

### Authentication & Users
- Firebase Auth (email/password), backend token verify, login/register screens
- Roles: admin, organizer, customer, sponsor
- Profile (GET/PATCH /me): display name, phone, username (mandatory)
- Email hidden everywhere except admin dashboard

### Venues
- CRUD for organizers (create, read, update, delete)
- List: organizers see own; customers see all
- Inline venue creation on the Create Event page
- **Search bar** on Venues page — filter by name, address, or capacity
- **Mapbox address autocomplete** on venue creation — typing an address shows Mapbox Geocoding v6 suggestions; selecting a suggestion auto-fills address, city, province, and lat/lng (hidden fields); green checkmark and coordinates shown when location is resolved
- Lat/lng fields hidden from user — auto-populated from geocoding selection

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
- **Spot release on live transition:** All unredeemed reserved spots from pledges are released (set to 0) when the event transitions to `live`, recalculating capacity based on actual tickets sold
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
- Featured sections: Trending (by registration count), Popular (by pledge amount), Coming Soon (future approved), **Community Events** (events with community rules enabled), **Near Me** (events within 25km of user's location via geolocation)
- "My Events" tab for logged-in customers (events they're registered to, including cancelled); **auto-reloads** when switching to the tab or pull-to-refresh; genre chips + text search
- Status filter hides draft/pending/cancelled for customers; shows all for organizers/admins
- When searching/filtering on home tab, featured sections are replaced by search results grid with filter banner and "Clear" button
- **Map View on Explore tab** — List/Map toggle pill switches between event grid and interactive Mapbox map (dark-v11 style); markers show event locations with green pins for live events; blue count badges for multiple events at one venue; **venue name label** displayed above each pin; tapping a marker opens a bottom sheet listing all events at that venue with navigation to event details
- **Location-Based Discovery** — "Near Me" section on Home tab uses device geolocation (geolocator package) to fetch events within 25km radius; graceful fallback when location permission is denied

### Co-Organizer Management
- Main organizer can **add/remove co-organizers** for their event
- **Permission levels:** `read` (view info, management stats, scan tickets) or `full` (all organizer actions including edit, discounts, etc.)
- Dedicated **Co-Organizers screen** (`/events/{id}/co-organizers`) with add form, permission selector (ChoiceChip), team list, and **full dark mode support**
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
- **Capacity impact preview on waitlist:** Each waitlist card shows what capacity would become if approved; ticket waitlist cards warn in red when approval would exceed capacity; capacity summary bar at top shows tickets sold, reserved spots, available slots with progress indicator

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
- **Spot Reservation during Funding** — customers can reserve ticket spots while pledging; see dedicated section below

### Spot Reservation during Funding
- **Concept:** During the funding phase, customers can pledge money and simultaneously reserve a specific number of ticket spots, giving pledgers first-chance access to tickets
- **Organizer-defined limit:** `max_reserved_spots_per_user` field on event (set during create/edit) — controls how many spots each user can reserve
- **Minimum pledge enforcement:** Each reserved spot requires a minimum pledge of `min_pledge_cents` × spots; the pledge amount must be >= `reserved_spots × min_pledge_per_spot`
- **Capacity tracking:** Reserved spots count towards `max_capacity` — capacity formula: `tickets_sold + total_reserved_spots`
- **Guest restriction:** Unregistered (guest) users cannot reserve spots, as they cannot purchase tickets later
- **3-step pledge flow:** Spot selector (choose spots + enter amount) → Invoice preview (shows pledge details, reserved spots, platform commission, net to organizer) → Receipt screen (full confirmation with receipt number)
- **Receipt number generation:** Unique receipt number format `PLG-YYYYMMDD-eventId-pledgeId` generated on each pledge
- **Pledge receipt screen:** Dedicated screen showing receipt number, event title, pledge amount, reserved spots, fee breakdown (platform fee %, net to organizer), and reserved spot info banner
- **Pledge discount adjustment:** When a user has reserved spots, the pledge-based discount is divided by the number of reserved spots to compute the per-ticket discount; users with no reserved spots get the full pledge discount
- **Reserved spot consumption on ticket purchase:** When a user with reserved spots buys tickets, their reserved spots are consumed first before affecting general ticket capacity; ticket invoice dialog shows "Using 1 of your X reserved spot(s) from pledging"
- **Unredeemed spot release:** When the event transitions to `live` status, any unredeemed reserved spots are released back into the general capacity pool (`reserved_spots` set to 0 for all active pledges)
- **Capacity decrease guard:** Organizers cannot reduce `max_capacity` below the sum of already sold tickets + unredeemed reserved spots
- **Funding Card display:** Shows "X spots reserved" alongside backers count; capacity display shows `reg + reserved / max` when reserved spots exist
- **Capacity info endpoint:** `GET /events/{id}/capacity-info` returns `max_capacity`, `tickets_sold`, `total_reserved_spots`, `occupied`, `available`, `registration_count`

### Funding Milestones
- **Percentage-based milestones** on funded events — organizers define milestones that unlock as funding reaches each percentage threshold
- **Milestone model:** `FundingMilestone` (id, event_id, title, description, unlock_percent, benefit_description, sort_order, like_count, dislike_count)
- **Per-milestone reactions:** `MilestoneReaction` (like/dislike per user per milestone, same toggle pattern as event reactions)
- **Automatic unlock:** `is_unlocked` computed from `total_pledged_cents / goal_cents * 100 >= unlock_percent`
- **6 API endpoints** under `/events/{id}/milestones`: list (public), create/update/delete (organizer), react and get-my-reaction (authenticated)
- **Feature-flagged:** All endpoints gated by `feature_milestones_enabled` admin setting
- **Milestone Timeline widget** on event detail below FundingCard — vertical progress bar with circular nodes (blue+checkmark when unlocked, grey+lock when locked), milestone cards with percentage, title, benefit description, UNLOCKED/LOCKED badges, per-milestone like/dislike
- **Organizer milestone builder** — collapsible section in create/edit event forms (after Funding Settings, visible when funding deadline is set); title, unlock % slider (1-100), benefit description

### Feature Flags (Admin Toggles)
- **Admin can enable/disable features platform-wide** from the Settings tab using Switch toggles
- **3 feature flags:** `feature_milestones_enabled`, `feature_schedule_enabled`, `feature_sponsors_enabled` (all default true)
- **Backend guard:** `require_feature()` dependency raises 403 when flag is disabled
- **Frontend:** `getFeatureFlags()` API method; UI sections hidden seamlessly when their flag is disabled
- Boolean settings auto-detected and rendered as switches (not text edit dialogs)

### Event Schedule / Agenda
- **Structured event schedule** — date/time-slot based agenda for multi-day events
- **Schedule model:** `EventScheduleItem` (id, event_id, date, start_time, end_time, title, description, sort_order)
- **`has_schedule` toggle** on Event model — organizer explicitly opts into structured schedule
- **Grouped by date** — API returns schedule items grouped into `ScheduleDayGroup` (date + items list), sorted by date then start_time
- **Overlap detection:** computed `overlaps: bool` per item when time ranges intersect on the same date
- **Excel export:** public `GET /export` endpoint generates `.xlsx` workbook with one sheet per date (via openpyxl)
- **6 API endpoints** under `/events/{id}/schedule`: list grouped (public), create/update/delete (organizer), bulk create (organizer), export .xlsx (public)
- **Feature-flagged:** All endpoints gated by `feature_schedule_enabled` admin setting
- **Schedule Timeline widget** on event detail — horizontal date tab pills, vertical timeline with blue nodes and time-slot cards, amber nodes/border for overlapping slots with "Overlaps" badge, Excel download button, summary footer
- **Organizer schedule builder** — collapsible section in create/edit event forms (after Dates, visible when both start and end dates set); "Use structured schedule" switch, date groups with constrained date pickers, time slot cards with start/end time pickers + title + description

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
- **Multi-ticket purchase** — customers can buy 1–10 tickets in a single transaction via a quantity counter on the invoice dialog; all-or-nothing capacity check (either all tickets purchased or all waitlisted); reserved spots consumed first (`min(quantity, user_reserved)`), remainder checked against general capacity
- **Purchase group** — multi-ticket purchases are linked by `purchase_group_id` on `TicketSale`; each ticket gets its own unique `ticket_code` and `receipt_number`
- **Aggregated invoice** — quantity selector on the invoice dialog shows per-ticket and total price breakdown, total discount saved, total platform fee; button text adapts ("Buy 3 Tickets" / "Get Free Ticket")
- **Aggregated purchase receipt** — `PurchaseGroupReceiptScreen` shows purchase summary (event, organizer, attendee, tier, quantity, total paid, discount, commission) followed by individual ticket cards each with a unique QR code
- **Individual ticket receipt with QR code** — each ticket receipt displays a centered QR code between the TICKET and PAYMENT sections, encoding structured JSON (`receipt_number`, `event_id`, `user_id`, `sale_id`, `ticket_code`) for organizer scanning
- **QR code scanning** — organizer scans QR code to automatically mark the specific ticket as scanned; scan status viewable in ticket sales lists
- Scan ticket by QR code (organizer/admin) — **auto-records customer attendance** for loyalty tracking
- **Per-event Ticket Sales page** — full-page view with search, stats (total sold, revenue), per-sale detail (attendee, tier, code, amount, scan status); **scanned/total stats banner** shows "X scanned / Y total sold" with progress bar
- **Per-event Scanned Tickets page** — full-page filtered view showing only scanned tickets with search, "scanned by" info, and scanned/total stats banner
- **Global All Ticket Sales page** (`/manage/ticket-sales`) — aggregates sales across all organiser events with search, accessible from Manage tab; **single API call** via `GET /me/organizer-ticket-sales` (single SQL join query, no N+1); each card tappable to view full ticket receipt
- **Global Scanned Tickets page** (`/manage/scanned-tickets`) — aggregates scanned tickets across all events with search, accessible from Manage tab; uses same single-query endpoint with `scanned_only=true`
- **Per-event Ticket Sales page** titled "Event Ticket Sales" to distinguish from global view
- **Ticket Waitlist** — tickets purchased after event capacity is reached get `waitlisted` status; organizer can approve/reject from unified waitlist screen
- **"Your Tickets" section on event detail** — shows the customer's tickets for the current event with scanned count ("X of Y scanned"), mini-cards with status badges, and link to full receipt; "View All" navigates to My Tickets
- **My Tickets screen grouped by event** — tickets grouped under event headers with ticket count and scanned count; event header tappable to navigate to event detail; search, status filters (all/purchased/waitlisted/cancelled), scanned stat chip
- **Live management stat chips** on event detail — status-aware 2×2 grid of clickable chips; early phases show registered count, fund waitlist, capacity badge; selling/live phases show tickets sold, scanned, ticket waitlist, revenue; completed shows all as read-only summary
- **Capacity badge** — "Registered/Max Capacity" visual indicator with color coding (green → orange → red)

### Terms and Conditions Agreement
- **Signup agreement** — organizers and customers must agree to role-specific terms during registration via a checkbox with tappable "Terms and Conditions" link
- **Role-specific terms content** — organizer terms cover platform fees, escrow policy, refund rules, clawback, account suspension; customer terms cover pledging, spot reservation, refund policy, escrow protection, tickets, community rules
- **Terms screen** — dedicated `TermsScreen` displays formatted terms with role badge, accessible from signup (via link) and profile (Legal section)
- **Backend support** — `terms_accepted_at` timestamp on User model, passed during signup via `verifyToken()`, stored on user creation
- **Profile access** — "Terms & Conditions" ListTile in Legal section on Profile screen navigates to TermsScreen with the user's role
- **Router** — `/terms?role=customer|organizer` route for direct navigation

### Email Notifications (Provider-Agnostic + ARQ Background Tasks)
- **Provider-agnostic architecture** — `EmailBackend` abstract base class with pluggable backends; swap providers by changing `EMAIL_PROVIDER` in `.env`
- **SendGrid backend** (default) — production email delivery via SendGrid v3 Web API
- **Console backend** — logs emails to stdout for development/testing without a real provider
- **Generic config** — `EMAIL_ENABLED` (master kill switch), `EMAIL_PROVIDER`, `EMAIL_API_KEY`, `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME`
- **ARQ background sending** — all emails enqueued as ARQ tasks via Redis (replaced `BackgroundTasks`); `enqueue()` helper with graceful Redis-down fallback; emails survive pod restarts
- **Graceful failure** — all email functions wrapped in try/except with logging; email errors never break the API
- **11 email types with Uber-themed HTML templates** (inline CSS, mobile-friendly, black/white/green accent):
  - **Event Cancelled** — sent to all registrants and ticket buyers when an event is cancelled
  - **Cancellation + Refund** — sent to pledgers when event is cancelled (includes individual refund amount)
  - **Ticket Purchased** — receipt email to buyer with tier, code, receipt number, amount, quantity, discount, commission
  - **Unpledge Refund** — confirmation when a user unpledges with refund details
  - **Unregister Refund** — confirmation when a user unregisters and receives a refund
  - **Waitlist Ticket Rejected** — notification to buyer when their waitlisted ticket is rejected
  - **Ticket Refund Approved** — sent to customer when organizer approves their ticket refund request (tier, amount, receipt #)
  - **Waitlist Ticket Approved** — sent to customer when organizer approves their waitlisted ticket (ticket code, "bring your QR")
  - **Sponsor Bid Approved** — sent to sponsor when organizer accepts their bid (category, bid amount)
  - **Sponsor Bid Rejected** — sent to sponsor when organizer rejects their bid (category, bid amount)
  - **Sponsor Payment Refunded** — sent to sponsor when organizer refunds their paid bid (category, refund amount, receipt #)
- **Trigger points:** cancel event, admin approve cancellation, auto-cancel lifecycle, purchase ticket, unpledge, unregister, reject waitlisted ticket, approve waitlisted ticket, approve ticket refund, accept/reject/refund sponsor bid
- **Cancellation email logic** — queries all affected users (registrants, pledgers, ticket buyers), deduplicates by email, sends refund variant to pledgers and generic variant to others

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

### Dark Mode
- **Full dark mode support** — toggleable from the Profile screen via `ThemeProvider`
- **Persistent theme** — user's preference saved to `SharedPreferences` and restored on app launch
- **`AppTheme` dark palette** — dedicated dark colors (`_dkSurface`, `_dkCard`, `_dkTextPrimary`, `_dkTextSecondary`, `_dkDivider`, `_dkInputFill`) with context-aware helpers (`cardOf()`, `textPrimaryOf()`, `surfaceOf()`, etc.)
- **Comprehensive screen coverage** — dark mode applied to: Home, Explore, Manage, Profile, Event Detail (management section, stat chips, capacity badge, status bar), Ticket Sales, Ticket Strategies, Discounts, Co-Organizer, Venue Picker, Ticket Receipt (QR code forced white background), My Tickets, bottom navigation bar (accent color for active tab)
- **Near-black color detection** — chips and badges dynamically swap near-black colors to `accentColor` in dark mode for visibility

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

### Privacy Rules
- **Attendee email hidden** from all receipt screens — removed from `TicketReceiptResponse` and `PurchaseGroupReceiptResponse`
- **Organizer name fallback** — all receipt and sponsor endpoints use `display_name` instead of `email` when available (5 backend fallback points fixed in `events.py`, `users.py`, `sponsors.py`, `services/sponsor.py`)
- Organizer email/phone preserved on receipts for contact purposes

### Event Bookmarks
- **Bookmark toggle** — customers can bookmark/unbookmark events via a single `POST /events/{id}/bookmark` endpoint
- **Bookmark icon** on event cards (Home, Explore, Manage tabs) and event detail AppBar — filled when bookmarked, outline when not
- **Bookmarked Events screen** (`/bookmarks`) — dedicated screen with search bar and event status filter chips
- **Batch check** — `POST /events/bookmarks/check` returns bookmark status for multiple events in one call (avoids N+1 on list pages)
- **"Bookmarks" quick action** in Manage tab for all roles
- Local `Set<int>` maintained for instant UI feedback before server response
- Backend: `Bookmark` model with unique constraint on `user_id + event_id`, Alembic migration `jj70j1k2l3m4`

### In-App Notification System
- **23 notification types** — `NotificationType` enum covering registration, waitlist, cancellation, ticket purchase, refund, bid actions, event approval/rejection, event updates, and more
- **Backend model** — `Notification` table with `user_id`, `type`, `title`, `message`, `data` (JSON), `is_read`, `created_at`; Alembic migration `mm00m4n5o6p7`
- **Notification service** — `create_notification()`, `create_bulk_notifications()`, `list_notifications()`, `unread_count()`, `mark_read()`, `mark_all_read()`
- **4 API endpoints** under `/me/notifications` — GET list, GET unread-count, PATCH mark-read, PATCH mark-all-read
- **13 backend trigger points** wired across:
  - `events.py`: register (confirmed + waitlisted + organizer notified on waitlist), update (bulk notify registrants), cancel (bulk notify all), publish, pledge, unregister/refund, purchase ticket, approve/reject waitlisted ticket
  - `sponsors.py`: place bid (notify organizer), accept/reject bid (notify sponsor)
  - `registration.py`: approve/reject waitlist
  - `admin.py`: approve/reject event (notify organizer)
- **Frontend provider** — `NotificationProvider` with 30-second polling for unread count, auth-based start/stop
- **Notification bell** in home screen AppBar with unread count badge
- **Notification screen** — per-type icons and colors, shimmer loading, pull-to-refresh, mark-all-read action, tap to navigate to event detail

### Organizer Public Profile
- **Public profile endpoint** — `GET /users/{id}/public-profile` returns display name, username, role, trust score, event count
- **Public events endpoint** — `GET /users/{id}/public-events` returns organizer's published events
- **Organizer Profile screen** (`/organizer-profile/:id`) — full profile page with stats, event list, average rating
- **Tappable organizer name** on event detail — opens bottom sheet with profile summary and "View Full Profile" link
- `organizer_name` added to `EventResponse` for display without extra API call

### Enhanced Sponsor Info for Organizers
- **Sponsor public profile endpoint** — `GET /users/{id}/sponsor-public-profile` returns company name, profession, logo, bid stats, average rating
- **Sponsor Profile screen** (`/sponsor-profile/:id`) — full sponsor profile page with company info, bid history, ratings
- **Tappable sponsor names** on bid management and organizer sponsors screens — opens bottom sheet with sponsor profile summary

### Sponsorship Category Prerequisites
- **Two new models** — `CategoryPrerequisite` (category_id, title, description, is_required, file_type) and `BidPrerequisiteUpload` (prerequisite_id, bid_id, file_url, status: pending/approved/rejected, reviewer_notes)
- **Alembic migration** `kk80k2l3m4n5` for both tables
- **6 API endpoints** — create/list/delete prerequisites (organizer), upload document (sponsor), list uploads per bid, review upload (organizer approve/reject)
- **Bid acceptance guard** — `accept_bid()` blocked if any required prerequisite uploads are not approved; categories with no prerequisites pass automatically
- **Frontend — Organizer** — prerequisite CRUD sheet on sponsorship categories screen, document review UI on bid management cards (approve/reject with notes)
- **Frontend — Sponsor** — upload documents sheet on bid cards, status indicators (pending/approved/rejected) per prerequisite

### Multi-Directional Rating System
- **Rating model** — `Rating` table with `event_id`, `rater_user_id`, `rated_user_id`, `direction` (customer_to_organizer, organizer_to_customer, organizer_to_sponsor, sponsor_to_organizer), `score` (1-5), `description`; unique constraint on event+rater+rated+direction
- **Alembic migration** `ll90l3m4n5o6` with indexes
- **4 API endpoints** — `POST /events/{id}/ratings` (create), `GET /events/{id}/ratings` (event summary with averages), `GET /events/{id}/ratings/all` (full list), `GET /users/{id}/ratings-received` (user summary)
- **Reviews section on completed events** — aggregate stats (average score, count) + top 5 best/worst reviews
- **Star picker + description form** for submitting ratings on completed events
- **All-reviews bottom sheet** for organizers to see full review list
- **Ratings on profiles** — average rating displayed on organizer and sponsor profile screens
- **Reusable widgets** — `StarRating` (interactive input) and `StarRatingDisplay` (read-only display)

### Sponsor Ticket Scan Count
- **`scan_count` column** added to `SponsorTicket` model — incremented on every scan (no longer a one-time operation)
- **Alembic migration** for the new column
- **Backend** — `scan_sponsor_ticket()` increments `scan_count` on every scan; `scanned_at` still set once on first scan
- **Frontend** — `scanCount` displayed on sponsor ticket card and receipt; ticket scanner screen handles both customer and sponsor tickets with mode toggle

### Event Creation Wizard (Multi-Step Form)
- **5-step wizard** replacing the single long form — uses `IndexedStack` for state persistence across steps:
  1. **Basics** — title, description, genre, community rules toggle
  2. **Funding** — funding deadline, funding goal, min pledge, reserved spots, refund slider, funding milestones
  3. **Dates & Tickets** — event start/end dates, event schedule, ticket strategy, discount strategies
  4. **Location & Sponsors** — venue picker, parking/transport info, sponsorship categories
  5. **Review & Publish** — summary of all fields, posts toggle, publish/draft toggle
- **Step indicator** — horizontal step circles with labels, current step highlighted, completed steps marked
- **Step error indicators** — red circle with badge icon on steps that have validation failures
- **Conditional validation** — funding deadline OR event dates required (not both); if funding deadline set, event dates optional and vice versa
- **Unsaved changes dialog** — confirmation prompt when closing with unsaved input
- **Loading/error states** — shimmer loading and error-with-retry for async data (venues, strategies, discounts)
- **Real-time date validation** — inline conflict warnings (end before start, event start before funding deadline)
- **Description character count** — live counter showing X / 2000
- **Contextual Next button** — label shows upcoming step name ("Next: Funding", "Next: Dates & Tickets", etc.)

### Milestone Discounts & Early Bird Discounts
- **Milestone discounts** — `FundingMilestoneSnapshot` + `FundingMilestoneUser` tables track which users had active pledges when each funding milestone was crossed
- **Automatic snapshot** — `_check_milestone_snapshots()` triggers on every pledge; when funding crosses a milestone percentage, all current pledgers are recorded
- **Discount application** — `compute_ticket_price()` applies the best milestone discount the user qualifies for (highest milestone reached while they had an active pledge)
- **Early bird discounts** — `EarlyBirdDiscount` table with `applies_to` (funding/tickets), time windows, and discount values
- **Funding early bird** — pledges within the early bird window get `is_early_bird=True` on the `Funding` record
- **Full CRUD** — endpoints on `/events/{id}/early-bird-discounts` for organizer management
- **Organizer discount cap** — `max_discount_percent` on `Event` (default 100); all discount types stack (standard + milestone + early bird), then the cap is applied
- **Frontend** — milestone discount config in event creation wizard (funding step), early bird config section, discount cap slider, early bird banner with countdown on event detail, milestone badges on timeline, full discount breakdown in ticket purchase flow

### Tier-Linked Funding (Spot Reservation by Tier)
- **Per-tier spot reservation** — `PledgeSpotReservation` join table maps each pledge's reserved spots to specific ticket tiers (one pledge can reserve across multiple tiers)
- **Tier-aware capacity** — `max_reserved_spots` on `TicketTier` controls per-tier reservation limits; `get_reserved_spots_for_tier()` and `consume_reserved_spots_for_tier()` handle tier-specific logic
- **`link_funding_to_tiers` toggle** — boolean on Event model; when enabled, pledge dialog shows tier-specific spot selectors instead of generic spot count
- **Minimum pledge enforcement** — pledge amount must cover `spots × tier.price_cents` for each selected tier
- **Reordered creation steps** — Dates & Tickets moved before Funding in the wizard so tiers are available when configuring funding
- **Backward compatible** — legacy global reservation mode still works when `link_funding_to_tiers` is false

### Refund Processing System (ARQ + Redis)
- **ARQ task queue** — asyncio-native background task system with Redis as message broker; replaces `FastAPI.BackgroundTasks` for persistent, retryable operations
- **Refund state machine** — new statuses on `FundingStatus`, `TicketSaleStatus`, `PaymentStatus`: `refund_processing`, `refunded`, `refund_failed`
- **Customer-initiated ticket refunds** — customers request refund (`refund_requested` status), organizer approves or rejects; `request_refund()`, `approve_refund()`, `reject_refund()`, `list_refund_requests()` service functions
- **Organizer refund management** — dedicated `RefundRequestsScreen` for organizers to view and approve/reject pending ticket refund requests; linked from live management stats
- **Bulk refunds on cancellation** — `refund_all_tickets_for_event()`, `refund_all_pledges_for_event()`, `refund_all_sponsor_payments_for_event()` automatically process all refunds when an event is cancelled
- **Immediate completion** — refunds transition `refund_processing` → `refunded` immediately (no payment gateway yet); ARQ infrastructure ready for future gateway integration with 3 retries and `refund_failed` for admin investigation
- **Frontend polling** — funding card shows "Refund Processing…" spinner, polls `GET /events/{id}/refund-status` every 3s until completed
- **Ticket refund UI** — "Request Refund" button on My Tickets for purchased/unscanned tickets; "Refund Pending Organizer Approval" banner for `refund_requested` status; "Refunded" filter chip on ticket list
- **ARQ worker** — `Backend/app/worker/main.py` with 13 registered tasks (5 refund + 8 email), `max_jobs=20`, `job_timeout=300`, 3 retries
- **Redis pool** — shared connection via `get_arq_pool()`/`close_arq_pool()` managed in FastAPI lifespan; `enqueue()` helper with graceful Redis-down fallback

### Backend Scaling & Infrastructure Hardening
- **API cleanup** — removed duplicate `capacity-summary` endpoint (frontend uses `capacity-info`), removed unused `organizer-trust` endpoint (data already in `EventResponse`)
- **Concurrency fix** — `pg_advisory_xact_lock(event_id)` added to `purchase_ticket()` and `create_pledge()`; serializes capacity-sensitive operations per-event (purchases for event A don't block event B) — prevents overselling under burst load
- **DB connection pooling** — `pool_size=10`, `max_overflow=20`, `pool_timeout=30`, `pool_recycle=1800` on async engine
- **Health probes** — `/healthz` (liveness, just returns 200) and `/health` (readiness, pings DB, returns 503 if unreachable)
- **Rate limiting** — `slowapi` middleware with user-id/IP key function:
  - Global default: 120 req/min
  - Auth (`/verify`): 10/min
  - Ticket purchase: 15/min
  - Pledge + register: 20/min
- **Email migration** — all `BackgroundTasks` email sends replaced with ARQ task enqueue; `BackgroundTasks` parameter removed from all endpoints

### API Documentation
- Swagger at `/api/v1/docs`, redirect from `/docs`

---

## Completed Features (by Phase)

| Phase | Features |
|-------|----------|
| Phase 1 | Display names (hide email), phone field, share button, mandatory username |
| Phase 2 | Cancel reason, unpledge/refund, guest pledge disclaimer, multi-param search, trending/popular/coming-soon |
| Phase 3 | Event post/feed system, event genres/categories, event image gallery |
| Post-Phase 3 | Edit event with approval rules, like/dislike system, admin pending-approval tab |
| Phase 4 | Two-date event lifecycle, auto-transition engine, clone completed events, refund deadline, Uber-style lifecycle bar |
| Phase 5 | Reusable ticket strategies with tiers, inline creation, ticket-strategy CRUD |
| Phase 6 | Uber-inspired UI overhaul, profile tab in bottom bar, close (X) navigation, home-tab search & genre filter, refund slider |
| Phase 7 | Calendar button, Waitlist UI, Ticket Tier Edit/Delete, Ticket Sales Dashboard, Scanned Tickets |
| Phase 7b | Global management pages (sales, scanned, waitlist), live stat chips, search bars, safe pop navigation |
| Phase 8 | Co-Organizer Management, Event Discounts, Reusable Discount Strategies, Customer Loyalty, Extend Funding |
| Phase 8b | Self-contained widgets (Funding Card, Reaction Bar, Feed), registration gate, modern event detail redesign |
| Phase 9c | Mandatory funding goal, detailed time display, configurable grace period, discount breakdown, community rules, free tickets |
| Phase 9d | Status-aware management UI, capacity badge, ticket waitlist, unified waitlist, selective re-approval, trust score, AppToast |
| Phase 10 | Spot Reservation during Funding — 3-step pledge flow, reserved spot consumption, capacity guards, waitlist preview |
| Phase 11 | Terms and Conditions — role-specific terms, signup checkbox, profile access |
| Phase 12 | Multi-Ticket Purchase & QR — quantity counter, purchase groups, aggregated receipts, QR codes, My Tickets |
| Phase 13 | Email Notifications — provider-agnostic (SendGrid + Console), 6 email types, Uber-themed HTML templates |
| Phase 14 | Parking & Transport Info — 4 transport fields, directions URL, "Getting There" card |
| Phase 15 | Ticket QR Encryption — AES-256-GCM, encrypted payloads, backward-compatible scan |
| Phase 16 | Map View & Geocoding — Mapbox dark-v11 map, venue markers, Near Me section, address autocomplete |
| Phase 17 | Dark Mode — full dark palette, context-aware helpers, all screens, single API for global ticket sales |
| Phase 18a | Feature Flags — `require_feature()` guard, 3 flags, admin toggle switches |
| Phase 18 | Funding Milestones — percentage-based unlock, like/dislike reactions, timeline widget, organizer builder |
| Phase 19 | Event Schedule — date/time-slot agenda, overlap detection, Excel export, timeline widget, schedule builder |
| Phase 20 | Sponsor Marketplace — sponsor role, categories, bidding, payments, sponsor tickets, carousel (chat deferred) |
| Privacy | Attendee email hidden from receipts, organizer name fallback across all endpoints |
| Bookmarks | Bookmark toggle, bookmark icon on cards/detail, Bookmarked Events screen, batch check |
| Notifications | 23 notification types, 13 trigger points, 30s polling, notification bell + badge, notification screen |
| Organizer Profile | Public profile + events endpoints, profile screen, tappable organizer name on event detail |
| Sponsor Info | Sponsor public profile endpoint, profile screen, tappable sponsor names on bid/sponsor screens |
| Prerequisites | Category prerequisites + document uploads, 6 API endpoints, bid acceptance guard, organizer review UI |
| Ratings | Multi-directional rating (4 directions), star picker, reviews on events + profiles, reusable star widgets |
| Scan Count | Sponsor ticket scan counter (increments every scan), displayed on ticket card + receipt |
| Event Creation Wizard | 5-step wizard with IndexedStack, step error indicators, loading states, date validation, character count |
| Milestone Discounts | Funding milestone snapshots, early bird time-window discounts, organizer discount cap, all types stack |
| Tier-Linked Funding | PledgeSpotReservation table, per-tier reservation/consumption, link_funding_to_tiers toggle, reordered wizard |
| Refund Processing | ARQ + Redis task queue, refund_processing/refunded/refund_failed states, customer-initiated ticket refunds with organizer approval, bulk refunds on cancellation |
| Backend Scaling | Advisory locks on capacity checks, DB connection pooling, health probes, slowapi rate limiting, email migration to ARQ |
| Email Expansion | 11 email types (added: ticket refund approved, waitlist approved, sponsor bid approved/rejected/refunded) |

### Detailed Phase Breakdowns (Phases 9–20)

<details>
<summary>Phase 9 — Business Logic (click to expand)</summary>

- 9.3 Free Tickets: `price_cents >= 0`, "FREE" badge, "Get Ticket" button, skip commission on $0
- 9.4 Community Rules: `community_rules` boolean toggle (draft only), max 14-day duration, max $50/tier, $10 listing fee, admin-configurable thresholds
- 9.5 Fund Escrow: `FundEscrow` + `EscrowRelease` models, 3-stage release (30/40/30), auto Stage 1, admin Escrow tab, freeze/unfreeze
- 9.6 Trust Score: completed/published ratio, 5 labels, color-coded badge, trusted organizers get 40% Stage 1

</details>

<details>
<summary>Phase 10 — Spot Reservation during Funding (click to expand)</summary>

- 10.1 `max_reserved_spots_per_user` on Event, `reserved_spots` + `receipt_number` on Funding + migration
- 10.2 3-step pledge flow (spot selector → invoice → receipt), guest restriction, capacity checks
- 10.3 Pledge invoice with commission breakdown; receipt with `PLG-YYYYMMDD-eventId-pledgeId`
- 10.4 Pledge discount divided by reserved spots for per-ticket calculation
- 10.5 Reserved spots consumed first on ticket purchase via `consume_one_reserved_spot()`
- 10.6 Unredeemed spots released on `live` transition
- 10.7 `max_capacity` floor = `tickets_sold + total_reserved_spots`
- 10.8 Waitlist capacity preview with per-card impact text and red warnings
- 10.9 Platform commission displayed on both pledge and ticket receipts

</details>

<details>
<summary>Phase 11 — Terms and Conditions (click to expand)</summary>

- 11.1 `terms_accepted_at` DateTime column on users table + Alembic migration
- 11.2 `verify_and_upsert_user()` stores `terms_accepted_at` for new users
- 11.3 `terms_content.dart` with role-specific terms (organizer: fees/escrow/clawback; customer: pledging/refund/escrow)
- 11.4 `TermsScreen` with role badge, accessible from signup and profile
- 11.5 Signup checkbox with tappable link; account creation blocked until agreed
- 11.6 "Terms & Conditions" in Profile Legal section; route `/terms?role=`

</details>

<details>
<summary>Phase 12 — Multi-Ticket Purchase & QR Codes (click to expand)</summary>

- 12.1 `purchase_group_id` column on `TicketSale` + migration + index
- 12.2 `purchase_ticket()` accepts quantity (1–10), shared `purchase_group_id`, all-or-nothing capacity, reserved spot consumption
- 12.3 Schemas: `TicketPurchaseBody.quantity`, `PurchaseGroupReceiptResponse`, `TicketSalesStatsResponse`
- 12.4 Endpoints: multi-ticket purchase, purchase group receipt, ticket sales stats, `/me/tickets`
- 12.5 Invoice dialog with +/- quantity selector, aggregated totals, adapted button text
- 12.6 Purchase flow navigates to aggregated or individual receipt
- 12.7 `PurchaseGroupReceiptScreen` with summary + individual ticket cards with QR
- 12.8 QR code on receipt encoding structured JSON (receipt_number, event_id, user_id, sale_id, ticket_code)
- 12.9 `MyTicketsScreen` groups tickets by event with counts
- 12.10 "Your Tickets" section on event detail with mini-cards
- 12.11 Scanned stats banner with progress bar
- 12.12 Dart model updated with `purchaseGroupId`, `commissionCents`

</details>

<details>
<summary>Phase 13 — Email Notifications (click to expand)</summary>

- 13.1 Generic config: `EMAIL_ENABLED`, `EMAIL_PROVIDER`, `EMAIL_API_KEY`, `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME`
- 13.2 `EmailBackend` ABC with SendGrid (production) + Console (dev) backends, factory, graceful error handling
- 13.3 6 Uber-themed HTML templates: event cancelled, cancellation refund, ticket purchased, unpledge refund, unregister refund, waitlist rejected
- 13.4 `email_notifications.py` with 5 high-level functions (deduplicates recipients, refund variant for pledgers)
- 13.5–13.9 Integrated into cancel, purchase, unpledge, unregister, reject endpoints via `BackgroundTasks`

</details>

<details>
<summary>Phase 14 — Parking & Transport Info (click to expand)</summary>

- 14.1 4 nullable text columns: `parking_info`, `transit_info`, `rideshare_info`, `accessibility_info` + migration
- 14.2 Fields in `EventCreate`, `EventUpdate`, `EventResponse`; computed `directions_url`
- 14.3 Google Maps directions link from venue address or lat/lng
- 14.4–14.5 Service pass-through + Dart model with `hasTransportInfo` getter
- 14.6 "Getting There" card with icon rows + "Get Directions" button
- 14.7–14.8 Collapsible section in create/edit forms

</details>

<details>
<summary>Phase 15 — Ticket QR Encryption (click to expand)</summary>

- 15.1 `TICKET_ENCRYPTION_KEY` (AES-256, 64-char hex); empty = plaintext fallback
- 15.3 `ticket_crypto.py` with AES-256-GCM encrypt/decrypt, 12-byte nonce, base64-encoded
- 15.4 `encrypted_qr_payload` on response schemas; `ScanTicketBody` accepts encrypted or legacy
- 15.5–15.6 All ticket responses include encrypted payload; scan endpoint decrypts + cross-validates
- 15.7–15.9 Dart model + receipt screens use encrypted payload; API service sends preferred format

</details>

<details>
<summary>Phase 16 — Map View, Location Discovery & Geocoding (click to expand)</summary>

- 16.1 Dependencies: `flutter_map`, `latlong2`, `geolocator`, `http`
- 16.3–16.4 `MapEvent` model + backend `MapEventMarker` schema with venue info
- 16.6 Mapbox Geocoding v6 forward API with debounced search (400ms)
- 16.8 Interactive map with dark-v11 tiles, auto-reload on pan/zoom, venue-grouped markers
- 16.9 Markers: black/green pins, blue count badges, venue name labels
- 16.10 `DraggableScrollableSheet` bottom sheet listing events per venue
- 16.11 List/Map toggle pill on Explore tab
- 16.12 "Near Me" section on Home tab (25km radius, device geolocation)
- 16.13–16.14 Mapbox address autocomplete on standalone + inline venue creation

</details>

<details>
<summary>Phase 17 — Dark Mode & UI Polish (click to expand)</summary>

- 17.1 `ThemeProvider` with `SharedPreferences` persistence
- 17.2 Dark palette: `_dkSurface` #121212, `_dkCard` #1E1E1E, etc.
- 17.3 Context-aware helpers: `cardOf()`, `textPrimaryOf()`, `surfaceOf()`, `dividerOf()`, etc.
- 17.4 Profile toggle switch, persists across restarts
- 17.5 All screens converted from hardcoded colors to context-aware helpers
- 17.6 Near-black detection swaps to `accentColor` in dark mode
- 17.7 QR code forced white background
- 17.8 Bottom nav active tab uses `accentColor`
- 17.9 Map venue name labels above pins
- 17.10 `GET /me/organizer-ticket-sales` single-query endpoint replacing N+1 calls
- 17.11–17.12 Tappable receipt cards; per-event title "Event Ticket Sales"

</details>

<details>
<summary>Phase 18a — Feature Flags (click to expand)</summary>

- 18a.1 3 feature flag keys in `PlatformSettings` DEFAULTS; `get_bool(db, key)` helper
- 18a.2 `require_feature()` FastAPI dependency raises 403 when disabled
- 18a.3 Alembic migration seeds flags with descriptions
- 18a.4 Admin Settings tab renders boolean settings as Switch toggles
- 18a.5 `getFeatureFlags()` API method; UI sections hidden when flag disabled

</details>

<details>
<summary>Phase 18 — Funding Milestones (click to expand)</summary>

- 18.1 `FundingMilestone` + `MilestoneReaction` tables with migration
- 18.2 Schemas with computed `is_unlocked` field
- 18.3 Service: list (sorted, unlock computed), create/update/delete, react (toggle/switch pattern)
- 18.4 6 API endpoints under `/events/{id}/milestones`, all feature-gated
- 18.5 Dart model + 6 API methods
- 18.6 Milestone Timeline widget: vertical progress bar, circular nodes, UNLOCKED/LOCKED badges, like/dislike
- 18.7 Organizer builder: collapsible section, title + slider + benefit, local state on create, live CRUD on edit

</details>

<details>
<summary>Phase 19 — Event Schedule / Agenda (click to expand)</summary>

- 19.1 `EventScheduleItem` table + `has_schedule` on Event + migration
- 19.2 Service: grouped by date, overlap detection, Excel export via openpyxl
- 19.3 6 API endpoints under `/events/{id}/schedule`, all feature-gated
- 19.4 Dart models + 6 API methods + `hasSchedule` field
- 19.5 Schedule Timeline: date tab pills, vertical timeline, overlap warnings, Excel download, summary footer
- 19.6 Organizer builder: "Use structured schedule" switch, date groups, time slot cards, batch/live CRUD

</details>

<details>
<summary>Phase 20 — Sponsor Marketplace (click to expand)</summary>

- 20.1 `sponsor` role + `SponsorProfile` model + onboarding screen + migration
- 20.2 `SponsorshipCategory` model with bid stats, CRUD endpoints, categories screen
- 20.3 `SponsorBid` model with 5 statuses, 6 bid endpoints, Place Bid dialog, Bid Management screen
- 20.4 Real-Time Negotiation Chat — **DEFERRED** (uses bid proposal text + accept/reject for now)
- 20.5 `SponsorPayment` model with commission, pay endpoint, "Pay" button on accepted bids
- 20.6 `SponsorTicket` with AES-256-GCM QR, auto-generated on payment, scan endpoint
- 20.7 Sponsor carousel: public endpoint + horizontal logo row on event detail
- 20.8 Role-based visibility: categories hidden from customers, tickets hidden from sponsors
- 20.9 `SponsorDashboardScreen` with profile, tickets, payment history

</details>

<details>
<summary>Milestone Discounts & Early Bird Discounts (click to expand)</summary>

- `FundingMilestoneSnapshot` + `FundingMilestoneUser` tables for tracking pledgers at each milestone crossing
- `EarlyBirdDiscount` table with `applies_to` (funding/tickets), time windows, discount values
- `_check_milestone_snapshots()` in `funding.py` triggers on every pledge
- `compute_ticket_price()` applies best milestone discount user qualifies for
- `max_discount_percent` on Event (default 100) — organizer cap on total stacked discounts
- Full CRUD on `/events/{id}/early-bird-discounts`
- Frontend: milestone config in wizard, early bird section, cap slider, countdown banner, discount breakdown

</details>

<details>
<summary>Tier-Linked Funding (click to expand)</summary>

- `PledgeSpotReservation` join table (pledge_id, tier_id, spots)
- `max_reserved_spots` on `TicketTier` for per-tier limits
- `link_funding_to_tiers` boolean on Event model
- `get_reserved_spots_for_tier()`, `consume_reserved_spots_for_tier()` service functions
- Reordered wizard: Dates & Tickets → Funding (tiers available when configuring funding)
- Legacy global reservation mode preserved when `link_funding_to_tiers` is false

</details>

<details>
<summary>Refund Processing System (click to expand)</summary>

- ARQ + Redis task queue replacing `BackgroundTasks` for persistent, retryable operations
- New enum values: `refund_processing`, `refunded`, `refund_failed` on `FundingStatus`, `TicketSaleStatus`, `PaymentStatus`
- `refund_requested` status on `TicketSaleStatus` for customer-initiated refund flow
- Service functions: `request_refund()`, `approve_refund()`, `reject_refund()`, `list_refund_requests()`
- Bulk refund functions: `refund_all_tickets_for_event()`, `refund_all_pledges_for_event()`, `refund_all_sponsor_payments_for_event()`
- ARQ worker: 13 registered tasks (5 refund + 8 email), `max_jobs=20`, 3 retries
- Redis pool: `get_arq_pool()`/`close_arq_pool()` in FastAPI lifespan, `enqueue()` helper
- Frontend: "Request Refund" button, "Refund Pending" banner, RefundRequestsScreen for organizers, polling on funding card
- Alembic migration `tt70t3u4v5w6` for new enum values

</details>

<details>
<summary>Backend Scaling & Infrastructure Hardening (click to expand)</summary>

- Removed duplicate `capacity-summary` and unused `organizer-trust` endpoints
- `pg_advisory_xact_lock(event_id)` in `purchase_ticket()` and `create_pledge()` — per-event serialization
- DB connection pooling: `pool_size=10`, `max_overflow=20`, `pool_timeout=30`, `pool_recycle=1800`
- Health probes: `/healthz` (liveness), `/health` (readiness, checks DB connectivity)
- Rate limiting via `slowapi`: global 120/min, auth 10/min, purchase 15/min, pledge/register 20/min
- `rate_limit.py` with user-id/IP key function
- All `BackgroundTasks` email sends replaced with ARQ enqueue; `BackgroundTasks` removed from all endpoints
- Dependencies added: `slowapi>=0.1.9`, `arq>=0.26.0`, `redis[hiredis]>=5.0.0`

</details>

<details>
<summary>Email Expansion — 11 Types (click to expand)</summary>

- Original 6: event cancelled, cancellation+refund, ticket purchased, unpledge refund, unregister refund, waitlist rejected
- New 5: ticket refund approved, waitlist ticket approved, sponsor bid approved, sponsor bid rejected, sponsor payment refunded
- All 11 types have Uber-themed HTML templates (inline CSS, mobile-friendly, black/white/green accent)
- All sent via ARQ background tasks with Redis queue
- Trigger points wired into: `approve_ticket_refund`, `approve_waitlisted_ticket`, `accept_bid`, `reject_bid`, `refund_bid` endpoints

</details>

---

## Unimplemented Features (To Do)

### Ready to Build

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| 1 | **Multi-Role System** | Users can hold multiple roles (customer + organizer + sponsor). `roles` JSON column on User, add-role/switch-role endpoints, `require_role()` update, role switcher on profile, sponsor onboarding for existing users. **HIGH RISK** — touches auth dependency used by 40+ endpoints | **High — Next** |

### Future Phases

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| 2 | **File Upload for Images** | Replace URL-based image adding with actual file upload to cloud storage (S3/GCS) | Medium — Phase 21 |
| 3 | **Organizer Verification** | Verification flow for organizers (identity/contact check before they can publish events) | Medium — Phase 22 |
| 4 | **Real-Time Sponsor Negotiation Chat** | WebSocket-based chat between organizer and sponsor per bid (deferred from Phase 20.4). WhatsApp-style UI, counter-offer amounts, push notifications when offline, read-only after bid resolution | Medium — Phase 20.4 |
| 5 | **Newcomer / Trending Badges** | Newcomer badge for new organizers, trending indicator on tickets/events | Low — Phase 23 |
| 6 | **Verify Organizer via External Apps** | Use third-party verification service or app for organizer identity | Low — Phase 23 |
| 7 | **Chatbot for Support** | In-app chatbot for user support and FAQ | Low — Phase 23 |

### Infrastructure (When K8s Env Available)

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| 8 | **Dockerization & K8s Deployment** | Dockerfile (multi-stage), K8s manifests (Deployments, Services, HPA, PDB), nginx-ingress with method-based routing, read/write/worker pod split, ConfigMap/Secrets | Medium — When K8s ready |
| 9 | **S3 Storage Migration** | Replace local `static/uploads/` with S3-compatible storage (MinIO/AWS S3) for multi-pod; `storage.py` abstraction, presigned URLs, CDN | Medium — Before multi-pod |
| 10 | **Redis Caching Layer** | Cache featured events (60s TTL), event detail (30s), dashboard stats (30s), map data (120s); time-based + event-driven invalidation | Medium — For read scaling |
| 11 | **Observability & Monitoring** | Structured JSON logging (structlog), Prometheus metrics (`/metrics`), request ID propagation (`X-Request-ID`), per-service dashboards | Medium — For production |

### Scaling (When Needed)

| # | Feature | Description | Priority |
|---|---------|-------------|----------|
| 12 | **K8s Role-Based Scaling** | Same codebase, conditional route mounting via `SERVICE_ROLE` env var, 4 K8s Deployments with independent HPAs, Nginx Ingress path-based routing | Medium — Phase 24a |
| 13 | **Domain-Based Modular Monolith** | Reorganize into domain folders, break up 78KB `events.py`, shared queries layer, clean domain boundaries | Medium — Phase 24b |
| 14 | **Full Microservice Extraction** | Separate databases, API gateway, gRPC, distributed tracing. Only when team/traffic scaling triggers are met | Low — Phase 24c |

---

## Planned Phases (Upcoming)

### Feature 7 — Multi-Role System (Next)

**Status:** Ready to implement. **HIGH RISK** — touches auth dependency used by 40+ endpoints. Estimated: **3 hours**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 7.1 | **User Model** | Small | Add `roles: JSON` column to `users` table |
| 7.2 | **Migration** | Medium | Add `roles` column, populate from existing `role` via `json_build_array(role::text)` |
| 7.3 | **`require_role()` Update** | **HIGH RISK** | Update `dependencies.py` to check `user.roles` list in addition to `user.role` |
| 7.4 | **Add Role Endpoint** | Small | `POST /me/roles/add` — adds a new role to user's roles list |
| 7.5 | **Switch Role Endpoint** | Small | `PATCH /me/roles/switch` — changes active role |
| 7.6 | **`/me` Response** | Small | Include `roles` list in `MeResponse` schema |
| 7.7 | **Dart Model** | Small | Add `roles: List<String>?` to `AppUser`, update `fromJson` |
| 7.8 | **Frontend Role Switcher** | Medium | ChoiceChip row on profile screen, "Add Role" button |
| 7.9 | **Sponsor Onboarding for Existing Users** | Medium | Handle "adding sponsor role" flow vs "initial signup as sponsor" |

**Key risks:**
- `require_role()` is global — every protected endpoint (40+) goes through it
- Data migration must produce valid JSON for all existing users
- Frontend `if (user.isOrganizer)` checks must use active role, not just role list
- Adding sponsor role must trigger onboarding without creating new account

### Phase 21 — Media

Estimated: **1 session**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 1 | **File Upload for Images** | Large | Backend: S3/GCS integration, upload endpoint. Frontend: file picker replacing URL input |

### Phase 22 — Trust & Security

Estimated: **1–2 sessions**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 1 | **Organizer Verification** | Large | Backend: verification request model, document upload, admin review queue. Frontend: verification status badge, submission form |

> **Note:** Feature Flags / Admin Controls originally planned here have been moved to **Phase 18a** and built as a foundational system before all new features.

### Phase 23 — Nice to Have

Lowest priority. Estimated: **1–2 sessions**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 1 | **Newcomer / Trending Badges** | Small | Backend: badge logic based on organizer age / event stats. Frontend: badge display on cards |
| 2 | **Verify Organizer via External Apps** | Large | Third-party API integration — scope TBD |
| 3 | **Chatbot for Support** | Large | Standalone feature — could use an off-the-shelf widget or build custom |

### Feature 10 — Dockerization & K8s Deployment

**Status:** Deferred — no K8s environment yet. Estimated: **1–2 sessions**.

**Prerequisite**: K8s cluster available (local minikube/kind or cloud).

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 10.1 | **Dockerfile** | Small | Multi-stage build (python:3.12-slim), separate entrypoint for ARQ worker (`arq app.worker.main.WorkerSettings`) |
| 10.2 | **K8s Manifests** | Medium | Deployments (read/write/worker pods), Services, HPA (CPU 70%), PDB (`minAvailable: 1`), ConfigMap/Secrets |
| 10.3 | **Ingress Routing** | Small | nginx-ingress with method-based routing: `GET /api/*` → read-pods, `POST/PATCH/DELETE /api/*` → write-pods |
| 10.4 | **Read/Write Split** | Small | Same codebase deployed three ways; read pods connect to DB replica, write pods to primary, worker pods to Redis + primary |

### Feature 11 — S3 Storage Migration

**Status:** Deferred — required before multi-pod deployment. Estimated: **1 session**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 11.1 | **S3 Client Setup** | Small | `boto3`/`aiobotocore` dependency, `S3_BUCKET`/`S3_ENDPOINT_URL` config, `storage.py` with `upload_file()`/`get_file_url()` |
| 11.2 | **Migrate Upload Endpoints** | Medium | Update event images, schedule images, sponsor logos to upload to S3 with structured keys (`events/{id}/images/{uuid}.{ext}`) |
| 11.3 | **Serve Strategy** | Small | Presigned URLs or CDN (CloudFront), remove `StaticFiles` mount for uploads, migration script for existing files |

### Feature 12 — Redis Caching Layer

**Status:** Deferred — for read scaling. Estimated: **1 session**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 12.1 | **Cache Infrastructure** | Small | `cache.py` with `get_cached()`/`set_cached()`/`invalidate()` using existing Redis connection |
| 12.2 | **Cache Targets** | Medium | Featured events (60s TTL), event detail (30s), dashboard stats (30s), map data (120s) |
| 12.3 | **Cache Invalidation** | Medium | Time-based TTL + event-driven invalidation on mutations (update, publish, cancel, pledge, purchase) |

### Feature 13 — Observability & Monitoring

**Status:** Deferred — for production. Estimated: **1 session**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 13.1 | **Structured JSON Logging** | Small | `python-json-logger` or `structlog`, fields: timestamp, level, request_id, user_id, duration_ms |
| 13.2 | **Prometheus Metrics** | Small | `prometheus-fastapi-instrumentator`, `/metrics` endpoint, custom metrics (ARQ jobs, cache hit/miss, DB pool) |
| 13.3 | **Request ID Propagation** | Small | Middleware for `X-Request-ID` header generation/forwarding, attached to all log entries |

### Phase 24a — K8s Role-Based Scaling (Minimal Effort)

**Status:** Ready to implement when scaling is needed. Estimated: **1–2 sessions**.

**Concept:** Same codebase, zero refactoring. One Docker image, four Kubernetes Deployments. Each Deployment sets `SERVICE_ROLE` env var to control which routers are mounted. Nginx Ingress routes by URL path to the correct service. Frontend unchanged (single `API_BASE_URL` points to Ingress).

**Architecture:**

```
Flutter App → K8s Nginx Ingress → ┬─ platform-api  (auth, admin, settings)        replicas: 1-2
                                   ├─ customer-api  (browse, register, buy)         HPA: 2-20 pods
                                   ├─ organizer-api (manage, scan, venues, CRUD)    HPA: 2-5 pods
                                   └─ sponsor-api   (bids, payments, tickets)       HPA: 2-10 pods
                                                    ↓
                                            Shared PostgreSQL + Redis
```

**Route ownership:**
- **platform-api:** `/api/v1/auth/*`, `/api/v1/admin/*`, `/api/v1/me` (profile)
- **customer-api:** `/api/v1/events` (list, detail, featured, map), register, pledge, purchase-ticket, posts, reactions, milestones/schedule (read-only), sponsor carousel, `/api/v1/me/tickets`, `/api/v1/me/pledges`
- **organizer-api:** event CRUD, publish/cancel/clone, scan-ticket, ticket-sales, waitlist, co-organizers, ticket-tiers, discounts, venues, ticket-strategies, discount-strategies, milestones/schedule (CRUD), `/api/v1/me/organizer-ticket-sales`, `/api/v1/me/customers`
- **sponsor-api:** `/api/v1/me/sponsor-profile`, `/api/v1/events/*/sponsorships/*`, bids, payments, `/api/v1/me/sponsor-tickets`, scan-sponsor

**Overlapping routes (graceful degradation):** `events.router` mounted on both customer-api and organizer-api. If Ingress misroutes, it still works — routing is for scaling optimization, not hard isolation.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 24a.1 | **Conditional Router Mounting** | Small | Modify `router.py` → `build_router(role)` function. Read `SERVICE_ROLE` env var (default `all`). Conditionally mount routers based on role. `all` = current behavior (no regression) |
| 24a.2 | **Dockerfile** | Small | Single `Backend/Dockerfile`. `SERVICE_ROLE` overridden per K8s Deployment |
| 24a.3 | **K8s Manifests** | Medium | `k8s/` directory: 4 Deployments + Services + HPAs, Nginx Ingress with path-based routing rules, ConfigMap (shared env), Secrets (DB password, encryption key, API keys), optional Redis Deployment |
| 24a.4 | **Ingress Routing** | Small | Nginx Ingress rules: most-specific paths first (sponsor → organizer → platform), customer-api as catch-all fallback |

### Phase 24b — Domain-Based Modular Monolith (Medium Effort)

**Status:** Recommended after 24a is stable. Estimated: **4–6 sessions**.

**Concept:** Reorganize `Backend/app/` into domain-based folders. Each domain owns its models, schemas, services, and routes. Cross-cutting concerns (db, auth, encryption, email) go into `shared/`. The biggest win is breaking up `events.py` (78.6 KB, 60+ endpoints) into 5-6 focused domain route files.

**Target structure:**

```
Backend/app/
  domains/
    events/        (models.py, schemas.py, service.py, routes.py) — Event CRUD + lifecycle
    funding/       (models.py, schemas.py, service.py, routes.py) — pledges, escrow, receipts
    tickets/       (models.py, schemas.py, service.py, routes.py) — purchase, scan, tiers, waitlist
    registration/  (models.py, schemas.py, service.py, routes.py) — register, unregister, waitlist
    sponsors/      (models.py, schemas.py, service.py, routes.py) — profile, categories, bids, payments
    milestones/    (models.py, schemas.py, service.py, routes.py) — already isolated
    schedule/      (models.py, schemas.py, service.py, routes.py) — already isolated
    venues/        (models.py, schemas.py, service.py, routes.py) — venue CRUD
    discounts/     (models.py, schemas.py, service.py, routes.py) — rules, strategies, claims
    users/         (models.py, schemas.py, service.py, routes.py) — auth, profile, /me
    platform/      (models.py, service.py, routes.py) — admin, settings, feature flags
  shared/
    db.py          (engine, session, Base)
    config.py      (Settings)
    dependencies.py (DbSession, CurrentUser, require_role, require_feature)
    security.py    (Firebase auth)
    crypto.py      (AES-256-GCM)
    queries.py     (shared read helpers: get_event_or_404, get_funding_summary)
    email/         (service, templates, notifications)
  main.py
  router.py
```

**Key challenge — cross-domain dependencies:**
- `event ↔ funding` bidirectional dependency resolved via `shared/queries.py` for read operations
- Domain services import from `shared/` and own domain only, never from other domain services directly
- Cross-domain writes orchestrated at the route handler level (route calls service A then service B)

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 24b.1 | **Domain Folder Structure** | Medium | Create 11 domain folders under `domains/`. Move ~40 files into new locations. Update ~200+ import paths |
| 24b.2 | **Break Up events.py** | Large | Split 78.6KB `events.py` (60+ endpoints) into `events/routes.py`, `funding/routes.py`, `tickets/routes.py`, `registration/routes.py` (+ social endpoints distributed appropriately) |
| 24b.3 | **Shared Queries Layer** | Small | `shared/queries.py` — extract common read helpers (`get_event_or_404`, `get_funding_summary`, `get_capacity_info`) used by multiple domains. Resolves bidirectional dependency between events ↔ funding |
| 24b.4 | **Domain API Contracts** | Small | Define clear interfaces between domains. No cross-domain direct model access — go through service functions or shared queries |

### Phase 24c — Full Microservice Extraction (Future)

**Status:** Not recommended yet. Revisit when scaling triggers are met.

**When to revisit (any of these become true):**
- 3+ developers working simultaneously and experiencing merge conflicts / deployment bottlenecks
- One feature needs independent horizontal scaling (e.g., sponsor bidding gets 10x traffic vs. the rest)
- Different teams want different deployment cadences (sponsors team ships weekly, events team ships monthly)
- A component needs a different tech stack (e.g., real-time bidding engine in Go/Rust for performance)

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 24c.1 | **Service Extraction** | Very Large | Extract one domain at a time into its own FastAPI service with its own database. Start with `sponsors/` (most isolated) |
| 24c.2 | **API Gateway** | Large | Kong or Traefik as entry point. Service discovery, rate limiting, auth propagation |
| 24c.3 | **Inter-Service Communication** | Large | gRPC or HTTP for sync calls, Redis Streams or RabbitMQ for async events (e.g., "bid accepted" triggers sponsor ticket generation) |
| 24c.4 | **Observability** | Medium | Distributed tracing (OpenTelemetry), per-service logging, health dashboards |

**Completed phases (1–20 + cross-cutting features):** Auth, venues, events, funding, tickets, registration, admin, search, business logic (commission, escrow, trust score), spot reservation, terms, multi-ticket + QR, email notifications (11 types via ARQ), transport info, QR encryption, map view + geocoding, dark mode, feature flags, funding milestones, event schedule, sponsor marketplace, privacy rules, bookmarks, in-app notifications, organizer profiles, sponsor info, prerequisites, ratings, scan count, event creation wizard, milestone discounts + early bird discounts, tier-linked funding, refund processing (ARQ + Redis), backend scaling (advisory locks, rate limiting, connection pooling, health probes). Real-time negotiation chat (20.4) deferred.

**Recommended order for remaining work:**
1. **Feature 7 — Multi-Role System** (next — high risk, 13+ files)
2. **Phase 21 — Media** (file upload for images)
3. **Phase 22 — Trust & Security** (organizer verification)
4. **Phase 20.4 — Sponsor Negotiation Chat** (WebSocket real-time chat, deferred)
5. **Phase 23 — Nice to Have** (badges, external verification, chatbot)
6. **Dockerization & K8s Deployment** (when K8s env available)
7. **S3 Storage Migration** (required before multi-pod deployment)
8. **Redis Caching Layer** (for read scaling)
9. **Observability & Monitoring** (for production)
10. **Phase 24a — K8s Role-Based Scaling** (when needed)
11. **Phase 24b — Domain Modular Monolith** (when codebase grows)
12. **Phase 24c — Microservice Extraction** (only when scaling triggers are met)

---

## File Location

- **Path:** `Crowd_Funding_Event/FEATURES.md`
- Update this file as features are implemented or new requests are added.
