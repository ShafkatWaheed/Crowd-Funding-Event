# Add SSLCommerz Payment Gateway (Bangladesh)

## Context

The project already has a clean `PaymentGateway` ABC with `MockPaymentGateway` (fully working) and `StripePaymentGateway` (stub). The goal is to add **SSLCommerz** as a third gateway for the Bangladesh market (BDT only). SSLCommerz uses a **redirect-based** flow (server creates session → customer redirected to SSLCommerz page → IPN confirms payment), which differs from the current immediate `charge() → ChargeResult` pattern.

The design must be **backward-compatible** — Mock and Stripe continue working unchanged.

---

## Architecture: Two-Phase Payment

`ChargeResult` gains a new status `"pending_redirect"` alongside existing `"completed"` / `"failed"`. Immediate gateways (Mock/Stripe) return `"completed"` as before. SSLCommerz returns `"pending_redirect"` with a `redirect_url`. A `PendingPayment` table tracks the async state. When SSLCommerz sends an IPN callback, `confirm_charge()` validates and completes the business record.

```
Immediate (Mock/Stripe):  charge() → completed → done
Redirect  (SSLCommerz):   charge() → pending_redirect → IPN → confirm_charge() → completed
```

---

## Files Overview

| File | Action | Description |
|------|--------|-------------|
| `Backend/app/services/payment_gateway.py` | Modify | Extend `ChargeResult`, add `confirm_charge()` to ABC, update factory |
| `Backend/app/models/pending_payment.py` | **New** | `PendingPayment` model (tracks redirect payment lifecycle) |
| `Backend/app/services/sslcommerz_gateway.py` | **New** | `SSLCommerzPaymentGateway` class (charge, confirm, refund) |
| `Backend/app/services/payment_completion.py` | **New** | Completes business records (ticket/pledge/sponsor) after IPN |
| `Backend/app/api/v1/sslcommerz.py` | **New** | IPN endpoint, success/fail/cancel redirects, status poll |
| `Backend/app/api/v1/router.py` | Modify | Register sslcommerz router |
| `Backend/app/models/ticket.py` | Modify | Add `payment_pending` to `TicketSaleStatus` enum |
| `Backend/app/models/funding.py` | Modify | Add `payment_pending` to `FundingStatus` enum |
| `Backend/app/models/sponsor.py` | Modify | Add `payment_pending` to `PaymentStatus` enum |
| `Backend/app/services/ticket/sales.py` | Modify | Handle `pending_redirect` in `purchase_ticket()` |
| `Backend/app/services/funding/pledges.py` | Modify | Handle `pending_redirect` in `create_pledge()` |
| `Backend/app/services/sponsor/payments.py` | Modify | Handle `pending_redirect` in `pay_bid()` |
| `Backend/app/services/platform_settings.py` | Modify | Add SSLCommerz settings to DEFAULTS/DESCRIPTIONS |
| `Backend/app/worker/tasks.py` | Modify | Add `expire_pending_payments` cron task |
| `Backend/alembic/versions/zz04_sslcommerz.py` | **New** | Migration: pending_payments table + enum values |
| `FrontEnd/lib/screens/payment/sslcommerz_webview_screen.dart` | **New** | WebView screen for SSLCommerz redirect |
| `FrontEnd/lib/services/api_service.dart` | Modify | Add `getPendingPaymentStatus()` |
| `FrontEnd/lib/screens/event/event_detail/ticket_tiers_section.dart` | Modify | Handle redirect response → open WebView |
| `FrontEnd/lib/providers/config_provider.dart` | Modify | Add `sslcommerzEnabled` flag |
| `FrontEnd/pubspec.yaml` | Modify | Add `webview_flutter` dependency |

---

## Backend Changes

### 1. Extend `ChargeResult` — `payment_gateway.py`

Add two optional fields (no existing code breaks):

```python
@dataclass
class ChargeResult:
    transaction_id: str
    status: str                          # "completed" | "failed" | "pending_redirect"
    authorization_code: str
    receipt_reference: str | None = None
    redirect_url: str | None = None      # SSLCommerz GatewayPageURL
    pending_payment_id: int | None = None
```

### 2. Add `confirm_charge()` to ABC — `payment_gateway.py`

Non-abstract method with default `NotImplementedError`. Only SSLCommerz overrides it.

```python
async def confirm_charge(self, db, *, tran_id: str, validation_data: dict) -> ChargeResult:
    raise NotImplementedError("This gateway does not support redirect confirmation")
```

