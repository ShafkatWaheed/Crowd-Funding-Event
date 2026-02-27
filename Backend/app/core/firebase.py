"""
Lazy Firebase Admin app initialization for ID token verification.
"""
from pathlib import Path
from typing import Optional

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin.credentials import Certificate

from app.config import settings
from app.logger import get_logger, log_step

logger = get_logger("core.firebase")

_firebase_app: Optional[firebase_admin.App] = None


def get_firebase_app() -> firebase_admin.App:
    """Return initialized Firebase app. Raises ValueError with details if not configured."""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    if not (settings.FIREBASE_PROJECT_ID or "").strip():
        raise ValueError(
            "Firebase is not configured: FIREBASE_PROJECT_ID is empty. "
            "Set it in .env (e.g. FIREBASE_PROJECT_ID=crowd-funding-event)."
        )
    cred_path = (settings.GOOGLE_APPLICATION_CREDENTIALS or "").strip()
    if not cred_path:
        raise ValueError(
            "Firebase is not configured: GOOGLE_APPLICATION_CREDENTIALS is empty. "
            "Set it in .env to the full path of your Firebase service account JSON file."
        )
    path = Path(cred_path)
    if not path.is_file():
        raise ValueError(
            f"Firebase is not configured: credentials file not found at {cred_path!r}. "
            "Check GOOGLE_APPLICATION_CREDENTIALS in .env (use absolute path; in WSL use /mnt/c/... for Windows paths)."
        )
    try:
        _firebase_app = firebase_admin.get_app()
        logger.debug("Reusing existing Firebase app")
        return _firebase_app
    except ValueError:
        _firebase_app = None
    try:
        cred = Certificate(cred_path)
        _firebase_app = firebase_admin.initialize_app(
            cred,
            options={"projectId": settings.FIREBASE_PROJECT_ID.strip()},
        )
        log_step(logger, "Firebase app initialized", project_id=settings.FIREBASE_PROJECT_ID.strip())
        return _firebase_app
    except Exception as e:
        logger.error("Firebase initialization failed: %s", e)
        raise ValueError(
            f"Firebase is not configured: failed to initialize ({e!s}). "
            "Check that the credentials JSON is valid and FIREBASE_PROJECT_ID matches your Firebase project."
        ) from e


def verify_id_token(token: str) -> dict:
    """
    Verify Firebase ID token and return decoded claims.
    Raises ValueError if token invalid or Firebase not configured.
    Returns dict with at least: uid, email (optional), name (optional).
    """
    app = get_firebase_app()
    try:
        decoded = firebase_auth.verify_id_token(token, check_revoked=True)
    except firebase_auth.RevokedIdTokenError:
        logger.warning("Token verification failed: revoked")
        raise ValueError("Token has been revoked")
    except firebase_auth.ExpiredIdTokenError:
        logger.warning("Token verification failed: expired")
        raise ValueError("Token has expired")
    except firebase_auth.InvalidIdTokenError:
        logger.warning("Token verification failed: invalid")
        raise ValueError("Invalid token")
    logger.debug("Token verified for uid=%s", decoded.get("uid"))
    return decoded
