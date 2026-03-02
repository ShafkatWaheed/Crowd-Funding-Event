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
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import CurrentUser, DbSession, ReadDbSession, require_role
from app.rate_limit import limiter, dynamic_limit
from app.models.dispute import Dispute, DisputeStatus
from app.models.email_mock_log import EmailMockLog
from app.models.email_template import EmailTemplate
from app.models.escrow import EscrowStatus, FundEscrow, TicketEscrow, SponsorEscrow
from app.models.ledger_entry import LedgerEntry
from app.models.payment_info import OrganizerBankAccount, UserPaymentInfo
from app.models.payment_mock_ledger import MockLedgerStatus, PaymentMockLedger
from app.models.reconciliation import ReconciliationReport
from app.models.user import User, UserRole
from app.services import audit as audit_svc
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
        user = (await db.execute(select(User).where(User.id == current_user.id))).scalar_one()
        return {
            "mode": "stripe",
            "stripe_customer_id": user.stripe_customer_id,
            "stripe_configured": user.stripe_customer_id is not None,
        }
    info = (await db.execute(
        select(UserPaymentInfo).where(UserPaymentInfo.user_id == current_user.id)
    )).scalar_one_or_none()
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
    info = (await db.execute(
        select(UserPaymentInfo).where(UserPaymentInfo.user_id == current_user.id)
    )).scalar_one_or_none()
    if not info:
        info = UserPaymentInfo(user_id=current_user.id)
        db.add(info)
    if body.card_holder_name is not None:
        info.card_holder_name = body.card_holder_name
    if body.card_last_four is not None:
        info.card_last_four = body.card_last_four
    if body.card_brand is not None:
        info.card_brand = body.card_brand
    if body.billing_address is not None:
        info.billing_address = body.billing_address
    if body.payment_method_token is not None:
        info.payment_method_token = body.payment_method_token
    await db.flush()
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
        user = (await db.execute(select(User).where(User.id == current_user.id))).scalar_one()
        return {
            "mode": "stripe_connect",
            "stripe_connect_account_id": user.stripe_connect_account_id,
            "stripe_connected": user.stripe_connect_account_id is not None,
        }
    acct = (await db.execute(
        select(OrganizerBankAccount).where(OrganizerBankAccount.user_id == current_user.id)
    )).scalar_one_or_none()
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
    from app.models.payment_info import BankVerificationStatus
    from app.services import notification_service as notif_svc
    from app.models.notification import NotificationType

    acct = (await db.execute(
        select(OrganizerBankAccount).where(OrganizerBankAccount.user_id == current_user.id)
    )).scalar_one_or_none()
    if not acct:
        acct = OrganizerBankAccount(user_id=current_user.id,
                                     institution_number_encrypted=enc.encrypt(body.institution_number),
                                     transit_number_encrypted=enc.encrypt(body.transit_number),
                                     account_number_encrypted=enc.encrypt(body.account_number),
                                     account_holder_encrypted=enc.encrypt(body.account_holder))
        db.add(acct)
    else:
        acct.institution_number_encrypted = enc.encrypt(body.institution_number)
        acct.transit_number_encrypted = enc.encrypt(body.transit_number)
        acct.account_number_encrypted = enc.encrypt(body.account_number)
        acct.account_holder_encrypted = enc.encrypt(body.account_holder)

    acct.verified = False
    acct.verification_status = BankVerificationStatus.pending
    acct.rejection_reason = None

    if body.payout_schedule:
        acct.payout_schedule = body.payout_schedule
    if body.payout_day is not None:
        acct.payout_day = body.payout_day
    if body.min_payout_cents is not None:
        acct.min_payout_cents = body.min_payout_cents
    await db.flush()

    await notif_svc.create_notification(
        db, user_id=current_user.id,
        type=NotificationType.bank_verification_pending,
        title="Bank Account Submitted",
        message="Your bank account details have been submitted for verification.",
        data={"bank_account_id": acct.id},
    )

    try:
        from app.worker.redis_pool import enqueue
        delay = await settings_svc.get_int(db, "bank_verification_delay_seconds")
        await enqueue("mock_verify_bank_account", acct.id, _defer_by=delay)
    except Exception:
        pass

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
    from app.models.event import Event

    event = (await db.execute(
        select(Event).where(Event.id == event_id)
    )).scalar_one_or_none()
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
    entry = (await db.execute(
        select(PaymentMockLedger).where(PaymentMockLedger.transaction_id == transaction_id)
    )).scalar_one_or_none()
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

