"""
Phase 5 — Email stack tests: email_service, email_templates, email_notifications.

Targets missing coverage lines to push each module above 70%.
"""
from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.email_template import EmailTemplate
from app.models.funding import Funding, FundingStatus
from app.models.registration import Registration, RegistrationStatus
from app.models.ticket import TicketSale, TicketSaleStatus, TicketTier
from app.models.user import User

# ═══════════════════════════════════════════════════════════════════════════
# Helpers: clear caches between tests
# ═══════════════════════════════════════════════════════════════════════════

from app.services.email_service import _backend_cache
from app.services.email_templates import _branding_cache


@pytest.fixture(autouse=True)
def _clear_email_caches():
    """Reset backend + branding caches before every test."""
    _backend_cache.clear()
    _branding_cache.clear()
    yield
    _backend_cache.clear()
    _branding_cache.clear()


# ###########################################################################
#  PART 1 — email_service.py
# ###########################################################################


class TestSendGridBackend:
    """Cover SendGridBackend.send() success / failure / exception and send_bulk()."""

    def _make_backend(self):
        """Build a SendGridBackend with mocked internals."""
        from app.services.email_service import SendGridBackend

        with patch("app.services.email_service.settings") as mock_settings:
            mock_settings.EMAIL_API_KEY = "test-key"
            mock_settings.EMAIL_FROM_ADDRESS = "from@test.com"
            mock_settings.EMAIL_FROM_NAME = "Test"
            with patch(
                "app.services.email_service.SendGridBackend.__init__",
                return_value=None,
            ):
                backend = SendGridBackend()
                backend._client = MagicMock()
        return backend

    @pytest.mark.asyncio
    async def test_send_success(self):
        backend = self._make_backend()
        mock_resp = MagicMock()
        mock_resp.status_code = 202
        backend._client.send = MagicMock(return_value=mock_resp)

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_FROM_ADDRESS = "from@test.com"
            ms.EMAIL_FROM_NAME = "Test"
            result = await backend.send("user@test.com", "User", "Subject", "<p>hi</p>")

        assert result is True

    @pytest.mark.asyncio
    async def test_send_failure_non_200(self):
        backend = self._make_backend()
        mock_resp = MagicMock()
        mock_resp.status_code = 400
        mock_resp.body = "Bad Request"
        backend._client.send = MagicMock(return_value=mock_resp)

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_FROM_ADDRESS = "from@test.com"
            ms.EMAIL_FROM_NAME = "Test"
            result = await backend.send("user@test.com", "User", "Subject", "<p>hi</p>")

        assert result is False

    @pytest.mark.asyncio
    async def test_send_exception(self):
        backend = self._make_backend()
        backend._client.send = MagicMock(side_effect=Exception("network error"))

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_FROM_ADDRESS = "from@test.com"
            ms.EMAIL_FROM_NAME = "Test"
            result = await backend.send("user@test.com", "User", "Subject", "<p>hi</p>")

        assert result is False

    @pytest.mark.asyncio
    async def test_send_bulk(self):
        backend = self._make_backend()
        mock_resp = MagicMock()
        mock_resp.status_code = 202
        backend._client.send = MagicMock(return_value=mock_resp)

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_FROM_ADDRESS = "from@test.com"
            ms.EMAIL_FROM_NAME = "Test"
            recipients = [
                {"email": "a@test.com", "name": "A"},
                {"email": "b@test.com", "name": "B"},
                {"email": "c@test.com"},
            ]
            count = await backend.send_bulk(recipients, "Subj", "<p>body</p>")

        assert count == 3

    @pytest.mark.asyncio
    async def test_send_bulk_partial_failure(self):
        backend = self._make_backend()
        good_resp = MagicMock()
        good_resp.status_code = 202
        bad_resp = MagicMock()
        bad_resp.status_code = 400
        bad_resp.body = "Bad"
        backend._client.send = MagicMock(side_effect=[good_resp, bad_resp, good_resp])

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_FROM_ADDRESS = "from@test.com"
            ms.EMAIL_FROM_NAME = "Test"
            recipients = [
                {"email": "a@test.com", "name": "A"},
                {"email": "b@test.com", "name": "B"},
                {"email": "c@test.com", "name": "C"},
            ]
            count = await backend.send_bulk(recipients, "Subj", "<p>body</p>")

        assert count == 2


