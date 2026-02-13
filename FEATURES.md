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
- **Two-date system:** Event Date (start/end) and Funding Deadline are independent — at least one must be set
- **Edit event:** Draft and unpublished (pending_approval) events edit freely; approved/live events move to `pending_approval` after edit (needs admin re-approval). Admin edits bypass approval.
- Delete event (draft, unpublished/pending_approval, or cancelled only)
- Cancel event (with mandatory reason) — available for unpublished, approved, selling_tickets, waiting_event_date, and live events
- Reactivate cancelled event (cancelled -> draft)
- Publish draft event (draft -> approved)
- **Clone completed events** into a new draft with all parameters pre-filled (no dates)

### Event Lifecycle State Machine
- **Statuses:** `draft` → `approved` → `selling_tickets` / `waiting_event_date` → `live` → `completed`
- **Both Fund + Event date set:** After funding deadline passes → `selling_tickets` (pledge/unregister blocked, buy tickets only) → at event start → `live` → at event end → `completed`
- **Only Fund date set:** After funding deadline → `waiting_event_date` (organizer has 20% of funding duration to set event date). If deadline passes without date → auto-cancel + refund registered users (guest pledges held for admin). Once date set → `selling_tickets` → `live` → `completed`
- **Only Event date set:** Goes to `selling_tickets` (no funding phase) → `live` → `completed`
- **Auto-transition:** Status transitions are checked automatically on every event fetch
- **State restrictions:** Pledge and unregister blocked in `selling_tickets`, `waiting_event_date`, `live`, `completed`

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
- Featured sections: Trending (by registration count), Popular (by pledge amount), Coming Soon (future approved)
- "My Events" section for logged-in users (events they're registered to, including cancelled)
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
- **Waitlist Approve/Reject UI** — per-event waitlist page with approve/reject buttons and search
- **Global Waitlist page** (`/manage/waitlist`) — aggregates waitlisted registrations across all organiser events with search, accessible from Manage tab

### Funding & Pledges
- Pledge money to event (customer) — only during `approved` (funding active) status
- Unpledge with refund (non-guest pledges)
- Guest pledge with non-refundable disclaimer
- Funding goal, min pledge, funding deadline
- Total pledged & days left displayed on event detail and event cards
- Pledging blocked after funding ends (selling_tickets / waiting / live / completed)

### Ticket Strategies (Reusable Templates)
- **Separate reusable object** (like venues) — organizers create ticket strategies with named tiers
- Each strategy has tiers (e.g. "Platinum", "Diamond", "General") with name, description, price, quantity, display order
- Strategies linked to events via dropdown on create/edit screens
- **Required when no funding deadline is set;** optional when funding deadline is set (can be added later during `waiting_event_date`)
- Inline strategy creation form on the Create Event page
- Tier descriptions explain what each ticket tier provides
- Total ticket quantity vs max capacity validation with remaining amount display
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

### Customer Loyalty Tracking
- **OrganizerCustomerHistory** — auto-populated when a ticket is scanned (records organizer, customer, event, scan time)
- **Dedicated Customers screen** (`/manage/customers`) accessible from the Manage tab
- Lists all unique customers who attended the organizer's events, with **event count** and **"Loyal" badge** for repeat attendees (2+ events)
- Search bar + stats (total customers, repeat customers)
- Endpoint: `GET /me/customers`

### Tickets
- Ticket tiers copied from strategy to event on creation
- Ticket tier list on event detail screen with name, description, and price
- **Ticket tier edit & delete** — organizer can update name, description, price or delete tiers via edit/delete icons on the Manage Ticket Tiers section
- Price preview with discounts (common + pledge-based + selective + event discounts, capped at ticket price)
- Purchase ticket dialog with tier selection (customer, must be registered)
- Scan ticket by QR code (organizer/admin) — **auto-records customer attendance** for loyalty tracking
- **Per-event Ticket Sales page** — full-page view with search, stats (total sold, revenue), per-sale detail (attendee, tier, code, amount, scan status)
- **Per-event Scanned Tickets page** — full-page filtered view showing only scanned tickets with search and "scanned by" info
- **Global All Ticket Sales page** (`/manage/ticket-sales`) — aggregates sales across all organiser events with search, accessible from Manage tab
- **Global Scanned Tickets page** (`/manage/scanned-tickets`) — aggregates scanned tickets across all events with search, accessible from Manage tab
- **Live management stat chips** on event detail — 2×2 grid of clickable chips (sold, scanned, waitlisted, revenue) with live counts that navigate to the per-event management pages

### Like / Dislike System
- Users (customers/organizers) see like & dislike buttons, can toggle reactions
- Like count visible to everyone (event detail + event cards)
- Dislike count hidden from users; admin sees both like & dislike counts (read-only, no buttons)
- One reaction per user per event; toggle off or switch

### Event Posts / Feed
- Registered users can post on event wall
- Organizer can toggle posts on/off per event
- Posts listed with author name, time-ago display
- Delete option for post author, organizer, or admin

### Event Images / Gallery
- Add images by URL with optional caption
- Horizontal scrollable gallery on event detail
- Organizer/admin can add/delete images

### Sharing & Calendar
- Share event link (copy to clipboard)
- **Add to Calendar** — calendar icon in event detail AppBar copies the `.ics` download URL for import into any calendar app

### Extend Funding (with Admin Approval)
- Organizer can request to extend funding period from `waiting_event_date` events
- **Admin approval required** — organizer's request is stored as `pending_extension` on the event
- Admin approves/rejects via the **Extensions tab** in the Admin Dashboard or inline on event detail
- When approved, dates are applied and status transitions as needed
- Admins can apply extensions directly (no pending state)
- Dialog with fields for new funding end, start time, and end time

### Admin Dashboard
- Overview tab: platform stats (total users, events, revenue)
- Pending Approval tab: events edited by organizers needing re-approval (approve/reject)
- **Extensions tab:** events with pending funding extension requests — admin approve/reject with details
- Drafts tab: draft events list with publish/delete actions
- Users tab: full user list with email visible (masked for non-admin)

### Frontend Screens & UX
- **Uber-inspired UI** — black/white/green accent, Inter font, rounded containers, subtle shadows
- **Bottom navigation bar** with 4 tabs: Home, Explore, Manage (organizer/admin) / My Events (customer), Profile
- **Manage tab** — three rows of quick-action cards: Row 1 (Create Event, Venues, Tickets, Admin); Row 2 (All Sales, Scanned, Waitlist); Row 3 (Customers) — each opens a global management page
- **Profile tab** embedded directly in the bottom nav — shows user avatar, name, phone, role badge, grouped menu sections (Account, Management), sign-out button. Bottom bar persists.
- **Close (X) icon** on all inner screens — uses safe pop navigation: returns to the tab/page the user came from (falls back to home if no history)
- Login screen: Uber-styled with custom "CF" logo, bold headings, grey-filled inputs, full-width black sign-in button
- Home tab: hero header with user greeting, real search bar, genre chips, featured event carousels
- Explore tab: dedicated search + advanced filters, events in grid
- **Uber-style lifecycle bar** on every event card and detail screen showing progress through stages
- Event Detail: full info, genre badge, funding stats, posts feed, image gallery, like/dislike, ticket tiers with descriptions, state-dependent actions (register/pledge only during funding; buy tickets during selling_tickets/live), clone button for completed events, "Set Event Date" & "Extend Funding" buttons for waiting_event_date, Co-Organizers & Discounts management links, pending extension banner (admin approve/reject inline), "Your Discounts" section for customers
- **Create Event form layout:** Title/Description/Genre → Dates & Funding Deadline (with refund slider) → Max Capacity & Registration Type → Venue (dropdown + inline create) → Ticket Strategy (dropdown + inline create) → Funding Settings (if applicable) → Posts/Publish toggles
- Edit Event: pre-filled form with date pickers, warning banner for live/approved events
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
| Phase 5 | Reusable ticket strategies with tiers (name, description, price, qty), inline creation, event linkage, ticket-strategy CRUD endpoints, ticket tier display & purchase on event detail |
| Phase 6 — UI Polish | Uber-inspired UI overhaul (theme, login, home, event cards, bottom nav), profile tab in bottom bar, close (X) icon on all inner screens, home-tab search & genre filter, form layout reorder (dates before venue/tickets), refund slider with 20% cap enforcement, edit/cancel/delete for unpublished events, ticket tier URL fixes |
| Phase 7 — Event Mgmt Tools | Add-to-Calendar button, Waitlist Approve/Reject UI, Ticket Tier Edit & Delete, Ticket Sales Dashboard with stats, Scanned Tickets sub-tab, backend `description` passthrough for tier create/update |
| Phase 7b — Global Mgmt & Search | Per-event sales/scanned/waitlist as full pages with search; Global aggregated pages (/manage/ticket-sales, /manage/scanned-tickets, /manage/waitlist) accessible from Manage tab; Live 2×2 stat chips on event detail (sold, scanned, waitlisted, revenue); Search bars on Venues and Ticket Strategies pages; Close (X) uses safe pop navigation to return to source tab |
| Phase 8 — Organizer Tools | **Co-Organizer Management** with read/full permissions; **Event Discounts** (pledge %, ticket %, fixed, targeting pledgers/non-pledgers/all, capped at ticket price); **Customer Loyalty Tracking** (auto-records attendance on ticket scan, Customers page with repeat badges); **Extend Funding with Admin Approval** (pending extension → admin approve/reject in Dashboard + inline); Admin Dashboard Extensions tab; Manage tab Customers quick-action |

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
| 1 | **Admin Approval at 80% Pledge** | When an event reaches 80% of its funding goal, deletion/cancellation requires admin approval | High |
| 2 | **Commission per Ticket Sale** | Platform takes a configurable commission (e.g. 2%) on each ticket sale; admin sets the rate | High |
| 3 | **Cancellation Email** | When an event is cancelled, send email to all registered users with the cancellation reason | High |
| 4 | **Free Tickets / Flexible Pricing** | Support free tickets and flexible pricing options per tier | Medium |
| 5 | **Genre-Based Pricing Rules** | Community events: $10 listing fee, platform cut from pledges, max 2-week duration; other events: no limit | Medium |
| 6 | **Unpledge Confirmation Email** | Send email when a user successfully unpledges | Medium |
| 7 | **Organizer Verification** | Verification flow for organizers (identity/contact check before they can publish events) | Medium |
| 8 | **File Upload for Images** | Replace URL-based image adding with actual file upload to cloud storage (S3/GCS) | Medium |
| 9 | **Ticket Encryption** | Encrypt QR codes / ticket data so they cannot be forged | Medium |
| 10 | **Feature Flags / Admin Controls** | Admin can enable/disable platform features globally (posts, guest pledges, commission, etc.) | Medium |
| 11 | **Location-Based Discovery** | Show events near the user based on browser geolocation or saved location | Medium |
| 12 | **Parking / Transport Info** | Structured fields in event description for parking, transit, Uber-style directions | Low |
| 13 | **Verify Organizer via External Apps** | Use third-party verification service or app for organizer identity | Low |
| 14 | **Chatbot for Support** | In-app chatbot for user support and FAQ | Low |
| 15 | **Newcomer / Trending Badges** | Newcomer badge for new organizers, trending indicator on tickets/events | Low |

---

## Planned Phases (Upcoming)

### Phase 9 — Business Logic (Backend + Frontend)

Core money and platform rules. Estimated: **2–3 sessions**.

| # | Feature | Effort | What to Build |
|---|---------|--------|--------------|
| 1 | **Commission per Ticket Sale** | Medium | Backend: commission model + admin config endpoint + deduction on purchase. Frontend: admin settings panel, commission display on receipts |
| 2 | **Admin Approval at 80% Pledge** | Medium | Backend: check pledge % before allowing cancel/delete, route to admin queue if ≥80%. Frontend: admin approval UI |
| 3 | **Free Tickets / Flexible Pricing** | Small | Backend: allow `price_cents=0` on tiers. Frontend: "Free" badge on tier display |
| 4 | **Genre-Based Pricing Rules** | Medium | Backend: enforce community event rules (max 2 weeks, $10 fee, pledge cut). Frontend: display rules when "community" genre selected |

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
