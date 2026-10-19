

# Category 8: Scale strategy

**Problem statement:** Load and data volume grow, and you must decide what to distribute, cache, and replicate with the smallest amount of irreversible complexity. The failure is paying for scale you never need, or hitting a hard ceiling with no plan.

**Subproblems:** 8A when and what to scale. 8B choosing the store. 8C copies of data (cache, replicas, specialized stores).

## 8A. When and what to scale

#### 8.1 "At scale we need distributed databases, so design for that from the start" (was #6) 
- **Why wrong:** Most systems never reach the limits of a well-tuned single node, and early distribution costs complexity and weakens guarantees.
- **What is correct:** Scale in stages guided by measured bottlenecks.
- **Problem it creates:** Slower development, harder debugging, and weaker invariants for hypothetical load.
- **First-principles fix:** Measure current load and the headroom of one node. Keep the model shardable (a tenant or entity key on every table) without sharding. Define metric thresholds that trigger each next stage.
- **Meta:** Which resource limit will I hit first, and at what load? What number triggers the next step?
- **Second-order:** Is the shardable key actually present in every table? Does delaying make a later migration harder?

#### 8.2 "Horizontal scaling is always better than vertical" (was #9) 
- **Why wrong:** Horizontal wins at the ceiling. Below it, vertical is simpler and cheaper in engineering time.
- **What is correct:** Scale up until cost, failure domain, or a hard limit demands scaling out.
- **Problem it creates:** Premature distribution complexity, or hitting the ceiling with no plan.
- **First-principles fix:** Know the largest available instance and the cost per step. Scale up with replication for availability, define the ceiling, and plan the horizontal step before you reach roughly 60-70% of it [Guessing on the exact threshold, so choose your own from measured growth].
- **Meta:** How far is current load from the largest instance?
- **Second-order:** What is the resize procedure and downtime? A single node is a single failure domain, and licensing costs may change with size.

#### 8.3 "NoSQL scales, SQL doesn't" (was #7) 
- **Why wrong:** Scalability comes from the data model and access pattern (partitionability). NoSQL stores achieve it by removing cross-partition capabilities.
- **What is correct:** Choose the store by access patterns and invariants.
- **Problem it creates:** Application code reimplements joins and consistency, and query changes become expensive.
- **First-principles fix:** List access patterns and invariants. If every query is single-key or single-partition and invariants are local, a partitioned key-value or wide-column store fits. If you need ad-hoc queries or multi-entity invariants, use relational or distributed SQL.
- **Meta:** How often do queries change? Which invariants span entities?
- **Second-order:** What does migrating between stores cost? What operational skill does the team have? How do secondary indexes behave in the new store?

## 8B. Choosing the store

#### 8.4 "Use the best database for each job" (was #19b) 
- **Why wrong:** Each additional store adds operational burden, failure modes, expertise needs, and a synchronization problem.
- **What is correct:** There is one system of record, and the others are derived, rebuildable projections.
- **Problem it creates:** Inconsistent copies, several sources of truth, and complex incident response.
- **First-principles fix:** Default to one general-purpose relational database. Add a specialized store only for a measured need, feed it via CDC or an outbox, make sure it can be rebuilt from the source, and document ownership.
- **Meta:** Which store is the source of truth for each fact? Can I rebuild every derived store from scratch, and how long would it take?
- **Second-order:** Lag between source and derived store becomes visible to users, rebuilds cost time and money, and schemas drift.

## 8C. Copies of data

#### 8.5 "Caching is a performance feature" (was #10) 
- **Why wrong:** A cache is a second copy with its own consistency, invalidation, stampede, and cold-start behavior, and it can hide slow queries.
- **What is correct:** A cache is derived data with an explicit staleness contract.
- **Problem it creates:** Stale reads, thundering herds, and outages when the cache is cold.
- **First-principles fix:** Fix the query first. Then cache only read-heavy data with defined staleness tolerance, set TTL and invalidation (event-driven where correctness matters), add request coalescing against stampedes, and load-test the cold-cache case.
- **Meta:** What happens if the cache is empty? How stale may this data be?
- **Second-order:** Cache-key design couples to write paths, and memory sizing and eviction change which data stays hot.

#### 8.6 "Read replicas scale reads transparently" (was #11) 
- **Why wrong:** Replicas lag, so reads can return old data. They scale reads only, they inherit the same bad queries, and lag grows under load.
- **What is correct:** A replica read is a view of the past.
- **Problem it creates:** Read-your-writes violations, stale decisions, and lag-driven errors.
- **First-principles fix:** Classify reads by freshness need. Route freshness-critical reads to the primary, or use LSN-aware or session-pinned reads. Monitor lag with a routing fallback, and keep any read that precedes a write decision on the primary.
- **Meta:** Which reads feed decisions that cause writes? What staleness is acceptable for each read?
- **Second-order:** Routing logic adds complexity, and falling back to the primary during replica lag can overload it.

---
