# Adding Real-Time Queue, Redis, and Load Balancing

This doc describes how to add **real-time queue patterns**, **Redis** (beyond current ARQ use), and **load balancing** to the Crowd Funding Event backend so you can handle high-demand ticket sales without stampedes or oversell.

---

## What You Already Have

- **Redis:** Used for ARQ (refund jobs, email). `app.worker.redis_pool` + `REDIS_URL` in config.
- **Rate limiting:** slowapi, per-route limits (e.g. purchase 15/min).
- **Advisory lock:** `pg_advisory_xact_lock(event_id)` around purchase/pledge so concurrent buyers for the same event are serialized; no oversell.

---

## 1. Real-Time Queue Patterns (Ticket Sale Queue)

**Goal:** For high-demand events, put users in a **waiting room** then a **queue** instead of everyone hitting checkout at once.

### Option A: Redis-backed queue (recommended)

- **Waiting room:** Before sale opens, users hit e.g. `POST /events/{id}/queue/join` → you store a **queue token** in Redis (e.g. Sorted Set by timestamp, or a list) and return a **position** or **token**.
- **Polling:** Frontend polls `GET /events/{id}/queue/status?token=...` every few seconds; backend reads position from Redis and returns `{ "position": 42, "can_purchase": false }` until their turn.
- **Turn to buy:** When it’s their turn (or when sale opens and queue is processed), API returns `can_purchase: true` and a short-lived **checkout token**; frontend then calls existing `purchase_ticket` with that token (or you gate purchase behind “in queue and allowed”).
- **Redis structures:**
  - **Sorted Set:** `event:queue:{event_id}` → score = join time, value = user_id or session_id. You serve in order; when a user is “allowed,” you remove them and issue checkout token (short TTL in Redis).
  - Or **List:** LPUSH join, BRPOP serve; same idea.

**Backend pieces to add:**

- A **queue service** (e.g. `app.services.queue` or `app.api.v1.events.queue`) that uses **Redis** (see section 2) to:
  - `join_queue(event_id, user_id)` → add to Redis, return position/token.
  - `get_queue_status(event_id, token)` → position, can_purchase, optional checkout_token.
  - `allow_checkout(event_id, token)` → called when it’s their turn; set a short-lived key `checkout:{event_id}:{user_id}` so purchase_ticket accepts the request.
- Optional: **per-event queue cap** (e.g. max 10k in queue) to avoid unbounded growth.
- **Queue-enabled events:** Only enable the queue for selected events via a per-event flag (see section **Queue-enabled events (admin)** below).

**Frontend:**

- “Join waiting room” button → call join; show “You’re in line. Position: N.”
- Poll status; when `can_purchase` → show “Proceed to checkout” and call existing purchase flow (with checkout token if you use it).

---

## 2. Redis for Queue (and Optional Cache)

You already have Redis for ARQ. For **queue state** you need to talk to Redis **directly** (not only via ARQ), so use the same `REDIS_URL` with a **second client**.

**Use `redis.asyncio`:**

- Add dependency: **`redis[asyncio]`** (official redis-py async support).
- In a new module (e.g. `app.redis.client` or alongside `app.worker.redis_pool`), create an async Redis client from `settings.REDIS_URL`, and create/close it in app lifespan (same pattern as the ARQ pool).
- Queue service uses this client for:
  - **Sorted Set** `event:queue:{event_id}` (or List) for queue order.
  - Keys like `checkout:{event_id}:{user_id}` with TTL for the “allowed to purchase” window.
- Do not use the ARQ pool for queue state; ARQ’s pool is for job enqueue only. A dedicated `redis.asyncio` client keeps queue logic clear and gives you full access to Redis commands (e.g. `zadd`, `zrange`, `setex`).

**Optional – Redis cache:**

- Use the same client (or same Redis instance) for caching, e.g.:
  - Event detail by ID (TTL 60–120s).
  - “Featured events” list.
- Invalidate on event update or use short TTL. Improves list/detail performance under load and fits well with load balancing (shared cache across instances).

---

## Queue-enabled events (admin)

The queue should only apply to **selected events**, not all. That way normal events keep the current “buy when you want” flow, and high-demand events can opt in to a waiting room + queue.

**Model and API:**

- Add a boolean field on **Event**, e.g. **`queue_enabled`** (default `False`). When `True`, joining the queue and the queue status endpoints are active for that event, and `purchase_ticket` is gated on “in queue and allowed to checkout” (see queue service).
- **Who can set it:** Only **admin** (and optionally the event organizer if you later allow it). So:
  - **PATCH /events/{id}** – allow `queue_enabled` in the update body only when the caller is admin (or restrict to an admin-only endpoint).
  - Or add an **admin-only** endpoint, e.g. **PATCH /admin/events/{id}/queue-enabled** with body `{ "queue_enabled": true }`, and keep general event update from changing this field.
