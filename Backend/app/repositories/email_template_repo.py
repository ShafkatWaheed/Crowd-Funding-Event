"""
Email template data-access layer.

All SQLAlchemy queries for EmailTemplate live here.
"""
from __future__ import annotations

from sqlalchemy import delete as sa_delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.email_template import EmailTemplate


class EmailTemplateRepository:
    """Pure data-access for EmailTemplate."""

    async def list_all(self, db: AsyncSession) -> list[EmailTemplate]:
        q = select(EmailTemplate).order_by(EmailTemplate.template_key)
        return list((await db.execute(q)).scalars().all())

    async def get_by_key(
        self, db: AsyncSession, key: str
    ) -> EmailTemplate | None:
        q = select(EmailTemplate).where(EmailTemplate.template_key == key)
        return (await db.execute(q)).scalar_one_or_none()

    async def create(
        self, db: AsyncSession, tmpl: EmailTemplate
    ) -> EmailTemplate:
        db.add(tmpl)
        await db.flush()
        return tmpl

    async def flush(self, db: AsyncSession) -> None:
        await db.flush()

    async def delete(self, db: AsyncSession, tmpl: EmailTemplate) -> None:
        await db.delete(tmpl)
        await db.flush()

    async def delete_all(self, db: AsyncSession) -> int:
        """Delete all email templates. Returns count of deleted rows."""
        result = await db.execute(sa_delete(EmailTemplate))
        await db.flush()
        return result.rowcount

    async def create_mock_log(
        self,
        db: AsyncSession,
        *,
        to_email: str,
        subject: str,
        body_html: str,
        template_key: str | None,
        status: str,
    ) -> None:
        """Create an EmailMockLog entry."""
        from app.models.email_mock_log import EmailMockLog
        log = EmailMockLog(
            to_email=to_email,
            subject=subject,
            body_html=body_html,
            template_key=template_key,
            status=status,
        )
        db.add(log)
        await db.flush()


# Module-level singleton
email_template_repo = EmailTemplateRepository()
