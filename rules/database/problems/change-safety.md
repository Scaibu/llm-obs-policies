# Category 5: Change safety

**Problem statement:** The system must change (schema, data, config, code) while serving traffic. Old and new versions coexist during every rollout, changes take locks and generate load, and some changes destroy information. The failure is an outage or data loss caused by a change that looked routine.

**Subproblems:** 5A planning and compatibility. 5B executing changes on live data. 5C change control.

## 5A. Planning and compatibility

#### 5.1 "Schema design is a phase we finish before building" (was #2) [Certain]
- **Why wrong:** The schema encodes your day-one understanding of the business, which is the least informed you will ever be. The business changes, so a "finished" schema becomes a constraint.
- **What is correct:** The schema is a versioned contract that keeps evolving. Design effort belongs on irreversible choices, and reversible ones can stay light.
- **Problem it creates:** Over-design (speculative tables and columns) or fear of change (workarounds pile up in application code and old columns get repurposed).
- **First-principles fix:** Classify each decision by reversal cost. A nullable column is cheap. Keys, grain, tenancy, and partition key are expensive. Decide the expensive ones deliberately with written assumptions, decide the cheap ones just in time, and build the migration pipeline before the first table.
- **Meta:** Which decisions here would cost a project to reverse at 10x data? Which assumption would invalidate each?
- **Second-order:** Does a good migration pipeline tempt sloppiness on the expensive decisions? How do I stop reversible decisions from silently becoming irreversible as dependents accumulate?

#### 5.2 "Schema migration is a deployment step" (was #25) [Certain]
- **Why wrong:** On a live system a migration runs while old and new application versions coexist, takes locks, and generates load. It is a rollout, not a step.
- **What is correct:** Every change must be valid for the application version before it and the version after it.
- **Problem it creates:** Errors when old code meets new schema, and rollbacks that can't undo the change.
- **First-principles fix:** Use expand/contract. Add compatible structure, deploy code that handles both shapes, backfill, switch reads, stop writing the old structure, and remove it in a later release. Each step is independently reversible.
- **Meta:** Which application versions can run against each intermediate schema? What is the rollback at each step?
- **Second-order:** How long must the compatibility window stay open when releases are slow (mobile clients)? How do I verify old and new copies agree during dual writes?

#### 5.3 "Deploy the schema first, then the code, always" (was #77) [Likely]
- **Why wrong:** Direction matters. Additions go schema-first, removals go code-first, renames and type changes need several steps, and during rollout both code versions run.
- **What is correct:** Order is set by compatibility in both directions.
- **Problem it creates:** Errors in the rollout window, such as old code hitting a dropped column or new code hitting a missing one.
- **First-principles fix:** Build a compatibility matrix (code N and N+1 against schema S and S+1) and sequence steps so every live combination is valid. Keep additive and destructive changes in separate releases.
- **Meta:** Which versions run at the same time, including long-lived workers and cached clients?
- **Second-order:** How do I enforce the matrix in CI (test N against S+1)? What about consumers I don't deploy, such as partners reading my database?

#### 5.4 "Rollback means running the down migration" (was #75) [Certain]
- **Why wrong:** Data transformations and drops destroy information, and writes made after deploy may not be representable in the old schema.
- **What is correct:** Production rolls forward. Rollback ability is a design property (compatibility), not a script.
- **Problem it creates:** A down migration that loses data, or can't run because new data violates old constraints.
- **First-principles fix:** Make each step additive and compatible, keep the old structure until the new one is proven, gate behavior with feature flags, take a restore point before destructive steps, and rehearse the forward-fix path.
- **Meta:** After an hour of new writes, can old code still read everything? What exactly is lost if I revert?
- **Second-order:** Does keeping old structures around create permanent clutter? Who owns the final contract step?

## 5B. Executing changes on live data