- **Event response:** Include `queue_enabled` in the event detail response so the frontend can show “Join waiting room” only when `queue_enabled` is true and the event is in a status that allows ticket purchase (e.g. `selling_tickets`).
- **Admin UI:** In the admin dashboard (event list or event detail), add a control (e.g. toggle or checkbox) “Queue for ticket sale” and call the API that sets `queue_enabled` for that event.

**Behavior summary:**

- `queue_enabled == False` (default): no queue; existing purchase flow unchanged.
- `queue_enabled == True`: show “Join waiting room”; user must join queue, poll status, and only when `can_purchase` (and optional checkout token) call `purchase_ticket`.

---

## 3. Load Balancing

Load balancing is **infrastructure**, not application code. It spreads traffic across multiple app instances so no single process handles “everyone at once.”

**What to do:**

1. **Run multiple app instances**
   - Same FastAPI app, multiple processes or hosts.
   - Example: 2–4 Uvicorn workers per host, or 2–4 containers/pods, each running Uvicorn.

2. **Put a load balancer in front**
   - **Local:** e.g. **nginx** in front of several `uvicorn` processes (upstream with `server 127.0.0.1:8001`, `8002`, …).
   - **Cloud:** **AWS ALB**, **GCP Load Balancer**, **Cloudflare**, etc., pointing to your app instances (by port or target group).

3. **Session/state**
   - Your app is largely **stateless** (DB + Redis). No in-process session storage that would tie a user to one instance. So **round-robin or least-connections** is fine.
   - If you add **queue tokens**, store them in **Redis** (section 2) so any instance can validate them.

4. **Health checks**
   - You already have `/healthz` and `/health`. Point the load balancer’s health check at `/health` (or `/healthz`) so it only sends traffic to healthy instances.

**Example (single host, nginx + multiple workers):**

```text
                    [nginx :80]
                         |
         +---------------+---------------+
         |               |               |
    [uvicorn :8001] [uvicorn :8002] [uvicorn :8003]
         |               |               |
         +---------------+---------------+
                         |
              [PostgreSQL]  [Redis]
```

**Example (Docker/Kubernetes):**

- Run 3 replicas of your FastAPI image.
- Service/LoadBalancer or Ingress in front; health check on `/health`.
- All replicas share the same DB and Redis; advisory lock and Redis queue work across them.

---

## 4. Suggested Order of Implementation

1. **Load balancing (no app code change)**  
   - Add nginx (or cloud LB) and 2+ Uvicorn workers (or 2+ containers).  
   - Confirm health checks and that traffic is spread.

2. **Redis client for queue (and optional cache)**  
   - Add `redis[asyncio]` (or similar), create async Redis client in lifespan, use same `REDIS_URL`.  
   - Optional: use it for a small cache (e.g. event by ID) to validate the path.

3. **Queue service + API**  
   - Implement join / status / allow-checkout using Redis Sorted Set (or List).  
   - Add `GET/POST /events/{id}/queue/...` (or under a `queue` sub-router).  
   - Gate `purchase_ticket` on “in queue and allowed” when queue is enabled for that event.

4. **Frontend**  
   - Waiting room UI, poll queue status, then “Proceed to checkout” using existing purchase flow.

5. **Queue-enabled events (admin)**  
   - Add `queue_enabled` on Event; only admin can set it (see **Queue-enabled events (admin)** section). Expose in event API and admin UI so only selected events use the queue.

---

## 5. Summary

| Piece | Status | Action |
|-------|--------|--------|
| **Real-time queue** | Not present | Add queue service + Redis (Sorted Set/List), join/status/allow-checkout API, optional checkout token; frontend waiting room + poll. |
| **Redis** | In use for ARQ | Add a second async Redis client using **redis.asyncio** (same REDIS_URL) for queue state (and optional cache). |
| **Queue-enabled events** | Not present | Add `queue_enabled` on Event; **admin only** can enable per event (PATCH or admin endpoint); expose in event API and admin UI. |
| **Load balancing** | Not in app | Add nginx or cloud LB; run 2+ Uvicorn workers or 2+ app replicas; health checks on `/health`. |

This keeps your current behavior for normal events (no queue), adds a path for high-demand sales (queue + Redis), and uses load balancing to scale the app layer without changing core purchase/pledge logic.