class TestResolveBackend:
    """Cover _resolve_backend() — reads platform settings then falls back to env."""

    @pytest.mark.asyncio
    async def test_resolve_backend_from_platform_settings(self):
        from app.services.email_service import _resolve_backend, ConsoleBackend

        mock_session = AsyncMock(spec=AsyncSession)

        @asynccontextmanager
        async def mock_cm():
            yield mock_session

        mock_session_maker = MagicMock(side_effect=lambda: mock_cm())

        with patch(
            "app.db.base.async_session_maker",
            mock_session_maker,
        ):
            with patch(
                "app.services.platform_settings.get_str",
                new_callable=AsyncMock,
                return_value="console",
            ):
                backend = await _resolve_backend()

        assert isinstance(backend, ConsoleBackend)

    @pytest.mark.asyncio
    async def test_resolve_backend_fallback_to_env(self):
        from app.services.email_service import _resolve_backend, ConsoleBackend

        # Force the platform settings path to fail
        with patch(
            "app.db.base.async_session_maker",
            side_effect=Exception("no db"),
        ):
            with patch("app.services.email_service.settings") as ms:
                ms.EMAIL_PROVIDER = "console"
                backend = await _resolve_backend()

        assert isinstance(backend, ConsoleBackend)


class TestLogMockEmail:
    """Cover _log_mock_email() — writes to EmailMockLog with bounce sim."""

    @pytest.mark.asyncio
    async def test_log_mock_email_sent(self):
        from app.services.email_service import _log_mock_email

        mock_session = AsyncMock()
        mock_session.add = MagicMock()
        mock_session.commit = AsyncMock()

        @asynccontextmanager
        async def mock_cm():
            yield mock_session

        mock_session_maker = MagicMock(side_effect=lambda: mock_cm())

        with patch("app.db.base.async_session_maker", mock_session_maker):
            with patch(
                "app.services.platform_settings.get_int",
                new_callable=AsyncMock,
                return_value=0,
            ):
                status = await _log_mock_email("user@test.com", "Subject", "<p>hi</p>")

        assert status == "sent"
        mock_session.add.assert_called_once()
        mock_session.commit.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_log_mock_email_bounced(self):
        from app.services.email_service import _log_mock_email

        mock_session = AsyncMock()
        mock_session.add = MagicMock()
        mock_session.commit = AsyncMock()

        @asynccontextmanager
        async def mock_cm():
            yield mock_session

        mock_session_maker = MagicMock(side_effect=lambda: mock_cm())

        with patch("app.db.base.async_session_maker", mock_session_maker):
            with patch(
                "app.services.platform_settings.get_int",
                new_callable=AsyncMock,
                return_value=100,
            ):
                with patch("random.randint", return_value=1):
                    status = await _log_mock_email("user@test.com", "Subj", "<p>hi</p>")

        assert status == "bounced"

    @pytest.mark.asyncio
    async def test_log_mock_email_exception_returns_sent(self):
        from app.services.email_service import _log_mock_email

        with patch(
            "app.db.base.async_session_maker",
            side_effect=Exception("db down"),
        ):
            status = await _log_mock_email("user@test.com", "Subj", "<p>hi</p>")

        # Exception caught — returns default "sent"
        assert status == "sent"


