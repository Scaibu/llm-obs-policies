The most common mistake with background jobs is running unbounded in-process loops without distributed leases or fencing tokens. [Certain] When two replicas run the same cron job or process the same batch concurrently due to network jitter, un-fenced writes cause duplicate billing, corrupted aggregates, and deadlocks.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis
  ↺  registers cleanup
```

---

## 1. Job Specification Contract

```
defineJob(name) → jobSpec                                                   ▶
├── schedule() → cron | interval | event-triggered
├── singleton() → yes | no (whether only one replica across fleet may run)
├── overlapPolicy() → skip | queue | replace
├── timeout() → max duration before hard abort
├── chunkSize() → bounded items per unit of work (memory protection)
├── rateLimit() → max ops/second on shared downstream resources
└── idempotent() → must be yes (mandatory invariant)
```

[Likely] Multi-step or long-running orchestrations belong in a durable workflow or saga engine, not simple background cron jobs. The checkpoint, retry, and compensation logic below is the bare minimum for single-concern batch workers.

---

## 2. Distributed Execution & Lease Engine

```
runJob(context, jobSpec) → runResult
├── acquireLease(jobName, ttl) → lease + fencingToken             ⚙ ⚠ → skip run (lost race)
├── loadCheckpoint(jobName) → cursor                              ⚙
├── loop processChunk(context, cursor) → nextCursor               ▶
│   ├── fetchChunk(cursor, chunkSize) → items
│   ├── processItems(items)       (idempotent; uses fencingToken on every DB write)
│   ├── saveCheckpoint(nextCursor)
│   ├── renewLease(lease)                                         ⚠ → stop immediately (lost lease)
│   ├── throttle(rateLimit)                                       ⚙
│   └── stop if context cancelled or timeout reached
├── releaseLease(lease)                                           ⚙
├── recordRun(status, duration, itemsProcessed)                   ⚙
└── alertOn(missedSchedule | overran | failedTwice)               ⚙
```

---

## 3. Chunk Processing & Fencing Verification

```
processChunk(context, items, fencingToken) → nextCursor                     ▶
├── inTransaction(db)
│   ├── verifyFencingToken(jobName, fencingToken)                 ⚙ ⚠ → abort if token bumped
│   ├── applyBatchMutations(items)
│   ├── emitOutboxEvents(items)
│   └── updateCheckpointCursor(lastItemId)
└── advanceMonotonicClock()                                       ⚙
```

---

## 4. Strict Background Job Invariants

1. **Storage Fencing on All Mutations**: Every SQL update performed by a job must include `WHERE fencing_token = :current_token`. If an owner loses its lease during a GC pause, a newer incarnation with a higher token invalidates stale writes.
2. **Monotonic Lease Renewals**: Renew leases at $TTL / 3$ using a monotonic clock. If a renewal fails or returns zero rows, the job must immediately abort all in-flight work and refrain from external I/O.
3. **Bounded Chunk Memory Clamps**: Never fetch full datasets with `SELECT * FROM table`. Datasets must be paginated via indexed monotonic cursors (`WHERE id > :last_id ORDER BY id ASC LIMIT :chunk_size`).

