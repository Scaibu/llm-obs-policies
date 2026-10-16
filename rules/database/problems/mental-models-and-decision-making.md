
# Category 12: Mental models and decision-making

**Problem statement:** Many technical failures originate in how decisions are made: unstated assumptions, rules applied outside their conditions, costs pushed into the future, and knowledge lost over time. Failure here means a system whose designers can't explain why it is shaped this way or when that shape stops being valid.

**Subproblems:** 12A framing the system. 12B tradeoffs over time. 12C institutional memory.

## 12A. Framing the system

#### 12.1 "The database is where we store data" (was #1) [Certain]
- **Why wrong:** Storage is incidental. The database arbitrates concurrent state change, enforces invariants, orders durable writes, and plans queries.
- **What is correct:** The database is the arbiter of shared mutable state.
- **Problem it creates:** Invariants enforced only by application code, which fail under races, bugs, multiple writers, and manual scripts.
- **First-principles fix:** For each invariant, write the statement, the enforcing mechanism (unique, check, FK, exclusion constraint, transaction, lock), and what bypasses it. Push every enforceable invariant down into the database, and restrict who can write directly.
- **Meta:** Which invariants would survive a buggy or malicious writer? Which exist only by convention?
- **Second-order:** Constraint violations need clean error handling in the application, cross-row invariants may need serializable isolation or triggers, and adding constraints to already-dirty data requires cleanup first.

#### 12.2 "The ORM abstracts the database away" (was #5) [Certain]
- **Why wrong:** It leaks through N+1 queries, lazy loading, implicit transactions, generated SQL, locking behavior, and migrations.
- **What is correct:** An ORM is a SQL generator, and the database's behavior stays the real interface.
- **Problem it creates:** Hidden query patterns, surprise transactions and locks, performance cliffs.
- **First-principles fix:** Capture SQL per request in development and CI, set query-count budgets per endpoint and fail tests on N+1, use explicit eager loading, write raw SQL for hot or complex paths, understand where the ORM opens and flushes transactions, and review generated migrations (5.8).
- **Meta:** How many queries does this endpoint run, and what are they? Where does the ORM start and end transactions?
- **Second-order:** Hand-written SQL bypasses ORM caches and hooks, query-count tests can be brittle, and the team needs SQL skill.

#### 12.3 "Best practices are universal" (was #29) [Certain]
- **Why wrong:** Each practice was extracted from a context (scale, workload, era, team size).
- **What is correct:** A practice is a conclusion with premises.
- **Problem it creates:** Cargo-culting, such as microservices for a five-person team or sharding at 50 GB.
- **First-principles fix:** For every adopted practice, write its premise ("assumes X"), check whether X holds here, and set a trigger to revisit. Prefer principles (invariants, reversibility, failure model) over named patterns.
- **Meta:** Under what conditions was this practice right where it came from? Which don't hold for us?
- **Second-order:** Re-examining everything is expensive, so prioritize premises that are costly to be wrong about.

## 12B. Tradeoffs over time

#### 12.4 "Design for 100x scale now" (was #28) [Likely]
- **Why wrong:** You are guessing future load. The complexity cost is certain and immediate, it usually targets the wrong bottleneck, and growth changes the product.
- **What is correct:** Design for roughly 10x, keep the number of one-way doors small, and have a trigger plan for the next order of magnitude.
- **Problem it creates:** Slow delivery, over-engineering, a design shaped for a workload that never arrives.
- **First-principles fix:** List the one-way doors (keys, tenancy, partition key, consistency model) and decide those carefully for the horizon you can reason about. For the rest, define metric thresholds and sketch the migration, then revisit with real growth data.
- **Meta:** Which decisions can't be undone cheaply? What number triggers the next stage?
- **Second-order:** Growth may be non-uniform, "10x" can harden into dogma, and migration sketches rot.

#### 12.5 "We might switch databases someday, so abstract it" (was #27) [Certain]
- **Why wrong:** Real database migrations are rare and are rewrites anyway. Abstraction forces the lowest common denominator, and portability is illusory because isolation, locking, types, and SQL dialects differ.
- **What is correct:** Use your engine fully and isolate at module boundaries, so a replacement means rewriting an adapter, not pretending equivalence.
- **Problem it creates:** Lost engine features (partial indexes, JSONB, advisory locks), an abstraction tax, and no real portability.
- **First-principles fix:** Choose the engine for its capabilities with eyes open, keep SQL in a bounded data-access layer per module, don't leak engine-specific types across module boundaries, and write down what a migration would actually require.
- **Meta:** Which engine features do I deliberately depend on? What would migration cost, honestly?
- **Second-order:** Lock-in grows silently as features accumulate, and vendor pricing leverage shifts to the vendor.

#### 12.6 "More data is always an asset, so keep everything" (was #26) [Likely]
- **Why wrong:** Data has carrying costs: storage, backup and restore time, query slowdown, security exposure, legal liability. Its value decays.
- **What is correct:** Data has a lifecycle, and retention is a design input.
- **Problem it creates:** Growing tables, restore times that breach RTO, larger breach impact, compliance violations.
- **First-principles fix:** Classify datasets by purpose, value over time, and legal minimum and maximum retention. Define hot, warm, cold, and delete tiers, partition so expiry is a cheap partition drop, archive in cheaper formats, automate it, and track storage by class.
- **Meta:** Which decision does this data support, and for how long? What would a breach of it cost?
- **Second-order:** Deleted data can't serve future analytics, archive retrieval needs testing, and legal holds override retention.

#### 12.7 "Cost optimization can wait" (was #100) [Likely]
- **Why wrong:** Architecture sets unit cost: cross-AZ or cross-region transfer, provisioned IOPS, over-indexing, retention, scan-heavy queries, and the number of data copies.
- **What is correct:** Cost per unit of work is a design-time metric like latency.
- **Problem it creates:** Expensive designs that are hard to unwind, surprise bills, and cost cuts forced under pressure that damage reliability.
- **First-principles fix:** Estimate cost per transaction or per tenant at design time, tag resources, track cost per feature, review top cost drivers monthly, include cost in each ADR, and alert on cost anomalies.
- **Meta:** What does one request cost end to end? Which design choice drives most of it?
- **Second-order:** Cost cuts can remove redundancy or headroom, and chargeback can distort team behavior.

## 12C. Institutional memory

#### 12.8 "The team will remember why we decided this" (was #101) [Certain]
- **Why wrong:** People leave, context fades, and decisions outlive the assumptions that justified them.
- **What is correct:** A decision needs its assumptions and invalidation triggers recorded.
- **Problem it creates:** Constraints nobody understands, which leads either to cargo-culting them or to removing them recklessly, and to assumptions that rot until an incident reveals them.
- **First-principles fix:** An ADR template with context, decision, alternatives considered, assumptions (with numbers), the metric or event that would invalidate each, an owner, and a review date. Keep a per-system assumptions register linked to monitors, and review it in postmortems and quarterly.
- **Meta:** Which assumption would hurt most if false? What metric would tell me?
- **Second-order:** ADRs go stale, too many low-value ADRs bury the important ones, and the process must stay light enough to be used.

---
