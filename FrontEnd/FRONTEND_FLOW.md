# Frontend Flow — How the Flutter Web App Works

This document explains how the Flutter frontend is structured: project layout, data flow, authentication, routing, state management, and how each screen connects to the backend API.

---

## 1. App Startup

```
main.dart
    ↓  WidgetsFlutterBinding.ensureInitialized()
    ↓  dotenv.load('.env')              — loads Firebase config + API_BASE_URL
    ↓  Firebase.initializeApp(options)  — initializes Firebase Auth for the web
    ↓  runApp(CrowdFundApp)
    ↓
CrowdFundApp  (StatelessWidget)
    ↓  MultiProvider  (sets up dependency injection for the whole app)
    │   ├── Provider<ApiService>          — Dio HTTP client with auth interceptor
    │   ├── ChangeNotifierProvider<AuthProvider>  — auth state, current user
    │   └── ChangeNotifierProvider<EventProvider> — event list/detail state
    ↓
Consumer<AuthProvider>  →  creates GoRouter  →  MaterialApp.router
```

- **Environment:** All secrets (Firebase keys, API URL) live in `.env`, loaded via `flutter_dotenv`. The `.env` file is listed as a Flutter asset in `pubspec.yaml` and gitignored.
- **Firebase:** Initialized once at startup with config from `.env`. Firebase Auth handles sign-in/sign-up and provides ID tokens.
- **Providers:** Set up at the root so every screen can access `ApiService`, `AuthProvider`, and `EventProvider` via `context.read<T>()` or `context.watch<T>()`.

---

## 2. Authentication Flow

### Sign Up (new user)

```
RegisterScreen
    ↓  User picks role (Customer / Organizer), enters email + password
    ↓
AuthProvider.signUp(email, password, role, displayName)
    ↓
FirebaseAuth.createUserWithEmailAndPassword(email, password)
    ↓  Returns UserCredential with Firebase User
    ↓
user.getIdToken()  →  idToken
    ↓
ApiService.verifyToken(idToken, role)
    ↓  POST /api/v1/auth/verify  { id_token, role }
    ↓  Backend creates user in PostgreSQL, returns profile
    ↓
ApiService.getMe()
    ↓  GET /api/v1/me  (Bearer token auto-attached by Dio interceptor)
    ↓
AuthProvider._user = AppUser.fromJson(response)
AuthProvider._state = AuthState.authenticated
    ↓  notifyListeners()
    ↓
GoRouter redirect:  isAuthenticated + on /register  →  redirect to '/'
```

### Sign In (existing user)

```
LoginScreen
    ↓  User enters email + password
    ↓
AuthProvider.signIn(email, password)
    ↓
FirebaseAuth.signInWithEmailAndPassword(email, password)
    ↓  Returns UserCredential
    ↓
user.getIdToken()  →  idToken
    ↓
ApiService.verifyToken(idToken, 'customer')   — backend looks up existing role
    ↓  POST /api/v1/auth/verify
    ↓
ApiService.getMe()  →  AppUser
    ↓
AuthProvider._state = authenticated  →  notifyListeners()  →  GoRouter redirects to '/'
```

### Sign Out

```
AuthProvider.signOut()
    ↓  FirebaseAuth.signOut()
    ↓  _user = null,  _state = unauthenticated
    ↓  notifyListeners()
    ↓
GoRouter redirect:  !isAuthenticated  →  redirect to '/login'
```

### Auto-Login (on app reload)

```
FirebaseAuth.authStateChanges() stream
    ↓  Firebase restores session from browser storage
    ↓
AuthProvider._onAuthStateChanged(firebaseUser)
    ↓  If user != null:  ApiService.getMe()  →  load AppUser
    ↓  If user == null:  state = unauthenticated
```

---

## 3. How API Calls Work

Every API call goes through `ApiService`, which wraps Dio.

```
Any screen / provider
    ↓  calls ApiService method (e.g. api.getEvents())
    ↓
Dio interceptor (onRequest)
    ↓  FirebaseAuth.instance.currentUser
    ↓  user.getIdToken()  →  fresh ID token
    ↓  Attaches:  Authorization: Bearer <token>
    ↓
Dio sends HTTP request to backend
    ↓  Base URL from ApiConfig  (reads API_BASE_URL from .env)
    ↓  e.g. GET http://localhost:8000/api/v1/events
    ↓
Response  →  parsed as Map/List  →  returned to caller
```

**Key point:** The Dio interceptor automatically refreshes and attaches the Firebase ID token on every request. No manual token management needed in screens.

---

## 4. State Management (Provider Pattern)

