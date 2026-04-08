# Firebase RTDB Chat — Design Spec v2

**Date:** 2026-04-07
**Status:** Approved
**Supersedes:** 2026-03-31-firebase-rtdb-chat-design.md
**Approach:** Full Firebase RTDB with sharded counters (Approach C)

---

## Overview

Unified communication system for the crowd-funding event platform, migrating from Redis/WebSocket to Firebase Realtime Database. Three communication types per event:

1. **Announcement Channels** — organizer broadcasts to customers or sponsors (read-only for audience, with like/dislike reactions)
2. **1:1 DMs** — two-way private chat between organizer and individual customers/sponsors
3. **Sponsor bid chat migration** — existing Redis/WebSocket sponsor chat moves to Firebase RTDB

Executed in two phases:
- **Phase 1:** Build announcement channels + customer DMs + unified "My Events" tab on Firebase RTDB. Sponsor chat stays on Redis.
- **Phase 2:** Migrate sponsor chat from Redis → Firebase RTDB. Delete WebSocket/Redis chat code. Unify organizer inbox.

## Motivation

- Eliminate Redis infrastructure management for chat (streams, pub/sub, presence tracking, archive/purge crons)
- Firebase RTDB provides real-time sync natively on mobile without custom WebSocket code
- Firebase Auth + FCM already in the project — RTDB plugs in with zero new vendors
- Announcement channels give organizers a broadcast tool with sentiment feedback (like/dislike)
- Unified "My Events" tab combines tickets + communications in one place

## Decisions Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Announcement channel access | Ticket or pledge holders only | Financial commitment required — registration alone is insufficient |
| Announcement permissions | Organizer writes, audience reads + likes/dislikes | One-way broadcast with sentiment feedback |
| Like/dislike implementation | Firebase sharded counters (10 shards per post) | Prevents write contention at scale; proven Firebase pattern |
| DM access | Customer: ticket/pledge. Sponsor: active bid | Same gating as announcement channels |
| Auto-kick on refund | Full refund → remove from announcement channel, DM becomes read-only | Losing financial ties revokes communication access |
| Auto-kick sponsor | Bid rejected/cancelled → same as customer refund | Consistent access control |
| Customer nav | Unified "My Events" tab (replaces Tickets tab) | Combines tickets + announcements + DMs per event in one view |
| Sponsor nav | Unified "My Events" tab (replaces Channel tab) | Same pattern as customer — announcements + DM + bid status + tickets |
| Organizer nav | Keeps "Channel" tab → event list → event chat hub | Two sections per event: Customers and Sponsors |
| Event card sort | Live → Upcoming (soonest) → Selling/Funding → Completed | Live events always on top |
| Completed event visibility | Read-only, hidden after N days (admin-configurable, default 7) | Prevents stale content; admin controls retention |
| Conversation scope | One DM per customer/sponsor per event | Inquiries are event-scoped |
| Real-time backend | Firebase RTDB (not Firestore) | Faster, cheaper, simpler for chat + reactions |
| Migration strategy | Phased — customer first (Phase 1), sponsor migration (Phase 2) | Low risk, each phase independently shippable |
| Backend role | Gatekeeper (validates access, creates channels/conversations) + Listener (FCM push, reaction aggregation, unread counts) | Clients talk directly to Firebase for messages; backend handles auth + side effects |
| Image upload | Option B — create post/message first, then attach image via upload endpoint | Post exists briefly without image; upload updates `image_url` field |
| Image upload backend | Keep existing backend upload endpoint | One migration at a time; Firebase Storage deferred |
| Chat lifecycle | Full lifecycle — read-only after event ends, hidden after retention period, archive at 30 days, purge at 60 days | Same policy as current Redis system, enforced via backend cron |
| Co-organizers | Co-organizers (via `EventOrganizer` table) can post announcements and see/respond to all DMs for their event | They are added to `channel_members` alongside the primary organizer |
| Organizer as member | Organizer + co-organizers are added to `channel_members` | Required for Firebase security rules — their Flutter client reads posts/channels via Firebase directly |
| New member history | New members see ALL past announcements (not just posts after joining) | Firebase RTDB gives full read access to the node; filtering would add complexity for minimal benefit |
| Phase 1 organizer inbox | Customer section only — sponsor section deferred to Phase 2 | Avoids dual-source merge (Firebase + Redis) in the organizer inbox |

---

## Communication Model

### Channel Types (per event)

