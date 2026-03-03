"""
Banking service: business logic for payment info, bank accounts,
email templates, and disputes. Extracted from banking route.
"""
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.logger import get_logger
from app.models.dispute import Dispute, DisputeStatus
from app.models.email_template import EmailTemplate
from app.models.escrow import EscrowStatus
from app.models.notification import NotificationType
from app.models.payment_info import BankVerificationStatus, OrganizerBankAccount, UserPaymentInfo
from app.repositories.banking_repo import banking_repo
from app.repositories.email_template_repo import email_template_repo
from app.services import audit as audit_svc
from app.services import encryption as enc
from app.services import notification_service as notif_svc
from app.services import platform_settings as settings_svc

logger = get_logger("service.banking")


# ═══════════════════════════════════════════
#  Payment Info
# ═══════════════════════════════════════════

async def upsert_payment_info(
    db: AsyncSession,
    user_id: int,
    *,
    card_holder_name: str | None = None,
    card_last_four: str | None = None,
    card_brand: str | None = None,
    billing_address: str | None = None,
    payment_method_token: str | None = None,
) -> UserPaymentInfo:
    """Create or update a user's payment info and flush."""
    info = await banking_repo.get_payment_info(db, user_id)
    if not info:
        info = UserPaymentInfo(user_id=user_id)
        await banking_repo.create_payment_info(db, info)
    if card_holder_name is not None:
        info.card_holder_name = card_holder_name
    if card_last_four is not None:
        info.card_last_four = card_last_four
    if card_brand is not None:
        info.card_brand = card_brand
    if billing_address is not None:
        info.billing_address = billing_address
    if payment_method_token is not None:
        info.payment_method_token = payment_method_token
    await banking_repo.flush(db)
    return info


# ═══════════════════════════════════════════
#  Bank Account
# ═══════════════════════════════════════════

