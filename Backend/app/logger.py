"""
Centralized JSON logging configuration.

Usage:
    from app.logger import get_logger, log_step
    logger = get_logger(__name__)
    log_step(logger, "Processing ticket purchase", user_id=42, event_id=7)
    logger.info("Ticket sale completed", extra={"user_id": 42, "amount": 5000})
    logger.debug("Discount applied", extra={"code": "EARLY20", "pct": 20})
"""
import json
import logging
import sys
from datetime import datetime, timezone


class JSONFormatter(logging.Formatter):
    """Outputs each log record as a single JSON line (OpenSearch / Loki friendly)."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict = {
            "time": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        if record.exc_info and record.exc_info[0] is not None:
            payload["exception"] = self.formatException(record.exc_info)

        skip = {
            "color_message", "message", "msg", "args", "exc_info", "exc_text",
            "stack_info", "levelname", "levelno", "pathname", "filename",
            "module", "lineno", "funcName", "created", "msecs", "relativeCreated",
            "thread", "threadName", "processName", "process", "name",
            "taskName",
        }
        for key, val in record.__dict__.items():
            if key.startswith("_") or key in skip:
                continue
            payload[key] = val

        return json.dumps(payload, default=str)


def setup_logging(level: str = "INFO") -> None:
    """Configure the root logger with JSON output to stdout."""
    numeric_level = getattr(logging, level.upper(), logging.INFO)

    root = logging.getLogger()
    root.setLevel(numeric_level)

    if not root.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JSONFormatter())
        root.addHandler(handler)
    else:
        for handler in root.handlers:
            handler.setFormatter(JSONFormatter())

    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.error").setLevel(numeric_level)


def get_logger(name: str) -> logging.Logger:
    """Return a named logger."""
    return logging.getLogger(name)


def log_step(logger: logging.Logger, msg: str, *args, **extra_fields) -> None:
    """Log a process step at INFO level with a [STEP] prefix.

    Extra keyword args are added to the JSON payload for structured searching.
    """
    logger.info("[STEP] " + msg, *args, extra=extra_fields)
