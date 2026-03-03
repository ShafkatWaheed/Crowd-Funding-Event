"""Tests for encryption service: encrypt, decrypt, mask_value, set_key."""
import pytest

from app.services import encryption


@pytest.fixture(autouse=True)
def reset_key():
    """Reset the global encryption key before each test."""
    encryption._KEY = None
    yield
    encryption._KEY = None


# ── Encrypt / Decrypt roundtrip ───────────────────────────────────


def test_encrypt_decrypt_roundtrip():
    """Encrypting then decrypting returns the original value."""
    plaintext = "1234567890"
    ciphertext = encryption.encrypt(plaintext)
    assert isinstance(ciphertext, bytes)
    result = encryption.decrypt(ciphertext)
    assert result == plaintext


def test_encrypt_decrypt_unicode():
    """Handles unicode characters."""
    plaintext = "Héllo Wörld! 🎉"
    ciphertext = encryption.encrypt(plaintext)
    result = encryption.decrypt(ciphertext)
    assert result == plaintext


def test_different_plaintexts_different_ciphertexts():
    """Different inputs produce different ciphertexts."""
    ct1 = encryption.encrypt("alpha")
    ct2 = encryption.encrypt("beta")
    assert ct1 != ct2


# ── set_key ───────────────────────────────────────────────────────


def test_set_key_base64():
    """set_key with a 44-char base64= string sets it directly."""
    from cryptography.fernet import Fernet
    key = Fernet.generate_key().decode()
    encryption.set_key(key)
    assert encryption._KEY is not None
    # Verify the key works for encrypt/decrypt
    ct = encryption.encrypt("test")
    assert encryption.decrypt(ct) == "test"


def test_set_key_raw():
    """set_key with a plain string pads/truncates to 32 bytes and base64-encodes."""
    encryption.set_key("my_secret_key_for_testing")
    assert encryption._KEY is not None
    ct = encryption.encrypt("test")
    assert encryption.decrypt(ct) == "test"


def test_set_key_empty():
    """set_key with empty string does not change key."""
    encryption.set_key("")
    assert encryption._KEY is None


# ── Auto-generated key ────────────────────────────────────────────


def test_auto_generated_key():
    """When no key is set and no env var, a key is auto-generated."""
    assert encryption._KEY is None
    ct = encryption.encrypt("auto")
    assert encryption._KEY is not None
    assert encryption.decrypt(ct) == "auto"


# ── decrypt handles string input ─────────────────────────────────


def test_decrypt_accepts_string():
    """decrypt can handle a string ciphertext (not just bytes)."""
    ct = encryption.encrypt("string_test")
    ct_str = ct.decode("utf-8")
    result = encryption.decrypt(ct_str)
    assert result == "string_test"


# ── mask_value ────────────────────────────────────────────────────


def test_mask_default():
    """mask_value hides all but last 4 characters."""
    assert encryption.mask_value("12345678") == "****5678"


def test_mask_custom_visible():
    """mask_value with visible=2 shows only last 2."""
    assert encryption.mask_value("ABCDEF", visible=2) == "****EF"


def test_mask_short_value():
    """If value is shorter than visible, return as-is."""
    assert encryption.mask_value("AB", visible=4) == "AB"


def test_mask_exact_length():
    """If value length equals visible, return as-is."""
    assert encryption.mask_value("ABCD", visible=4) == "ABCD"