async def upsert_bank_account(
    db: AsyncSession,
    user_id: int,
    *,
    institution_number: str,
    transit_number: str,
    account_number: str,
    account_holder: str,
    payout_schedule: str | None = None,
    payout_day: int | None = None,
    min_payout_cents: int | None = None,
) -> OrganizerBankAccount:
    """Create or update an organizer bank account, notify, and enqueue verification."""
    acct = await banking_repo.get_bank_account(db, user_id)
    if not acct:
        acct = OrganizerBankAccount(
            user_id=user_id,
            institution_number_encrypted=enc.encrypt(institution_number),
            transit_number_encrypted=enc.encrypt(transit_number),
            account_number_encrypted=enc.encrypt(account_number),
            account_holder_encrypted=enc.encrypt(account_holder),
        )
        await banking_repo.create_bank_account(db, acct)
    else:
        acct.institution_number_encrypted = enc.encrypt(institution_number)
        acct.transit_number_encrypted = enc.encrypt(transit_number)
        acct.account_number_encrypted = enc.encrypt(account_number)
        acct.account_holder_encrypted = enc.encrypt(account_holder)

    acct.verified = False
    acct.verification_status = BankVerificationStatus.pending
    acct.rejection_reason = None

    if payout_schedule:
        acct.payout_schedule = payout_schedule
    if payout_day is not None:
        acct.payout_day = payout_day
    if min_payout_cents is not None:
        acct.min_payout_cents = min_payout_cents
    await banking_repo.flush(db)

    await notif_svc.create_notification(
        db, user_id=user_id,
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

    return acct


async def verify_bank_account(
    db: AsyncSession,
    user_id: int,
    admin_id: int,
) -> OrganizerBankAccount:
    """Admin marks a bank account as verified."""
    from app.core.exceptions import NotFoundError

    acct = await banking_repo.get_bank_account(db, user_id)
    if not acct:
        raise NotFoundError("Bank account not found for user", user_id)

    acct.verified = True
    acct.verification_status = BankVerificationStatus.verified
    acct.rejection_reason = None
    await banking_repo.flush(db)

    await notif_svc.create_notification(
        db, user_id=user_id,
        type=NotificationType.bank_verified,
        title="Bank Account Verified",
        message="Your bank account has been verified. Payouts can now proceed.",
        data={"bank_account_id": acct.id},
    )
    await audit_svc.log_action(
        db, admin_id=admin_id, action="bank_account_verify",
        target_type="bank_account", target_id=user_id,
    )
    return acct


async def reject_bank_account(
    db: AsyncSession,
    user_id: int,
    admin_id: int,
    reason: str,
) -> OrganizerBankAccount:
    """Admin rejects a bank account verification."""
    from app.core.exceptions import NotFoundError

    acct = await banking_repo.get_bank_account(db, user_id)
    if not acct:
        raise NotFoundError("Bank account not found for user", user_id)

    acct.verified = False
    acct.verification_status = BankVerificationStatus.rejected
    acct.rejection_reason = reason
    await banking_repo.flush(db)

    await notif_svc.create_notification(
        db, user_id=user_id,
        type=NotificationType.bank_verification_pending,
        title="Bank Account Rejected",
        message=f"Your bank account verification was rejected: {reason}. Please update your details.",
        data={"bank_account_id": acct.id, "reason": reason},
    )
    await audit_svc.log_action(
        db, admin_id=admin_id, action="bank_account_reject",
        target_type="bank_account", target_id=user_id,
        details={"reason": reason},
    )
    return acct


# ═══════════════════════════════════════════
#  Email Templates
# ═══════════════════════════════════════════

async def upsert_email_template(
    db: AsyncSession,
    key: str,
    *,
    subject: str | None = None,
    body_html: str | None = None,
    is_active: bool | None = None,
) -> EmailTemplate:
    """Create or update an email template."""
    tmpl = await email_template_repo.get_by_key(db, key)
    if not tmpl:
        tmpl = EmailTemplate(template_key=key, subject="", body_html="", variables="[]")
        await email_template_repo.create(db, tmpl)
    if subject is not None:
        tmpl.subject = subject
    if body_html is not None:
        tmpl.body_html = body_html
    if is_active is not None:
        tmpl.is_active = is_active
    await email_template_repo.flush(db)
    return tmpl


async def reset_email_template(db: AsyncSession, key: str) -> None:
    """Delete a customized email template, resetting to default."""
    tmpl = await email_template_repo.get_by_key(db, key)
    if tmpl:
        await email_template_repo.delete(db, tmpl)


async def reset_all_email_templates(db: AsyncSession) -> int:
    """Delete all customized email templates, resetting to defaults."""
    return await email_template_repo.delete_all(db)


# ═══════════════════════════════════════════
#  Disputes
# ═══════════════════════════════════════════

async def create_dispute(
    db: AsyncSession,
    *,
    transaction_id: str,
    event_id: int | None,
    user_id: int,
    amount_cents: int,
    reason: str,
) -> Dispute:
    """Create a dispute and freeze associated escrows if linked to an event."""
    dispute = Dispute(
        transaction_id=transaction_id,
        event_id=event_id,
        user_id=user_id,
        amount_cents=amount_cents,
        reason=reason,
    )
    await banking_repo.create_dispute(db, dispute)

    if event_id:
        fe, te, se = await banking_repo.get_escrow_by_event(db, event_id)
        if fe and fe.status not in (EscrowStatus.frozen, EscrowStatus.fully_released):
            fe.status = EscrowStatus.frozen
        if te and te.status not in (EscrowStatus.frozen, EscrowStatus.fully_released):
            te.status = EscrowStatus.frozen
        if se and se.status not in (EscrowStatus.frozen, EscrowStatus.fully_released):
            se.status = EscrowStatus.frozen

    await banking_repo.flush(db)
    return dispute


async def resolve_dispute(
    db: AsyncSession,
    dispute_id: int,
    *,
    outcome: str,
    notes: str | None,
    admin_id: int,
) -> Dispute:
    """Resolve a dispute (won/lost). Unfreeze escrows if won."""
    from app.core.exceptions import NotFoundError

    dispute = await banking_repo.get_dispute(db, dispute_id)
    if not dispute:
        raise NotFoundError("Dispute", dispute_id)

    now = datetime.now(timezone.utc)
    dispute.status = DisputeStatus.won if outcome == "won" else DisputeStatus.lost
    dispute.resolved_at = now
    dispute.outcome_notes = notes

    if outcome == "won" and dispute.event_id:
        fe, te, se = await banking_repo.get_escrow_by_event(db, dispute.event_id)
        for esc in (fe, te, se):
            if esc and esc.status == EscrowStatus.frozen:
                if esc.stage3_released_at:
                    esc.status = EscrowStatus.fully_released
                elif esc.stage1_released_at:
                    esc.status = EscrowStatus.partially_released
                else:
                    esc.status = EscrowStatus.holding

    await banking_repo.flush(db)
    await audit_svc.log_action(
        db, admin_id=admin_id, action="dispute_resolve",
        target_type="dispute", target_id=dispute_id,
        details={"outcome": outcome, "notes": notes},
    )
    return dispute


async def submit_dispute_evidence(db: AsyncSession, dispute_id: int) -> Dispute:
    """Mark a dispute as evidence_submitted."""
    from app.core.exceptions import NotFoundError

    dispute = await banking_repo.get_dispute(db, dispute_id)
    if not dispute:
        raise NotFoundError("Dispute", dispute_id)
    dispute.status = DisputeStatus.evidence_submitted
    dispute.evidence_submitted_at = datetime.now(timezone.utc)
    await banking_repo.flush(db)
    return dispute


async def accept_dispute_loss(db: AsyncSession, dispute_id: int) -> Dispute:
    """Accept a dispute loss."""
    from app.core.exceptions import NotFoundError

    dispute = await banking_repo.get_dispute(db, dispute_id)
    if not dispute:
        raise NotFoundError("Dispute", dispute_id)
    dispute.status = DisputeStatus.lost
    dispute.resolved_at = datetime.now(timezone.utc)
    await banking_repo.flush(db)
    return dispute


async def simulate_mock_dispute(
    db: AsyncSession,
    transaction_id: str,
    admin_id: int,
) -> Dispute:
    """Create a mock dispute for testing."""
    ledger_entry = await banking_repo.get_mock_ledger_by_transaction_id(db, transaction_id)
    amount = ledger_entry.amount_cents if ledger_entry else 5000
    dispute = Dispute(
        transaction_id=transaction_id,
        stripe_dispute_id=f"dp_mock_{transaction_id}",
        amount_cents=amount,
        fee_cents=1500,
        user_id=admin_id,
        reason="fraudulent",
    )
    await banking_repo.create_dispute(db, dispute)
    await audit_svc.log_action(
        db, admin_id=admin_id, action="dispute_create",
        target_type="dispute", target_id=dispute.id,
        details={"transaction_id": transaction_id},
    )
    return dispute


async def handle_dispute_webhook(
    db: AsyncSession,
    stripe_dispute_id: str,
    status: str,
) -> None:
    """Handle Stripe dispute.closed webhook — resolve and unfreeze escrows if won."""
    dispute = await banking_repo.get_dispute_by_stripe_id(db, stripe_dispute_id)
    if not dispute:
        return

    now = datetime.now(timezone.utc)
    dispute.resolved_at = now
    if status == "won":
        dispute.status = DisputeStatus.won
    else:
        dispute.status = DisputeStatus.lost

    if dispute.event_id and status == "won":
        fe, te, se = await banking_repo.get_escrow_by_event(db, dispute.event_id)
        for esc in (fe, te, se):
            if esc and esc.status == EscrowStatus.frozen:
                if esc.stage3_released_at:
                    esc.status = EscrowStatus.fully_released
                elif esc.stage1_released_at:
                    esc.status = EscrowStatus.partially_released
                else:
                    esc.status = EscrowStatus.holding

    await banking_repo.flush(db)
