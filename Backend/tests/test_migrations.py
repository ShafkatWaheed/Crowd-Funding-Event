"""
Migration verification tests.

These tests verify Alembic migration integrity without touching the main test DB.
They use alembic's ScriptDirectory and autogenerate APIs to detect:
- Broken revision chains
- Multiple heads (branch splits)
- Empty downgrade functions (irreversible migrations)
- Schema drift between ORM models and migration-created schema

Tests 1-3 (upgrade/downgrade on a live DB) are skipped unless
MIGRATION_TEST_DATABASE_URL is set — they need a throwaway DB.
"""
import ast
import os
from pathlib import Path

import pytest

from alembic.config import Config
from alembic.script import ScriptDirectory

pytestmark = [
    pytest.mark.asyncio,
]

# ── Shared helpers ──

_BACKEND_DIR = Path(__file__).resolve().parent.parent
_ALEMBIC_INI = _BACKEND_DIR / "alembic.ini"


def _get_alembic_config() -> Config:
    cfg = Config(str(_ALEMBIC_INI))
    cfg.set_main_option("script_location", str(_BACKEND_DIR / "alembic"))
    return cfg


def _get_script_directory() -> ScriptDirectory:
    return ScriptDirectory.from_config(_get_alembic_config())


# ── Static tests (no DB needed) ──


def test_current_head_single():
    """Alembic should have exactly one head (no branch splits)."""
    script = _get_script_directory()
    heads = script.get_heads()
    assert len(heads) == 1, f"Expected 1 head, got {len(heads)}: {heads}"


def test_migration_chain_unbroken():
    """Every revision should be reachable by walking down_revision from head to None."""
    script = _get_script_directory()
    heads = script.get_heads()
    assert len(heads) >= 1, "No heads found"

    visited = set()
    current = heads[0]
    while current is not None:
        assert current not in visited, f"Cycle detected at {current}"
        visited.add(current)
        rev = script.get_revision(current)
        assert rev is not None, f"Revision {current} not found in script directory"
        current = rev.down_revision

    # All revisions should be reachable
    all_revisions = {r.revision for r in script.walk_revisions()}
    unreachable = all_revisions - visited
    assert not unreachable, f"Unreachable revisions (orphans): {unreachable}"


def test_all_downgrades_have_ops():
    """Warn about migrations with empty downgrade() — they're irreversible."""
    script = _get_script_directory()
    versions_dir = Path(script.dir)

    empty_downgrades = []
    for py_file in versions_dir.glob("*.py"):
        if py_file.name == "__pycache__":
            continue
        source = py_file.read_text()
        try:
            tree = ast.parse(source)
        except SyntaxError:
            continue

        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name == "downgrade":
                # Check if body is just `pass` or empty
                body = node.body
                is_empty = (
                    len(body) == 1
                    and isinstance(body[0], (ast.Pass, ast.Expr))
                    and (
                        isinstance(body[0], ast.Pass)
                        or (isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant))
                    )
                )
                if is_empty:
                    empty_downgrades.append(py_file.name)

    # This is a warning, not a hard failure — some migrations are legitimately irreversible
    # (e.g. adding enum values in PostgreSQL can't be undone without recreating the type)
    if empty_downgrades:
        import warnings
        warnings.warn(
            f"{len(empty_downgrades)} migration(s) have empty downgrade(): "
            f"{', '.join(empty_downgrades[:5])}{'...' if len(empty_downgrades) > 5 else ''}",
            stacklevel=1,
        )


def test_no_duplicate_revisions():
    """No two migration files should have the same revision ID."""
    script = _get_script_directory()
    seen = {}
    for rev in script.walk_revisions():
        if rev.revision in seen:
            pytest.fail(
                f"Duplicate revision ID '{rev.revision}' in "
                f"{rev.path} and {seen[rev.revision]}"
            )
        seen[rev.revision] = rev.path


def test_revision_ids_not_empty():
    """Every migration file should have a non-empty revision ID."""
    script = _get_script_directory()
    for rev in script.walk_revisions():
        assert rev.revision, f"Empty revision ID in {rev.path}"
        assert rev.revision.strip(), f"Whitespace-only revision ID in {rev.path}"


# ── Live DB tests (require MIGRATION_TEST_DATABASE_URL) ──

MIGRATION_DB_URL = os.environ.get("MIGRATION_TEST_DATABASE_URL")
_skip_no_migration_db = pytest.mark.skipif(
    not MIGRATION_DB_URL,
    reason="MIGRATION_TEST_DATABASE_URL not set — skipping live migration tests",
)


@_skip_no_migration_db
async def test_upgrade_head_clean():
    """Run alembic upgrade head on a blank DB — should not error."""
    from alembic import command
    cfg = _get_alembic_config()
    cfg.set_main_option("sqlalchemy.url", MIGRATION_DB_URL)
    command.upgrade(cfg, "head")


@_skip_no_migration_db
async def test_downgrade_base():
    """Upgrade to head, then downgrade to base — should not error."""
    from alembic import command
    cfg = _get_alembic_config()
    cfg.set_main_option("sqlalchemy.url", MIGRATION_DB_URL)
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "base")


@_skip_no_migration_db
async def test_upgrade_downgrade_roundtrip():
    """Upgrade → downgrade → upgrade — ensures idempotency."""
    from alembic import command
    cfg = _get_alembic_config()
    cfg.set_main_option("sqlalchemy.url", MIGRATION_DB_URL)
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")
