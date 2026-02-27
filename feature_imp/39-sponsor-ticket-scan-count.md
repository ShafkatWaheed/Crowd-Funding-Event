# Sponsor Ticket Scan Count

## Initiator

- **Who:** Organizer/Admin (scan); System (increment scan_count).
- **When:** Ticket scanner sponsor mode; sponsor ticket card/receipt.

## Frontend flow

- **Screen/Widget:** TicketScannerScreen (sponsor mode); Sponsor ticket card/receipt (scanCount).
- **User action:** Scan sponsor QR; view count.
- **API calls:** scanSponsorTicket POST. Response includes scan_count.

## Backend routing

- **Entry:** sponsors.router → tickets.
- **Handler:** POST scan-sponsor. Increment scan_count; scanned_at on first scan.

## Service layer

- **Module(s):** app.services.sponsor.tickets.
- **Main functions:** scan_sponsor_ticket: validate, find ticket, increment scan_count, set scanned_at if first.

## Models and DB

- **Models:** SponsorTicket (scan_count, scanned_at).
- **Tables updated/read:** sponsor_tickets.

## Dependencies

- **Requires:** [Auth](01-auth-users.md), [37](37-sponsorship-prerequisites.md).
- **Triggers / side effects:** None.
- **Related:** When a sponsor ticket has **delegates** ([67 Sponsor Delegates](67-sponsor-delegates.md)), `scan_count` is incremented only when a delegate is checked in via the check-in endpoint; the initial scan returns the delegate list and does not increment the count.

## Prompt

Implement **Sponsor Ticket Scan Count** for the Crowd Funding Event app. Backend: POST scan-sponsor; increment scan_count on sponsor ticket; set scanned_at on first scan. Frontend: TicketScannerScreen sponsor mode; sponsor ticket card/receipt showing scanCount. Follow the flow, dependencies, and diagrams in this document.

## Flow diagram

```mermaid
flowchart LR
  subgraph pipeline [Pipeline]
    A[Sponsor]
    B[SponsorDashboard Scan]
    C["GET /sponsor/scan-count"]
    D[sponsor.router]
    E[sponsor scan count]
    F[ticket_sales scan]
  end
  A --> B --> C --> D --> E --> F
  Pre[37-Prerequisites] -.-> D
```

## Vulnerabilities

- Organizer/admin only. Payload validation. Multiple scans by design.

## Improvements

- Show first scanned at + count.

## Feedback

- Scanner: customer and sponsor modes.
