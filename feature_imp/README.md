# Feature implementation docs

This folder documents each major feature of the Crowd Funding Event product: **end-to-end flow** (who initiates, frontend path, API calls, backend routing, services, models, DB) and **per-feature** Vulnerabilities, Improvements, and Feedback.

**Objective:** Use these docs to make the product **robust and professional**. Treat the Vulnerabilities and Improvements sections in each doc as an actionable backlog (prioritized by severity and impact).

## How to use

- Each feature has one file: `NN-slug.md` (e.g. `01-auth-users.md`).
- Every doc follows the same template: Initiator → Frontend flow → Backend routing → Service layer → Models and DB → Dependencies → Vulnerabilities → Improvements → Feedback.
- Cross-references use relative links to other feature docs (e.g. `[Auth](01-auth-users.md)`). Each doc has a Mermaid flow diagram; to see it rendered in Cursor/VS Code, install the **Markdown Preview Mermaid Support** extension (GitHub renders Mermaid automatically).

## Index of features

| # | File | Feature |
|---|------|---------|
| 1 | [01-auth-users.md](01-auth-users.md) | Authentication & Users |
| 2 | [02-venues.md](02-venues.md) | Venues |
| 3 | [03-events-crud-lifecycle.md](03-events-crud-lifecycle.md) | Events CRUD & Lifecycle |
| 4 | [04-event-lifecycle-state-machine.md](04-event-lifecycle-state-machine.md) | Event Lifecycle State Machine |
| 5 | [05-refund-policy.md](05-refund-policy.md) | Refund Policy |
| 6 | [06-event-discovery-search.md](06-event-discovery-search.md) | Event Discovery & Search |
| 7 | [07-co-organizer-management.md](07-co-organizer-management.md) | Co-Organizer Management |
| 8 | [08-registration-waitlist.md](08-registration-waitlist.md) | Registration & Waitlist |
| 9 | [09-funding-pledges.md](09-funding-pledges.md) | Funding & Pledges |
| 10 | [10-spot-reservation-funding.md](10-spot-reservation-funding.md) | Spot Reservation during Funding |
| 11 | [11-funding-milestones.md](11-funding-milestones.md) | Funding Milestones |
| 12 | [12-feature-flags.md](12-feature-flags.md) | Feature Flags |
| 13 | [13-event-schedule.md](13-event-schedule.md) | Event Schedule |
| 14 | [14-ticket-strategies.md](14-ticket-strategies.md) | Ticket Strategies |
| 15 | [15-event-discounts.md](15-event-discounts.md) | Event Discounts |
| 16 | [16-reusable-discount-strategies.md](16-reusable-discount-strategies.md) | Reusable Discount Strategies |
| 17 | [17-customer-loyalty.md](17-customer-loyalty.md) | Customer Loyalty |
| 18 | [18-organizer-trust-score.md](18-organizer-trust-score.md) | Organizer Trust Score |
| 19 | [19-tickets.md](19-tickets.md) | Tickets |
| 20 | [20-terms-conditions.md](20-terms-conditions.md) | Terms and Conditions |
| 21 | [21-email-notifications.md](21-email-notifications.md) | Email Notifications |
| 22 | [22-like-dislike.md](22-like-dislike.md) | Like / Dislike |
| 23 | [23-event-posts-feed.md](23-event-posts-feed.md) | Event Posts / Feed |
| 24 | [24-event-images-gallery.md](24-event-images-gallery.md) | Event Images |
| 25 | [25-sharing-calendar.md](25-sharing-calendar.md) | Sharing & Calendar |
| 26 | [26-extend-funding.md](26-extend-funding.md) | Extend Funding |
| 27 | [27-set-event-date.md](27-set-event-date.md) | Set Event Date |
| 28 | [28-admin-dashboard.md](28-admin-dashboard.md) | Admin Dashboard |
| 29 | [29-fund-escrow.md](29-fund-escrow.md) | Fund Escrow |
| 30 | [30-dark-mode.md](30-dark-mode.md) | Dark Mode |
| 31 | [31-frontend-screens-ux.md](31-frontend-screens-ux.md) | Frontend Screens & UX |
| 32 | [32-privacy-rules.md](32-privacy-rules.md) | Privacy Rules |
| 33 | [33-event-bookmarks.md](33-event-bookmarks.md) | Event Bookmarks |
| 34 | [34-in-app-notifications.md](34-in-app-notifications.md) | In-App Notifications |
| 35 | [35-organizer-public-profile.md](35-organizer-public-profile.md) | Organizer Public Profile |
| 36 | [36-sponsor-info-organizers.md](36-sponsor-info-organizers.md) | Enhanced Sponsor Info |
| 37 | [37-sponsorship-prerequisites.md](37-sponsorship-prerequisites.md) | Sponsorship Category Prerequisites |
| 38 | [38-ratings.md](38-ratings.md) | Multi-Directional Rating |
| 39 | [39-sponsor-ticket-scan-count.md](39-sponsor-ticket-scan-count.md) | Sponsor Ticket Scan Count |
| 40 | [40-event-creation-wizard.md](40-event-creation-wizard.md) | Event Creation Wizard |
| 41 | [41-milestone-early-bird-discounts.md](41-milestone-early-bird-discounts.md) | Milestone & Early Bird Discounts |
| 42 | [42-tier-linked-funding.md](42-tier-linked-funding.md) | Tier-Linked Funding |
| 43 | [43-refund-processing.md](43-refund-processing.md) | Refund Processing |
| 44 | [44-backend-scaling-infra.md](44-backend-scaling-infra.md) | Backend Scaling & Infra |
| 45 | [45-parking-transport.md](45-parking-transport.md) | Parking & Transport |
| 46 | [46-api-docs.md](46-api-docs.md) | API Documentation |
| 47 | [47-organizer-dashboard-filters.md](47-organizer-dashboard-filters.md) | Organizer Dashboard Filters (Genre and Event) |
| 48 | [48-sign-out-animation.md](48-sign-out-animation.md) | Sign-Out Animation |
| 49 | [49-redis-caching.md](49-redis-caching.md) | Redis Caching Layer |
| 50 | [50-cache-ttl-admin-toggle.md](50-cache-ttl-admin-toggle.md) | Cache TTL and Enable/Disable in Admin Settings |
| 51 | [51-backend-query-improvements.md](51-backend-query-improvements.md) | Backend Query Improvements |
| 53 | [53-banking-financial-management.md](53-banking-financial-management.md) | Banking & Financial Management |
| 54 | [54-ticket-sponsor-escrow.md](54-ticket-sponsor-escrow.md) | Ticket & Sponsor Escrow |
| 55 | [55-public-config-endpoint.md](55-public-config-endpoint.md) | Public Configuration Endpoint |
| 57 | [57-clickable-notifications-redesign.md](57-clickable-notifications-redesign.md) | Clickable Notifications Redesign |
| 58 | [58-admin-audit-logging.md](58-admin-audit-logging.md) | Admin Audit Logging |
| 59 | [59-payment-gateway-mock.md](59-payment-gateway-mock.md) | Payment Gateway (Mock) |
| 60 | [60-stripe-webhooks.md](60-stripe-webhooks.md) | Stripe Webhooks |
| 61 | [61-configurable-rate-limits.md](61-configurable-rate-limits.md) | Configurable API Rate Limits |
| 62 | [62-fcm-push-notifications.md](62-fcm-push-notifications.md) | FCM Push Notifications |
| 63 | [63-admin-configurable-file-upload-validation.md](63-admin-configurable-file-upload-validation.md) | Admin-Configurable File Upload Validation |
| 64 | [64-cache-key-injection-hardening.md](64-cache-key-injection-hardening.md) | Cache Key Injection Hardening |
| 65 | [65-arq-worker-control.md](65-arq-worker-control.md) | ARQ Worker Control |
| 66 | [66-admin-settings-expansion.md](66-admin-settings-expansion.md) | Admin Settings Expansion |
| 67 | [67-sponsor-delegates.md](67-sponsor-delegates.md) | Sponsor Delegates |
| 68 | [68-escrow-bank-account-guard.md](68-escrow-bank-account-guard.md) | Escrow Bank Account Guard |
| 69 | [69-structured-logging.md](69-structured-logging.md) | Structured JSON Logging (stdout, OpenSearch-ready) |
| 70 | [70-sponsor-negotiation-chat.md](70-sponsor-negotiation-chat.md) | Sponsor-Organizer Negotiation Chat |

### Partially implemented

| # | File | Feature | Note |
|---|------|---------|------|
| 52 | [52-kyc-aml-verification.md](52-kyc-aml-verification.md) | KYC/AML Verification | Mock + admin review live; Stripe Identity pending |

### Planned (not yet implemented)

| # | File | Feature |
|---|------|---------|
| 56 | [56-mobile-platform-ios-android.md](56-mobile-platform-ios-android.md) | Mobile Platform (iOS & Android) |