| Channel | Who can post | Who can read | Reactions | Access gate |
|---------|-------------|-------------|-----------|-------------|
| Customer Announcements | Organizer only | Customers with ticket/pledge | Like/Dislike | Ticket or pledge |
| Sponsor Announcements | Organizer only | Sponsors with accepted/paid bid | Like/Dislike | Bid accepted or paid |
| Customer ↔ Organizer DM | Both | Both | None | Ticket or pledge |
| Sponsor ↔ Organizer DM | Both | Both | None | Bid created (pending/accepted/paid) |

### Auto-Kick Rules

| Trigger | Action |
|---------|--------|
| All tickets refunded AND all pledges refunded | Remove from customer announcement channel. DM becomes read-only. |
| Sponsor bid rejected or cancelled | Remove from sponsor announcement channel. DM becomes read-only. |

"Remove from channel" = delete `channel_members/{channel}/{uid}` entry. User stops receiving new posts. Existing DM history preserved as read-only.

---

## Navigation & UI

### Customer View — "My Events" Tab (4th tab, replaces Tickets)

Unified event cards sorted by proximity to live:

```
Sort order:
  1. 🔴 Live Now (red pulse dot)
  2. 🟡 Upcoming (soonest first, "In X days" badge)
  3. 🟢 Selling Tickets / Funding
  4. ⚫ Completed (dimmed, hidden after retention period)

Card structure (per event):
  ┌─────────────────────────────────────┐
  │ Event Name          [Live Now] 🔴   │  ← header (tap → event detail)
  │ Apr 7, 2026 • The Grand Hall       │
  ├─────────────────────────────────────┤
  │ 📢 Announcements    "Doors open..." │  ← tap → announcement channel
  │                              [2]    │     (read + like/dislike)
  ├─────────────────────────────────────┤
  │ 💬 Chat with Organizer  "Sure..." │  ← tap → 1:1 DM screen
  │                              [1]    │     (or "Message Organizer → New")
  ├─────────────────────────────────────┤
  │ 🎫 VIP Pass — Ticket #4821    →   │  ← tap → ticket detail/QR
  │ 🎫 General — Ticket #4822     →   │
  └─────────────────────────────────────┘
```

Completed events become read-only and are hidden after `completed_event_chat_retention_days` (admin-configurable, default 7).

### Sponsor View — "My Events" Tab (4th tab, replaces Channel)

Same unified card layout, sponsor-specific content:

```
Card structure (per event):
  ┌─────────────────────────────────────┐
  │ Event Name          [Upcoming] 🟡   │
  │ May 20, 2026 • Central Park        │
  ├─────────────────────────────────────┤
  │ 📢 Sponsor Announcements           │  ← tap → sponsor announcement channel
  │    "Booth setup starts Friday"      │
  ├─────────────────────────────────────┤
  │ 💬 Chat with Organizer             │  ← tap → 1:1 DM
  ├─────────────────────────────────────┤
  │ 🏷️ Gold Sponsor — Accepted ✅      │  ← bid category + status badge
  ├─────────────────────────────────────┤
  │ 🎫 VIP Pass — Ticket #5501    →   │  ← tickets from sponsorship package
  └─────────────────────────────────────┘
```

### Organizer View — "Channel" Tab (unchanged position)

Two-step navigation:

```
Step 1: Event List
  ┌─────────────────────────────────────┐
  │ Art Exhibition Gala    [3 unread]   │
  │ Music Festival 2026    [0 unread]   │
  └─────────────────────────────────────┘

Step 2: Event Chat Hub (tap an event)
  Phase 1 (customer section only):
  ┌─────────────────────────────────────┐
  │ CUSTOMERS                           │
  │ 📢 Announcements (post + view)     │  ← organizer creates posts here
  │ 💬 Jane Doe — "Wheelchair access?" │  ← individual DM
  │ 💬 Alex Smith — "Thanks!"          │
  └─────────────────────────────────────┘

  Phase 2 (adds sponsor section):
  ┌─────────────────────────────────────┐
  │ CUSTOMERS                           │
  │ 📢 Announcements (post + view)     │
  │ 💬 Jane Doe — "Wheelchair access?" │
  │ 💬 Alex Smith — "Thanks!"          │
  ├─────────────────────────────────────┤
  │ SPONSORS                            │
  │ 📢 Sponsor Announcements (post)    │
  │ 💬 Acme Corp — "Larger booth?"     │
  └─────────────────────────────────────┘
```

---

## Phase 1: Customer Chat + Announcements on Firebase RTDB

### 1. Firebase RTDB Data Structure

