# Firebase RTDB Chat — Design Spec

**Date:** 2026-03-31
**Status:** Approved
**Approach:** Phased Firebase (Approach C)

---

## Overview

Add customer-to-organizer messaging and migrate the entire chat system from Redis Streams/WebSocket to Firebase Realtime Database. Executed in two phases:

- **Phase 1:** Build customer chat on Firebase RTDB + new organizer inbox UI. Sponsor chat stays on Redis.
- **Phase 2:** Migrate sponsor chat from Redis → Firebase RTDB. Delete WebSocket/Redis chat code.

## Motivation

- Eliminate Redis infrastructure management for chat (streams, pub/sub, presence tracking, archive/purge crons)
- Firebase RTDB provides real-time sync natively on mobile without custom WebSocket code
- Firebase Auth + FCM already in the project — RTDB plugs in with zero new vendors

## Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Conversation trigger | Customer must have a ticket/pledge for the event | Access control — only paying participants can message |
| Conversation scope | One per customer per event | Customer inquiries are about the event, not individual tickets |
| Organizer inbox layout | Hybrid: horizontal event circles + filter chips + flat conversation list | 2 taps to reach a chat, scales well, preserves event-circle vision |
| Real-time backend | Firebase RTDB (not Firestore) | Faster, cheaper, simpler for 1:1 chat with read-by-conversation patterns |
| Migration scope | Both sponsor + customer chat migrate to Firebase | Single system, no dual maintenance |
| Migration strategy | Phased — customer first (Phase 1), sponsor migration (Phase 2) | Low risk, each phase independently shippable |
| Backend role | Gatekeeper (validates access, creates conversations) + Listener (FCM push, unread counts, metadata) | Clients talk directly to Firebase for messages; backend handles auth + side effects |
| Image upload | Keep existing backend upload endpoint | One migration at a time; Firebase Storage deferred |
| Chat lifecycle | Full lifecycle — read-only after event ends, archive at 30 days, purge at 60 days | Same policy as current Redis system, enforced via Firebase Security Rules + backend cron |
| Customer/sponsor view | Simple flat list of their conversations | They have few conversations; grouping unnecessary |

---

## Phase 1: Customer Chat on Firebase RTDB

### 1. Firebase RTDB Data Structure

```
crowd_funding_chat/
├── conversations/
│   └── {conversation_id}/              # "event_42_user_789"
│       ├── event_id: 42
│       ├── customer_user_id: 789
│       ├── organizer_user_id: 101
│       ├── customer_name: "Jane Doe"
│       ├── organizer_name: "John Org"
│       ├── event_title: "Art Exhibition Gala"
│       ├── type: "customer"            # "customer" | "sponsor" (Phase 2)
│       ├── bid_id: null                # only for sponsor convos (Phase 2)
│       ├── status: "open"              # "open" | "read_only" | "archived"
│       ├── created_at: 1711900000000
│       ├── last_message_at: 1711900500000
│       ├── last_message_text: "Is there parking?"
│       └── unread/
│           ├── {user_id}: 3
│           └── {user_id}: 0
│
├── messages/
│   └── {conversation_id}/
│       └── {push_id}/                  # Firebase auto-generated
│           ├── sender_id: 789
│           ├── body: "Is there parking nearby?"
│           ├── msg_type: "text"        # "text" | "image"
│           ├── client_id: "pending_abc123"
│           ├── created_at: 1711900500000
│           └── status: "sent"          # "sent" | "delivered" | "read"
│
├── user_conversations/
│   └── {firebase_uid}/
│       └── {conversation_id}: true     # index for quick lookup (keyed by Firebase UID for security rules)
│
└── typing/
    └── {conversation_id}/
        └── {user_id}: true|false       # ephemeral typing indicator
```

**Conversation ID format:** `event_{eventId}_user_{firebaseUid}` — deterministic, prevents duplicates. Uses Firebase UID (string) since Firebase Security Rules operate on `auth.uid`. The PG `customer_chat_conversation` table stores integer user IDs for joins; the backend maps between Firebase UID and PG user ID during conversation creation.

### 2. Firebase Security Rules

