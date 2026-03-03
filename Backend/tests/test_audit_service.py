"""Tests for audit service: log_action and list_audit_logs."""
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.services import audit as audit_svc
from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── log_action ────────────────────────────────────────────────────


async def test_log_action_basic(
    db_session: AsyncSession,
    test_users,
):
    """log_action creates an audit log entry."""
    admin = test_users["admin"]
    entry = await audit_svc.log_action(
        db_session,
        admin_id=admin.id,
        action="test_action",
        target_type="event",
        target_id=42,
        details={"key": "value"},
    )
    assert entry.admin_id == admin.id
    assert entry.action == "test_action"
    assert entry.target_type == "event"
    assert entry.target_id == "42"
    assert entry.details == {"key": "value"}


async def test_log_action_no_details(
    db_session: AsyncSession,
    test_users,
):
    """log_action works without details."""
    admin = test_users["admin"]
    entry = await audit_svc.log_action(
        db_session,
        admin_id=admin.id,
        action="simple_action",
        target_type="user",
    )
    assert entry.action == "simple_action"
    assert entry.target_id is None
    assert entry.details is None


async def test_log_action_string_target_id(
    db_session: AsyncSession,
    test_users,
):
    """target_id can be a string."""
    admin = test_users["admin"]
    entry = await audit_svc.log_action(
        db_session,
        admin_id=admin.id,
        action="string_id_action",
        target_type="setting",
        target_id="some_key",
    )
    assert entry.target_id == "some_key"


# ── list_audit_logs ──────────────────────────────────────────────


async def test_list_audit_logs_empty(
    db_session: AsyncSession,
    test_users,
):
    """list_audit_logs returns empty when no logs."""
    logs, total = await audit_svc.list_audit_logs(db_session)
    assert isinstance(logs, list)
    assert isinstance(total, int)


async def test_list_audit_logs_with_entries(
    db_session: AsyncSession,
    test_users,
):
    """list_audit_logs returns created entries."""
    admin = test_users["admin"]
    await audit_svc.log_action(db_session, admin_id=admin.id, action="action_a", target_type="event")
    await audit_svc.log_action(db_session, admin_id=admin.id, action="action_b", target_type="user")
    await db_session.flush()

    logs, total = await audit_svc.list_audit_logs(db_session)
    assert total >= 2
    actions = [log.action for log in logs]
    assert "action_a" in actions
    assert "action_b" in actions


async def test_list_audit_logs_filter_action(
    db_session: AsyncSession,
    test_users,
):
    """list_audit_logs filters by action."""
    admin = test_users["admin"]
    await audit_svc.log_action(db_session, admin_id=admin.id, action="filter_me", target_type="event")
    await audit_svc.log_action(db_session, admin_id=admin.id, action="other", target_type="event")
    await db_session.flush()

    logs, total = await audit_svc.list_audit_logs(db_session, action="filter_me")
    assert all(log.action == "filter_me" for log in logs)
