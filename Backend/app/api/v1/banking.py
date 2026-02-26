"""
Banking & financial APIs: payment info, bank accounts, escrow overview,
mock ledger, email templates, disputes, reconciliation, tax, payouts.
"""
from datetime import date, datetime, timezone

from fastapi import APIRouter, Body, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dependencies import CurrentUser, DbSession, ReadDbSession, require_role
from app.models.dispute import Dispute, DisputeStatus
from app.models.email_mock_log import EmailMockLog
from app.models.email_template import EmailTemplate
from app.models.escrow import EscrowStatus, FundEscrow, TicketEscrow, SponsorEscrow
from app.models.ledger_entry import LedgerEntry
from app.models.payment_info import OrganizerBankAccount, UserPaymentInfo
from app.models.payment_mock_ledger import MockLedgerStatus, PaymentMockLedger
from app.models.reconciliation import ReconciliationReport
from app.models.user import User, UserRole
from app.services import encryption as enc
from app.services import ledger as ledger_svc
from app.services import platform_settings as settings_svc

router = APIRouter()


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


@router.get("/me/payment-info", response_model=PaymentInfoResponse)
async def get_payment_info(db: ReadDbSession, current_user: CurrentUser):
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
async def update_payment_info(body: PaymentInfoUpdate, db: DbSession, current_user: CurrentUser):
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
    bank_name_masked: str | None = None
    account_last_four: str | None = None
    account_holder_masked: str | None = None
    routing_masked: str | None = None
    swift_masked: str | None = None
    verified: bool = False
    payout_schedule: str = "weekly"
    payout_day: int = 1
    min_payout_cents: int = 2500
    has_bank_account: bool = False


class BankAccountUpdate(BaseModel):
    bank_name: str
    account_number: str
    routing_number: str
    account_holder: str
    swift_code: str | None = None
    payout_schedule: str | None = None
    payout_day: int | None = None
    min_payout_cents: int | None = None


@router.get("/me/bank-account", response_model=BankAccountResponse)
async def get_bank_account(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.organizer)),
):
    acct = (await db.execute(
        select(OrganizerBankAccount).where(OrganizerBankAccount.user_id == current_user.id)
    )).scalar_one_or_none()
    if not acct:
        return BankAccountResponse()
    return BankAccountResponse(
        bank_name_masked=enc.mask_value(enc.decrypt(acct.bank_name_encrypted)),
        account_last_four=enc.decrypt(acct.account_number_encrypted)[-4:],
        account_holder_masked=enc.mask_value(enc.decrypt(acct.account_holder_encrypted)),
        routing_masked=enc.mask_value(enc.decrypt(acct.routing_number_encrypted)),
        swift_masked=enc.mask_value(enc.decrypt(acct.swift_code_encrypted)) if acct.swift_code_encrypted else None,
        verified=acct.verified,
        payout_schedule=acct.payout_schedule,
        payout_day=acct.payout_day,
        min_payout_cents=acct.min_payout_cents,
        has_bank_account=True,
    )


@router.put("/me/bank-account", response_model=BankAccountResponse)
async def update_bank_account(
    body: BankAccountUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.organizer)),
):
    acct = (await db.execute(
        select(OrganizerBankAccount).where(OrganizerBankAccount.user_id == current_user.id)
    )).scalar_one_or_none()
    if not acct:
        acct = OrganizerBankAccount(user_id=current_user.id,
                                     bank_name_encrypted=enc.encrypt(body.bank_name),
                                     account_number_encrypted=enc.encrypt(body.account_number),
                                     routing_number_encrypted=enc.encrypt(body.routing_number),
                                     account_holder_encrypted=enc.encrypt(body.account_holder))
        db.add(acct)
    else:
        acct.bank_name_encrypted = enc.encrypt(body.bank_name)
        acct.account_number_encrypted = enc.encrypt(body.account_number)
        acct.routing_number_encrypted = enc.encrypt(body.routing_number)
        acct.account_holder_encrypted = enc.encrypt(body.account_holder)
    if body.swift_code:
        acct.swift_code_encrypted = enc.encrypt(body.swift_code)
    if body.payout_schedule:
        acct.payout_schedule = body.payout_schedule
    if body.payout_day is not None:
        acct.payout_day = body.payout_day
    if body.min_payout_cents is not None:
        acct.min_payout_cents = body.min_payout_cents
    await db.flush()
    return BankAccountResponse(
        bank_name_masked=enc.mask_value(body.bank_name),
        account_last_four=body.account_number[-4:],
        account_holder_masked=enc.mask_value(body.account_holder),
        routing_masked=enc.mask_value(body.routing_number),
        swift_masked=enc.mask_value(body.swift_code) if body.swift_code else None,
        verified=acct.verified,
        payout_schedule=acct.payout_schedule,
        payout_day=acct.payout_day,
        min_payout_cents=acct.min_payout_cents,
        has_bank_account=True,
    )


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
    platform_account_bank_name: str | None = None
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
    disputes_open_count: int = 0
    disputes_total_amount_cents: int = 0
    last_reconciliation_status: str | None = None
    last_reconciliation_delta_cents: int = 0
    mock_mode_active: bool = False


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

    platform_bank_name: str | None = None
    platform_last_four: str | None = None
    if platform_configured:
        raw_bank = await settings_svc.get_str(db, "platform_holding_bank_name")
        raw_acct = await settings_svc.get_str(db, "platform_holding_account_number")
        if raw_bank:
            try:
                platform_bank_name = enc.mask_value(enc.decrypt(raw_bank))
            except Exception:
                platform_bank_name = raw_bank
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

    # Commission breakdown by source (ticket / funding / sponsor)
    source_q = (
        select(
            LedgerEntry.description,
            func.coalesce(func.sum(LedgerEntry.amount_cents), 0),
        )
        .where(LedgerEntry.account == "platform_commission", LedgerEntry.entry_type == "credit")
        .group_by(LedgerEntry.description)
    )
    source_rows = (await db.execute(source_q)).all()
    commission_by_source = {"ticket": 0, "funding": 0, "sponsor": 0}
    for desc, amt in source_rows:
        desc_lower = (desc or "").lower()
        if "ticket" in desc_lower:
            commission_by_source["ticket"] += int(amt)
        elif "pledge" in desc_lower or "fund" in desc_lower:
            commission_by_source["funding"] += int(amt)
        elif "sponsor" in desc_lower:
            commission_by_source["sponsor"] += int(amt)
        else:
            commission_by_source["ticket"] += int(amt)

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

    return BankingOverviewResponse(
        platform_account_configured=platform_configured,
        platform_account_bank_name=platform_bank_name,
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
        commission_by_source=commission_by_source,
        tax_collected_total_cents=tax_total,
        disputes_open_count=int(disputes[0]),
        disputes_total_amount_cents=int(disputes[1]),
        last_reconciliation_status=last_recon.status if last_recon else None,
        last_reconciliation_delta_cents=last_recon.delta_cents if last_recon else 0,
        mock_mode_active=mock_active,
    )


