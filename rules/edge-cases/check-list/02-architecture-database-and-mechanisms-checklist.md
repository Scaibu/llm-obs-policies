# Checklist 02: Architecture, Database & Concurrency Mechanisms (Exhaustive Verification)

**Source Reference**: [Why Failures Take Their Shape (Parts 9–17)](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/why-failures-take-their-shape.md)  
**Scope**: Complete operational checklist across Database Isolation Levels, Concurrency Control, Lock Internals, Pagination, Replication Lag, DDL Migrations, Application State Engines, Memory Leaks, Infrastructure Connection Pools, DNS, Reconcilers, and Principles 16–28.

---

## 1. Database Isolation Levels & Anomaly Elimination (Parts 9, 10.1)

- [ ] **Isolation Level Anomaly Mapping**:
  - [ ] **Read Committed**: Checked against Non-Repeatable Reads, Phantom Reads, and Lost Updates.
  - [ ] **Repeatable Read / Snapshot Isolation**: Verified that code is hardened against **Write Skew** (where two transactions concurrently read valid state and execute overlapping updates that together violate a global constraint).
  - [ ] **Serializable Isolation**: If `SERIALIZABLE` is used, are application query executors wrapped in automatic retry loops catching serialization failure error codes (`40001` in Postgres, `1213` deadlock in MySQL)?
- [ ] **Optimistic vs. Pessimistic Locking Strategy**:
  - [ ] **Optimistic Concurrency Control (OCC)**:
    - [ ] Target tables have an explicit `version INT NOT NULL DEFAULT 1` or `updated_at` column.
    - [ ] Mutations execute: `UPDATE table SET val = :val, version = version + 1 WHERE id = :id AND version = :expected_version;`
    - [ ] Rows affected checked: If rows $= 0$, code throws an explicit `OptimisticLockException` and retries or reports conflict.
  - [ ] **Pessimistic Locking**:
    - [ ] High-contention rows acquired with `SELECT ... FOR UPDATE` within a short, bounded transaction.
    - [ ] Lock duration minimized by keeping external network calls (HTTP/gRPC/email) strictly **outside** the transaction block.
  - [ ] **Hot-Spot Increment Optimization**:
    - [ ] Are high-frequency counter updates (page views, ledger balances) designed as append-only event streams or sharded counters rather than updating a single hot database row?

---

## 2. Lock Management & Queue Processing (Parts 10.2, 10.3)

- [ ] **Database Queue Worker Safety (`SKIP LOCKED`)**:
  - [ ] Relational DB queue consumers query jobs using `SELECT id, payload FROM background_jobs WHERE status = 'PENDING' ORDER BY priority DESC, id ASC FOR UPDATE SKIP LOCKED LIMIT :batch_size;`
  - [ ] Status columns used in queue polling are backed by composite indexes (e.g., `CREATE INDEX idx_jobs_status_prio ON background_jobs (status, priority, id) WHERE status = 'PENDING';`).
  - [ ] Do workers avoid bare `SELECT ... FOR UPDATE` on queue tables to prevent all worker threads blocking behind a single slow job?
- [ ] **Deadlock Prevention & Lock Ordering**:
  - [ ] Are multi-entity locks always acquired in a deterministic alphabetical or numeric sequence (e.g., sort account IDs before locking)?
  - [ ] Are deadlock logs monitored and alert thresholds established?
- [ ] **Lock Timeouts on Application Queries**:
  - [ ] Is `statement_timeout` (e.g. 5s) and `lock_timeout` (e.g. 2s) set on all database connections to prevent stuck transactions from locking connection pools?

---

## 3. High-Performance Pagination & Keyset Navigation (Part 10.4)

- [ ] **Complete Elimination of Deep `OFFSET`**:
  - [ ] Are tables with $> 10,000$ rows prohibited from using `OFFSET N` queries (which force full index scans of $N$ skipped rows)?
- [ ] **Keyset (Cursor-Based) Pagination Verification**:
  - [ ] Does pagination retrieve records using tuple comparison:
    ```sql
    SELECT id, created_at, title
    FROM audit_events
    WHERE (created_at, id) < (:last_created_at, :last_id)
    ORDER BY created_at DESC, id DESC
    LIMIT 50;
    ```
  - [ ] Is there a composite index matching the exact sort order: `CREATE INDEX idx_events_created_id ON audit_events (created_at DESC, id DESC);`?
  - [ ] Is a strictly unique tie-breaker column (e.g., primary key `id`) always included in the `ORDER BY` to prevent missed or repeated rows when timestamps collide?

---

## 4. Replication Lag & Consistency Guardrails (Part 10.5)

- [ ] **Read-Your-Own-Writes Consistency**:
  - [ ] Immediately after a user creates or edits an entity, are subsequent read requests routed to the **primary** database (or cached in session) for a grace period (e.g. 5–10s)?
- [ ] **Decision Logic Isolation from Read Replicas**:
  - [ ] Are critical business decisions (charging cards, releasing escrow, checking stock availability) executed strictly against the authoritative primary database, never against asynchronous read replicas?
- [ ] **Replication Lag Monitoring**:
  - [ ] Are replication lag monitors (e.g. `pg_stat_replication.replay_lag` / MySQL seconds behind master) configured with alerts firing at $> 5\text{ seconds}$?

---

## 5. DDL Migrations & Zero-Downtime Schema Safety (Part 10.6)

- [ ] **DDL Lock Queue Safety**:
  - [ ] Do all migration scripts enforce: `SET lock_timeout = '2000ms';` before running `ALTER TABLE` or `CREATE INDEX`?
