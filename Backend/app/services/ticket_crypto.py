"""
Ticket QR payload encryption / decryption using AES-256-GCM.

Encrypted format: base64( nonce_12bytes || ciphertext || tag_16bytes )
Plaintext payload:  {"tc": "<ticket_code>", "eid": <event_id>, "sid": <sale_id>, "v": 1}

When TICKET_ENCRYPTION_KEY is empty the module falls back to plaintext JSON
so local development works without any key setup.
"""

from __future__ import annotations

import base64
import json
import logging
import os
from functools import lru_cache

from app.config import settings

log = logging.getLogger(__name__)

_PAYLOAD_VERSION = 1


# ── Key helpers ──────────────────────────────────────────────────────


@lru_cache(maxsize=1)
def _get_key_bytes() -> bytes | None:
    """Return the 32-byte AES key, or *None* if encryption is disabled."""
    raw = settings.TICKET_ENCRYPTION_KEY.strip()
    if not raw:
        return None
    try:
        key = bytes.fromhex(raw)
    except ValueError:
        log.error("TICKET_ENCRYPTION_KEY is not valid hex – encryption disabled")
        return None
    if len(key) != 32:
        log.error(
            "TICKET_ENCRYPTION_KEY must be 64 hex chars (32 bytes); got %d bytes – encryption disabled",
            len(key),
        )
        return None
    return key


def encryption_enabled() -> bool:
    """Return True when a valid encryption key is configured."""
    return _get_key_bytes() is not None


# ── Public API ───────────────────────────────────────────────────────


def encrypt_ticket_qr(ticket_code: str, event_id: int, sale_id: int) -> str:
    """
    Encrypt a ticket QR payload.

    Returns a URL-safe base64 string suitable for embedding in a QR code.
    If no encryption key is configured, returns a plaintext JSON string instead.
    """
    payload = {
        "tc": ticket_code,
        "eid": event_id,
        "sid": sale_id,
        "v": _PAYLOAD_VERSION,
    }
    plaintext = json.dumps(payload, separators=(",", ":")).encode()

    key = _get_key_bytes()
    if key is None:
        # Dev/fallback — return plaintext JSON
        return plaintext.decode()

    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    aesgcm = AESGCM(key)
    nonce = os.urandom(12)  # 96-bit nonce recommended by NIST SP 800-38D
    ciphertext = aesgcm.encrypt(nonce, plaintext, None)  # no AAD needed
    # ciphertext includes the 16-byte GCM auth tag at the end
    blob = nonce + ciphertext
    return base64.urlsafe_b64encode(blob).decode()


def decrypt_ticket_qr(encrypted_payload: str) -> dict:
    """
    Decrypt a ticket QR payload.

    Returns the original dict: ``{"tc": ..., "eid": ..., "sid": ..., "v": ...}``

    Raises ``ValueError`` on:
    - missing / invalid encryption key
    - tampered ciphertext (GCM auth-tag failure)
    - malformed payload
    """
    key = _get_key_bytes()

    if key is None:
        # If encryption is disabled, the payload might be plaintext JSON
        try:
            data = json.loads(encrypted_payload)
            if isinstance(data, dict) and "tc" in data:
                return data
        except (json.JSONDecodeError, TypeError):
            pass
        raise ValueError("Encryption key not configured and payload is not valid plaintext")

    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    try:
        blob = base64.urlsafe_b64decode(encrypted_payload)
    except Exception as exc:
        raise ValueError(f"Invalid base64 payload: {exc}") from exc

    if len(blob) < 12 + 16:
        raise ValueError("Payload too short to contain nonce + auth tag")

    nonce = blob[:12]
    ciphertext = blob[12:]

    aesgcm = AESGCM(key)
    try:
        plaintext = aesgcm.decrypt(nonce, ciphertext, None)
    except Exception as exc:
        raise ValueError(f"Decryption failed (tampered or wrong key): {exc}") from exc

    try:
        data = json.loads(plaintext)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Decrypted data is not valid JSON: {exc}") from exc

    if not isinstance(data, dict) or "tc" not in data:
        raise ValueError("Decrypted payload missing required 'tc' field")

    return data
