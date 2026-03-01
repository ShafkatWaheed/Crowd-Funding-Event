"""
Age verification helpers for age-restricted events.
"""
from datetime import date

from app.core.exceptions import ForbiddenError


def calculate_age(birthday: date) -> int:
    today = date.today()
    return today.year - birthday.year - ((today.month, today.day) < (birthday.month, birthday.day))


def enforce_age_limit(
    user_birthday: date | None,
    event_age_restricted: bool,
    event_min_age: int,
    action: str = "access this event",
) -> None:
    if not event_age_restricted:
        return
    if user_birthday is None:
        raise ForbiddenError(
            "You must set your birthday in your profile before you can " + action
        )
    age = calculate_age(user_birthday)
    if age < event_min_age:
        raise ForbiddenError(
            f"You must be at least {event_min_age} years old to {action}"
        )


def validate_organizer_can_restrict_age(
    organizer_birthday: date | None,
    age_restricted: bool,
) -> None:
    """Only 18+ organizers can create age-restricted events."""
    if not age_restricted:
        return
    if organizer_birthday is None:
        raise ForbiddenError(
            "You must set your birthday before creating an age-restricted event"
        )
    organizer_age = calculate_age(organizer_birthday)
    if organizer_age < 18:
        raise ForbiddenError(
            "You must be at least 18 years old to create an age-restricted event"
        )