- [ ] **Concurrent Index Creation**:
  - [ ] Are PostgreSQL indexes created using `CREATE INDEX CONCURRENTLY` outside of transaction blocks (`autocommit = true`)?
  - [ ] Are invalid index statuses audited after failed concurrent index creation attempts?
- [ ] **Zero-Downtime Column Addition & Renaming**:
  - [ ] Are new columns added as `NULL` or with default values that do not trigger full table rewrites (Postgres 11+ metadata-only defaults)?
  - [ ] Are column renames executed via the Expand-Migrate-Contract pattern rather than a breaking single-step `RENAME COLUMN`?

---

## 6. Transactional Boundaries & Dual-Write Elimination (Part 9, Part 15)

- [ ] **Zero Split Dual Writes**:
  - [ ] Verified that code **never** commits a DB transaction and subsequently attempts a network message publish or webhook call as a separate uncoordinated step.
- [ ] **Transactional Outbox Implementation**:
  - [ ] Are domain events inserted into an `outbox` table within the exact same database transaction that modifies business entities?
  - [ ] Is outbox polling or Change Data Capture (CDC / Debezium) used to guarantee at-least-once message delivery to downstream message brokers?
- [ ] **Outbox Polling Sequence Gap Mitigation**:
  - [ ] When polling by auto-increment ID (`WHERE id > :last_id`), are out-of-order transaction commits handled (e.g. using continuous sequence trackers or a trailing 10-second time buffer window)?

---

## 7. Application State Engines & Memory Safety (Part 11)

- [ ] **Explicit State Machine Matrix**:
  - [ ] Are all entity lifecycle transitions defined in a centralized, validated state machine table?
  - [ ] Does every update check current state atomically: `UPDATE orders SET status = 'PAID' WHERE id = :id AND status = 'PENDING';`?
  - [ ] Are terminal states (`COMPLETED`, `CANCELLED`, `REFUNDED`) permanently locked against further updates?
- [ ] **Memory & Buffer Ceiling**:
  - [ ] Are large datasets processed via streaming cursors / chunking, never loading entire multi-gigabyte queries into heap memory?
  - [ ] Are in-memory caches (LRU caches) strictly bounded by maximum element counts and TTLs?
- [ ] **Asynchronous Task Cancellation**:
  - [ ] Are background tasks and goroutines wired to cancellation contexts (`AbortController`, `context.Context`) to terminate processing when clients disconnect?

---

## 8. Connection Pooling & Network Infrastructure (Part 12)

- [ ] **Little's Law Connection Pool Math**:
  - [ ] Is connection pool size sized appropriately:
    $$\text{Max Pool Connections} \approx (\text{DB CPU Cores} \times 2) + \text{Disk Spindle Count}$$
  - [ ] Is total pool allocation across all application pods capped below database `max_connections` with 20% reserved headroom for admin tasks?
- [ ] **DNS Caching & TTL Limits**:
  - [ ] Is DNS lookup cache TTL configured to 10–30s across Node (`lookup: dnsCache`), JVM (`networkaddress.cache.ttl=30`), and Go to ensure zero-downtime during IP failover?
- [ ] **Graceful Pod Termination Lifecycle**:
  - [ ] Do application pods handle `SIGTERM` signals cleanly:
    1. Receive `SIGTERM`.
    2. Wait 5 seconds (`preStop` hook) for service mesh / load balancer routing updates.
    3. Stop accepting new connections.
    4. Drain and finish in-flight requests within `terminationGracePeriodSeconds`.
    5. Close DB connection pools and exit.
- [ ] **Readiness vs. Liveness Probe Safety**:
  - [ ] Does the **Liveness** probe only test process responsiveness, avoiding external dependencies (DB, Kafka) to prevent cluster-wide rolling reboot cascades during database latency spikes?
  - [ ] Does the **Readiness** probe verify downstream reachability before accepting user traffic?

---

## 9. Continuous Invariant Reconciliation & Drift Auditing (Part 14, Part 16)

- [ ] **Continuous Out-of-Band Audit Crons**:
  - [ ] Are reconciliation crons running periodically (every 5–60 mins) to detect data drift across systems?
  - [ ] Financial balance check: Sum of transaction entries matches account balance.
  - [ ] Inventory balance check: Sum of reserved + available inventory matches total warehouse stock.
  - [ ] Orphan record check: No child records exist without valid parent references.
- [ ] **Stuck State Reconciliation**:
  - [ ] Are there automated jobs searching for records stuck in `IN_PROGRESS` or `PENDING` states longer than their maximum timeout, triggering auto-recovery or alerts?

---

## 10. Principles 16–28 Operationalized (Part 17)

- [ ] Never wait without an explicit, shorter timeout than the caller.
- [ ] Treat "unknown" as a first-class outcome on every network call.
- [ ] Enforce atomicity where a single DB engine provides it; use outbox + idempotency across systems.
- [ ] Base business decisions strictly on fresh, authoritative primary reads, not stale replicas or caches.
- [ ] Design and rehearse the failure modes of every safeguard (retries, failover, autoscaling, circuit breakers).
- [ ] Prefer small, staged, reversible migrations over monolithic schema changes.
- [ ] Measure and alert on resource headroom (distance to limit), not merely boolean uptime.
- [ ] Alert on missing expected heartbeat signals, not just presence of errors.
- [ ] Automate recurrent maintenance: SSL renewals, secret rotations, partition dropping, backup restore drills.
- [ ] Maintain recovery tooling independent of the systems they monitor and restore.
- [ ] Track every architectural exception with an assigned owner and hard expiration date.
- [ ] Ensure domain models match reality before attempting performance optimizations.
- [ ] Quantify capacity with simple math: Little's Law, retry amplification ratios, and fan-out tail probabilities.
