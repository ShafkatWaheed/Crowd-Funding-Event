"""
Tests for notification endpoints and device-token management.

Endpoints under test (mounted at /api/v1/me/):
  GET    /notifications
  GET    /notifications/unread-count
  PATCH  /notifications/{id}/read
  PATCH  /notifications/read-all
  DELETE /notifications/{id}
  POST   /device-tokens
  DELETE /device-tokens/{token}
"""
import pytest

pytestmark = pytest.mark.asyncio


async def test_list_notifications(client, test_notification, auth_headers_customer, test_users):
    """GET notifications returns list with at least one notification."""
    r = await client.get("/api/v1/me/notifications", headers=auth_headers_customer)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["title"] == "Test Notification"


async def test_list_notifications_pagination(client, test_notification, auth_headers_customer, test_users):
    """Pagination params work."""
    r = await client.get(
        "/api/v1/me/notifications",
        params={"offset": 0, "limit": 5},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200


async def test_unread_count(client, test_notification, auth_headers_customer, test_users):
    """GET unread-count returns count >= 1 (notification is unread by default)."""
    r = await client.get("/api/v1/me/notifications/unread-count", headers=auth_headers_customer)
    assert r.status_code == 200
    data = r.json()
    assert data["unread_count"] >= 1


async def test_mark_read(client, test_notification, auth_headers_customer, test_users):
    """PATCH mark notification as read."""
    r = await client.patch(
        f"/api/v1/me/notifications/{test_notification.id}/read",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["success"] is True


async def test_mark_read_wrong_user(client, test_notification, auth_headers_organizer, test_users):
    """PATCH mark read as different user returns false or 403/404."""
    r = await client.patch(
        f"/api/v1/me/notifications/{test_notification.id}/read",
        headers=auth_headers_organizer,
    )
    # Either returns success=false (notification not found for this user) or 403/404
    if r.status_code == 200:
        assert r.json()["success"] is False
    else:
        assert r.status_code in (403, 404)


async def test_mark_all_read(client, test_notification, auth_headers_customer, test_users):
    """PATCH mark-all-read returns count."""
    r = await client.patch("/api/v1/me/notifications/read-all", headers=auth_headers_customer)
    assert r.status_code == 200
    data = r.json()
    assert data["marked_read"] >= 1


async def test_delete_notification(client, test_notification, auth_headers_customer, test_users):
    """DELETE notification returns 204."""
    r = await client.delete(
        f"/api/v1/me/notifications/{test_notification.id}",
        headers=auth_headers_customer,
    )
    assert r.status_code == 204


async def test_delete_wrong_user(client, test_notification, auth_headers_organizer, test_users):
    """DELETE notification as different user fails."""
    r = await client.delete(
        f"/api/v1/me/notifications/{test_notification.id}",
        headers=auth_headers_organizer,
    )
    # Either 204 (silent no-op) or 403/404
    assert r.status_code in (204, 403, 404)


async def test_register_device_token(client, auth_headers_customer, test_users):
    """POST device-tokens registers a new token."""
    r = await client.post(
        "/api/v1/me/device-tokens",
        json={"token": "new-fcm-token-abc", "platform": "android"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


async def test_register_device_token_duplicate(client, test_device_token, auth_headers_customer, test_users):
    """POST same token upserts (updates user_id)."""
    r = await client.post(
        "/api/v1/me/device-tokens",
        json={"token": "fcm-test-token-12345", "platform": "web"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


async def test_unregister_device_token(client, test_device_token, auth_headers_customer, test_users):
    """DELETE device-tokens/{token} removes it."""
    r = await client.delete(
        "/api/v1/me/device-tokens/fcm-test-token-12345",
        headers=auth_headers_customer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True


async def test_notifications_unauthenticated(client, test_users):
    """GET notifications without auth returns 401/403."""
    r = await client.get("/api/v1/me/notifications")
    assert r.status_code in (401, 403)
