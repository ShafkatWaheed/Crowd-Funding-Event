"""
Stripe webhook handler for dispute events.
"""
from fastapi import APIRouter, Header, Request

from app.dependencies import DbSession
from app.logger import get_logger
from app.services import platform_settings as settings_svc

router = APIRouter()
log = get_logger(__name__)


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
        metadata = data.get("metadata", {}) or {}
        raw_uid = metadata.get("user_id")

        from app.services import banking_service as banking_svc
        dispute = await banking_svc.handle_dispute_created_webhook(
            db,
            stripe_dispute_id=stripe_dispute_id,
            charge_id=data.get("charge", ""),
            amount=data.get("amount", 0),
            reason=data.get("reason", "product_not_received"),
            event_id=metadata.get("event_id"),
            user_id=int(raw_uid) if raw_uid else None,
        )
        if dispute is None:
            return {"ok": True, "message": "duplicate"}
        log.info("Dispute created from webhook: %s", stripe_dispute_id)

    elif event_type == "charge.dispute.closed":
        data = event.get("data", {}).get("object", {})
        stripe_dispute_id = data.get("id", "")
        status = data.get("status", "")

        from app.services import banking_service as banking_svc
        await banking_svc.handle_dispute_webhook(db, stripe_dispute_id, status)
        log.info("Dispute resolved from webhook: %s -> %s", stripe_dispute_id, status)

    return {"ok": True}
