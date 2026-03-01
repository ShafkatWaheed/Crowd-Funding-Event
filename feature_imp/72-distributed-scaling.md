# Distributed Scaling: Multi-Pod Coordination

## Problem

When running multiple backend pods (horizontal scaling), three components use **in-memory state** that doesn't share across processes. Each pod acts independently, breaking correctness.

---

## 1. Redis-Backed Rate Limiting

### Current (broken at scale)

`app.rate_limit` uses slowapi with in-memory storage. Each pod has its own counters.

```
Pod A: "user-42 made 40 requests"   ← under 120/min limit
Pod B: "user-42 made 40 requests"   ← under limit
Pod C: "user-42 made 40 requests"   ← under limit

Total reality: user-42 made 120 requests — limit should have kicked in
```

### Fix

Replace slowapi's in-memory storage with a Redis-backed storage backend. All pods read/write the same counter per user/IP.

### Files to change

- `Backend/app/rate_limit.py` — swap storage backend to Redis (slowapi supports custom storage)
- `Backend/app/main.py` — pass Redis URL to limiter storage at startup

### Implementation notes

- slowapi accepts a custom `storage_uri` param pointing to Redis (e.g. `redis://localhost:6379`)
- Use sliding window algorithm (Redis ZSET) for accuracy, or fixed window (INCR + EXPIRE) for simplicity
- Fallback: if Redis is down, allow requests through (open circuit) — don't block all traffic because rate limiting is unavailable
- Keep the existing `dynamic_limit()` and `_key_func()` logic unchanged — only the storage layer changes

---

## 2. Cron Leader Election (SETNX)

### Current (broken at scale)

ARQ worker cron jobs (`app.worker.main.WorkerSettings.cron_jobs`) run on every worker instance. With 3 worker pods, each cron job fires 3 times — triple emails, triple payouts, triple reconciliation.

### Fix

Before running a cron job, the worker attempts to "claim" it in Redis using SETNX:

```
Worker A: SETNX "cron_lock:daily_reconciliation" "worker-a" → OK (got it, run the job)
Worker B: SETNX "cron_lock:daily_reconciliation" "worker-b" → FAIL (skip)
Worker C: SETNX "cron_lock:daily_reconciliation" "worker-c" → FAIL (skip)
```

The lock has a TTL (e.g. 5 minutes) so if the winning worker crashes mid-job, the lock auto-expires and the next cycle can proceed.

### Files to change

- `Backend/app/worker/tasks.py` — wrap each cron task function in an `acquire_cron_lock()` guard
- `Backend/app/worker/redis_pool.py` — add `acquire_cron_lock(task_name, ttl)` helper using SETNX + EXPIRE

### Implementation notes

```python
async def acquire_cron_lock(task_name: str, ttl: int = 300) -> bool:
    """Try to claim exclusive cron execution. Returns True if this worker won."""
    pool = await get_arq_pool()
    key = f"cron_lock:{task_name}"
    acquired = await pool.set(key, "1", nx=True, ex=ttl)
    return bool(acquired)
```

Each cron task wraps its body:

```python
async def daily_reconciliation(ctx):
    if not await acquire_cron_lock("daily_reconciliation", ttl=300):
        return  # another worker is handling it
    # ... actual reconciliation logic ...
```

### Affected cron jobs (8 total)

| Task | Risk if duplicated |
|------|--------------------|
| `process_escrow_release` | Double payouts |
| `process_scheduled_payouts` | Double payouts |
| `daily_reconciliation` | Duplicate reports |
| `check_ticket_escrows` | Duplicate status transitions |
| `check_sponsor_escrows` | Duplicate status transitions |
| `archive_completed_chats` | Harmless but wasteful |
| `purge_old_archives` | Harmless but wasteful |
| `cleanup_old_records` | Harmless but wasteful |

Priority: escrow release and scheduled payouts are **critical** — must not run twice.

---

## 3. WebSocket Connection Registry in Redis

### Current (broken at scale)

`app.api.v1.chat.py` stores active WebSocket connections in a Python dict:

```python
_connections: dict[int, WebSocket] = {}  # user_id → socket
```

If user-42 is on Pod A and user-99 sends them a message from Pod B, Pod B can't find user-42's socket. Message lost.

```
Pod A: _connections = {42: <ws>}     ← user-42 is here
Pod B: _connections = {99: <ws>}     ← user-99 is here

User-99 sends message → hits Pod B → Pod B looks up user-42 → not found → lost
```

### Fix

The app already uses Redis Pub/Sub to broadcast messages across processes — this part works. The missing piece is a **connection registry** so the system knows which users are online (for presence, delivery receipts, etc.).

On WebSocket connect:
```
SADD "ws:online" "42"              # user-42 is online
SET  "ws:pod:42" "pod-a" EX 60     # user-42 is on pod-a (TTL refreshed by heartbeat)
```

On WebSocket disconnect:
```
SREM "ws:online" "42"
DEL  "ws:pod:42"
```

Heartbeat (every 30s, already exists):
```
EXPIRE "ws:pod:42" 60              # refresh TTL
```

### Files to change

- `Backend/app/api/v1/chat.py` — add Redis SET/DEL on connect/disconnect, EXPIRE on heartbeat
- `Backend/app/services/chat_service.py` — use Redis SISMEMBER to check online status for delivery/presence

### Implementation notes

- Keep the local `_connections` dict for the actual WebSocket object (can't store sockets in Redis)
- Redis registry is for **cross-pod awareness** only: "is user X online anywhere?" and "which pod?"
- Message delivery already works via Pub/Sub — this adds presence tracking
- If a pod crashes without cleanup, TTL auto-expires the stale entries (self-healing)

---

## Dependencies

- **Requires:** Redis (already in use for ARQ, cache, chat)
- **Requires:** [44-backend-scaling-infra.md](44-backend-scaling-infra.md) (connection pooling, advisory locks)
- **Requires:** [61-configurable-rate-limits.md](61-configurable-rate-limits.md) (dynamic_limit stays, storage changes)
- **Requires:** [70-sponsor-negotiation-chat.md](70-sponsor-negotiation-chat.md) (WebSocket chat system)
- **Requires:** [49-redis-caching.md](49-redis-caching.md) (Redis infrastructure)

## Priority

| Component | Priority | Risk if skipped |
|-----------|----------|----------------|
| Cron leader election | **P0** | Double payouts, duplicate emails |
| Redis rate limiting | **P1** | Rate limits ineffective, abuse possible |
| WebSocket registry | **P2** | Presence inaccurate, but messages still deliver via Pub/Sub |

## Effort estimate

- Cron leader election: Small — one helper function + wrap 8 tasks
- Redis rate limiting: Small — swap slowapi storage backend config
- WebSocket registry: Medium — Redis SET/DEL/EXPIRE lifecycle + presence queries
