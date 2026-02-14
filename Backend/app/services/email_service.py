"""
Provider-agnostic email service.

Architecture:
  EmailBackend (ABC)
    ├── SendGridBackend   — production (default)
    └── ConsoleBackend    — dev / testing (logs to stdout)

To add a new provider:
  1. Subclass EmailBackend
  2. Add a branch in get_email_backend()
  3. Set EMAIL_PROVIDER=<name> in .env
"""

from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from typing import Any

from app.config import settings

logger = logging.getLogger("email_service")


# ═══════════════════════════════════════════════════════════
# Abstract base
# ═══════════════════════════════════════════════════════════

class EmailBackend(ABC):
    """Interface every email provider must implement."""

    @abstractmethod
    async def send(
        self,
        to_email: str,
        to_name: str,
        subject: str,
        html: str,
    ) -> bool:
        """Send a single email.  Return True on success."""
        ...

    @abstractmethod
    async def send_bulk(
        self,
        recipients: list[dict[str, str]],  # [{"email": ..., "name": ...}, ...]
        subject: str,
        html: str,
    ) -> int:
        """Send the same email to many recipients.  Return count of successes."""
        ...


# ═══════════════════════════════════════════════════════════
# SendGrid backend
# ═══════════════════════════════════════════════════════════

class SendGridBackend(EmailBackend):
    """Send via the SendGrid v3 Web API."""

    def __init__(self) -> None:
        # Lazy import — only needed when this backend is active
        from sendgrid import SendGridAPIClient  # type: ignore[import-untyped]

        self._client = SendGridAPIClient(api_key=settings.EMAIL_API_KEY)

    async def send(
        self,
        to_email: str,
        to_name: str,
        subject: str,
        html: str,
    ) -> bool:
        from sendgrid.helpers.mail import Mail, Email, To, Content  # type: ignore[import-untyped]

        message = Mail(
            from_email=Email(settings.EMAIL_FROM_ADDRESS, settings.EMAIL_FROM_NAME),
            to_emails=To(to_email, to_name),
            subject=subject,
            html_content=Content("text/html", html),
        )
        try:
            resp = self._client.send(message)
            ok = 200 <= resp.status_code < 300
            if ok:
                logger.info("Email sent to %s (status %s)", to_email, resp.status_code)
            else:
                logger.warning(
                    "SendGrid returned %s for %s: %s",
                    resp.status_code, to_email, resp.body,
                )
            return ok
        except Exception:
            logger.exception("SendGrid send failed for %s", to_email)
            return False

    async def send_bulk(
        self,
        recipients: list[dict[str, str]],
        subject: str,
        html: str,
    ) -> int:
        sent = 0
        for r in recipients:
            ok = await self.send(
                to_email=r["email"],
                to_name=r.get("name", ""),
                subject=subject,
                html=html,
            )
            if ok:
                sent += 1
        return sent


# ═══════════════════════════════════════════════════════════
# Console backend (development / testing)
# ═══════════════════════════════════════════════════════════

class ConsoleBackend(EmailBackend):
    """Print emails to the console — no real delivery."""

    async def send(
        self,
        to_email: str,
        to_name: str,
        subject: str,
        html: str,
    ) -> bool:
        logger.info(
            "[ConsoleEmail] TO: %s <%s>  SUBJECT: %s  (html length: %d)",
            to_name, to_email, subject, len(html),
        )
        return True

    async def send_bulk(
        self,
        recipients: list[dict[str, str]],
        subject: str,
        html: str,
    ) -> int:
        logger.info(
            "[ConsoleEmail] BULK TO %d recipients  SUBJECT: %s",
            len(recipients), subject,
        )
        return len(recipients)


# ═══════════════════════════════════════════════════════════
# Factory
# ═══════════════════════════════════════════════════════════

_backend_cache: EmailBackend | None = None


def get_email_backend() -> EmailBackend:
    """Return the configured email backend (cached after first call)."""
    global _backend_cache
    if _backend_cache is not None:
        return _backend_cache

    provider = settings.EMAIL_PROVIDER.lower().strip()
    if provider == "sendgrid":
        _backend_cache = SendGridBackend()
    elif provider == "console":
        _backend_cache = ConsoleBackend()
    else:
        raise ValueError(
            f"Unknown EMAIL_PROVIDER '{provider}'. "
            "Supported: sendgrid, console"
        )
    logger.info("Email backend initialised: %s", provider)
    return _backend_cache


# ═══════════════════════════════════════════════════════════
# Public helpers (what the rest of the codebase imports)
# ═══════════════════════════════════════════════════════════

async def send_email(
    to_email: str,
    to_name: str,
    subject: str,
    html_content: str,
) -> bool:
    """Send one email.  Returns False (never raises) if disabled or on error."""
    if not settings.EMAIL_ENABLED:
        logger.debug("EMAIL_ENABLED=False — skipping email to %s", to_email)
        return False
    try:
        backend = get_email_backend()
        return await backend.send(to_email, to_name, subject, html_content)
    except Exception:
        logger.exception("send_email failed for %s", to_email)
        return False


async def send_email_bulk(
    recipients: list[dict[str, str]],
    subject: str,
    html_content: str,
) -> int:
    """Send same email to many recipients.  Returns count sent (never raises)."""
    if not settings.EMAIL_ENABLED:
        logger.debug("EMAIL_ENABLED=False — skipping bulk email to %d recipients", len(recipients))
        return 0
    if not recipients:
        return 0
    try:
        backend = get_email_backend()
        return await backend.send_bulk(recipients, subject, html_content)
    except Exception:
        logger.exception("send_email_bulk failed for %d recipients", len(recipients))
        return 0
