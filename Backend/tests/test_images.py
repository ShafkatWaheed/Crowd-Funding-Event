"""Event images API: list, add by URL, delete, permission checks."""
import pytest
from httpx import AsyncClient

from tests.conftest import SKIP_DB


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(SKIP_DB, reason="SKIP_DB_TESTS set"),
]


# ── helpers ──

def _images_url(event_id: int) -> str:
    return f"/api/v1/events/{event_id}/images"


def _image_url(event_id: int, image_id: int) -> str:
    return f"/api/v1/events/{event_id}/images/{image_id}"


# ── tests ──

async def test_list_images(
    client: AsyncClient,
    test_event_approved,
    test_event_image,
    auth_headers_organizer,
) -> None:
    """GET /events/{id}/images returns the existing image."""
    r = await client.get(
        _images_url(test_event_approved.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert any(img["image_url"] == "https://example.com/test.jpg" for img in data)


async def test_create_image(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
) -> None:
    """POST /events/{id}/images as organizer adds an image by URL (query params)."""
    r = await client.post(
        _images_url(test_event_approved.id),
        params={
            "image_url": "https://example.com/new.jpg",
            "caption": "New image",
            "display_order": 1,
        },
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["image_url"] == "https://example.com/new.jpg"
    assert data["caption"] == "New image"
    assert data["display_order"] == 1
    assert "id" in data


async def test_delete_image(
    client: AsyncClient,
    test_event_approved,
    test_event_image,
    auth_headers_organizer,
) -> None:
    """DELETE /events/{id}/images/{iid} as organizer removes the image."""
    r = await client.delete(
        _image_url(test_event_approved.id, test_event_image.id),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    assert r.json()["ok"] is True

    # Verify it's gone
    r2 = await client.get(_images_url(test_event_approved.id))
    assert r2.status_code == 200
    assert all(img["id"] != test_event_image.id for img in r2.json())


async def test_images_not_organizer(
    client: AsyncClient,
    test_event_approved,
    auth_headers_customer,
) -> None:
    """POST /events/{id}/images as customer returns 403 (not organizer/admin)."""
    r = await client.post(
        _images_url(test_event_approved.id),
        params={"image_url": "https://example.com/hack.jpg"},
        headers=auth_headers_customer,
    )
    assert r.status_code == 403


async def test_images_public(
    client: AsyncClient,
    test_event_approved,
    test_event_image,
) -> None:
    """GET /events/{id}/images without auth returns 200 (public endpoint)."""
    r = await client.get(_images_url(test_event_approved.id))
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1


async def test_delete_image_not_found(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
) -> None:
    """DELETE /events/{id}/images/{bad_id} returns 404."""
    r = await client.delete(
        _image_url(test_event_approved.id, 999999),
        headers=auth_headers_organizer,
    )
    assert r.status_code == 404


# ── Phase 0D gap-fills ──


async def test_upload_event_image_file(
    client: AsyncClient,
    test_event_approved,
    auth_headers_organizer,
) -> None:
    """POST /events/{id}/images/upload with a file creates an image record."""
    # Create a minimal valid JPEG (SOI + EOI markers)
    fake_jpeg = b"\xff\xd8\xff\xe0" + b"\x00" * 100 + b"\xff\xd9"
    r = await client.post(
        f"/api/v1/events/{test_event_approved.id}/images/upload",
        files={"file": ("test.jpg", fake_jpeg, "image/jpeg")},
        data={"caption": "Uploaded image", "display_order": "2"},
        headers=auth_headers_organizer,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["caption"] == "Uploaded image"
    assert data["display_order"] == 2
    assert "id" in data
    assert data["image_url"].endswith(".jpg")


async def test_max_images_policy(
    client: AsyncClient,
    test_event_approved,
    test_event_image,
    auth_headers_organizer,
) -> None:
    """Adding images beyond max limit returns 409."""
    from unittest.mock import patch, AsyncMock

    # Mock the policy to return max_images=1 (we already have 1 from fixture)
    async def mock_policy(db, event):
        return {"event_max_images": 1}

    with patch("app.api.v1.events.images.event_service.get_effective_policy", side_effect=mock_policy):
        r = await client.post(
            _images_url(test_event_approved.id),
            params={"image_url": "https://example.com/extra.jpg"},
            headers=auth_headers_organizer,
        )
    assert r.status_code == 409
    assert "Max" in r.json()["detail"]
