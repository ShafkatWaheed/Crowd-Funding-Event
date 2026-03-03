"""Tests for age verification service: calculate_age, enforce_age_limit, validate_organizer."""
from datetime import date, timedelta

import pytest

from app.services.age_verification import calculate_age, enforce_age_limit, validate_organizer_can_restrict_age
from app.core.exceptions import ForbiddenError


# ── calculate_age ─────────────────────────────────────────────────


def test_calculate_age_exact():
    """Age calculation for a known birthday."""
    today = date.today()
    birthday = today.replace(year=today.year - 25)
    assert calculate_age(birthday) == 25


def test_calculate_age_before_birthday():
    """Age is one less if birthday hasn't happened yet this year."""
    today = date.today()
    future_birthday = today + timedelta(days=30)
    birthday = future_birthday.replace(year=today.year - 20)
    assert calculate_age(birthday) == 19


def test_calculate_age_on_birthday():
    """Age is exact on the birthday."""
    today = date.today()
    birthday = today.replace(year=today.year - 18)
    assert calculate_age(birthday) == 18


# ── enforce_age_limit ─────────────────────────────────────────────


def test_enforce_not_restricted():
    """No error when event is not age-restricted."""
    enforce_age_limit(None, event_age_restricted=False, event_min_age=0)


def test_enforce_no_birthday_raises():
    """Error when event is restricted but user has no birthday."""
    with pytest.raises(ForbiddenError, match="birthday"):
        enforce_age_limit(None, event_age_restricted=True, event_min_age=18)


def test_enforce_underage_raises():
    """Error when user is under the minimum age."""
    young = date.today() - timedelta(days=365 * 16)
    with pytest.raises(ForbiddenError, match="at least 18"):
        enforce_age_limit(young, event_age_restricted=True, event_min_age=18)


def test_enforce_of_age_passes():
    """No error when user meets the minimum age."""
    old_enough = date.today() - timedelta(days=365 * 21)
    enforce_age_limit(old_enough, event_age_restricted=True, event_min_age=18)


def test_enforce_custom_action():
    """Custom action string appears in error message."""
    with pytest.raises(ForbiddenError, match="sponsor this event"):
        enforce_age_limit(None, event_age_restricted=True, event_min_age=18, action="sponsor this event")


# ── validate_organizer_can_restrict_age ───────────────────────────


def test_organizer_not_restricted():
    """No error when not creating an age-restricted event."""
    validate_organizer_can_restrict_age(None, age_restricted=False)


def test_organizer_no_birthday_raises():
    """Error when organizer has no birthday but wants age restriction."""
    with pytest.raises(ForbiddenError, match="birthday"):
        validate_organizer_can_restrict_age(None, age_restricted=True)


def test_organizer_underage_raises():
    """Error when organizer is under 18."""
    young = date.today() - timedelta(days=365 * 17)
    with pytest.raises(ForbiddenError, match="at least 18"):
        validate_organizer_can_restrict_age(young, age_restricted=True)


def test_organizer_of_age_passes():
    """No error when organizer is 18+."""
    adult = date.today() - timedelta(days=365 * 25)
    validate_organizer_can_restrict_age(adult, age_restricted=True)
