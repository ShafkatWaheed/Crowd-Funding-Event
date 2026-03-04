"""
Banking & financial APIs: payment info, bank accounts, escrow overview,
mock ledger, email templates, disputes, reconciliation, tax, payouts.
"""
from datetime import date, datetime, timedelta, timezone

import uuid
from pathlib import Path

from fastapi import APIRouter, Body, Depends, File, Query, Request, UploadFile
from pydantic import BaseModel, field_validator

from app.logger import get_logger, log_step

logger = get_logger("api.banking")

from app.dependencies import CurrentUser, DbSession, ReadDbSession, require_role
from app.rate_limit import limiter, dynamic_limit
from app.models.dispute import Dispute, DisputeStatus
from app.models.email_template import EmailTemplate
from app.models.escrow import EscrowStatus
from app.models.payment_info import OrganizerBankAccount, UserPaymentInfo
from app.models.user import User, UserRole
from app.repositories.banking_repo import banking_repo
from app.repositories.email_template_repo import email_template_repo
from app.services import audit as audit_svc
from app.services import banking_service as banking_svc
from app.services import encryption as enc
from app.services import ledger as ledger_svc
from app.services import platform_settings as settings_svc
from fastapi.exceptions import HTTPException

router = APIRouter()


# ═══════════════════════════════════════════
#  Stripe Config (public)
# ═══════════════════════════════════════════

@router.get("/stripe/config")
async def get_stripe_config(db: ReadDbSession):
    """Return Stripe publishable key + enabled status for frontend."""
    stripe_on = await settings_svc.get_bool(db, "stripe_enabled")
    connect_on = await settings_svc.get_bool(db, "stripe_connect_enabled")
    pk = await settings_svc.get_str(db, "stripe_publishable_key") if stripe_on else ""
    return {
        "stripe_enabled": stripe_on,
        "stripe_connect_enabled": connect_on,
        "publishable_key": pk,
    }


# ═══════════════════════════════════════════
#  Stripe Payment Intent (authenticated)
# ═══════════════════════════════════════════

class PaymentIntentRequest(BaseModel):
    amount_cents: int
    description: str
    idempotency_key: str | None = None


@router.post("/payments/create-intent")
@limiter.limit(dynamic_limit("payment_action", "10/minute"))
async def create_payment_intent(
    request: Request,
    body: PaymentIntentRequest,
    db: DbSession,
    current_user: CurrentUser,
):
    """Create a payment intent for the Stripe Payment Sheet."""
    stripe_on = await settings_svc.get_bool(db, "stripe_enabled")
    if not stripe_on:
        raise HTTPException(status_code=400, detail="Stripe is not enabled")

    # Stub — returns error until StripePaymentGateway.create_intent() is implemented
    raise HTTPException(
        status_code=501,
        detail="Stripe PaymentIntent creation not yet implemented. Coming soon.",
    )


# ═══════════════════════════════════════════
#  User Payment Info (all roles)
# ═══════════════════════════════════════════

class PaymentInfoResponse(BaseModel):
    card_holder_name: str | None = None
    card_last_four: str | None = None
    card_brand: str | None = None
    billing_address: str | None = None
    has_payment_method: bool = False


class PaymentInfoUpdate(BaseModel):
    card_holder_name: str | None = None
    card_last_four: str | None = None
    card_brand: str | None = None
    billing_address: str | None = None
    payment_method_token: str | None = None


@router.get("/me/payment-info")
async def get_payment_info(db: ReadDbSession, current_user: CurrentUser):
    stripe_on = await settings_svc.get_bool(db, "stripe_enabled")
    if stripe_on:
        user = await banking_repo.get_user(db, current_user.id)
        return {
            "mode": "stripe",
            "stripe_customer_id": user.stripe_customer_id,
            "stripe_configured": user.stripe_customer_id is not None,
        }
    info = await banking_repo.get_payment_info(db, current_user.id)
    if not info:
        return PaymentInfoResponse()
    return PaymentInfoResponse(
        card_holder_name=info.card_holder_name,
        card_last_four=info.card_last_four,
        card_brand=info.card_brand,
        billing_address=info.billing_address,
        has_payment_method=bool(info.payment_method_token),
    )


