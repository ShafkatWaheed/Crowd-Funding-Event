"""
User data-access layer.

All SQLAlchemy queries for users and KYC documents live here.
Services must call these methods instead of db.execute() directly.
"""
from datetime import datetime

from sqlalchemy import delete as sa_delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.kyc_document import KycDocument, KycDocumentStatus
from app.models.user import User, UserRole
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    model_class = User

    # ═══════════════════════════════════════════════════════════════════
    #  User CRUD
    # ═══════════════════════════════════════════════════════════════════

    async def get_by_id(
        self, db: AsyncSession, user_id: int
    ) -> User | None:
        """Load user by id with sponsor_profile eager-loaded."""
        q = (
            select(User)
            .where(User.id == user_id)
            .options(selectinload(User.sponsor_profile))
        )
        result = await db.execute(q)
        return result.scalar_one_or_none()

    async def get_by_firebase_uid(
        self, db: AsyncSession, uid: str
    ) -> User | None:
        """Look up a user by their Firebase UID."""
        q = select(User).where(User.firebase_uid == uid)
        result = await db.execute(q)
        return result.scalar_one_or_none()

    async def search_organizers(
        self,
        db: AsyncSession,
        query: str,
        *,
        limit: int = 20,
    ) -> list[User]:
        """Search users with organizer or admin role by email or display_name."""
        search_term = f"%{query.strip()}%"
        q = (
            select(User)
            .where(
                User.role.in_([UserRole.organizer, UserRole.admin]),
                or_(
                    User.email.ilike(search_term),
                    User.display_name.ilike(search_term),
                ),
            )
            .limit(limit)
        )
        result = await db.execute(q)
        return list(result.scalars().all())

    async def create_user(
        self,
        db: AsyncSession,
        *,
        firebase_uid: str,
        email: str,
        display_name: str,
        role: UserRole,
        birthday: datetime | None = None,
        terms_accepted_at: datetime | None = None,
    ) -> User:
        """Create a new user, flush, refresh, and return."""
        user = User(
            firebase_uid=firebase_uid,
            email=email,
            display_name=display_name,
            role=role,
            birthday=birthday,
            terms_accepted_at=terms_accepted_at,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)
        return user

    async def update_user(
        self, db: AsyncSession, user: User, **kwargs
    ) -> User:
        """Set arbitrary attributes on the user, flush, and refresh."""
        for key, value in kwargs.items():
            setattr(user, key, value)
        await db.flush()
        await db.refresh(user)
        return user

    async def list_users(
        self,
        db: AsyncSession,
        *,
        search: str | None = None,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[User], int]:
        """
        Admin: list users with optional search on email/display_name.
        Returns (users, total_count).
        """
        conditions = []
        if search and search.strip():
            search_term = f"%{search.strip()}%"
            conditions.append(
                or_(
                    User.email.ilike(search_term),
                    User.display_name.ilike(search_term),
                )
            )

        # Total count
        count_q = select(func.count(User.id))
        if conditions:
            count_q = count_q.where(*conditions)
        total = int((await db.execute(count_q)).scalar_one())

        # Paginated rows
        q = select(User).order_by(User.created_at.desc())
        if conditions:
            q = q.where(*conditions)
        q = q.offset(offset).limit(limit)
        result = await db.execute(q)
        return list(result.scalars().all()), total

    async def count_all(self, db: AsyncSession) -> int:
        """Count all users."""
        q = select(func.count(User.id))
        return int((await db.execute(q)).scalar_one())

    # ═══════════════════════════════════════════════════════════════════
    #  KYC Documents
    # ═══════════════════════════════════════════════════════════════════

    async def get_kyc_documents(
        self, db: AsyncSession, user_id: int
    ) -> list[KycDocument]:
        """List all KYC documents for a user."""
        q = (
            select(KycDocument)
            .where(KycDocument.user_id == user_id)
            .order_by(KycDocument.submitted_at.desc())
        )
        result = await db.execute(q)
        return list(result.scalars().all())

    async def get_kyc_document_by_type(
        self, db: AsyncSession, user_id: int, document_type: str
    ) -> KycDocument | None:
        """Find a KYC document by user and document type."""
        q = select(KycDocument).where(
            KycDocument.user_id == user_id,
            KycDocument.document_type == document_type,
        )
        result = await db.execute(q)
        return result.scalar_one_or_none()

    async def create_kyc_document(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        document_type: str,
        file_path: str,
        mime_type: str,
        original_filename: str,
    ) -> KycDocument:
        """Create a new KYC document record."""
        doc = KycDocument(
            user_id=user_id,
            document_type=document_type,
            file_path=file_path,
            mime_type=mime_type,
            original_filename=original_filename,
        )
        db.add(doc)
        await db.flush()
        await db.refresh(doc)
        return doc

    async def upsert_kyc_document(
        self,
        db: AsyncSession,
        *,
        user_id: int,
        document_type: str,
        file_path: str,
        mime_type: str,
        original_filename: str,
    ) -> KycDocument:
        """Update an existing KYC document of the given type, or create a new one."""
        existing = await self.get_kyc_document_by_type(db, user_id, document_type)
        if existing:
            existing.file_path = file_path
            existing.mime_type = mime_type
            existing.original_filename = original_filename
            existing.status = KycDocumentStatus.pending
            existing.rejection_reason = None
            existing.reviewed_at = None
            existing.reviewed_by_id = None
            await db.flush()
            await db.refresh(existing)
            return existing
        return await self.create_kyc_document(
            db,
            user_id=user_id,
            document_type=document_type,
            file_path=file_path,
            mime_type=mime_type,
            original_filename=original_filename,
        )

    async def delete_kyc_document(
        self, db: AsyncSession, document_id: int, user_id: int
    ) -> bool:
        """
        Delete a KYC document if its status is pending.
        Returns True if a row was deleted, False otherwise.
        """
        q = (
            sa_delete(KycDocument)
            .where(
                KycDocument.id == document_id,
                KycDocument.user_id == user_id,
                KycDocument.status == KycDocumentStatus.pending,
            )
            .returning(KycDocument.id)
        )
        result = await db.execute(q)
        await db.flush()
        return result.scalar_one_or_none() is not None

    async def list_pending_kyc_users(
        self, db: AsyncSession
    ) -> list[User]:
        """Select users whose kyc_status is 'submitted'."""
        q = (
            select(User)
            .where(User.kyc_status == "submitted")
            .order_by(User.created_at.asc())
        )
        result = await db.execute(q)
        return list(result.scalars().all())


# Module-level singleton
user_repo = UserRepository()
