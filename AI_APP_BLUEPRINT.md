# Blueprint: Building Full-Stack Apps with AI

> A practical playbook distilled from building a production-grade Crowd-Funded Event Platform (FastAPI + Flutter) entirely with AI assistance.

---

## Table of Contents

1. [Mindset Shift](#1-mindset-shift)
2. [Before You Write a Single Prompt](#2-before-you-write-a-single-prompt)
3. [The Phased Build Strategy](#3-the-phased-build-strategy)
4. [Prompting Patterns That Work](#4-prompting-patterns-that-work)
5. [The Backend-First Rule](#5-the-backend-first-rule)
6. [Frontend Execution](#6-frontend-execution)
7. [Error Recovery & Debugging](#7-error-recovery--debugging)
8. [Managing Context Across Sessions](#8-managing-context-across-sessions)
9. [Anti-Patterns to Avoid](#9-anti-patterns-to-avoid)
10. [The Complete Workflow](#10-the-complete-workflow)
11. [Prompt Templates](#11-prompt-templates)

---

## 1. Mindset Shift

Building with AI is not "telling a computer what to code." It is **collaborative architecture** — you are the product owner, architect, and QA lead. The AI is your senior developer who never gets tired but needs clear direction.

**Key principles:**

- **You own the decisions.** The AI proposes, you approve. Never let the AI pick your database, auth strategy, or state management without understanding why.
- **Think in systems, not screens.** Before building a "login page," think: auth flow → token storage → protected routes → role-based access → session expiry.
- **Small, verified steps beat big ambiguous leaps.** A working login screen today is worth more than a half-broken app with 20 features tomorrow.

---

## 2. Before You Write a Single Prompt

### 2.1 Define Your App in One Paragraph

Write a plain-English description of what your app does, who uses it, and what makes it different. This becomes your north star.

**Example (this project):**
> "A platform where organizers create crowd-funded events at venues, customers pledge money and buy tickets, events progress through a lifecycle (draft → approval → funding → tickets → live → completed), with real-time status tracking, QR ticket scanning, and map-based discovery."

### 2.2 Identify Your Actors (Roles)

List every user type and what they can do:

```
- Customer: browse events, pledge, buy tickets, view receipts
- Organizer: create events/venues, manage tickets, scan QR codes, view sales
- Admin: approve/reject events, manage users, override statuses
```

### 2.3 Create a Feature Inventory

Before touching code, create a `FEATURES.md` file. List every feature you want, grouped by domain. Mark each as TODO, IN PROGRESS, or COMPLETED. This file becomes your conversation anchor — you'll reference it constantly.

```markdown
| # | Feature                    | Status    |
|---|----------------------------|-----------|
| 1 | User auth (JWT)            | COMPLETED |
| 2 | Event CRUD                 | COMPLETED |
| 3 | Venue management           | TODO      |
| 4 | Ticket purchasing          | TODO      |
| ...                                        |
```

### 2.4 Pick Your Stack and Commit

Decide early. Changing frameworks mid-project wastes enormous context. Recommended stacks for AI-assisted development:

| Layer       | Recommended                  | Why                                    |
|-------------|------------------------------|----------------------------------------|
| Backend     | FastAPI (Python) or Express  | AI knows these deeply, great ecosystem |
| Database    | PostgreSQL + SQLAlchemy/Prisma | Mature, well-documented               |
| Frontend    | Flutter, Next.js, or React   | AI generates high-quality code for all |
| Auth        | JWT with refresh tokens      | Simple, stateless, AI handles well     |
| State Mgmt  | Provider (Flutter) / Zustand | Minimal boilerplate, AI-friendly       |

---

## 3. The Phased Build Strategy

**This is the single most important section.** Do not try to build everything at once. Break your app into phases of 3-5 related features each.

### Phase ordering rules:

1. **Foundation first**: Auth, user model, database setup, project structure
2. **Core domain next**: The main entity your app revolves around (events, products, posts)
3. **Relationships after**: Connecting entities (events → venues, users → tickets)
4. **Business logic then**: Workflows, state machines, validations
5. **Discovery & UX last**: Search, maps, notifications, polish

### Example phase plan (from this project):

```
Phase 1:  Auth + User roles + JWT
Phase 2:  Venue CRUD
Phase 3:  Event CRUD + Status lifecycle
Phase 4:  Funding (pledges, goals, deadlines)
Phase 5:  Ticket tiers + Purchasing
Phase 6:  Registration + Capacity management
Phase 7:  Admin approval workflow
Phase 8:  Search + Filters + Featured events
Phase 9:  Multi-ticket purchase + Receipts
Phase 10: Email notifications
Phase 11: QR ticket encryption + Scanning
Phase 12: Map view + Location discovery
Phase 13: UI polish + Consistency pass
```

**Rule: Never start Phase N+1 until Phase N compiles and runs without errors.**

---

## 4. Prompting Patterns That Work

### 4.1 The Feature Brief (Starting a New Feature)

When starting a new feature, give the AI a complete brief:

```
Implement [FEATURE NAME].

Context:
- We have [existing models/tables]
- The [ROLE] needs to [ACTION]
- It should work like [ANALOGY or DESCRIPTION]

Requirements:
- Backend: [endpoint, model changes, validation rules]
- Frontend: [screen, navigation, state management]
- Edge cases: [what happens when X, Y, Z]

Constraints:
- Must be consistent with our existing [theme/patterns/architecture]
- Use [specific library] for [specific thing]
```

**Real example from this project:**
```
Implement multi-ticket purchasing.

Context:
- We have TicketTier and TicketSale models
- Customers select a tier and quantity, then purchase

Requirements:
- Backend: accept quantity in purchase endpoint, generate individual 
  ticket codes, group them by purchase_group_id, return aggregated receipt
- Frontend: quantity selector on purchase screen, group receipt screen 
  showing all tickets with individual QR codes
- Edge cases: insufficient capacity, max per user limits, concurrent purchases

Constraints:
- Use existing AppTheme colors and card patterns
- QR codes should encode structured JSON (event_id, ticket_code, tier)
```

### 4.2 The Surgical Fix (Fixing a Specific Bug)

Paste the exact error. Include the file path and line number. State what you expected vs what happened.

```
Error in lib/widgets/event_map_widget.dart:12:
'MapEvent' is imported from both 'package:crowd_funding_app/models/map_event.dart' 
and 'package:flutter_map/src/gestures/map_events.dart'.

Expected: No naming conflicts
Actual: Dart compiler fails due to ambiguous import

Fix this naming collision.
```

**Why this works:** The AI doesn't have to guess. It knows the file, the line, the error type, and what "done" looks like.

### 4.3 The Continuation Prompt

When a session times out or you return later:

```
continue where you left off
```

This works because the AI has conversation history. But for fresh sessions, be more specific:

```
We're building a Crowd Funding Event app (FastAPI + Flutter).

Last session we completed: [Phase X features]
Current state: [what compiles, what's broken]
Next task: [what to build next]

Reference FEATURES.md for the full feature list.
```

### 4.4 The Architecture Question

When you need to make a technical decision:

```
What can we use to build [FEATURE]?

Requirements:
- Must work on [platforms]
- Needs [specific capability]
- Prefer [free/open-source/specific license]
```

**Let the AI propose options, then YOU decide.** Example from this project:
- "What can we use to build a QR scanner?" → AI proposed `mobile_scanner` → User approved → AI integrated.
- "Can I get venue location from Mapbox?" → AI confirmed → User chose Mapbox over Nominatim → AI implemented.

### 4.5 The Consistency Directive

When you want changes across the app:

```
Make [SPECIFIC THING] consistent across all screens.

Rules:
- [Specific rule 1]
- [Specific rule 2]

Affected screens: [list them or say "all"]
```

**Real example:** "Make sure the map theme is consistent with our theme" — one sentence that triggered the AI to match Mapbox's `dark-v11` style with `AppTheme` colors across markers, popups, and toggles.

---

## 5. The Backend-First Rule

**Always build backend before frontend for each feature.**

### The pattern:

```
1. Database model / migration
2. Service layer (business logic)
3. API endpoint (route + validation)
4. Test the endpoint (curl / Swagger UI)
5. Frontend model (Dart/TS class matching the API response)
6. API service method (the HTTP call)
7. State management (Provider/Zustand)
8. UI screen
```

### Why this order matters:

- The API contract is defined before the UI exists, so you don't build screens that talk to endpoints that don't exist yet.
- Each step is independently verifiable. Model compiles? Check. Endpoint returns correct JSON? Check. UI renders? Check.
- If the AI makes a mistake, you catch it at the smallest possible scope.

### Prompt for backend work:

```
Add a new endpoint: POST /events/{id}/scan-ticket

Request body: { ticket_code: string?, encrypted_payload: string? }
Response: { status: "success"|"already_scanned"|"invalid", ticket_info: {...} }

Business logic:
- If encrypted_payload provided, decrypt with AES-256-GCM, extract ticket_code
- Look up TicketSale by ticket_code
- Verify it belongs to this event
- If already scanned, return "already_scanned"
- Mark as scanned (scanned_at = now), return ticket details

Add the Pydantic schemas and service function too.
```

---

## 6. Frontend Execution

### 6.1 Model First, Screen Second

Always create/update the Dart/TS model before building the screen. The AI needs to know the data shape.

```
Update the TicketSale model to include the new encrypted_qr_payload field 
from the API response. Then update the receipt screen to use it for QR codes.
```

### 6.2 State the Screen's Purpose

```
Build a ticket scanner screen.

It should:
- Use mobile_scanner for camera-based QR detection
- Parse both encrypted and plaintext QR payloads
- Call POST /events/{id}/scan-ticket
- Show success (green), already-scanned (amber), or invalid (red) feedback
- Track scan count in the session
- Include torch toggle and camera switch buttons
- Be accessible from event detail screen for organizers
```

### 6.3 Reference Existing Patterns

The most powerful prompt modifier is: **"follow the same pattern as [existing screen]"**

```
Build the waitlist management screen following the same pattern as 
the ticket sales screen — same card layout, same search/filter bar, 
same empty state design.
```

This gives the AI a concrete reference and ensures consistency without you having to describe every pixel.

### 6.4 Theme and Styling

Establish your theme early (Phase 1) and reference it everywhere:

```dart
// Define once in config/theme.dart
class AppTheme {
  static const Color primaryColor = Color(0xFF000000);
  static const Color accentColor = Color(0xFF276EF1);
  static const Color successColor = Color(0xFF05944F);
  static const Color errorColor = Color(0xFFE11900);
  static const Color surfaceColor = Color(0xFFF6F6F6);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF141414);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color dividerColor = Color(0xFFE2E2E2);
  // ... consistent border radius, shadows, text styles
}
```

Then in prompts: "Use AppTheme colors. Follow our existing card style with 16px border radius, subtle box shadow, and white background."

---

## 7. Error Recovery & Debugging

### 7.1 Copy-Paste the Exact Error

Never paraphrase errors. The AI needs the exact text:

```
importError: cannot import name 'PurchaseGroupReceiptResponse' from 'app.schemas'
```

Not: "there's an import error in schemas"

### 7.2 Build After Every Feature

Run `flutter analyze` (or your linter) and `flutter build web` after every feature. Don't stack 3 features then discover 15 errors.

### 7.3 The "Stale Cache" Pattern

If you get errors that don't match the source code:

```
flutter clean && flutter pub get
```

This happened to us when renaming `MapEvent` to `EventMarker` — the build cache held the old class name.

### 7.4 Permission Issues

If package installs or builds fail with permission errors:

```bash
sudo chown -R $(whoami) /path/to/project
```

This commonly happens when tools run with elevated privileges during one step and regular privileges during another.

### 7.5 Database Errors

For 500 errors, always check:
1. **Foreign key constraints** — deleting a parent with children? (Our venue delete bug)
2. **Missing migrations** — new column but old schema?
3. **Null violations** — required field not provided?

Prompt: "I get a 500 on DELETE /venues/2. Check for foreign key constraint issues."

---

## 8. Managing Context Across Sessions

### 8.1 The FEATURES.md Anchor

Update `FEATURES.md` after every completed phase. This file lets you (and the AI) quickly understand project state.

### 8.2 Conversation Continuity

When the AI says "continue where you left off" works, it's because it has:
- Your conversation history
- Access to read your files
- The FEATURES.md as ground truth

For fresh sessions, provide:
1. Tech stack reminder
2. What's completed (reference FEATURES.md)
3. Current errors or state
4. What to build next

### 8.3 The "Do We Have Conflicts" Check

Before starting a new feature that touches existing code, ask:

```
Do we have any conflicts with this feature?
```

This triggers the AI to scan existing code for naming collisions, import conflicts, model mismatches, and migration issues BEFORE writing new code.

---

## 9. Anti-Patterns to Avoid

### 9.1 The Kitchen Sink Prompt
**Bad:**
```
Build a complete event management system with auth, CRUD, tickets, 
payments, maps, notifications, admin panel, and analytics.
```

**Why it fails:** Too broad. The AI will scaffold shallow implementations of everything instead of deep implementations of anything.

**Good:** Break into 13 phases (see Section 3).

### 9.2 The Vague Aesthetic Request
**Bad:**
```
Make it look modern.
```

**Good:**
```
Modernize the manage tab: remove the event grid, upgrade quick action 
cards with colored icon backgrounds and subtle shadows, add consistent 
rounded corners (16px), match the header style from the Home tab.
```

### 9.3 Ignoring Errors
**Bad:** Seeing a warning and continuing to build new features.
**Good:** Fix every error and warning before starting the next feature. Technical debt compounds exponentially.

### 9.4 Not Verifying Backend Before Frontend
**Bad:** Building a whole purchase flow UI, then discovering the endpoint returns a different shape.
**Good:** Test the endpoint with curl or Swagger UI first, then build the UI.

### 9.5 Changing Architecture Mid-Build
**Bad:** "Actually, let's switch from Provider to Riverpod" on Phase 8.
**Good:** Make architecture decisions in Phase 1. Commit to them.

---

## 10. The Complete Workflow

Here is the step-by-step workflow for building each feature:

```
┌─────────────────────────────────────────────┐
│  1. UPDATE FEATURES.md — mark as IN PROGRESS │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  2. ASK: "Do we have conflicts with this?"   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  3. BACKEND — Model → Service → Endpoint     │
│     Verify: curl / Swagger UI                │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  4. FRONTEND — Model → API Service → Screen  │
│     Verify: flutter analyze                  │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  5. BUILD — flutter build web (or run)       │
│     Fix any errors immediately               │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  6. TEST — manually verify the flow          │
│     Check edge cases                         │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  7. COMMIT — git add + commit with message   │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  8. UPDATE FEATURES.md — mark as COMPLETED   │
│     Move to next feature                     │
└─────────────────────────────────────────────┘
```

---

## 11. Prompt Templates

### Starting a new project:

```
I'm building a [TYPE] app using [BACKEND STACK] and [FRONTEND STACK].

Users: [list roles and what each can do]

Core features (in priority order):
1. [Feature 1]
2. [Feature 2]
...

Start with project scaffolding: folder structure, dependency files, 
database setup, and user auth (JWT with role-based access).
```

### Adding a feature:

```
Implement [FEATURE NAME].

Backend:
- New model/fields: [describe]
- New endpoint: [METHOD /path — request/response shape]
- Business logic: [rules, validations, edge cases]

Frontend:
- New screen: [describe purpose and layout]
- Navigation: [how user gets there]
- State: [what data to fetch/manage]

Follow existing patterns. Use AppTheme for styling.
```

### Fixing a bug:

```
[PASTE EXACT ERROR]

File: [path]
What I was doing: [action that triggered it]
Expected: [what should happen]
```

### UI consistency pass:

```
Make [ASPECT] consistent across all screens:
- [Rule 1]
- [Rule 2]
- [Rule 3]

Affected files: [list or "all screens"]
```

### Asking for options:

```
What are our options for [CAPABILITY]?

Requirements:
- [Requirement 1]
- [Requirement 2]
- Platform: [web/mobile/both]
- Budget: [free/paid OK]

Give me 2-3 options with trade-offs.
```

---

## 12. Tech Stack Recommendations

### For AI-assisted full-stack development:

| Choice          | Recommendation        | Reason                                              |
|-----------------|-----------------------|-----------------------------------------------------|
| Backend         | **FastAPI** (Python)  | Type hints = fewer AI mistakes. Auto-docs via Swagger |
| ORM             | **SQLAlchemy 2.0**    | Async support, AI knows it deeply                    |
| Database        | **PostgreSQL**        | Robust, free, excellent ecosystem                    |
| Migrations      | **Alembic**           | Pairs with SQLAlchemy, AI handles well               |
| Frontend        | **Flutter**           | Single codebase for web + mobile, strong typing      |
| State           | **Provider**          | Simple, predictable, minimal boilerplate             |
| Routing         | **GoRouter**          | Declarative, deep-link support                       |
| HTTP Client     | **Dio**               | Interceptors for auth tokens, error handling         |
| Auth            | **JWT + Refresh**     | Stateless, simple, AI implements correctly            |
| Maps            | **flutter_map + Mapbox** | Cross-platform, generous free tier                |
| QR Codes        | **qr_flutter + mobile_scanner** | Generate + scan in one stack            |
| Encryption      | **cryptography (Python)** | AES-256-GCM for ticket security                 |

### Project structure that works:

```
project/
├── Backend/
│   ├── app/
│   │   ├── api/v1/          # Route handlers (thin)
│   │   ├── core/            # Config, exceptions, security
│   │   ├── models/          # SQLAlchemy models
│   │   ├── schemas/         # Pydantic request/response
│   │   ├── services/        # Business logic (thick)
│   │   └── main.py
│   ├── alembic/             # Migrations
│   └── requirements.txt
├── FrontEnd/
│   └── lib/
│       ├── config/          # Theme, router, constants
│       ├── models/          # Dart data classes
│       ├── providers/       # State management
│       ├── services/        # API client, helpers
│       ├── screens/         # Pages (grouped by domain)
│       ├── widgets/         # Reusable components
│       └── main.dart
├── FEATURES.md              # Your living feature tracker
└── AI_APP_BLUEPRINT.md      # This file
```

---

## Final Thought

The best prompt is a clear thought. If you can explain what you want to a colleague in 30 seconds, you can prompt an AI to build it. The art is in the sequencing — small, verifiable steps, backend before frontend, errors fixed before new features, and a living document that keeps everyone (including the AI) on the same page.

Build one thing. Verify it works. Move on. Repeat 50 times. You have a production app.

---

*Generated from the development of the Crowd-Funded Event Platform — 16 phases, 100+ features, FastAPI + Flutter, built entirely with AI assistance.*