```json
{
  "rules": {
    "crowd_funding_chat": {
      "conversations": {
        "$conv_id": {
          ".read": "root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists()",
          ".write": false,
          "unread": {
            "$uid": {
              ".write": "auth.uid == $uid && root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists()"
            }
          }
        }
      },
      "messages": {
        "$conv_id": {
          ".read": "root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists()",
          ".write": "root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists() && root.child('crowd_funding_chat/conversations/' + $conv_id + '/status').val() == 'open'"
        }
      },
      "user_conversations": {
        "$uid": {
          ".read": "auth.uid == $uid",
          ".write": false
        }
      },
      "typing": {
        "$conv_id": {
          "$uid": {
            ".read": "root.child('crowd_funding_chat/user_conversations/' + auth.uid + '/' + $conv_id).exists()",
            ".write": "auth.uid == $uid"
          }
        }
      }
    }
  }
}
```

**Enforcement summary:**
- Users can only read conversations they're a participant in (via `user_conversations` index)
- Messages can only be written to `open` conversations
- Only backend (Admin SDK, bypasses rules) can create conversations, update status, or modify `user_conversations`
- Users can only update their own unread count and typing indicator

### 3. Backend — New Files (3-Layer)

```
Backend/app/api/v1/customer_chat.py            # Routes (thin)
Backend/app/services/customer_chat_service.py   # Business logic
Backend/app/repositories/firebase_chat_repo.py  # All Firebase Admin SDK calls
```

#### 3a. Repository: `firebase_chat_repo.py`

All Firebase Admin SDK calls isolated here. Services never touch `db_ref` directly.

```
FirebaseChatRepository
  ├── create_conversation(db_ref, conv_id, data) → dict
  ├── get_conversation(db_ref, conv_id) → dict | None
  ├── get_user_conversations(db_ref, user_id) → list[str]
  ├── add_user_conversation(db_ref, user_id, conv_id) → None
  ├── update_conversation_status(db_ref, conv_id, status) → None
  ├── delete_conversation(db_ref, conv_id) → None
  ├── delete_messages(db_ref, conv_id) → None
  ├── export_messages(db_ref, conv_id) → list[dict]
  ├── increment_unread(db_ref, conv_id, user_id) → None
  ├── update_last_message(db_ref, conv_id, text, timestamp) → None
```

#### 3b. Service: `customer_chat_service.py`

```
initiate_conversation(db, firebase_ref, user_id, event_id)
  1. Verify user has a ticket/pledge (via funding_repo or ticket_repo)
  2. Check if conversation exists (deterministic ID)
  3. If exists → return it. If not → create in Firebase + store reference in PG
  4. Return conversation metadata

close_event_conversations(db, firebase_ref, event_id)
  Called when event → completed/cancelled
  Mark all conversations for this event as read_only

archive_old_conversations(db, firebase_ref, retention_days=30)
  Export messages → gzip → filesystem, update status

purge_archived_conversations(db, firebase_ref, archive_retention_days=30)
  Delete from Firebase + delete archive files
```

#### 3c. Routes: `customer_chat.py`

| Endpoint | Method | Session | Purpose |
|----------|--------|---------|---------|
| `POST /api/v1/chat/conversations/customer` | POST | DbSession | Validate ticket → create conversation in Firebase → return conversation_id |
| `GET /api/v1/chat/conversations/organizer/{event_id}` | GET | ReadDbSession | List conversations for an event |
| `POST /api/v1/chat/conversations/{conv_id}/close` | POST | DbSession | Mark conversation read-only |
| `POST /api/v1/chat/conversations/{conv_id}/upload` | POST | DbSession | Image upload (reuses existing file storage logic) |

#### 3d. PostgreSQL — New Table

```sql
CREATE TABLE customer_chat_conversation (
    id SERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) UNIQUE NOT NULL,  -- "event_42_user_789"
    event_id INTEGER NOT NULL REFERENCES event(id),
    customer_user_id INTEGER NOT NULL REFERENCES "user"(id),
    organizer_user_id INTEGER NOT NULL REFERENCES "user"(id),
    status VARCHAR(20) DEFAULT 'open',              -- open, read_only, archived
    created_at TIMESTAMPTZ DEFAULT now(),
    archived_at TIMESTAMPTZ NULL,
    UNIQUE(event_id, customer_user_id)
);
```

Purpose: lifecycle tracking, event-scoped queries, join with user/event tables for metadata. Firebase remains source of truth for messages.

