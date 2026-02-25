# Event Lifecycle State Machine

## Initiator

- **Who:** System (on event fetch) and Organizer/Admin (publish, cancel, set date, extend, start selling, reactivate).
- **When:** Every event fetch runs transition checks; user actions trigger state changes.

## Frontend flow

- **Screen/Widget:** Same as [Events CRUD](03-events-crud-lifecycle.md); status pill and lifecycle bar on event cards and Event Detail.
- **User action:** Publish, cancel, set event date, extend funding, reactivate, clone; admin approve/reject.
- **API calls:** Same as 03; GET event returns current status; POST lifecycle endpoints change status.

## Backend routing

- **Entry:** Same as 03; lifecycle handlers in `events/lifecycle.py`; transition logic in `app.services.event.lifecycle` and applied on event load (e.g. in get_or_404 or list).

## Service layer

- **Module(s):** `app.services.event.lifecycle`, `app.services.event.crud` (where transition check is invoked).
- **Main functions:** `cancel_event()`, `reactivate()`, `publish()`, `set_event_date()`, `extend_funding()`, `approve_extension()`, transition checks (e.g. approved → selling_tickets when funding_end_at passed; waiting_event_date → selling_tickets when start_time set; live → completed when end_time passed).

## Models and DB

- **Models:** `Event` (status, start_time, end_time, funding_end_at, pending_cancellation, pending_extension).
- **Tables updated/read:** `events`. Status enum: draft, pending_approval, approved, selling_tickets, waiting_event_date, live, completed, cancelled.

## Dependencies

- **Requires:** [Events CRUD](03-events-crud-lifecycle.md), [Auth](01-auth-users.md). Depends on platform_settings for grace period, cancel threshold.
- **Triggers / side effects:** [Spot Reservation](10-spot-reservation-funding.md) (spot release on live); [Tickets](19-tickets.md), [Registration](08-registration-waitlist.md) (which actions allowed per status); [Notifications](34-in-app-notifications.md), [Email](21-email-notifications.md).

## Flow diagram

```mermaid
flowchart LR
  subgraph pipeline [Pipeline]
    A[Organizer]
    B[EventDetailScreen]
    C["POST cancel/publish/set-date"]
    D["lifecycle.router"]
    E["event.lifecycle"]
    F["events status"]
  end
  A --> B --> C --> D --> E --> F
  F --> Spot[Spot release]
  F --> Reg[Registration]
  F --> Tix[Tickets]
  Evt[Events CRUD] --> F
```

## Vulnerabilities

- Transition checks run on fetch (no cron); if no one fetches an event, transition could be delayed. Acceptable for MVP; optional cron for time-based transitions if needed.
- selling_tickets cancellation requires admin approval; ensure admin-only route for cancellation/approve.

## Improvements

- Centralize all transition rules in one module (e.g. `compute_next_status(event, now)`) and call from both get and list to avoid drift.
- Document state diagram (draft → … → completed) in this doc or FEATURES.md for quick reference.

## Feedback

- Lifecycle is the backbone of the product; keeping it in `event/lifecycle.py` with clear function names helps. Feature doc [03](03-events-crud-lifecycle.md) and this one split CRUD vs state machine.
