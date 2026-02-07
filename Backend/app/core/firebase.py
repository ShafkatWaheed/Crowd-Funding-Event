"""
Lazy Firebase Admin app initialization for ID token verification.
"""
from typing import Optional

import firebase_admin
from firebase_admin import auth as firebase_auth

from app.config import settings

_firebase_app: Optional[firebase_admin.App] = None


def get_firebase_app() -> Optional[firebase_admin.App]:
    """Return initialized Firebase app, or None if not configured."""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    if not settings.FIREBASE_PROJECT_ID:
        return None
    if not settings.GOOGLE_APPLICATION_CREDENTIALS:
        return None
    try:
        _firebase_app = firebase_admin.get_app()
        return _firebase_app
    except ValueError:
        _firebase_app = None
    try:
        _firebase_app = firebase_admin.initialize_app()
        return _firebase_app
    except Exception:
        return None


def verify_id_token(token: str) -> dict:
    """
    Verify Firebase ID token and return decoded claims.
    Raises ValueError if token invalid or Firebase not configured.
    Returns dict with at least: uid, email (optional), name (optional).
    """
    app = get_firebase_app()
    if app is None:
        raise ValueError("Firebase is not configured")
    try:
        decoded = firebase_auth.verify_id_token(token, check_revoked=True)
    except firebase_auth.RevokedIdTokenError:
        raise ValueError("Token has been revoked")
    except firebase_auth.ExpiredIdTokenError:
        raise ValueError("Token has expired")
    except firebase_auth.InvalidIdTokenError:
        raise ValueError("Invalid token")
    return decoded
