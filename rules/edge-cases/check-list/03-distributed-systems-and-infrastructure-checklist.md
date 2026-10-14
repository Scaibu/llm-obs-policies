# Checklist 03: Distributed Systems & Infrastructure Scale (Exhaustive Verification)

**Source Reference**: [Distributed Systems Edge Cases (Parts 18–28)](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/distributed-systems-edge-cases.md)  
**Scope**: Complete operational checklist across Distributed Locks, Fencing Tokens, Leader Election, Clock Drift, Distributed Sagas, Network Partitions, Ephemeral Port Exhaustion, EBS Burst Credits, Emergent Feedback Loops, Chaos Testing, Code Smells, and Principles 29–44.

---

## 1. Distributed Locking & Fencing Tokens (Part 18.1)

- [ ] **Mandatory Fencing Token Enforcement**:
  - [ ] Are all distributed locks (Redis, Postgres advisory locks, Consul, Zookeeper, etcd) coupled with a monotonically increasing fencing token generated on lock acquisition?
  - [ ] Does the downstream storage/data service check that incoming writes provide a fencing token strictly greater than the highest token previously processed:
    ```sql
    UPDATE storage_resource 
    SET state = :payload, last_fencing_token = :current_token 
    WHERE id = :resource_id AND last_fencing_token < :current_token;
    ```
  - [ ] If rows updated $= 0$, is the operation rejected as an expired/stale lease (preventing split-brain data corruption during long GC pauses, process freezes, or network stalls)?
- [ ] **Lease Time-To-Live (TTL) & Heartbeat Threads**:
  - [ ] Is lock TTL configured with significant margin over typical job duration ($> 3\times$ normal execution)?
  - [ ] Does an active background heartbeat thread continuously renew the lock lease during task execution?
  - [ ] If lease renewal fails or times out, does the worker task immediately abort execution and release resources?
- [ ] **Deterministic Lock Acquisition Ordering**:
  - [ ] When multiple distributed locks or database rows must be acquired, are they sorted in an absolute canonical order (e.g. sorted by UUID/ID) to eliminate circular deadlock conditions?

---

## 2. Consensus, Quorums & Leader Election (Parts 18.2, 18.3)

- [ ] **Strict Majority Quorums**:
  - [ ] Do cluster consensus decisions (Raft, Paxos, etcd) enforce strict majority quorum:
    $$Q = \left\lfloor \frac{N}{2} \right\rfloor + 1$$
  - [ ] Are cluster nodes configured with odd counts ($N=3, 5, 7$) to prevent tied split-brain states?
- [ ] **Leader Election & Split-Brain Mitigation**:
  - [ ] When a network partition occurs, does the isolated minority partition immediately relinquish leadership, stop serving writes, and reject mutations?
  - [ ] Is cluster membership reconfiguration executed using joint consensus / single-node transitions to prevent dual-leader states?

---

## 3. Clocks, Logical Ordering & Timers (Part 18.4)

- [ ] **Strict Use of Monotonic Clocks**:
  - [ ] Are all latency metrics, duration timers, timeouts, and rate limits calculated using monotonic clocks (`CLOCK_MONOTONIC`, `process.hrtime()`, `time.Now().Sub()`), never system wall clocks (`Date.now()`, `time.time()`)?
- [ ] **Clock Skew & NTP Tolerance**:
  - [ ] Are all servers synchronized via NTP/Chrony with automated alerts firing if clock offset exceeds $100\text{ms}$?
  - [ ] Is domain ordering decoupled from wall clocks, relying instead on monotonically increasing sequence numbers, database sequences, or Lamport/Hybrid Logical Clocks?

---

## 4. Network Partitions & Connection Lifecycles (Part 18.5)

- [ ] **Handling Half-Open Connections**:
  - [ ] Are TCP Keepalive parameters explicitly configured on all sockets:
    - `TCP_KEEPIDLE = 60` (start keepalives after 60s of inactivity)
    - `TCP_KEEPINTVL = 10` (send probe every 10s)
    - `TCP_KEEPCNT = 3` (drop connection after 3 unacknowledged probes)
  - [ ] Are HTTP/gRPC client and server idle timeouts aligned to prevent sending requests over half-open or gateway-terminated connections?
- [ ] **Circuit Breakers for Broken Network Paths**:
  - [ ] Do remote HTTP/gRPC clients wrap endpoints in circuit breakers (e.g. Netflix Hystrix/Resilience4j pattern) that trip when connection failure rates exceed 50% within a rolling window?

---

## 5. Distributed Sagas & Idempotency Engineering (Parts 18.6, 18.7)

- [ ] **Saga Step Categorization**:
  - [ ] **Compensatable Steps**: Every step before the pivot has a fully tested, automated compensating transaction (e.g. refunding reserved balance, cancelling reservation).
  - [ ] **Pivot Step**: The definitive step after which the transaction cannot be cancelled and must go forward (e.g. capturing payment).
  - [ ] **Retryable Steps**: Every step after the pivot is guaranteed to succeed eventually through idempotent retries (e.g. provisioning service, sending confirmation).