```
┌─────────────────────────────────────────────────────┐
│  MultiProvider (root of widget tree)                │
│  ├── ApiService         — stateless HTTP client     │
│  ├── AuthProvider       — auth state + current user │
│  └── EventProvider      — event list + detail       │
└─────────────────────────────────────────────────────┘
         │
         ▼
   Screens use:
   • context.watch<T>()  — rebuild when state changes (in build())
   • context.read<T>()   — one-time access (in callbacks, initState)
```

### AuthProvider

| Field | Type | Purpose |
|-------|------|---------|
| `_state` | `AuthState` | `initial → loading → authenticated / unauthenticated / error` |
| `_user` | `AppUser?` | Current user profile (id, email, displayName, role) |
| `_errorMessage` | `String?` | Human-readable error for UI display |

Listens to `FirebaseAuth.authStateChanges()` for auto-login/logout.

### EventProvider

| Field | Type | Purpose |
|-------|------|---------|
| `_events` | `List<Event>` | Current event list (from search/filter) |
| `_selectedEvent` | `Event?` | Currently viewed event detail |
| `_isLoading` | `bool` | Loading indicator for UI |
| `_error` | `String?` | Error message for UI |

Methods: `loadEvents(filters)`, `loadEvent(id)`, `createEvent(data)`, `submitEvent(id)`, `cancelEvent(id)`.

---

## 5. Routing (GoRouter)

```
GoRouter
    ↓  refreshListenable: authProvider  (re-evaluates redirect on auth changes)
    ↓
redirect logic:
    ├── loading?        →  null (wait)
    ├── !auth + !authRoute  →  '/login'
    └── auth + authRoute    →  '/'

Routes:
    /              →  HomeScreen          (event list with search/filter)
    /login         →  LoginScreen
    /register      →  RegisterScreen
    /events/:id    →  EventDetailScreen   (funding, tickets, register, pledge)
    /events/create →  CreateEventScreen   (organizer/admin only)
    /venues        →  VenueListScreen     (organizer only)
    /venues/create →  CreateVenueScreen   (organizer only)
    /profile       →  ProfileScreen       (role-based links, sign out)
    /admin         →  AdminDashboardScreen (admin only: stats, approvals, users)
```

- **Auth guard:** The `redirect` function runs on every navigation. Unauthenticated users are always sent to `/login`. Authenticated users on `/login` or `/register` are sent to `/`.
- **Role-based UI:** Screens conditionally show/hide features based on `auth.user.role`. The FAB for "New Event" only appears for organizers/admins. Admin nav icon only appears for admins.

---

## 6. Screen-by-Screen Flow

### LoginScreen (`/login`)

```
User enters email + password
    ↓  Form validation (email format, non-empty password)
    ↓  AuthProvider.signIn()
    ↓  On success: GoRouter redirects to /
    ↓  On error: error message shown in red banner
    ↓  Link to /register
```

### RegisterScreen (`/register`)

```
User selects role (Customer card / Organizer card)
    ↓  Enters name (optional), email, password
    ↓  Form validation (email, password ≥ 6 chars)
    ↓  AuthProvider.signUp(email, password, role, displayName)
    ↓  On success: GoRouter redirects to /
    ↓  On error: error message shown
    ↓  Link to /login
```

### HomeScreen (`/`)

```
initState  →  EventProvider.loadEvents()
    ↓  GET /api/v1/events
    ↓
UI:
    ├── AppBar:  role-based nav icons (Admin, Venues, Profile)
    ├── Search bar + status filter dropdown + Filter button
    │   ↓  _applyFilters()  →  EventProvider.loadEvents(filters)
    ├── Event list (EventCard widgets)
    │   ↓  Card shows: title, status badge, date, venue, capacity, funding progress
    │   ↓  onTap  →  context.go('/events/${event.id}')
    ├── Empty state: "No events found"
    ├── Error state: error message + Retry button
    └── FAB "New Event" (organizer/admin only)  →  /events/create
```

### EventDetailScreen (`/events/:id`)

```
initState  →  EventProvider.loadEvent(id)  +  _loadExtra()
    ↓  GET /api/v1/events/{id}
    ↓  GET /api/v1/events/{id}/funding
    ↓  GET /api/v1/events/{id}/ticket-tiers
    ↓
UI:
    ├── Title + status chip
    ├── Description
    ├── Info rows: date/time, venue + address, capacity, registration type
    ├── Funding progress card (if funding goal):
    │   └── Amount raised / goal, progress bar, % funded, pledge count
    ├── Ticket tiers list (name + price)
    ├── Discounts info (common %, pledge %)
    └── Customer actions (if role = customer):
        ├── "Register for Event" button  →  POST /api/v1/events/{id}/register
        └── "Make a Pledge" button  →  dialog with amount input  →  POST /api/v1/events/{id}/pledge
```

