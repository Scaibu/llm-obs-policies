
# Category 7: Data modeling and integrity

**Problem statement:** Business facts must be represented so that invariants are enforceable by the database, history is preserved where needed, and the required questions are answerable. The failure is data that is wrong but valid-looking, found months later.

**Subproblems:** 7A decomposition (what is a table). 7B lifecycle and deletion. 7C structure versus flexibility. 7D derived and duplicated data.

## 7A. Decomposition

#### 7.1 "The model should mirror the real world: one entity, one table" (was #4) [Likely]
- **Why wrong:** Real-world objects play several roles with different lifecycles and invariants, and mapping nouns to tables merges conflicting concerns.
- **What is correct:** Tables are drawn along invariants, change patterns, and access patterns.
- **Problem it creates:** God tables, columns that are nullable by role, awkward constraints.
- **First-principles fix:** Identify aggregates by asking what must change atomically. Separate roles and lifecycles into their own tables (party, role, account), and keep optional attributes in one-to-one extension tables with their own constraints.
- **Meta:** Which attributes change together? Which invariants span them?
- **Second-order:** More tables mean more joins, so I need views or an API layer to present the unified entity.

#### 7.2 "One wide table with every attribute is simple" (was #41) [Likely]
- **Why wrong:** Wide rows mean fewer rows per page and colder caches, and hot and cold columns share row churn. Large values add overhead.
- **What is correct:** Physical rows should group columns by access and update pattern.
- **Problem it creates:** Bloat, slow scans, write amplification.
- **First-principles fix:** Move rarely read or large columns to side tables (1:1), let TOAST handle big values, and separate frequently updated columns (counters, last_seen) from stable ones.
- **Meta:** Which columns are read together, and which are updated together?
- **Second-order:** Reassembling rows costs joins, and consistency across split rows needs the same transaction.

#### 7.3 "Normalize first, denormalize only when slow" (was #3) [Likely]
- **Why wrong:** Both choices trade write cost against read cost. "Only when slow" ignores update-anomaly risk and treats normal form as moral rather than economic.
- **What is correct:** Each fact has one owner, and copies are allowed only with a defined refresh and verification.
- **Problem it creates:** Drifting copies and inconsistent totals, or over-normalized read paths with join explosion.
- **First-principles fix:** For every duplicated or derived field, specify the source of truth, the update mechanism (trigger, application, async job), the staleness tolerance, and a drift-check query. Denormalize on measured read cost, otherwise stay normalized.
- **Meta:** If this copy is wrong, who notices and when? What is the read-to-write ratio?
- **Second-order:** Copies multiply write paths, schema changes must propagate to every copy, and repairs need backfills.

## 7B. Lifecycle and deletion

#### 7.4 "A status column models a lifecycle" (was #35) [Likely]
- **Why wrong:** It allows any value-to-value change, loses transition history, and combines with flags into impossible states.
- **What is correct:** A lifecycle is states plus allowed transitions plus who and when.
- **Problem it creates:** Illegal transitions (refund before payment), unexplained states, races on transitions.
- **First-principles fix:** Define a transition table or constraint, update state with compare-and-set (WHERE status = expected), keep a history table, and use one status column with a CHECK rather than several booleans.
- **Meta:** Which transitions are legal? What invariants hold in each state?
- **Second-order:** Adding states needs migration and code updates, and concurrent transitions need conflict handling.

#### 7.5 "Soft delete is the safe way to delete" (was #18) [Certain]
- **Why wrong:** Deleted rows stay visible to every query that forgets the filter, collide with unique constraints, inflate tables and indexes, and don't satisfy erasure requirements.
- **What is correct:** "Delete" has distinct purposes: hide, undo, retain for audit, erase.
- **Problem it creates:** Leaks of deleted data through a missed filter, uniqueness conflicts, compliance failures, slower tables.
- **First-principles fix:** Choose per purpose. Use an archive table or audit log for recovery and audit. If soft delete is needed, use partial unique indexes (WHERE deleted_at IS NULL) and views that apply the filter. Run a scheduled hard purge by retention.
- **Meta:** Why do we keep deleted rows, for whom, and for how long?
- **Second-order:** Restoring needs conflict handling, foreign keys may point at deleted rows, and erasure must reach archives and backups.

#### 7.6 "Foreign keys slow the database, so drop them" (was #31) [Likely]
- **Why wrong:** FK cost is a bounded lookup per write (plus locks on parent rows), while the benefit is system-wide integrity.
- **What is correct:** FKs are an integrity tool with a measurable cost.
- **Problem it creates:** Accumulating orphans, dangling references after deletes, hidden data bugs.
- **First-principles fix:** Keep FKs by default and index the referencing columns. If you drop one on a hot path or across shards, replace it with write-path enforcement and periodic orphan detection and repair.
- **Meta:** Which writes are hot enough that FK cost shows up in profiles?
- **Second-order:** Cascading deletes can create huge transactions, and deferred constraints change when failures surface.

## 7C. Structure versus flexibility

#### 7.7 "A flexible schema (JSON or schemaless) gives us agility" (was #19) [Likely]
- **Why wrong:** The schema moves into code, undocumented and unenforced. You lose constraints and good statistics, and migrating shapes is painful.
- **What is correct:** Flexibility needs explicit schema-evolution rules.
- **Problem it creates:** Readers handling many shapes, silent bad data, slow queries on unindexed paths.
- **First-principles fix:** Use columns for anything filtered, joined, constrained, or aggregated. Use JSON only for opaque or sparse attributes, validate it with a schema or CHECK, promote hot keys to columns, and version the payload.
- **Meta:** Which JSON keys are queried today? Who reads each shape?
- **Second-order:** Promotion migrations on large tables are costly, and readers must handle both shapes during the transition.

#### 7.8 "Arrays or comma-separated values are a shortcut for many-to-many" (was #38) [Certain]
- **Why wrong:** No referential integrity, awkward indexing and updates, and ambiguous parsing.
- **What is correct:** Relationships are rows.
- **Problem it creates:** Orphan references, slow membership queries, update races on the whole array.
- **First-principles fix:** Use an association table with a composite primary key and FKs. Use arrays with GIN only for read-mostly, tag-like, non-referential sets where integrity doesn't matter.
- **Meta:** Do the elements refer to other entities? Will I query by element?
- **Second-order:** More rows and joins, and ordering semantics need an explicit position column.

## 7D. Derived data

#### 7.9 "Maintain counters with UPDATE count = count + 1 on the parent row" (was #37) [Certain]
- **Why wrong:** It causes hot-row contention, duplicate increments on retries, and drift from the real rows.
- **What is correct:** Counters are derived data.
- **Problem it creates:** Throughput collapse on popular rows and wrong counts.
- **First-principles fix:** Compute from source rows when cheap. Otherwise append events and aggregate asynchronously with reconciliation, split hot counters across N rows, and make increments idempotent with event IDs.
- **Meta:** What is the maximum write rate on one counter? How is drift detected?
- **Second-order:** Eventual counts confuse users, and reconciliation adds load.

---