class BankingOverviewResponse(BaseModel):
    platform_account_configured: bool = False
    platform_account_institution: str | None = None
    platform_account_transit: str | None = None
    platform_account_last_four: str | None = None
    fund_escrow_total_held_cents: int = 0
    fund_escrow_total_released_cents: int = 0
    fund_escrow_active_count: int = 0
    ticket_escrow_total_held_cents: int = 0
    ticket_escrow_total_released_cents: int = 0
    ticket_escrow_active_count: int = 0
    sponsor_escrow_total_held_cents: int = 0
    sponsor_escrow_total_released_cents: int = 0
    sponsor_escrow_active_count: int = 0
    commission_total_cents: int = 0
    commission_period_cents: int = 0
    commission_by_source: dict = {}
    tax_collected_total_cents: int = 0
    tax_collected_period_cents: int = 0
    payout_pending_count: int = 0
    payout_pending_total_cents: int = 0
    transaction_total_count: int = 0
    transaction_settled_count: int = 0
    transaction_pending_count: int = 0
    transaction_failed_count: int = 0
    disputes_open_count: int = 0
    disputes_total_amount_cents: int = 0
    last_reconciliation_status: str | None = None
    last_reconciliation_delta_cents: int = 0
    mock_mode_active: bool = False
    stripe_enabled: bool = False
    stripe_connect_enabled: bool = False


