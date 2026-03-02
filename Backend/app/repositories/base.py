"""Base repository with common CRUD operations."""
from typing import TypeVar, Generic, Sequence

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

T = TypeVar("T")


class BaseRepository(Generic[T]):
    """Generic base — subclasses set ``model_class``."""

    model_class: type[T]

    async def get_by_id(self, db: AsyncSession, id: int) -> T | None:
        result = await db.execute(
            select(self.model_class).where(self.model_class.id == id)
        )
        return result.scalar_one_or_none()

    async def get_or_404(self, db: AsyncSession, id: int, label: str = "") -> T:
        obj = await self.get_by_id(db, id)
        if not obj:
            from app.core.exceptions import NotFoundError

            raise NotFoundError(label or self.model_class.__tablename__, id)
        return obj

    async def create(self, db: AsyncSession, obj: T) -> T:
        db.add(obj)
        await db.flush()
        await db.refresh(obj)
        return obj

    async def count(self, db: AsyncSession, *where) -> int:
        q = select(func.count()).select_from(self.model_class).where(*where)
        return int((await db.execute(q)).scalar_one())

    async def list_paginated(
        self,
        db: AsyncSession,
        *where,
        order_by=None,
        offset: int = 0,
        limit: int = 20,
        options: Sequence | None = None,
    ) -> tuple[list[T], int]:
        """Return (items, total_count) with optional eager-load options."""
        base = select(self.model_class).where(*where)
        if options:
            for opt in options:
                base = base.options(opt)
        if order_by is not None:
            base = base.order_by(order_by)

        total = await self.count(db, *where)
        result = await db.execute(base.offset(offset).limit(limit))
        return list(result.scalars().all()), total
