# Enhanced Sponsor Info for Organizers

## Initiator

- **Who:** Organizer (view sponsor profile when reviewing bids/sponsors).
- **When:** Bid Management, Organizer Sponsors (tappable sponsor name → bottom sheet → View Full Profile).

## Frontend flow

- **Screen/Widget:** `BidManagementScreen`, `OrganizerSponsorsScreen` (tappable sponsor); `SponsorProfileScreen` (`/sponsor-profile/:id`) with company, bid history, ratings.
- **User action:** Tap sponsor name; view full profile (company, profession, logo, bid stats, average rating).
- **API calls:** `getSponsorPublicProfile(userId)` GET `/api/v1/users/{id}/sponsor-public-profile`.

## Backend routing

- **Entry:** `public_profiles.router` prefix `/users`.
- **Handler:** GET `/{user_id}/sponsor-public-profile`.

## Service layer

- **Module(s):** Public profiles; SponsorProfile + ratings aggregate.
- **Main functions:** Load SponsorProfile; return company, profession, logo, bid stats, average rating.

## Models and DB

- **Models:** `User`, `SponsorProfile`, `SponsorBid`, `Rating`.
- **Tables updated/read:** `users`, `sponsor_profiles`, `sponsor_bids`, `ratings`.

## Dependencies

- **Requires:** [Auth](01-auth-users.md), [Sponsorship](37-sponsorship-prerequisites.md), [Ratings](38-ratings.md).
- **Triggers / side effects:** None.

## Flow diagram

```mermaid
flowchart LR
  subgraph pipeline [Pipeline]
    A[Organizer]
    B[EventDetail Sponsors]
    C["GET/POST/PATCH /events/id/sponsors"]
    D[sponsors.router]
    E[sponsor_service]
    F[event_sponsors]
  end
  A --> B --> C --> D --> E --> F
  Pre[37-Prerequisites] Rat[38-Ratings] -.-> E
```

## Vulnerabilities

- Only public sponsor fields; no sensitive data. user_id: validate sponsor role.

## Improvements

- Bid history on profile; paginate. Logo URL allowlist.

## Feedback

- Mirrors organizer profile; tappable on bid management and organizer sponsors.