class TestSendEmail:
    """Cover send_email() — console backend + mock bounce."""

    @pytest.mark.asyncio
    async def test_send_email_disabled(self):
        from app.services.email_service import send_email

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = False
            result = await send_email("user@test.com", "User", "Subj", "<p>hi</p>")

        assert result is False

    @pytest.mark.asyncio
    async def test_send_email_console_backend_success(self):
        from app.services.email_service import send_email, ConsoleBackend

        console = ConsoleBackend()

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            with patch(
                "app.services.email_service._resolve_backend",
                new_callable=AsyncMock,
                return_value=console,
            ):
                with patch(
                    "app.services.email_service._log_mock_email",
                    new_callable=AsyncMock,
                    return_value="sent",
                ):
                    result = await send_email(
                        "user@test.com", "User", "Subj", "<p>hi</p>"
                    )

        assert result is True

    @pytest.mark.asyncio
    async def test_send_email_console_backend_bounce(self):
        from app.services.email_service import send_email, ConsoleBackend

        console = ConsoleBackend()

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            with patch(
                "app.services.email_service._resolve_backend",
                new_callable=AsyncMock,
                return_value=console,
            ):
                with patch(
                    "app.services.email_service._log_mock_email",
                    new_callable=AsyncMock,
                    return_value="bounced",
                ):
                    result = await send_email(
                        "user@test.com", "User", "Subj", "<p>hi</p>"
                    )

        assert result is False

    @pytest.mark.asyncio
    async def test_send_email_exception(self):
        from app.services.email_service import send_email

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            with patch(
                "app.services.email_service._resolve_backend",
                new_callable=AsyncMock,
                side_effect=Exception("boom"),
            ):
                result = await send_email("user@test.com", "User", "Subj", "<p>hi</p>")

        assert result is False

    @pytest.mark.asyncio
    async def test_send_email_body_html_kwarg(self):
        """body_html overrides html_content."""
        from app.services.email_service import send_email, ConsoleBackend

        console = ConsoleBackend()

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            with patch(
                "app.services.email_service._resolve_backend",
                new_callable=AsyncMock,
                return_value=console,
            ):
                with patch(
                    "app.services.email_service._log_mock_email",
                    new_callable=AsyncMock,
                    return_value="sent",
                ) as mock_log:
                    result = await send_email(
                        "user@test.com",
                        "User",
                        "Subj",
                        body_html="<p>overridden</p>",
                    )

        assert result is True
        # _log_mock_email should receive the body_html value
        mock_log.assert_awaited_once()
        assert mock_log.call_args[0][2] == "<p>overridden</p>"


class TestSendEmailBulk:
    """Cover send_email_bulk() — console + non-console paths."""

    @pytest.mark.asyncio
    async def test_send_email_bulk_disabled(self):
        from app.services.email_service import send_email_bulk

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = False
            result = await send_email_bulk(
                [{"email": "a@test.com"}], "Subj", "<p>hi</p>"
            )

        assert result == 0

    @pytest.mark.asyncio
    async def test_send_email_bulk_empty_recipients(self):
        from app.services.email_service import send_email_bulk

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            result = await send_email_bulk([], "Subj", "<p>hi</p>")

        assert result == 0

    @pytest.mark.asyncio
    async def test_send_email_bulk_console_all_sent(self):
        from app.services.email_service import send_email_bulk, ConsoleBackend

        console = ConsoleBackend()

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            with patch(
                "app.services.email_service._resolve_backend",
                new_callable=AsyncMock,
                return_value=console,
            ):
                with patch(
                    "app.services.email_service._log_mock_email",
                    new_callable=AsyncMock,
                    return_value="sent",
                ):
                    result = await send_email_bulk(
                        [
                            {"email": "a@test.com", "name": "A"},
                            {"email": "b@test.com", "name": "B"},
                        ],
                        "Subj",
                        "<p>hi</p>",
                    )

        assert result == 2

    @pytest.mark.asyncio
    async def test_send_email_bulk_console_some_bounced(self):
        from app.services.email_service import send_email_bulk, ConsoleBackend

        console = ConsoleBackend()

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            with patch(
                "app.services.email_service._resolve_backend",
                new_callable=AsyncMock,
                return_value=console,
            ):
                with patch(
                    "app.services.email_service._log_mock_email",
                    new_callable=AsyncMock,
                    side_effect=["sent", "bounced", "sent"],
                ):
                    result = await send_email_bulk(
                        [
                            {"email": "a@test.com", "name": "A"},
                            {"email": "b@test.com", "name": "B"},
                            {"email": "c@test.com"},
                        ],
                        "Subj",
                        "<p>hi</p>",
                    )

        assert result == 2

    @pytest.mark.asyncio
    async def test_send_email_bulk_non_console_backend(self):
        from app.services.email_service import send_email_bulk

        mock_backend = AsyncMock()
        mock_backend.send_bulk = AsyncMock(return_value=3)

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            with patch(
                "app.services.email_service._resolve_backend",
                new_callable=AsyncMock,
                return_value=mock_backend,
            ):
                result = await send_email_bulk(
                    [
                        {"email": "a@test.com"},
                        {"email": "b@test.com"},
                        {"email": "c@test.com"},
                    ],
                    "Subj",
                    "<p>hi</p>",
                )

        assert result == 3

    @pytest.mark.asyncio
    async def test_send_email_bulk_exception(self):
        from app.services.email_service import send_email_bulk

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_ENABLED = True
            with patch(
                "app.services.email_service._resolve_backend",
                new_callable=AsyncMock,
                side_effect=Exception("boom"),
            ):
                result = await send_email_bulk(
                    [{"email": "a@test.com"}], "Subj", "<p>hi</p>"
                )

        assert result == 0