```
crowd_funding_chat/
├── channels/
│   └── {channel_id}/                        # "event_42_customer" or "event_42_sponsor"
│       ├── event_id: 42
│       ├── organizer_user_id: 101
│       ├── type: "customer" | "sponsor"
│       ├── status: "open" | "read_only"
│       ├── created_at: 1711900000000
│       └── last_post_at: 1711900500000
│
├── posts/
│   └── {channel_id}/
│       └── {push_id}/
│           ├── sender_id: 101              # always the organizer
│           ├── body: "Doors open at 6pm!"
│           ├── msg_type: "text" | "image"
│           ├── image_url: null             # populated after upload (Option B)
│           ├── created_at: 1711900500000
│           └── reaction_counts/
│               ├── like: 142               # aggregated (sum of shards)
│               └── dislike: 23
│
├── reaction_shards/
│   └── {channel_id}/
│       └── {post_id}/
│           └── shard_{0-9}/                # 10 shards per post
│               ├── like: 14
│               └── dislike: 2
│
├── user_reactions/
│   └── {channel_id}/
│       └── {post_id}/
│           └── {firebase_uid}: "like" | "dislike" | null
│
├── conversations/
│   └── {conv_id}/                          # "event_42_user_{firebase_uid}"
│       ├── event_id: 42
│       ├── customer_user_id: 789
│       ├── organizer_user_id: 101
│       ├── customer_name: "Jane Doe"
│       ├── organizer_name: "John Org"
│       ├── event_title: "Art Exhibition Gala"
│       ├── type: "customer" | "sponsor"
│       ├── bid_id: null                    # only for sponsor convos (Phase 2)
│       ├── status: "open" | "read_only"
│       ├── created_at: 1711900000000
│       ├── last_message_at: 1711900500000
│       ├── last_message_text: "Is there parking?"
│       └── unread/
│           └── {user_id}: 3
│
├── messages/
│   └── {conv_id}/
│       └── {push_id}/
│           ├── sender_id: 789
│           ├── body: "Is there parking nearby?"
│           ├── msg_type: "text" | "image"
│           ├── image_url: null             # populated after upload (Option B)
│           ├── client_id: "pending_abc123"
│           ├── created_at: 1711900500000
│           └── status: "sent" | "delivered" | "read"
│
├── channel_members/
│   └── {channel_id}/
│       └── {firebase_uid}: true            # access index for security rules
│                                           # includes organizer + co-organizers + audience
│
├── channel_read_cursors/
│   └── {channel_id}/
│       └── {firebase_uid}: "{last_read_post_id}"  # per-user read cursor for unread badge
│
├── user_conversations/
│   └── {firebase_uid}/
│       └── {conv_id}: true                 # DM access index
│
└── typing/
    └── {conv_id}/
        └── {user_id}: true | false
```

**Conversation ID format:** `event_{eventId}_user_{firebaseUid}` — deterministic, prevents duplicates. Uses Firebase UID (string) since Firebase Security Rules operate on `auth.uid`. The PG `chat_conversation` table stores integer user IDs for joins; the backend maps between Firebase UID and PG user ID during conversation creation.

**Channel ID format:** `event_{eventId}_customer` or `event_{eventId}_sponsor` — one per audience type per event.

### 2. Firebase Security Rules

```json
{
  "rules": {
    "crowd_funding_chat": {
      "channels": {
        "$channel_id": {
          ".read": "root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists()",
          ".write": false
        }
      },
      "posts": {
        "$channel_id": {
          ".read": "root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists()",
          ".write": false
        }
      },
      "reaction_shards": {
        "$channel_id": {
          "$post_id": {
            "$shard": {
              ".read": false,
              ".write": "root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists() && root.child('crowd_funding_chat/channels/' + $channel_id + '/status').val() == 'open'"
            }
          }
        }
      },
      "user_reactions": {
        "$channel_id": {
          "$post_id": {
            "$uid": {
              ".read": "auth.uid == $uid",
              ".write": "auth.uid == $uid && root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists() && root.child('crowd_funding_chat/channels/' + $channel_id + '/status').val() == 'open'"
            }
          }
        }
      },
      "channel_members": {
        "$channel_id": {
          "$uid": {
            ".read": "auth.uid == $uid",
            ".write": false
          }
        }
      },
      "channel_read_cursors": {
        "$channel_id": {
          "$uid": {
            ".read": "auth.uid == $uid",
            ".write": "auth.uid == $uid && root.child('crowd_funding_chat/channel_members/' + $channel_id + '/' + auth.uid).exists()"
          }
        }
      },
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
- Channel posts: only backend (Admin SDK) can write — organizer posts go through backend gatekeeper
- Reaction shards: channel members can write to shards (like/dislike) only on open channels
- User reactions: each user can only write their own reaction (prevents double-voting)
- DM messages: both participants can write only to open conversations
- Channel/conversation creation, status changes, member management: backend only (Admin SDK bypasses rules)

### 3. Sharded Counter Flow

```
User taps "like" on announcement post:

