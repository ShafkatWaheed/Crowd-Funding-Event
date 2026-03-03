"""Tests for worker email notification tasks."""
import pytest
from unittest.mock import patch, AsyncMock


pytestmark = pytest.mark.asyncio


# ── send_waitlist_rejected_email ──────────────────────────────────


async def test_send_waitlist_rejected_email():
    """Task sends waitlist rejection email."""
    with patch("app.worker.tasks.email_notify", new_callable=lambda: type("M", (), {"send_waitlist_rejected_email": AsyncMock()})):
        from app.worker.tasks import send_waitlist_rejected_email
        await send_waitlist_rejected_email(
            {},
            buyer_email="buyer@test.com",
            buyer_name="Test Buyer",
            event_title="Test Event",
            tier_name="General",
            amount_cents=2500,
        )


async def test_send_waitlist_rejected_email_minimal():
    """Task handles minimal args."""
    with patch("app.worker.tasks.email_notify", new_callable=lambda: type("M", (), {"send_waitlist_rejected_email": AsyncMock()})):
        from app.worker.tasks import send_waitlist_rejected_email
        await send_waitlist_rejected_email(
            {},
            buyer_email="buyer@test.com",
            buyer_name="",
            event_title="E",
            tier_name="T",
            amount_cents=0,
        )


# ── send_ticket_refund_approved_email ─────────────────────────────


async def test_send_ticket_refund_approved_email():
    """Task sends ticket refund approval email."""
    with patch("app.worker.tasks.email_notify", new_callable=lambda: type("M", (), {"send_ticket_refund_approved_email": AsyncMock()})):
        from app.worker.tasks import send_ticket_refund_approved_email
        await send_ticket_refund_approved_email(
            {},
            buyer_email="buyer@test.com",
            buyer_name="Buyer",
            event_title="Event",
            tier_name="VIP",
            amount_cents=5000,
            receipt_number="TR-001",
        )


# ── send_waitlist_approved_email ──────────────────────────────────


async def test_send_waitlist_approved_email():
    """Task sends waitlist approval email with ticket code."""
    with patch("app.worker.tasks.email_notify", new_callable=lambda: type("M", (), {"send_waitlist_approved_email": AsyncMock()})):
        from app.worker.tasks import send_waitlist_approved_email
        await send_waitlist_approved_email(
            {},
            buyer_email="buyer@test.com",
            buyer_name="Buyer",
            event_title="Event",
            tier_name="General",
            amount_cents=1000,
            ticket_code="TKT-123",
            event_date="2026-06-01",
        )


# ── send_sponsor_bid_approved_email ──────────────────────────────


async def test_send_sponsor_bid_approved_email():
    """Task sends sponsor bid approval email."""
    with patch("app.worker.tasks.email_notify", new_callable=lambda: type("M", (), {"send_sponsor_bid_approved_email": AsyncMock()})):
        from app.worker.tasks import send_sponsor_bid_approved_email
        await send_sponsor_bid_approved_email(
            {},
            sponsor_email="sponsor@test.com",
            sponsor_name="Sponsor Corp",
            event_title="Big Event",
            category_name="Gold",
            bid_amount_cents=10000,
        )


# ── send_sponsor_bid_rejected_email ──────────────────────────────


async def test_send_sponsor_bid_rejected_email():
    """Task sends sponsor bid rejection email."""
    with patch("app.worker.tasks.email_notify", new_callable=lambda: type("M", (), {"send_sponsor_bid_rejected_email": AsyncMock()})):
        from app.worker.tasks import send_sponsor_bid_rejected_email
        await send_sponsor_bid_rejected_email(
            {},
            sponsor_email="sponsor@test.com",
            sponsor_name="Sponsor Corp",
            event_title="Big Event",
            category_name="Gold",
            bid_amount_cents=5000,
        )


# ── send_sponsor_refund_email ─────────────────────────────────────


async def test_send_sponsor_refund_email():
    """Task sends sponsor refund email."""
    with patch("app.worker.tasks.email_notify", new_callable=lambda: type("M", (), {"send_sponsor_refund_email": AsyncMock()})):
        from app.worker.tasks import send_sponsor_refund_email
        await send_sponsor_refund_email(
            {},
            sponsor_email="sponsor@test.com",
            sponsor_name="Sponsor Corp",
            event_title="Event",
            category_name="Silver",
            refunded_cents=7500,
            receipt_number="SP-001",
        )


async def test_send_sponsor_refund_email_no_receipt():
    """Task handles no receipt number."""
    with patch("app.worker.tasks.email_notify", new_callable=lambda: type("M", (), {"send_sponsor_refund_email": AsyncMock()})):
        from app.worker.tasks import send_sponsor_refund_email
        await send_sponsor_refund_email(
            {},
            sponsor_email="sponsor@test.com",
            sponsor_name="",
            event_title="Event",
            category_name="Bronze",
            refunded_cents=3000,
            receipt_number=None,
        )