@router.get("/admin/banking-overview", response_model=BankingOverviewResponse)
async def admin_banking_overview(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    period: str = Query("30d"),
):
    period_map = {"7d": 7, "30d": 30, "90d": 90, "1y": 365}
    delta_days = period_map.get(period, 30)

    mock_active = await settings_svc.get_bool(db, "payment_mock_enabled")
    platform_configured = await settings_svc.get_bool(db, "platform_holding_configured")

    platform_inst: str | None = None
    platform_transit: str | None = None
    platform_last_four: str | None = None
    if platform_configured:
        raw_inst = await settings_svc.get_str(db, "platform_holding_institution_number")
        raw_transit = await settings_svc.get_str(db, "platform_holding_transit_number")
        raw_acct = await settings_svc.get_str(db, "platform_holding_account_number")
        if raw_inst:
            try:
                platform_inst = enc.decrypt(raw_inst)
            except Exception:
                platform_inst = raw_inst
        if raw_transit:
            try:
                platform_transit = enc.decrypt(raw_transit)
            except Exception:
                platform_transit = raw_transit
        if raw_acct:
            try:
                platform_last_four = enc.decrypt(raw_acct)[-4:]
            except Exception:
                platform_last_four = raw_acct[-4:] if raw_acct else None

    # Fund escrow aggregates
    fe = (await db.execute(
        select(
            func.coalesce(func.sum(FundEscrow.total_held_cents), 0),
            func.coalesce(func.sum(
                FundEscrow.stage1_released_cents + FundEscrow.stage2_released_cents + FundEscrow.stage3_released_cents
            ), 0),
            func.count(),
        ).where(FundEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]))
    )).one()

    # Ticket escrow aggregates
    te = (await db.execute(
        select(
            func.coalesce(func.sum(TicketEscrow.total_held_cents), 0),
            func.coalesce(func.sum(
                TicketEscrow.stage1_released_cents + TicketEscrow.stage2_released_cents + TicketEscrow.stage3_released_cents
            ), 0),
            func.count(),
        ).where(TicketEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]))
    )).one()

    # Sponsor escrow aggregates
    se = (await db.execute(
        select(
            func.coalesce(func.sum(SponsorEscrow.total_held_cents), 0),
            func.coalesce(func.sum(
                SponsorEscrow.stage1_released_cents + SponsorEscrow.stage2_released_cents + SponsorEscrow.stage3_released_cents
            ), 0),
            func.count(),
        ).where(SponsorEscrow.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]))
    )).one()

    # Commission from ledger
    commission_total = abs(await ledger_svc.get_account_balance(db, "platform_commission"))
    tax_total = abs(await ledger_svc.get_account_balance(db, "tax_collected"))

    cutoff = datetime.now(timezone.utc) - timedelta(days=delta_days)

    # Commission breakdown by source (ticket / funding / sponsor) within period
    source_q = (
        select(
            LedgerEntry.description,
            func.coalesce(func.sum(LedgerEntry.amount_cents), 0),
        )
        .where(
            LedgerEntry.account == "platform_commission",
            LedgerEntry.entry_type == "credit",
            LedgerEntry.created_at >= cutoff,
        )
        .group_by(LedgerEntry.description)
    )
    source_rows = (await db.execute(source_q)).all()
    commission_by_source = {"ticket": 0, "funding": 0, "sponsor": 0}
    commission_period_cents = 0
    for desc, amt in source_rows:
        amt_int = int(amt)
        commission_period_cents += amt_int
        desc_lower = (desc or "").lower()
        if "ticket" in desc_lower:
            commission_by_source["ticket"] += amt_int
        elif "pledge" in desc_lower or "fund" in desc_lower:
            commission_by_source["funding"] += amt_int
        elif "sponsor" in desc_lower:
            commission_by_source["sponsor"] += amt_int
        else:
            commission_by_source["ticket"] += amt_int

    # Tax collected within the period
    tax_period_q = (
        select(func.coalesce(func.sum(LedgerEntry.amount_cents), 0))
        .where(
            LedgerEntry.account == "tax_collected",
            LedgerEntry.entry_type == "credit",
            LedgerEntry.created_at >= cutoff,
        )
    )
    tax_collected_period_cents = abs(int((await db.execute(tax_period_q)).scalar_one()))

    # Disputes
    disputes = (await db.execute(
        select(
            func.count(),
            func.coalesce(func.sum(Dispute.amount_cents), 0),
        ).where(Dispute.status == DisputeStatus.open)
    )).one()

    # Last reconciliation
    last_recon = (await db.execute(
        select(ReconciliationReport).order_by(ReconciliationReport.run_date.desc()).limit(1)
    )).scalar_one_or_none()

    # Payout summary (released escrow = pending payout since no payout tracking yet)
    payout_pending_total = int(fe[1]) + int(te[1]) + int(se[1])

    from app.models.event import Event as _Evt
    payout_pending_count = 0
    for _EscrowModel in (FundEscrow, TicketEscrow, SponsorEscrow):
        _cnt = (await db.execute(
            select(func.count(func.distinct(_Evt.organizer_id)))
            .select_from(_EscrowModel)
            .join(_Evt, _EscrowModel.event_id == _Evt.id)
            .where(_EscrowModel.status.in_([EscrowStatus.holding, EscrowStatus.partially_released]))
        )).scalar_one()
        payout_pending_count = max(payout_pending_count, int(_cnt))

    # Transaction summary counts
    txn_total = int((await db.execute(
        select(func.count(PaymentMockLedger.id))
    )).scalar_one())
    txn_settled = int((await db.execute(
        select(func.count(PaymentMockLedger.id)).where(
            PaymentMockLedger.status == MockLedgerStatus.settled)
    )).scalar_one())
    txn_pending = int((await db.execute(
        select(func.count(PaymentMockLedger.id)).where(
            PaymentMockLedger.status == MockLedgerStatus.pending)
    )).scalar_one())
    txn_failed = int((await db.execute(
        select(func.count(PaymentMockLedger.id)).where(
            PaymentMockLedger.status == MockLedgerStatus.failed)
    )).scalar_one())

    return BankingOverviewResponse(
        platform_account_configured=platform_configured,
        platform_account_institution=platform_inst,
        platform_account_transit=platform_transit,
        platform_account_last_four=platform_last_four,
        fund_escrow_total_held_cents=int(fe[0]),
        fund_escrow_total_released_cents=int(fe[1]),
        fund_escrow_active_count=int(fe[2]),
        ticket_escrow_total_held_cents=int(te[0]),
        ticket_escrow_total_released_cents=int(te[1]),
        ticket_escrow_active_count=int(te[2]),
        sponsor_escrow_total_held_cents=int(se[0]),
        sponsor_escrow_total_released_cents=int(se[1]),
        sponsor_escrow_active_count=int(se[2]),
        commission_total_cents=commission_total,
        commission_period_cents=commission_period_cents,
        commission_by_source=commission_by_source,
        tax_collected_total_cents=tax_total,
        tax_collected_period_cents=tax_collected_period_cents,
        disputes_open_count=int(disputes[0]),
        disputes_total_amount_cents=int(disputes[1]),
        payout_pending_count=payout_pending_count,
        payout_pending_total_cents=payout_pending_total,
        transaction_total_count=txn_total,
        transaction_settled_count=txn_settled,
        transaction_pending_count=txn_pending,
        transaction_failed_count=txn_failed,
        last_reconciliation_status=last_recon.status if last_recon else None,
        last_reconciliation_delta_cents=last_recon.delta_cents if last_recon else 0,
        mock_mode_active=mock_active,
        stripe_enabled=await settings_svc.get_bool(db, "stripe_enabled"),
        stripe_connect_enabled=await settings_svc.get_bool(db, "stripe_connect_enabled"),
    )


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
    from app.models.payment_info import BankVerificationStatus
    from app.services import notification_service as notif_svc
    from app.models.notification import NotificationType
    from app.core.exceptions import NotFoundError

    acct = (await db.execute(
        select(OrganizerBankAccount).where(OrganizerBankAccount.user_id == user_id)
    )).scalar_one_or_none()
    if not acct:
        raise NotFoundError("Bank account not found for user", user_id)

    acct.verified = True
    acct.verification_status = BankVerificationStatus.verified
    acct.rejection_reason = None
    await db.flush()

    await notif_svc.create_notification(
        db, user_id=user_id,
        type=NotificationType.bank_verified,
        title="Bank Account Verified",
        message="Your bank account has been verified. Payouts can now proceed.",
        data={"bank_account_id": acct.id},
    )
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="bank_account_verify",
        target_type="bank_account", target_id=user_id,
    )
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
    from app.models.payment_info import BankVerificationStatus
    from app.services import notification_service as notif_svc
    from app.models.notification import NotificationType
    from app.core.exceptions import NotFoundError

    acct = (await db.execute(
        select(OrganizerBankAccount).where(OrganizerBankAccount.user_id == user_id)
    )).scalar_one_or_none()
    if not acct:
        raise NotFoundError("Bank account not found for user", user_id)

    acct.verified = False
    acct.verification_status = BankVerificationStatus.rejected
    acct.rejection_reason = body.reason
    await db.flush()

    await notif_svc.create_notification(
        db, user_id=user_id,
        type=NotificationType.bank_verification_pending,
        title="Bank Account Rejected",
        message=f"Your bank account verification was rejected: {body.reason}. Please update your details.",
        data={"bank_account_id": acct.id, "reason": body.reason},
    )
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="bank_account_reject",
        target_type="bank_account", target_id=user_id,
        details={"reason": body.reason},
    )
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
    rows = (await db.execute(
        select(EmailTemplate).order_by(EmailTemplate.template_key)
    )).scalars().all()
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
    tmpl = (await db.execute(
        select(EmailTemplate).where(EmailTemplate.template_key == key)
    )).scalar_one_or_none()
    if not tmpl:
        tmpl = EmailTemplate(template_key=key, subject="", body_html="", variables="[]")
        db.add(tmpl)
    if body.subject is not None:
        tmpl.subject = body.subject
    if body.body_html is not None:
        tmpl.body_html = body.body_html
    if body.is_active is not None:
        tmpl.is_active = body.is_active
    await db.flush()
    return {"ok": True, "template_key": tmpl.template_key}