1. Client reads user_reactions/{channel}/{post}/{uid}
   → If already "like": remove reaction (toggle off)
   → If "dislike": switch to "like"
   → If null: add "like"

2. Client picks random shard (0-9)
   → Firebase transaction on reaction_shards/{channel}/{post}/shard_{N}/like: +1
   → If switching from dislike: also transaction on shard_{N}/dislike: -1

3. Client writes user_reactions/{channel}/{post}/{uid}: "like"

4. Backend Firebase Listener detects shard change:
   → Reads all 10 shards
   → Sums like counts, sums dislike counts
   → Writes aggregated totals to posts/{channel}/{post}/reaction_counts/{like, dislike}

5. All clients subscribed to the post see updated reaction_counts in real-time
```

### 4. Backend — New Files (3-Layer)

```
Backend/app/api/v1/chat_channels.py              # Announcement channel routes
Backend/app/api/v1/chat_conversations.py          # DM routes
Backend/app/services/chat/channel_service.py      # Announcement business logic
Backend/app/services/chat/conversation_service.py # DM business logic
Backend/app/repositories/firebase_chat_repo.py    # All Firebase Admin SDK calls
Backend/app/repositories/chat_conversation_repo.py # PG conversation queries
Backend/app/worker/firebase_chat_listener.py      # Real-time listener (reactions, messages)
```

#### 4a. Repository: `firebase_chat_repo.py`

All Firebase Admin SDK calls isolated here. Services never touch `db_ref` directly.

```
FirebaseChatRepository
  # Channels
  ├── create_channel(conv_id, data) → dict
  ├── get_channel(channel_id) → dict | None
  ├── update_channel_status(channel_id, status) → None
  ├── add_channel_member(channel_id, firebase_uid) → None
  ├── remove_channel_member(channel_id, firebase_uid) → None
  ├── get_channel_members(channel_id) → list[str]
  ├── create_post(channel_id, data) → str (post_id)
  ├── get_posts(channel_id, limit, before_key) → list[dict]
  ├── aggregate_reactions(channel_id, post_id) → dict (like, dislike totals)
  ├── write_reaction_counts(channel_id, post_id, counts) → None
  ├── update_post_image(channel_id, post_id, image_url) → None
  ├── get_read_cursor(channel_id, firebase_uid) → str | None
  ├── set_read_cursor(channel_id, firebase_uid, post_id) → None
  # Conversations (DMs)
  ├── create_conversation(conv_id, data) → dict
  ├── get_conversation(conv_id) → dict | None
  ├── get_user_conversations(firebase_uid) → list[str]
  ├── add_user_conversation(firebase_uid, conv_id) → None
  ├── remove_user_conversation(firebase_uid, conv_id) → None
  ├── update_conversation_status(conv_id, status) → None
  ├── update_last_message(conv_id, text, timestamp) → None
  ├── increment_unread(conv_id, user_id) → None
  ├── delete_conversation(conv_id) → None
  ├── delete_messages(conv_id) → None
  ├── export_messages(conv_id) → list[dict]
  └── export_posts(channel_id) → list[dict]
```

#### 4b. Repository: `chat_conversation_repo.py`

PostgreSQL queries for conversation/channel metadata.

```
ChatConversationRepository
  ├── create(db, data) → ChatConversation
  ├── get_by_conv_id(db, conv_id) → ChatConversation | None
  ├── get_by_event_and_user(db, event_id, user_id) → ChatConversation | None
  ├── list_by_event(db, event_id, type_filter) → list[ChatConversation]
  ├── list_by_user(db, user_id) → list[ChatConversation]
  ├── update_status(db, conv_id, status) → None
  ├── list_channels_by_event(db, event_id) → list[ChatChannel]
  ├── create_channel(db, data) → ChatChannel
  ├── get_channel(db, channel_id) → ChatChannel | None
  └── list_active_by_event(db, event_id, type_filter) → list
```

#### 4c. Service: `channel_service.py`

```
create_channel(db, firebase_ref, organizer_id, event_id, channel_type)
  1. Verify user is the event organizer or co-organizer
  2. Check if channel already exists (deterministic ID)
  3. If exists → return it
  4. Create in Firebase + store reference in PG
  5. Add organizer + all co-organizers to channel_members
  6. Add all eligible audience members (ticket/pledge holders or accepted/paid sponsors)
  7. Return channel metadata

