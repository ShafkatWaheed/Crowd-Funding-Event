# Event Creation Wizard (Multi-Step Form)

## Initiator

- **Who:** Organizer or Admin.
- **When:** Create Event (5 steps).

## Frontend flow

- **Screen/Widget:** CreateEventScreen: (1) Basics (title, description, genre, community rules); (2) Funding; (3) Dates & Tickets; (4) Location & Sponsors; (5) Review & Publish.
- **User action:** Fill steps; Next/Back; step indicator; error indicators; unsaved dialog; submit at Review.
- **API calls:** createEvent(data) POST /api/v1/events. Intermediate: getVenues, getTicketStrategies, getDiscountStrategies.

## Backend routing

- **Entry:** POST /api/v1/events (events/crud.py).
- **Handler:** create_event. Validation: funding_end_at or start_time; funding_goal when funding set; refund cap 20%.

## Service layer

- **Module(s):** app.services.event.crud, lifecycle, permissions.
- **Main functions:** create_event(); validations in schema and service.

## Models and DB

- **Models:** Event and related (tiers, discounts, schedule).
- **Tables updated/read:** events, ticket_tiers, etc.

## Dependencies

- **Requires:** [01](01-auth-users.md), [02](02-venues.md), [14](14-ticket-strategies.md), [16](16-reusable-discount-strategies.md), [03](03-events-crud-lifecycle.md), [13](13-event-schedule.md), [45](45-parking-transport.md).
- **Triggers / side effects:** Draft or publish from step 5.

## Flow diagram

```mermaid
flowchart LR
  subgraph pipeline [Pipeline]
    A[Organizer]
    B[EventCreationWizard]
    C["multi-step POST/PATCH events"]
    D[events venues tickets discounts]
    E[event venue ticket discount]
    F[events venues tiers discounts]
  end
  A --> B --> C --> D --> E --> F
  Wiz2[02-Venues] Wiz14[14-Tickets] Wiz16[16-Discounts] Wiz3[03-Events] Wiz13[13-Schedule] Wiz45[45-Parking] -.-> D
```

## Vulnerabilities

- Server-side validation for all required fields.

## Improvements

- Step errors; loading states; date validation. Steps reordered (Dates before Funding) for tier-linked.

## Feedback

- IndexedStack; single create at end.
