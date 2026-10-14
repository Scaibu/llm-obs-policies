# Checklist 05: Engine, Platform & Runtime Internals (Exhaustive Verification)

**Source Reference**: [Engine, Platform, and Runtime-Specific Edge Cases (Parts 44–58)](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/engine-platform-runtime-specific-edge-cases.md)  
**Scope**: Complete operational checklist across PostgreSQL, MySQL (InnoDB), Redis, Kafka, Elasticsearch, Kubernetes, Cloud (AWS/GCP), HTTP/gRPC/TLS Protocols, Language Runtimes (Go, Node, Python, JVM), and Principles 61–74.

---

## 1. PostgreSQL Internals & Storage Engine Gate (Part 45)

- [ ] **Transaction ID (XID) Wraparound Prevention**:
  - [ ] Are monitors tracking `datfrozenxid` age (`SELECT max(age(datfrozenxid)) FROM pg_database;`) with alarms firing if age exceeds $1.2 \text{ billion}$ transactions?
  - [ ] Is `autovacuum_freeze_max_age` configured properly to trigger aggressive freezing before reaching the 2-billion transaction emergency read-only shutdown threshold?
- [ ] **Autovacuum Tuning on High-Write Tables**:
  - [ ] Is `autovacuum_vacuum_scale_factor` tuned down on high-write tables (e.g. from default 0.2 to `0.05` or `0.01`) so vacuuming triggers frequently on small dead-tuple accumulation?
  - [ ] Is `autovacuum_cost_limit` increased (e.g. from default 200 to `2000`) with `autovacuum_cost_delay = 2ms` to prevent autovacuum worker starvation?
- [ ] **DDL Lock Queues & Lock Timeouts**:
  - [ ] Does every migration script execute `SET lock_timeout = '2s';` before running any `ALTER TABLE` or DDL statement, preventing DDL locks from queuing up and blocking all incoming application traffic?
- [ ] **Index Creation Safety**:
  - [ ] Are all production indexes created using `CREATE INDEX CONCURRENTLY` in non-transactional mode (`autocommit = true`)?
  - [ ] Is there an automated check querying `pg_index.indisvalid = false` to detect and clean up failed concurrent index builds?
- [ ] **Prepared Statement Cache & Plan Invalidation**:
  - [ ] Are connection poolers (PgBouncer in transaction mode) configured properly to handle or bypass prepared statement cached plan regression (`plan_cache_mode = force_custom_plan` or named prepared statements reset)?
- [ ] **Connection Memory & Work Mem Bounds**:
  - [ ] Is total memory allocation capped:
    $$\text{Max DB Memory} \approx \text{shared_buffers} + (\text{max_connections} \times \text{work_mem})$$
  - [ ] Are direct connections routed through PgBouncer connection poolers to prevent OS process fork memory overhead ($5\text{MB}–10\text{MB}$ per backend connection)?

---

## 2. MySQL (InnoDB) Specifics & Concurrency (Part 46)

- [ ] **Gap Locks & Deadlock Elimination**:
  - [ ] In `REPEATABLE READ` isolation, are updates and `SELECT ... FOR UPDATE` queries verified to use unique index lookups, preventing InnoDB from placing gap locks across large row ranges?
- [ ] **Metadata Lock (MDL) Queue Cascades**:
  - [ ] Are long-running SELECT transactions monitored and killed before initiating `ALTER TABLE` DDL operations?
- [ ] **Auto-Increment Lock Modes**:
  - [ ] Is `innodb_autoinc_lock_mode` set to `2` (interleaved mode) for high-concurrency batch inserts (compatible with row-based binlogging `binlog_format = ROW`)?
- [ ] **Replication Lag & Multi-Threaded Replication**:
  - [ ] Is `replica_parallel_workers` configured ($> 4$) to prevent single-threaded replication lag behind high-throughput primaries?

---

## 3. Redis & In-Memory Cache Hardening (Part 47)

- [ ] **Complete Elimination of Blocking Commands**:
  - [ ] Are $O(N)$ commands completely banned in production: `KEYS *`, `FLUSHALL`, `FLUSHDB`, `HGETALL` (on massive hashes), `SMEMBERS`?
  - [ ] Are iterative cursor commands (`SCAN`, `HSCAN`, `SSCAN`, `ZSCAN`) used exclusively for collection traversals?
  - [ ] Are large key deletions performed asynchronously using `UNLINK` instead of blocking `DEL`?