create_post(db, firebase_ref, organizer_id, channel_id, body, msg_type)
  1. Verify user is the organizer or co-organizer for this channel's event
  2. Verify channel status is "open"
  3. Write post to Firebase (image_url: null if msg_type is "image")
  4. Update channel.last_post_at
  5. Send FCM push to all channel members (batched, up to 500 per multicast)
  6. Return post data (including post_id for subsequent image upload)

attach_image(db, firebase_ref, organizer_id, channel_id, post_id, image_url)
  1. Verify user is the organizer or co-organizer
  2. Update post's image_url field in Firebase
  (Called after backend upload endpoint returns the URL)

add_member(db, firebase_ref, channel_id, user_id)
  Called when a customer buys a ticket or creates a pledge, or when a sponsor bid is accepted/paid
  1. Look up user's Firebase UID
  2. Add to channel_members/{channel_id}/{firebase_uid}
  3. If channel doesn't exist yet, create it first

remove_member(db, firebase_ref, channel_id, user_id)
  Called on full refund (all tickets + all pledges) or bid rejection/cancellation
  1. Check if user has ANY remaining financial tie to the event
  2. If yes → do nothing (keep membership)
  3. If no → remove from channel_members/{channel_id}/{firebase_uid}

close_event_channels(db, firebase_ref, event_id)
  Called when event → completed/cancelled
  Mark all channels for this event as read_only
```

#### 4d. Service: `conversation_service.py`

```
initiate_conversation(db, firebase_ref, user_id, event_id)
  1. Verify user has a ticket/pledge (customer) or active bid (sponsor)
  2. Determine conversation type based on user's relationship to event
  3. Check if conversation exists (deterministic ID)
  4. If exists → return it. If not → create in Firebase + store in PG
  5. Return conversation metadata

revoke_access(db, firebase_ref, user_id, event_id)
  Called on full refund or bid rejection
  1. Find conversation for this user + event
  2. Update status to "read_only" in Firebase + PG
  3. Remove from channel_members for the relevant announcement channel

close_event_conversations(db, firebase_ref, event_id)
  Called when event → completed/cancelled
  Mark all conversations for this event as read_only

archive_old_conversations(db, firebase_ref, retention_days=30)
  Export messages → gzip → filesystem, update status

purge_archived_conversations(db, firebase_ref, archive_retention_days=30)
  Delete from Firebase + delete archive files
```

#### 4e. Routes: `chat_channels.py`

| Endpoint | Method | Session | Purpose |
|----------|--------|---------|---------|
| `POST /api/v1/chat/channels` | POST | DbSession | Create announcement channel for event (organizer only) |
| `GET /api/v1/chat/channels/{channel_id}/posts` | GET | ReadDbSession | List posts with pagination |
| `POST /api/v1/chat/channels/{channel_id}/posts` | POST | DbSession | Create announcement post (organizer only) |
| `POST /api/v1/chat/channels/{channel_id}/posts/{post_id}/upload` | POST | DbSession | Image upload for announcement post |

#### 4f. Routes: `chat_conversations.py`

| Endpoint | Method | Session | Purpose |
|----------|--------|---------|---------|
| `POST /api/v1/chat/conversations` | POST | DbSession | Initiate DM (validate ticket/bid → create in Firebase) |
| `GET /api/v1/chat/conversations` | GET | ReadDbSession | List user's conversations (for "My Events" tab) |
| `GET /api/v1/chat/conversations/event/{event_id}` | GET | ReadDbSession | List conversations for an event (organizer inbox) |
| `POST /api/v1/chat/conversations/{conv_id}/upload` | POST | DbSession | Image upload for DM |
| `POST /api/v1/chat/conversations/{conv_id}/close` | POST | DbSession | Mark conversation read-only |

#### 4g. PostgreSQL — New Tables

```sql
CREATE TABLE chat_channel (
    id SERIAL PRIMARY KEY,
    channel_id VARCHAR(100) UNIQUE NOT NULL,     -- "event_42_customer"
    event_id INTEGER NOT NULL REFERENCES event(id),
    organizer_user_id INTEGER NOT NULL REFERENCES "user"(id),
    type VARCHAR(20) NOT NULL,                    -- "customer" | "sponsor"
    status VARCHAR(20) DEFAULT 'open',            -- "open" | "read_only" | "archived"
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(event_id, type)
);

