"""Event co-organizer API: list, invite, respond, update permission, self-remove, remove."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


def _organizers_url(event_id: int) -> str:
    return f"/api/v1/events/{event_id}/organizers"


def _organizer_url(event_id: int, user_id: int) -> str:
    return f"/api/v1/events/{event_id}/organizers/{user_id}"


# =====================================================================
# 1. List organizers
# =====================================================================


async def test_list_organizers(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """GET /events/{id}/organizers returns the main organizer."""
    r = await client.get(
        _organizers_url(test_event_approved.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # The main organizer should be first and flagged is_main=True
    main = data[0]
    assert main["is_main"] is True
    assert main["user_id"] == test_users["organizer"].id
    assert main["permission"] == "full"
    assert main["invitation_status"] == "accepted"


# =====================================================================
# 2. Invite co-organizer
# =====================================================================


async def test_invite_co_organizer(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
):
    """POST /events/{id}/organizers invites organizer2 as co-organizer."""
    organizer2 = test_users["organizer2"]
    r = await client.post(
        _organizers_url(test_event_approved.id),
        json={"user_id": organizer2.id, "permission": "read"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["user_id"] == organizer2.id
    assert data["event_id"] == test_event_approved.id
    assert data["permission"] == "read"
    assert data["invitation_status"] == "pending"


# =====================================================================
# 3. Respond to invitation (accept)
# =====================================================================


async def test_respond_accept(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
    auth_headers_organizer2,
):
    """POST /events/{id}/organizers/{user_id}/respond with accept=true accepts invitation."""
    organizer2 = test_users["organizer2"]

    # First invite organizer2
    invite_r = await client.post(
        _organizers_url(test_event_approved.id),
        json={"user_id": organizer2.id, "permission": "read"},
        headers=auth_headers_organizer,
    )
    assert invite_r.status_code == 200

    # Accept as organizer2
    r = await client.post(
        f"{_organizer_url(test_event_approved.id, organizer2.id)}/respond",
        json={"accept": True},
        headers=auth_headers_organizer2,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["invitation_status"] == "accepted"
    assert data["user_id"] == organizer2.id


# =====================================================================
# 4. Respond to invitation (decline)
# =====================================================================


async def test_respond_decline(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
    auth_headers_organizer2,
):
    """POST /events/{id}/organizers/{user_id}/respond with accept=false declines invitation."""
    organizer2 = test_users["organizer2"]

    # Invite organizer2
    invite_r = await client.post(
        _organizers_url(test_event_approved.id),
        json={"user_id": organizer2.id, "permission": "read"},
        headers=auth_headers_organizer,
    )
    assert invite_r.status_code == 200

    # Decline as organizer2
    r = await client.post(
        f"{_organizer_url(test_event_approved.id, organizer2.id)}/respond",
        json={"accept": False},
        headers=auth_headers_organizer2,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["invitation_status"] == "declined"
    assert data["user_id"] == organizer2.id


# =====================================================================
# 5. Update co-organizer permission
# =====================================================================


async def test_update_permission(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
    auth_headers_organizer2,
):
    """PATCH /events/{id}/organizers/{user_id} updates the co-organizer's permission."""
    organizer2 = test_users["organizer2"]

    # Invite and accept first
    await client.post(
        _organizers_url(test_event_approved.id),
        json={"user_id": organizer2.id, "permission": "read"},
        headers=auth_headers_organizer,
    )
    await client.post(
        f"{_organizer_url(test_event_approved.id, organizer2.id)}/respond",
        json={"accept": True},
        headers=auth_headers_organizer2,
    )

    # Update permission as main organizer
    r = await client.patch(
        _organizer_url(test_event_approved.id, organizer2.id),
        json={"permission": "manage"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["permission"] == "manage"
    assert data["user_id"] == organizer2.id


# =====================================================================
# 6. Self-remove as co-organizer
# =====================================================================


async def test_self_remove(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
    auth_headers_organizer2,
):
    """DELETE /events/{id}/organizers/me removes the co-organizer from the event."""
    organizer2 = test_users["organizer2"]

    # Invite and accept first
    await client.post(
        _organizers_url(test_event_approved.id),
        json={"user_id": organizer2.id, "permission": "read"},
        headers=auth_headers_organizer,
    )
    await client.post(
        f"{_organizer_url(test_event_approved.id, organizer2.id)}/respond",
        json={"accept": True},
        headers=auth_headers_organizer2,
    )

    # Self-remove as organizer2
    r = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/organizers/me",
        headers=auth_headers_organizer2,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


# =====================================================================
# 7. Remove co-organizer (by main organizer)
# =====================================================================


async def test_remove_co_organizer(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_organizer,
    auth_headers_organizer2,
):
    """DELETE /events/{id}/organizers/{user_id} removes a co-organizer."""
    organizer2 = test_users["organizer2"]

    # Invite and accept first
    await client.post(
        _organizers_url(test_event_approved.id),
        json={"user_id": organizer2.id, "permission": "read"},
        headers=auth_headers_organizer,
    )
    await client.post(
        f"{_organizer_url(test_event_approved.id, organizer2.id)}/respond",
        json={"accept": True},
        headers=auth_headers_organizer2,
    )

    # Main organizer removes organizer2
    r = await client.delete(
        _organizer_url(test_event_approved.id, organizer2.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


# =====================================================================
# 8. Invite as customer is forbidden (403)
# =====================================================================


async def test_invite_not_main_organizer(
    client: AsyncClient,
    test_event_approved,
    test_users,
    auth_headers_customer,
):
    """POST /events/{id}/organizers as customer returns 403."""
    organizer2 = test_users["organizer2"]
    r = await client.post(
        _organizers_url(test_event_approved.id),
        json={"user_id": organizer2.id, "permission": "read"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 403
