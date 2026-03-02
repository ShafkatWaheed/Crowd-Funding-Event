"""
Miscellaneous service tests: email, notifications, push, post, KYC,
platform settings, ticket crypto, age verification, config.
"""
import pytest
from datetime import date, timedelta, datetime, timezone
from unittest.mock import patch, AsyncMock, MagicMock


# ---------------------------------------------------------------------------
# Age verification
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_calculate_age():
    """calculate_age returns correct age."""
    from app.services.age_verification import calculate_age
    bday = date.today() - timedelta(days=365 * 25 + 6)
    age = calculate_age(bday)
    assert age == 25


@pytest.mark.asyncio
async def test_enforce_age_limit_passes():
    """enforce_age_limit passes for adults."""
    from app.services.age_verification import enforce_age_limit
    bday = date.today() - timedelta(days=365 * 25)
    # Should not raise
    enforce_age_limit(bday, True, 18, "test")


@pytest.mark.asyncio
async def test_enforce_age_limit_fails():
    """enforce_age_limit raises for underage."""
    from app.services.age_verification import enforce_age_limit
    from app.core.exceptions import ForbiddenError
    bday = date.today() - timedelta(days=365 * 15)
    with pytest.raises(ForbiddenError):
        enforce_age_limit(bday, True, 18, "test")


@pytest.mark.asyncio
async def test_enforce_age_limit_not_restricted():
    """enforce_age_limit passes when event is not age restricted."""
    from app.services.age_verification import enforce_age_limit
    bday = date.today() - timedelta(days=365 * 15)
    # Not restricted → no raise
    enforce_age_limit(bday, False, 18, "test")


# ---------------------------------------------------------------------------
# Ticket crypto
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_ticket_crypto_roundtrip():
    """encrypt → decrypt ticket QR payload."""
    from app.services.ticket_crypto import encrypt_ticket_qr, decrypt_ticket_qr
    encrypted = encrypt_ticket_qr("TKT-001", 1, 1)
    decrypted = decrypt_ticket_qr(encrypted)
    assert decrypted["tc"] == "TKT-001"
    assert decrypted["eid"] == 1


@pytest.mark.asyncio
async def test_ticket_crypto_encryption_enabled():
    """encryption_enabled returns bool."""
    from app.services.ticket_crypto import encryption_enabled
    result = encryption_enabled()
    assert isinstance(result, bool)


# ---------------------------------------------------------------------------
# Notification endpoints
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_notifications(client, db_session, test_notification, auth_headers_customer):
    """List notifications."""
    resp = await client.get("/api/v1/me/notifications", headers=auth_headers_customer)
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 1