@router.put("/me/payment-info", response_model=PaymentInfoResponse)
@limiter.limit(dynamic_limit("payment_action", "10/minute"))
async def update_payment_info(request: Request, body: PaymentInfoUpdate, db: DbSession, current_user: CurrentUser):
    stripe_on = await settings_svc.get_bool(db, "stripe_enabled")
    if stripe_on:
        raise HTTPException(
            status_code=400,
            detail="Payment methods managed by Stripe. Card details are stored securely by Stripe.",
        )
    log_step(logger, "Updating payment info", user_id=current_user.id)
    info = await banking_svc.upsert_payment_info(
        db, current_user.id,
        card_holder_name=body.card_holder_name,
        card_last_four=body.card_last_four,
        card_brand=body.card_brand,
        billing_address=body.billing_address,
        payment_method_token=body.payment_method_token,
    )
    return PaymentInfoResponse(
        card_holder_name=info.card_holder_name,
        card_last_four=info.card_last_four,
        card_brand=info.card_brand,
        billing_address=info.billing_address,
        has_payment_method=bool(info.payment_method_token),
    )


# ═══════════════════════════════════════════
#  Organizer Bank Account (organizer-only)
# ═══════════════════════════════════════════

class BankAccountResponse(BaseModel):
    institution_number: str | None = None
    transit_number: str | None = None
    account_last_four: str | None = None
    account_holder_masked: str | None = None
    verified: bool = False
    verification_status: str = "pending"
    rejection_reason: str | None = None
    payout_schedule: str = "weekly"
    payout_day: int = 1
    min_payout_cents: int = 2500
    has_bank_account: bool = False
    decryption_failed: bool = False


class BankAccountUpdate(BaseModel):
    institution_number: str
    transit_number: str
    account_number: str
    account_holder: str
    payout_schedule: str | None = None
    payout_day: int | None = None
    min_payout_cents: int | None = None

    @field_validator("institution_number")
    @classmethod
    def validate_institution(cls, v: str) -> str:
        v = v.strip()
        if not v or not v.isdigit() or len(v) != 3:
            raise ValueError("Institution number must be exactly 3 digits")
        return v

    @field_validator("transit_number")
    @classmethod
    def validate_transit(cls, v: str) -> str:
        v = v.strip()
        if not v or not v.isdigit() or len(v) != 5:
            raise ValueError("Transit number must be exactly 5 digits")
        return v

    @field_validator("account_number")
    @classmethod
    def validate_account(cls, v: str) -> str:
        v = v.strip()
        if not v or not v.isdigit() or len(v) < 7 or len(v) > 12:
            raise ValueError("Account number must be 7-12 digits")
        return v

    @field_validator("account_holder")
    @classmethod
    def validate_holder(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Account holder cannot be empty")
        return v.strip()


@router.get("/me/bank-account")
async def get_bank_account(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer)),
):
    stripe_connect = await settings_svc.get_bool(db, "stripe_connect_enabled")
    if stripe_connect:
        user = await banking_repo.get_user(db, current_user.id)
        return {
            "mode": "stripe_connect",
            "stripe_connect_account_id": user.stripe_connect_account_id,
            "stripe_connected": user.stripe_connect_account_id is not None,
        }
    acct = await banking_repo.get_bank_account(db, current_user.id)
    if not acct:
        return BankAccountResponse()
    try:
        return BankAccountResponse(
            institution_number=enc.decrypt(acct.institution_number_encrypted),
            transit_number=enc.decrypt(acct.transit_number_encrypted),
            account_last_four=enc.decrypt(acct.account_number_encrypted)[-4:],
            account_holder_masked=enc.mask_value(enc.decrypt(acct.account_holder_encrypted)),
            verified=acct.verified,
            verification_status=acct.verification_status.value,
            rejection_reason=acct.rejection_reason,
            payout_schedule=acct.payout_schedule,
            payout_day=acct.payout_day,
            min_payout_cents=acct.min_payout_cents,
            has_bank_account=True,
        )
    except Exception:
        logger.warning("Failed to decrypt bank account data for user=%d — re-enter bank details", current_user.id)
        return BankAccountResponse(
            has_bank_account=True,
            verified=acct.verified,
            verification_status=acct.verification_status.value,
            rejection_reason=acct.rejection_reason,
            decryption_failed=True,
        )


