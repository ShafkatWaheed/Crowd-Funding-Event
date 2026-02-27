"""
FastAPI application entry point.
Mounts API v1 router and configures CORS, middleware, logging.
"""
import logging
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from starlette.types import ASGIApp, Receive, Scope, Send

from app.api.v1.router import api_router
from app.config import settings
from app.core.exceptions import AppException
from app.db.base import async_engine, read_engine
from app.rate_limit import setup_rate_limiting
from app.cache import init_cache, close_cache
from app.worker.redis_pool import get_arq_pool, close_arq_pool

STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
STATIC_DIR.mkdir(exist_ok=True)
(STATIC_DIR / "uploads").mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("app")


class LogRequestsMiddleware:
    """Pure ASGI middleware for request logging (no BaseHTTPMiddleware / call_next).
    This avoids the 'attached to a different loop' asyncpg bug that BaseHTTPMiddleware causes."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start = time.perf_counter()
        status_code = 0

        async def send_wrapper(message):
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
            await send(message)

        await self.app(scope, receive, send_wrapper)

        duration_ms = (time.perf_counter() - start) * 1000
        logger.info(
            "%s %s %s %.1fms",
            scope["method"],
            scope["path"],
            status_code,
            duration_ms,
        )


@asynccontextmanager
async def lifespan(application: FastAPI):
    logger.info("Starting %s", settings.PROJECT_NAME)
    try:
        await get_arq_pool()
        logger.info("ARQ Redis pool connected")
    except Exception:
        logger.warning("Redis not available — ARQ tasks will be skipped (refunds complete inline)")
    await init_cache()
    try:
        from app.cache import set_cache_enabled
        from app.db.base import async_session_maker
        from app.services.platform_settings import get_bool
        from app.rate_limit import reload_rate_limits
        async with async_session_maker() as db:
            set_cache_enabled(await get_bool(db, "cache_enabled"))
            await reload_rate_limits(db)
    except Exception:
        logger.warning("Could not load startup settings — using defaults")
    yield
    await close_cache()
    await close_arq_pool()
    await read_engine.dispose()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    lifespan=lifespan,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
)

app.add_middleware(LogRequestsMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

setup_rate_limiting(app)
app.include_router(api_router, prefix=settings.API_V1_STR)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


def _app_exception_handler(request, exc: AppException):
    """Ensure all app errors return consistent JSON with status_code and detail."""
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
    )


app.add_exception_handler(AppException, _app_exception_handler)


@app.get("/healthz")
def healthz():
    """Liveness probe -- just confirms the process is alive."""
    return {"status": "ok"}


@app.get("/health")
async def health():
    """Readiness probe -- confirms the app can reach primary and replica databases."""
    result: dict = {"status": "ok"}
    try:
        async with async_engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        result["db_primary"] = "connected"
    except Exception as exc:
        result.update(status="unhealthy", db_primary=str(exc))

    try:
        async with read_engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        result["db_replica"] = "connected"
    except Exception as exc:
        result.update(status="unhealthy", db_replica=str(exc))

    if result["status"] != "ok":
        return JSONResponse(status_code=503, content=result)
    return result