class TestGetEmailBackend:
    """Cover get_email_backend() factory including cache hits and unknown provider."""

    def test_console_provider(self):
        from app.services.email_service import get_email_backend, ConsoleBackend

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_PROVIDER = "console"
            backend = get_email_backend()

        assert isinstance(backend, ConsoleBackend)

    def test_unknown_provider_raises(self):
        from app.services.email_service import get_email_backend

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_PROVIDER = "unknown_provider"
            with pytest.raises(ValueError, match="Unknown EMAIL_PROVIDER"):
                get_email_backend()

    def test_cache_hit(self):
        from app.services.email_service import get_email_backend, ConsoleBackend

        with patch("app.services.email_service.settings") as ms:
            ms.EMAIL_PROVIDER = "console"
            b1 = get_email_backend()
            b2 = get_email_backend()

        assert b1 is b2

    def test_provider_override(self):
        from app.services.email_service import get_email_backend, ConsoleBackend

        backend = get_email_backend(provider_override="console")
        assert isinstance(backend, ConsoleBackend)


# ###########################################################################
#  PART 2 — email_templates.py
# ###########################################################################


class TestTryDbTemplate:
    """Cover _try_db_template() — None db, active template, inactive template, exception."""

    @pytest.mark.asyncio
    async def test_db_none_returns_none(self):
        from app.services.email_templates import _try_db_template

        result = await _try_db_template(None, "event_cancelled", {"event_title": "X"})
        assert result is None

    @pytest.mark.asyncio
    async def test_active_template_renders(self, db_session: AsyncSession):
        from app.services.email_templates import _try_db_template

        tmpl = EmailTemplate(
            template_key="test_active_tmpl",
            subject="Test Subject",
            body_html="<p>Hello {{name}}, event: {{event}}</p>",
            variables='["name", "event"]',
            is_active=True,
        )
        db_session.add(tmpl)
        await db_session.commit()

        result = await _try_db_template(
            db_session, "test_active_tmpl", {"name": "Alice", "event": "Gala"}
        )

        assert result is not None
        assert "Hello Alice" in result
        assert "event: Gala" in result

    @pytest.mark.asyncio
    async def test_inactive_template_returns_none(self, db_session: AsyncSession):
        from app.services.email_templates import _try_db_template

        tmpl = EmailTemplate(
            template_key="test_inactive_tmpl",
            subject="Sub",
            body_html="<p>{{name}}</p>",
            variables='["name"]',
            is_active=False,
        )
        db_session.add(tmpl)
        await db_session.commit()

        result = await _try_db_template(
            db_session, "test_inactive_tmpl", {"name": "Alice"}
        )

        assert result is None

    @pytest.mark.asyncio
    async def test_missing_template_returns_none(self, db_session: AsyncSession):
        from app.services.email_templates import _try_db_template

        result = await _try_db_template(
            db_session, "nonexistent_key_xyz", {"foo": "bar"}
        )
        assert result is None


class TestLoadBranding:
    """Cover load_branding() — caches logo_url and footer_text."""

    @pytest.mark.asyncio
    async def test_load_branding(self):
        from app.services.email_templates import load_branding, _branding_cache

        mock_db = AsyncMock()

        async def mock_get_str(db, key):
            return {
                "email_template_logo_url": "https://logo.png",
                "email_template_footer_text": "Custom footer text",
            }.get(key, "")

        with patch(
            "app.services.platform_settings.get_str",
            side_effect=mock_get_str,
        ):
            await load_branding(mock_db)

        assert _branding_cache["logo_url"] == "https://logo.png"
        assert _branding_cache["footer_text"] == "Custom footer text"


