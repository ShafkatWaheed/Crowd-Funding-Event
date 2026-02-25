# Dark Mode

## Initiator

- **Who:** User (toggle in Profile). System (restore saved preference on launch).
- **When:** Profile screen → theme toggle; app launch (SharedPreferences).

## Frontend flow

- **Screen/Widget:** Profile screen (theme switch: light/dark). All screens use AppTheme context-aware helpers (cardOf, textPrimaryOf, surfaceOf, etc.) so dark mode applies everywhere. QR code on receipt forced to white background.
- **User action:** Toggle dark mode; preference persisted. No API call for theme (local only).
- **API calls:** None. Theme is frontend-only (ThemeProvider, SharedPreferences).

## Backend routing

- N/A (no backend).

## Service layer

- N/A. Frontend: ThemeProvider (e.g. ChangeNotifier or Provider), AppTheme class with dark palette (_dkSurface, _dkCard, _dkTextPrimary, ...) and helpers. SharedPreferences key for theme (e.g. isDark).

## Models and DB

- None.

## Dependencies

- **Requires:** None. Independent feature.
- **Triggers / side effects:** None. All screens and components that use AppTheme automatically respect dark mode.

## Flow diagram

```mermaid
flowchart LR
  subgraph pipeline [Pipeline]
    A[User]
    B[Settings Theme]
    C[local storage]
    D[AppTheme provider]
    E[theme state]
    F[preference]
  end
  A --> B --> C --> D --> E --> F
```

## Vulnerabilities

- None (UI only). Ensure no hardcoded light colors in critical components; use theme helpers so dark mode is consistent. Contrast (e.g. near-black chips) handled by swapping to accentColor in dark mode.

## Improvements

- Document palette tokens and usage (e.g. when to use cardOf vs surfaceOf) for new screens. Test all screens in both modes (list in FEATURES).
- Optional: system theme detection (follow device) with override in Profile.

## Feedback

- Full coverage per FEATURES (Home, Explore, Manage, Profile, Event Detail, Ticket Sales, Receipts, etc.). Single source of truth: AppTheme + ThemeProvider.