### CreateEventScreen (`/events/create`)

```
initState  →  ApiService.getVenues()  →  populate venue dropdown
    ↓
Form:
    ├── Title, Description
    ├── Venue dropdown (organizer's venues)
    ├── Start/End time pickers (date + time)
    ├── Max capacity, Registration type (open/closed)
    ├── Funding section (optional): goal ($), min pledge ($)
    └── Submit  →  EventProvider.createEvent(data)
        ↓  POST /api/v1/events
        ↓  On success: navigate to /
```

### VenueListScreen (`/venues`)

```
initState  →  ApiService.getVenues()
    ↓
UI:
    ├── List of venue cards (name, address, capacity)
    │   └── Delete button  →  ApiService.deleteVenue(id)  →  reload
    ├── Empty state: "No venues yet"
    └── FAB "Add Venue"  →  /venues/create
```

### CreateVenueScreen (`/venues/create`)

```
Form:
    ├── Name, Address, City, Province
    ├── Max capacity
    ├── Lat/Lng (optional)
    └── Submit  →  ApiService.createVenue(data)
        ↓  POST /api/v1/venues
        ↓  On success: navigate to /venues
```

### ProfileScreen (`/profile`)

```
UI:
    ├── Avatar (first letter of name), display name, email
    ├── Role chip (ADMIN / ORGANIZER / CUSTOMER)
    ├── Quick links (role-based):
    │   ├── Customer: My Pledges, My Tickets
    │   ├── Organizer: My Events (→ /), My Venues (→ /venues)
    │   └── Admin: Admin Dashboard (→ /admin)
    └── Sign Out  →  AuthProvider.signOut()  →  /login
```

### AdminDashboardScreen (`/admin`)

```
initState  →  loads in parallel:
    ├── ApiService.adminGetStats()        →  GET /api/v1/admin/stats
    ├── ApiService.adminGetUsers()        →  GET /api/v1/admin/users
    └── ApiService.adminGetEvents(pending) →  GET /api/v1/admin/events?status=pending_approval
    ↓
3-tab layout:
    ├── Overview tab: stat cards (total users, total events, pending approvals, total pledged)
    ├── Approvals tab: list of pending events with Approve ✓ / Reject ✗ buttons
    │   ↓  POST /api/v1/admin/events/{id}/approve  { approved: true/false }
    └── Users tab: list of all users (avatar, name, email, role chip)
```

---

## 7. Data Models (Dart)

All models live in `lib/models/` and have `fromJson()` factories for API response parsing.

| Model | Fields | Helpers |
|-------|--------|---------|
| `AppUser` | id, firebaseUid, email, displayName, role, createdAt | `isAdmin`, `isOrganizer`, `isCustomer` |
| `Event` | id, organizerId, venueId, title, description, startTime, endTime, lat, lng, fundingGoalCents, fundingEndAt, minPledgeCents, status, registrationType, maxCapacity, commonDiscountPercent, pledgeDiscountPercent, totalPledgedCents, fundingDaysLeft, venue, createdAt | `fundingProgress`, `fundingGoalFormatted`, `totalPledgedFormatted`, `isFunding` |
| `Venue` | id, organizerId, name, address, city, province, lat, lng, maxCapacity, createdAt | `fullAddress` |
| `TicketTier` | id, eventId, name, priceCents, displayOrder | `priceFormatted` |
| `TicketSale` | id, eventId, userId, ticketTierId, ticketCode, amountPaidCents, discountAppliedCents, extraPerks, status, scannedAt, createdAt | `amountPaidFormatted`, `isScanned` |
| `Pledge` | id, eventId, userId, amountCents, status, createdAt, eventTitle | `amountFormatted` |
| `FundingSummary` | goalCents, totalPledgedCents, pledgeCount, fundingEndAt | `progress`, `goalFormatted`, `totalPledgedFormatted` |

All monetary values are in **cents** (matching the backend). Formatted helpers divide by 100 for display.

---

## 8. Folder Structure