class TestUnregisterRefundTemplate:
    """Cover unregister_refund_template."""

    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import unregister_refund_template

        html = await unregister_refund_template(
            event_title="Test Event", refunded_cents=5000, db=None
        )
        assert "Unregistered" in html
        assert "$50.00" in html
        assert "Test Event" in html

    @pytest.mark.asyncio
    async def test_with_db_template(self, db_session: AsyncSession):
        from app.services.email_templates import unregister_refund_template

        tmpl = EmailTemplate(
            template_key="unregister_refund",
            subject="Unregistered",
            body_html="<p>Custom unregister for {{event_title}}, refund={{refunded_cents}}</p>",
            variables='["event_title","refunded_cents"]',
            is_active=True,
        )
        db_session.add(tmpl)
        await db_session.commit()

        html = await unregister_refund_template(
            event_title="DB Event", refunded_cents=3000, db=db_session
        )
        assert "Custom unregister for DB Event" in html


class TestWaitlistTicketRejectedTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import waitlist_ticket_rejected_template

        html = await waitlist_ticket_rejected_template(
            event_title="Concert", tier_name="VIP", amount_cents=10000, db=None
        )
        assert "Not Approved" in html
        assert "Concert" in html
        assert "VIP" in html
        assert "$100.00" in html

    @pytest.mark.asyncio
    async def test_free_ticket(self):
        from app.services.email_templates import waitlist_ticket_rejected_template

        html = await waitlist_ticket_rejected_template(
            event_title="Free Event", tier_name="Gen", amount_cents=0, db=None
        )
        assert "FREE" in html


class TestTicketRefundApprovedTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import ticket_refund_approved_template

        html = await ticket_refund_approved_template(
            event_title="Concert",
            tier_name="VIP",
            amount_cents=5000,
            receipt_number="REC-001",
            db=None,
        )
        assert "Ticket Refund Approved" in html
        assert "$50.00" in html
        assert "REC-001" in html

    @pytest.mark.asyncio
    async def test_no_receipt_number(self):
        from app.services.email_templates import ticket_refund_approved_template

        html = await ticket_refund_approved_template(
            event_title="Concert",
            tier_name="VIP",
            amount_cents=0,
            db=None,
        )
        assert "FREE" in html


class TestWaitlistTicketApprovedTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import waitlist_ticket_approved_template

        html = await waitlist_ticket_approved_template(
            event_title="Concert",
            tier_name="VIP",
            amount_cents=7500,
            ticket_code="TKT-123",
            event_date="Jan 01, 2026",
            db=None,
        )
        assert "You're In!" in html or "You&#x27;re In!" in html or "Approved" in html
        assert "Concert" in html
        assert "VIP" in html
        assert "$75.00" in html
        assert "TKT-123" in html

    @pytest.mark.asyncio
    async def test_free_no_code_no_date(self):
        from app.services.email_templates import waitlist_ticket_approved_template

        html = await waitlist_ticket_approved_template(
            event_title="Free Fest",
            tier_name="Gen",
            amount_cents=0,
            db=None,
        )
        assert "FREE" in html


class TestSponsorBidRejectedTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import sponsor_bid_rejected_template

        html = await sponsor_bid_rejected_template(
            event_title="Tech Conf",
            category_name="Gold",
            bid_amount_cents=50000,
            db=None,
        )
        assert "Not Accepted" in html
        assert "Tech Conf" in html
        assert "Gold" in html
        assert "$500.00" in html


class TestSponsorRefundTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import sponsor_refund_template

        html = await sponsor_refund_template(
            event_title="Event X",
            category_name="Platinum",
            refunded_cents=100000,
            receipt_number="SPR-001",
            db=None,
        )
        assert "Sponsorship Refunded" in html
        assert "$1,000.00" in html
        assert "SPR-001" in html

    @pytest.mark.asyncio
    async def test_no_receipt(self):
        from app.services.email_templates import sponsor_refund_template

        html = await sponsor_refund_template(
            event_title="Event X",
            category_name="Silver",
            refunded_cents=25000,
            db=None,
        )
        assert "Sponsorship Refunded" in html
        assert "$250.00" in html


class TestSponsorBidApprovedTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import sponsor_bid_approved_template

        html = await sponsor_bid_approved_template(
            event_title="Gala",
            category_name="Diamond",
            bid_amount_cents=200000,
            db=None,
        )
        assert "Accepted" in html
        assert "Gala" in html
        assert "Diamond" in html
        assert "$2,000.00" in html


class TestEventCancelledTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded_with_date(self):
        from app.services.email_templates import event_cancelled_template

        html = await event_cancelled_template(
            event_title="My Event",
            reason="Budget cuts",
            event_date="Jan 15, 2026",
            db=None,
        )
        assert "Event Cancelled" in html
        assert "My Event" in html
        assert "Budget cuts" in html
        assert "Jan 15, 2026" in html

    @pytest.mark.asyncio
    async def test_hardcoded_no_date_no_reason(self):
        from app.services.email_templates import event_cancelled_template

        html = await event_cancelled_template(
            event_title="My Event",
            reason="",
            db=None,
        )
        assert "No reason provided." in html

    @pytest.mark.asyncio
    async def test_with_db_template(self, db_session: AsyncSession):
        from app.services.email_templates import event_cancelled_template

        tmpl = EmailTemplate(
            template_key="event_cancelled",
            subject="Cancelled",
            body_html="<p>Custom: {{event_title}} cancelled because {{reason}}</p>",
            variables='["event_title","reason"]',
            is_active=True,
        )
        db_session.add(tmpl)
        await db_session.commit()

        html = await event_cancelled_template(
            event_title="DB Event",
            reason="rain",
            db=db_session,
        )
        assert "Custom: DB Event cancelled because rain" in html


class TestTicketPurchasedTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded_free_ticket(self):
        from app.services.email_templates import ticket_purchased_template

        html = await ticket_purchased_template(
            event_title="Free Fest",
            tier_name="Free",
            ticket_code="FRE-001",
            receipt_number="REC-FRE-001",
            amount_cents=0,
            db=None,
        )
        assert "FREE" in html
        assert "Free Fest" in html

    @pytest.mark.asyncio
    async def test_hardcoded_with_db_template(self, db_session: AsyncSession):
        from app.services.email_templates import ticket_purchased_template

        tmpl = EmailTemplate(
            template_key="ticket_purchased",
            subject="Ticket",
            body_html="<p>Ticket for {{event_title}}, tier={{tier_name}}, code={{ticket_code}}</p>",
            variables='["event_title","tier_name","ticket_code"]',
            is_active=True,
        )
        db_session.add(tmpl)
        await db_session.commit()

        html = await ticket_purchased_template(
            event_title="DB Event",
            tier_name="VIP",
            ticket_code="TKT-DB-001",
            receipt_number="REC-DB-001",
            amount_cents=5000,
            db=db_session,
        )
        assert "Ticket for DB Event" in html


class TestCancellationRefundTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import cancellation_refund_template

        html = await cancellation_refund_template(
            event_title="Big Event",
            reason="Low turnout",
            refunded_cents=15000,
            event_date="Mar 01, 2026",
            db=None,
        )
        assert "Refund" in html
        assert "$150.00" in html
        assert "Big Event" in html

    @pytest.mark.asyncio
    async def test_with_db_template(self, db_session: AsyncSession):
        from app.services.email_templates import cancellation_refund_template

        tmpl = EmailTemplate(
            template_key="cancellation_refund",
            subject="Cancelled & Refund",
            body_html="<p>{{event_title}} cancelled, refund={{refunded_cents}}</p>",
            variables='["event_title","refunded_cents"]',
            is_active=True,
        )
        db_session.add(tmpl)
        await db_session.commit()

        html = await cancellation_refund_template(
            event_title="DB Cancel",
            reason="rain",
            refunded_cents=5000,
            db=db_session,
        )
        assert "DB Cancel cancelled" in html


class TestUnpledgeRefundTemplate:
    @pytest.mark.asyncio
    async def test_hardcoded(self):
        from app.services.email_templates import unpledge_refund_template

        html = await unpledge_refund_template(
            event_title="Fest", refunded_cents=3000, db=None
        )
        assert "Pledge Refunded" in html
        assert "$30.00" in html

    @pytest.mark.asyncio
    async def test_with_db_template(self, db_session: AsyncSession):
        from app.services.email_templates import unpledge_refund_template

        tmpl = EmailTemplate(
            template_key="unpledge_refund",
            subject="Unpledge",
            body_html="<p>Unpledged from {{event_title}}, amount={{refunded_cents}}</p>",
            variables='["event_title","refunded_cents"]',
            is_active=True,
        )
        db_session.add(tmpl)
        await db_session.commit()

        html = await unpledge_refund_template(
            event_title="DB Event", refunded_cents=2000, db=db_session
        )
        assert "Unpledged from DB Event" in html


