"""Tests for Pydantic schema field validators — no DB needed."""
import pytest
from pydantic import ValidationError

from app.schemas.event import EventCreate, EventUpdate, CancelBody, EventPostCreate, EventDiscountCreate


class TestEventCreateBounds:
    def test_title_too_long(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="x" * 201, max_capacity=100)

    def test_title_empty(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="", max_capacity=100)

    def test_description_too_long(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, description="x" * 10_001)

    def test_max_capacity_zero(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=0)

    def test_max_capacity_negative(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=-1)

    def test_max_capacity_over_million(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=1_000_001)

    def test_funding_goal_negative(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, funding_goal_cents=-1)

    def test_min_pledge_zero(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, min_pledge_cents=0)

    def test_discount_percent_over_100(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, common_discount_percent=101)

    def test_pledge_discount_percent_negative(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, pledge_discount_percent=-1)

    def test_min_age_negative(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, min_age=-1)

    def test_min_age_over_120(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, min_age=121)

    def test_refund_deadline_days_negative(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, refund_deadline_days=-1)

    def test_max_discount_percent_over_100(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, max_discount_percent=101)

    def test_waitlist_max_size_zero(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, waitlist_max_size=0)

    def test_parking_info_too_long(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, parking_info="x" * 2001)

    def test_transit_info_too_long(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, transit_info="x" * 2001)

    def test_rideshare_info_too_long(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, rideshare_info="x" * 2001)

    def test_accessibility_info_too_long(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, accessibility_info="x" * 2001)

    def test_refund_deadline_percent_over_100(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, refund_deadline_percent=101)

    def test_reserved_spots_release_percent_over_100(self):
        with pytest.raises(ValidationError):
            EventCreate(venue_id=1, title="OK", max_capacity=100, reserved_spots_release_percent=101)

    def test_valid_event_create(self):
        e = EventCreate(venue_id=1, title="My Event", max_capacity=100)
        assert e.title == "My Event"
        assert e.max_capacity == 100

    def test_valid_event_create_all_fields(self):
        e = EventCreate(
            venue_id=1,
            title="Full Event",
            description="A great event",
            max_capacity=500,
            funding_goal_cents=100000,
            min_pledge_cents=1000,
            common_discount_percent=10,
            pledge_discount_percent=5,
            min_age=21,
            max_discount_percent=50,
            waitlist_max_size=100,
            parking_info="Lot A",
            transit_info="Bus 42",
            rideshare_info="Use Uber",
            accessibility_info="Wheelchair accessible",
            refund_deadline_days=7,
            refund_deadline_percent=80,
            reserved_spots_release_percent=50,
        )
        assert e.funding_goal_cents == 100000
        assert e.min_age == 21


class TestEventUpdateBounds:
    def test_title_too_long(self):
        with pytest.raises(ValidationError):
            EventUpdate(title="x" * 201)

    def test_title_empty(self):
        with pytest.raises(ValidationError):
            EventUpdate(title="")

    def test_max_capacity_zero(self):
        with pytest.raises(ValidationError):
            EventUpdate(max_capacity=0)

    def test_max_capacity_over_million(self):
        with pytest.raises(ValidationError):
            EventUpdate(max_capacity=1_000_001)

    def test_funding_goal_negative(self):
        with pytest.raises(ValidationError):
            EventUpdate(funding_goal_cents=-1)

    def test_min_pledge_zero(self):
        with pytest.raises(ValidationError):
            EventUpdate(min_pledge_cents=0)

    def test_discount_percent_over_100(self):
        with pytest.raises(ValidationError):
            EventUpdate(common_discount_percent=101)

    def test_min_age_over_120(self):
        with pytest.raises(ValidationError):
            EventUpdate(min_age=121)

    def test_parking_info_too_long(self):
        with pytest.raises(ValidationError):
            EventUpdate(parking_info="x" * 2001)

    def test_valid_partial_update(self):
        u = EventUpdate(title="New Title", max_capacity=50)
        assert u.title == "New Title"

    def test_all_none_is_valid(self):
        u = EventUpdate()
        assert u.title is None


class TestCancelBodyBounds:
    def test_reason_too_long(self):
        with pytest.raises(ValidationError):
            CancelBody(reason="x" * 2001)

    def test_reason_empty(self):
        with pytest.raises(ValidationError):
            CancelBody(reason="")

    def test_valid_reason(self):
        c = CancelBody(reason="Weather issues")
        assert c.reason == "Weather issues"


class TestEventPostCreateBounds:
    def test_content_empty(self):
        with pytest.raises(ValidationError):
            EventPostCreate(content="")

    def test_content_too_long(self):
        with pytest.raises(ValidationError):
            EventPostCreate(content="x" * 5001)

    def test_valid_content(self):
        p = EventPostCreate(content="Hello world")
        assert p.content == "Hello world"