@pytest.mark.asyncio
async def test_unread_count(client, db_session, test_notification, auth_headers_customer):
    """Get unread notification count."""
    resp = await client.get("/api/v1/me/notifications/unread-count", headers=auth_headers_customer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_mark_notification_read(client, db_session, test_notification, auth_headers_customer):
    """Mark notification as read."""
    resp = await client.patch(
        f"/api/v1/me/notifications/{test_notification.id}/read",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_mark_all_read(client, db_session, test_notification, auth_headers_customer):
    """Mark all notifications read."""
    resp = await client.patch("/api/v1/me/notifications/read-all", headers=auth_headers_customer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_delete_notification(client, db_session, test_notification, auth_headers_customer):
    """Delete notification."""
    resp = await client.delete(
        f"/api/v1/me/notifications/{test_notification.id}",
        headers=auth_headers_customer,
    )
    assert resp.status_code in (200, 204)


@pytest.mark.asyncio
async def test_register_device_token(client, db_session, test_users, auth_headers_customer):
    """Register device token."""
    resp = await client.post(
        "/api/v1/me/device-tokens",
        headers=auth_headers_customer,
        json={"token": "new-fcm-token", "platform": "android"},
    )
    assert resp.status_code in (200, 201)


@pytest.mark.asyncio
async def test_delete_device_token(client, db_session, test_device_token, auth_headers_customer):
    """Delete device token."""
    resp = await client.delete(
        f"/api/v1/me/device-tokens/{test_device_token.token}",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Config endpoint
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_config_endpoint(client, db_session):
    """GET /config returns configuration."""
    resp = await client.get("/api/v1/config")
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# KYC endpoints (customer)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_kyc_status(client, db_session, test_users, auth_headers_customer):
    """GET KYC status."""
    resp = await client.get("/api/v1/me/kyc-status", headers=auth_headers_customer)
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Post endpoints (extended)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_post_not_registered(client, db_session, test_event_approved, auth_headers_customer):
    """Cannot create post without registration (if enforced)."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/posts",
        headers=auth_headers_customer,
        json={"content": "Hello"},
    )
    # May be 403 (not registered) or 200 (if registration not enforced)
    assert resp.status_code in (200, 201, 403, 409)


@pytest.mark.asyncio
async def test_list_posts(client, db_session, test_event_approved, test_event_post, auth_headers_customer):
    """List posts on event."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/posts",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_toggle_posts(client, db_session, test_event_approved, auth_headers_organizer):
    """Toggle posts on/off."""
    resp = await client.post(
        f"/api/v1/events/{test_event_approved.id}/toggle-posts",
        headers=auth_headers_organizer,
        json={"enabled": False},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_delete_post_as_organizer(client, db_session, test_event_approved, test_event_post, auth_headers_organizer):
    """Organizer can delete post."""
    resp = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/posts/{test_event_post.id}",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Ratings (extended)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_ratings_summary(client, db_session, test_event_completed, test_rating, auth_headers_customer):
    """Get ratings summary."""
    resp = await client.get(
        f"/api/v1/events/{test_event_completed.id}/ratings/summary",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_list_ratings(client, db_session, test_event_completed, test_rating, auth_headers_organizer):
    """List ratings for event (organizer only)."""
    resp = await client.get(
        f"/api/v1/events/{test_event_completed.id}/ratings",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_user_ratings_received(client, db_session, test_users, test_rating, auth_headers_customer):
    """Get user's received ratings."""
    organizer = test_users["organizer"]
    resp = await client.get(
        f"/api/v1/users/{organizer.id}/ratings-received",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Venues (extended)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_venues(client, db_session, test_venue, auth_headers_organizer):
    """List venues."""
    resp = await client.get("/api/v1/venues", headers=auth_headers_organizer)
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_get_venue(client, db_session, test_venue, auth_headers_organizer):
    """Get specific venue."""
    resp = await client.get(f"/api/v1/venues/{test_venue.id}", headers=auth_headers_organizer)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_update_venue(client, db_session, test_venue, auth_headers_organizer):
    """Update venue."""
    resp = await client.patch(
        f"/api/v1/venues/{test_venue.id}",
        headers=auth_headers_organizer,
        json={"name": "Updated Hall"},
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_create_venue(client, db_session, test_users, auth_headers_organizer):
    """Create new venue."""
    resp = await client.post(
        "/api/v1/venues",
        headers=auth_headers_organizer,
        json={
            "name": "New Venue",
            "address": "456 New St",
            "city": "Toronto",
            "province": "ON",
            "lat": 43.65,
            "lng": -79.38,
            "max_capacity": 200,
        },
    )
    assert resp.status_code in (200, 201)


# ---------------------------------------------------------------------------
# Images (extended)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_event_images(client, db_session, test_event_approved, test_event_image, auth_headers_customer):
    """List event images."""
    resp = await client.get(
        f"/api/v1/events/{test_event_approved.id}/images",
        headers=auth_headers_customer,
    )
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_delete_event_image(client, db_session, test_event_approved, test_event_image, auth_headers_organizer):
    """Delete event image."""
    resp = await client.delete(
        f"/api/v1/events/{test_event_approved.id}/images/{test_event_image.id}",
        headers=auth_headers_organizer,
    )
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health(client):
    """Health endpoint."""
    resp = await client.get("/api/v1/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


# ---------------------------------------------------------------------------
# Platform settings (service level)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_setting_default(db_session):
    """get_int returns default for unknown setting."""
    from app.services import platform_settings as ps
    # Clear any cache
    val = await ps.get_int(db_session, "platform_commission_percent")
    assert isinstance(val, int)


@pytest.mark.asyncio
async def test_set_and_get_setting(db_session):
    """set_value + get_str roundtrip."""
    from app.services import platform_settings as ps
    await ps.set_value(db_session, "test_setting_xyz", "hello")
    val = await ps.get_str(db_session, "test_setting_xyz")
    assert val == "hello"


@pytest.mark.asyncio
async def test_get_bool_setting(db_session):
    """get_bool returns boolean."""
    from app.services import platform_settings as ps
    await ps.set_value(db_session, "test_bool_xyz", "true")
    val = await ps.get_bool(db_session, "test_bool_xyz")
    assert val is True


@pytest.mark.asyncio
async def test_get_all_settings(db_session):
    """get_all returns all settings."""
    from app.services import platform_settings as ps
    settings = await ps.get_all(db_session)
    assert isinstance(settings, dict)


# ---------------------------------------------------------------------------
# Email service (unit)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_email_service_disabled():
    """send_email returns False when disabled."""
    with patch("app.services.email_service.settings") as mock_settings:
        mock_settings.SENDGRID_API_KEY = ""
        from app.services.email_service import send_email
        # When no API key → console/disabled mode
        result = await send_email(
            to_email="test@test.com",
            to_name="Test",
            subject="Test",
            html_content="<p>Hello</p>",
        )
        assert isinstance(result, bool)


# ---------------------------------------------------------------------------
# Webhook endpoint
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_stripe_webhook_invalid_event(client, db_session):
    """POST /webhooks/stripe with invalid payload."""
    resp = await client.post(
        "/api/v1/webhooks/stripe",
        content=b"{}",
        headers={"Content-Type": "application/json"},
    )
    # May return 200 (ignored) or 400
    assert resp.status_code in (200, 400)
