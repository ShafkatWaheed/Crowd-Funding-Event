# Implementation Guide — Eight Feature Batch

This document describes the **exact** implementation for each feature: new files, modified files, code snippets, database migrations, API contracts, and frontend widgets. Follow the batch order to avoid dependency issues.

---

## Table of Contents

1. [Privacy Rules (Cross-Cutting)](#0-privacy-rules-cross-cutting)
2. [Feature 1 — In-App Notification System](#feature-1--in-app-notification-system)
3. [Feature 2 — Organizer Public Profile](#feature-2--organizer-public-profile)
4. [Feature 6 — Event Bookmarks](#feature-6--event-bookmarks)
5. [Feature 3 — Enhanced Sponsor Info for Organizers](#feature-3--enhanced-sponsor-info-for-organizers)
6. [Feature 4 — Sponsorship Category Prerequisites](#feature-4--sponsorship-category-prerequisites)
7. [Feature 5 — Multi-Directional Rating System](#feature-5--multi-directional-rating-system)
8. [Feature 7 — Multi-Role System](#feature-7--multi-role-system)

---

## 0. Privacy Rules (Cross-Cutting)

These changes apply across the codebase **before** any feature work begins.

### 0.1 Backend — Remove attendee email from receipt schemas (keep organizer email/phone)

**Rule: Organizer contact info stays on receipts so customers can reach the organizer.
Customer/sponsor (attendee) email is removed — their personal info should not be exposed.**

**File: `Backend/app/schemas/ticket.py`**

Remove `attendee_email` only from `TicketReceiptResponse` (line 106):

```python
# REMOVE this line only:
attendee_email: str | None = None
```

Keep `organizer_email` and `organizer_phone` — they stay.

Remove `attendee_email` only from `PurchaseGroupReceiptResponse` (line 178):

```python
# REMOVE this line only:
attendee_email: str | None = None
```

Keep `organizer_email` and `organizer_phone` — they stay.

### 0.2 Backend — Stop populating attendee email in receipt endpoints (keep organizer)

**File: `Backend/app/api/v1/events.py`**

Organizer info stays unchanged — keep `organizer_email` and `organizer_phone` as-is.
Only fix the `organizer_name` fallback to not leak email as a name:

```python
# BEFORE (line 1221):
organizer_name = organizer.display_name or organizer.email

# AFTER (display_name is mandatory):
organizer_name = organizer.display_name
```

Remove attendee email only (~line 1231-1232):

```python
# BEFORE:
attendee_name=(sale.user.display_name or sale.user.email) if sale.user else None,
attendee_email=sale.user.email if sale.user else None,

# AFTER (display_name is mandatory, remove attendee_email):
attendee_name=sale.user.display_name if sale.user else None,
```

Apply the same changes to:
- Purchase group receipt endpoint in `events.py` (~lines 1289-1327): fix `organizer_name` fallback, remove `attendee_email`
- `Backend/app/api/v1/users.py` single ticket receipt (~lines 172-199): same fixes

### 0.3 Backend — Fix sponsor email fallback

**File: `Backend/app/api/v1/sponsors.py`**

Line 186 in `_bid_to_response` — when no `SponsorProfile` exists, the fallback currently
leaks the user's email into `company_name`. Since `display_name` is mandatory (set at
registration), simply use it directly — no email fallback needed:

```python
# BEFORE (line 186):
fallback_name = (user.display_name or user.email) if user else "Unknown"

# AFTER:
fallback_name = user.display_name if user else "Unknown"
```

When a `SponsorProfile` **does** exist, `company_name` is already used (line 173),
so no change needed there. The `contact_name` fallback on line 191 already uses
`display_name` without email, which is correct.

### 0.4 Frontend — Remove attendee email from receipt screens (keep organizer email/phone)

**Organizer email and phone stay visible on receipts — customers need to be able to contact the organizer.
Only the attendee (customer/sponsor) email is removed.**

**File: `FrontEnd/lib/screens/event/ticket_receipt_screen.dart`**

Keep organizer email/phone rows as-is (~lines 278-281). Only remove the attendee email row (~lines 289-290):

```dart
// REMOVE attendee email only:
if (attendeeEmail.isNotEmpty)
  _detailRow(context, 'Email', attendeeEmail),
```

Remove the attendee email variable (~line 111):

```dart
// REMOVE:
final attendeeEmail = r['attendee_email'] ?? '';
```

**File: `FrontEnd/lib/screens/event/purchase_group_receipt_screen.dart`**

Keep organizer email/phone rows as-is (~lines 254-259). Only remove:
- Attendee email row (~lines 266-267)
- Attendee email variable read (~line 127)
- Fix QR fallback at line 435: replace `'user_id': receipt['attendee_email']` with `'user_id': receipt['user_id']`

---

## Feature 1 — In-App Notification System

### 1.1 Backend Model

**New file: `Backend/app/models/notification.py`**

```python
"""
In-app notification model.
"""
import enum
from datetime import datetime
from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class NotificationType(str, enum.Enum):
    # Registration
    registration_confirmed = "registration_confirmed"
    registration_waitlisted = "registration_waitlisted"
    waitlist_approved = "waitlist_approved"
    waitlist_rejected = "waitlist_rejected"

    # Funding / Pledges
    pledge_confirmed = "pledge_confirmed"
    funding_goal_reached = "funding_goal_reached"
    milestone_reached = "milestone_reached"

    # Tickets
    ticket_purchased = "ticket_purchased"
    ticket_waitlist_approved = "ticket_waitlist_approved"
    ticket_waitlist_rejected = "ticket_waitlist_rejected"

    # Refunds
    refund_issued = "refund_issued"

    # Event lifecycle
    event_status_changed = "event_status_changed"
    event_approved = "event_approved"
    event_rejected = "event_rejected"
    event_cancelled = "event_cancelled"
    schedule_updated = "schedule_updated"

    # Sponsor
    bid_received = "bid_received"
    bid_accepted = "bid_accepted"
    bid_rejected = "bid_rejected"
    sponsor_ticket_generated = "sponsor_ticket_generated"

    # Social (used by Feature 5)
    new_rating_received = "new_rating_received"

    # Bookmarks (used by Feature 6)
    bookmarked_event_update = "bookmarked_event_update"


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    type: Mapped[NotificationType] = mapped_column(Enum(NotificationType), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    data: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    user = relationship("User")
```

### 1.2 Register model in `__init__.py`

**File: `Backend/app/models/__init__.py`**

Add to imports:

```python
from app.models.notification import Notification, NotificationType
```

Add to `__all__`:

```python
"Notification",
"NotificationType",
```

### 1.3 Alembic Migration

**New file: `Backend/alembic/versions/ii60i0j1k2l3_notifications.py`**

```python
"""Add notifications table.

Revision ID: ii60i0j1k2l3
Revises: hh50h9i0j1k2
Create Date: 2026-02-18
"""
from alembic import op
import sqlalchemy as sa

revision = "ii60i0j1k2l3"
down_revision = "hh50h9i0j1k2"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column(
            "type",
            sa.Enum(
                "registration_confirmed", "registration_waitlisted",
                "waitlist_approved", "waitlist_rejected",
                "pledge_confirmed", "funding_goal_reached", "milestone_reached",
                "ticket_purchased", "ticket_waitlist_approved", "ticket_waitlist_rejected",
                "refund_issued",
                "event_status_changed", "event_approved", "event_rejected",
                "event_cancelled", "schedule_updated",
                "bid_received", "bid_accepted", "bid_rejected",
                "sponsor_ticket_generated",
                "new_rating_received", "bookmarked_event_update",
                name="notificationtype",
            ),
            nullable=False,
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("data", sa.JSON(), nullable=True),
        sa.Column("is_read", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_notifications_user_id", "notifications", ["user_id"])
    op.create_index("ix_notifications_user_unread", "notifications", ["user_id", "is_read"])

def downgrade() -> None:
    op.drop_index("ix_notifications_user_unread")
    op.drop_index("ix_notifications_user_id")
    op.drop_table("notifications")
    op.execute("DROP TYPE IF EXISTS notificationtype")
```

### 1.4 Notification Service

**New file: `Backend/app/services/notification_service.py`**

```python
"""
In-app notification service.
"""
from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationType

logger = logging.getLogger("notifications")


async def create_notification(
    db: AsyncSession,
    *,
    user_id: int,
    type: NotificationType,
    title: str,
    message: str,
    data: dict[str, Any] | None = None,
) -> Notification:
    """Create a single notification for one user."""
    notif = Notification(
        user_id=user_id,
        type=type,
        title=title,
        message=message,
        data=data,
    )
    db.add(notif)
    await db.flush()
    return notif


async def create_bulk_notifications(
    db: AsyncSession,
    *,
    user_ids: list[int],
    type: NotificationType,
    title: str,
    message: str,
    data: dict[str, Any] | None = None,
) -> int:
    """Create the same notification for multiple users. Returns count created."""
    unique_ids = list(set(user_ids))
    for uid in unique_ids:
        db.add(Notification(
            user_id=uid,
            type=type,
            title=title,
            message=message,
            data=data,
        ))
    await db.flush()
    logger.info("Created %d notifications of type %s", len(unique_ids), type.value)
    return len(unique_ids)


async def list_notifications(
    db: AsyncSession,
    *,
    user_id: int,
    unread_only: bool = False,
    offset: int = 0,
    limit: int = 20,
) -> list[Notification]:
    q = select(Notification).where(Notification.user_id == user_id)
    if unread_only:
        q = q.where(Notification.is_read == False)
    q = q.order_by(Notification.created_at.desc()).offset(offset).limit(limit)
    return list((await db.execute(q)).scalars().all())


async def unread_count(db: AsyncSession, *, user_id: int) -> int:
    q = select(func.count()).where(
        Notification.user_id == user_id,
        Notification.is_read == False,
    )
    return (await db.execute(q)).scalar_one()


async def mark_read(db: AsyncSession, *, notification_id: int, user_id: int) -> bool:
    result = await db.execute(
        update(Notification)
        .where(Notification.id == notification_id, Notification.user_id == user_id)
        .values(is_read=True)
    )
    return result.rowcount > 0


async def mark_all_read(db: AsyncSession, *, user_id: int) -> int:
    result = await db.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read == False)
        .values(is_read=True)
    )
    return result.rowcount
```

### 1.5 Notification API Router

**New file: `Backend/app/api/v1/notifications.py`**

```python
"""
In-app notification endpoints.
"""
from fastapi import APIRouter, Query

from app.dependencies import CurrentUser, DbSession
from app.services import notification_service as notif_svc

router = APIRouter()


@router.get("/notifications")
async def list_notifications(
    db: DbSession,
    current_user: CurrentUser,
    unread_only: bool = Query(False),
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List notifications for the current user, newest first."""
    items = await notif_svc.list_notifications(
        db, user_id=current_user.id, unread_only=unread_only,
        offset=offset, limit=limit,
    )
    return [
        {
            "id": n.id,
            "type": n.type.value,
            "title": n.title,
            "message": n.message,
            "data": n.data,
            "is_read": n.is_read,
            "created_at": n.created_at.isoformat() if n.created_at else None,
        }
        for n in items
    ]


@router.get("/notifications/unread-count")
async def get_unread_count(db: DbSession, current_user: CurrentUser):
    """Get the number of unread notifications."""
    count = await notif_svc.unread_count(db, user_id=current_user.id)
    return {"unread_count": count}


@router.patch("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: int,
    db: DbSession,
    current_user: CurrentUser,
):
    """Mark a single notification as read."""
    ok = await notif_svc.mark_read(db, notification_id=notification_id, user_id=current_user.id)
    return {"success": ok}


@router.patch("/notifications/read-all")
async def mark_all_notifications_read(db: DbSession, current_user: CurrentUser):
    """Mark all notifications as read for the current user."""
    count = await notif_svc.mark_all_read(db, user_id=current_user.id)
    return {"marked_read": count}
```

### 1.6 Register notification router

**File: `Backend/app/api/v1/router.py`**

Add import and mount:

```python
from app.api.v1 import notifications

api_router.include_router(notifications.router, prefix="/me", tags=["notifications"])
```

### 1.7 Integration — Where to call `create_notification`

For each trigger, add the call inside the existing endpoint **after** the main operation succeeds and **before** `return`. Use `db` directly (not BackgroundTasks) since it's a simple INSERT.

**File: `Backend/app/api/v1/events.py`**

| Endpoint | After line | Code to add |
|----------|-----------|-------------|
| `register_event` (~line 870) | After `reg = await registration_service.register(...)` | See below |
| `unregister_event` (~line 920) | After refund result | `create_notification(db, user_id=current_user.id, type=NotificationType.refund_issued, ...)` |
| `cancel_event` (~line 510) | After `event = await event_service.cancel_event(...)` | `create_bulk_notifications(db, user_ids=..., type=NotificationType.event_cancelled, ...)` |
| `purchase_ticket` (~line 1090) | After `sales = await ticket_service.purchase_ticket(...)` | `create_notification(db, user_id=current_user.id, type=NotificationType.ticket_purchased, ...)` |
| `approve_waitlisted_ticket` (~line 1398) | After approve | `create_notification(db, user_id=sale.user_id, type=NotificationType.ticket_waitlist_approved, ...)` |
| `reject_waitlisted_ticket` (~line 1412) | After reject | `create_notification(db, user_id=sale.user_id, type=NotificationType.ticket_waitlist_rejected, ...)` |
| `publish_event` (~line 672) | After publish | `create_notification(db, user_id=current_user.id, type=NotificationType.event_approved, ...)` |
| pledge endpoints | After pledge creation | `create_notification(db, user_id=current_user.id, type=NotificationType.pledge_confirmed, ...)` |
| schedule update endpoint | After update | `create_bulk_notifications(db, user_ids=registrant_ids, type=NotificationType.schedule_updated, ...)` |

**Registration example (in `register_event` endpoint):**

```python
from app.services import notification_service as notif_svc
from app.models.notification import NotificationType

# After: reg = await registration_service.register(db, event_id=event_id, user=current_user)
if reg.status.value == "registered":
    await notif_svc.create_notification(
        db,
        user_id=current_user.id,
        type=NotificationType.registration_confirmed,
        title="Registration Confirmed",
        message=f"You are registered for the event.",
        data={"event_id": event_id},
    )
elif reg.status.value == "waitlist":
    await notif_svc.create_notification(
        db,
        user_id=current_user.id,
        type=NotificationType.registration_waitlisted,
        title="Added to Waitlist",
        message=f"You have been added to the waitlist.",
        data={"event_id": event_id},
    )
```

**Cancel event example (in `cancel_event` endpoint):**

```python
# After: event = await event_service.cancel_event(db, event, current_user, reason=body.reason)
# Gather all affected user IDs
from app.models.registration import Registration, RegistrationStatus
from app.models.funding import Funding, FundingStatus
affected_q = select(Registration.user_id).where(
    Registration.event_id == event.id,
    Registration.status.in_([RegistrationStatus.registered, RegistrationStatus.waitlist]),
)
affected_ids = [r for r in (await db.execute(affected_q)).scalars().all()]
pledger_q = select(Funding.user_id).where(
    Funding.event_id == event.id,
    Funding.status.in_([FundingStatus.pledged, FundingStatus.refunded]),
)
pledger_ids = [r for r in (await db.execute(pledger_q)).scalars().all()]
all_ids = list(set(affected_ids + pledger_ids))

if all_ids:
    await notif_svc.create_bulk_notifications(
        db,
        user_ids=all_ids,
        type=NotificationType.event_cancelled,
        title="Event Cancelled",
        message=f'"{event.title}" has been cancelled. {body.reason or ""}',
        data={"event_id": event.id},
    )
```

**File: `Backend/app/api/v1/sponsors.py`**

| Endpoint | Code to add |
|----------|-------------|
| `place_bid` (~line 224) | Notify organizer: `create_notification(db, user_id=organizer_id, type=NotificationType.bid_received, ...)` |
| `accept_bid` (~line 291) | Notify sponsor: `create_notification(db, user_id=bid.sponsor_user_id, type=NotificationType.bid_accepted, ...)` |
| `reject_bid` (~line 309) | Notify sponsor: `create_notification(db, user_id=bid.sponsor_user_id, type=NotificationType.bid_rejected, ...)` |

**place_bid example:**

```python
# After: bid = await sponsor_svc.place_bid(db, cat_id, current_user, data)
# Get event organizer ID to notify
from sqlalchemy import select as sel
from app.models.sponsor import SponsorshipCategory
cat = (await db.execute(sel(SponsorshipCategory).where(SponsorshipCategory.id == cat_id))).scalar_one()
from app.models.event import Event
event = (await db.execute(sel(Event).where(Event.id == cat.event_id))).scalar_one()
await notif_svc.create_notification(
    db,
    user_id=event.organizer_id,
    type=NotificationType.bid_received,
    title="New Sponsor Bid",
    message=f"A new bid of ${data.amount_cents / 100:.2f} was placed on '{cat.name}'.",
    data={"event_id": cat.event_id, "category_id": cat_id, "bid_id": bid.id},
)
```

**File: `Backend/app/services/registration.py`**

In `approve_waitlist()` (~line 112) and `reject_waitlist()` (~line 157), add notification calls at the end:

```python
# In approve_waitlist, after status update:
from app.services import notification_service as notif_svc
from app.models.notification import NotificationType
await notif_svc.create_notification(
    db, user_id=reg.user_id,
    type=NotificationType.waitlist_approved,
    title="Waitlist Approved",
    message="Your registration has been approved!",
    data={"event_id": reg.event_id},
)

# In reject_waitlist, after status update:
await notif_svc.create_notification(
    db, user_id=reg.user_id,
    type=NotificationType.waitlist_rejected,
    title="Waitlist Rejected",
    message="Your registration request was not approved.",
    data={"event_id": reg.event_id},
)
```

**File: `Backend/app/api/v1/admin.py`**

In event approval endpoint, notify organizer:

```python
await notif_svc.create_notification(
    db, user_id=event.organizer_id,
    type=NotificationType.event_approved,
    title="Event Approved",
    message=f'Your event "{event.title}" has been approved.',
    data={"event_id": event.id},
)
```

In event rejection endpoint:

```python
await notif_svc.create_notification(
    db, user_id=event.organizer_id,
    type=NotificationType.event_rejected,
    title="Event Rejected",
    message=f'Your event "{event.title}" was not approved.',
    data={"event_id": event.id},
)
```

### 1.8 Frontend — Notification Provider

**New file: `FrontEnd/lib/providers/notification_provider.dart`**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _api;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  Timer? _pollTimer;

  NotificationProvider(this._api);

  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;

  void startPolling() {
    _pollTimer?.cancel();
    _fetchUnreadCount();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchUnreadCount());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final resp = await _api.dio.get('/me/notifications/unread-count');
      final count = resp.data['unread_count'] ?? 0;
      if (count != _unreadCount) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadNotifications({bool unreadOnly = false, int offset = 0}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _api.dio.get('/me/notifications', queryParameters: {
        'unread_only': unreadOnly,
        'offset': offset,
        'limit': 20,
      });
      if (offset == 0) {
        _notifications = List<Map<String, dynamic>>.from(resp.data);
      } else {
        _notifications.addAll(List<Map<String, dynamic>>.from(resp.data));
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markRead(int notificationId) async {
    try {
      await _api.dio.patch('/me/notifications/$notificationId/read');
      final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (idx >= 0) {
        _notifications[idx]['is_read'] = true;
      }
      _unreadCount = (_unreadCount - 1).clamp(0, 999);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.dio.patch('/me/notifications/read-all');
      for (final n in _notifications) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
```

### 1.9 Frontend — Register Provider

**File: `FrontEnd/lib/main.dart`**

Add to imports:

```dart
import 'providers/notification_provider.dart';
```

Add to `MultiProvider.providers` list (after `EventProvider`):

```dart
ChangeNotifierProvider(create: (ctx) {
  final notifProvider = NotificationProvider(apiService);
  return notifProvider;
}),
```

Start polling when user is authenticated. In `_AppShellState.build()`, after the `authProvider` check:

```dart
// Start/stop notification polling based on auth state
final notifProvider = context.read<NotificationProvider>();
if (authProvider.isAuthenticated) {
  notifProvider.startPolling();
} else {
  notifProvider.stopPolling();
}
```

### 1.10 Frontend — Notification Bell in AppBar

**File: `FrontEnd/lib/screens/home/home_screen.dart`**

In the AppBar `actions` list, add before existing actions:

```dart
Consumer<NotificationProvider>(
  builder: (ctx, notifProv, _) {
    return IconButton(
      icon: Badge(
        isLabelVisible: notifProv.unreadCount > 0,
        label: Text(
          notifProv.unreadCount > 99 ? '99+' : '${notifProv.unreadCount}',
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
        backgroundColor: AppTheme.errorColor,
        child: Icon(Icons.notifications_outlined, color: AppTheme.primaryOf(context)),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const NotificationScreen(),
        ));
      },
    );
  },
),
```

### 1.11 Frontend — Notification Screen

**New file: `FrontEnd/lib/screens/notification/notification_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/shimmer_loaders.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationProvider>().loadNotifications();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'registration_confirmed':
        return Icons.check_circle_outline;
      case 'registration_waitlisted':
        return Icons.hourglass_top;
      case 'waitlist_approved':
        return Icons.thumb_up_outlined;
      case 'waitlist_rejected':
        return Icons.thumb_down_outlined;
      case 'pledge_confirmed':
        return Icons.volunteer_activism;
      case 'funding_goal_reached':
        return Icons.flag_outlined;
      case 'milestone_reached':
        return Icons.emoji_events_outlined;
      case 'ticket_purchased':
        return Icons.confirmation_number_outlined;
      case 'ticket_waitlist_approved':
        return Icons.check_circle;
      case 'ticket_waitlist_rejected':
        return Icons.cancel_outlined;
      case 'refund_issued':
        return Icons.money_off;
      case 'event_cancelled':
        return Icons.event_busy;
      case 'event_status_changed':
        return Icons.sync;
      case 'event_approved':
        return Icons.verified;
      case 'event_rejected':
        return Icons.block;
      case 'schedule_updated':
        return Icons.schedule;
      case 'bid_received':
        return Icons.gavel;
      case 'bid_accepted':
        return Icons.handshake;
      case 'bid_rejected':
        return Icons.cancel;
      case 'sponsor_ticket_generated':
        return Icons.badge;
      case 'new_rating_received':
        return Icons.star_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    if (type.contains('cancel') || type.contains('reject')) return AppTheme.errorColor;
    if (type.contains('approved') || type.contains('confirmed') || type.contains('accepted')) {
      return AppTheme.successColor;
    }
    if (type.contains('waitlist')) return AppTheme.warningColor;
    if (type.contains('bid')) return AppTheme.accentColor;
    return AppTheme.textSecondary;
  }

  void _onTapNotification(Map<String, dynamic> notif) {
    final provider = context.read<NotificationProvider>();
    if (notif['is_read'] != true) {
      provider.markRead(notif['id']);
    }
    // Navigate based on notification data
    final data = notif['data'] as Map<String, dynamic>?;
    if (data != null && data['event_id'] != null) {
      Navigator.pushNamed(context, '/events/${data['event_id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationProvider>().markAllRead(),
            child: Text('Mark all read', style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (ctx, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return ListView.builder(
              itemCount: 8,
              itemBuilder: (_, __) => const ShimmerEventCard(),
            );
          }
          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64,
                      color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(height: 12),
                  Text('No notifications yet',
                      style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(),
            child: ListView.separated(
              itemCount: provider.notifications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1, color: AppTheme.dividerOf(context),
              ),
              itemBuilder: (ctx, i) {
                final n = provider.notifications[i];
                final type = n['type'] ?? '';
                final isRead = n['is_read'] == true;
                return ListTile(
                  tileColor: isRead ? null : AppTheme.accentColor.withValues(alpha: 0.05),
                  leading: CircleAvatar(
                    backgroundColor: _colorForType(type).withValues(alpha: 0.15),
                    child: Icon(_iconForType(type), color: _colorForType(type), size: 20),
                  ),
                  title: Text(
                    n['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  subtitle: Text(
                    n['message'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
                  ),
                  trailing: Text(
                    _formatTime(n['created_at']),
                    style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 11),
                  ),
                  onTap: () => _onTapNotification(n),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dt);
  }
}
```

---

## Feature 2 — Organizer Public Profile

### 2.1 Backend API

**New file: `Backend/app/api/v1/public_profiles.py`**

```python
"""
Public profile endpoints — visible to any authenticated user.
Never expose email or phone.
"""
from fastapi import APIRouter, Query
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.dependencies import CurrentUser, DbSession
from app.core.exceptions import NotFoundError
from app.models.user import User, UserRole
from app.models.event import Event, EventStatus

router = APIRouter()

_PUBLIC_STATUSES = [
    EventStatus.approved, EventStatus.selling_tickets,
    EventStatus.waiting_event_date, EventStatus.live, EventStatus.completed,
]


@router.get("/users/{user_id}/public-profile")
async def get_public_profile(user_id: int, db: DbSession, current_user: CurrentUser):
    """Get public profile for any user. No email/phone returned."""
    user = (await db.execute(
        select(User).where(User.id == user_id)
    )).scalar_one_or_none()
    if not user:
        raise NotFoundError("User", user_id)

    events_count = 0
    if user.role == UserRole.organizer:
        events_count = (await db.execute(
            select(func.count()).where(
                Event.organizer_id == user_id,
                Event.status.in_(_PUBLIC_STATUSES),
            )
        )).scalar_one()

    # Trust score (reuse existing pattern from event responses)
    from app.services.event import compute_organizer_trust
    trust = await compute_organizer_trust(db, user_id) if user.role == UserRole.organizer else {}

    # Sponsor profile (if sponsor)
    sponsor_data = None
    if user.role == UserRole.sponsor:
        from app.models.sponsor import SponsorProfile
        profile = (await db.execute(
            select(SponsorProfile).where(SponsorProfile.user_id == user_id)
        )).scalar_one_or_none()
        if profile:
            sponsor_data = {
                "company_name": profile.company_name,
                "contact_name": profile.contact_name,
                "profession": profile.profession,
                "logo_url": profile.logo_url,
                "description": profile.description,
                "website_url": profile.website_url,
            }

    # Extract city from address (only show city, not full street address)
    city = None
    if user.address:
        parts = [p.strip() for p in user.address.split(",")]
        city = parts[1] if len(parts) > 1 else parts[0]

    return {
        "id": user.id,
        "display_name": user.display_name or "Unknown",
        "role": user.role.value,
        "city": city,
        "years_of_experience": user.years_of_experience,
        "member_since": user.created_at.isoformat() if user.created_at else None,
        "events_hosted_count": events_count,
        "trust": trust,
        "sponsor_profile": sponsor_data,
    }


@router.get("/users/{user_id}/public-events")
async def get_public_events(
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
    offset: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=50),
):
    """List public events organized by a user."""
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise NotFoundError("User", user_id)

    q = (
        select(Event)
        .where(Event.organizer_id == user_id, Event.status.in_(_PUBLIC_STATUSES))
        .order_by(Event.created_at.desc())
        .offset(offset).limit(limit)
    )
    events = (await db.execute(q)).scalars().all()

    from app.api.v1.events import _event_to_response
    return [_event_to_response(e) for e in events]
```

### 2.2 Register route

**File: `Backend/app/api/v1/router.py`**

```python
from app.api.v1 import public_profiles

api_router.include_router(public_profiles.router, prefix="", tags=["public-profiles"])
```

### 2.3 Frontend — API methods

**File: `FrontEnd/lib/services/api_service.dart`**

Add these methods:

```dart
Future<Map<String, dynamic>> getPublicProfile(int userId) async {
  final resp = await dio.get('/users/$userId/public-profile');
  return resp.data;
}

Future<List<dynamic>> getPublicEvents(int userId, {int offset = 0, int limit = 10}) async {
  final resp = await dio.get('/users/$userId/public-events', queryParameters: {
    'offset': offset,
    'limit': limit,
  });
  return resp.data;
}
```

### 2.4 Frontend — Organizer Profile Screen

**New file: `FrontEnd/lib/screens/profile/organizer_profile_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/shimmer_loaders.dart';

class OrganizerProfileScreen extends StatefulWidget {
  final int userId;
  const OrganizerProfileScreen({super.key, required this.userId});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic>? _events;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    try {
      final results = await Future.wait([
        api.getPublicProfile(widget.userId),
        api.getPublicEvents(widget.userId),
      ]);
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _events = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(title: Text(_profile?['display_name'] ?? 'Profile')),
      body: _loading
          ? ListView(children: List.generate(4, (_) => const ShimmerEventCard()))
          : _profile == null
              ? const Center(child: Text('Profile not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildStats(),
                      const SizedBox(height: 20),
                      if (_events != null && _events!.isNotEmpty) ...[
                        Text('Events', style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context),
                        )),
                        const SizedBox(height: 12),
                        ..._events!.map((e) => _buildEventCard(e)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final name = _profile!['display_name'] ?? 'Unknown';
    final city = _profile!['city'];
    final memberSince = _profile!['member_since'];
    final exp = _profile!['years_of_experience'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                  color: AppTheme.accentColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(name, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryOf(context),
          )),
          if (city != null) ...[
            const SizedBox(height: 4),
            Text(city, style: TextStyle(
              color: AppTheme.textSecondaryOf(context), fontSize: 14,
            )),
          ],
          if (memberSince != null) ...[
            const SizedBox(height: 4),
            Text(
              'Member since ${DateFormat.yMMMM().format(DateTime.parse(memberSince))}',
              style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13),
            ),
          ],
          if (exp != null) ...[
            const SizedBox(height: 4),
            Text('$exp years of experience',
                style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    final trust = _profile!['trust'] as Map<String, dynamic>?;
    final eventsCount = _profile!['events_hosted_count'] ?? 0;
    final trustScore = trust?['trust_score'] ?? 0.0;
    final label = trust?['label'] ?? 'New';

    return Row(
      children: [
        _statCard('Events', '$eventsCount', Icons.event),
        const SizedBox(width: 12),
        _statCard('Trust', '${(trustScore * 100).toInt()}%', Icons.verified_user),
        const SizedBox(width: 12),
        _statCard('Level', label, Icons.military_tech),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.accentColor, size: 24),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            )),
            Text(label, style: TextStyle(
              fontSize: 12, color: AppTheme.textSecondaryOf(context),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(event['title'] ?? '', style: TextStyle(
          fontWeight: FontWeight.w600, color: AppTheme.textPrimaryOf(context),
        )),
        subtitle: Text(event['status'] ?? '', style: TextStyle(
          color: AppTheme.textSecondaryOf(context), fontSize: 13,
        )),
        trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondaryOf(context)),
        onTap: () {
          // Navigate to event detail
        },
      ),
    );
  }
}
```

### 2.5 Frontend — Organizer Bottom Sheet

**File: `FrontEnd/lib/screens/event/event_detail_screen.dart`**

Add a helper method in `_EventDetailScreenState`:

```dart
void _showOrganizerProfile(BuildContext context, int organizerId) async {
  final api = context.read<ApiService>();
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.cardOf(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return FutureBuilder<Map<String, dynamic>>(
        future: api.getPublicProfile(organizerId),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          }
          final p = snap.data!;
          final trust = p['trust'] as Map<String, dynamic>?;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.15),
                  child: Text((p['display_name'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(fontSize: 24, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Text(p['display_name'] ?? 'Unknown', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryOf(ctx),
                )),
                if (p['city'] != null)
                  Text(p['city'], style: TextStyle(color: AppTheme.textSecondaryOf(ctx))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.event, size: 16, color: AppTheme.textSecondaryOf(ctx)),
                  const SizedBox(width: 4),
                  Text('${p['events_hosted_count'] ?? 0} events', style: TextStyle(color: AppTheme.textSecondaryOf(ctx))),
                  const SizedBox(width: 16),
                  Icon(Icons.verified_user, size: 16, color: AppTheme.textSecondaryOf(ctx)),
                  const SizedBox(width: 4),
                  Text(trust?['label'] ?? 'New', style: TextStyle(color: AppTheme.textSecondaryOf(ctx))),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => OrganizerProfileScreen(userId: organizerId),
                      ));
                    },
                    child: const Text('View Full Profile'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
```

Then find where the organizer name/trust badge is rendered on event detail and wrap it in an `InkWell`:

```dart
InkWell(
  onTap: () => _showOrganizerProfile(context, event.organizerId),
  borderRadius: BorderRadius.circular(8),
  child: /* existing organizer name / trust badge widget */,
)
```

---

## Feature 6 — Event Bookmarks

### 6.1 Backend Model

**New file: `Backend/app/models/bookmark.py`**

```python
"""Event bookmark model."""
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Bookmark(Base):
    __tablename__ = "bookmarks"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    user = relationship("User")
    event = relationship("Event")

    __table_args__ = (
        UniqueConstraint("user_id", "event_id", name="uq_bookmarks_user_event"),
    )
```

### 6.2 Register model

**File: `Backend/app/models/__init__.py`**

```python
from app.models.bookmark import Bookmark
# Add "Bookmark" to __all__
```

### 6.3 Alembic Migration

**New file: `Backend/alembic/versions/jj70j1k2l3m4_bookmarks.py`**

```python
"""Add bookmarks table.

Revision ID: jj70j1k2l3m4
Revises: ii60i0j1k2l3
"""
from alembic import op
import sqlalchemy as sa

revision = "jj70j1k2l3m4"
down_revision = "ii60i0j1k2l3"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "bookmarks",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "event_id", name="uq_bookmarks_user_event"),
    )
    op.create_index("ix_bookmarks_user_id", "bookmarks", ["user_id"])
    op.create_index("ix_bookmarks_event_id", "bookmarks", ["event_id"])

def downgrade() -> None:
    op.drop_table("bookmarks")
```

### 6.4 Backend API

Add to `Backend/app/api/v1/events.py` (or create `Backend/app/api/v1/bookmarks.py`):

```python
# ── Bookmarks ──

@router.post("/{event_id}/bookmark")
async def toggle_bookmark(event_id: int, db: DbSession, current_user: CurrentUser):
    """Toggle bookmark on an event. Returns new bookmark state."""
    from app.models.bookmark import Bookmark
    existing = (await db.execute(
        select(Bookmark).where(
            Bookmark.user_id == current_user.id,
            Bookmark.event_id == event_id,
        )
    )).scalar_one_or_none()

    if existing:
        await db.delete(existing)
        return {"bookmarked": False}
    else:
        db.add(Bookmark(user_id=current_user.id, event_id=event_id))
        await db.flush()
        return {"bookmarked": True}
```

Add to `Backend/app/api/v1/users.py`:

```python
@router.get("/bookmarks")
async def get_my_bookmarks(
    db: DbSession,
    current_user: CurrentUser,
    offset: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
):
    """List bookmarked events for the current user."""
    from app.models.bookmark import Bookmark
    from app.models.event import Event
    q = (
        select(Event)
        .join(Bookmark, Bookmark.event_id == Event.id)
        .where(Bookmark.user_id == current_user.id)
        .order_by(Bookmark.created_at.desc())
        .offset(offset).limit(limit)
    )
    events = (await db.execute(q)).scalars().all()
    return [_event_to_response(e) for e in events]
```

### 6.5 Frontend — API methods

**File: `FrontEnd/lib/services/api_service.dart`**

```dart
Future<Map<String, dynamic>> toggleBookmark(int eventId) async {
  final resp = await dio.post('/events/$eventId/bookmark');
  return resp.data;
}

Future<List<dynamic>> getMyBookmarks({int offset = 0, int limit = 20}) async {
  final resp = await dio.get('/me/bookmarks', queryParameters: {
    'offset': offset, 'limit': limit,
  });
  return resp.data;
}
```

### 6.6 Frontend — Bookmark Icon on Event Cards

In `FrontEnd/lib/screens/home/home_screen.dart`, add a bookmark icon to each event card widget
across all tabs (Home, Explore, Manage). Maintain a local `Set<int> _bookmarkedIds` and toggle
on tap:

```dart
IconButton(
  icon: Icon(
    _bookmarkedIds.contains(event.id) ? Icons.bookmark : Icons.bookmark_border,
    color: _bookmarkedIds.contains(event.id) ? AppTheme.accentColor : AppTheme.textSecondaryOf(context),
  ),
  onPressed: () async {
    final api = context.read<ApiService>();
    final result = await api.toggleBookmark(event.id);
    setState(() {
      if (result['bookmarked'] == true) {
        _bookmarkedIds.add(event.id);
      } else {
        _bookmarkedIds.remove(event.id);
      }
    });
  },
)
```

Also add the same bookmark icon on `event_detail_screen.dart` in the AppBar actions.

### 6.7 Frontend — Bookmarks Quick Action in Manage (All Roles)

Add a "Bookmarks" quick action in the Manage section for all three roles (customer,
organizer, sponsor), alongside existing quick actions like "My Tickets" and "My Pledges".

In `FrontEnd/lib/screens/home/home_screen.dart`, in the Manage tab quick actions area:

```dart
_quickAction(
  icon: Icons.bookmark_rounded,
  label: 'Bookmarks',
  onTap: () {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const BookmarkedEventsScreen(),
    ));
  },
),
```

### 6.8 Frontend — Bookmarked Events Screen

**New file: `FrontEnd/lib/screens/bookmark/bookmarked_events_screen.dart`**

A dedicated screen that loads bookmarked events and provides the **same search bar and
event state filter chips** that the Manage tab uses. This gives users the full ability
to search and filter within their bookmarked events.

```dart
class BookmarkedEventsScreen extends StatefulWidget {
  const BookmarkedEventsScreen({super.key});

  @override
  State<BookmarkedEventsScreen> createState() => _BookmarkedEventsScreenState();
}

class _BookmarkedEventsScreenState extends State<BookmarkedEventsScreen> {
  List<dynamic> _allEvents = [];
  List<dynamic> _filteredEvents = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      _allEvents = await api.getMyBookmarks();
      _applyFilters();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _applyFilters() {
    var result = List<dynamic>.from(_allEvents);

    // Search by title
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((e) =>
        (e['title'] ?? '').toString().toLowerCase().contains(query)
      ).toList();
    }

    // Filter by event status
    if (_selectedStatus != null) {
      result = result.where((e) => e['status'] == _selectedStatus).toList();
    }

    setState(() => _filteredEvents = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceOf(context),
      appBar: AppBar(title: const Text('Bookmarks')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Search bookmarked events...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.inputFillOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statusChip(null, 'All'),
                _statusChip('approved', 'Funding'),
                _statusChip('waiting_event_date', 'Awaiting Date'),
                _statusChip('selling_tickets', 'Selling Tickets'),
                _statusChip('live', 'Live'),
                _statusChip('completed', 'Completed'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Event list
          Expanded(
            child: _loading
                ? ListView(children: List.generate(4, (_) => const ShimmerEventCard()))
                : _filteredEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border, size: 64,
                                color: AppTheme.textSecondaryOf(context)),
                            const SizedBox(height: 12),
                            Text(
                              _allEvents.isEmpty
                                  ? 'No bookmarked events'
                                  : 'No events match your filters',
                              style: TextStyle(color: AppTheme.textSecondaryOf(context)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredEvents.length,
                          itemBuilder: (ctx, i) {
                            // Reuse existing event card widget
                            return _buildEventCard(_filteredEvents[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String? status, String label) {
    final selected = _selectedStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedStatus = selected ? null : status);
          _applyFilters();
        },
      ),
    );
  }
}
```

---

## Feature 3 — Enhanced Sponsor Info for Organizers

### 3.1 Backend — Extend public_profiles.py

**File: `Backend/app/api/v1/public_profiles.py`**

Add endpoint:

```python
@router.get("/users/{user_id}/sponsor-public-profile")
async def get_sponsor_public_profile(user_id: int, db: DbSession, current_user: CurrentUser):
    """Get public sponsor profile. No email/phone."""
    from app.models.sponsor import SponsorProfile, SponsorBid, BidStatus
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if not user:
        raise NotFoundError("User", user_id)

    profile = (await db.execute(
        select(SponsorProfile).where(SponsorProfile.user_id == user_id)
    )).scalar_one_or_none()

    # Bid statistics
    total_bids = (await db.execute(
        select(func.count()).where(SponsorBid.sponsor_user_id == user_id)
    )).scalar_one()
    accepted_bids = (await db.execute(
        select(func.count()).where(
            SponsorBid.sponsor_user_id == user_id,
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid]),
        )
    )).scalar_one()

    # Events sponsored (distinct event IDs from accepted/paid bids)
    from app.models.sponsor import SponsorshipCategory
    events_sponsored = (await db.execute(
        select(func.count(func.distinct(SponsorshipCategory.event_id)))
        .join(SponsorBid, SponsorBid.category_id == SponsorshipCategory.id)
        .where(
            SponsorBid.sponsor_user_id == user_id,
            SponsorBid.status.in_([BidStatus.accepted, BidStatus.paid]),
        )
    )).scalar_one()

    return {
        "id": user_id,
        "display_name": user.display_name or "Unknown",
        "company_name": profile.company_name if profile else None,
        "contact_name": profile.contact_name if profile else None,
        "profession": profile.profession if profile else None,
        "logo_url": profile.logo_url if profile else None,
        "description": profile.description if profile else None,
        "website_url": profile.website_url if profile else None,
        "member_since": user.created_at.isoformat() if user.created_at else None,
        "total_bids": total_bids,
        "accepted_bids": accepted_bids,
        "events_sponsored": events_sponsored,
    }
```

### 3.2 Frontend — Sponsor Profile Screen

**New file: `FrontEnd/lib/screens/profile/sponsor_profile_screen.dart`**

Similar structure to `OrganizerProfileScreen` but displays:
- Company name and logo (if URL exists, show `NetworkImage`)
- Contact name, profession, description
- Website link (tappable, opens URL)
- Stats: total bids, accepted bids, events sponsored
- No email, no phone

### 3.3 Frontend — Bottom Sheet from Bid Management

**File: `FrontEnd/lib/screens/sponsor/bid_management_screen.dart`**

Where sponsor names are rendered in bid cards, wrap with `InkWell`:

```dart
InkWell(
  onTap: () => _showSponsorProfileSheet(context, bid['sponsor_profile']['user_id']),
  child: /* existing sponsor company name text */,
)
```

The `_showSponsorProfileSheet` method follows the same pattern as `_showOrganizerProfile` from Feature 2 — fetch `/users/{id}/sponsor-public-profile`, show bottom sheet with company name, profession, stats, "View Full Profile" button.

### 3.4 Frontend — Same for Organizer Sponsors Screen

**File: `FrontEnd/lib/screens/sponsor/organizer_sponsors_screen.dart`**

Make sponsor cards tappable to open the same bottom sheet/profile screen.

---

## Feature 4 — Sponsorship Category Prerequisites

### 4.1 Backend Model

**New file: `Backend/app/models/prerequisite.py`**

```python
"""Sponsorship category prerequisites and document uploads."""
import enum
from datetime import datetime
from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class UploadStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class CategoryPrerequisite(Base):
    __tablename__ = "category_prerequisites"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("sponsorship_categories.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_required: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    category = relationship("SponsorshipCategory")
    uploads = relationship("BidPrerequisiteUpload", back_populates="prerequisite")


class BidPrerequisiteUpload(Base):
    __tablename__ = "bid_prerequisite_uploads"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    bid_id: Mapped[int] = mapped_column(ForeignKey("sponsor_bids.id"), nullable=False, index=True)
    prerequisite_id: Mapped[int] = mapped_column(ForeignKey("category_prerequisites.id"), nullable=False)
    file_url: Mapped[str] = mapped_column(String(500), nullable=False)
    status: Mapped[UploadStatus] = mapped_column(Enum(UploadStatus), default=UploadStatus.pending, nullable=False)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewer_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    bid = relationship("SponsorBid")
    prerequisite = relationship("CategoryPrerequisite", back_populates="uploads")
```

### 4.2 Alembic Migration

**New file: `Backend/alembic/versions/kk80k2l3m4n5_prerequisites.py`**

```python
"""Add prerequisite tables.

Revision ID: kk80k2l3m4n5
Revises: jj70j1k2l3m4
"""
from alembic import op
import sqlalchemy as sa

revision = "kk80k2l3m4n5"
down_revision = "jj70j1k2l3m4"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "category_prerequisites",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("category_id", sa.Integer(), sa.ForeignKey("sponsorship_categories.id"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_required", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_category_prerequisites_cat", "category_prerequisites", ["category_id"])

    op.create_table(
        "bid_prerequisite_uploads",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("bid_id", sa.Integer(), sa.ForeignKey("sponsor_bids.id"), nullable=False),
        sa.Column("prerequisite_id", sa.Integer(), sa.ForeignKey("category_prerequisites.id"), nullable=False),
        sa.Column("file_url", sa.String(500), nullable=False),
        sa.Column("status", sa.Enum("pending", "approved", "rejected", name="uploadstatus"), nullable=False, server_default="pending"),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewer_note", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_bid_prerequisite_uploads_bid", "bid_prerequisite_uploads", ["bid_id"])

def downgrade() -> None:
    op.drop_table("bid_prerequisite_uploads")
    op.execute("DROP TYPE IF EXISTS uploadstatus")
    op.drop_table("category_prerequisites")
```

### 4.3 Backend API

**File: `Backend/app/api/v1/sponsors.py`** — Add these endpoints:

```python
# ── Category Prerequisites (Organizer creates) ──

@router.post("/events/{event_id}/sponsorships/{cat_id}/prerequisites", status_code=201)
async def create_prerequisite(
    event_id: int, cat_id: int,
    name: str = Form(...),
    description: str | None = Form(None),
    is_required: bool = Form(True),
    db: DbSession,
    current_user: CurrentUser,
):
    """Organizer adds a prerequisite to a sponsorship category."""
    from app.models.prerequisite import CategoryPrerequisite
    cat = await sponsor_svc._get_category(db, cat_id)
    await sponsor_svc._require_organizer(db, cat.event_id, current_user)
    prereq = CategoryPrerequisite(
        category_id=cat_id, name=name, description=description, is_required=is_required,
    )
    db.add(prereq)
    await db.flush()
    await db.refresh(prereq)
    return {"id": prereq.id, "name": prereq.name, "description": prereq.description, "is_required": prereq.is_required}


@router.get("/events/{event_id}/sponsorships/{cat_id}/prerequisites")
async def list_prerequisites(event_id: int, cat_id: int, db: DbSession, current_user: CurrentUser):
    """List prerequisites for a category."""
    from app.models.prerequisite import CategoryPrerequisite
    q = select(CategoryPrerequisite).where(CategoryPrerequisite.category_id == cat_id)
    items = (await db.execute(q)).scalars().all()
    return [{"id": p.id, "name": p.name, "description": p.description, "is_required": p.is_required} for p in items]


# ── Bid Prerequisite Uploads (Sponsor uploads) ──

@router.post("/bids/{bid_id}/prerequisites/{prereq_id}/upload")
async def upload_prerequisite_document(
    bid_id: int, prereq_id: int,
    file: UploadFile = File(...),
    db: DbSession,
    current_user: CurrentUser,
):
    """Sponsor uploads a document for a prerequisite."""
    from app.models.prerequisite import BidPrerequisiteUpload
    from app.models.sponsor import SponsorBid
    bid = (await db.execute(select(SponsorBid).where(SponsorBid.id == bid_id))).scalar_one_or_none()
    if not bid or bid.sponsor_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your bid")

    # Save file
    import os, uuid
    upload_dir = "static/uploads/prerequisites"
    os.makedirs(upload_dir, exist_ok=True)
    ext = os.path.splitext(file.filename)[1] if file.filename else ".pdf"
    filename = f"{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(upload_dir, filename)
    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)

    upload = BidPrerequisiteUpload(
        bid_id=bid_id,
        prerequisite_id=prereq_id,
        file_url=f"/static/uploads/prerequisites/{filename}",
    )
    db.add(upload)
    await db.flush()
    await db.refresh(upload)
    return {"id": upload.id, "file_url": upload.file_url, "status": upload.status.value}


# ── Review Uploads (Organizer) ──

@router.patch("/bids/{bid_id}/prerequisites/{prereq_id}/review")
async def review_prerequisite_upload(
    bid_id: int, prereq_id: int,
    status: str = Form(...),  # "approved" or "rejected"
    reviewer_note: str | None = Form(None),
    db: DbSession,
    current_user: CurrentUser,
):
    """Organizer approves or rejects an uploaded prerequisite document."""
    from app.models.prerequisite import BidPrerequisiteUpload, UploadStatus
    from app.models.sponsor import SponsorBid
    from datetime import datetime, timezone
    bid = (await db.execute(select(SponsorBid).where(SponsorBid.id == bid_id))).scalar_one_or_none()
    if not bid:
        raise HTTPException(status_code=404, detail="Bid not found")
    cat = await sponsor_svc._get_category(db, bid.category_id)
    await sponsor_svc._require_organizer(db, cat.event_id, current_user)

    upload = (await db.execute(
        select(BidPrerequisiteUpload).where(
            BidPrerequisiteUpload.bid_id == bid_id,
            BidPrerequisiteUpload.prerequisite_id == prereq_id,
        )
    )).scalar_one_or_none()
    if not upload:
        raise HTTPException(status_code=404, detail="Upload not found")

    upload.status = UploadStatus(status)
    upload.reviewed_at = datetime.now(timezone.utc)
    upload.reviewer_note = reviewer_note
    await db.flush()
    await db.refresh(upload)

    # Notify sponsor
    await notif_svc.create_notification(
        db, user_id=bid.sponsor_user_id,
        type=NotificationType.bid_received,
        title=f"Document {'Approved' if status == 'approved' else 'Rejected'}",
        message=f"Your uploaded document was {status}." + (f" Note: {reviewer_note}" if reviewer_note else ""),
        data={"bid_id": bid_id},
    )

    return {"id": upload.id, "status": upload.status.value, "reviewer_note": upload.reviewer_note}
```

### 4.4 Backend — Block bid acceptance if prerequisites not met

**File: `Backend/app/services/sponsor.py`** — In `accept_bid()` (~line 270), add check before accepting:

```python
# Before: bid.status = BidStatus.accepted
from app.models.prerequisite import CategoryPrerequisite, BidPrerequisiteUpload, UploadStatus
required_prereqs = (await db.execute(
    select(CategoryPrerequisite).where(
        CategoryPrerequisite.category_id == bid.category_id,
        CategoryPrerequisite.is_required == True,
    )
)).scalars().all()

for prereq in required_prereqs:
    upload = (await db.execute(
        select(BidPrerequisiteUpload).where(
            BidPrerequisiteUpload.bid_id == bid.id,
            BidPrerequisiteUpload.prerequisite_id == prereq.id,
            BidPrerequisiteUpload.status == UploadStatus.approved,
        )
    )).scalar_one_or_none()
    if not upload:
        raise HTTPException(
            status_code=400,
            detail=f"Required document '{prereq.name}' has not been approved yet",
        )
```

### 4.5 Frontend

**Organizer side** — In `sponsorship_categories_screen.dart`, add an "Add Requirements" section when creating/editing a category. Form fields: name (text), description (text), is_required (checkbox). CRUD via API.

**Sponsor side** — When placing a bid, show "Required Documents" section listing prerequisites. For each, show upload button. Use `image_picker` or `file_picker` to select files, POST to `/bids/{bid_id}/prerequisites/{prereq_id}/upload`.

**Organizer review** — In `bid_management_screen.dart`, when viewing bid details, show uploaded documents with approve/reject buttons.

---

## Feature 5 — Multi-Directional Rating System

### 5.1 Backend Model

**New file: `Backend/app/models/rating.py`**

```python
"""Rating model for multi-directional reviews."""
import enum
from datetime import datetime
from sqlalchemy import DateTime, Enum, ForeignKey, Integer, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class RatingDirection(str, enum.Enum):
    customer_to_event = "customer_to_event"
    customer_to_organizer = "customer_to_organizer"
    organizer_to_sponsor = "organizer_to_sponsor"
    sponsor_to_organizer = "sponsor_to_organizer"


class Rating(Base):
    __tablename__ = "ratings"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    rater_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    rated_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False, index=True)
    direction: Mapped[RatingDirection] = mapped_column(Enum(RatingDirection), nullable=False)
    stars: Mapped[int] = mapped_column(Integer, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    rater = relationship("User", foreign_keys=[rater_user_id])
    rated_user = relationship("User", foreign_keys=[rated_user_id])
    event = relationship("Event")

    __table_args__ = (
        UniqueConstraint("rater_user_id", "event_id", "direction", name="uq_ratings_rater_event_direction"),
    )
```

### 5.2 Alembic Migration

**New file: `Backend/alembic/versions/ll90l3m4n5o6_ratings.py`**

```python
"""Add ratings table.

Revision ID: ll90l3m4n5o6
Revises: kk80k2l3m4n5
"""
from alembic import op
import sqlalchemy as sa

revision = "ll90l3m4n5o6"
down_revision = "kk80k2l3m4n5"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "ratings",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("rater_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("rated_user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("event_id", sa.Integer(), sa.ForeignKey("events.id"), nullable=False),
        sa.Column("direction", sa.Enum(
            "customer_to_event", "customer_to_organizer",
            "organizer_to_sponsor", "sponsor_to_organizer",
            name="ratingdirection",
        ), nullable=False),
        sa.Column("stars", sa.Integer(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("rater_user_id", "event_id", "direction", name="uq_ratings_rater_event_direction"),
    )
    op.create_index("ix_ratings_rater", "ratings", ["rater_user_id"])
    op.create_index("ix_ratings_rated", "ratings", ["rated_user_id"])
    op.create_index("ix_ratings_event", "ratings", ["event_id"])

def downgrade() -> None:
    op.drop_table("ratings")
    op.execute("DROP TYPE IF EXISTS ratingdirection")
```

### 5.3 Backend API

**New file: `Backend/app/api/v1/ratings.py`**

```python
"""Rating endpoints."""
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, field_validator
from sqlalchemy import func, select

from app.dependencies import CurrentUser, DbSession
from app.models.event import Event, EventStatus
from app.models.rating import Rating, RatingDirection
from app.services import notification_service as notif_svc
from app.models.notification import NotificationType

router = APIRouter()


class RatingCreate(BaseModel):
    direction: str
    rated_user_id: int | None = None
    stars: int
    description: str | None = None

    @field_validator("stars")
    @classmethod
    def stars_range(cls, v: int) -> int:
        if v < 1 or v > 5:
            raise ValueError("stars must be 1-5")
        return v


@router.post("/events/{event_id}/ratings", status_code=201)
async def create_rating(event_id: int, body: RatingCreate, db: DbSession, current_user: CurrentUser):
    """Create a rating. Only allowed after event is completed."""
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.status != EventStatus.completed:
        raise HTTPException(status_code=400, detail="Ratings are only allowed for completed events")

    direction = RatingDirection(body.direction)

    existing = (await db.execute(
        select(Rating).where(
            Rating.rater_user_id == current_user.id,
            Rating.event_id == event_id,
            Rating.direction == direction,
        )
    )).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=409, detail="You have already rated for this direction")

    rating = Rating(
        rater_user_id=current_user.id,
        rated_user_id=body.rated_user_id,
        event_id=event_id,
        direction=direction,
        stars=body.stars,
        description=body.description,
    )
    db.add(rating)
    await db.flush()

    # Notify the rated user
    if body.rated_user_id:
        await notif_svc.create_notification(
            db, user_id=body.rated_user_id,
            type=NotificationType.new_rating_received,
            title="New Rating Received",
            message=f"You received a {body.stars}-star rating.",
            data={"event_id": event_id, "rating_id": rating.id},
        )

    return {"id": rating.id, "stars": rating.stars}


@router.get("/events/{event_id}/ratings/summary")
async def get_event_ratings_summary(event_id: int, db: DbSession, current_user: CurrentUser):
    """
    Event rating summary: aggregate + top 5 best + top 5 worst reviews.
    Visible to all authenticated users on the event detail screen.
    Direction: customer_to_event only.
    """
    from sqlalchemy.orm import selectinload
    base = select(Rating).where(
        Rating.event_id == event_id,
        Rating.direction == RatingDirection.customer_to_event,
    ).options(selectinload(Rating.rater))

    # Aggregate
    agg_q = select(
        func.avg(Rating.stars).label("avg_stars"),
        func.count(Rating.id).label("count"),
    ).where(
        Rating.event_id == event_id,
        Rating.direction == RatingDirection.customer_to_event,
    )
    agg = (await db.execute(agg_q)).one()

    # Top 5 best (highest stars, then newest)
    best = (await db.execute(
        base.order_by(Rating.stars.desc(), Rating.created_at.desc()).limit(5)
    )).scalars().all()

    # Top 5 worst (lowest stars, then newest)
    worst = (await db.execute(
        base.order_by(Rating.stars.asc(), Rating.created_at.desc()).limit(5)
    )).scalars().all()

    def _fmt(r):
        return {
            "id": r.id,
            "rater_name": r.rater.display_name if r.rater else "Anonymous",
            "stars": r.stars,
            "description": r.description,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }

    return {
        "avg_stars": round(float(agg.avg_stars), 1) if agg.avg_stars else None,
        "count": agg.count,
        "top_reviews": [_fmt(r) for r in best],
        "worst_reviews": [_fmt(r) for r in worst],
    }


@router.get("/events/{event_id}/ratings")
async def list_event_ratings(
    event_id: int, db: DbSession, current_user: CurrentUser,
    direction: str | None = Query(None),
):
    """List ALL individual ratings for an event. Organizer only (full feedback list)."""
    from app.models.event import Event
    from app.models.user import UserRole
    from sqlalchemy.orm import selectinload
    event = (await db.execute(select(Event).where(Event.id == event_id))).scalar_one_or_none()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if current_user.role != UserRole.admin and current_user.id != event.organizer_id:
        raise HTTPException(status_code=403, detail="Only the organizer can view the full review list")

    q = (
        select(Rating)
        .where(Rating.event_id == event_id)
        .options(selectinload(Rating.rater))
    )
    if direction:
        q = q.where(Rating.direction == RatingDirection(direction))
    q = q.order_by(Rating.created_at.desc())
    items = (await db.execute(q)).scalars().all()
    return [
        {
            "id": r.id,
            "rater_name": r.rater.display_name if r.rater else "Anonymous",
            "direction": r.direction.value,
            "stars": r.stars,
            "description": r.description,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in items
    ]


@router.get("/users/{user_id}/ratings-received")
async def get_user_ratings_summary(user_id: int, db: DbSession, current_user: CurrentUser):
    """
    User rating summary: aggregate + top 5 best + top 5 worst reviews.
    Visible to all authenticated users on public profiles.
    Used for:
      - Organizer profile: shows customer_to_organizer + sponsor_to_organizer reviews
      - Sponsor profile: shows organizer_to_sponsor reviews
    """
    from sqlalchemy.orm import selectinload
    base = select(Rating).where(
        Rating.rated_user_id == user_id,
    ).options(selectinload(Rating.rater))

    # Aggregate
    agg_q = select(
        func.avg(Rating.stars).label("avg_stars"),
        func.count(Rating.id).label("count"),
    ).where(Rating.rated_user_id == user_id)
    agg = (await db.execute(agg_q)).one()

    # Top 5 best
    best = (await db.execute(
        base.order_by(Rating.stars.desc(), Rating.created_at.desc()).limit(5)
    )).scalars().all()

    # Top 5 worst
    worst = (await db.execute(
        base.order_by(Rating.stars.asc(), Rating.created_at.desc()).limit(5)
    )).scalars().all()

    def _fmt(r):
        return {
            "id": r.id,
            "rater_name": r.rater.display_name if r.rater else "Anonymous",
            "direction": r.direction.value,
            "stars": r.stars,
            "description": r.description,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }

    return {
        "avg_stars": round(float(agg.avg_stars), 1) if agg.avg_stars else None,
        "count": agg.count,
        "top_reviews": [_fmt(r) for r in best],
        "worst_reviews": [_fmt(r) for r in worst],
    }
```

Register in `router.py`:

```python
from app.api.v1 import ratings
api_router.include_router(ratings.router, prefix="", tags=["ratings"])
```

### 5.4 Frontend — Display Rules

All rating summaries use the **"top 5 best + top 5 worst"** pattern with aggregate stats.
Reviews are publicly visible — not hidden from any role.

#### 5.4.1 On Completed Event Detail (all roles)

**File: `FrontEnd/lib/screens/event/event_detail_screen.dart`**

When `event.status == completed`, show a "Reviews" section fetched from
`GET /events/{id}/ratings/summary`:

```
┌─────────────────────────────────────┐
│  ★ 4.2  (15 ratings)               │  <- aggregate
├─────────────────────────────────────┤
│  Top Reviews                        │
│  ★★★★★  "Amazing event!" — Alice    │  <- top 5 best
│  ★★★★★  "Well organized" — Bob      │
│  ...                                │
├─────────────────────────────────────┤
│  Critical Reviews                   │
│  ★★     "Venue was too small" — Eve │  <- top 5 worst
│  ★      "Poor sound quality" — Dan  │
│  ...                                │
├─────────────────────────────────────┤
│  [Rate this event]  (if not rated)  │  <- star picker + form
└─────────────────────────────────────┘
```

- **All authenticated users** see the aggregate + top 5 best + top 5 worst
- **Customers** who haven't rated yet also see the star picker + description form below
- **Organizer** additionally has access to the full review list via
  `GET /events/{id}/ratings` (a "View All Reviews" button)

#### 5.4.2 On Organizer Public Profile (Feature 2)

**File: `FrontEnd/lib/screens/profile/organizer_profile_screen.dart`**

Fetch from `GET /users/{organizer_id}/ratings-received` and display:

```
┌─────────────────────────────────────┐
│  ★ 4.5  (23 ratings)               │  <- aggregate
├─────────────────────────────────────┤
│  Top Reviews                        │
│  ★★★★★  "Best organizer" — Alice    │  <- top 5 best reviews
│  ...                                │  (from customers + sponsors)
├─────────────────────────────────────┤
│  Critical Reviews                   │
│  ★★     "Slow communication" — Eve  │  <- top 5 worst reviews
│  ...                                │
└─────────────────────────────────────┘
```

Reviews shown here come from `customer_to_organizer` and `sponsor_to_organizer`
directions combined. Visible to all authenticated users viewing the profile.

#### 5.4.3 On Sponsor Public Profile (Feature 3)

**File: `FrontEnd/lib/screens/profile/sponsor_profile_screen.dart`**

Same layout as organizer profile. Fetch from `GET /users/{sponsor_id}/ratings-received`:

```
┌─────────────────────────────────────┐
│  ★ 3.8  (7 ratings)                │  <- aggregate
├─────────────────────────────────────┤
│  Top Reviews                        │
│  ★★★★★  "Great partner" — OrganizerA│  <- top 5 best
│  ...                                │  (from organizer_to_sponsor)
├─────────────────────────────────────┤
│  Critical Reviews                   │
│  ★★     "Didn't deliver" — OrganizerB│ <- top 5 worst
│  ...                                │
└─────────────────────────────────────┘
```

Reviews shown here come from `organizer_to_sponsor` direction only.
Visible to all authenticated users viewing the profile.

#### 5.4.4 Frontend Implementation

```dart
// In event_detail_screen.dart, for completed events:
if (event.status == EventStatus.completed) ...[
  _buildReviewsSection(context, event),
],
```

The `_buildReviewsSection` method:
1. Calls `GET /events/{id}/ratings/summary` on load
2. Displays aggregate (avg stars + count)
3. Shows "Top Reviews" list (up to 5 cards: name, stars, description)
4. Shows "Critical Reviews" list (up to 5 cards: name, stars, description)
5. If current user hasn't rated yet: shows star picker + description field + submit button
6. After submit: refreshes the summary to update aggregate and lists

For profile screens, same pattern using `GET /users/{id}/ratings-received`.

### 5.5 Frontend — Star Rating Widget

```dart
class StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged;
  final double size;

  const StarRating({super.key, required this.rating, this.onChanged, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(i + 1) : null,
          child: Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < rating ? Colors.amber : AppTheme.textSecondaryOf(context),
            size: size,
          ),
        );
      }),
    );
  }
}
```

---

## Feature 7 — Multi-Role System

### 7.1 Backend — Schema Changes

**File: `Backend/app/models/user.py`**

Add `roles` column:

```python
from sqlalchemy import JSON

class User(Base):
    # ... existing fields ...
    roles: Mapped[list | None] = mapped_column(JSON, nullable=True)
    # `role` remains as the "active" role
```

### 7.2 Alembic Migration

**New file: `Backend/alembic/versions/mm00m4n5o6p7_multirole.py`**

```python
"""Add roles JSON column to users.

Revision ID: mm00m4n5o6p7
Revises: ll90l3m4n5o6
"""
from alembic import op
import sqlalchemy as sa

revision = "mm00m4n5o6p7"
down_revision = "ll90l3m4n5o6"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column("users", sa.Column("roles", sa.JSON(), nullable=True))
    # Populate roles from existing role column
    op.execute("UPDATE users SET roles = json_build_array(role::text)")

def downgrade() -> None:
    op.drop_column("users", "roles")
```

### 7.3 Backend — Role Management Endpoints

**File: `Backend/app/api/v1/users.py`**

```python
@router.post("/roles/add")
async def add_role(
    body: dict,
    db: DbSession,
    current_user: CurrentUser,
):
    """Add a new role to the current user's role set."""
    new_role = body.get("role")
    if new_role not in [r.value for r in UserRole]:
        raise HTTPException(status_code=400, detail=f"Invalid role: {new_role}")
    if new_role == "admin":
        raise HTTPException(status_code=403, detail="Cannot self-assign admin role")

    current_roles = current_user.roles or [current_user.role.value]
    if new_role in current_roles:
        raise HTTPException(status_code=409, detail=f"Already have role: {new_role}")

    current_roles.append(new_role)
    current_user.roles = current_roles
    await db.flush()
    await db.refresh(current_user)
    return {"roles": current_user.roles, "active_role": current_user.role.value}


@router.patch("/roles/switch")
async def switch_role(
    body: dict,
    db: DbSession,
    current_user: CurrentUser,
):
    """Switch the active role. Must be one of the user's existing roles."""
    target = body.get("role")
    current_roles = current_user.roles or [current_user.role.value]
    if target not in current_roles:
        raise HTTPException(status_code=400, detail=f"You don't have the role: {target}")

    current_user.role = UserRole(target)
    await db.flush()
    await db.refresh(current_user)
    return {"roles": current_user.roles, "active_role": current_user.role.value}
```

### 7.4 Backend — Update `require_role` to check `roles` list

**File: `Backend/app/dependencies.py`**

Update `require_role` to also check `user.roles`:

```python
def require_role(*allowed_roles: UserRole):
    async def _require_role(current_user: Annotated[User, Depends(get_current_user)]) -> User:
        # Check active role first, then roles list
        if current_user.role in allowed_roles:
            return current_user
        user_roles = current_user.roles or [current_user.role.value]
        if any(r in [ar.value for ar in allowed_roles] for r in user_roles):
            return current_user
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    return _require_role
```

### 7.5 Frontend — Role Switcher

**File: `FrontEnd/lib/screens/profile/profile_screen.dart`**

Add a role switcher widget (e.g., `ChoiceChip` row) at the top of the profile screen:

```dart
// In build(), before other profile content:
if (user.roles != null && user.roles!.length > 1)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Wrap(
      spacing: 8,
      children: user.roles!.map((role) {
        final isActive = role == user.role;
        return ChoiceChip(
          label: Text(role[0].toUpperCase() + role.substring(1)),
          selected: isActive,
          onSelected: (_) async {
            final api = context.read<ApiService>();
            await api.dio.patch('/me/roles/switch', data: {'role': role});
            await context.read<AuthProvider>().refreshUser();
          },
        );
      }).toList(),
    ),
  ),
```

### 7.6 Frontend — Add Role Button

In the profile screen (below the role switcher), add an "Add Role" button that shows a dialog:

```dart
TextButton.icon(
  icon: const Icon(Icons.add_circle_outline),
  label: const Text('Add Role'),
  onPressed: () => _showAddRoleDialog(context),
)
```

The dialog presents available roles the user doesn't have yet. Selecting one calls `POST /me/roles/add`. If the new role is `organizer`, prompt for any required onboarding info. If `sponsor`, navigate to the sponsor onboarding screen.

### 7.7 Frontend — AppUser model update

**File: `FrontEnd/lib/models/user.dart`**

Add `roles` field:

```dart
class AppUser {
  // ... existing fields ...
  final List<String>? roles;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      // ... existing ...
      roles: json['roles'] != null ? List<String>.from(json['roles']) : null,
    );
  }
}
```

### 7.8 Backend — Return `roles` in `/me` response

**File: `Backend/app/api/v1/users.py`**

In `_me_response`:

```python
def _me_response(u) -> dict:
    return {
        # ... existing fields ...
        "roles": u.roles or [u.role.value],
    }
```

Also update `MeResponse` schema to include `roles: list[str] | None = None`.

---

## Implementation Status

### COMPLETED (verified in codebase)

```
Batch A (Foundation) — ALL DONE:
  [x] 0. Privacy rules (receipts + sponsor fallback)
        - All 5 backend name fallbacks fixed (sponsors.py, events.py, users.py, services/sponsor.py)
        - attendeeEmail removed from ticket_receipt_screen.dart & purchase_group_receipt_screen.dart
        - Organizer email/phone preserved on receipts
  [x] 2. Feature 2 — Organizer Public Profile (backend + frontend)
        - public_profiles.py with public-profile and public-events endpoints
        - organizer_name added to EventResponse
        - OrganizerProfileScreen, bottom sheet, tappable organizer, route
  [x] 6. Feature 6 — Bookmarks (model + API + frontend)
        - Bookmark model, migration, toggle/list/batch-check API endpoints
        - Bookmark icon on event cards and event detail AppBar
        - BookmarkedEventsScreen with search and status filters
        - "Bookmarks" quick action in Manage section, route registered
  [x] Addendum: Sponsor Ticket Scan Count
        - scan_count added to SponsorTicket model + migration
        - scan_sponsor_ticket service increments count, includes in response
        - scanCount in SponsorTicketModel, displayed on ticket card + receipt
        - Ticket scanner screen handles both customer and sponsor tickets with mode toggle
```

### REMAINING (not yet implemented)

```
Batch A (Foundation) — remaining:
  [ ] 1. Feature 1 — Notifications (model + service + API + integration + frontend)  ~4 hours
        - Backend: Notification model, migration, notification_service.py, notifications.py router
        - Backend integration: Wire create_notification calls into events.py, sponsors.py,
          registration.py, admin.py (all trigger points from Section 1.7)
        - Frontend: NotificationProvider, register in main.dart, notification bell in AppBar,
          NotificationScreen

Batch B (Profiles & Prerequisites):
  [x] 3. Feature 3 — Sponsor Info for Organizers  ~2 hours
        - Backend: sponsor-public-profile endpoint in public_profiles.py
        - Frontend: SponsorProfileScreen, bottom sheet from bid management + organizer sponsors
  [x] 4. Feature 4 — Category Prerequisites  ~3 hours
        - Backend: CategoryPrerequisite + BidPrerequisiteUpload models, migration, API endpoints
          (create, list, delete, upload, list-uploads, review), block bid acceptance if prereqs not met
        - Frontend: Organizer prerequisite CRUD sheet, sponsor upload docs sheet, organizer review UI in bid cards

Batch C (Social):
  [ ] 5. Feature 5 — Ratings  ~3 hours
        - Backend: Rating model, migration, ratings.py router (create, event summary,
          full list, user summary)
        - Frontend: Reviews section on completed events (aggregate + top 5 best/worst),
          star picker + description form, reviews on organizer/sponsor profiles,
          StarRating widget

Batch D (Structural):
  [ ] 7. Feature 7 — Multi-Role  ~3 hours
        - Backend: roles JSON column on User, migration, add-role + switch-role endpoints,
          update require_role dependency, return roles in /me response
        - Frontend: roles in AppUser model, role switcher on profile, add role dialog
```

### Remaining Migrations (to be applied in order)

1. `ii60i0j1k2l3` — notifications
2. ~~`kk80k2l3m4n5` — prerequisites~~ (applied)
3. `ll90l3m4n5o6` — ratings
4. `mm00m4n5o6p7` — multi-role

Note: Bookmarks and scan_count migrations are already applied.

---

## Addendum: Sponsor Ticket Scan Count

Currently, `SponsorTicket.scanned_at` is set once on first scan and subsequent scans are
no-ops. Since a sponsor ticket can represent multiple category spots (i.e. multiple people
entering under one sponsor), scanning should **increment a counter** so organizers can track
how many people have entered using that sponsor ticket.

### Model Change

**File: `Backend/app/models/sponsor.py`** — Add `scan_count` to `SponsorTicket`:

```python
class SponsorTicket(Base):
    __tablename__ = "sponsor_tickets"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), nullable=False)
    sponsor_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    qr_data_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    receipt_number: Mapped[str] = mapped_column(String(100), nullable=False)
    scanned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    scan_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)  # NEW
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    event = relationship("Event")
    sponsor = relationship("User")

    __table_args__ = (
        UniqueConstraint("event_id", "sponsor_user_id", name="uq_sponsor_tickets_event_user"),
    )
```

### Migration

**New file: `Backend/alembic/versions/nn10n5o6p7q8_sponsor_scan_count.py`**

```python
"""Add scan_count to sponsor_tickets.

Revision ID: nn10n5o6p7q8
Revises: mm00m4n5o6p7
"""
from alembic import op
import sqlalchemy as sa

revision = "nn10n5o6p7q8"
down_revision = "mm00m4n5o6p7"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.add_column("sponsor_tickets", sa.Column("scan_count", sa.Integer(), server_default="0", nullable=False))

def downgrade() -> None:
    op.drop_column("sponsor_tickets", "scan_count")
```

### Service Change

**File: `Backend/app/services/sponsor.py`** — Update `scan_sponsor_ticket()` (line 554):

```python
async def scan_sponsor_ticket(
    db: AsyncSession, event_id: int, encrypted_payload: str
) -> dict:
    """Decrypt QR and return sponsor info + won categories. Increments scan_count each time."""
    from app.services.ticket_crypto import decrypt_ticket_qr
    try:
        data = decrypt_ticket_qr(encrypted_payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    ticket_event_id = data.get("eid")
    ticket_id = data.get("sid")
    if ticket_event_id != event_id:
        raise HTTPException(status_code=400, detail="QR does not belong to this event")

    ticket = (await db.execute(
        select(SponsorTicket).where(SponsorTicket.id == ticket_id)
    )).scalar_one_or_none()
    if not ticket:
        raise HTTPException(status_code=404, detail="Sponsor ticket not found")

    from datetime import datetime
    # Set scanned_at on first scan, increment count on every scan
    if not ticket.scanned_at:
        ticket.scanned_at = datetime.utcnow()
    ticket.scan_count = (ticket.scan_count or 0) + 1
    await db.flush()

    profile = await get_profile(db, ticket.sponsor_user_id)
    cats = await get_won_categories(db, event_id, ticket.sponsor_user_id)

    return {
        "ticket_id": ticket.id,
        "receipt_number": ticket.receipt_number,
        "company_name": profile.company_name if profile else "Unknown",
        "contact_name": profile.contact_name if profile else "",
        "categories": cats,
        "category_names": [c["name"] for c in cats],
        "category_count": len(cats),
        "scan_count": ticket.scan_count,
        "already_scanned": ticket.scan_count > 1,  # True if scanned before this scan
    }
```

Key behavior changes:
- `scanned_at` — still set once on first scan (records when the ticket was first used)
- `scan_count` — incremented on **every** scan (tracks total entries)
- `already_scanned` — now means "was scanned before this scan" (count > 1)
- New `scan_count` field in the response so the frontend can display it

### Frontend Change

**File: `FrontEnd/lib/screens/sponsor/sponsor_ticket_screen.dart`** (or wherever the scan result is displayed)

Show the scan count in the scan result UI:

```dart
// After displaying company name and categories:
Text(
  'Entries: ${result['scan_count']}',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimaryOf(context),
  ),
),
```

Also display `scan_count` on the sponsor ticket detail screen so both the organizer
and sponsor can see how many times the ticket has been scanned.
