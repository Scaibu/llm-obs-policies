# Category 9: Distributed consistency and service boundaries

**Problem statement:** Once state or logic is split across processes, services, or regions, no single component can observe or atomically change everything. You must decide, per invariant, what consistency is needed, where the atomicity boundary sits, and how components communicate under partial failure, delay, duplication, and reordering. Failure here means invariants silently violated across boundaries, and "independent" services that fail together.

**Subproblems:** 9A choosing a consistency model. 9B boundaries and ownership. 9C communication and failure semantics. 9D event-driven systems.

## 9A. Consistency model

#### 9.1 "CAP says pick two, so eventual consistency is a fine default" (was #12) [Likely]
- **Why wrong:** CAP speaks only to behavior during a partition and uses a narrow definition of consistency (linearizability). In normal operation the real tradeoff is latency versus consistency, and consistency is a spectrum. Declaring a whole system "eventually consistent" avoids the decision.
- **What is correct:** Consistency is chosen per invariant, with a price attached.
- **Problem it creates:** You either overpay (strong everywhere) or get incidents where weak consistency touched money, inventory, uniqueness, or permissions.
- **First-principles fix:** List the invariants and classify each: must never be violated even briefly, may be violated briefly then repaired, or irrelevant. Give the first class strong guarantees inside one atomicity boundary (serializable, single leader). Give the second class bounded staleness or read-your-writes plus a repair mechanism.
- **Meta:** What does a violated invariant cost if it lasts 5 seconds? Who can observe the violation?
- **Second-order:** Can a weakly consistent read feed a decision that needs strong consistency? (It usually can, and that's the leak.) Do two consistency regimes mean two code paths to test?

#### 9.2 "Eventual consistency converges by itself" (was #90) [Likely]
- **Why wrong:** Convergence needs two things: every update eventually reaching every replica, and a deterministic merge rule. Without a merge rule, replicas stay different, and last-write-wins "converges" while silently discarding data.
- **What is correct:** Convergence is a designed property of the delivery guarantee plus the merge function.
- **Problem it creates:** Divergent replicas that nobody detects, and lost updates that look like normal operation.
- **First-principles fix:** Choose merge semantics per field: single-writer ownership, CRDTs, version vectors, or domain rules (for example "max", "union"). Add anti-entropy (periodic comparison via checksums or Merkle trees) and alert on divergence.
- **Meta:** What happens when two replicas accept conflicting updates? Who or what decides the winner?
- **Second-order:** Can reconciliation overwrite newer data with older? Deletes need tombstones, and garbage-collecting tombstones too early resurrects deleted data.

## 9B. Boundaries and ownership

#### 9.3 "Microservices should each own their database, always" (was #15) [Likely]
- **Why wrong:** Database-per-service follows from an ownership boundary, so it isn't a rule. Applied by default it splits invariants across services (no shared transaction), removes joins, complicates reporting, and produces a distributed monolith.
- **What is correct:** Boundaries follow invariants and rate of change. A modular monolith with per-module schema ownership is a legitimate boundary.
- **Problem it creates:** Cross-service invariants with no enforcement, chatty calls on hot paths, lockstep deployments, duplicated data.
- **First-principles fix:** Map invariants to the sets of entities that must change atomically, and put each set in one boundary. Count cross-boundary calls on the hottest paths. Split only for independent scaling, availability, team ownership, or compliance, and provide cross-boundary reads through APIs, events, or replicated read models.
- **Meta:** Which services must always deploy together? Which invariants cross my current boundaries?
- **Second-order:** Reporting now needs a data platform. Contracts must stay versioned forever, and ownership disputes over shared concepts (customer, product) appear.

#### 9.4 "Use distributed transactions or sagas to keep services consistent" (was #14) [Likely]
- **Why wrong:** Two-phase commit couples availability to the coordinator and holds locks across participants. Sagas have no isolation (others see half-finished states), and compensations can fail or be impossible (an email already sent, goods already shipped).
- **What is correct:** Avoid needing cross-boundary atomicity. Where you can't, make intermediate states first-class.
- **Problem it creates:** Stuck sagas, exposed partial state, double or failed compensation.
- **First-principles fix:** First redraw boundaries (9.3) so the invariant is local. Otherwise model explicit states (pending, confirmed, cancelled), use reservation patterns (try-confirm-cancel) with expiry, make every step and compensation idempotent, add timeouts with a sweeper, and surface stuck sagas to a human-visible queue.
- **Meta:** Which step can't be compensated? What does another reader see mid-saga?
- **Second-order:** Reservation expiry races with confirmation, compensation order matters, and long-running sagas need observability of their own.

#### 9.5 "Event sourcing and CQRS are the advanced, correct design" (was #16) [Likely]
- **Why wrong:** They cost permanent event-schema evolution, projection rebuild time, eventual consistency between command and query sides, harder debugging, and trouble with erasure on immutable logs.
- **What is correct:** Default to current state plus an append-only history. Use event sourcing where the sequence of facts is itself the asset.
- **Problem it creates:** Complexity that exceeds the benefit, read-your-writes failures, projections that can't be rebuilt in time.
- **First-principles fix:** Ask which questions require full history ("state at time T", audit, undo). If only audit is needed, use a history table. If you do adopt it, use versioned events with upcasters, snapshots, a timed rebuild drill, and per-subject encryption keys for erasure.
- **Meta:** Which question can I answer only with the complete event history? How long does a full replay take?
- **Second-order:** Event schemas live forever, projections multiply, and privacy deletion on immutable events needs crypto-shredding.

#### 9.6 "The API can expose our ORM model directly" (was #86) [Likely]
- **Why wrong:** It welds clients to storage, so schema changes become breaking changes. Client-controlled shapes can trigger N+1 or unbounded queries, internal fields leak, and authorization attaches to entities instead of use cases.
- **What is correct:** An API is a contract with its own lifecycle and cost model.
- **Problem it creates:** Schema that can't change, overload from client queries, accidental data exposure.
- **First-principles fix:** Put an explicit contract layer between storage and clients. Add pagination with hard maximums, a cost budget per request (depth and complexity limits for GraphQL), a versioning and deprecation policy, field-level authorization, and contract tests.
- **Meta:** Which internal schema change would break a client today? Can a client construct an expensive query?
- **Second-order:** The mapping layer needs maintenance, old versions must be supported, and deprecations need enforcement.

## 9C. Communication and failure semantics

#### 9.7 "The network is reliable and fast inside our data center" (was #81) [Certain]
- **Why wrong:** Packet loss, retransmits, gray failures (slow rather than dead), GC and VM pauses, and tail latency are normal. With fan-out, rare tail events become frequent: a request touching 50 services hits a slow one most of the time.
- **What is correct:** Every remote call has unbounded latency and an ambiguous outcome.
- **Problem it creates:** Stuck threads and connections, cascading latency, writes whose result is unknown.
- **First-principles fix:** A propagated deadline on every call, separate pools per dependency (bulkheads), hedged requests for idempotent reads, per-dependency degradation modes, and treating a timeout on a write as "unknown," which needs idempotency and reconciliation.
- **Meta:** What happens when this dependency takes 30 seconds? Which calls are critical-path versus optional?
- **Second-order:** Hedging adds load, fallback paths go untested until an incident, and degraded modes need chaos testing.

#### 9.8 "Redundancy removes single points of failure" (was #83) [Likely]
- **Why wrong:** Redundant components share failure causes: the same deploy, config, library bug, AZ, DNS, certificate expiry, auth provider, or traffic surge.
- **What is correct:** Redundancy helps against independent failures, and correlated failures need isolation.
- **Problem it creates:** N+1 systems that are fully down because all replicas fail together.
- **First-principles fix:** Enumerate shared dependencies and failure domains (deploy pipeline, config store, DNS, auth, clocks, certificates, region). Use cells or shards with bounded blast radius, staged rollouts with automatic rollback, and fail-static behavior (keep serving last known good config when the control plane dies).
- **Meta:** Which single change can reach all replicas at once? What does every copy depend on?
- **Second-order:** Cells raise cost and routing complexity, and staged rollouts slow urgent fixes.

## 9D. Event-driven systems

#### 9.9 "Kafka (or any log) is our database" (was #84) [Likely]
- **Why wrong:** Logs have retention and compaction semantics, no ad-hoc queries, ordering only within a partition, and replay costs that grow with history.
- **What is correct:** A log is transport and history, and current state needs a queryable store.
- **Problem it creates:** Data lost at retention expiry, no way to ask "what is X's state now" without replay.
- **First-principles fix:** Name the system of record. If the log is the record, set retention and compaction deliberately, use a schema registry, take snapshots, and drill rebuilds. Keep read models rebuildable.
- **Meta:** What happens when retention expires? Can I answer "current state of X" without replaying?
- **Second-order:** Compaction deletes history, infinite retention costs money, and replay can overload downstream systems.

#### 9.10 "Our event stream guarantees ordering" (was #85) [Certain]
- **Why wrong:** Order exists per partition only, and only if producers retry safely and consumers process serially per key. Parallel consumers, retries, cross-topic flows, and repartitioning all reorder effects.
- **What is correct:** Order is defined per key and preserved only if both ends are built for it.
- **Problem it creates:** Stale updates overwrite newer state, and deletes arrive before creates.
- **First-principles fix:** Identify the entity whose events must be ordered and partition by its ID. Use idempotent producers, process each key serially in consumers, and put a version or sequence number on every event so consumers drop stale ones or buffer gaps. Avoid depending on cross-key order.
- **Meta:** Which invariant needs ordering, over which key? What happens if two events for one key are processed in parallel?
- **Second-order:** Hot keys serialize throughput, repartitioning remaps keys, and a gap in sequence numbers needs a policy (wait, skip, alert).

---
