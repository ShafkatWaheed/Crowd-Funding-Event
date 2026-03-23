# Enhanced Sponsor Info for Organizers

## Initiator

- **Who:** Organizer (view sponsor profile when reviewing bids/sponsors).
- **When:** Bid Management, Organizer Sponsors (tappable sponsor name → bottom sheet → View Full Profile).

## Frontend flow

- **Screen/Widget:** `BidManagementScreen`, `OrganizerSponsorsScreen` (tappable sponsor); `SponsorProfileScreen` (`/sponsor-profile/:id`) with company, bid history, ratings; **Contact & Social** card (bio, email, website, social handles — same as organizer public profile) when sponsor has set contact/social.
- **User action:** Tap sponsor name; view full profile (company, profession, logo, bid stats, average rating, contact and social links).
- **API calls:** `getSponsorPublicProfile(userId)` GET `/api/v1/users/{id}/sponsor-public-profile`. Sponsor public profile response includes **contact/social** (bio, website_url, contact_email, instagram, twitter, facebook, linkedin, youtube, tiktok) when set; see [01-auth-users](01-auth-users.md) for PATCH `/me` and ProfileContactSection.

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

## Prompt

Implement **Enhanced Sponsor Info for Organizers** for the Crowd Funding Event app. Backend: GET `/users/{id}/sponsor-public-profile` (company, profession, logo, bid stats, average rating). Frontend: Tappable sponsor name in Bid Management and Organizer Sponsors; SponsorProfileScreen. Follow the flow, dependencies, and diagrams in this document.

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