- [ ] **Memory Eviction Policy & Fragmentation**:
  - [ ] Is `maxmemory-policy` explicitly configured (`allkeys-lru` / `volatile-lru` for caching, `noeviction` for persistent message queues)?
  - [ ] Is memory fragmentation ratio monitored ($\text{mem_fragmentation_ratio} > 1.5$ triggers `activedefrag yes`)?
- [ ] **Persistence fsync Latency Protection**:
  - [ ] Is `appendfsync` configured as `everysec` with `no-appendfsync-on-rewrite yes` to prevent disk fsync stalls from blocking the Redis single-threaded event loop?
- [ ] **Redis Cluster Multi-Key Commands**:
  - [ ] Do multi-key operations (MGET, transactions, Lua scripts) wrap keys in explicit hash tags (e.g. `{user:123}.profile`, `{user:123}.orders`) so all target keys map to the same cluster hash slot?

---

## 4. Kafka & Message Broker Infrastructure (Part 48)

- [ ] **Consumer Rebalance Storm Prevention**:
  - [ ] Is `max.poll.interval.ms` configured with at least $3\times$ headroom above the maximum anticipated batch processing duration?
  - [ ] Are consumer groups configured with `CooperativeStickyAssignor` to allow incremental, non-blocking partition rebalances?
- [ ] **Commit Semantics & Duplicate Handling**:
  - [ ] Is `enable.auto.commit` disabled, and are offsets committed manually *after* processing is complete?
- [ ] **Poison Pill Elimination & Dead-Letter Queues (DLQ)**:
  - [ ] Do consumers wrap message deserialization in `try/catch` blocks, routing poison pill messages directly to a DLQ topic with alert dispatch, preventing consumer crash loops?
- [ ] **Partition Key Skew Audit**:
  - [ ] Are partition keys verified for high cardinality to prevent hot tenants from overloading single partition brokers?

---

## 5. Elasticsearch & Secondary Indexes (Part 49)

- [ ] **Mapping Explosion Mitigation**:
  - [ ] Is dynamic mapping disabled (`"dynamic": "strict"` or `"false"`) on open-ended JSON fields to prevent arbitrary keys from exhausting cluster metadata heap memory?
  - [ ] Is `index.mapping.total_fields.limit` explicitly configured ($< 1000$)?
- [ ] **Refresh vs. Flush Visibility Lag**:
  - [ ] Do application workflows account for the 1-second `refresh_interval` search visibility delay rather than expecting immediate consistency on write?
- [ ] **Pagination Safety**:
  - [ ] Are deep pagination queries migrated to `search_after` with point-in-time (PIT) tokens, avoiding deep `from + size` queries ($> 10,000$ rows)?

---

## 6. Kubernetes & Container Orchestration (Part 50)

- [ ] **Graceful Pod Shutdown Lifecycle**:
  - [ ] Does every Deployment pod specification include a preStop hook:
    ```yaml
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 5"]
    ```
  - [ ] Does the application handle `SIGTERM`, cease taking new traffic, finish existing requests, and shut down cleanly within `terminationGracePeriodSeconds` (e.g. 30s–60s)?
- [ ] **Readiness vs. Liveness Probe Disconnection**:
  - [ ] **Liveness Probe**: Configured to only test process internal responsiveness (HTTP endpoint returning 200 without checking external databases).
  - [ ] **Readiness Probe**: Configured to verify DB/queue reachability before allowing ingress traffic.
- [ ] **CPU Throttling & Memory Limits**:
  - [ ] Are container memory limits set with sufficient headroom above average consumption to prevent hard `OOMKilled` evictions?
  - [ ] Is CPU throttling monitored via `container_cpu_cfs_throttled_periods_total`?

---

## 7. Cloud Provider Specifics (AWS / GCP / Azure) (Part 51)

- [ ] **S3 / Blob Storage Lifecycle & Multipart Cleanup**:
  - [ ] Are S3 bucket lifecycle rules configured with `AbortIncompleteMultipartUpload` after 7 days to eliminate hidden storage costs from failed uploads?
- [ ] **IAM Permission Eventual Consistency**:
  - [ ] Do automation scripts account for 10–30s replication latency when creating IAM roles, policies, and service accounts before attempting to assume them?