```
FrontEnd/
├── lib/
│   ├── main.dart              # App entry: Firebase init, providers, MaterialApp.router
│   ├── config/
│   │   ├── api_config.dart    # API base URL (from .env)
│   │   ├── theme.dart         # Material 3 theme, colors, Google Fonts
│   │   └── router.dart        # GoRouter: routes, auth redirect, role-based nav
│   ├── models/
│   │   ├── user.dart          # AppUser, UserRole enum
│   │   ├── event.dart         # Event, EventStatus, RegistrationType
│   │   ├── venue.dart         # Venue
│   │   ├── ticket.dart        # TicketTier, TicketSale
│   │   └── funding.dart       # Pledge, FundingSummary, PledgeStatus
│   ├── services/
│   │   └── api_service.dart   # Dio client + Firebase auth interceptor + all API methods
│   ├── providers/
│   │   ├── auth_provider.dart  # Auth state, sign in/up/out, Firebase listener
│   │   └── event_provider.dart # Event list/detail, create/submit/cancel
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── event/
│   │   │   ├── event_detail_screen.dart
│   │   │   └── create_event_screen.dart
│   │   ├── venue/
│   │   │   ├── venue_list_screen.dart
│   │   │   └── create_venue_screen.dart
│   │   ├── profile/
│   │   │   └── profile_screen.dart
│   │   └── admin/
│   │       └── admin_dashboard_screen.dart
│   └── widgets/
│       └── event_card.dart    # Reusable card: title, status, date, venue, funding bar
├── .env                       # Firebase config + API_BASE_URL (gitignored)
├── pubspec.yaml               # Dependencies + .env asset
├── web/                       # Flutter web entry (index.html)
└── test/
    └── widget_test.dart
```

---

## 9. Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Email/password sign-in/up, ID token management |
| `dio` | HTTP client with interceptors (auto-attaches Bearer token) |
| `provider` | State management (ChangeNotifierProvider) |
| `go_router` | Declarative routing with auth redirects |
| `flutter_dotenv` | Load `.env` file for config |
| `google_fonts` | Inter font family for modern UI |
| `intl` | Date formatting (MMM d, y • h:mm a) |
| `qr_flutter` | QR code rendering for ticket codes |
| `flutter_secure_storage` | Secure local storage (for future use) |
| `shared_preferences` | Simple key-value persistence |

---

## 10. Role-Based UI Visibility

| UI Element | Customer | Organizer | Admin |
|------------|----------|-----------|-------|
| Event list (browse) | ✓ | ✓ | ✓ |
| Event detail | ✓ | ✓ | ✓ |
| Register / Pledge buttons | ✓ | ✗ | ✗ |
| "New Event" FAB | ✗ | ✓ | ✓ |
| Venues nav icon | ✗ | ✓ | ✗ |
| Admin nav icon | ✗ | ✗ | ✓ |
| My Pledges / My Tickets | ✓ | ✗ | ✗ |
| My Events / My Venues | ✗ | ✓ | ✗ |
| Admin Dashboard link | ✗ | ✗ | ✓ |

---

## 11. Environment Setup

1. **Flutter SDK:** Installed at `/home/shafkat/development/flutter` (added to PATH in `.bashrc`).
2. **Chrome:** Uses Windows Chrome via WSL2: `CHROME_EXECUTABLE="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"`.
3. **`.env` file** in `FrontEnd/` root:
   ```env
   FIREBASE_API_KEY=...
   FIREBASE_AUTH_DOMAIN=crowd-funding-event.firebaseapp.com
   FIREBASE_PROJECT_ID=crowd-funding-event
   FIREBASE_STORAGE_BUCKET=crowd-funding-event.firebasestorage.app
   FIREBASE_MESSAGING_SENDER_ID=...
   FIREBASE_APP_ID=...
   FIREBASE_MEASUREMENT_ID=...
   API_BASE_URL=http://localhost:8000
   ```
4. **Run:**
   ```bash
   cd FrontEnd
   flutter run -d chrome
   ```
5. **Build for production:**
   ```bash
   flutter build web
   ```
   Output in `build/web/` — deploy to any static hosting.

---

## 12. Short Summary

- **Startup:** `.env` → Firebase init → Providers → GoRouter → MaterialApp.
- **Auth:** Firebase handles sign-in/sign-up and stores credentials in browser. `AuthProvider` listens to auth state changes, syncs with backend via `POST /auth/verify`, and loads `AppUser` from `GET /me`. Dio interceptor auto-attaches fresh Bearer token to every API call.
- **Routing:** GoRouter with auth redirect — unauthenticated users go to `/login`, authenticated users on auth pages go to `/`. Screens show/hide features based on `user.role`.
- **State:** Provider pattern — `AuthProvider` for auth, `EventProvider` for events. Screens use `context.watch<T>()` to rebuild on changes and `context.read<T>()` for one-time access.
- **API:** All calls go through `ApiService` (Dio). Auth interceptor handles token refresh. Backend is at `API_BASE_URL/api/v1/...`.
- **Data:** Dart models with `fromJson()` match backend response shapes. Monetary values in cents, formatted with `$` helpers.
- **Platform:** Flutter Web (Chrome via WSL2). Same codebase can later target iOS/Android with minimal changes.