class TestEventDiscountCreateBounds:
    def test_name_empty(self):
        with pytest.raises(ValidationError):
            EventDiscountCreate(name="", discount_type="ticket_percent", value=10)

    def test_name_too_long(self):
        with pytest.raises(ValidationError):
            EventDiscountCreate(name="x" * 201, discount_type="ticket_percent", value=10)

    def test_value_zero(self):
        with pytest.raises(ValidationError):
            EventDiscountCreate(name="10off", discount_type="ticket_percent", value=0)

    def test_value_negative(self):
        with pytest.raises(ValidationError):
            EventDiscountCreate(name="10off", discount_type="ticket_percent", value=-1)

    def test_milestone_percent_over_100(self):
        with pytest.raises(ValidationError):
            EventDiscountCreate(
                name="MS", discount_type="funding_milestone",
                value=10, milestone_percent=101
            )

    def test_milestone_percent_zero(self):
        with pytest.raises(ValidationError):
            EventDiscountCreate(
                name="MS", discount_type="funding_milestone",
                value=10, milestone_percent=0
            )

    def test_milestone_discount_value_zero(self):
        with pytest.raises(ValidationError):
            EventDiscountCreate(
                name="MS", discount_type="funding_milestone",
                value=10, milestone_discount_value=0
            )

    def test_valid_discount(self):
        d = EventDiscountCreate(name="Early Bird", discount_type="ticket_percent", value=15)
        assert d.name == "Early Bird"
        assert d.value == 15


from app.schemas.funding import PledgeBody, TierReservation
from app.schemas.sponsor import SponsorProfileCreate, CategoryCreate, BidCreate
from app.schemas.ticket_strategy import TicketStrategyTierInput, TicketStrategyCreate
from app.schemas.discount_strategy import DiscountStrategyCreate


class TestPledgeBodyBounds:
    def test_amount_negative(self):
        with pytest.raises(ValidationError):
            PledgeBody(amount_cents=-1)

    def test_amount_zero(self):
        with pytest.raises(ValidationError):
            PledgeBody(amount_cents=0)

    def test_reserved_spots_negative(self):
        with pytest.raises(ValidationError):
            PledgeBody(amount_cents=500, reserved_spots=-1)

    def test_tier_spots_zero(self):
        with pytest.raises(ValidationError):
            TierReservation(tier_id=1, spots=0)

    def test_valid_pledge(self):
        p = PledgeBody(amount_cents=1000, reserved_spots=2)
        assert p.amount_cents == 1000


class TestSponsorBounds:
    def test_company_name_empty(self):
        with pytest.raises(ValidationError):
            SponsorProfileCreate(company_name="", contact_name="A", profession="B")

    def test_company_name_too_long(self):
        with pytest.raises(ValidationError):
            SponsorProfileCreate(company_name="x" * 201, contact_name="A", profession="B")

    def test_category_spots_zero(self):
        with pytest.raises(ValidationError):
            CategoryCreate(name="Gold", total_spots=0, min_bid_cents=100)

    def test_category_min_bid_negative(self):
        with pytest.raises(ValidationError):
            CategoryCreate(name="Gold", total_spots=5, min_bid_cents=-1)

    def test_bid_amount_zero(self):
        with pytest.raises(ValidationError):
            BidCreate(amount_cents=0)

    def test_bid_proposal_too_long(self):
        with pytest.raises(ValidationError):
            BidCreate(amount_cents=1000, proposal_text="x" * 5001)

    def test_valid_category(self):
        c = CategoryCreate(name="Gold", total_spots=5, min_bid_cents=10000)
        assert c.total_spots == 5


class TestTicketStrategyBounds:
    def test_tier_price_negative(self):
        with pytest.raises(ValidationError):
            TicketStrategyTierInput(name="VIP", price_cents=-1)

    def test_tier_name_empty(self):
        with pytest.raises(ValidationError):
            TicketStrategyTierInput(name="", price_cents=1000)

    def test_strategy_name_empty(self):
        with pytest.raises(ValidationError):
            TicketStrategyCreate(name="", tiers=[])

    def test_valid_tier(self):
        t = TicketStrategyTierInput(name="General", price_cents=0)
        assert t.price_cents == 0  # free tier is valid


class TestDiscountStrategyBounds:
    def test_value_zero(self):
        with pytest.raises(ValidationError):
            DiscountStrategyCreate(name="10off", discount_type="ticket_percent", value=0)

    def test_name_empty(self):
        with pytest.raises(ValidationError):
            DiscountStrategyCreate(name="", discount_type="ticket_percent", value=10)

    def test_valid_discount(self):
        d = DiscountStrategyCreate(name="Early", discount_type="ticket_percent", value=15)
        assert d.value == 15
