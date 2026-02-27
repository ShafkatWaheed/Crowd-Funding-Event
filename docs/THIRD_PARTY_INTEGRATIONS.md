# Third-Party Integrations

This document lists **every place in the app that requires (or is stubbed for) third-party integration** — similar to KYC (Stripe Identity). Use it for onboarding, compliance, and planning external service setup.

---

## 1. KYC / Identity Verification

| What | Where | Third party | Status |
|------|--------|-------------|--------|
| KYC verification | `Backend/app/services/kyc_verification.py` | **Stripe Identity** (stub) | Stub only: `StripeIdentityKycService` raises `NotImplementedError("Stripe Identity not yet integrated")`. Production uses `MockKycVerificationService` when `kyc_mock_enabled` is true. |
| Config / feature flag | `platform_settings`: `kyc_mock_enabled` | — | When `false`, code path would use Stripe Identity (once implemented). |

**Config:** No env vars yet for Stripe Identity; add when integrating.

---

## 2. Authentication (Firebase)

| What | Where | Third party | Status |
|------|--------|-------------|--------|
| ID token verification | `Backend/app/core/firebase.py` | **Firebase Auth** | Active: `firebase_admin.verify_id_token()`. |
| Auth dependency | `Backend/app/core/security.py` | Firebase | Uses `verify_id_token()` for every protected request. |
| Auth API | `Backend/app/api/v1/auth.py` | Firebase | POST `/auth/verify` uses Firebase token. |
| Auth service | `Backend/app/services/auth.py` | Firebase | `verify_and_upsert_user()` calls `verify_id_token()`. |
| Chat WebSocket | `Backend/app/api/v1/chat.py` | Firebase | WebSocket auth uses `verify_id_token(token)`. |

**Config (env):** `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` (path to service account JSON).

---

## 3. Push Notifications (FCM)

| What | Where | Third party | Status |
|------|--------|-------------|--------|
| Send push | `Backend/app/services/push_notification.py` | **Firebase Cloud Messaging (FCM)** | Active: `firebase_admin.messaging` to send to device tokens. |
| ARQ tasks | `Backend/app/worker/tasks.py` | FCM | `send_push_to_user`, `send_push_bulk` call push service. |
| Chat offline notify | `Backend/app/api/v1/chat.py` | FCM | Sends FCM when chat recipient is offline. |
| Device tokens | `Backend/app/api/v1/notifications.py` | — | Stores FCM tokens; sending is via FCM. |

**Config:** Same Firebase app as auth (`FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS`). Toggle: platform setting `push_notifications_enabled`.

---

## 4. Email (SendGrid)

| What | Where | Third party | Status |
|------|--------|-------------|--------|
| Send email | `Backend/app/services/email_service.py` | **SendGrid** (v3 API) | Active: `SendGridAPIClient(api_key=settings.EMAIL_API_KEY)`, `Mail` / `send()`. |
| Email notifications | `Backend/app/services/email_notifications.py` | SendGrid | Uses email_service (which uses SendGrid when provider is sendgrid). |

**Config (env):** `EMAIL_ENABLED`, `EMAIL_PROVIDER` (e.g. `sendgrid`), `EMAIL_API_KEY`, `EMAIL_FROM_ADDRESS`, `EMAIL_FROM_NAME`. Alternative: `EMAIL_PROVIDER=console` (no third party).

---

## 5. Payments & Disputes (Stripe)

| What | Where | Third party | Status |
|------|--------|-------------|--------|
| Webhook: disputes | `Backend/app/api/v1/webhooks.py` | **Stripe** | Active: `stripe.Webhook.construct_event(body, signature, secret)` for POST `/webhooks/stripe`; creates/updates `Dispute` from Stripe events. |
| Payment gateway | `Backend/app/services/payment_gateway.py` | **Stripe** (stub) | `StripePaymentGateway` is a stub (all methods raise `NotImplementedError("Stripe integration not yet implemented")`). Production currently uses `MockPaymentGateway` when `payment_mock_enabled` is true. |

**Config:** No Stripe env in `config.py`; webhook secret is in DB. Platform setting: `stripe_webhook_secret` (from DB via `settings_svc.get_str(db, "stripe_webhook_secret")`) for webhook signature verification.

---

## 6. Database (PostgreSQL)

| What | Where | Third party | Status |
|------|--------|-------------|--------|
| Primary DB | `Backend/app/config.py`, `Backend/app/db/base.py` | **PostgreSQL** (asyncpg) | Active for all persistence. |
| Replica | `DATABASE_REPLICA_URL` | PostgreSQL | Optional read replica. |

**Config (env):** `DATABASE_URL`, `DATABASE_REPLICA_URL`, optionally `TEST_DATABASE_URL`.

---

## 7. Redis (Queue, Cache, Chat)

| What | Where | Third party | Status |
|------|--------|-------------|--------|
| ARQ worker pool | `Backend/app/worker/redis_pool.py`, `Backend/app/worker/main.py` | **Redis** | Job queue. |
| Cache | `Backend/app/cache.py` | Redis | Cache-aside; degrades if Redis down. |
| Chat streams / PubSub | `Backend/app/services/chat_service.py`, `Backend/app/api/v1/chat.py` | Redis | Redis Streams + Pub/Sub for real-time chat. |

**Config (env):** `REDIS_URL`.

---

## Summary Table

| # | Area | Third party | Required config | Implemented? |
|---|------|-------------|-----------------|--------------|
| 1 | **KYC** | Stripe Identity | (future API key / config) | No — stub only; mock used. |
| 2 | **Auth** | Firebase | `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` | Yes. |
| 3 | **Push** | FCM (Firebase) | Same as Firebase | Yes. |
| 4 | **Email** | SendGrid | `EMAIL_API_KEY`, `EMAIL_PROVIDER`, etc. | Yes (or `console` for no third party). |
| 5 | **Disputes** | Stripe webhooks | `stripe_webhook_secret` (DB) | Yes. |
| 6 | **Payments** | Stripe (charges/refunds) | (future Stripe keys) | No — stub only; mock used. |
| 7 | **Database** | PostgreSQL | `DATABASE_URL` (and optional replica) | Yes. |
| 8 | **Queue/Cache/Chat** | Redis | `REDIS_URL` | Yes. |

**File storage:** Uploads (KYC, events, prerequisites, schedule) go to local `static/uploads/` (and chat archives under `static/archives/chat`). There is **no** third-party object storage (e.g. S3) in the codebase.

---

## Stubbed (Future Integration)

- **KYC:** Stripe Identity — implement `StripeIdentityKycService` in `Backend/app/services/kyc_verification.py` and add env/DB config.
- **Payments:** Stripe — implement `StripePaymentGateway` in `Backend/app/services/payment_gateway.py` and configure Stripe API keys and webhook secret.