### 3. Update factory — `payment_gateway.py`

```python
async def get_gateway(db) -> PaymentGateway:
    sslcommerz_on = await settings_svc.get_bool(db, "sslcommerz_enabled")
    if sslcommerz_on:
        from app.services.sslcommerz_gateway import SSLCommerzPaymentGateway
        return SSLCommerzPaymentGateway()
    stripe_on = await settings_svc.get_bool(db, "stripe_enabled")
    if stripe_on:
        return StripePaymentGateway()
    return MockPaymentGateway()
```

### 4. `PendingPayment` model — `models/pending_payment.py`

Tracks the lifecycle of a redirect-based payment between session creation and IPN confirmation.

Key columns:
- `tran_id` (unique) — sent to SSLCommerz, used to correlate IPN
- `payment_type` — `"ticket"` / `"pledge"` / `"sponsor"`
- `status` — `initiated` → `completed` / `failed` / `cancelled` / `expired`
- `user_id`, `event_id` — who and what
- Context fields for completing the business record: `ticket_tier_id`, `quantity`, `bid_id`, `reserved_spots`, `tier_reservations_json`, `commission_cents`
- SSLCommerz fields: `val_id`, `bank_tran_id` (needed for refunds), `session_key`
- `expires_at` — auto-expire after 30 min

### 5. `SSLCommerzPaymentGateway` — `services/sslcommerz_gateway.py`

**`charge()`**:
1. Create `PendingPayment` record with status `initiated`
2. POST to SSLCommerz `gwprocess/v4/api.php` with store credentials, amount, tran_id, callback URLs, customer info
3. Return `ChargeResult(status="pending_redirect", redirect_url=GatewayPageURL)`

**`confirm_charge()`** (called by IPN endpoint):
1. Look up `PendingPayment` by `tran_id`
2. Call SSLCommerz validation API with `val_id`
3. If `VALID`: mark pending as `completed`, record ledger entries, return completed `ChargeResult`
4. If invalid: mark pending as `failed`

**`refund()`**:
1. Look up `PendingPayment` to get `bank_tran_id`
2. Call SSLCommerz refund API with `bank_tran_id`, `refund_amount`, `refund_remarks`
3. Return `RefundResult`

**`transfer()`, `hold()`, `release_hold()`**: raise `NotImplementedError` — SSLCommerz is payment collection only. Escrow uses internal ledger.

Uses `httpx.AsyncClient` for HTTP calls to SSLCommerz.

### 6. `PaymentCompletionService` — `services/payment_completion.py`

Called after `confirm_charge()` succeeds. Updates business records based on `payment_type`:

- **ticket**: Update `TicketSale` records from `payment_pending` → `purchased`, set `gateway_auth_code`, run post-purchase effects (escrow, notifications)
- **pledge**: Update `Funding` from `payment_pending` → `pledged`, run milestone checks
- **sponsor**: Update `SponsorPayment` from `payment_pending` → `completed`, mark bid as `paid`, ensure sponsor ticket

### 7. SSLCommerz API routes — `api/v1/sslcommerz.py`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/webhooks/sslcommerz` | POST | IPN handler — validates + completes payment |
| `/sslcommerz/success` | POST | Customer redirect — also validates as safety net, returns HTML with app deep link |
| `/sslcommerz/fail` | POST | Customer redirect — marks payment failed |
| `/sslcommerz/cancel` | POST | Customer redirect — marks payment cancelled |
| `/pending-payments/{id}/status` | GET | Frontend polls this to check completion (auth required) |

IPN is the **authoritative** confirmation. Success redirect also validates as safety net (IPN may be delayed). Both are idempotent.

### 8. Consumer modifications — `ticket/sales.py`, `funding/pledges.py`, `sponsor/payments.py`

Pattern (using ticket as example, lines 129-151 in `sales.py`):

```python
result = await gw.charge(db, user_id=user.id, amount_cents=total_charge, ...)

if result.status == "failed":
    raise ConflictError(...)
if result.status == "pending_redirect":
    ticket_status = TicketSaleStatus.payment_pending
    gateway_txn_id = result.transaction_id
    gateway_auth = None
    # Still create TicketSale records (with payment_pending status)
    # Return redirect info to caller
```

API endpoint response wraps the result:
```python
return {
    "payment_type": "redirect" | "immediate",
    "redirect_url": str | None,
    "pending_payment_id": int | None,
    "tickets": [...],  # empty list for redirect, normal list for immediate
}
```

