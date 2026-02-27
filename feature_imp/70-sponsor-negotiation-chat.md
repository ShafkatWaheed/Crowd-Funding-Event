# Feature 70 – Sponsor-Organizer Negotiation Chat

## Overview

Real-time, per-bid WhatsApp-style chat between event organizers and sponsors.
Messages are stored in **Redis Streams** (zero PostgreSQL growth). Real-time
delivery uses **WebSocket** with **Redis Pub/Sub** for cross-process routing.
Offline users receive **FCM push notifications** via the existing push pipeline.

---

## Architecture

```
Flutter App
  ├── ChatSocketService (WebSocket client, auto-reconnect)
  ├── ChatProvider (ChangeNotifier, message state)
  └── BidChatScreen / ConversationsScreen

FastAPI Backend
  ├── WebSocket  /api/v1/chat/ws/chat?token=JWT
  ├── REST       /api/v1/chat/bids/{id}/messages
  ├── REST       /api/v1/chat/conversations
  └── REST POST  /api/v1/chat/bids/{id}/read

Storage
  ├── Redis Streams   chat:bid:{bid_id}   (message content, MAXLEN ~500)
  ├── Redis Hash      chat:read:{bid_id}  (read cursors per user)
  ├── Redis Pub/Sub   chat:bid:{bid_id}   (real-time event routing)
  └── PostgreSQL      sponsor_bids table  (3 metadata columns only)
```

---

## Chat Lifecycle

Chat is **open (read/write)** when ALL are true:
- Bid status is `pending`, `accepted`, or `paid`
- Event status is `approved`, `selling_tickets`, `waiting_event_date`, or `live`

Chat becomes **read-only** when ANY occur:
- Bid is `rejected` or `withdrawn`
- Event reaches `completed` or `cancelled`

Chat is **archived** 30 days after event completion → `.json.gz` file on disk.
Archive is **purged** 30 days after archival → permanent deletion.

---

## WebSocket Protocol

Single WS connection per user, multiplexed across bid channels.

### Client → Server

| Type    | Fields                             | Purpose                  |
|---------|------------------------------------|--------------------------|
| join    | bid_id                             | Subscribe to bid channel |
| leave   | bid_id                             | Unsubscribe              |
| send    | bid_id, body, client_id            | Send a message           |
| ack     | bid_id, message_id                 | Delivery acknowledgement |
| read    | bid_id, message_id                 | Read receipt             |
| typing  | bid_id, is_typing                  | Typing indicator         |
| pong    | (none)                             | Heartbeat response       |

### Server → Client

| Type        | Fields                                      | Purpose               |
|-------------|---------------------------------------------|------------------------|
| joined      | bid_id, is_writable                         | Channel joined         |
| sent        | client_id, message_id, created_at           | Send confirmation      |
| new_message | message {id, bid_id, sender_id, body, ...}  | Incoming message       |
| delivered   | message_id, by                              | Delivery receipt       |
| read        | message_id, bid_id, by                      | Read receipt           |
| typing      | bid_id, user_id, is_typing                  | Typing indicator       |
| ping        | (none)                                      | Heartbeat (30s)        |
| error       | detail                                      | Error message          |

### Delivery Status (WhatsApp-style ticks)

- Single grey tick → `sent` (server received)
- Double grey tick → `delivered` (recipient device received via `ack`)
- Blue double tick → `read` (recipient viewed)

---

## API Endpoints

### REST

| Method | Path                              | Auth | Purpose                         |
|--------|-----------------------------------|------|---------------------------------|
| GET    | /chat/bids/{bid_id}/messages      | JWT  | Paginated history (cursor-based)|
| GET    | /chat/conversations               | JWT  | List conversations with unreads |
| POST   | /chat/bids/{bid_id}/read          | JWT  | Mark-read fallback (REST)       |

### WebSocket

| Path                      | Auth           | Purpose          |
|---------------------------|----------------|------------------|
| /chat/ws/chat?token=JWT   | Firebase token | Real-time chat   |

---

## Database Changes

### Migration: `iii_bid_chat_metadata`

Added to `sponsor_bids` table:
- `last_message_at` (DateTime, nullable) — timestamp of last message
- `unread_count_organizer` (Integer, default 0) — unread count for organizer
- `unread_count_sponsor` (Integer, default 0) — unread count for sponsor

Added to `notificationtype` enum:
- `chat_message`

---

## Platform Settings

| Key                          | Default | Description                           |
|------------------------------|---------|---------------------------------------|
| `chat_enabled`               | true    | Master toggle for chat feature        |
| `chat_max_message_length`    | 2000    | Max characters per message            |
| `chat_stream_maxlen`         | 500     | Max messages per bid in Redis         |
| `chat_archive_retention_days`| 30      | Days to keep archives before purge    |

---

## Cron Tasks

| Task                       | Schedule     | Purpose                                  |
|----------------------------|--------------|------------------------------------------|
| `archive_resolved_chats`   | Daily 3:00AM | Export old streams to .json.gz, clear PG  |
| `purge_old_chat_archives`  | Daily 3:45AM | Delete archive files older than 30 days   |

---

## Offline Push

When a message is sent and the recipient has no active WebSocket connection,
the system enqueues an FCM push notification via the existing pipeline:

```
chat_service.send_message()
  → check _connections dict
  → recipient not connected
  → notification_service.create_notification(type=chat_message)
  → ARQ worker → push_notification.send_push() → FCM
```

---

## Key Files

### Backend

| File | Purpose |
|------|---------|
| `Backend/app/services/chat_service.py` | Redis Streams CRUD, Pub/Sub, archive, purge |
| `Backend/app/api/v1/chat.py` | WebSocket endpoint + REST history endpoints |
| `Backend/app/models/sponsor.py` | SponsorBid model (3 metadata columns added) |
| `Backend/app/models/notification.py` | `chat_message` notification type |
| `Backend/app/services/platform_settings.py` | Chat settings (4 keys) |
| `Backend/app/worker/tasks.py` | `archive_resolved_chats`, `purge_old_chat_archives` |
| `Backend/app/worker/main.py` | Cron job registration |
| `Backend/app/api/v1/router.py` | Chat router registration |
| `Backend/alembic/versions/iii_bid_chat_metadata.py` | Migration |

### Frontend

| File | Purpose |
|------|---------|
| `FrontEnd/lib/models/chat_message.dart` | ChatMessage, ChatConversation models |
| `FrontEnd/lib/services/chat_socket_service.dart` | WebSocket client with auto-reconnect |
| `FrontEnd/lib/providers/chat_provider.dart` | Chat state management (ChangeNotifier) |
| `FrontEnd/lib/services/api_service.dart` | REST methods: getChatMessages, getChatConversations, markChatRead |
| `FrontEnd/lib/screens/chat/bid_chat_screen.dart` | WhatsApp-style chat UI |
| `FrontEnd/lib/screens/chat/conversations_screen.dart` | Conversations list |
| `FrontEnd/lib/config/router.dart` | Chat routes (/chat, /chat/bid/:bidId) |
| `FrontEnd/lib/screens/sponsor/bid_management_screen.dart` | Chat button on bid cards |
| `FrontEnd/pubspec.yaml` | web_socket_channel dependency |

---

## Data Lifecycle

```
Active Chat (Redis Stream) ──→ Archive (.json.gz) ──→ Deleted
         ↑                        ↑                     ↑
    While event active     30 days after event     30 days after
    + bid is open          completed/cancelled     archive
```

Maximum data retention: ~60 days after event ends.
No message content ever stored in PostgreSQL.
