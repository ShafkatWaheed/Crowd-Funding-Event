"""
Application configuration from environment variables.
"""
from pathlib import Path
from typing import List

from pydantic import computed_field, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

# Resolve .env relative to this file (Backend/.env), not the working directory
_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=str(_ENV_FILE), case_sensitive=True)

    PROJECT_NAME: str = "Crowd-Funded Event API"
    API_V1_STR: str = "/api/v1"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/event_db"
    DATABASE_REPLICA_URL: str | None = None  # read-replica; falls back to DATABASE_URL
    DATABASE_ECHO: bool = False
    # Optional: use a separate DB for pytest so tests never truncate real data. If unset, tests use DATABASE_URL (risky).
    TEST_DATABASE_URL: str | None = None

    # Firebase (for ID token verification)
    FIREBASE_PROJECT_ID: str = ""
    GOOGLE_APPLICATION_CREDENTIALS: str = ""

    # CORS: from .env as string (e.g. * or http://localhost:3000,https://app.example.com)
    cors_origins_raw: str = Field(default="*", validation_alias="CORS_ORIGINS")

    # ── Email (provider-agnostic) ──
    EMAIL_ENABLED: bool = False  # master kill-switch
    EMAIL_PROVIDER: str = "sendgrid"  # sendgrid | console | (future: smtp, resend, ses)
    EMAIL_API_KEY: str = ""  # provider API key
    EMAIL_FROM_ADDRESS: str = "noreply@crowdfundevent.com"
    EMAIL_FROM_NAME: str = "CrowdFund Event"

    # Redis (ARQ task queue + caching)
    REDIS_URL: str = "redis://localhost:6379/0"
    CACHE_DEFAULT_TTL: int = 60  # seconds
    RATELIMIT_STORAGE_URL: str = "memory://"  # Redis in prod: redis://host:6379/1

    # Database connection pool
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20
    DB_POOL_TIMEOUT: int = 30
    DB_POOL_RECYCLE: int = 1800

    # Logging
    LOG_LEVEL: str = "INFO"  # DEBUG | INFO | WARNING | ERROR

    # ── Ticket QR Encryption (AES-256-GCM) ──
    TICKET_ENCRYPTION_KEY: str = ""  # 64-char hex string (32 bytes); empty = plaintext fallback (dev mode)

    # ── Bank Account Encryption (Fernet) ──
    BANK_ENCRYPTION_KEY: str = ""  # base64-url-safe 32 bytes; empty = auto-generated (dev only)

    @computed_field
    @property
    def CORS_ORIGINS(self) -> List[str]:
        raw = self.cors_origins_raw or "*"
        parts = [x.strip() for x in raw.split(",") if x.strip()]
        return parts if parts else ["*"]


settings = Settings()
