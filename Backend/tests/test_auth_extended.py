"""
Extended auth tests: verify_and_upsert_user service-level + API edge cases.
"""
import pytest
from datetime import date, timedelta
from unittest.mock import patch, MagicMock

from app.services.auth import verify_and_upsert_user
from app.models.user import UserRole


# ---------------------------------------------------------------------------
# Service-level tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_upsert_creates_new_customer(db_session):
    """New user with valid token + birthday → customer by default."""
    fake_decoded = {"uid": "new-uid-1", "email": "new@test.com", "name": "New User"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        user = await verify_and_upsert_user(
            db_session, "fake-token",
            birthday=date.today() - timedelta(days=365 * 20),
        )
    assert user.firebase_uid == "new-uid-1"
    assert user.email == "new@test.com"
    assert user.role == UserRole.customer


@pytest.mark.asyncio
async def test_upsert_creates_organizer_role(db_session):
    """New user requesting organizer role."""
    fake_decoded = {"uid": "new-uid-2", "email": "org@test.com", "name": "Org"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        user = await verify_and_upsert_user(
            db_session, "fake-token",
            sign_up_role="organizer",
            birthday=date.today() - timedelta(days=365 * 25),
        )
    assert user.role == UserRole.organizer


@pytest.mark.asyncio
async def test_upsert_creates_sponsor_role(db_session):
    """New user requesting sponsor role."""
    fake_decoded = {"uid": "new-uid-3", "email": "sp@test.com", "name": "Sp"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        user = await verify_and_upsert_user(
            db_session, "fake-token",
            sign_up_role="sponsor",
            birthday=date.today() - timedelta(days=365 * 30),
        )
    assert user.role == UserRole.sponsor


@pytest.mark.asyncio
async def test_upsert_rejects_admin_role(db_session):
    """Requesting 'admin' role should default to customer."""
    fake_decoded = {"uid": "new-uid-4", "email": "a@test.com", "name": "A"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        user = await verify_and_upsert_user(
            db_session, "fake-token",
            sign_up_role="admin",
            birthday=date.today() - timedelta(days=365 * 25),
        )
    assert user.role == UserRole.customer


@pytest.mark.asyncio
async def test_upsert_rejects_under_13(db_session):
    """Users under 13 should be rejected."""
    fake_decoded = {"uid": "young-uid", "email": "kid@test.com", "name": "Kid"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        with pytest.raises(ValueError, match="at least 13"):
            await verify_and_upsert_user(
                db_session, "fake-token",
                birthday=date.today() - timedelta(days=365 * 10),
            )


@pytest.mark.asyncio
async def test_upsert_requires_birthday_for_new(db_session):
    """New users must provide birthday."""
    fake_decoded = {"uid": "no-bday-uid", "email": "nb@test.com", "name": "NB"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        with pytest.raises(ValueError, match="Birthday is required"):
            await verify_and_upsert_user(db_session, "fake-token")


@pytest.mark.asyncio
async def test_upsert_updates_existing_user(db_session, test_users):
    """Existing user should update email/display_name only, role unchanged."""
    organizer = test_users["organizer"]
    fake_decoded = {
        "uid": organizer.firebase_uid,
        "email": "updated@test.com",
        "name": "Updated Name",
    }
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        user = await verify_and_upsert_user(db_session, "fake-token")
    assert user.id == organizer.id
    assert user.email == "updated@test.com"
    assert user.display_name == "Updated Name"
    assert user.role == UserRole.organizer  # unchanged


@pytest.mark.asyncio
async def test_upsert_display_name_override(db_session):
    """display_name_override takes precedence over token's name claim."""
    fake_decoded = {"uid": "override-uid", "email": "o@test.com", "name": "Token Name"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        user = await verify_and_upsert_user(
            db_session, "fake-token",
            display_name_override="Override Name",
            birthday=date.today() - timedelta(days=365 * 20),
        )
    assert user.display_name == "Override Name"


@pytest.mark.asyncio
async def test_upsert_invalid_token(db_session):
    """Invalid token (missing uid) raises ValueError."""
    with patch("app.services.auth.verify_id_token", return_value={}):
        with pytest.raises(ValueError, match="Token missing uid"):
            await verify_and_upsert_user(db_session, "bad-token")


@pytest.mark.asyncio
async def test_upsert_birthday_as_string(db_session):
    """Birthday can be passed as ISO string."""
    bday = (date.today() - timedelta(days=365 * 20)).isoformat()
    fake_decoded = {"uid": "str-bday-uid", "email": "sb@test.com", "name": "SB"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        user = await verify_and_upsert_user(
            db_session, "fake-token",
            birthday=bday,
        )
    assert user.birthday is not None


@pytest.mark.asyncio
async def test_upsert_terms_accepted(db_session):
    """terms_accepted_at is stored for new users."""
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    fake_decoded = {"uid": "terms-uid", "email": "t@test.com", "name": "T"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        user = await verify_and_upsert_user(
            db_session, "fake-token",
            terms_accepted_at=now,
            birthday=date.today() - timedelta(days=365 * 20),
        )
    assert user.terms_accepted_at is not None


# ---------------------------------------------------------------------------
# API-level tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_verify_endpoint_success(client, db_session):
    """POST /v1/auth/verify with valid token creates user."""
    bday = (date.today() - timedelta(days=365 * 20)).isoformat()
    fake_decoded = {"uid": "api-uid", "email": "api@test.com", "name": "API User"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        resp = await client.post("/api/v1/auth/verify", json={
            "id_token": "valid-token",
            "birthday": bday,
        })
    assert resp.status_code == 200
    data = resp.json()
    assert data["email"] == "api@test.com"


@pytest.mark.asyncio
async def test_verify_endpoint_with_role(client, db_session):
    """POST /v1/auth/verify with role=organizer."""
    bday = (date.today() - timedelta(days=365 * 25)).isoformat()
    fake_decoded = {"uid": "api-org-uid", "email": "apiorg@test.com", "name": "API Org"}
    with patch("app.services.auth.verify_id_token", return_value=fake_decoded):
        resp = await client.post("/api/v1/auth/verify", json={
            "id_token": "valid-token",
            "role": "organizer",
            "birthday": bday,
        })
    assert resp.status_code == 200
    assert resp.json()["role"] == "organizer"