# ═══════════════════════════════════════════
#  Admin Platform Holding Account Config
# ═══════════════════════════════════════════

class PlatformAccountUpdate(BaseModel):
    bank_name: str
    account_number: str
    routing_number: str
    account_holder: str


class PlatformAccountResponse(BaseModel):
    bank_name_masked: str | None = None
    account_last_four: str | None = None
    routing_masked: str | None = None
    account_holder_masked: str | None = None
    configured: bool = False


@router.put("/admin/platform-account", response_model=PlatformAccountResponse)
async def update_platform_account(
    body: PlatformAccountUpdate,
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    await settings_svc.set_value(db, "platform_holding_bank_name", enc.encrypt(body.bank_name))
    await settings_svc.set_value(db, "platform_holding_account_number", enc.encrypt(body.account_number))
    await settings_svc.set_value(db, "platform_holding_routing_number", enc.encrypt(body.routing_number))
    await settings_svc.set_value(db, "platform_holding_account_holder", enc.encrypt(body.account_holder))
    await settings_svc.set_value(db, "platform_holding_configured", "true")
    return PlatformAccountResponse(
        bank_name_masked=enc.mask_value(body.bank_name),
        account_last_four=body.account_number[-4:],
        routing_masked=enc.mask_value(body.routing_number),
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
    raw_bank = await settings_svc.get_str(db, "platform_holding_bank_name")
    raw_acct = await settings_svc.get_str(db, "platform_holding_account_number")
    raw_routing = await settings_svc.get_str(db, "platform_holding_routing_number")
    raw_holder = await settings_svc.get_str(db, "platform_holding_account_holder")
    try:
        bank_name = enc.decrypt(raw_bank) if raw_bank else None
        acct_num = enc.decrypt(raw_acct) if raw_acct else None
        routing = enc.decrypt(raw_routing) if raw_routing else None
        holder = enc.decrypt(raw_holder) if raw_holder else None
    except Exception:
        bank_name = raw_bank
        acct_num = raw_acct
        routing = raw_routing
        holder = raw_holder
    return PlatformAccountResponse(
        bank_name_masked=enc.mask_value(bank_name) if bank_name else None,
        account_last_four=acct_num[-4:] if acct_num else None,
        routing_masked=enc.mask_value(routing) if routing else None,
        account_holder_masked=enc.mask_value(holder) if holder else None,
        configured=True,
    )


# ═══════════════════════════════════════════
#  Admin Email Templates
# ═══════════════════════════════════════════

class EmailTemplateResponse(BaseModel):
    template_key: str
    subject: str
    body_html: str
    variables: str
    is_active: bool


class EmailTemplateUpdate(BaseModel):
    subject: str | None = None
    body_html: str | None = None
    is_active: bool | None = None


@router.get("/admin/email-templates")
async def list_email_templates(
    db: ReadDbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    rows = (await db.execute(
        select(EmailTemplate).order_by(EmailTemplate.template_key)
    )).scalars().all()
    return [
        EmailTemplateResponse(
            template_key=t.template_key, subject=t.subject,
            body_html=t.body_html, variables=t.variables, is_active=t.is_active,
        )
        for t in rows
    ]


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

@router.post("/admin/mock/clear")
async def clear_mock_data(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
    from sqlalchemy import delete
    await db.execute(delete(PaymentMockLedger))
    await db.execute(delete(EmailMockLog))
    await db.flush()
    return {"ok": True, "message": "All mock data cleared"}


@router.post("/admin/mock/settle-all")
async def settle_all_pending(
    db: DbSession,
    current_user: User = Depends(require_role(UserRole.admin)),
):
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
#  Cities endpoint (for city filter autocomplete)
# ═══════════════════════════════════════════

@router.get("/events/cities")
async def list_cities(db: ReadDbSession):
    from app.models.venue import Venue
    rows = (await db.execute(
        select(Venue.city).where(Venue.city.isnot(None), Venue.city != "")
        .distinct().order_by(Venue.city)
    )).scalars().all()
    return {"cities": list(rows)}


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