CREATE TABLE chat_conversation (
    id SERIAL PRIMARY KEY,
    conversation_id VARCHAR(150) UNIQUE NOT NULL, -- "event_42_user_{firebase_uid}"
    event_id INTEGER NOT NULL REFERENCES event(id),
    participant_user_id INTEGER NOT NULL REFERENCES "user"(id),
    organizer_user_id INTEGER NOT NULL REFERENCES "user"(id),
    type VARCHAR(20) NOT NULL,                    -- "customer" | "sponsor"
    status VARCHAR(20) DEFAULT 'open',            -- "open" | "read_only" | "archived"
    created_at TIMESTAMPTZ DEFAULT now(),
    archived_at TIMESTAMPTZ NULL,
    UNIQUE(event_id, participant_user_id)
);
```

Purpose: lifecycle tracking, event-scoped queries, join with user/event tables for metadata. Firebase remains source of truth for messages and posts.

#### 4h. Firebase Listener (Worker)

Persistent background process alongside ARQ worker:

```
Backend/app/worker/firebase_chat_listener.py

on_new_message(event):
  1. Update last_message_at + last_message_text on conversation node
  2. Increment recipient's unread count via Firebase transaction
  3. Send FCM push if recipient offline (via existing notification pipeline)

on_reaction_shard_change(event):
  1. Read all 10 shards for the affected post
  2. Sum like and dislike counts
  3. Write aggregated totals to posts/{channel}/{post}/reaction_counts
```

Runs continuously — not a periodic cron. Listens to `crowd_funding_chat/messages` and `crowd_funding_chat/reaction_shards` nodes.

#### 4i. Cron Tasks

| Task | Schedule | Action |
|------|----------|--------|
| `close_completed_event_chats` | Event transition hooks | Mark all channels + conversations for event as read_only |
| `archive_old_chat_data` | Daily 3:00 AM | Export Firebase messages/posts → gzip, set status archived |
| `purge_archived_chats` | Daily 3:45 AM | Delete from Firebase + delete archive files |

#### 4j. Channel Membership Integration Points

**Symmetric integration points** — every access grant has a corresponding revoke, and both announcement channel membership and DM access are tracked independently.

**Add member triggers (grant access):**

| Trigger | Backend Hook Location | Announcement Channel | DM |
|---------|----------------------|---------------------|-----|
| Ticket purchased | `ticket_service.purchase_ticket()` | Add to customer channel | Allow DM initiation |
| Pledge created | `pledge_service.create_pledge()` | Add to customer channel | Allow DM initiation |
| Sponsor bid created | `sponsor_service.create_bid()` | — (not yet accepted) | Allow DM initiation |
| Sponsor bid accepted/paid | `sponsor_service.update_bid_status()` | Add to sponsor channel | Already open |

`add_member()` is idempotent — if user is already a member, it's a no-op. DM creation is also idempotent (deterministic conversation ID).

**Remove member triggers (revoke access):**

| Trigger | Backend Hook Location | Announcement Channel | DM |
|---------|----------------------|---------------------|-----|
| Ticket refund (check: no remaining tickets or pledges) | `ticket_service.refund_ticket()` | Remove from customer channel | Set read-only |
| Pledge refund (check: no remaining tickets or pledges) | `pledge_service.refund_pledge()` | Remove from customer channel | Set read-only |
| Sponsor bid rejected | `sponsor_service.update_bid_status()` | Remove from sponsor channel (if was member) | Set read-only |
| Sponsor bid cancelled | `sponsor_service.cancel_bid()` | Remove from sponsor channel (if was member) | Set read-only |

`revoke_access()` checks if user has ANY remaining financial tie (other tickets, other pledges). Only kicks if ALL ties are gone. For sponsors, bid rejection/cancellation always revokes — there is no "remaining tie" check (one bid per sponsor per event).

#### 4k. Admin Configuration

New platform settings (stored in `platform_setting` table):

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `completed_event_chat_retention_days` | int | 7 | Days after event completion before hiding from "My Events" tab |

Exposed via existing `/api/v1/config` public endpoint → `PublicConfig` model → `ConfigProvider`.

### 5. Frontend — New Files (3-Layer)

#### 5a. New Dependency

```yaml
# pubspec.yaml
firebase_database: ^11.x
```

#### 5b. Models

```
FrontEnd/lib/models/chat.dart