# ###########################################################################
#  PART 3 — email_notifications.py
# ###########################################################################


class TestNotifyEventCancelled:
    """Cover notify_event_cancelled() — the big DB-reading function."""

    @pytest.mark.asyncio
    async def test_notify_event_cancelled(
        self,
        db_session: AsyncSession,
        test_event_approved,
        test_users,
        test_registration,
        test_pledge,
        test_ticket_tier,
        test_ticket_sale,
    ):
        from app.services.email_notifications import notify_event_cancelled

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            with patch(
                "app.services.email_notifications.send_email_bulk",
                new_callable=AsyncMock,
                return_value=1,
            ) as mock_bulk:
                await notify_event_cancelled(
                    db_session,
                    event_id=test_event_approved.id,
                    event_title="Test Event",
                    reason="Budget cuts",
                )

        # Pledger (customer) gets individual email (refund variant)
        mock_send.assert_called()
        # Registration is the same user who pledged, so they are deduplicated
        # But ticket sale is also the same customer. So mock_bulk may or may
        # not be called depending on whether there are non-pledger users.
        # In this fixture the customer is both pledger and registrant+ticket buyer,
        # so non_pledger_recipients is empty.

    @pytest.mark.asyncio
    async def test_notify_event_cancelled_with_non_pledger_registrant(
        self,
        db_session: AsyncSession,
        test_event_approved,
        test_users,
        test_pledge,  # customer is pledger
    ):
        """Add a second user as a registrant (not a pledger) so bulk is called."""
        from app.services.email_notifications import notify_event_cancelled

        # Add organizer as a registrant (non-pledger)
        reg2 = Registration(
            event_id=test_event_approved.id,
            user_id=test_users["organizer"].id,
            status=RegistrationStatus.registered,
        )
        db_session.add(reg2)
        await db_session.commit()

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            with patch(
                "app.services.email_notifications.send_email_bulk",
                new_callable=AsyncMock,
                return_value=1,
            ) as mock_bulk:
                await notify_event_cancelled(
                    db_session,
                    event_id=test_event_approved.id,
                    event_title="Test Event",
                    reason="Budget cuts",
                    event_date=datetime.now(timezone.utc),
                )

        # Pledger (customer) gets individual email
        mock_send.assert_called()
        # Organizer (registrant, non-pledger) gets bulk email
        mock_bulk.assert_called_once()

    @pytest.mark.asyncio
    async def test_notify_event_cancelled_no_pledgers(
        self,
        db_session: AsyncSession,
        test_event_approved,
        test_users,
        test_registration,
    ):
        """No pledgers — only registrants get bulk email."""
        from app.services.email_notifications import notify_event_cancelled

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            with patch(
                "app.services.email_notifications.send_email_bulk",
                new_callable=AsyncMock,
                return_value=1,
            ) as mock_bulk:
                await notify_event_cancelled(
                    db_session,
                    event_id=test_event_approved.id,
                    event_title="Test Event",
                    reason=None,
                )

        # No pledgers — send not called for individual emails
        mock_send.assert_not_called()
        # Registrant gets bulk email
        mock_bulk.assert_called_once()


class TestNotifyTicketPurchased:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_ticket_purchased

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_ticket_purchased(
                buyer_email="buyer@test.com",
                buyer_name="Buyer",
                event_title="Concert",
                tier_name="VIP",
                ticket_code="TKT-001",
                receipt_number="REC-001",
                amount_cents=5000,
                quantity=2,
                event_date=datetime(2026, 6, 15, tzinfo=timezone.utc),
                discount_cents=500,
                commission_cents=100,
            )

        mock_send.assert_called_once()
        call_args = mock_send.call_args
        assert call_args[0][0] == "buyer@test.com"
        assert "Concert" in call_args[0][2]

    @pytest.mark.asyncio
    async def test_exception_is_caught(self):
        from app.services.email_notifications import notify_ticket_purchased

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            side_effect=Exception("boom"),
        ):
            # Should not raise
            await notify_ticket_purchased(
                buyer_email="buyer@test.com",
                buyer_name="Buyer",
                event_title="Concert",
                tier_name="VIP",
                ticket_code="TKT-001",
                receipt_number="REC-001",
                amount_cents=5000,
            )


