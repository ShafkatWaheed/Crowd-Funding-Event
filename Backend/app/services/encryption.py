"""
Fernet symmetric encryption for sensitive banking data.

Uses BANK_ENCRYPTION_KEY env var (base64-url-safe 32 bytes).
Generates a key automatically if not set (dev mode only).
"""
from __future__ import annotations

import base64
import os

from cryptography.fernet import Fernet

_KEY: bytes | None = None


def _get_key() -> bytes:
    global _KEY
    if _KEY is not None:
        return _KEY

    raw = os.environ.get("BANK_ENCRYPTION_KEY", "")
    if raw:
        if len(raw) == 44 and raw.endswith("="):
            _KEY = raw.encode()
        else:
            _KEY = base64.urlsafe_b64encode(raw.ljust(32, "\0")[:32].encode())
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