ChatChannel           # channel_id, event_id, type, status, last_post_at
ChatPost              # id, channel_id, sender_id, body, msg_type, created_at, reaction_counts
ChatConversation      # conv_id, event_id, type, status, participant metadata, last_message, unread
ChatMessage           # id, sender_id, body, msg_type, client_id, created_at, status
UserReaction          # "like" | "dislike" | null
MyEventCard           # event metadata + channel + conversation + tickets (composite model for UI)
```

#### 5c. Repository: `chat_firebase_repository.dart`

Replaces both `chat_repository.dart` (REST) and `chat_socket_service.dart` (WebSocket) with a single class:

```
ChatFirebaseRepository
  # Channels (Announcements)
  ├── getChannel(channelId) → Stream<ChatChannel>
  ├── getPosts(channelId) → Stream<List<ChatPost>>
  ├── getUserReaction(channelId, postId, userId) → Stream<UserReaction>
  ├── reactToPost(channelId, postId, userId, reaction) → Future<void>
  │     (handles shard selection, user_reactions write, toggle logic)
  ├── getUserChannels(userId) → Stream<List<String>>
  │     (reads channel_members to find user's channels)
  ├── getReadCursor(channelId, userId) → Stream<String?>
  ├── setReadCursor(channelId, userId, postId) → Future<void>
  # DMs
  ├── getConversations(userId) → Stream<List<ChatConversation>>
  ├── getMessages(conversationId) → Stream<List<ChatMessage>>
  ├── sendMessage(conversationId, body, msgType, clientId) → Future<void>
  ├── markRead(conversationId, userId) → Future<void>
  ├── setTyping(conversationId, userId, bool) → Future<void>
  ├── getTyping(conversationId) → Stream<Map<String, bool>>
  # REST (backend gatekeeper)
  ├── initConversation(eventId) → Future<ChatConversation>
  ├── createChannel(eventId, type) → Future<ChatChannel>
  ├── createPost(channelId, body, msgType) → Future<ChatPost>
  ├── uploadImage(targetId, bytes, filename) → Future<String>
  │     (REST: uploads to backend, returns URL)
  ├── attachImage(channelId, postId, imageUrl) → Future<void>
  │     (REST: updates post's image_url after upload)
  ├── attachDmImage(convId, messageId, imageUrl) → Future<void>
  │     (REST: updates message's image_url after upload)
  └── dispose() → cancel all Firebase listeners
```

#### 5d. Provider: `ChatFirebaseProvider`

```
ChatFirebaseProvider extends ChangeNotifier
  State:
    myEventCards: List<MyEventCard>         # composite: event + channel + DM + tickets
    activeChannel: ChatChannel?
    activePosts: List<ChatPost>
    activeMessages: List<ChatMessage>
    typingUsers: Map<String, bool>
    loading: bool
    error: String?
    activeConversationId: String?
    activeChannelId: String?

  Methods:
    # My Events tab
    loadMyEvents() → builds MyEventCard list from channels + conversations + tickets

    # Announcement channels
    openChannel(channelId) → subscribe to posts stream
    closeChannel() → cancel post subscription
    createPost(body, msgType) → REST call to backend
    reactToPost(postId, reaction) → Firebase direct write (sharded)

    # DMs
    openConversation(id) → subscribe to message + typing streams
    closeConversation() → cancel message/typing subscriptions
    sendMessage(body, msgType) → Firebase direct write
    markRead() → Firebase direct write
    setTyping(bool) → Firebase direct write
    initConversation(eventId) → REST call to backend

    # Image upload
    uploadImage(bytes, filename) → REST call to backend

  Lifecycle:
    Stream subscriptions auto-cancel on close/dispose
    Channel/conversation streams stay alive while provider exists
```

#### 5e. Screens

| Screen | Status | Purpose |
|--------|--------|---------|
| `my_events_tab.dart` | **New** | Unified event cards (replaces `MyTicketsScreen` for customers, replaces `ConversationsScreen` for sponsors) |
| `announcement_channel_screen.dart` | **New** | Read announcements + like/dislike. Organizer: compose + post. |
| `dm_chat_screen.dart` | **New** | 1:1 DM screen. Reuses `bid_chat_screen.dart` UI patterns (bubbles, image picker, typing indicator). |
| `organizer_inbox_screen.dart` | **New** | Event list → event chat hub (customers section + sponsors section). |
| `organizer_event_chat_hub.dart` | **New** | Two sections: Customer (announcements + DMs) and Sponsor (announcements + DMs). |

### 6. What Stays Untouched in Phase 1

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
2. **Extend `chat_conversation` table**: Add `bid_id` column for sponsor conversations
3. **Update `ChatFirebaseProvider`**: Add sponsor conversation support (bid_id, sponsor-specific metadata)
4. **Migrate `bid_chat_screen.dart`**: Point to `ChatFirebaseProvider` instead of old `ChatProvider`
5. **Unify organizer inbox**: Remove the dual-source merge — everything reads from Firebase
6. **Unify "My Events" tab for sponsors**: Sponsor announcements + DMs now come from Firebase (same as customer)
7. **Delete old code**:
   - `chat_socket_service.dart`
   - `chat_provider.dart` (old)
   - `chat_repository.dart` (old)
   - `Backend/app/api/v1/chat.py` (WebSocket endpoint + old REST routes)
   - `Backend/app/services/chat_service.py` (Redis stream logic)
   - Redis archive/purge cron tasks
8. **Remove Redis chat config**: `chat_stream_maxlen`, `chat_archive_retention_days` (replace with Firebase equivalents)

---

## Testing Strategy

### Backend Tests

| Test Area | Approach |
|-----------|----------|
| Firebase Chat Repository | Mock Firebase Admin SDK `db.reference()`. Test CRUD, shard writes, aggregation, member management. |
| Channel Service | Mock `firebase_chat_repo` + `ticket_repo`/`funding_repo`. Test organizer validation, member auto-population, post creation. |
| Conversation Service | Mock `firebase_chat_repo` + `funding_repo`/`ticket_repo`. Test access validation, duplicate prevention, revoke_access with remaining-tie check. |
| API Routes | Integration tests with test client. Mock Firebase. Test auth, organizer-only post creation, response shapes. |
| Firebase Listener | Unit test `on_new_message` and `on_reaction_shard_change` with synthetic events. Verify unread increment, FCM push, reaction aggregation. |
| Auto-kick | Test revoke_access called on refund/rejection. Verify partial refund does NOT kick. |
| Cron Tasks | Test archive export format, purge deletion, status transitions. |

### Frontend Tests

| Test Area | Approach |
|-----------|----------|
| ChatFirebaseRepository | Mock `FirebaseDatabase.instance.ref()`. Test stream emissions, sharded reaction writes, message sending. |
| ChatFirebaseProvider | Mock repository. Test MyEventCard building, state transitions, reaction toggle logic. |
| MyEventsTab | Widget test with mock provider. Event card sort order, status badges, tap navigation. |
| AnnouncementChannelScreen | Widget test. Post list, like/dislike buttons, organizer compose box, read-only banner. |
| DmChatScreen | Widget test. Message bubbles, image picker, typing indicator, read-only banner. |
| OrganizerInboxScreen | Widget test. Event list, chat hub sections, unread badges. |

### Manual Testing Checklist

- [ ] Customer with ticket can see announcement channel
- [ ] Customer without ticket/pledge cannot access channel
- [ ] Organizer can post announcement — appears in real-time for all members
- [ ] Like/dislike updates in real-time, toggles correctly, one-per-user enforced
- [ ] Customer can initiate DM with organizer
- [ ] Messages appear in real-time on both sides
- [ ] Typing indicator works in DMs
- [ ] Image upload works in both channels and DMs
- [ ] Unread counts update correctly
- [ ] Full ticket refund → customer removed from channel, DM read-only
- [ ] Partial refund (still has other ticket) → access preserved
- [ ] Sponsor bid rejected → removed from sponsor channel, DM read-only
- [ ] Organizer sees event list → chat hub with customer + sponsor sections
- [ ] "My Events" tab: live events sorted to top
- [ ] Completed events become read-only, hidden after retention period
- [ ] FCM push notification for offline recipient
- [ ] Offline message queuing (Firebase native)
- [ ] App backgrounded → foregrounded → messages sync
- [ ] Admin can configure `completed_event_chat_retention_days`

---

## Effort Estimates

| Phase | Scope | Estimate |
|-------|-------|----------|
| Phase 1 | Announcement channels + customer DMs + unified My Events tab + organizer inbox + auto-kick hooks + Firebase listener | ~8-10 days |
| Phase 2 | Sponsor chat migration + code cleanup + unified inbox + My Events sponsor unification | ~4-5 days |
| **Total** | | **~12-15 days** |

---

## Infrastructure Requirements

- Enable Firebase Realtime Database in Firebase Console (same project as Auth/FCM)
- Deploy security rules (JSON above)
- Add `firebase_database` to Flutter pubspec
- Add `firebase-admin` RTDB initialization to backend (already has firebase-admin for Auth)
- Firebase Listener process needs to run alongside ARQ worker (new entry in docker-compose or same container)

## Cost Considerations

- Firebase RTDB: $5/GB stored, $1/GB downloaded. Chat messages + announcement posts are small (few KB per conversation). Negligible cost at current scale.
- Sharded counters add ~10x the write volume for reactions, but each write is tiny (~50 bytes). At 1000 reactions/day, this is well under free tier.
- Simultaneous connections: Free tier supports 100 concurrent. Blaze plan (pay-as-you-go) has no hard limit. $0.06/GB transferred.
