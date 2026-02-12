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

### Events — CRUD & Lifecycle
- Create event (organizer/admin) with genre (required), posts toggle, funding fields
- **Two-date system:** Event Date (start/end) and Funding Deadline are independent — at least one must be set
- **Edit event:** Draft events edit freely; approved/live events move to `pending_approval` after edit (needs admin re-approval). Admin edits bypass approval.
- Delete event (draft/cancelled only)
- Cancel event (with mandatory reason)
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
- Refund deadline field only appears in create/edit when funding deadline is set
- Customers refunded if they unregister before the refund cutoff; no refund after

### Event Discovery & Search
- Multi-parameter search: text, status, registration type, date range, city, has-funding, has-tickets, min/max capacity, genre
- Genre filter on home screen (community, music, tech, sports, arts, food, charity, education, business, other)
- Featured sections: Trending (by registration count), Popular (by pledge amount), Coming Soon (future approved)
- "My Events" section for logged-in users (events they're registered to, including cancelled)
- Status filter hides draft/pending/cancelled for customers; shows all for organizers/admins

### Registration
- Open/closed (waitlist) registration
- Register, unregister, check registration status
- Capacity checks, waitlist auto-promote on type change
- Registration count denormalized on event model

### Funding & Pledges
- Pledge money to event (customer) — only during `approved` (funding active) status
- Unpledge with refund (non-guest pledges)
- Guest pledge with non-refundable disclaimer
- Funding goal, min pledge, funding deadline
- Total pledged & days left displayed on event detail and event cards
- Pledging blocked after funding ends (selling_tickets / waiting / live / completed)

### Tickets
- Ticket tiers (create, list)
- Price preview with discounts (common + pledge-based + selective)
- Purchase ticket (customer, must be registered)
- Scan ticket by QR code (organizer/admin)

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

### Sharing
- Share event link (copy to clipboard)

### Admin Dashboard
- Overview tab: platform stats (total users, events, revenue)
- Pending Approval tab: events edited by organizers needing re-approval (approve/reject)
- Drafts tab: draft events list with publish/delete actions
- Users tab: full user list with email visible (masked for non-admin)

### Frontend Screens
- Login, Register (with phone + mandatory username)
- Home: event list, featured sections, advanced filters, genre filter, "My Events" carousel
- **Uber-style lifecycle bar** on every event card and detail screen showing progress through stages
- Event Detail: full info, genre badge, funding stats, posts feed, image gallery, like/dislike, state-dependent actions (register/pledge only during funding; buy tickets during selling_tickets/live), clone button for completed events, "Set Event Date" button for waiting_event_date
- Create Event: form with inline venue creation, genre picker, posts toggle, **clear two-section date picker** (Event Date + Funding Deadline, at least one required, with contextual hints)
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

---

## Unimplemented Features (To Do)

### Backend Ready — Needs Frontend UI

These features have **working backend endpoints** but no frontend screen/button yet. Sorted by priority.

| # | Feature | Description | Backend Endpoints | Priority |
|---|---------|-------------|-------------------|----------|
| 1 | **Map View** | Show events on an interactive map, filter by bounding box, radius, or city | `GET /events/map` | High |
| 2 | **Add to Calendar** | Button on event detail to download an .ics file for the user's calendar app | `GET /events/{id}/calendar.ics` | High |
| 3 | **Co-Organizer Management** | Organizer can add/remove co-organizers for their event; list all organizers | `GET /events/{id}/organizers`, `POST /events/{id}/organizers`, `DELETE /events/{id}/organizers/{user_id}` | High |
| 4 | **Waitlist Approve/Reject** | Organizer/admin can approve or reject individual waitlisted registrations | `POST /events/{id}/registrations/{reg_id}/decision` | High |
| 5 | **Ticket Tier Edit & Delete** | Organizer can update or remove ticket tiers after creation | `PATCH /events/{id}/ticket-tiers/{tier_id}`, `DELETE /events/{id}/ticket-tiers/{tier_id}` | Medium |
| 6 | **Ticket Sales Dashboard** | Organizer/admin can view a list of all ticket sales for their event | `GET /events/{id}/ticket-sales` | Medium |
| 7 | **Scanned Tickets List** | Organizer/admin can view which tickets have been scanned at the door | `GET /events/{id}/scanned-tickets` | Medium |
| 8 | **Selective User Discounts** | Organizer can set/remove a custom discount for a specific user on an event | `POST /events/{id}/discounts`, `DELETE /events/{id}/discounts/{user_id}` | Medium |
| 9 | **Extend Funding** | Organizer can extend funding deadline and optionally set a new event date | `POST /events/{id}/extend-funding` | Low |

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

## File Location

- **Path:** `Crowd_Funding_Event/FEATURES.md`
- Update this file as features are implemented or new requests are added.