- [ ] **Idempotency Key Deduplication Engine**:
  - [ ] Are all mutative API endpoints (POST /payments, POST /orders) identified by unique, client-provided `Idempotency-Key` headers?
  - [ ] Is idempotency recorded atomically:
    ```sql
    INSERT INTO idempotency_records (key, response_status, response_body, expires_at)
    VALUES (:key, :status, :body, NOW() + INTERVAL '24 hours')
    ON CONFLICT (key) DO NOTHING;
    ```
  - [ ] If a matching idempotency record already exists, does the server immediately return the cached response without re-executing business logic?

---

## 6. Database Internal Traps & Storage Pressures (Part 19)

- [ ] **Foreign Key Cascades & Row Locking**:
  - [ ] Are foreign keys indexed on referencing columns to prevent full-table share locks on parent table updates/deletes?
- [ ] **Postgres Advisory Lock Scope**:
  - [ ] Are advisory locks explicitly scoped: `pg_advisory_xact_lock()` for transaction scope, or paired with guaranteed `pg_advisory_unlock()` inside `try/finally` blocks for session scope?
- [ ] **WAL & Checkpoint Saturation**:
  - [ ] Is PostgreSQL `max_wal_size` sized appropriately (e.g. 16GB–64GB) with `checkpoint_completion_target = 0.9` to prevent disk I/O write spikes during high write throughput?

---

## 7. Infrastructure Bottlenecks & Network Exhaustion (Part 21)

- [ ] **NAT Gateway & Ephemeral Port Limits**:
  - [ ] Are outbound HTTP/gRPC clients reusing persistent connection pools (Keep-Alive) to avoid exhausting OS ephemeral ports ($65,535$ limit) and triggering SNAT port exhaustion on cloud NAT gateways?
- [ ] **Cloud Storage IOPS & Burst Credits**:
  - [ ] Are cloud block storage volumes (e.g. AWS EBS gp2/gp3) monitored for Burst Balance exhaustion ($\text{Burst Balance} < 50\%$), with provisioned IOPS configured for high-write databases?
- [ ] **Load Balancer Algorithms**:
  - [ ] Are load balancers configured for **Least Outstanding Requests** or **Power of Two Random Choices (P2C)** rather than naive Round Robin for uneven or long-lived request streams?

---

## 8. Second-Order & Emergent Failure Defenses (Part 22)

- [ ] **Cache Invalidation Stampede Prevention**:
  - [ ] Are cache keys refreshed proactively using probabilistic early expiration (XFetch algorithm) or single-flight mutexes (Go `singleflight` / Redis lock)?
  - [ ] Do cache TTLs include randomized jitter (e.g. $\text{TTL} \pm 15\%$) to prevent synchronized mass expiration?
- [ ] **Autoscaling Oscillation (Flapping) Control**:
  - [ ] Are autoscalers configured with cooldown / stabilization windows (e.g. 5–10 mins cooldown before scaling in) to prevent oscillation during bursty traffic?
- [ ] **Health Check Thrashing Prevention**:
  - [ ] Do healthcheck probes require multiple consecutive failures (e.g. 3 consecutive failures over 30s) before marking an instance unhealthy, preventing transient blips from evicting entire server pools?

---

## 9. Methods for Exposing Unknown Unknowns (Part 23)

- [ ] **Chaos Fault Injection & Game Days**:
  - [ ] Are systems regularly tested in staging/pre-prod under simulated chaos:
    - Packet drops (20% latency/loss via `tc/netem`).
    - Sudden instance termination (`SIGKILL`).
    - Clock skew injections ($\pm 5\text{ seconds}$).
    - Database primary failover drills.
- [ ] **Shadow Traffic & Dark Launching**:
  - [ ] Are major architectural rewrites verified by replaying live production traffic asynchronously before cutting over?

---

## 10. Code Smells & Architectural Anti-Pattern Audit (Part 26)

- [ ] **Audit Checklist - Zero Tolerance for the Following Smells**:
  - [ ] **`sleep()` in Logic or Tests**: No hardcoded sleep intervals used for synchronization or waiting.
  - [ ] **Naked Retries**: No unbounded `while(true) { try { ... } catch { retry; } }` loops without backoff and finite budget.
  - [ ] **Unbounded Concurrency**: No naked `Promise.all(massiveList.map(...))` or spawning unbounded goroutines without semaphores.
  - [ ] **Swallowed Exceptions**: No empty `catch (e) {}` blocks that mask failures or return misleading empty arrays.
  - [ ] **Global In-Memory Maps**: No static dictionaries/maps caching objects without LRU eviction and memory bounds.

---

## 11. Principles 29–44 Operationalized (Part 28)

- [ ] Enforce fencing tokens on every distributed lease.
- [ ] Rely on quorum majorities for consensus decisions.
- [ ] Use monotonic clocks for elapsed time and timeouts.
- [ ] Propagate deadline budgets through every RPC hop.
- [ ] Apply exponential backoff with full randomized jitter to every retry.
- [ ] Ensure all state mutations support idempotent replay.
- [ ] Protect databases from connection starvation via connection poolers.
- [ ] Prevent cache stampedes with probabilistic refresh and jittered TTLs.
- [ ] Maintain backward and forward compatibility across schema versions.
- [ ] Reconcile state against independent authoritative logs.
- [ ] Test with the ugliest real-world datasets under simulated chaos.
- [ ] Question every framework default (isolation levels, timeouts, pool sizes).
- [ ] Make the safe operational path the default and the dangerous path hard.
- [ ] Document accepted risks with explicit owners and expiry dates.
- [ ] Assume understanding is partial and verify continuous health via production audits.