#### 5.5 "Adding a column is a safe, quick migration" (was #74) [Likely]
- **Why wrong:** Some changes rewrite the table (engine and version dependent). Even instant ones need a brief exclusive lock that queues behind any long transaction, and every later query then queues behind the waiting lock.
- **What is correct:** The danger is the lock queue, not the operation's duration.
- **Problem it creates:** A full traffic stall from a "trivial" DDL on a busy table.
- **First-principles fix:** Treat DDL as lock acquisition. Set a low lock_timeout, check for long transactions first, retry with backoff, run in low traffic, use online variants (CREATE INDEX CONCURRENTLY, online schema-change tools), and test on production-sized data under concurrent load.
- **Meta:** Which transactions may be open when this runs? What lock level does this statement need in my version?
- **Second-order:** Does repeated lock timeout leave migrations half-applied? Do failed concurrent builds leave invalid indexes that need cleanup?

#### 5.6 "A backfill is just an UPDATE" (was #76) [Certain]
- **Why wrong:** One giant statement holds locks, produces huge WAL/binlog, lags replicas, bloats storage, and can't resume after failure.
- **What is correct:** A backfill is a production workload and must be throttled, resumable, and idempotent.
- **Problem it creates:** Replica lag, lock pile-ups, bloat, and half-done runs.
- **First-principles fix:** Process in primary-key-ordered batches with a commit per batch, use an idempotent predicate (WHERE new_col IS NULL), track a cursor, throttle on replica lag and load, then verify counts and sample correctness.
- **Meta:** Can I kill it at any point and resume? How do I know it finished correctly?
- **Second-order:** Do rows written during the backfill get missed? Does batching leave vacuum and bloat work behind afterward?

#### 5.7 "Column defaults are harmless" (was #78) [Likely]
- **Why wrong:** A default turns "the writer forgot" into valid-looking data. On some engines and versions, adding a default or NOT NULL rewrites or scans the table.
- **What is correct:** A default is a business statement ("absent means X") and is valid only if X is true.
- **Problem it creates:** Wrong data indistinguishable from real data, skewed analytics, hidden bugs.
- **First-principles fix:** Add a default only when it's a real domain fact. Otherwise use NOT NULL with no default so writers must be explicit. For migrations, add the column nullable, backfill, then add the constraint (NOT VALID then VALIDATE where supported).
- **Meta:** If a writer omits this field, is the default actually correct? Can I tell defaulted values from supplied ones?
- **Second-order:** Does removing a default break old writers mid-rollout? Do ORM defaults and database defaults disagree?

## 5C. Change control

#### 5.8 "Generated migrations are safe" (was #79) [Certain]
- **Why wrong:** Tools infer intent from diffs (a rename looks like drop-and-add) and don't know table sizes, lock levels, or traffic.
- **What is correct:** Generated SQL is a draft, and its safety depends on context the tool lacks.
- **Problem it creates:** Data loss on renames, blocking index builds, long locks, type rewrites.
- **First-principles fix:** Review the actual SQL, lint with migration-safety tools (squawk, strong_migrations, or similar), require explicit handling of rename, type change, and drop, run against a production-sized copy, and gate it in CI.
- **Meta:** What statements does this generate, and what lock does each take? Does anything drop data?
- **Second-order:** Does the gate slow teams enough that they bypass it? Does the schema in code still match production after manual fixes (drift)?

#### 5.9 "Config and flag changes are safe any time" (was #89) [Certain]
- **Why wrong:** Config changes alter system-wide behavior instantly, often with no review, tests, or staged rollout.
- **What is correct:** Config is code with a faster, less supervised deployment path.
- **Problem it creates:** Outages from a flag flip, timeout change, or limit change, with no record of who changed what.
- **First-principles fix:** Version and review config, roll it out in stages (canary, percentage), validate automatically, make revert instant, keep an audit log, and give every flag an owner and a removal date.
- **Meta:** What is the blast radius if this value is wrong? Can I revert without a deploy?
- **Second-order:** Do flag combinations create untested states? Who removes dead flags?

---

