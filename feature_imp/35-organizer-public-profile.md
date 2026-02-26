# Organizer Public Profile

## Initiator

- **Who:** Any user (view). Event detail shows organizer name (tappable).
- **When:** Tap organizer name on Event Detail; Organizer Profile screen (`/organizer-profile/:id`).

## Frontend flow

- **Screen/Widget:** Event Detail (organizer name → bottom sheet + "View Full Profile"); `OrganizerProfileScreen` (stats, event list, average rating).
- **User action:** Tap organizer name; view profile (display name, username, role, trust score, event count, events, ratings).
- **API calls:** `getPublicProfile(userId)` GET `/api/v1/users/{id}/public-profile`; `getPublicEvents(userId)` GET `/api/v1/users/{id}/public-events`. EventResponse includes organizer_name.

## Backend routing

- **Entry:** `api_router` → `public_profiles.router` prefix `/users`.
- **Handler:** `public_profiles.py` → GET `/{user_id}/public-profile`, GET `/{user_id}/public-events`.

## Service layer

- **Module(s):** Public profile logic; event list by organizer_id, published status.
- **Main functions:** Return display_name, username, role, trust score, event count; list events for organizer.

## Models and DB

- **Models:** `User`, `Event`, `Rating`. Read-only.
- **Tables updated/read:** `users`, `events`, `ratings`.

## Dependencies

- **Requires:** [Auth](01-auth-users.md), [Events](03-events-crud-lifecycle.md), [Trust Score](18-organizer-trust-score.md), [Ratings](38-ratings.md).
- **Triggers / side effects:** None.

## Prompt

Implement **Organizer Public Profile** for the Crowd Funding Event app. Backend: GET `/users/{id}/public-profile`, GET `/{id}/public-events`; return display_name, username, role, trust score, event count, events. Frontend: Event Detail tappable organizer name; OrganizerProfileScreen with stats, event list, average rating. Follow the flow, dependencies, and diagrams in this document.

## Flow diagram

```mermaid
flowchart LR
  subgraph pipeline [Pipeline]
    A[Public User]
    B[OrganizerProfileScreen]
    C["GET /organizers/id"]
    D[organizers.router]
    E[organizer profile]
    F[users events trust]
  end
  A --> B --> C --> D --> E --> F
  Trust[18-Trust] Rat[38-Ratings] -.-> E
```

## Vulnerabilities

- Expose only public fields; no email/phone. user_id in URL: public by design.

## Improvements

- Cache profile short TTL. Paginate public events.

## Feedback

- Tappable organizer name; single profile + events endpoints. organizer_name in EventResponse avoids extra call.