class TestNotifyUnpledgeRefund:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_unpledge_refund

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_unpledge_refund(
                user_email="u@test.com",
                user_name="User",
                event_title="Event",
                refunded_cents=5000,
            )

        mock_send.assert_called_once()

    @pytest.mark.asyncio
    async def test_zero_refund_skips(self):
        from app.services.email_notifications import notify_unpledge_refund

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
        ) as mock_send:
            await notify_unpledge_refund(
                user_email="u@test.com",
                user_name="User",
                event_title="Event",
                refunded_cents=0,
            )

        mock_send.assert_not_called()


class TestNotifyUnregisterRefund:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_unregister_refund

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_unregister_refund(
                user_email="u@test.com",
                user_name="User",
                event_title="Event",
                refunded_cents=5000,
            )

        mock_send.assert_called_once()

    @pytest.mark.asyncio
    async def test_zero_refund_skips(self):
        from app.services.email_notifications import notify_unregister_refund

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
        ) as mock_send:
            await notify_unregister_refund(
                user_email="u@test.com",
                user_name="User",
                event_title="Event",
                refunded_cents=0,
            )

        mock_send.assert_not_called()


class TestNotifyWaitlistTicketRejected:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_waitlist_ticket_rejected

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_waitlist_ticket_rejected(
                buyer_email="b@test.com",
                buyer_name="Buyer",
                event_title="Concert",
                tier_name="VIP",
                amount_cents=7500,
            )

        mock_send.assert_called_once()


class TestNotifyTicketRefundApproved:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_ticket_refund_approved

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_ticket_refund_approved(
                buyer_email="b@test.com",
                buyer_name="Buyer",
                event_title="Concert",
                tier_name="VIP",
                amount_cents=5000,
                receipt_number="REC-001",
            )

        mock_send.assert_called_once()


class TestNotifyWaitlistTicketApproved:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_waitlist_ticket_approved

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_waitlist_ticket_approved(
                buyer_email="b@test.com",
                buyer_name="Buyer",
                event_title="Concert",
                tier_name="VIP",
                amount_cents=7500,
                ticket_code="TKT-W001",
                event_date=datetime(2026, 6, 15, tzinfo=timezone.utc),
            )

        mock_send.assert_called_once()


class TestNotifySponsorBidApproved:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_sponsor_bid_approved

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_sponsor_bid_approved(
                sponsor_email="sp@test.com",
                sponsor_name="Sponsor",
                event_title="Gala",
                category_name="Gold",
                bid_amount_cents=50000,
            )

        mock_send.assert_called_once()


class TestNotifySponsorBidRejected:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_sponsor_bid_rejected

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_sponsor_bid_rejected(
                sponsor_email="sp@test.com",
                sponsor_name="Sponsor",
                event_title="Gala",
                category_name="Gold",
                bid_amount_cents=50000,
            )

        mock_send.assert_called_once()


class TestNotifySponsorRefund:
    @pytest.mark.asyncio
    async def test_basic(self):
        from app.services.email_notifications import notify_sponsor_refund

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_sponsor_refund(
                sponsor_email="sp@test.com",
                sponsor_name="Sponsor",
                event_title="Gala",
                category_name="Gold",
                refunded_cents=50000,
                receipt_number="SPR-001",
            )

        mock_send.assert_called_once()

    @pytest.mark.asyncio
    async def test_without_receipt(self):
        from app.services.email_notifications import notify_sponsor_refund

        with patch(
            "app.services.email_notifications.send_email",
            new_callable=AsyncMock,
            return_value=True,
        ) as mock_send:
            await notify_sponsor_refund(
                sponsor_email="sp@test.com",
                sponsor_name="Sponsor",
                event_title="Gala",
                category_name="Gold",
                refunded_cents=25000,
            )

        mock_send.assert_called_once()


class TestFormatDate:
    """Cover _format_date() utility."""

    def test_none(self):
        from app.services.email_notifications import _format_date

        assert _format_date(None) is None

    def test_aware_dt(self):
        from app.services.email_notifications import _format_date

        dt = datetime(2026, 6, 15, 14, 30, tzinfo=timezone.utc)
        result = _format_date(dt)
        assert "Jun 15, 2026" in result
        assert "UTC" in result

    def test_naive_dt(self):
        from app.services.email_notifications import _format_date

        dt = datetime(2026, 6, 15, 14, 30)
        result = _format_date(dt)
        assert "Jun 15, 2026" in result
        assert "UTC" in result