#### 3e. Firebase Listener (Worker)

Persistent background process alongside ARQ worker:

```
Backend/app/worker/firebase_chat_listener.py

on_new_message(event):
  1. Update last_message_at + last_message_text on conversation node
  2. Increment recipient's unread count via Firebase transaction
  3. Send FCM push if recipient offline (via existing notification pipeline)
```

Runs continuously — not a periodic cron. Listens to `crowd_funding_chat/messages` node.

#### 3f. Cron Tasks

| Task | Schedule | Action |
|------|----------|--------|
| `close_completed_event_chats` | Event transition hooks | Mark all event conversations read_only |
| `archive_old_chat_conversations` | Daily 3:00 AM | Export Firebase messages → gzip, set status archived |
| `purge_archived_chats` | Daily 3:45 AM | Delete from Firebase + delete archive files |

### 4. Frontend — New Files (3-Layer)

#### 4a. New Dependency

```yaml
# pubspec.yaml
firebase_database: ^11.x
```

#### 4b. Repository: `chat_firebase_repository.dart`

Replaces both `chat_repository.dart` (REST) and `chat_socket_service.dart` (WebSocket) with a single class:

```
ChatFirebaseRepository
  ├── getConversations(userId) → Stream<List<ChatConversation>>
  ├── getMessages(conversationId) → Stream<List<ChatMessage>>
  ├── sendMessage(conversationId, body, msgType, clientId) → Future<void>
  ├── markRead(conversationId, userId) → Future<void>
  ├── setTyping(conversationId, userId, bool) → Future<void>
  ├── getTyping(conversationId) → Stream<Map<String, bool>>
  ├── initConversation(eventId) → Future<ChatConversation>  (REST → backend gatekeeper)
  ├── uploadImage(conversationId, bytes, filename) → Future<ChatMessage>  (REST → backend upload)
  └── dispose() → cancel all Firebase listeners
```

`initConversation` and `uploadImage` are the only REST calls. Everything else is Firebase direct.

#### 4c. Provider: `ChatFirebaseProvider`

```
ChatFirebaseProvider extends ChangeNotifier
  State:
    conversations: List<ChatConversation>
    activeMessages: List<ChatMessage>
    unreadCounts: Map<String, int>
    typingUsers: Map<String, bool>
    loading: bool
    error: String?
    activeConversationId: String?

  Methods:
    loadConversations() → subscribe to conversation stream
    openConversation(id) → subscribe to message + typing streams
    closeConversation() → cancel message/typing subscriptions
    sendMessage(body, msgType) → repo.sendMessage
    markRead() → repo.markRead
    setTyping(bool) → repo.setTyping
    initConversation(eventId) → repo.initConversation (REST)
    uploadImage(bytes, filename) → repo.uploadImage (REST)

  Lifecycle:
    Stream subscriptions auto-cancel on closeConversation/dispose
    Conversations stream stays alive while provider exists
```

#### 4d. Screens

| Screen | Status | Purpose |
|--------|--------|---------|
| `organizer_inbox_screen.dart` | **New** | Horizontal event circles + filter chips (All/Sponsors/Customers) + flat conversation list |
| `customer_chat_screen.dart` | **New** | Reuses `bid_chat_screen.dart` UI patterns (bubbles, image picker, typing indicator). Header shows event name. |
| `conversations_screen.dart` | **Modified** | Customer/sponsor flat list view. Reads from `ChatFirebaseProvider`. |

#### 4e. Phase 1 Organizer Inbox — Merging Two Systems

During Phase 1, the organizer inbox merges:
- Sponsor conversations from old `ChatProvider` (Redis)
- Customer conversations from new `ChatFirebaseProvider`

This temporary bridge is removed in Phase 2.

### 5. What Stays Untouched in Phase 1

- `chat_socket_service.dart` — WebSocket client (sponsor chat)
- `chat_provider.dart` — Redis-based provider (sponsor chat)
- `chat_repository.dart` — REST calls (sponsor chat)
- `bid_chat_screen.dart` — Sponsor chat UI
- `Backend/app/api/v1/chat.py` — WebSocket endpoint + sponsor REST routes
- `Backend/app/services/chat_service.py` — Redis stream logic

---

