# Gap Analysis: feature_imp vs Application

This document compares the **feature_imp** documentation (intended scope and status) against the **actual codebase** to find gaps: features documented but missing, partially implemented, or misclassified (e.g. "planned" when implemented).

**Scope:** Backend (`Backend/app`), Frontend (`FrontEnd/lib`), and `feature_imp/*.md` index + selected feature docs.

---

## 1. Index / README Gaps

### 1.1 Feature 70 (Sponsor Negotiation Chat) — Not in index

- **feature_imp:** `70-sponsor-negotiation-chat.md` exists and describes WebSocket chat, Redis Streams, REST messages, FCM for offline.
- **README.md:** The main index table lists features 1–69 only. **Feature 70 is not listed** in the "Index of features" table.
- **Code:** Implemented — `Backend/app/api/v1/chat.py`, `Backend/app/services/chat_service.py`, router mount, Redis Streams/PubSub, FCM for offline.

**Gap:** Add a row for feature 70 in `feature_imp/README.md` (e.g. "70 | 70-sponsor-negotiation-chat.md | Sponsor-Organizer Negotiation Chat").

---

### 1.2 Feature 52 (KYC/AML) — Misclassified as "Planned"

- **README.md:** Lists 52 under "Planned (not yet implemented)".
- **Reality:** KYC is **implemented** end-to-end:
  - Backend: `kyc_verification.py` (mock + Stripe stub), `kyc_document` model, upload/submit/admin-verify, `require_kyc()` gate.
  - Frontend: KYC section, required banner, admin KYC tab, settings toggles.
  - Only **Stripe Identity** (third-party verification) is not integrated; mock and admin review are live.

**Gap:** Move 52 from "Planned" to the main index with a note that production KYC uses mock/admin review until Stripe Identity is integrated, or add a subsection "Implemented with mock; third-party (Stripe Identity) pending."

---

## 2. Implementation Gaps (Doc Exists, Code Missing or Partial)

### 2.1 Feature 56 — Mobile Platform (iOS & Android)

- **feature_imp:** `56-mobile-platform-ios-android.md` describes adding `android/` and `ios/` platforms, guarding `usePathUrlStrategy()` with `kIsWeb`, Firebase mobile config, permissions.
- **Code:** No `FrontEnd/android/` or `FrontEnd/ios/` directories present. Flutter app is effectively web-only from a platform perspective.

**Gap:** Mobile platform setup is **not implemented**. To close: run `flutter create . --platforms android,ios`, add `kIsWeb` guard in `main.dart`, configure Firebase and permissions per doc.

---

### 2.2 All other checked features — Implemented

Spot-checks against docs found **no** other "documented but missing" features among:

- **17 Customer Loyalty:** `OrganizerCustomerHistory`, `list_organizer_customers`, GET `/me/customers`, CustomerHistoryScreen with "Loyal" badge (2+ events).
- **18 Organizer Trust Score:** `get_organizer_trust_score`, escrow bonus, shown on profile and event.
- **25 Sharing & Calendar:** Share sheet (Gmail, WhatsApp, Copy, More), calendar sheet (Google Calendar, .ics), GET `/{event_id}/calendar.ics`, ticket share.
- **30 Dark Mode:** ThemeProvider, dark/light/system, toggle in profile.
- **44 Backend Scaling:** Rate limits, `/healthz` and `/health`, DB pool, `pg_advisory_xact_lock` in purchase_ticket and create_pledge.
- **45 Parking & Transport:** All four fields (parking, transit, rideshare, accessibility) + directions_url in backend and frontend; "Getting There" card with icon rows.
- **64 Cache Key Hardening:** `safe_cache_key()` in `cache.py`, used by dashboard and platform_settings.

---

## 3. Doc-Only or Code-Only Items

- **feature_imp:** No feature doc was found for "third-party integrations" or "logging" beyond 69; 69 (structured logging) is in the index and implemented.
- **Code:** Chat (70) is implemented and has a doc but is missing from the README index (see 1.1). No other major code areas were found that lack a corresponding feature_imp doc.

---

## 4. Summary Table

| Gap type | Item | Action |
|----------|------|--------|
| Index missing | Feature 70 (Sponsor Chat) | Add row to feature_imp/README.md index table. |
| Misclassified | Feature 52 (KYC) | Move from "Planned" to main index; optionally note "Stripe Identity pending". |
| Not implemented | Feature 56 (Mobile iOS/Android) | Implement per 56-mobile-platform-ios-android.md (platforms, kIsWeb, Firebase, permissions) or keep as planned. |

---

## 5. Recommendations

1. **Update feature_imp/README.md:** Add feature 70 to the index; reclassify feature 52 (implemented with mock, third-party pending).
2. **Feature 56:** Either implement mobile platforms when needed or keep 56 in "Planned" and ensure README clearly states "Mobile (iOS/Android) — not yet implemented."
3. **Ongoing:** When adding a new feature doc (e.g. 71+), add a corresponding row to the README index and, if it has a "planned" vs "implemented" status, place it in the correct section.
