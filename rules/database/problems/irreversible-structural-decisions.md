# Category 2: Irreversible structural decisions

**Problem statement:** Some decisions are baked into identity, physical layout, or value semantics. Reversing them costs more with every row and every dependent. The failure is not a bug but a lock-in: the system works until growth, a new region, or a new requirement makes the old choice impossible to change cheaply.

**Subproblems:** 2A identity and keys. 2B data placement. 2C value semantics.

## 2A. Identity and keys

#### 2.1 "Choosing IDs is a small detail" (was #17) 
- **Why wrong:** ID type and generation decide index locality, insert throughput, shardability, multi-writer merging, enumeration risk, and ordering semantics, and every foreign key and API copies them.
- **What is correct:** The ID is the system's identity contract.
- **Problem it creates:** Fragmented indexes (random UUIDv4 on clustered keys), 32-bit overflow, impossible merges, leaked volume through sequential public IDs.
- **First-principles fix:** Derive requirements: who generates IDs (one node or many), whether time-ordering matters, expected cardinality (64-bit minimum), and exposure outside the system. Then use time-ordered 64-bit IDs or UUIDv7/ULID-style IDs, with a separate opaque public ID if exposure matters.
- **Meta:** How many entities in ten years, from how many writers? Does anything assume ID order equals time order?
- **Second-order:** Do time-ordered IDs create a hot right edge at scale? Does an embedded timestamp leak information?

#### 2.2 "Every table needs an auto-increment id" (was #32) 
- **Why wrong:** An association table already has a natural composite key. A surrogate adds an index and a meaningless identity, and a central sequence is a contention and merge hazard.
- **What is correct:** A key represents the identity of the fact, and a pure relationship's identity is the pair it relates.
- **Problem it creates:** Duplicate association rows if the real key isn't constrained, an extra index, merge collisions.
- **First-principles fix:** Ask what makes two rows "the same fact" and make that the primary key (composite for associations). Add a surrogate only when the row is referenced elsewhere or has its own lifecycle.
- **Meta:** What uniquely identifies this fact in the real world? Who references this row?
- **Second-order:** Do wide composite keys bloat every referencing index? Will the definition of identity change (for example allowing repeated relationships over time)?

#### 2.3 "Email, username, or phone is a unique identifier" (was #39) 
- **Why wrong:** These attributes change, are shared or recycled, and have normalization variants (case, Unicode, plus-addressing).
- **What is correct:** Identity is separate from the attributes used for lookup or login.
- **Problem it creates:** Account takeover on recycled addresses, duplicate accounts, painful change flows.
- **First-principles fix:** Use an immutable surrogate identity. Put a unique constraint on a normalized form with a defined normalization function, store attribute history, and verify ownership on change.
- **Meta:** What happens when the owner changes the attribute or loses it? Who else can legitimately own it later?
- **Second-order:** If the normalization rule changes, how do I rewrite uniqueness data? How do I handle collisions discovered afterward?

## 2B. Data placement

#### 2.4 "Sharding solves scale" (was #8) 
- **Why wrong:** It addresses single-node write and size limits, and introduces cross-shard queries and transactions, hot shards, resharding, and multiplied operations.
- **What is correct:** Sharding is a last-resort split of the consistency domain, justified only when one node can't carry the write load.
- **Problem it creates:** Many requests become scatter-gather, invariants spanning shards can't be enforced transactionally, and operations cost multiplies.
- **First-principles fix:** Compute the real limit (write IOPS, working set, storage) and exhaust cheaper levers first. If sharding is required, pick the key so each request and each invariant lives in one shard (tenant, account), and model cross-shard flows as explicit sagas.
- **Meta:** Which resource is exhausted, with numbers? Which invariants cross the proposed key?
- **Second-order:** How do I rebalance when one tenant outgrows a shard? Which reports now need a separate analytical store?

#### 2.5 "Shard with user_id % N" (was #70) 
- **Why wrong:** Changing N remaps nearly every key, so growth forces mass data movement, and skew still creates hot shards.
- **What is correct:** Placement needs a stable key-to-bucket mapping and a separate, changeable bucket-to-node mapping.
- **Problem it creates:** Every resharding becomes a high-risk migration.
- **First-principles fix:** Hash keys into a large fixed number of logical buckets (thousands), keep a directory mapping buckets to nodes, and rebalance by moving whole buckets.
- **Meta:** How will I add the 10th node, and what moves? How big is the largest bucket relative to a node?
- **Second-order:** Where does the directory live, and how do clients cache it safely? How do I move a bucket that is taking writes?

