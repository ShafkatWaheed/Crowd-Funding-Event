"""Tests for ticket_crypto service: encrypt/decrypt QR, plaintext fallback, tamper detection."""
import os

import pytest
from unittest.mock import patch


# ── Helpers ───────────────────────────────────────────────────────


def _clear_lru_cache():
    """Clear the _get_key_bytes LRU cache between tests."""
    from app.services.ticket_crypto import _get_key_bytes
    _get_key_bytes.cache_clear()


@pytest.fixture(autouse=True)
def clear_cache():
    _clear_lru_cache()
    yield
    _clear_lru_cache()


# Generate a valid 32-byte (64 hex chars) key for tests
VALID_KEY_HEX = os.urandom(32).hex()


# ── Plaintext fallback (no key) ──────────────────────────────────


def test_encrypt_plaintext_fallback():
    """Without encryption key, encrypt returns plaintext JSON."""
    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = ""
        _clear_lru_cache()
        from app.services.ticket_crypto import encrypt_ticket_qr
        result = encrypt_ticket_qr("CODE123", 1, 100)
        assert '"tc"' in result or '"CODE123"' in result


def test_decrypt_plaintext_fallback():
    """Without encryption key, decrypt parses plaintext JSON."""
    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = ""
        _clear_lru_cache()
        from app.services.ticket_crypto import encrypt_ticket_qr, decrypt_ticket_qr
        encrypted = encrypt_ticket_qr("CODE456", 2, 200)
        result = decrypt_ticket_qr(encrypted)
        assert result["tc"] == "CODE456"
        assert result["eid"] == 2
        assert result["sid"] == 200


# ── Encrypted roundtrip ──────────────────────────────────────────


def test_encrypt_decrypt_roundtrip():
    """Encrypt then decrypt returns original data."""
    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = VALID_KEY_HEX
        _clear_lru_cache()
        from app.services.ticket_crypto import encrypt_ticket_qr, decrypt_ticket_qr
        encrypted = encrypt_ticket_qr("TICKET_ABC", 10, 500)
        # Encrypted output should be base64, not plaintext JSON
        assert "TICKET_ABC" not in encrypted
        result = decrypt_ticket_qr(encrypted)
        assert result["tc"] == "TICKET_ABC"
        assert result["eid"] == 10
        assert result["sid"] == 500
        assert result["v"] == 1


# ── Tampered payload ─────────────────────────────────────────────


def test_decrypt_tampered_payload():
    """Tampering with ciphertext raises ValueError."""
    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = VALID_KEY_HEX
        _clear_lru_cache()
        from app.services.ticket_crypto import encrypt_ticket_qr, decrypt_ticket_qr
        import base64
        encrypted = encrypt_ticket_qr("TICKET_X", 1, 1)
        blob = bytearray(base64.urlsafe_b64decode(encrypted))
        blob[15] ^= 0xFF  # flip a byte in ciphertext
        tampered = base64.urlsafe_b64encode(bytes(blob)).decode()
        with pytest.raises(ValueError, match="Decryption failed"):
            decrypt_ticket_qr(tampered)


# ── Invalid key ───────────────────────────────────────────────────


def test_invalid_hex_key():
    """Non-hex key disables encryption (returns None key)."""
    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = "not-valid-hex!"
        _clear_lru_cache()
        from app.services.ticket_crypto import encryption_enabled
        assert encryption_enabled() is False


def test_wrong_length_key():
    """Key with wrong byte length disables encryption."""
    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = "aabb"  # 2 bytes, not 32
        _clear_lru_cache()
        from app.services.ticket_crypto import encryption_enabled
        assert encryption_enabled() is False


def test_valid_key_enables_encryption():
    """Valid 64-hex-char key enables encryption."""
    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = VALID_KEY_HEX
        _clear_lru_cache()
        from app.services.ticket_crypto import encryption_enabled
        assert encryption_enabled() is True


# ── Payload too short ─────────────────────────────────────────────


def test_decrypt_short_payload():
    """Payload shorter than nonce + tag raises ValueError."""
    with patch("app.services.ticket_crypto.settings") as mock_settings:
        mock_settings.TICKET_ENCRYPTION_KEY = VALID_KEY_HEX
        _clear_lru_cache()
        import base64
        from app.services.ticket_crypto import decrypt_ticket_qr
        short = base64.urlsafe_b64encode(b"short").decode()
        with pytest.raises(ValueError, match="too short"):
            decrypt_ticket_qr(short)
