"""Auth API: POST /auth/verify (with real Firebase skipped in tests)."""
import os
import pytest
from httpx import AsyncClient


pytestmark = [
    pytest.mark.asyncio,
    pytest.mark.skipif(
        os.environ.get("SKIP_DB_TESTS", "").lower() in ("1", "true", "yes"),
        reason="SKIP_DB_TESTS set",
    ),
]


async def test_verify_requires_body(client: AsyncClient) -> None:
    r = await client.post("/api/v1/auth/verify", json={})
    assert r.status_code in (400, 422)


async def test_verify_invalid_token_returns_401(client: AsyncClient) -> None:
    r = await client.post(
        "/api/v1/auth/verify",
        json={"id_token": "invalid-token", "role": "customer"},
    )
    assert r.status_code == 401


async def test_verify_missing_id_token(client: AsyncClient) -> None:
    r = await client.post("/api/v1/auth/verify", json={"role": "customer"})
    assert r.status_code == 422
