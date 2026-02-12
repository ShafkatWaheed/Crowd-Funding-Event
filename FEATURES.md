# Crowd Funding Event — Features

This document lists **current features**, **requested/new features**, and **unimplemented** items for the project.

---

## Currently Implemented

- **Auth:** Firebase Auth, backend verify, login/register, roles (admin, organizer, customer)
- **Users:** Profile (GET/PATCH /me), display name, phone, role; email hidden (admin-only)
- **Venues:** CRUD for organizers, list (organizers see own; customers see all)
- **Events:** CRUD, draft vs publish (no admin approval), cancel (with reason), reactivate (cancelled -> draft), delete (draft/cancelled only)
- **Registration:** Open/closed (waitlist), register/unregister, capacity checks, registration count on events
- **Funding:** Pledge, unpledge (refund), guest pledges (non-refundable with disclaimer), funding goal, min pledge, funding deadline, total pledged / days left
- **Tickets:** Ticket tiers, price preview with discounts, purchase, scan (QR), ticket sales list
- **Admin:** List users/events (full email visible), stats, draft events list
- **Discovery:** Trending events (by registration count), Popular events (by pledge amount), Coming Soon (future approved events), featured sections on home screen
- **Search:** Multi-parameter filters: text search, status, registration type, date range, has funding toggle, genre filter
- **Sharing:** Share event link (copy to clipboard)
- **Event Genres (Phase 3):** Predefined genre/category on events (community, music, tech, sports, arts, food, charity, education, business, other); genre picker on create/edit; genre filter on home; genre badge on event cards and featured cards
- **Event Posts / Feed (Phase 3):** Registered users can post on event wall; organizer can toggle posts on/off per event; posts listed with author name, time-ago, delete option for author/organizer/admin
- **Event Images / Gallery (Phase 3):** Add images by URL with optional caption; horizontal scrollable gallery on event detail; organizer/admin can delete images
- **Frontend:** Login, register (with phone), home (event list + featured + advanced filters + genre filter), event detail (cancel reason, unpledge, guest disclaimer, posts feed, image gallery, genre badge), create event (inline venue, genre picker, posts toggle), profile, venues, admin dashboard
- **API docs:** Swagger at `/api/v1/docs`, redirect from `/docs`

---

## Requested / New Features (To Implement)

### Delete & Moderation
- **Admin approval when 80% pledge raised** -- If an event has reached 80% of its funding goal, deletion (or cancellation?) must require admin approval before taking effect.

### Notifications
- **Cancellation email** -- When an event is cancelled, send email to all registered users with the cancellation reason.
- **Unpledge email** -- Send email confirmation when a user unpledges.

### Map
- **Map to show events** -- Map view showing event locations (e.g. using lat/lng); filter by city/location.

### Support
- **Chatbot for support** -- In-app or linked chatbot for user support.

### Admin Control
- **Admin controls all features** -- Admin can enable/disable or configure features (e.g. posts, guest pledges, commission, etc.).

### Discovery & Ranking
- **Based on user location** -- Show events near the user (location-based).

### Tickets & Commission
- **Commission per ticket sale** -- Platform takes a commission (e.g. 2%); configurable by admin (e.g. if under a threshold).
- **Ticket prices: free or flexible** -- Support free tickets and flexible pricing options.
- **Ticket encryption** -- Tickets (e.g. QR/code) should be encrypted.

### Monetization & Event Types
- **Free event posting** -- Allow some events to be posted for free.
- **Event genre pricing rules** -- Community events promotion cost (e.g. $10); platform takes cut from pledges; community max 2 weeks; other events no limit.

### Trending & Engagement (Tickets)
- **Ticket-level engagement** -- Newcomer badge, like button, trending indicator for tickets/events.

### Verification
- **Verify event organizer** -- Verification flow for event organizers (e.g. identity/contact verification).
- **Verify organizer through apps** -- Use external verification service or app to verify organizers.

### Rich Media (Enhancements)
- **File upload for images** -- Replace URL-based image add with actual file upload + cloud storage.
- **Parking info, Uber-style gallery** -- Structured parking/transportation fields in event description.

---

## Completed Features (by Phase)

| Phase | Features |
|-------|----------|
| Phase 1 | Display names (hide email), phone field, share button, mandatory username |
| Phase 2 | Cancel reason, unpledge/refund, guest pledge disclaimer, multi-param search, trending/popular/coming-soon |
| Phase 3 | Event post/feed system, event genres/categories, event image gallery |

---

## Unimplemented (Summary)

| Area            | Item |
|-----------------|------|
| Moderation      | Admin approval when 80% pledged |
| Email           | Cancellation email to registrants; unpledge confirmation email |
| Map             | Map view for events |
| Support         | Chatbot |
| Admin           | Feature flags / control over all above |
| Discovery       | Location-based event discovery |
| Tickets         | Commission (admin-configurable); free/flexible price; encryption |
| Events          | Free event posting; genre pricing rules (community vs other) |
| Ranking         | Newcomer/like/trending for tickets |
| Verification    | Organizer verification; verify via "Apps" |
| Media           | File upload for images; parking/transport info |

---

## File Location

- **Path:** `Crowd_Funding_Event/FEATURES.md`
- Update this file as features are implemented or new requests are added.
