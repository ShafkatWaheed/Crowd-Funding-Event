"""
Worker run log data-access layer.

SQLAlchemy queries for WorkerRunLog records (admin worker-run views).
"""
from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.worker_run_log import WorkerRunLog


class WorkerRunRepository:

    async def list_runs(
        self,
        db: AsyncSession,
        *,
        task_name: str | None = None,
        status: str | None = None,
        offset: int = 0,
        limit: int = 50,
    ) -> tuple[list[WorkerRunLog], int]:
        conditions = []
        if task_name:
            conditions.append(WorkerRunLog.task_name == task_name)
        if status:
            conditions.append(WorkerRunLog.status == status)

        count_q = select(func.count(WorkerRunLog.id))
        if conditions:
            count_q = count_q.where(*conditions)
        total = (await db.execute(count_q)).scalar() or 0

        q = (
            select(WorkerRunLog)
            .order_by(WorkerRunLog.started_at.desc())
            .offset(offset)
            .limit(limit)
        )
        if conditions:
            q = q.where(*conditions)
        rows = list((await db.execute(q)).scalars().all())
        return rows, total

    async def create_run_log(
        self,
        db: AsyncSession,
        *,
        task_name: str,
        status: str,
        started_at,
        finished_at=None,
        duration_ms: float = 0,
        items_processed: int | None = None,
        error: str | None = None,
    ) -> None:
        """Persist a worker run log entry."""
        db.add(WorkerRunLog(
            task_name=task_name,
            status=status,
            started_at=started_at,
            finished_at=finished_at,
            duration_ms=duration_ms,
            items_processed=items_processed,
            error=error,
        ))

    async def delete_before(self, db: AsyncSession, cutoff) -> int:
        """Delete WorkerRunLog entries older than cutoff. Returns rowcount."""
        from sqlalchemy import delete
        result = await db.execute(
            delete(WorkerRunLog).where(WorkerRunLog.started_at < cutoff)
        )
        return result.rowcount

    async def get_summary(self, db: AsyncSession) -> tuple[list, dict]:
        """Return (aggregate_rows, last_status_map) for worker summary."""
        q = (
            select(
                WorkerRunLog.task_name,
                func.count(WorkerRunLog.id).label("total_runs"),
                func.count(case((WorkerRunLog.status == "error", 1))).label("total_errors"),
                func.max(WorkerRunLog.started_at).label("last_run_at"),
            )
            .group_by(WorkerRunLog.task_name)
        )
        rows = list((await db.execute(q)).all())

        last_status_q = (
            select(WorkerRunLog.task_name, WorkerRunLog.status)
            .distinct(WorkerRunLog.task_name)
            .order_by(WorkerRunLog.task_name, WorkerRunLog.started_at.desc())
        )
        last_rows = (await db.execute(last_status_q)).all()
        last_status_map = {r.task_name: r.status for r in last_rows}

        return rows, last_status_map


# Module-level singleton
worker_run_repo = WorkerRunRepository()