@router.put("/me/bank-account", response_model=BankAccountResponse)
@limiter.limit(dynamic_limit("payment_action", "10/minute"))
async def update_bank_account(
    request: Request,
    body: BankAccountUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer)),
):
    stripe_connect = await settings_svc.get_bool(db, "stripe_connect_enabled")
    if stripe_connect:
        raise HTTPException(
            status_code=400,
            detail="Bank account managed by Stripe Connect. Use Stripe dashboard to update banking details.",
        )
    log_step(logger, "Updating bank account", user_id=current_user.id)
    acct = await banking_svc.upsert_bank_account(
        db, current_user.id,
        institution_number=body.institution_number,
        transit_number=body.transit_number,
        account_number=body.account_number,
        account_holder=body.account_holder,
        payout_schedule=body.payout_schedule,
        payout_day=body.payout_day,
        min_payout_cents=body.min_payout_cents,
    )
    return BankAccountResponse(
        institution_number=body.institution_number,
        transit_number=body.transit_number,
        account_last_four=body.account_number[-4:],
        account_holder_masked=enc.mask_value(body.account_holder),
        verified=acct.verified,
        verification_status=acct.verification_status.value,
        rejection_reason=acct.rejection_reason,
        payout_schedule=acct.payout_schedule,
        payout_day=acct.payout_day,
        min_payout_cents=acct.min_payout_cents,
        has_bank_account=True,
    )


@router.delete("/me/bank-account")
@limiter.limit(dynamic_limit("payment_action", "10/minute"))
async def delete_bank_account(
    request: Request,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer)),
):
    """Bank account cannot be deleted once set. Use update to change details."""
    from app.core.exceptions import ForbiddenError

    logger.warning("Bank account delete forbidden", extra={"user_id": current_user.id})
    raise ForbiddenError(
        "Bank account cannot be deleted. You can update your bank details via the form."
    )


# ═══════════════════════════════════════════
#  Organizer: Request Refund Retry
# ═══════════════════════════════════════════

@router.post("/me/events/{event_id}/request-refund-retry")
@limiter.limit("1/hour")
async def request_refund_retry(
    request: Request,
    event_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer)),
):
    """Organizer requests admins to retry failed refunds for their event."""
    from app.core.exceptions import ForbiddenError, NotFoundError
    from app.services import refund_retry
    from app.services import notification_service as notif_svc
    from app.services.escrow_base import get_all_admin_ids, get_organizer_for_event
    from app.models.notification import NotificationType
    from app.repositories.event_repo import event_repo

    event = await event_repo.get_by_id_with_relations(db, event_id)
    if not event:
        raise NotFoundError("Event", event_id)
    if event.organizer_id != current_user.id:
        logger.warning("Refund retry forbidden: not organizer", extra={"event_id": event_id, "user_id": current_user.id})
        raise ForbiddenError("You are not the organizer of this event")

    count = await refund_retry.count_failed_refunds_for_event(db, event_id)
    if count == 0:
        raise NotFoundError("No failed refunds found for this event")

    admin_ids = await get_all_admin_ids(db)
    if admin_ids:
        await notif_svc.create_bulk_notifications(
            db, user_ids=admin_ids,
            type=NotificationType.refund_retry_requested,
            title="Refund Retry Requested",
            message=(
                f"Organizer '{current_user.display_name or current_user.email}' "
                f"is requesting a retry of {count} failed refund(s) "
                f"for Event #{event_id} '{event.title}'."
            ),
            data={"event_id": event_id, "organizer_id": current_user.id, "count": count},
        )

    return {"ok": True, "requested": count}


# ═══════════════════════════════════════════
#  Payment Status Polling
# ═══════════════════════════════════════════

@router.get("/payments/{transaction_id}/status")
async def get_payment_status(transaction_id: str, db: ReadDbSession, current_user: CurrentUser):
    entry = await banking_repo.get_mock_ledger_by_transaction_id(db, transaction_id)
    if not entry:
        return {"status": "not_found"}
    return {
        "transaction_id": entry.transaction_id,
        "status": entry.status.value,
        "receipt_reference": entry.receipt_reference,
        "authorization_code": entry.authorization_code,
        "failure_reason": entry.failure_reason,
    }