## Phase 2: Migrate Sponsor Chat to Firebase RTDB

Phase 2 scope (executed after Phase 1 is stable):

1. **Data migration script**: Export existing Redis sponsor chat streams → Firebase RTDB under the same data structure (type: "sponsor", with bid_id populated)
2. **New PG table or extend existing**: Track sponsor conversations in `customer_chat_conversation` (rename to `chat_conversation`) or create a parallel table
3. **Update `ChatFirebaseProvider`**: Add sponsor conversation support (bid_id, sponsor-specific metadata)
4. **Migrate `bid_chat_screen.dart`**: Point to `ChatFirebaseProvider` instead of old `ChatProvider`
5. **Unify organizer inbox**: Remove the dual-source merge — everything reads from Firebase
6. **Delete old code**:
   - `chat_socket_service.dart`
   - `chat_provider.dart` (old)
   - `chat_repository.dart` (old)
   - `Backend/app/api/v1/chat.py` (WebSocket endpoint + old REST routes)
   - `Backend/app/services/chat_service.py` (Redis stream logic)
   - Redis archive/purge cron tasks
7. **Remove Redis chat config**: `chat_stream_maxlen`, `chat_archive_retention_days` (replace with Firebase equivalents)

---

## Testing Strategy

### Backend Tests

| Test Area | Approach |
|-----------|----------|
| Firebase Chat Repository | Mock Firebase Admin SDK `db.reference()`. Test CRUD, unread increments, status transitions. |
| Customer Chat Service | Mock `firebase_chat_repo` + `funding_repo`/`ticket_repo`. Test ticket validation, duplicate prevention, lifecycle. |
| API Routes | Integration tests with test client. Mock Firebase. Test auth, ticket ownership, response shapes. |
| Firebase Listener | Unit test `on_new_message` with synthetic events. Verify unread increment + FCM push. |
| Cron Tasks | Test archive export format, purge deletion, status transitions. |

### Frontend Tests

| Test Area | Approach |
|-----------|----------|
| ChatFirebaseRepository | Mock `FirebaseDatabase.instance.ref()`. Test stream emissions, message sending, typing updates. |
| ChatFirebaseProvider | Mock repository. Test state transitions: loading → loaded, send → list update, unread changes. |
| OrganizerInboxScreen | Widget test with mock provider. Event circles, filter chips, conversation list. |
| CustomerChatScreen | Widget test. Message bubbles, image picker, typing indicator, read-only banner. |
| Conversations merge (Phase 1) | Organizer inbox correctly merges Redis sponsor + Firebase customer conversations. |

### Manual Testing Checklist

- [ ] Customer with ticket can initiate conversation
- [ ] Customer without ticket is rejected
- [ ] Messages appear in real-time on both sides
- [ ] Typing indicator works
- [ ] Image upload works in customer chat
- [ ] Unread counts update correctly
- [ ] Organizer sees both sponsor + customer conversations
- [ ] Event circles show correct unread badges
- [ ] Filter chips (All/Sponsors/Customers) work
- [ ] Read-only mode enforced after event completion
- [ ] FCM push notification for offline recipient
- [ ] Offline message queuing (Firebase native)
- [ ] App backgrounded → foregrounded → messages sync

---

## Effort Estimates

| Phase | Scope | Estimate |
|-------|-------|----------|
| Phase 1 | Customer chat on Firebase + organizer inbox + backend gatekeeper/listener | ~5-6 days |
| Phase 2 | Sponsor chat migration + code cleanup + unified inbox | ~3-4 days |
| **Total** | | **~8-10 days** |

---

## Infrastructure Requirements

- Enable Firebase Realtime Database in Firebase Console (same project as Auth/FCM)
- Deploy security rules (JSON above)
- Add `firebase_database` to Flutter pubspec
- Add `firebase-admin` RTDB initialization to backend (already has firebase-admin for Auth)
- Firebase Listener process needs to run alongside ARQ worker (new entry in docker-compose or same container)

## Cost Considerations

- Firebase RTDB: $5/GB stored, $1/GB downloaded. Chat messages are small (few KB per conversation). Negligible cost at current scale.
- Simultaneous connections: Free tier supports 100 concurrent. Blaze plan (pay-as-you-go) has no hard limit. $0.06/GB transferred.
