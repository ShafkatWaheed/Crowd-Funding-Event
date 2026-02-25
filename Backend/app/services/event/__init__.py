"""
Event service: re-export all public functions so "from app.services import event as event_service" still works.
"""
from app.services.event.permissions import (
    _event_can_edit,
    is_main_organizer,
    user_can_edit_event,
    user_can_read_event_mgmt,
)
from app.services.event.crud import (
    auto_transition_status,
    create,
    get_by_id,
    get_or_404,
    list_events,
    list_events_for_map,
    publish_event,
    update,
)
from app.services.event.lifecycle import (
    approve_extension,
    cancel_event,
    delete_or_cancel,
    extend_funding,
    reactivate_event,
    reject_extension,
    set_event_date,
    start_selling_tickets,
)
from app.services.event.organizers import (
    add_event_organizer,
    list_event_organizers,
    remove_event_organizer,
)
from app.services.event.discounts import (
    compute_event_discounts_for_user,
    create_event_discount,
    delete_event_discount,
    list_event_discounts,
)
from app.services.event.queries import (
    clone_event,
    get_coming_soon_events,
    get_my_registered_events,
    get_popular_events,
    get_trending_events,
)
from app.services.event.attendance import (
    get_organizer_trust_score,
    list_organizer_customers,
    record_customer_attendance,
)

__all__ = [
    "_event_can_edit",
    "add_event_organizer",
    "approve_extension",
    "auto_transition_status",
    "cancel_event",
    "clone_event",
    "compute_event_discounts_for_user",
    "create",
    "create_event_discount",
    "delete_event_discount",
    "delete_or_cancel",
    "extend_funding",
    "get_by_id",
    "get_coming_soon_events",
    "get_my_registered_events",
    "get_or_404",
    "get_organizer_trust_score",
    "get_popular_events",
    "get_trending_events",
    "is_main_organizer",
    "list_event_discounts",
    "list_event_organizers",
    "list_events",
    "list_events_for_map",
    "list_organizer_customers",
    "publish_event",
    "reactivate_event",
    "record_customer_attendance",
    "reject_extension",
    "remove_event_organizer",
    "set_event_date",
    "start_selling_tickets",
    "update",
    "user_can_edit_event",
    "user_can_read_event_mgmt",
]
