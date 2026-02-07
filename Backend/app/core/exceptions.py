"""
Custom API exceptions and handlers.
"""
from fastapi import HTTPException


class AppException(HTTPException):
    """Base app exception."""

    def __init__(self, status_code: int, detail: str):
        super().__init__(status_code=status_code, detail=detail)


class NotFoundError(AppException):
    def __init__(self, resource: str, id: str | int):
        super().__init__(404, f"{resource} not found: {id}")


class ForbiddenError(AppException):
    def __init__(self, detail: str = "Forbidden"):
        super().__init__(403, detail)


class ConflictError(AppException):
    def __init__(self, detail: str):
        super().__init__(409, detail)
