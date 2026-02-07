"""
Application configuration from environment variables.
"""
from typing import List

from pydantic import computed_field, Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "Crowd-Funded Event API"
    API_V1_STR: str = "/api/v1"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost:5432/event_db"
    DATABASE_ECHO: bool = False

    # Firebase (for ID token verification)
    FIREBASE_PROJECT_ID: str = ""
    GOOGLE_APPLICATION_CREDENTIALS: str = ""

    # CORS: from .env as string (e.g. * or http://localhost:3000,https://app.example.com)
    cors_origins_raw: str = Field(default="*", validation_alias="CORS_ORIGINS")

    @computed_field
    @property
    def CORS_ORIGINS(self) -> List[str]:
        raw = self.cors_origins_raw or "*"
        parts = [x.strip() for x in raw.split(",") if x.strip()]
        return parts if parts else ["*"]

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