# ═══════════════════════════════════════════
#  Admin Banking Overview
# ═══════════════════════════════════════════

@router.get("/admin/banking-overview")
async def admin_banking_overview(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    period: str = Query("30d"),
):
    return await banking_svc.get_overview(db, period)


# ═══════════════════════════════════════════
#  Admin Platform Holding Account Config
# ═══════════════════════════════════════════

class PlatformAccountUpdate(BaseModel):
    institution_number: str
    transit_number: str
    account_number: str
    account_holder: str


class PlatformAccountResponse(BaseModel):
    institution_number: str | None = None
    transit_number: str | None = None
    account_last_four: str | None = None
    account_holder_masked: str | None = None
    configured: bool = False


@router.put("/admin/platform-account", response_model=PlatformAccountResponse)
async def update_platform_account(
    body: PlatformAccountUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    log_step(logger, "Updating platform account", admin_id=current_user.id)
    await settings_svc.set_value(db, "platform_holding_institution_number", enc.encrypt(body.institution_number).decode())
    await settings_svc.set_value(db, "platform_holding_transit_number", enc.encrypt(body.transit_number).decode())
    await settings_svc.set_value(db, "platform_holding_account_number", enc.encrypt(body.account_number).decode())
    await settings_svc.set_value(db, "platform_holding_account_holder", enc.encrypt(body.account_holder).decode())
    await settings_svc.set_value(db, "platform_holding_configured", "true")
    return PlatformAccountResponse(
        institution_number=body.institution_number,
        transit_number=body.transit_number,
        account_last_four=body.account_number[-4:],
        account_holder_masked=enc.mask_value(body.account_holder),
        configured=True,
    )


@router.get("/admin/platform-account", response_model=PlatformAccountResponse)
async def get_platform_account(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    configured = await settings_svc.get_bool(db, "platform_holding_configured")
    if not configured:
        return PlatformAccountResponse()
    raw_inst = await settings_svc.get_str(db, "platform_holding_institution_number")
    raw_transit = await settings_svc.get_str(db, "platform_holding_transit_number")
    raw_acct = await settings_svc.get_str(db, "platform_holding_account_number")
    raw_holder = await settings_svc.get_str(db, "platform_holding_account_holder")
    try:
        inst = enc.decrypt(raw_inst) if raw_inst else None
        transit = enc.decrypt(raw_transit) if raw_transit else None
        acct_num = enc.decrypt(raw_acct) if raw_acct else None
        holder = enc.decrypt(raw_holder) if raw_holder else None
    except Exception:
        inst = raw_inst
        transit = raw_transit
        acct_num = raw_acct
        holder = raw_holder
    return PlatformAccountResponse(
        institution_number=inst,
        transit_number=transit,
        account_last_four=acct_num[-4:] if acct_num else None,
        account_holder_masked=enc.mask_value(holder) if holder else None,
        configured=True,
    )


# ═══════════════════════════════════════════
#  Admin Bank Account Verification
# ═══════════════════════════════════════════

@router.post("/admin/bank-accounts/{user_id}/verify")
@limiter.limit("60/minute")
async def admin_verify_bank_account(
    request: Request,
    user_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin marks an organizer's bank account as verified."""
    stripe_connect = await settings_svc.get_bool(db, "stripe_connect_enabled")
    if stripe_connect:
        raise HTTPException(
            status_code=400,
            detail="Bank verification handled by Stripe Connect. Manual verification disabled.",
        )
    await banking_svc.verify_bank_account(db, user_id, admin_id=current_user.id)
    return {"ok": True, "user_id": user_id, "verification_status": "verified"}


class BankRejectBody(BaseModel):
    reason: str = "Bank account details could not be verified"


@router.post("/admin/bank-accounts/{user_id}/reject")
@limiter.limit("60/minute")
async def admin_reject_bank_account(
    request: Request,
    user_id: int,
    body: BankRejectBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Admin rejects an organizer's bank account verification."""
    stripe_connect = await settings_svc.get_bool(db, "stripe_connect_enabled")
    if stripe_connect:
        raise HTTPException(
            status_code=400,
            detail="Bank verification handled by Stripe Connect. Manual verification disabled.",
        )
    await banking_svc.reject_bank_account(db, user_id, admin_id=current_user.id, reason=body.reason)
    return {"ok": True, "user_id": user_id, "verification_status": "rejected"}


# ═══════════════════════════════════════════
#  Admin Email Templates
# ═══════════════════════════════════════════

class EmailTemplateResponse(BaseModel):
    template_key: str
    subject: str
    body_html: str
    variables: str
    is_active: bool
    is_customized: bool = True


class EmailTemplateUpdate(BaseModel):
    subject: str | None = None
    body_html: str | None = None
    is_active: bool | None = None


# Default templates — always shown even when not yet customized in DB
_DEFAULT_TEMPLATES: list[dict] = [
    {"template_key": "event_cancelled", "subject": "Event Cancelled: {{event_title}}", "variables": '["event_title", "reason", "event_date"]'},
    {"template_key": "ticket_purchased", "subject": "Ticket Confirmation: {{event_title}}", "variables": '["event_title", "ticket_type", "quantity", "total", "event_date", "venue"]'},
    {"template_key": "unpledge_refund", "subject": "Pledge Refund: {{event_title}}", "variables": '["event_title", "amount", "reason"]'},
    {"template_key": "unregister_refund", "subject": "Unregistration Refund: {{event_title}}", "variables": '["event_title", "amount"]'},
    {"template_key": "cancellation_refund", "subject": "Cancellation Refund: {{event_title}}", "variables": '["event_title", "amount", "reason"]'},
    {"template_key": "waitlist_ticket_rejected", "subject": "Waitlist Update: {{event_title}}", "variables": '["event_title", "reason"]'},
    {"template_key": "ticket_refund_approved", "subject": "Refund Approved: {{event_title}}", "variables": '["event_title", "amount", "ticket_type"]'},
    {"template_key": "waitlist_ticket_approved", "subject": "Waitlist Approved: {{event_title}}", "variables": '["event_title", "ticket_type"]'},
    {"template_key": "sponsor_bid_approved", "subject": "Sponsorship Approved: {{event_title}}", "variables": '["event_title", "category_name", "amount"]'},
    {"template_key": "sponsor_bid_rejected", "subject": "Sponsorship Update: {{event_title}}", "variables": '["event_title", "category_name", "reason"]'},
    {"template_key": "sponsor_refund", "subject": "Sponsor Refund: {{event_title}}", "variables": '["event_title", "amount", "reason"]'},
]


@router.get("/admin/email-templates")
async def list_email_templates(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    rows = await email_template_repo.list_all(db)
    db_map = {t.template_key: t for t in rows}

    result = []
    for dflt in _DEFAULT_TEMPLATES:
        key = dflt["template_key"]
        if key in db_map:
            t = db_map[key]
            result.append(EmailTemplateResponse(
                template_key=t.template_key, subject=t.subject,
                body_html=t.body_html, variables=t.variables,
                is_active=t.is_active, is_customized=True,
            ))
        else:
            result.append(EmailTemplateResponse(
                template_key=key, subject=dflt["subject"],
                body_html="", variables=dflt["variables"],
                is_active=True, is_customized=False,
            ))
    # Include any extra DB templates not in defaults
    for t in rows:
        if t.template_key not in {d["template_key"] for d in _DEFAULT_TEMPLATES}:
            result.append(EmailTemplateResponse(
                template_key=t.template_key, subject=t.subject,
                body_html=t.body_html, variables=t.variables,
                is_active=t.is_active, is_customized=True,
            ))
    return result


@router.put("/admin/email-templates/{key}")
async def update_email_template(
    key: str,
    body: EmailTemplateUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    tmpl = await banking_svc.upsert_email_template(
        db, key, subject=body.subject, body_html=body.body_html, is_active=body.is_active,
    )
    return {"ok": True, "template_key": tmpl.template_key}


@router.post("/admin/email-templates/{key}/reset")
async def reset_email_template(
    key: str,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    await banking_svc.reset_email_template(db, key)
    return {"ok": True, "message": f"Template '{key}' reset to default"}


@router.post("/admin/email-templates/reset-all")
async def reset_all_email_templates(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    deleted = await banking_svc.reset_all_email_templates(db)
    return {"ok": True, "deleted_count": deleted}


@router.post("/admin/email-templates/{key}/test-send")
async def test_send_email_template(
    key: str,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    from app.services.email_service import send_email
    tmpl = await email_template_repo.get_by_key(db, key)
    subject = tmpl.subject if tmpl else f"Test: {key}"
    body = tmpl.body_html if tmpl else f"<p>Test email for template: {key}</p>"
    await send_email(to_email=current_user.email, subject=subject, body_html=body)
    return {"ok": True, "sent_to": current_user.email}


@router.post("/admin/email-templates/upload-logo")
@limiter.limit(dynamic_limit("file_upload", "10/minute"))
async def upload_email_logo(
    request: Request,
    db: DbSession,
    file: UploadFile = File(...),
    current_user: User = Depends(require_role(UserRole.admin)),
):
    """Upload a logo image for email templates."""
    from app.services.upload_validation import validate_upload

    log_step(logger, "Uploading email logo", admin_id=current_user.id)
    contents = await validate_upload(db, file, "image")

    ext = Path(file.filename or "logo.png").suffix.lower() or ".png"
    if ext not in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        ext = ".png"
    filename = f"email_logo_{uuid.uuid4().hex[:12]}{ext}"

    upload_dir = Path(__file__).resolve().parent.parent.parent.parent / "static" / "uploads"
    upload_dir.mkdir(parents=True, exist_ok=True)
    dest = upload_dir / filename
    dest.write_bytes(contents)

    image_url = f"/static/uploads/{filename}"
    await settings_svc.set_value(db, "email_template_logo_url", image_url)

    from app.api.v1.config import invalidate_public_config
    await invalidate_public_config()

    await audit_svc.log_action(
        db, admin_id=current_user.id, action="email_logo_upload",
        target_type="setting", target_id="email_template_logo_url",
        details={"logo_url": image_url},
    )
    return {"ok": True, "logo_url": image_url}


# ═══════════════════════════════════════════
#  Admin Mock Overview
# ═══════════════════════════════════════════

@router.get("/admin/mock-overview")
async def admin_mock_overview(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    txn_data = await banking_repo.get_mock_ledger_overview(db)
    email_data = await banking_repo.get_email_mock_overview(db)

    txn_count = txn_data["total"]
    txn_volume = txn_data["volume"]
    txn_success = txn_data["success"]
    email_count = email_data["total"]
    email_bounced = email_data["bounced"]

    return {
        "total_transactions": txn_count,
        "total_volume_cents": int(txn_volume),
        "success_count": txn_success,
        "success_rate": round(txn_success / txn_count * 100, 1) if txn_count > 0 else 100.0,
        "total_emails": email_count,
        "email_bounce_count": email_bounced,
        "email_bounce_rate": round(email_bounced / email_count * 100, 1) if email_count > 0 else 0.0,
        "last_transaction_at": txn_data["last_txn"].isoformat() if txn_data["last_txn"] else None,
        "last_email_at": email_data["last_email"].isoformat() if email_data["last_email"] else None,
        "recent_transactions": [
            {
                "id": t.id, "transaction_id": t.transaction_id,
                "operation": t.operation.value, "amount_cents": t.amount_cents,
                "from_account": t.from_account, "to_account": t.to_account,
                "status": t.status.value, "authorization_code": t.authorization_code,
                "receipt_reference": t.receipt_reference, "failure_reason": t.failure_reason,
                "created_at": t.created_at.isoformat() if t.created_at else None,
            }
            for t in txn_data["recent"]
        ],
        "recent_emails": [
            {
                "id": e.id, "to_email": e.to_email, "subject": e.subject,
                "template_key": e.template_key, "status": e.status,
                "created_at": e.created_at.isoformat() if e.created_at else None,
            }
            for e in email_data["recent"]
        ],
    }


# ═══════════════════════════════════════════
#  Admin Mock Quick Actions
# ═══════════════════════════════════════════

async def _require_mock_mode(db):
    if not await settings_svc.get_bool(db, "payment_mock_enabled"):
        from app.core.exceptions import ForbiddenError
        raise ForbiddenError("Mock controls are only available when mock mode is enabled")


@router.post("/admin/mock/clear")
async def clear_mock_data(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    await _require_mock_mode(db)
    await banking_repo.delete_all_mock_data(db)
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="mock_clear",
        target_type="mock", target_id=None,
    )
    return {"ok": True, "message": "All mock data cleared"}


@router.post("/admin/mock/settle-all")
async def settle_all_pending(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    await _require_mock_mode(db)
    count = await banking_repo.settle_all_pending(db)
    return {"ok": True, "settled_count": count}


@router.post("/admin/mock/fail-next")
async def fail_next_charge(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    await _require_mock_mode(db)
    await settings_svc.set_value(db, "mock_fail_next_charge", "true")
    return {"ok": True}


# ═══════════════════════════════════════════
#  Admin Mock Reset Defaults
# ═══════════════════════════════════════════

_MOCK_DEFAULTS = {k: v for k, v in settings_svc.DEFAULTS.items() if k.startswith("mock_")}


@router.post("/admin/mock/reset-defaults")
async def reset_mock_defaults(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    await _require_mock_mode(db)
    for key, default_val in _MOCK_DEFAULTS.items():
        await settings_svc.set_value(db, key, str(default_val))
    return {"ok": True, "reset_count": len(_MOCK_DEFAULTS)}


# ═══════════════════════════════════════════
#  Admin Disputes
# ═══════════════════════════════════════════

class DisputeResponse(BaseModel):
    id: int
    stripe_dispute_id: str | None = None
    transaction_id: str
    event_id: int | None
    user_id: int
    amount_cents: int
    fee_cents: int
    reason: str
    status: str
    created_at: datetime | None


@router.get("/admin/disputes")
async def list_disputes(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    status_filter: str | None = Query(None),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    rows, total = await banking_repo.list_disputes(
        db, status=status_filter, offset=offset, limit=limit,
    )
    return {
        "items": [
            DisputeResponse(
                id=d.id, stripe_dispute_id=d.stripe_dispute_id,
                transaction_id=d.transaction_id, event_id=d.event_id,
                user_id=d.user_id, amount_cents=d.amount_cents, fee_cents=d.fee_cents,
                reason=d.reason, status=d.status.value, created_at=d.created_at,
            )
            for d in rows
        ],
        "total": total,
    }


class CreateDisputeBody(BaseModel):
    transaction_id: str
    event_id: int | None = None
    user_id: int
    amount_cents: int
    reason: str = "product_not_received"


@router.post("/admin/disputes")
async def create_dispute(
    body: CreateDisputeBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    log_step(logger, "Creating dispute", transaction_id=body.transaction_id, event_id=body.event_id, admin_id=current_user.id)
    dispute = await banking_svc.create_dispute(
        db, transaction_id=body.transaction_id, event_id=body.event_id,
        user_id=body.user_id, amount_cents=body.amount_cents, reason=body.reason,
    )
    return {"ok": True, "dispute_id": dispute.id}


class ResolveDisputeBody(BaseModel):
    outcome: str  # "won" or "lost"
    notes: str | None = None


@router.post("/admin/disputes/{dispute_id}/resolve")
async def resolve_dispute(
    dispute_id: int,
    body: ResolveDisputeBody,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    log_step(logger, "Resolving dispute", dispute_id=dispute_id, outcome=body.outcome, admin_id=current_user.id)
    dispute = await banking_svc.resolve_dispute(
        db, dispute_id, outcome=body.outcome, notes=body.notes, admin_id=current_user.id,
    )
    return {"ok": True, "status": dispute.status.value}


@router.post("/admin/disputes/{dispute_id}/submit-evidence")
async def submit_dispute_evidence(
    dispute_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    dispute = await banking_svc.submit_dispute_evidence(db, dispute_id)
    return {"ok": True, "status": dispute.status.value}


@router.post("/admin/disputes/{dispute_id}/accept")
async def accept_dispute_loss(
    dispute_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    dispute = await banking_svc.accept_dispute_loss(db, dispute_id)
    return {"ok": True, "status": dispute.status.value}


@router.post("/admin/mock/simulate-dispute")
async def simulate_dispute(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    transaction_id: str = Body(embed=True),
):
    await _require_mock_mode(db)
    dispute = await banking_svc.simulate_mock_dispute(db, transaction_id, admin_id=current_user.id)
    return {"ok": True, "dispute_id": dispute.id}


# ═══════════════════════════════════════════
#  Admin Ledger Health
# ═══════════════════════════════════════════

@router.get("/admin/ledger-health")
async def ledger_health(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    return await ledger_svc.verify_balance(db)


# ═══════════════════════════════════════════
#  Admin Reconciliation
# ═══════════════════════════════════════════

@router.get("/admin/reconciliation")
async def list_reconciliation_reports(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    limit: int = Query(30, ge=1, le=365),
):
    rows = await banking_repo.list_reconciliation_reports(db, limit=limit)
    return [
        {
            "run_date": r.run_date.isoformat(),
            "actual_balance_cents": r.actual_balance_cents,
            "expected_balance_cents": r.expected_balance_cents,
            "delta_cents": r.delta_cents,
            "status": r.status,
        }
        for r in rows
    ]


@router.post("/admin/reconciliation/run")
async def run_reconciliation_now(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    from app.services.reconciliation import run_reconciliation
    report = await run_reconciliation(db)
    return {
        "run_date": report.run_date.isoformat(),
        "status": report.status,
        "delta_cents": report.delta_cents,
    }


# ═══════════════════════════════════════════
#  Admin Payout Status (D3)
# ═══════════════════════════════════════════

@router.get("/admin/payout-status")
async def admin_payout_status(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    organizers = await banking_repo.list_organizer_users(db)

    items = []
    for org in organizers:
        org_id, org_name, org_email = org
        bank = await banking_repo.get_bank_account(db, org_id)
        pending_cents = await banking_repo.get_released_escrow_cents_for_organizer(db, org_id)

        bank_status = "missing"
        if bank:
            bank_status = "verified" if bank.verified else "configured"

        items.append({
            "organizer_id": org_id,
            "organizer_name": org_name or org_email,
            "organizer_email": org_email,
            "pending_payout_cents": pending_cents,
            "bank_status": bank_status,
            "payout_schedule": bank.payout_schedule if bank else "weekly",
            "next_payout_date": None,
        })

    return {"items": items}


@router.post("/admin/payouts/{organizer_id}/force")
async def force_payout(
    organizer_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="payout_force",
        target_type="organizer", target_id=organizer_id,
    )
    return {"ok": True, "message": f"Payout initiated for organizer {organizer_id}"}


# ═══════════════════════════════════════════
#  Admin Transaction Ledger (E1)
# ═══════════════════════════════════════════

@router.get("/admin/transactions")
async def list_transactions(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    operation: str | None = Query(None),
    status: str | None = Query(None),
    date_from: date | None = Query(None),
    date_to: date | None = Query(None),
    search: str | None = Query(None),
):
    # Convert date to datetime for repo
    dt_from = datetime.combine(date_from, datetime.min.time()) if date_from else None
    dt_to = datetime.combine(date_to, datetime.max.time()) if date_to else None

    rows, total = await banking_repo.list_transactions(
        db, offset=offset, limit=limit, operation=operation, status=status,
        date_from=dt_from, date_to=dt_to, search=search,
    )

    return {
        "items": [
            {
                "id": t.id,
                "transaction_id": t.transaction_id,
                "operation": t.operation.value,
                "amount_cents": t.amount_cents,
                "fee_cents": t.fee_cents,
                "from_account": t.from_account,
                "to_account": t.to_account,
                "description": t.description,
                "status": t.status.value,
                "authorization_code": t.authorization_code,
                "receipt_reference": t.receipt_reference,
                "failure_reason": t.failure_reason,
                "created_at": t.created_at.isoformat() if t.created_at else None,
                "completed_at": t.completed_at.isoformat() if t.completed_at else None,
            }
            for t in rows
        ],
        "total": total,
    }


# ═══════════════════════════════════════════
#  Admin Reconciliation History (E2)
# ═══════════════════════════════════════════

@router.get("/admin/reconciliation/history")
async def reconciliation_history(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    limit: int = Query(30, ge=1, le=365),
):
    rows = await banking_repo.list_reconciliation_reports(db, limit=limit)
    return [
        {
            "run_date": r.run_date.isoformat(),
            "actual_balance_cents": r.actual_balance_cents,
            "expected_balance_cents": r.expected_balance_cents,
            "delta_cents": r.delta_cents,
            "status": r.status,
        }
        for r in rows
    ]