- [ ] **API Rate Limit Handling**:
  - [ ] Are AWS/GCP SDK calls wrapped in retry interceptors handling `ThrottlingException`, `RequestLimitExceeded`, and `RateExceeded`?

---

## 8. Protocols & Transport Optimization (Part 52)

- [ ] **gRPC Load Balancing & L7 Proxies**:
  - [ ] Are gRPC client connections routed through L7 load balancers (Envoy, Traefik) or configured with client-side subchannel load balancing (`round_robin`), preventing all gRPC RPCs from pinning to a single server instance over a persistent HTTP/2 TCP connection?
- [ ] **WebSocket Connection Management**:
  - [ ] Are WebSocket connections configured with regular heartbeat/ping-pong frames (every 30s) to detect dead clients and terminate stale sockets?
- [ ] **TLS Handshake Resumption**:
  - [ ] Are TLS session tickets / session caching enabled to eliminate redundant asymmetric cryptographic handshake overhead on repeat connections?

---

## 9. Language & Runtime Traps (Part 53)

### Go Runtime
- [ ] **Goroutine Leak Audit**:
  - [ ] Does every spawned goroutine have a deterministic exit path bound to `ctx.Done()`?
  - [ ] Are unbuffered channels paired with non-blocking selects or guaranteed active readers?
- [ ] **Nil Interface Trap**:
  - [ ] Does code avoid returning a typed nil pointer as an `error` or `interface{}` value (which evaluates to non-nil interface)?
- [ ] **Defer in Loops**:
  - [ ] Are file closes and unlocks inside tight loops wrapped in anonymous functions to prevent deferred execution piling up until loop completion?

### Node.js / TypeScript Runtime
- [ ] **Event Loop Non-Blocking**:
  - [ ] Are CPU-heavy operations (large JSON parsing, image manipulation, crypto) offloaded to Worker Threads?
- [ ] **Unhandled Promise Rejections**:
  - [ ] Is `process.on('unhandledRejection', ...)` registered with structured logging and crash reporting?
- [ ] **Event Emitter Leak Prevention**:
  - [ ] Are event listeners properly unbound (`removeListener` / `AbortSignal`) when sockets or streams close?

### Python Runtime
- [ ] **GIL & Asyncio Event Loop Safety**:
  - [ ] Are CPU-bound routines dispatched to `concurrent.futures.ProcessPoolExecutor`, never blocking the asyncio event loop?
  - [ ] Are mutable default arguments (`def func(data={})`) eliminated and replaced with `data=None`?

### Java / JVM Runtime
- [ ] **GC Pause & Stop-The-World (STW) Limits**:
  - [ ] Are low-latency garbage collectors (ZGC, Shenandoah, or G1GC tuned) configured with max pause targets (`-XX:MaxGCPauseMillis=20`) to avoid distributed lease expiration?
- [ ] **Metaspace & Native Memory Leak Monitoring**:
  - [ ] Are JVM Metaspace and direct byte buffer allocations tracked with alerts before reaching max memory limits?

---

## 10. Principles 61–74 Operationalized (Part 58)

- [ ] Learn technology failure modes before adopting them and record them in a platform behavior sheet.
- [ ] Measure effective live runtime configuration, not static config files.
- [ ] Define "success" per architectural layer (accepted, persisted, replicated, visible).
- [ ] Match each tool to its primary guarantee (cache for speed, DB for invariants, index for search).
- [ ] Place automated alerts on every internal accumulator (XID age, consumer lag, dead tuples, burst balance).
- [ ] Retry in exactly one designated layer with a finite budget; disable retries elsewhere.
- [ ] Align end-to-end timeout budgets systematically across all service hops.
- [ ] Verify version-specific behavior in an isolated lab before production deployment.
- [ ] Explicitly define fail-open vs. fail-closed policies per component.
- [ ] Rehearse disaster recovery to "application healthy," not merely "process running."
- [ ] Prefer boring, well-understood configurations; treat deviations as owned exceptions.
- [ ] Pair design reviews with engineers who have operational experience with the chosen technology.
- [ ] Treat platform and runtime upgrades as behavior changes requiring thorough regression testing.
- [ ] Validate runtime types at language boundaries against empty, null, and hostile payloads.