Same pattern for pledge and sponsor endpoints.

### 9. Platform settings — `platform_settings.py`

Add to `DEFAULTS`:
```python
"sslcommerz_enabled": "false",
"sslcommerz_store_id": "",
"sslcommerz_store_passwd": "",
"sslcommerz_sandbox": "true",
"sslcommerz_server_base_url": "",
"pending_payment_expiry_minutes": "30",
```

### 10. Expiry cron — `worker/tasks.py`

`expire_pending_payments()` runs every 5 minutes, marks stale `initiated` payments as `expired`, and fails the associated business records.

### 11. Migration — `alembic/versions/zz04_sslcommerz.py`

- Create `pending_payments` table with indexes on `tran_id` (unique), `(user_id, status)`, `(status, expires_at)`
- `ALTER TYPE ticketsalestatus ADD VALUE 'payment_pending'`
- `ALTER TYPE fundingstatus ADD VALUE 'payment_pending'`
- `ALTER TYPE paymentstatus ADD VALUE 'payment_pending'`

---

## Frontend Changes

### 1. `webview_flutter` dependency — `pubspec.yaml`

```yaml
webview_flutter: ^4.10.0
```

### 2. SSLCommerz WebView screen — `screens/payment/sslcommerz_webview_screen.dart`

- Loads SSLCommerz `GatewayPageURL` in a WebView
- Intercepts navigation to success/fail/cancel URLs → closes WebView
- Polls `/pending-payments/{id}/status` every 3 seconds as backup
- Callbacks: `onSuccess`, `onFailure`, `onCancel`

### 3. API service — `api_service.dart`

Add `getPendingPaymentStatus(int pendingPaymentId)` — GET `/pending-payments/{id}/status`.

### 4. Purchase flow adaptation — `ticket_tiers_section.dart`

After calling `purchaseTickets()`, check response:
- If `payment_type == "redirect"`: push `SSLCommerzWebViewScreen` with `redirect_url` + `pending_payment_id`
- If `payment_type == "immediate"`: handle as before (show receipt)

Same pattern for pledge and sponsor payment screens.

### 5. ConfigProvider — `config_provider.dart`

Add `bool sslcommerzEnabled = false`, read from public config.

---

## SSLCommerz Payment Flow

```
Customer → App → POST /purchase-ticket → charge() → SSLCommerz session API
                                                    ↓
Customer ← App ← { redirect_url, pending_id }   GatewayPageURL
                                                    ↓
Customer → WebView → SSLCommerz payment page → pays
                                                    ↓
                     IPN POST → /webhooks/sslcommerz → confirm_charge() → validation API
                                                    ↓ VALID
                     complete_pending_payment() → TicketSale: payment_pending → purchased
                                                    ↓
Customer ← WebView detects success redirect / polls status → "Payment successful!"
```

---

## Implementation Order

1. **Core infra** (no consumer changes): `ChargeResult` fields, `confirm_charge()` on ABC, `PendingPayment` model, migration, platform settings
2. **SSLCommerz gateway**: `sslcommerz_gateway.py` (charge, confirm, refund)
3. **Completion service**: `payment_completion.py`
4. **API routes**: `sslcommerz.py` (IPN, redirects, status poll), register in router
5. **Consumer adaptation**: Modify `purchase_ticket()`, `create_pledge()`, `pay_bid()` + their API endpoints
6. **Frontend**: WebView screen, API service method, purchase flow changes
7. **Housekeeping**: Expiry cron task, add `sslcommerz_enabled` to public config

---

## Verification

1. **Mock gateway unaffected**: With `sslcommerz_enabled=false`, all existing flows work identically
2. **SSLCommerz sandbox**: Enable `sslcommerz_enabled=true` + `sslcommerz_sandbox=true`, use test credentials
3. **Ticket purchase redirect**: POST purchase → get redirect URL → open in WebView → pay on SSLCommerz sandbox → IPN fires → ticket status becomes `purchased`
4. **Pledge + sponsor**: Same flow with respective endpoints
5. **Refund**: Request refund on SSLCommerz-paid ticket → worker calls SSLCommerz refund API
6. **Expiry**: Create a pending payment, wait 30+ min, verify cron marks it expired
7. **Idempotency**: Double-submit same purchase → same `PendingPayment` returned
8. `dart analyze FrontEnd/lib/` → no issues
9. `alembic upgrade head` → migration applies cleanly