@router.post("/admin/email-templates/{key}/reset")
async def reset_email_template(
    key: str,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    tmpl = (await db.execute(
        select(EmailTemplate).where(EmailTemplate.template_key == key)
    )).scalar_one_or_none()
    if tmpl:
        await db.delete(tmpl)
        await db.flush()
    return {"ok": True, "message": f"Template '{key}' reset to default"}


@router.post("/admin/email-templates/reset-all")
async def reset_all_email_templates(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    from sqlalchemy import delete as sa_delete
    result = await db.execute(sa_delete(EmailTemplate))
    await db.flush()
    return {"ok": True, "deleted_count": result.rowcount}


@router.post("/admin/email-templates/{key}/test-send")
async def test_send_email_template(
    key: str,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    from app.services.email_service import send_email
    tmpl = (await db.execute(
        select(EmailTemplate).where(EmailTemplate.template_key == key)
    )).scalar_one_or_none()
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
    txn_count = (await db.execute(select(func.count()).select_from(PaymentMockLedger))).scalar_one()
    txn_volume = (await db.execute(
        select(func.coalesce(func.sum(PaymentMockLedger.amount_cents), 0))
    )).scalar_one()
    txn_success = (await db.execute(
        select(func.count()).select_from(PaymentMockLedger).where(
            PaymentMockLedger.status == MockLedgerStatus.completed
        )
    )).scalar_one()
    email_count = (await db.execute(select(func.count()).select_from(EmailMockLog))).scalar_one()
    email_bounced = (await db.execute(
        select(func.count()).select_from(EmailMockLog).where(EmailMockLog.status == "bounced")
    )).scalar_one()

    last_txn_at = (await db.execute(
        select(func.max(PaymentMockLedger.created_at))
    )).scalar_one()
    last_email_at = (await db.execute(
        select(func.max(EmailMockLog.created_at))
    )).scalar_one()

    recent_txns = (await db.execute(
        select(PaymentMockLedger).order_by(PaymentMockLedger.created_at.desc()).limit(20)
    )).scalars().all()
    recent_emails = (await db.execute(
        select(EmailMockLog).order_by(EmailMockLog.created_at.desc()).limit(20)
    )).scalars().all()

    return {
        "total_transactions": txn_count,
        "total_volume_cents": int(txn_volume),
        "success_count": txn_success,
        "success_rate": round(txn_success / txn_count * 100, 1) if txn_count > 0 else 100.0,
        "total_emails": email_count,
        "email_bounce_count": email_bounced,
        "email_bounce_rate": round(email_bounced / email_count * 100, 1) if email_count > 0 else 0.0,
        "last_transaction_at": last_txn_at.isoformat() if last_txn_at else None,
        "last_email_at": last_email_at.isoformat() if last_email_at else None,
        "recent_transactions": [
            {
                "id": t.id, "transaction_id": t.transaction_id,
                "operation": t.operation.value, "amount_cents": t.amount_cents,
                "from_account": t.from_account, "to_account": t.to_account,
                "status": t.status.value, "authorization_code": t.authorization_code,
                "receipt_reference": t.receipt_reference, "failure_reason": t.failure_reason,
                "created_at": t.created_at.isoformat() if t.created_at else None,
            }
            for t in recent_txns
        ],
        "recent_emails": [
            {
                "id": e.id, "to_email": e.to_email, "subject": e.subject,
                "template_key": e.template_key, "status": e.status,
                "created_at": e.created_at.isoformat() if e.created_at else None,
            }
            for e in recent_emails
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
    from sqlalchemy import delete
    await db.execute(delete(PaymentMockLedger))
    await db.execute(delete(EmailMockLog))
    await db.flush()
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
    from sqlalchemy import update
    result = await db.execute(
        update(PaymentMockLedger)
        .where(PaymentMockLedger.status == MockLedgerStatus.settlement_pending)
        .values(status=MockLedgerStatus.settled, completed_at=datetime.now(timezone.utc))
    )
    await db.flush()
    return {"ok": True, "settled_count": result.rowcount}


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
    q = select(Dispute).order_by(Dispute.created_at.desc())
    if status_filter:
        try:
            q = q.where(Dispute.status == DisputeStatus(status_filter))
        except ValueError:
            pass
    total = (await db.execute(select(func.count()).select_from(q.subquery()))).scalar_one()
    rows = (await db.execute(q.offset(offset).limit(limit))).scalars().all()
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
    dispute = Dispute(
        transaction_id=body.transaction_id,
        event_id=body.event_id,
        user_id=body.user_id,
        amount_cents=body.amount_cents,
        reason=body.reason,
    )
    db.add(dispute)

    if body.event_id:
        fe = (await db.execute(
            select(FundEscrow).where(FundEscrow.event_id == body.event_id)
        )).scalar_one_or_none()
        if fe and fe.status not in (EscrowStatus.frozen, EscrowStatus.fully_released):
            fe.status = EscrowStatus.frozen
        te = (await db.execute(
            select(TicketEscrow).where(TicketEscrow.event_id == body.event_id)
        )).scalar_one_or_none()
        if te and te.status not in (EscrowStatus.frozen, EscrowStatus.fully_released):
            te.status = EscrowStatus.frozen
        se_esc = (await db.execute(
            select(SponsorEscrow).where(SponsorEscrow.event_id == body.event_id)
        )).scalar_one_or_none()
        if se_esc and se_esc.status not in (EscrowStatus.frozen, EscrowStatus.fully_released):
            se_esc.status = EscrowStatus.frozen

    await db.flush()
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
    dispute = (await db.execute(
        select(Dispute).where(Dispute.id == dispute_id)
    )).scalar_one_or_none()
    if not dispute:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Dispute", dispute_id)

    now = datetime.now(timezone.utc)
    if body.outcome == "won":
        dispute.status = DisputeStatus.won
    else:
        dispute.status = DisputeStatus.lost
    dispute.resolved_at = now
    dispute.outcome_notes = body.notes

    if body.outcome == "won" and dispute.event_id:
        for model in (FundEscrow, TicketEscrow, SponsorEscrow):
            esc = (await db.execute(
                select(model).where(model.event_id == dispute.event_id)
            )).scalar_one_or_none()
            if esc and esc.status == EscrowStatus.frozen:
                if esc.stage3_released_at:
                    esc.status = EscrowStatus.fully_released
                elif esc.stage1_released_at:
                    esc.status = EscrowStatus.partially_released
                else:
                    esc.status = EscrowStatus.holding

    await db.flush()
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="dispute_resolve",
        target_type="dispute", target_id=dispute_id,
        details={"outcome": body.outcome, "notes": body.notes},
    )
    return {"ok": True, "status": dispute.status.value}


@router.post("/admin/disputes/{dispute_id}/submit-evidence")
async def submit_dispute_evidence(
    dispute_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    dispute = (await db.execute(
        select(Dispute).where(Dispute.id == dispute_id)
    )).scalar_one_or_none()
    if not dispute:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Dispute", dispute_id)
    dispute.status = DisputeStatus.evidence_submitted
    dispute.evidence_submitted_at = datetime.now(timezone.utc)
    await db.flush()
    return {"ok": True, "status": dispute.status.value}


@router.post("/admin/disputes/{dispute_id}/accept")
async def accept_dispute_loss(
    dispute_id: int,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    dispute = (await db.execute(
        select(Dispute).where(Dispute.id == dispute_id)
    )).scalar_one_or_none()
    if not dispute:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Dispute", dispute_id)
    dispute.status = DisputeStatus.lost
    dispute.resolved_at = datetime.now(timezone.utc)
    await db.flush()
    return {"ok": True, "status": dispute.status.value}


@router.post("/admin/mock/simulate-dispute")
async def simulate_dispute(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
    transaction_id: str = Body(embed=True),
):
    await _require_mock_mode(db)
    ledger_entry = (await db.execute(
        select(PaymentMockLedger).where(PaymentMockLedger.transaction_id == transaction_id)
    )).scalar_one_or_none()
    amount = ledger_entry.amount_cents if ledger_entry else 5000
    dispute = Dispute(
        transaction_id=transaction_id,
        stripe_dispute_id=f"dp_mock_{transaction_id}",
        amount_cents=amount,
        fee_cents=1500,
        user_id=current_user.id,
        reason="fraudulent",
    )
    db.add(dispute)
    await db.flush()
    await audit_svc.log_action(
        db, admin_id=current_user.id, action="dispute_create",
        target_type="dispute", target_id=dispute.id,
        details={"transaction_id": transaction_id},
    )
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
    rows = (await db.execute(
        select(ReconciliationReport).order_by(ReconciliationReport.run_date.desc()).limit(limit)
    )).scalars().all()
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
    from app.models.escrow import FundEscrow, TicketEscrow, SponsorEscrow, EscrowStatus
    from app.models.event import Event

    organizers_q = (
        select(
            User.id,
            User.display_name,
            User.email,
        )
        .where(User.role == UserRole.organizer)
        .order_by(User.display_name)
    )
    organizers = (await db.execute(organizers_q)).all()

    items = []
    for org in organizers:
        org_id, org_name, org_email = org
        bank = (await db.execute(
            select(OrganizerBankAccount).where(OrganizerBankAccount.user_id == org_id)
        )).scalar_one_or_none()

        pending_cents = 0
        for model in (FundEscrow, TicketEscrow, SponsorEscrow):
            released_sum = (await db.execute(
                select(func.coalesce(func.sum(
                    model.stage1_released_cents + model.stage2_released_cents + model.stage3_released_cents
                ), 0))
                .join(Event, model.event_id == Event.id)
                .where(Event.organizer_id == org_id)
            )).scalar_one()
            pending_cents += int(released_sum)

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
    q = select(PaymentMockLedger)

    if operation:
        try:
            from app.models.payment_mock_ledger import MockLedgerOperation
            q = q.where(PaymentMockLedger.operation == MockLedgerOperation(operation))
        except ValueError:
            pass

    if status:
        try:
            q = q.where(PaymentMockLedger.status == MockLedgerStatus(status))
        except ValueError:
            pass

    if date_from:
        q = q.where(PaymentMockLedger.created_at >= datetime.combine(date_from, datetime.min.time()))
    if date_to:
        q = q.where(PaymentMockLedger.created_at <= datetime.combine(date_to, datetime.max.time()))

    if search:
        from sqlalchemy import or_
        q = q.where(or_(
            PaymentMockLedger.transaction_id.ilike(f"%{search}%"),
            PaymentMockLedger.receipt_reference.ilike(f"%{search}%"),
            PaymentMockLedger.description.ilike(f"%{search}%"),
        ))

    total = (await db.execute(select(func.count()).select_from(q.subquery()))).scalar_one()

    rows = (await db.execute(
        q.order_by(PaymentMockLedger.created_at.desc()).offset(offset).limit(limit)
    )).scalars().all()

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
    rows = (await db.execute(
        select(ReconciliationReport)
        .order_by(ReconciliationReport.run_date.desc())
        .limit(limit)
    )).scalars().all()
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