#### 2.6 "Partitioning always improves performance" (was #69) 
- **Why wrong:** Partitioning helps through pruning and cheap bulk drops. Queries without the partition key touch every partition, and unique constraints must include the partition key.
- **What is correct:** Partitioning is a physical layout aligned to data lifecycle and the dominant filter.
- **Problem it creates:** Slower queries, planning overhead with thousands of partitions, constraints you can't enforce globally.
- **First-principles fix:** Identify the dominant filter and the retention rule, partition on that, confirm pruning in plans, keep partition counts moderate, and enforce global uniqueness separately if needed.
- **Meta:** What fraction of queries include the partition key? How does data leave the table?
- **Second-order:** How are partitions created and dropped automatically? What happens when a new access pattern ignores the key?

#### 2.7 "Multi-tenancy has one right model" (was #88) 
- **Why wrong:** Tenants differ by orders of magnitude in size, risk, and compliance needs, so no single isolation model fits them all.
- **What is correct:** Isolation is a per-tenant-class decision behind a routing layer.
- **Problem it creates:** Noisy neighbors, impossible per-tenant restores, or the operational burden of thousands of databases.
- **First-principles fix:** Classify tenants by size and regulatory need. Use a shared schema with the tenant key everywhere for the small majority, and isolated schemas or databases for large or regulated ones. Run one tenant-aware router, backup, and migration process.
- **Meta:** What share of load does the largest tenant carry? Which tenant could demand data residency or restore-on-request?
- **Second-order:** How do I move a tenant from shared to isolated without downtime? Do migrations now run against N targets?

## 2C. Value semantics

#### 2.8 "Store timestamps the way users see them" (was #34) 
- **Why wrong:** Local time is ambiguous at DST transitions, and governments change zone rules, so stored local times can't be converted back reliably.
- **What is correct:** An instant that happened, a promise about local time, and a calendar date are three different data types.
- **Problem it creates:** Off-by-an-hour events at DST changes, wrong schedules after zone-rule updates.
- **First-principles fix:** Model each time field by meaning. Use occurred-at as a UTC instant, scheduled-for as local datetime plus zone ID resolved at execution, and date-only as a date with no time.
- **Meta:** Is this a moment that happened or a promise about a local clock? Which timezone defines "the day" for reporting?
- **Second-order:** How do I query by the user's local day efficiently? How do I handle timezone-database updates for already-stored future events?

#### 2.9 "Money is just a decimal column" (was #36) 
- **Why wrong:** Currency, rounding rules, tax inclusion, FX at transaction time, and corrections all matter, and a mutable balance destroys the audit trail.
- **What is correct:** Money state is a derivation of an immutable log of financial facts.
- **Problem it creates:** Balances you can't explain, rounding drift, corrections that overwrite history.
- **First-principles fix:** Store integer minor units plus a currency code, and record each movement as an immutable entry (double-entry: debits equal credits). Compute balances from entries with periodic snapshots, and make corrections new entries.
- **Meta:** Can I reproduce any historical balance and explain each change? Which rounding rule does each jurisdiction require?
- **Second-order:** How do I keep balances fast without a materialized balance becoming a second source of truth? How do I handle late-arriving corrections?

#### 2.10 "Collation and case sensitivity are cosmetic" (was #40) 
- **Why wrong:** Collation defines equality and order inside the index, and library changes can alter it.
- **What is correct:** Collation is part of the index's definition of "same."
- **Problem it creates:** Near-duplicates differing by case or accents, joins that can't use indexes, and in PostgreSQL, silently inconsistent indexes after a glibc or ICU upgrade [Likely on version specifics].
- **First-principles fix:** Decide per field what "same" means (exact, case-insensitive, accent-insensitive). Implement it with an explicit collation or a normalized column, pin library versions, reindex after upgrades, and run index-integrity checks.
- **Meta:** What should equality mean for this field in the business? Which other systems compare against it?
- **Second-order:** What happens to existing data when I change the rule? Do search and cache keys normalize the same way?

---
