"""Shared response builders for sponsor API."""


def _template_to_response(cat) -> dict:
    return {
        "id": cat.id,
        "organizer_id": cat.organizer_id,
        "is_template": cat.is_template,
        "name": cat.name,
        "description": cat.description,
        "image_url": cat.image_url,
        "total_spots": cat.total_spots,
        "min_bid_cents": cat.min_bid_cents,
        "sort_order": cat.sort_order,
    }


def _category_to_response(
    cat,
    bid_count: int = 0,
    bid_amounts: list[int] | None = None,
    my_bid_count: int = 0,
    my_bids: list[dict] | None = None,
    prereq_count: int = 0,
) -> dict:
    return {
        "id": cat.id,
        "event_id": cat.event_id,
        "name": cat.name,
        "description": cat.description,
        "image_url": cat.image_url,
        "total_spots": cat.total_spots,
        "filled_spots": cat.filled_spots,
        "min_bid_cents": cat.min_bid_cents,
        "sort_order": cat.sort_order,
        "bid_count": bid_count,
        "bid_amounts": bid_amounts or [],
        "my_bid_count": my_bid_count,
        "my_bids": my_bids or [],
        "prereq_count": prereq_count,
    }
