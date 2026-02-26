"""
Stripe webhook handler for dispute events.
"""
import logging

from fastapi import APIRouter, Header, Request

from app.dependencies import DbSession
from app.models.dispute import Dispute, DisputeStatus
from app.models.escrow import EscrowStatus, FundEscrow, SponsorEscrow, TicketEscrow
from app.services import platform_settings as settings_svc

from sqlalchemy import select

router = APIRouter()
log = logging.getLogger(__name__)


async def _freeze_escrows(db, event_id: int) -> None:
    for model in (FundEscrow, TicketEscrow, SponsorEscrow):
        esc = (await db.execute(
            select(model).where(model.event_id == event_id)
        )).scalar_one_or_none()
        if esc and esc.status not in (EscrowStatus.frozen, EscrowStatus.fully_released):
            esc.status = EscrowStatus.frozen


async def _unfreeze_escrows(db, event_id: int) -> None:
    for model in (FundEscrow, TicketEscrow, SponsorEscrow):
        esc = (await db.execute(
            select(model).where(model.event_id == event_id)
        )).scalar_one_or_none()
        if esc and esc.status == EscrowStatus.frozen:
            if esc.stage3_released_at:
                esc.status = EscrowStatus.fully_released
            elif esc.stage1_released_at:
                esc.status = EscrowStatus.partially_released
            else:
                esc.status = EscrowStatus.holding


@router.post("/webhooks/stripe")
async def stripe_webhook(
    request: Request,
    db: DbSession,
    stripe_signature: str | None = Header(None, alias="Stripe-Signature"),
):
    body = await request.body()
    mock_mode = await settings_svc.get_bool(db, "payment_mock_enabled")

    if not mock_mode:
        secret = await settings_svc.get_str(db, "stripe_webhook_secret")
        if secret:
            try:
                import stripe
                event = stripe.Webhook.construct_event(body, stripe_signature or "", secret)
            except Exception as exc:
                log.warning("Stripe webhook signature verification failed: %s", exc)
                from fastapi.responses import JSONResponse
                return JSONResponse({"error": "invalid signature"}, status_code=400)
        else:
            import json
            event = json.loads(body)
    else:
        import json
        event = json.loads(body)

    event_type = event.get("type", "")

    if event_type == "charge.dispute.created":
        data = event.get("data", {}).get("object", {})
        stripe_dispute_id = data.get("id", "")
        charge_id = data.get("charge", "")
        amount = data.get("amount", 0)
        reason = data.get("reason", "product_not_received")

        existing = (await db.execute(
            select(Dispute).where(Dispute.stripe_dispute_id == stripe_dispute_id)
        )).scalar_one_or_none()
        if existing:
            return {"ok": True, "message": "duplicate"}

        metadata = data.get("metadata", {}) or {}
        event_id = metadata.get("event_id")
        user_id = int(metadata.get("user_id", 0))

        dispute = Dispute(
            stripe_dispute_id=stripe_dispute_id,
            transaction_id=charge_id,
            event_id=int(event_id) if event_id else None,
            user_id=user_id,
            amount_cents=amount,
            reason=reason,
        )
        db.add(dispute)

        if event_id:
            await _freeze_escrows(db, int(event_id))

        await db.flush()
        log.info("Dispute created from webhook: %s", stripe_dispute_id)

    elif event_type == "charge.dispute.closed":
        data = event.get("data", {}).get("object", {})
        stripe_dispute_id = data.get("id", "")
        status = data.get("status", "")

        dispute = (await db.execute(
            select(Dispute).where(Dispute.stripe_dispute_id == stripe_dispute_id)
        )).scalar_one_or_none()
        if dispute:
            from datetime import datetime, timezone
            dispute.resolved_at = datetime.now(timezone.utc)
            if status == "won":
                dispute.status = DisputeStatus.won
                if dispute.event_id:
                    await _unfreeze_escrows(db, dispute.event_id)
            else:
                dispute.status = DisputeStatus.lost
            await db.flush()
            log.info("Dispute resolved from webhook: %s -> %s", stripe_dispute_id, status)

    return {"ok": True}
