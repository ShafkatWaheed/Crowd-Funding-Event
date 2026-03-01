"""
Fernet symmetric encryption for sensitive banking data.

Key resolution order:
1. Platform setting `bank_encryption_key` (set via admin UI or on startup)
2. BANK_ENCRYPTION_KEY env var / config.py
3. Auto-generated (dev mode only — lost on restart)
"""
from __future__ import annotations

import base64
import os

from cryptography.fernet import Fernet

_KEY: bytes | None = None


def set_key(raw: str) -> None:
    """Set the encryption key programmatically (called from admin settings or startup)."""
    global _KEY
    if not raw:
        return
    if len(raw) == 44 and raw.endswith("="):
        _KEY = raw.encode()
    else:
        _KEY = base64.urlsafe_b64encode(raw.ljust(32, "\0")[:32].encode())


def _get_key() -> bytes:
    global _KEY
    if _KEY is not None:
        return _KEY

    raw = os.environ.get("BANK_ENCRYPTION_KEY", "")
    if raw:
        set_key(raw)
    else:
        _KEY = Fernet.generate_key()
    return _KEY


def encrypt(plaintext: str) -> bytes:
    """Encrypt a plaintext string, returning Fernet ciphertext bytes."""
    f = Fernet(_get_key())
    return f.encrypt(plaintext.encode("utf-8"))


def decrypt(ciphertext: bytes) -> str:
    """Decrypt Fernet ciphertext bytes back to a plaintext string."""
    f = Fernet(_get_key())
    if isinstance(ciphertext, str):
        ciphertext = ciphertext.encode("utf-8")
    return f.decrypt(ciphertext).decode("utf-8")


def mask_value(value: str, visible: int = 4) -> str:
    """Return a masked version showing only the last `visible` characters."""
    if len(value) <= visible:
        return value
    return "*" * (len(value) - visible) + value[-visible:]
