# Event Discovery & Search

## Initiator

- **Who:** Customer or unauthenticated (browse); Organizer/Admin (see own + all statuses).
- **When:** Home tab, Explore tab, Map view, Featured sections (Trending, Popular, Coming Soon, Near Me, Community).

## Frontend flow

- **Screen/Widget:** `HomeScreen` (search bar, genre chips, featured carousels, search results grid), `Explore` tab (filters, list/map toggle), Map (Mapbox markers), “Near Me” (geolocation).
- **User action:** Search text, select genre, filter by status/date/city/capacity/funding/tickets; toggle map view; allow location for Near Me.
- **API calls:** `getEvents(params)` (GET `/api/v1/events` with query params), `getFeaturedEvents()`, `getMapEvents(bounds)`, `getGenres()`; list_events supports search, city, status, date_from, date_to, has_funding, has_tickets, min/max_capacity, genre, community_rules, sponsorship_only, include_all_statuses.

## Backend routing

- **Entry:** `api_router` → `events_router` prefix `/events`; `map_.router` before events (GET `/events/map`).
- **Handler:** `events/crud.py` → `list_events`, `get_featured_events`; `crud.py` → GET `/{event_id}` for detail; `map_.py` → GET `/map` (under events prefix) → returns map markers.

## Service layer

- **Module(s):** `app.services.event.crud` (or dashboard), `app.services.dashboard` for trending/popular/coming-soon.
- **Main functions:** `list_events()` (filters, pagination), `get_trending_events()`, `get_popular_events()`, `get_coming_soon_events()`; map aggregates events by venue for markers.

## Models and DB

- **Models:** `Event`, `Venue`; denormalized or joined for registration count, pledge totals, ticket counts, first image.
- **Tables updated/read:** `events`, `venues`, `registrations`, `fundings`, `ticket_sales`, `event_images` (for featured image).

## Dependencies

- **Requires:** [Auth](01-auth-users.md) (optional for list; affects include_all_statuses and organizer filter).
- **Triggers / side effects:** None (read-only discovery).

## Flow diagram

```mermaid
flowchart LR
  subgraph pipeline [Pipeline]
    A[Customer]
    B[HomeScreen Explore]
    C["GET /events GET /map"]
    D[crud + map_]
    E[event.crud dashboard]
    F[events venues]
  end
  A --> B --> C --> D --> E --> F
```

## Vulnerabilities

- List is filtered by status for non-organizers (draft/pending/cancelled hidden). Organizers see own events with include_all_statuses. No sensitive data in list response.
- Map endpoint returns event markers; ensure only public event fields and no PII.

## Improvements

- Featured and list both hit DB; consider caching featured (short TTL) to reduce load.
- Near Me uses frontend geolocation then backend filter by lat/lng; ensure index on venue/event location for radius queries.

## Feedback

- Discovery is well parameterized; map and list share same event model. Genre and filters are consistent with FEATURES.md.
