# Volume 3: The Subtle, Complex, and Usually Overlooked

Nothing from Volumes 1 and 2 is removed. This volume continues from Part 18 and focuses on details that experienced teams often do not think about until they cause an incident. These are interactions, internals, and second-order effects.

Some specifics (database internals, kernel defaults, cloud behavior) vary by product and version. Treat them as things to **verify for your exact stack**, not as universal facts.

---

## Part 18: Distributed Systems Depth

### 18.1 Clocks: three different things people call "time"

| Clock | What it gives you | Safe for | Unsafe for |
|---|---|---|---|
| Wall clock | Calendar time, can jump forward or backward (NTP steps, manual change, VM pause) | Display, logs, human-facing deadlines | Measuring durations, ordering events across machines, lock expiry |
| Monotonic clock | Always moves forward, meaningless across machines | Measuring elapsed time, timeouts on one machine | Comparing with another machine's value |
| Logical clock (counters, versions, vector or hybrid clocks) | Causal ordering | Ordering, conflict detection | Human time |

**Root causes:** A (assumption that time is one simple thing) and E (assuming a single timeline).

**Critical traps**
- **"Latest timestamp wins" across machines:** if server A's clock is 2 seconds ahead of server B, a write on B that happened *after* a write on A can lose. Data disappears silently. Nothing errors.
- **Client-supplied timestamps** used for ordering: a phone with the wrong date can write "from the future" and block every later correct write.
- **Measuring duration with wall clock:** an NTP correction produces negative or huge durations, breaking timeouts, rate limiters, and metrics.
- **Leap second handling differs by provider** (some smear it across hours, some step it), so mixed fleets can disagree by a second.
- **Pause-induced time jumps:** a VM pause, live migration, or a long garbage collection pause makes the process "wake up" in a different world than it went to sleep in (see 18.2).
- **Timestamp precision mismatches** between components break equality-based logic (for example, optimistic locking that compares timestamps stored at different precision).

**Questions:** Which clock does each timeout, expiry, and ordering rule use? What happens if the clock goes backward 5 seconds? What if it freezes?

**Fix:** use monotonic time for durations, use versions or sequence numbers for ordering, and use a single authoritative source (the database's clock or a sequencer) when timestamps must be compared.

### 18.2 Leases, pauses, and fencing tokens

A very common design: a process acquires a lease or lock with an expiry, does work, and releases it. It looks safe. It is not.

```
worker A: acquires lease (expires in 30s)
worker A: checks "lease still valid?" -> yes
worker A: process pauses for 40s (GC pause, VM freeze, swap storm, slow network)
lease expires; worker B acquires the lease and writes
worker A: wakes up, believes it still holds the lease, writes     <-- both wrote
```

The check and the action are separated by a gap that the process cannot perceive. No amount of "check the lease more carefully" closes it, because the pause can happen *between* the check and the write.

**Root cause:** E (assumption that the holder's belief about the world is current) and C (the resource does not enforce who is allowed to write).

**Fix: fencing tokens.** Every time a lease is granted, it comes with a monotonically increasing number. The *resource being protected* (database, storage, downstream service) rejects any write carrying a token lower than the highest it has seen.

```
lock.acquire() -> token = 34
write(resource, data, token=34)
resource: if token < highest_seen: reject   # stale holder is blocked by the resource itself
          else highest_seen = token; apply
```

The key insight: **the protection must live at the resource, not at the lock holder.** A lock service alone cannot make a pausing client safe. This applies to "distributed locks" built on caches or databases as well.

**Also consider:** whether the lock is for *efficiency* (avoid duplicate work; occasional double execution is harmless) or *correctness* (double execution causes damage). A cheap lock is fine for the first; the second requires fencing or a constraint in the database.

### 18.3 Leader election, split brain, and "believed leader"

- A node that was leader and got partitioned may **still believe it is leader** for some time and keep accepting writes.
- Failover promotes a new leader while the old one is alive but unreachable, so you now have two writers (split brain).
- Promotion of a stale replica loses the writes it never received. Automatic failover is a decision to accept that loss, and someone should have made it consciously.
- **Fencing the old leader** means *preventing* it from writing (revoking its storage access, cutting its network, power-cycling it, or using tokens), not just assuming it will notice.
- After the partition heals, the old leader's un-replicated writes are either discarded (data loss) or need manual reconciliation. Decide which, in advance.
- **Flapping:** unstable networks cause repeated elections, each of which interrupts writes. Aggressive timeouts make this worse, and overly long timeouts slow recovery. Tuning is a tradeoff that depends on your real network and pause characteristics.

**Questions:** How does the old leader learn it is no longer leader? What stops it from writing in the meantime? Who decides that losing N seconds of writes is acceptable?

### 18.4 Quorum and replication subtleties

- **Even-sized clusters:** a 4-node majority-quorum cluster tolerates the same number of failures as a 3-node one, but has more failure points and can split 2-2 with no majority.
- **Correlated placement:** 3 replicas in 3 nodes that share a rack, zone, power feed, or hypervisor are really one replica. Quorum math assumes independent failures.
- **Quorum size vs. "read your own writes":** with flexible quorums, having read-quorum plus write-quorum exceed replica count helps, but does not by itself give linearizable behavior (concurrent writes, sloppy quorums, hinted handoff, and clock-based conflict resolution can all break it).
- **Membership changes are dangerous moments:** adding or removing nodes changes what "majority" means. Doing it carelessly (several at once, or while unhealthy) can create two disjoint majorities.
- **Stale node rejoin:** a node that was offline for a long time comes back with old data or old configuration and can disrupt the cluster, or (in eventually consistent stores) resurrect deleted data (see 18.6).
- **Lost quorum:** if 2 of 3 fail, the cluster may become read-only or unavailable, and recovery procedures (forcing a single node to become leader) may discard data. That procedure should be written and rehearsed *before* it is needed.
- **Disk latency matters:** many consensus systems must write to disk before acknowledging. One slow disk, a noisy neighbor, or a fsync stall on the leader looks like leader failure and triggers elections and cascades.
- **Timeout tuning against real pauses:** election timeouts shorter than typical GC or network pauses create constant spurious elections.

### 18.5 Partitions are not just "up or down"

Real network failures are messier than "the node is dead":
- **Asymmetric:** A can reach B, B cannot reach A.
- **Partial:** A sees B, B sees C, A cannot see C. Different nodes hold different views of who is alive.
- **Slow, not dead:** packets arrive, but after 20 seconds. This is worse than a clean failure because timeouts and failure detectors give the wrong answer.
- **Intermittent:** 2% packet loss. TCP throughput drops dramatically with even small loss, and health checks pass most of the time.
- **One direction of one protocol:** ICMP blocked while TCP works, or large packets fail while small ones succeed (MTU).
- **Gray partitions:** the control plane sees the node as healthy; the data path does not work.

**The core limitation:** from one node's perspective, *a slow peer and a dead peer are indistinguishable*. Any failure detector is a guess with a threshold. Too sensitive, and you remove healthy nodes (and the extra load causes more removals). Too lax, and you keep sending traffic to dead ones.

**Questions:** What does each component do when it cannot tell whether a peer is down or slow? Do different components disagree about who is alive, and what happens then?

### 18.6 Deletion, tombstones, and resurrection

In eventually consistent or replicated systems, a delete must be recorded as a marker (tombstone), not just the absence of data; otherwise a replica that still has the old value will "repair" the deletion by copying the value back.

- Tombstones are eventually garbage-collected. If a replica was down or partitioned **longer than the tombstone retention**, it can come back and reintroduce deleted data ("zombie" data).
- This matters for privacy deletion (data the user erased returns), permissions revocation (a revoked grant reappears), and unique keys.
- The same pattern appears in sync systems, caches, offline-capable mobile apps, and search indexes built from change streams.

**Questions:** What is the maximum time a node can be offline and still safely rejoin? What enforces that limit? How do we know deleted things stay deleted?

### 18.7 Sagas and compensation are not rollbacks

When a multi-step business operation spans services, each step is committed separately. If step 4 fails, you run "compensating" actions for steps 1 to 3. Hidden problems:
- **Compensations can fail too,** and you then need a compensation for the compensation, or a manual queue.
- **Compensation is not inverse:** you cannot un-send an email, un-notify a user, or un-ring an external system. A refund is not the same as the charge never happening (fees, statements, tax records, user-visible history).
- **No isolation:** other users and processes can see and act on the intermediate state (inventory reserved but order not yet confirmed; money debited but not yet credited).
- **Compensation ordering and idempotency:** compensation may be triggered twice, or arrive before the original action completes (the "cancel" message overtaking the "create" message).
- **Timeouts during a step:** was it done or not? Compensation may undo something that never happened, or skip undoing something that did.
- **Long-running sagas** survive deployments and schema changes; in-flight sagas created by old code must be completable by new code.

**Design rules:** persist saga state durably; make every step and compensation idempotent; model the intermediate states explicitly in the domain (pending, reserved, confirmed) so they are legitimate and visible; handle "cancel before create" arrivals; provide a manual resolution path and alerts for sagas stuck beyond a limit.

### 18.8 Queue behavior under overload

- **An unbounded queue turns an overload into a latency disaster,** not an error. Everything is "accepted," and users wait minutes for answers that are no longer useful. By the time the system recovers, most queued work has been abandoned by the caller but is still processed (wasted capacity).
- **FIFO under sustained overload is the worst order:** every item waits the maximum time. In overload, it is often better to process the newest first, or to drop the oldest or lowest-priority, because stale work has no value.
- **Little's Law applies to queues:** queue length divided by processing rate is the delay. A queue of 1 million items at 1,000 per second is 1,000 seconds of delay, hidden behind a healthy-looking "accepted" response.
- **Backlog plus normal traffic after recovery** can exceed capacity, so the backlog never drains (metastable, Part 9.2).
- **Priority starvation:** low-priority work never runs; high-priority floods block important low-volume work.
- **Head-of-line blocking:** one slow or poison item blocks those behind it, or one big tenant's jobs occupy all workers.
- **Fairness:** a single tenant enqueues 10 million jobs, and everyone else waits. Per-tenant queues or quotas are needed.

**Questions:** What is the maximum age we accept for a queued item? What happens to items older than that? What stops a single producer from starving others?

### 18.9 Deadlines, cancellation, and abandoned work

- Timeouts set per hop (Part 4.1) handle *waiting*. **Deadline propagation** passes the remaining time budget down the call chain so inner calls do not start work the outer caller has already abandoned.
- When a caller times out and retries, **the original request may still be running** downstream. Now two copies execute (double side effects, double load).
- **Cancellation must be cooperative and propagate:** if the client disconnects, does the server stop the database query? An abandoned expensive query keeps consuming resources.
- **Work that cannot be cancelled** (a payment already submitted) needs an idempotency design, not a cancellation.
- Every retry decision should ask: *is anyone still waiting for this answer?*

### 18.10 Consistent hashing, rebalancing, and resharding hazards

- Adding or removing a node moves a portion of keys; for caches, that means a burst of cold misses hitting the source. For stateful systems, data must move while serving traffic, consuming I/O and network exactly when the cluster is already changing.
- **Autoscaling a cache or a sharded store in response to load** can worsen the load (rebalancing work plus cold keys).
- **Hot keys are not fixed by hashing;** hashing spreads *keys*, not *traffic*. One popular key still hits one node.
- **Virtual node count and uneven capacity** cause imbalance; one larger node takes more.
- **Resharding later is very hard:** choosing a shard key (tenant, user, time) bakes in assumptions about the largest entity and query patterns. Cross-shard queries, transactions, and uniqueness become difficult or impossible.
- **Shard key changes** in a live system require dual writes and verification (and the dual-write problem in Part 9.6).

---

## Part 19: Database Internals That Bite (Point Details)

### 19.1 MVCC side effects and "invisible" resource consumers

Most modern databases let readers and writers avoid blocking each other by keeping multiple row versions. The cost is cleanup, and the cleanup depends on *the oldest thing still needing an old version*.

- **Dead row accumulation (bloat):** updates and deletes leave old versions until cleanup. A long transaction, or an idle-in-transaction session, prevents cleanup across the whole database, not only its own tables. Tables and indexes grow, and queries slow down gradually.
- **Transaction ID exhaustion (in engines with finite transaction counters):** the database must periodically "freeze" old rows. If cleanup is blocked or disabled for long enough, the engine can be forced into a protective state that refuses writes until a long maintenance operation completes. This is a time bomb that arrives after months of healthy operation.
- **Replication slots and log retention:** a replica or a change-data-capture consumer that stops reading can cause the primary to retain logs for it indefinitely, filling the disk. The primary then fails because of a *downstream consumer's* problem. An abandoned slot (a decommissioned replica, a dead connector) is an especially silent version of this.
- **Undo/history growth in other engines:** long transactions make the purge of old versions lag, slowing queries (they have to walk version chains) and consuming space.
- **Autovacuum/cleanup competing with workload,** or tuned for small tables and falling behind on huge ones. Cleanup may be canceled by lock conflicts and never finish.
- **Bulk delete or update** creates as many dead rows as it touches; space is not returned to the OS by normal cleanup.

**Root causes:** F (finite resource consumed by an invisible process), G (one client's behavior affects everyone), H (no metric on oldest transaction, slot lag, or dead-row ratio).

**Monitor:** age of oldest transaction, replication slot lag and retained bytes, dead-row ratio on large tables, distance to transaction-ID limits (if applicable), cleanup duration and failures, and disk growth rate.

### 19.2 Locking and deadlocks, beyond the basics

- **Deadlocks from ordering:** two transactions updating the same two rows in opposite order; batch updates that touch rows in arbitrary order; upserts hitting the same keys in different order. Fix: consistent ordering (for example, sort keys before updating).
- **Deadlocks from foreign keys:** inserting a child takes a lock on the parent row; many children inserting for the same parent contend.
- **Gap and range locks** (in some engines and isolation levels) block inserts into ranges that seem unrelated, causing surprising contention and deadlocks.
- **Lock escalation or table-level locks** from certain operations or when many rows are touched.
- **Lock wait timeout vs. deadlock detection:** without a timeout, a forgotten transaction blocks others forever.
- **Hot rows** (Part 10.7) become a queue.
- **Retrying is mandatory:** deadlocks and serialization failures are *normal, expected outcomes* under concurrency, not bugs. Code that surfaces them as errors to users is incomplete.
- **Retry whole transaction logic,** including the reads and decisions, not just the failed statement, because the world changed.
- **Side effects inside retried transactions** (sending messages, calling APIs) happen multiple times.

### 19.3 What "committed" actually means (durability depth)

- Durability depends on **flush-to-disk settings**; relaxed settings trade a window of potential loss for speed. Know which setting is in use and whether the business accepted that window.
- **Storage can lie:** drives, controllers, virtualization layers, and network storage may acknowledge writes before they are truly persistent. Power-loss protection, write-cache policy, and the storage layer's guarantees matter.
- **Replication acknowledgment levels:** "committed" might mean written locally, received by a replica, flushed by a replica, or applied by a replica. Each gives different loss and staleness behavior on failover.
- **Write errors at the filesystem level:** disk full or I/O errors during flush; how the engine and the OS report and recover from such errors has led to real data-loss incidents. "It did not crash" does not mean "it wrote."
- **Crash consistency of backups:** a volume snapshot taken while the database is writing may capture an inconsistent state unless the engine supports crash-consistent recovery or the snapshot is coordinated. Verify by actually restoring it and running integrity checks.
- **Corruption:** bit rot, bad memory, bugs, or storage faults produce silent corruption. Without checksums and periodic verification, you may replicate and back up the corruption for weeks, until all restore points are bad.

### 19.4 Upserts, "insert if not exists", and error-as-control-flow

- `SELECT` then `INSERT` races; use the atomic upsert or rely on the unique constraint and treat the conflict as the normal path.
- **Upsert semantics differ by engine** (what happens to fields not in the update, triggers, sequences consumed even on conflict, concurrent delete, which row wins).
- **Merge statements** in some engines have known race behavior under concurrency; verify, and still keep a unique constraint.
- **A failed statement may poison the transaction** (in some engines the transaction is unusable until rollback or savepoint). Code that catches a duplicate error and continues inside the same transaction breaks.
- **Sequences are consumed on failure,** so heavy conflict traffic burns through IDs quickly (relevant for 32-bit keys).
- **Counting rows affected:** code that assumes "0 rows updated" means "not found" may actually mean "value unchanged" in some engines' default settings.

### 19.5 Optimizer and statistics: deeper

- **Correlated columns:** the planner assumes independence between columns. City and postal code are perfectly correlated, but the planner multiplies selectivities and underestimates rows by orders of magnitude, choosing a wrong join strategy.
- **Generic vs custom plans for prepared statements:** a plan built for one parameter may be reused for a very different one (skewed data), or the engine switches plan type after a number of executions, creating a sudden latency change that looks unrelated to any deploy.
- **Stale statistics after bulk load** (the table looks empty to the planner).
- **Estimates compound through joins:** a 10x error per step becomes 1000x after three joins.
- **Plan instability near thresholds:** two plans with similar estimated cost, one of which is catastrophically worse at runtime.
- **Partition pruning failing** when the query uses a function or type cast on the partition key, scanning every partition.
- **Materialized/derived data:** views and materialized views refreshed at the wrong cadence, or refresh blocking reads.
- **CTE, subquery, and ORM-generated SQL** behaving differently between versions (optimization fences added or removed).

**Mitigations:** capture slow query plans automatically, alert on plan changes for critical queries, test with skewed data, and know which queries are "load-bearing" and watch them by name.

### 19.6 Partitioning and time-based tables (time bombs)

- **Missing future partition:** inserts fail at midnight on the first of the month because nobody created the next partition. This is one of the most common scheduled outages. Automate creation well ahead, and alert on "fewer than N future partitions remain."
- **Default partition** silently accumulates "unexpected" rows and grows large.
- **Unique constraints must include the partition key** in many engines, so global uniqueness is weaker than it appears.
- **Too many partitions** slow planning and increase memory usage.
- **Dropping old partitions vs. deleting rows:** dropping is cheap; deleting creates bloat and lock pressure. But dropping is irreversible, and a retention job with a bug (wrong date arithmetic, wrong timezone, empty config value) can drop the wrong data.
- **Queries spanning partitions** and cross-partition foreign keys (often unsupported).
- **Archival and legal retention:** data must stay while under a legal hold but be deleted for privacy requests; both rules can apply to the same data.

### 19.7 Cascades, bulk deletes, and large operations

- A cascade can delete millions of dependent rows in one transaction: long locks, huge replication lag, massive log generation, and possible failure after hours (then a long rollback).
- Deleting a parent row requires checking every child table; without an index on the child's foreign key, each delete scans a whole table.
- **Batch deletes** with limits and pauses, selecting by a stable key range, are safer, resumable, and kinder to replication.
- **Soft delete followed by purge** needs care with references from other systems (caches, search, analytics, backups).
- **The "delete everything not in this list" pattern:** see Part 22.3 (empty input deleting everything).

### 19.8 Read replicas: additional hazards

- Long queries on a replica can conflict with replication apply; either the query is canceled or replication is delayed (configurable tradeoff), or the replica's long query holds back cleanup on the primary (if feedback is enabled).
- Replicas may have different indexes, settings, or hardware; plans differ.
- Replicas lag most under heavy write load, exactly when you rely on them.
- **Promoting a replica** for failover: check what it lacks (lag), what settings differ, and whether the application's connections actually move.
- **Cross-region replicas** lag by distance and suffer during network issues.
- **Reporting on replicas** can silently produce wrong numbers if replication is lagging or paused (the dashboard shows stale data confidently).

### 19.9 Type, collation, and default-value traps

- Timestamp type without time zone stores whatever you give it, with no record of zone; reading it in a different session zone yields no shift, but interpreting it is ambiguous. Time zone-aware types store an instant.
- `now()` or equivalent used as a column default during a migration applies the migration time to all existing rows, not the real creation time. Backfilling with the wrong default creates false history.
- Volatile defaults (random IDs, current time) applied to existing rows at migration behave differently than constants, and can force a table rewrite.
- Integer vs. bigint mismatches across joined or referenced columns (index not used, overflow at different times).
- Fixed-width character columns pad with spaces; comparisons may ignore trailing spaces in some engines and not others.
- Case-insensitive collations change uniqueness and sorting; moving between environments with different collations changes behavior.
- Lenient SQL modes in some engines silently truncate, convert invalid values to defaults (including "zero dates"), or accept out-of-range numbers. Enable strict mode everywhere, including development and test.
- Adding a new value to an enumerated type can have restrictions inside transactions in some engines, and old application code may not handle the new value.
- JSON numbers: large integers and decimals lose precision in many parsers.
- Generated or computed columns that depend on time zone or locale, changing behavior when settings change.

### 19.10 Connection poolers and session state

- Transaction-mode pooling shares server connections between clients between transactions, so **session-level features break or leak:** prepared statements, session variables, temp tables, advisory locks, `SET` commands, listen/notify.
- A session-level lock or setting acquired by one client and never released can be inherited by another client's next transaction.
- **Pooler as single point of failure** and as a new queue with its own limits.
- **Connection storms after failover or restart:** every instance reconnects at once.
- **Idle-in-transaction connections** held by application bugs pin pooler connections.

### 19.11 Multi-tenancy and isolation depth

- **Tenant filter enforcement:** convention-based ("always add `WHERE tenant_id`") fails eventually. Structural enforcement (row-level security policies, separate schemas or databases, scoped views or data-access layers that cannot omit the filter) holds up better. Note that privileged roles, table owners, and certain connections may bypass row-level policies unless configured otherwise.
- **Indexes must start with the tenant key** for most queries, or one tenant's large data slows all tenants.
- **Noisy neighbor:** a tenant running expensive queries or bulk imports degrades everyone. Need per-tenant rate limits, query timeouts, resource quotas, and queue fairness.
- **Skew:** the largest tenant may be 1000x the median; plans, batch jobs, and migrations behave very differently for them.
- **Cross-tenant identifiers:** foreign keys that do not include tenant can link rows across tenants if an ID is guessed or supplied by a client.
- **Per-tenant operations** (restore one tenant, export one tenant, delete one tenant) are hard if not designed in from the start.
- **Shared caches, queues, logs, search indexes, file storage paths:** every shared layer needs the tenant in its key, path, and access check.
- **Migrations across thousands of schemas or databases** take long, fail partway, and leave tenants on different versions; code must handle a mixed population.

### 19.12 Data deletion and privacy: where the data really is

A deletion request must reach: the primary database, replicas, backups, logs, caches, search indexes, analytics warehouses, data lake copies, exports and spreadsheets, message queues and dead-letter queues, third-party processors, machine learning training sets and derived features, and screenshots or attachments. Two hidden problems:
- **Backups are immutable by design,** so "delete" often means "will age out in N days," and restoring a backup can **reintroduce deleted personal data** unless a deletion ledger is re-applied after restore.
- **Legal retention vs. erasure obligations** can conflict for the same record; someone should have defined precedence and which fields are kept.

### 19.13 Analytics and data pipelines

- **Late-arriving data:** events arrive hours or days after they occurred. A daily report computed at midnight is wrong by morning. Decide how long you wait, how corrections propagate, and whether reports are restated.
- **Event time vs. processing time:** grouping by when you *received* an event gives different numbers than by when it *happened*.
- **Backfill double counting:** re-running a job that appends rather than overwrites doubles the data. Prefer idempotent, partition-overwrite designs: re-running a day replaces that day.
- **Join fan-out:** joining a one-to-many relation before summing multiplies the sum (an order total counted once per order item).
- **Aggregating over NULLs, empty groups, and duplicates;** `COUNT DISTINCT` approximations; averaging averages (average of per-group averages differs from the overall average).
- **Timezone and calendar boundaries:** "daily active users" for which timezone? Weeks starting Sunday or Monday? Fiscal calendars?
- **Upstream schema change produces NULLs silently:** a renamed field makes a column 100% NULL, and the pipeline "succeeds."
- **Empty input treated as success:** the source export failed and produced zero rows; the pipeline happily overwrites the good table with nothing. Check row counts and freshness against expectations, and fail on anomalies.
- **Partial writes:** a job dies halfway and leaves a half-updated table visible to readers. Use write-then-swap (publish atomically).
- **Metric definitions drifting** across teams; two dashboards both claim "revenue" with different numbers.
- **Slowly changing data:** reporting on current attribute values (a customer's current country) when the historical value (at the time of the order) is what the question needs.

---

## Part 20: Application-Level Subtleties

### 20.1 Numeric details that cause real disasters

- **Floating-point addition is not associative:** summing in a different order (parallel reduction, different batch sizes, a database using a different plan) gives slightly different results. Reports that "should match" do not, and equality checks break. Use exact decimals or integers for anything that must reconcile.
- **Intermediate overflow:** `(a * b) / c` can overflow in the multiplication even when the final result fits. `(low + high) / 2` can overflow for large indices.
- **Implicit conversions and widening/narrowing:** a 64-bit value stored into a 32-bit field truncates silently in some languages or databases.
- **Unsigned arithmetic:** `length - 1` on an empty collection wraps to a huge number.
- **Percentages and rounding:** three items at 33.3% sum to 99.9%. Rounding each line vs. rounding the total gives different results. Decide and document the rule, and put the remainder somewhere explicit.
- **Unit confusion:** seconds vs. milliseconds vs. microseconds; bytes vs. bits; cents vs. dollars; a timestamp in milliseconds interpreted as seconds becomes a date tens of thousands of years away.
- **Epoch limits:** 32-bit time values overflow in 2038; some systems have their own far-future or sentinel dates ("9999-12-31" used as "never expires" then breaks date arithmetic).
- **Sentinel values:** `-1`, `0`, empty string, or 1970-01-01 used to mean "unknown" get treated as real values in calculations and reports.
- **Division:** integer division truncation (and differences in rounding direction for negatives), division by zero, division producing infinity or NaN that then propagates silently through later math.
- **Comparing floating timestamps or money** for equality.

### 20.2 Strings and text: what "length" and "equal" really mean

- **Length has at least four meanings:** bytes, code units, code points, and user-perceived characters (grapheme clusters). A limit of "50 characters" enforced in bytes cuts non-Latin names and emoji; truncating in the middle of a multi-unit character produces invalid text or splits an emoji into garbage.
- **Case conversion is locale-dependent and not always reversible;** case-insensitive comparison should use proper case folding, not lowercase.
- **Invisible characters:** zero-width spaces, non-breaking spaces, directional override characters, soft hyphens, and control characters. They pass "not empty" checks, break equality, and are used for spoofing (two usernames that look identical, or a filename that appears to have a different extension).
- **Homoglyphs:** visually identical characters from different scripts allow impersonation.
- **Validate-then-normalize bugs:** if you validate a string and *then* normalize or decode it, the normalized result may violate the rule you just checked (a security-filter bypass pattern). Normalize first, then validate, then use the normalized value.
- **Double decoding and mixed encodings:** decoding input twice can turn a harmless sequence into a dangerous one; treat decoding as a single, explicit step at the boundary.
- **Null bytes and embedded newlines** in strings passed to systems that treat them as terminators or separators (file paths, headers, logs, CSV, command arguments). Newlines in user input can forge log lines or inject headers.
- **Sorting and searching text:** accent and locale-specific order; search that must match "resume" and "résumé" or not.
- **Trimming:** what counts as whitespace differs between libraries.
- **Secret comparison:** comparing tokens with a normal equality check can leak information through timing; use constant-time comparison for secrets.

### 20.3 Hashing, ordering, and determinism

- **Iteration order of hash-based collections** may vary between runs, versions, or machines. Code that depends on it (output order, tie-breaking, generated IDs, test expectations) breaks intermittently.
- **Built-in hash functions can be randomized per process** for security; using them to shard data or derive stable identifiers causes different processes to disagree. Use an explicitly specified, stable hash for anything persistent or cross-process.
- **Changing a hash function, shard count, or partitioning scheme** remaps all keys.
- **Inconsistent comparators** (violating transitivity, or treating NaN/NULL inconsistently) make some sort algorithms crash, loop, or produce garbage.
- **Mutable objects used as keys** then modified, vanishing from the map.
- **Non-deterministic output in supposedly deterministic systems** (builds, reports, exports) makes diffing and audit impossible.

### 20.4 Parsing, parser differentials, and hostile input

- **Catastrophic regex backtracking:** a pattern that is fast on normal input takes exponential time on a crafted one, consuming a CPU core per request and causing a denial of service. Prefer linear-time engines, bound input length, and set match timeouts.
- **Parser differentials:** two components parse the same input differently (a proxy and an application disagree on header boundaries, URL structure, duplicate parameters, duplicate JSON keys, encoding, or content type). Attackers exploit the gap; accidental versions cause "works in one path, not another." Use one parser, or make both strict.
- **Duplicate keys and parameters:** first wins, last wins, or merged? Varies by library.
- **Content-type confusion:** body is treated as a different format than the sender intended.
- **Decompression and expansion attacks:** small input expands to gigabytes (compression bombs, recursive entity expansion, deeply nested structures).
- **File uploads:** file name, extension, declared type, and actual content can all disagree; path traversal through names; image decoders as attack surface; size and dimension limits (a small file that decodes into a massive image).
- **Resource-limit defaults:** many parsers have no size or depth limit unless configured.

### 20.5 Serialization evolution across versions

- **Every serialized form outlives the code that wrote it:** database rows, queue messages, cache entries, files, logs, API responses held by clients, mobile app payloads.
- **Compatibility directions:** *backward compatible* means new readers handle old data; *forward compatible* means old readers handle new data. During a rolling deploy you need **both** at once.
- **Cache poisoning by version:** new code writes a cache format the old code (still running) cannot read, and old code's crash loop hits the cache and database; or new code reads old cache entries with missing fields.
- **In-flight messages:** a queue may hold hours or days of messages written by old code when new code deploys, or new-format messages when an old consumer is rolled back.
- **Adding a required field,** reusing a field number or name with a different meaning, changing a field's type, or changing an enum's meaning are breaking changes even if the schema "compiles."
- **Default values:** a missing field becomes a default (0, empty, false), which is indistinguishable from a deliberate value. A "missing flag defaults to false" bug silently turns features off (or a security option off).
- **Unknown enum values from newer producers:** old consumers need a defined fallback, not a crash.
- **Replaying history** (event sourcing, reprocessing, backfill) requires that old event versions remain parseable forever, or be upgraded by explicit migration.

### 20.6 Feature flags, configuration, and combinatorics

- **Flags multiply states:** 10 independent boolean flags have 1,024 combinations, and only a few were ever tested. Interacting flags (a flag that changes data format plus a flag that changes a consumer) create untested paths.
- **Default on failure:** when the flag service is unreachable, what value does the code use? That default is a production behavior that nobody tested.
- **Flag evaluation cost and latency** inside hot paths; flag service as a hard dependency.
- **Flags that change data:** turning a flag off does not un-write data created while it was on. Turning it back off (as a "safe rollback") may break readers.
- **Stale flags:** never cleaned up, so dead code paths remain reachable by an accidental config change.
- **Kill switches that depend on the broken thing:** the mechanism for disabling a feature relies on the service that is down or overloaded.
- **Per-user or per-tenant targeting bugs:** inconsistent bucketing across services, so one user sees the new behavior in one service and old in another within the same request.
- **Config changes applied at different times on different instances** create temporary mixed states.
- **Configuration values with units and ranges:** timeouts in seconds vs. milliseconds; a typo of one zero; no validation; a negative or zero value meaning "infinite" or "disabled" in some libraries.

### 20.7 Caching: the subtle races and semantics

**The classic invalidation race**

```
T1: read value from DB (old value v1)
T2: update DB to v2
T2: delete cache key
T1: write v1 into cache          <-- cache now holds stale v1, possibly until TTL expiry
```

Delete-on-write does not prevent this, because a slow reader can repopulate after the delete. Mitigations: short TTLs as a backstop, version-stamped entries (write only if newer), a short "tombstone" lock after invalidation, or reading through a single-flight mechanism. Even then, define the maximum tolerated staleness explicitly.

**Other subtle issues**
- **Cache key completeness:** the key must include every input that changes the result (user, tenant, permissions, locale, feature-flag state, currency, API version, time bucket). Missing one leaks data between users or returns the wrong variant.
- **Caching authorization-dependent data** under a shared key.
- **Caching errors or empty results** (failed fetch cached as "no data"), and negative caching for too long.
- **Cache penetration:** requests for keys that do not exist bypass the cache every time; attackers or buggy clients hammer the database with nonexistent IDs.
- **Synchronized TTLs:** many keys set at the same time with the same TTL expire together, creating periodic load spikes. Add jitter.
- **Eviction changing behavior:** memory pressure evicts entries, and code that depended on the entry's presence (for example, using the cache as session storage or a deduplication store) now fails or double-processes.
- **Cache as source of truth by accident:** when the cache holds the only copy of something (sessions, rate limit counters, dedupe keys, in-progress state), a flush or failover becomes data loss.
- **Stale reads for decisions** (permissions, balances, inventory) per Part 9.8.
- **Stampede protection** (single-flight, stale-while-revalidate) is itself a mechanism with failure modes: a lock that never releases; all waiters timing out together.
- **Multi-layer caching** (browser, CDN, reverse proxy, application, database) makes "purge" incomplete; one layer keeps serving old data.
- **Serialization cost and cache size:** huge cached objects cause network and memory spikes; a single large key can block a single-threaded cache server.

### 20.8 Time handling: more hidden cases

- **Time zone database updates:** governments change daylight-saving rules and zone offsets, sometimes with little notice. Servers, containers, runtimes, and databases carry their own copies of the zone data, and they can disagree. A scheduled event or reminder may be off by an hour on hosts with stale data.
- **Store the user's intended local time and zone (not just UTC) for future events** (a meeting at 9:00 in a city). If the zone rules change, the UTC instant should change with it; storing only UTC freezes the old rule.
- **Recurring events:** what does "every month on the 31st" do in April? What does "daily at 02:30" do on the day that 02:30 does not exist, or occurs twice?
- **"Add one month"** to January 31st: results vary by library.
- **Durations vs. calendar units:** "24 hours" and "one day" differ across DST changes; "30 days" and "one month" differ.
- **Week numbering and first-day-of-week** vary by locale and standard; year boundaries (week 1 of the next year starting in December) cause report errors in the last days of December.
- **Sleeping until a time:** a job that sleeps until midnight and then loops can run twice or skip a day if the clock adjusts.
- **Scheduled tasks at round times** (top of the hour, midnight UTC) cause global synchronization spikes across your own systems and everyone else's.
- **Expiry computed from client-provided time.**
- **Sort by time with equal timestamps,** need a tiebreaker.
- **Database time vs. application time:** `created_at` defaults set in different places with different clocks.

### 20.9 Randomness and uniqueness

- Non-cryptographic random generators for tokens, reset links, or session IDs are predictable.
- **Forked or cloned processes share a seed,** generating identical "random" values (two workers producing the same token or backoff jitter).
- Virtual machine images or containers cloned with identical initial entropy state.
- **Random jitter absent or too small,** so retries still synchronize.
- **Random sampling bias:** sampling by hash of a field that correlates with the outcome; sampling that drops rare errors you need to see.
- **"Unique enough" identifiers** generated by truncating, or by timestamp plus small random part, collide under load.
- **UUID generation depends on clock/host** in some versions, colliding if the clock is reset.

### 20.10 Background jobs and async processing: the classic subtle bugs

- **Enqueue before commit:**

```
begin transaction
  insert order
  enqueue job("process order X")      # job is visible to workers immediately
commit                                  # but the row is not yet visible to the worker
# worker runs, looks up order X, finds nothing -> fails or silently skips
```
  Fix: enqueue after commit (and accept the crash-between problem), or use the outbox pattern so the job record commits atomically with the data.
- **Enqueue inside a transaction that rolls back,** leaving a job for data that never existed.
- **Payload snapshot vs. reference:** a job carrying a full copy of an object acts on stale data when it finally runs; a job carrying only an ID must handle the row being changed or deleted in the meantime. Decide which is right for each job and handle "no longer exists" and "already processed."
- **Per-entity ordering:** two jobs for the same entity running concurrently or out of order (an "update" job before a "create" job).
- **Retry of permanent failures forever,** wasting capacity and filling logs, or giving up on transient failures too quickly.
- **Visibility timeout shorter than processing time** causing duplicate processing (Part 4.4); heartbeating for long jobs.
- **Jobs that enqueue jobs** without a bound (fan-out explosion), or recursively.
- **Cron at midnight:** all tenants' jobs at the same second.
- **Worker crash mid-job:** partial side effects; the retry must tolerate a half-done state.
- **Shutdown during job:** jobs killed by deploy; need graceful drain or resumability.
- **Jobs outliving their relevance:** a "send reminder" job delivered days late.
- **Priority inversion:** a low-priority job holding a lock needed by a high-priority one.
- **Silent discard:** workers that catch all exceptions, log, and acknowledge, deleting the job without success.

### 20.11 API and webhook design hazards

- **Batch endpoints with partial failure:** how are per-item results reported? Is the batch atomic? What does a retry of a partially applied batch do?
- **PATCH and partial update semantics:** absent vs. null vs. empty (Part 11.1); concurrent PATCHes with read-modify-write clients overwriting each other (use version or ETag preconditions).
- **Pagination contracts** (Part 11.7), and total counts that are expensive or inconsistent.
- **Error contract:** distinguishing retryable from non-retryable errors consistently; HTTP status codes used inconsistently cause clients to retry permanent failures or drop transient ones.
- **Rate limit semantics:** per key, per IP, per tenant? Do retries count? Is the limit documented with headroom, and do clients honor "retry after"?
- **Versioning and deprecation:** old versions live forever if clients cannot be forced to upgrade (mobile apps, partner integrations). Each supported version multiplies the test and behavior matrix.
- **Webhooks (you send):** receivers may be slow, down, or return misleading codes. Retries cause duplicates; ordering is not guaranteed; a single slow receiver can occupy your delivery workers (head-of-line blocking); signature secrets need rotation with overlap; include event IDs and timestamps so receivers can dedupe.
- **Webhooks (you receive):** verify signatures on the *raw* body (before parsing alters it); reject old timestamps to prevent replay; handle duplicates and out-of-order delivery; respond quickly and process asynchronously; beware that the event may be stale by the time you handle it, so fetch the current state when correctness matters.
- **Third-party API quirks:** "success" responses with error bodies, silently truncated results, eventual consistency (a just-created resource not yet retrievable), undocumented rate limits, inconsistent casing or types between endpoints.

### 20.12 Authorization: where checks go missing

- **Object-level checks:** the user is authenticated but is this *their* object? Every endpoint that accepts an ID is a potential gap.
- **Derived and secondary paths leak what the primary path protects:** search results, autocomplete, exports, reports, notifications, emails, audit logs, error messages, thumbnails, file URLs, analytics dashboards, and webhooks often bypass the permission check the main screen enforces.
- **Permissions that depend on state:** "can edit while draft." State can change between the check and the action (TOCTOU), and background jobs act later on behalf of a user whose permissions changed.
- **Background jobs and internal services** often run with broad identity and lose the original user's context, so one small bug turns into cross-user data access.
- **Mass assignment:** binding request fields directly onto a model lets users set fields they should not (role, owner, price, tenant).
- **Cached permissions:** revocation does not take effect until the cache expires; sessions and tokens that outlive revoked access (long-lived JWTs without a revocation path).
- **Privilege escalation through combination:** two individually reasonable permissions that together allow something unintended.
- **Admin and support tooling:** impersonation features and internal dashboards are often the weakest-audited path to the most sensitive data.
- **Confused deputy:** a service with high privileges performs an action requested by a low-privilege caller without checking the caller's rights.
- **Fail-open on dependency failure** (Part 11.2).
- **Defaults:** new endpoints, new roles, and new resource types default to open or closed?

### 20.13 Testing blind spots that hide all of the above

- **Test doubles that do not behave like the real thing:** a mock that always succeeds, a fake database with different isolation, constraint, collation, or type behavior, an in-memory queue with perfect ordering and no duplicates. Passing tests then prove little.
- **Different database in tests than in production** (lighter engine, different SQL dialect, no concurrency).
- **Mocked time** that cannot reproduce clock jumps, DST, or zone changes, or tests that depend on the real current date (and fail on the 31st, on leap days, or in December).
- **Order-dependent and shared-state tests;** tests that pass only when run alone or in a certain sequence.
- **Flaky tests tolerated** ("just re-run it") hide real race conditions. Flakiness is often a concurrency bug that has not yet hurt a customer.
- **Coverage without assertions:** code executed, but behavior not verified.
- **No tests at the integration seams** (Family D), no tests of migrations on realistic data, no tests of upgrade paths (old data, new code).
- **No tests of negative and hostile cases,** nor of failure handling (what happens when the dependency errors).
- **Unrealistic load tests:** *coordinated omission* (the load generator waits for slow responses before sending the next request, hiding the queueing that real users would experience), too short to hit burst limits, caches pre-warmed, uniform key distribution instead of skewed, no background jobs running.

---

## Part 21: Infrastructure, Deeper

### 21.1 TCP and network behavior that shapes latency and failure

- **Connection queues overflow under bursts:** the listen backlog or accept queue fills, and new connection attempts are silently dropped. Clients retry after 1 second, then 3, then 7, creating latency spikes of exactly those values, and appearing as random slowness while CPU is low.
- **Idle connection timeouts in middleboxes** (NAT, firewalls, load balancers, cloud gateways) are often shorter than default TCP keepalive intervals (which can be hours). The connection looks open on both ends but is dead in the middle; the next write fails or hangs until a long timeout. Set application-level or TCP keepalives shorter than the smallest idle timeout on the path, and know that smallest value.
- **Half-open connections:** one side crashed or was cut off without a clean close; the other side waits. Pools hand these out.
- **Loss has outsized effect:** even one or two percent packet loss can collapse TCP throughput, especially over long-distance links. "The link is up" does not mean "the link is good."
- **Small-message latency effects:** interactions between buffering algorithms and delayed acknowledgments can add tens of milliseconds to small request/response patterns.
- **MTU and path MTU discovery:** if ICMP is blocked, large packets silently disappear (a "black hole") while small requests work. Symptoms: small API calls succeed, large responses or uploads hang. Common across VPNs, tunnels, and overlays (which reduce effective MTU).
- **Ephemeral port and connection tracking exhaustion** (12.1): short-lived connections to the same destination through NAT.
- **DNS resolver settings in containers:** search-path and dots settings can multiply DNS queries per lookup (several failed lookups before the right one), overloading DNS and adding latency. A large response falling back from UDP to TCP can be blocked by firewall rules.
- **IPv4/IPv6 dual-stack issues:** names resolving to both, with one path broken, causing delays on every connection attempt.
- **Microbursts:** traffic that averages 30% utilization can still overflow buffers for milliseconds, dropping packets. Average utilization graphs hide it.
- **Cross-zone and cross-region latency** adds up across chatty call patterns (a request making 50 sequential cross-zone calls pays 50 round trips).
- **Load balancer connection reuse:** long-lived connections pinned to old backends; after scaling out, new nodes receive little traffic.

### 21.2 Memory, CPU, and runtime behavior

- **Container memory limits and file cache:** some accounting includes the page cache; processes doing heavy file I/O may approach the limit without a "leak." Behavior differs by platform and configuration, so verify.
- **Language runtime heap vs. container limit:** a managed runtime sized for the host's memory, not the container's, is killed abruptly when it grows. Off-heap and native memory, thread stacks, and direct buffers add to the footprint beyond the configured heap.
- **Garbage collection pauses** (stop-the-world, or memory-pressure-driven thrash) stall request processing, cause timeouts, trigger health check failures, lose leases (18.2), and cause clients to retry, increasing load. GC behavior changes with heap size, allocation rate, and data shape; it often gets dramatically worse near memory limits.
- **Memory fragmentation and slow growth:** resident memory creeps up over days even without a leak in application logic.
- **CPU throttling:** a container with a CPU quota may be throttled for part of each scheduling period even when average usage is below the limit, especially with many threads; this shows up as periodic latency spikes. Look at throttling metrics, not just CPU percent.
- **Thread and connection pool sizing vs. cores:** too many threads cause context-switch overhead; too few cause queuing; blocking calls in limited event-loop threads stall everything.
- **NUMA and huge-page effects** on large hosts (latency spikes from memory compaction or remote memory access).
- **Swap:** a little swap can avoid a crash but causes extreme latency; no swap causes abrupt kills. Decide deliberately.
- **Noisy neighbors on shared hardware:** CPU steal time, shared cache, and shared I/O cause unexplained jitter.
- **Startup costs:** JIT warm-up, cache warming, connection establishment; a freshly started instance is slower than a warmed one, and receiving full traffic immediately can overwhelm it (ramp-up or slow start is often needed).
- **Autoscaling based on CPU for I/O-bound or memory-bound workloads** scales too late or never.

### 21.3 Storage and filesystems: hidden behaviors

- **Durability vs. speed:** a write returning from the application does not mean data is on stable storage; flush behavior depends on code, filesystem, device, and virtualization.
- **Free space vs. file handles:** deleted files that are still held open by a process continue to occupy space. `df` and `du` disagree. Log rotation without signaling the process to reopen logs is a classic cause.
- **Reserved blocks, percentage full performance cliffs:** filesystems and databases perform worse as they approach full, and some become read-only on errors.
- **Snapshots consume space** as data changes; a forgotten snapshot slowly fills the volume.
- **Network-attached disks have throughput and IOPS caps** separate from capacity, often shared per instance and per volume, with burst allowances (Case 12).
- **RAID rebuilds and replacement:** performance drops during rebuild, and the rebuild stresses the remaining disks, raising the chance of a second failure (especially if disks came from the same batch and age).
- **SSD behavior:** write amplification and internal garbage collection cause sudden latency spikes as drives fill; wear limits.
- **Silent corruption:** without end-to-end checksums and scrubbing, you will not know until you read the data, possibly after backups have aged out.
- **Object storage semantics:** listing may be eventually consistent or expensive; overwriting, versioning, and lifecycle rules can delete or hide data; a lifecycle rule with the wrong prefix deletes the wrong things; per-prefix request rate limits; deleting versioned objects; accidental public access.
- **Local disk in cloud instances is often ephemeral:** data vanishes on stop, replacement, or some failures.
- **Backups on the same volume or the same failure domain** as the data.
- **Log volume:** debug logging left on; log storms during incidents filling disks, which then breaks the application.

### 21.4 Time infrastructure

- NTP or time-sync failure allows drift; different hosts in different states.
- **Clock steps backward** break anything using wall clock for timeouts, rate limits, or ordering.
- Virtualization pauses and live migration cause jumps.
- **Skew vs. validity windows:** certificates (not-yet-valid), signed tokens, one-time-password codes, cloud request signatures, and authentication protocols with small skew tolerance all fail when clocks are off by minutes.
- **Leap second behavior** differs among time sources; mixing smeared and non-smeared sources creates inconsistent offsets.
- **Containers share the host clock,** so one host problem affects all.
- **Monitoring the clock itself:** alert on clock offset, not just "NTP running."

### 21.5 Deployment and release: subtle causes of incidents

- **Bugs visible only at mixed-version states:** with 50% old and 50% new, incompatibilities (message formats, cache formats, schema, API) appear that neither full state has.
- **Canary blind spots:** the canary sample is too small, sees atypical traffic, runs at a quiet time, hits different tenants, or skips rare code paths (monthly jobs, specific customers, specific regions).
- **Bake time shorter than failure time:** memory leaks that show at 6 hours, cache behavior at TTL expiry, daily cron, month-end batch, certificate renewal at 30 days.
- **Health checks that pass for broken builds** (the app starts but a critical path is broken), so automated rollout continues.
- **Rolling deploy induced load:** restarting instances drops connections, empties caches, and creates reconnect storms; deploying all instances of a tier within a short window compounds it. Limit parallelism to what dependencies can absorb.
- **Rollback is also a deploy:** it takes the same time, has its own risks, and requires that previous artifacts and compatible data/config still exist.
- **Config deployed separately from code** with no version link, so they drift.
- **Database migration order vs. code order** (10.4), and migrations that run automatically at application startup on every instance simultaneously (race, lock contention).
- **Emergency changes bypassing the normal pipeline** and then never reconciled into code.
- **Multiple concurrent changes** make attribution impossible.
- **Changes by other teams or vendors** (platform upgrades, certificate rotation, network rules, cloud maintenance) that you did not schedule but that manifest as your incident. Keep a change calendar across the organization and ask "what changed?" across all layers.

### 21.6 Capacity planning: hidden arithmetic

- **N+1 redundancy means less than it sounds:** if three zones each run at 70% and one zone fails, the remaining two must absorb 105% of one zone's... more precisely, the load of three spread over two is 70% x 3 / 2 = 105% of capacity, which means overload. Usable capacity per zone must be low enough (about 66% for three zones) to survive losing one, with headroom left.
- **Failover capacity must exist at the moment of failure,** not be "requested then." Quotas, spare instance availability, and scale-up speed matter.
- **Dependencies must scale with you:** scaling the application tier 3x without scaling the database, cache, downstream services, and their connection limits just moves the failure.
- **Cache hit ratio dependence:** capacity planned around a 95% hit rate means the database sees 5% of traffic. If the hit rate drops to 80%, the database sees 4x more. A small change in hit ratio is a large change in backend load.
- **Retry amplification:** effective load = base load x (1 + retry rate x attempts) during trouble (Part 4.1 and 9.2).
- **Peak definitions:** average, p99, or "event day" peak? Marketing campaigns, holidays, batch schedules, end of month, and regional time patterns.
- **Growth compounding:** storage and traffic often grow faster than linear; time-to-exhaustion should be projected, not guessed.
- **Headroom for operations:** backups, reindexing, migrations, compaction, and failover rebuilds consume capacity; a system that cannot do maintenance under load will eventually skip it.

### 21.7 Hidden global and control-plane dependencies

List what each service needs **at startup** versus **at runtime** versus **to scale** versus **to deploy** versus **to recover**. Commonly forgotten items:
- Identity provider / SSO for engineers *and* for services.
- Secrets manager and configuration service (a service that cannot fetch secrets at boot cannot restart).
- Container/package registries and mirrors; base image sources.
- Certificate authorities and ACME endpoints; OCSP/CRL checks.
- DNS providers and registrars; time servers.
- Cloud control plane APIs (launching instances, changing routes, updating DNS).
- Feature flag and experimentation services.
- License servers and entitlement checks.
- Telemetry agents and log shippers (blocking or consuming resources when the backend is down).
- Third-party scripts in the client (analytics, payments widgets, chat) that can block page loads or break checkout.
- Partner IP allowlists (your egress addresses are in someone else's firewall rules).

**Question:** for each of these, what happens if it is unavailable for 10 minutes, at service start, during a deploy, and during an incident?

### 21.8 Bootstrapping and circular dependencies

Mature systems accumulate circular dependencies that only show up in a cold-start or total-failure scenario:
- DNS needs a config service that needs DNS.
- Authentication needs a database that needs credentials from a secrets service that needs authentication.
- The deployment system is deployed by itself; the monitoring system runs on the cluster it monitors; the runbooks live in a wiki hosted in the affected environment.
- After a full power or region loss, everything starts simultaneously and waits for each other, or overwhelms shared dependencies.

**Question: "Could we start the whole thing from nothing, in order, without any component that requires something not yet running?"** If nobody has tried, assume the answer is no. Document a cold-start order and test it in a non-production environment.

### 21.9 Disaster recovery: what actually fails

- **Replication lag** means the DR copy is behind by an unknown, variable amount; failing over accepts that loss.
- **Capacity in the DR region** may not exist or may be blocked by quotas; data is there but the compute is not.
- **Configuration and secrets** differ or are missing in DR; keys and certificates may not be replicated; encryption keys held in the failed region make replicated data unreadable.
- **DNS and traffic switching** depend on TTLs and client caching.
- **Third-party allowlists** contain only the primary's IPs.
- **Dependencies** (databases, queues, identity, payment providers, internal services) may themselves be only in the primary region.
- **Failover works, failback fails:** returning to the primary requires syncing back the writes made in DR, and risk of split brain. Often harder and more dangerous than the original failover.
- **Untested runbooks** with stale commands and missing access.
- **Human factors:** people are stressed, not all are reachable, and decisions ("do we fail over?") take long because no criteria were agreed in advance.
- **Partial DR:** some services fail over and some do not, leaving an inconsistent system.
- **RTO/RPO claims** are promises. If they were never measured in a drill, they are guesses.

### 21.10 Observability infrastructure: second-order effects

- **Pipeline delay:** metrics and logs are several minutes behind; alerts fire late. During a fast-moving incident you are looking at the past.
- **Evaluation windows and thresholds:** an alert requiring "5 minutes above threshold" misses a 4-minute outage that still damages users; a short window pages on noise.
- **Sampling and aggregation** hide rare or per-tenant problems; percentile aggregation across instances is not meaningful if done by averaging.
- **Monitoring from inside the same network/region** cannot see outages that affect users' path (DNS, CDN, routing).
- **Telemetry overhead:** agents consuming CPU and memory, synchronous logging and tracing slowing requests, log volume during errors amplifying the problem.
- **Cardinality costs:** a single mislabeled metric exploding storage; vendor rate limits dropping data during incidents, exactly when volume peaks.
- **Dashboards rot:** panels built for old architecture; missing new components; misleading units; inconsistent time ranges.
- **Alert dependencies:** if the paging provider, chat system, or phone network is down, the alert does not reach anyone; have a secondary channel and test it.
- **Silent data gaps:** a dashboard that shows a flat line because data stopped arriving looks "stable."

---

## Part 22: Second-Order and Emergent Failures

These arise from **interactions**, which no individual component review will reveal.

### 22.1 Safeguard interaction matrix

Every safeguard is a component with its own behavior. Pairs interact:

| Safeguard A | Safeguard B | Dangerous interaction |
|---|---|---|
| Client retries | Server timeout shorter than processing time | Work completes but client retries anyway: duplicates and load |
| Retries at several layers | No shared budget | Multiplicative amplification (3 x 3 x 3) |
| Circuit breaker | Retry logic | Retries open the breaker, which then blocks recovery traffic; or flapping open/closed |
| Health check | Deploy or load | Slow startup under load gets instances killed; all fail together |
| Autoscaler | Connection pool limits | Scale-up multiplies connections and kills the database |
| Autoscaler | Missing or delayed metrics | Scale-in on absent data; scale-out too late |
| Cache | Database failover | Cache warms from a lagging or different source; stale data cached |
| Rate limiter | Shared NAT/proxy IPs | Many legitimate users throttled as one |
| Rate limiter | Retries | Retried requests are counted and consume the remaining quota, locking out the real traffic |
| Failover | Async replication | Silent data loss accepted without anyone deciding |
| Backup | Replication | Deletion replicated instantly; backup has only recent state if retention is short |
| Logging | Disk space | Error storm fills disk, which kills the service that was already failing |
| Encryption key rotation | Caches and in-flight data | Old ciphertext unreadable, or new key not deployed everywhere |
| TTLs | Identical values | Synchronized expiry waves |
| Feature flag | Migration | Flag reverts code paths after data has moved to the new format |
| Timeouts | Deadlines | Inner timeouts longer than the outer: abandoned work |
| Queue | Autoscaler | Queue depth triggers scale-out; new workers overload the database that was the real bottleneck |
| Security controls (WAF, firewall) | Legitimate unusual traffic (big upload, batch) | Block during an incident or launch |

**Practice:** when adding any safeguard, write down "how does this fail, what does it do to everything else, and how does it behave *during* an incident?"

### 22.2 Emergent synchronization

Independent components accidentally align, producing spikes:
- Cron jobs at the top of the hour or midnight.
- Identical TTLs set at the same moment.
- Tokens issued at login with the same lifetime expiring together.
- Clients retrying at fixed intervals after a shared outage.
- Mobile apps refreshing on the hour; scheduled emails or push notifications sent to everyone at once.
- Health checks from many nodes polling at the same time.
- Periodic batch processes (billing, reports, backups, compaction) overlapping.

**Defense:** jitter everywhere you schedule, spread work deliberately, and look at load charts with fine time resolution for unexpected periodicity.

### 22.3 Destructive automation acting on bad input

Automation that *removes or changes* things is the most dangerous when its input is wrong and it cannot tell. The recurring shape is **"empty or partial input is treated as a valid truth."**

```
# cleanup job (dangerous)
valid_ids = fetch_active_ids_from_service()     # service was down: returns []  (or a truncated list)
delete from cache/storage/records where id not in valid_ids    # deletes everything
```

Variants: an autoscaler seeing no metrics and scaling to zero; a reconciler concluding all resources are "orphaned" because the inventory API timed out; a sync job treating a failed export as "everything was deleted at the source"; a deployment tool destroying resources missing from an incorrectly loaded config; a retention job using a null or zero cutoff; an infrastructure plan with an unset variable.

**Root causes:** B (no distinction between "empty" and "unknown/failed"), E (unknown outcome treated as a definite answer), C (no invariant guarding the size of destructive actions).

**Defenses:**
- Distinguish "I got an empty result" from "I failed to get the result," and abort on the latter.
- **Sanity limits on destructive operations:** refuse to delete more than X% or N items in one run without explicit human approval; compare to the previous run's counts.
- Soft-delete or quarantine first, hard-delete later.
- Dry-run output reviewed or compared against expectation; two-phase (plan, then apply).
- Require fresh and complete input (version, timestamp, checksum, expected count).
- Protect critical resources with independent deletion protection.

### 22.4 Recovery that causes the second outage

- **Catch-up storms:** after a dependency returns, all queued work and all retrying clients hit it simultaneously. Throttle recovery.
- **Cache refill storms** after restart or failover.
- **Replica rebuild** consuming the primary's I/O during an incident.
- **Mass reconnect** of long-lived connections (websocket, database, message broker).
- **Reprocessing a backlog** that overwhelms downstream systems, or creates duplicates (and thousands of emails or payments).
- **Manual "fixes"** (restart everything, flush the cache, rerun the job) that worsen the state. Runbooks should say what *not* to do, and recovery should be gradual (percentage-based ramp).

### 22.5 Reconcilers and cleaners with their own race conditions

- A cleanup job removing "orphaned" records while a creation flow is about to attach them (the record exists briefly before its parent link). Require a minimum age, or a second confirmation pass.
- A reconciler fixing the *wrong side* of a disagreement (overwriting the source of truth with the stale copy). Define direction explicitly and verify it.
- **Two automations fighting:** one scales up, one scales down; one restarts, one drains; one syncs A to B while another syncs B to A (an infinite ping-pong with changing timestamps).
- **Self-healing that hides a recurring fault:** automatic restarts mask a leak for months until the restarts stop being enough. Track the *rate* of automatic remediation as a health signal.

### 22.6 Observation changes the system

- Adding detailed logging, tracing, or health probing alters performance and can trigger the failure (or hide it: a "Heisenbug" vanishes when instrumented).
- Health checks that hit deep dependencies amplify load during trouble.
- Metrics scraping at high frequency on busy nodes.
- Debug endpoints or profilers left enabled in production.

---

## Part 23: Methods for Finding Unknown Unknowns

Checklists find known classes of problem. These methods help find classes you have not named.

### 23.1 Unsafe control action analysis (STPA-style)

Model the system as controllers (people, services, automation) that issue control actions (scale up, failover, retry, delete, deploy, approve) based on a believed state of the controlled process. For each control action ask four questions:

1. **Not provided** when needed (the failover never triggers).
2. **Provided when it should not be** (failover triggers on a blip; the delete runs on empty input).
3. **Provided too early, too late, or out of order** (scale-up after the spike is over; cancel before create).
4. **Applied too long or stopped too soon** (a lock held too long; a throttle released before recovery).

Then ask: *what does the controller believe, where does that belief come from, how stale or wrong could it be, and what feedback would correct it?* Many incidents are a controller acting on a wrong "process model": the autoscaler believing load dropped because the metric was missing, the operator believing they were in staging.

### 23.2 FMEA (failure modes and effects analysis)

For each component list: failure mode, effect on users, cause, current detection, current prevention, then score **severity, occurrence, and detectability** (each 1 to 10) and multiply for a risk priority number. The value is less in the number than in forcing a systematic walk through each component, and in the detectability column, which surfaces silent failures.

### 23.3 Fault tree analysis

Start from a top event ("customer charged incorrectly", "total outage", "data loss") and decompose with AND/OR gates into contributing events down to basic causes. OR gates show single points of failure; AND gates show the combinations that must align, and where one additional barrier breaks the chain. Useful for making "rare combination" failures visible.

### 23.4 Model checking and formal specification for concurrency protocols

For protocols where the risk is interleaving (locking schemes, leader election, distributed transactions, cache invalidation, idempotency state machines), a small formal model in a specification language plus an exhaustive state-space checker finds sequences of events that humans do not imagine (the lease-and-pause scenario, the cancel-before-create race). Even a one-page model of the core protocol often exposes bugs that extensive testing does not. You do not need to model the whole system, only the tricky protocol.

### 23.5 Stateful property-based and deterministic simulation testing

- **Model-based tests:** generate random sequences of operations (create, update, delete, retry, duplicate, reorder, crash) and compare the real system to a simple reference model; any divergence is a bug, and the tool shrinks the sequence to a minimal reproduction.
- **Deterministic simulation:** run the system with a controllable clock, network, and scheduler so that failures, delays, reordering, and crashes are injected from a seed; any failure is exactly reproducible.
- **Jepsen-style testing** for distributed data stores: inject partitions and clock skew while clients issue operations, then check the recorded history against the claimed consistency guarantees.

### 23.6 Production data archaeology (look for the weird rows)

Real data contains examples of every edge case your code never expected. Regularly run anomaly queries on production data (on a replica):

```
- amounts negative, zero, or above any plausible maximum
- dates before 2000, at epoch, or far in the future; updated_at before created_at
- strings with length 0, length above 99.9th percentile, leading/trailing whitespace, control or invisible characters, mixed scripts
- duplicates on fields that "must be unique" after normalization
- status values not in the documented list, or states that violate the state machine
- child rows whose parent is missing; parents with no children that should have some
- entities stuck in transitional states for longer than expected
- largest 20 tenants/users/objects and what their data shape looks like
- NULLs in columns that "should never be NULL"
- IDs or numbers near type limits
- rows where two fields disagree (shipped_at set but status not shipped)
```
Each oddity is either a bug already happening or a bug waiting for a trigger.

### 23.7 Differential and shadow techniques

- **Shadow traffic:** send real production requests to the new version in parallel and compare results, without returning them to users.
- **Differential testing:** run two implementations (old and new, or two parsers) on the same inputs and diff outputs. Differences reveal undocumented behavior that clients depend on.
- **Dual-run migrations:** compute results both ways and compare before switching over.
- **Replay of recorded production traffic or events** against new code in a safe environment.

### 23.8 Game days, chaos, and drills

Deliberately break things under controlled conditions: kill instances, add latency, cut a dependency, expire a certificate in staging, fill a disk, restore from backup, fail over a database under load, remove access for the primary on-call engineer, simulate clock skew, lose a zone, revoke a credential. Record what surprised you. Surprise is the finding. Practice the human side too: who declares the incident, who communicates, how decisions are made.

### 23.9 Code-reading for latent risk

Search the codebase and infrastructure definitions for constructs that correlate with hidden edge cases (see Part 25's smell list), and read the *absence* of handling: "what does this function do when the call fails?" often has no visible answer because there is no code for it.

---

## Part 24: Additional Worked Cases (Complex Root-Cause Chains)

### Case 14: The cleanup job that deleted everything

- **Symptom:** thousands of customer files missing.
- **Trigger:** the service listing active accounts timed out; the job received an empty list.
- **Proximate cause:** `delete where owner not in (active list)`, with an empty list, matched everything.
- **Contributing conditions:** the timeout was caught and converted to an empty result; no limit on deletion size; no soft delete; backups older than the most recent uploads.
- **Root causes:** **B** (empty vs. unknown not distinguished), **E** (unknown treated as a definite answer), **C** (no invariant bounding destructive actions), **K** (deletion job owned by nobody in particular, and reviewed as "a simple cleanup").
- **Class-level fix:** Part 22.3 defenses across *every* destructive automation, not just this one, plus an inventory of all such jobs.

### Case 15: The job that ran before its data existed

- **Symptom:** occasional orders never get confirmation emails; no errors.
- **Trigger:** under load, a worker picked up the job within milliseconds of enqueue.
- **Proximate cause:** the job was enqueued inside the transaction; the worker queried the order before the commit was visible, found none, and the handler treated "not found" as "nothing to do" and acknowledged the job.
- **Root causes:** **E** (ordering assumption: commit happens before consumption), **B** (missing state, with "not found" conflating "deleted," "not yet visible," and "never existed"), **H** (no metric for jobs that complete with "skipped").
- **Class-level fix:** outbox pattern or enqueue-after-commit with reconciliation; treat "not found" on first attempts as retryable for a bounded time; count and alert on skipped jobs.

### Case 16: The stale value that stayed for a day

- **Symptom:** a user's changed permission did not take effect for hours.
- **Trigger:** a read and an update raced around a cache invalidation (20.7).
- **Proximate cause:** a slow reader wrote the old value back after the invalidation.
- **Root causes:** **E** (ordering between database and cache operations assumed), **G** (cache silently part of the authorization path), **A** (assumed invalidation is atomic).
- **Class-level fix:** never authorize from a cache without a version check or short TTL; version-stamped cache writes; define and monitor maximum staleness for security-relevant data.

### Case 17: The lease holder that woke up late

- **Symptom:** two workers processed the same batch; a customer got two shipments.
- **Trigger:** a long garbage collection pause on the first worker.
- **Proximate cause:** the worker resumed and wrote after its lease had expired and been taken over.
- **Root causes:** **E** (belief about lease validity assumed current), **C** (the resource did not enforce ownership), **F** (memory pressure and pauses unobserved).
- **Class-level fix:** fencing tokens checked by the resource (18.2); idempotent shipment creation keyed by batch; GC pause metrics and alerts.

### Case 18: The month-end partition

- **Symptom:** all writes to the events table fail at 00:00 UTC on the first of the month.
- **Trigger:** a date.
- **Proximate cause:** no partition existed for the new month; the creation job had silently failed two weeks earlier.
- **Root causes:** **F** (time-triggered finite resource), **H** (the job's failure was not alerted; nothing monitored "partitions remaining"), **K** (job ownership lost when a team reorganized).
- **Class-level fix:** create partitions far ahead, alert on remaining runway (not on job success only), and add a default-partition safety net with an alert when it receives rows.

### Case 19: The region failover that could not connect to the bank

- **Symptom:** failover completes; payments fail in the new region.
- **Trigger:** a real regional outage.
- **Proximate cause:** the payment partner allowed traffic only from the primary region's egress IPs.
- **Root causes:** **G** (hidden external dependency on network identity), **J** (DR drills ran with test partners only), **K** (the allowlist was managed by another team and never part of the DR checklist).
- **Class-level fix:** inventory of every external party that holds our addresses, keys, or certificates; DR drills including real partner connectivity (or their sandbox with equivalent controls); contact paths for emergency changes.

### Case 20: The revenue report that was 3x too high

- **Symptom:** finance reports revenue triple the bank deposits.
- **Trigger:** a new join added to the report for "product category."
- **Proximate cause:** the order total was joined to order items before summing, multiplying each order total by its item count.
- **Root causes:** **B** (grain of the data not defined: one row per order vs. per item), **J** (no reconciliation test against an independent total), **H** (no automated comparison of report total to ledger).
- **Class-level fix:** state the grain of every dataset; aggregate at the right level before joining; automatic reconciliation of key totals against an independent source with tolerance alerts.

### Case 21: The disk that filled because of a dead consumer

- **Symptom:** the primary database went read-only; disk full.
- **Trigger:** a change-data-capture connector was decommissioned months earlier, but its replication slot remained.
- **Proximate cause:** the primary retained logs for the abandoned slot indefinitely.
- **Root causes:** **F** (unbounded retention for a consumer), **G** (a downstream consumer's state controls the primary's storage), **H** (no alert on retained bytes per slot), **K** (decommissioning checklist did not include the source-side cleanup).
- **Class-level fix:** limit retained log size per slot where supported, alert on slot lag and inactive slots, and include source-side resources in every decommission procedure.

### Case 22: The scale-out that killed the database

- **Symptom:** traffic spike, autoscaler adds 40 instances, database becomes unavailable.
- **Trigger:** marketing email.
- **Proximate cause:** each new instance opened its full connection pool, exceeding the database connection limit; existing healthy instances also failed to get connections.
- **Root causes:** **F** (shared finite resource, no global budget), **G** (application tier and database coupled through connections), **D** (autoscaler's contract ignores downstream capacity).
- **Class-level fix:** a pooler with a global cap, pool sizes derived from the database limit divided by maximum instance count, max-instances limit on the autoscaler tied to downstream capacity, and load shedding at the edge.

### Case 23: The feature flag that was not a rollback

- **Symptom:** after disabling a newly released feature, pages crashed for users who had used it.
- **Trigger:** turning the flag off.
- **Proximate cause:** data written in a new format while the flag was on could not be read by the old code path.
- **Root causes:** **I** (irreversibility hidden behind a reversible-looking control), **E** (old and new data coexisting), **J** (rollback of the flag never tested with real data).
- **Class-level fix:** classify flags as *pure code* (safe to revert) versus *data-changing* (needs compatibility plan), make readers tolerant of both formats first, then enable writers.

---

## Part 25: More Categorization Tools

### 25.1 Category by where the knowledge gap lives

A different angle on "why was this missed?" is **whose knowledge would have been needed**:

| Gap | Meaning | Remedy |
|---|---|---|
| **Domain gap** | Business reality (legal rules, accounting, physical processes) not understood by engineers | Involve domain experts in modeling and review; write down business invariants |
| **Platform gap** | Behavior of database, runtime, cloud, network, kernel not known | Read internals docs, run experiments, verify defaults, make platform knowledge a review role |
| **Interaction gap** | Each part understood, combination not | Interaction matrix (22.1), end-to-end tests, game days |
| **Scale gap** | Only visible at real volume or skew | Production-shaped data, soak tests, capacity math |
| **Time gap** | Only visible after days, months, or at a date | Expiry inventory, soak tests, long-horizon thinking |
| **Adversary gap** | Only visible to someone intentionally hostile | Threat modeling, red-team review |
| **Human gap** | Only visible under stress or turnover | Drills, guardrails, documentation, rotation |
| **Organizational gap** | Falls between teams or owners | Explicit ownership of boundaries, cross-team reviews |

### 25.2 Category by trigger type

- **Input-triggered** (specific data).
- **Volume-triggered** (scale or skew).
- **Concurrency-triggered** (interleaving).
- **Failure-triggered** (dependency or hardware fails).
- **Time-triggered** (dates, expiry, counters).
- **Change-triggered** (deploy, config, migration, upgrade).
- **Load-pattern-triggered** (synchronization, bursts, feedback).
- **Adversary-triggered.**
- **Human-triggered** (wrong command, wrong environment).
- **Silent accumulation** (no trigger, just growth).

Because triggers are nearly random while root causes are structural, use this list to *generate* test and drill scenarios, and the root-cause families to decide *what to fix*.

### 25.3 A severity weighting for subtle failures

Standard severity scales underweight the failures that matter most in complex systems. Add these multipliers when ranking:
- **Silent and permanent:** x3 (no natural discovery time, damage accumulates).
- **Irreversible:** x3 (cannot be fixed after discovery).
- **Affects recovery ability** (backups, access, monitoring, deploy tools): x3 (turns any future incident into a disaster).
- **Correlated across replicas/regions:** x2 (redundancy does not help).
- **Compounding with time** (grows the longer it runs): x2.
- **Touches money, legal, or safety:** x2.
Then compare with likelihood. A rare event with several of these multipliers usually outranks a common, loud, reversible one.

### 25.4 Risk register fields

```
risk id / title
scenario (one sentence: trigger -> mechanism -> harm)
root cause family (primary, secondary)
categories (impact, manifestation, detectability, reversibility, blast radius)
existing controls (prevent / detect / limit / recover) and evidence they work
residual risk and decision (mitigate / accept / transfer / avoid)
owner, date decided, review date, expiry of any "temporary acceptance"
leading indicator (what would show it growing)
test or drill that verifies the control
```

---

## Part 26: Code and Design Smells That Signal Hidden Edge Cases

Patterns to search for in code review and in configuration. None proves a bug; each is a prompt to ask "what happens when this assumption fails?"

**In code**
- Comments or names containing *"should never happen"*, *"assume"*, *"just"*, *"temporary"*, *"TODO"*, *"for now"*, *"hack"*.
- `catch` that logs and continues; `catch` that returns a default; catch-all handlers.
- A fixed `sleep` used to wait for something to be ready.
- A fixed retry count with no backoff, or an infinite retry loop.
- No timeout on a network, lock, or queue operation.
- A hard-coded limit (`LIMIT 1000`, buffer size, batch size) with no handling of "more than that."
- `LIMIT 1` or "first row" without an explicit order.
- Picking "the first" or "the only" item from a collection that could be empty or have several.
- `SELECT *`, or an unbounded `SELECT`.
- Check-then-act (`if not exists: create`, `if balance >= x: subtract`).
- Read-modify-write without a version or atomic operation.
- Current time obtained inline in business logic (`now()` deep inside), making behavior untestable and zone-dependent.
- Building SQL, paths, URLs, or commands by string concatenation.
- Copy-pasted blocks that differ slightly.
- Boolean parameters (especially several) that change behavior.
- Functions with side effects and a name that suggests a query (`getX` that creates).
- Mutable global or static state in request-handling code.
- Loops containing I/O (database calls, API calls, file operations).
- Nested loops over data that can grow.
- Swallowed or ignored return values and error codes.
- Comparing floats, money, or times with equality.
- Conversions between numeric types or units without explicit range checks.
- Special values (`-1`, `0`, `""`, `"N/A"`, `9999-12-31`) used as "none."
- String status values compared by literal text in many places.
- Code that "cleans up" or deletes based on a computed list.

**In schemas and queries**
- Nullable columns with no documented meaning for NULL.
- Status columns without a check constraint.
- `NOT IN` with a subquery; `COUNT(*)` where `COUNT(col)` is meant (or vice versa).
- Joins without consideration of cardinality; `DISTINCT` added to "fix" duplicate rows.
- Missing foreign keys, or foreign keys without supporting indexes.
- Unique rules implemented only in application code.
- Functions applied to indexed columns in `WHERE` clauses.
- `OFFSET` with large values; unbounded `IN` lists.
- Soft-delete flags with no partial-unique handling.
- Timestamps without zone; integer 32-bit keys on growing tables.
- Free-text JSON columns holding structured, queried data.

**In infrastructure and configuration**
- Default timeouts, default pool sizes, default retry settings left unexamined.
- `latest` image tags; unpinned dependency versions.
- Identical TTLs, schedules at round times, identical intervals across components.
- Resources without limits (memory, CPU, disk, queue depth, log retention).
- Alerts with no owner, no runbook, or muted "temporarily."
- Health checks that test only that the process is alive.
- Manual steps in runbooks that say "run this command" with no safeguards or environment verification.
- Single instances, single zones, single accounts, single keys, single people.
- Secrets or certificates with no recorded expiry.
- Backups with no restore test date.
- A destructive command that looks identical to a safe one.
- "Temporary" exceptions with no expiry date.

---

## Part 27: Additional Deep Question Bank (By Theme)

**On time and ordering**
- Which clock does this use, and what if it jumps?
- If two events happen "at the same time" on two machines, how do we decide the order, and what do we lose if we are wrong?
- What is the maximum time a node or client can be away and safely return?
- What happens if a delayed message arrives after its effect was superseded?

**On ownership and enforcement**
- If the holder of this lock or lease pauses for a minute, who stops it from acting?
- Who is allowed to write this data, and does the data store enforce it or only our code?
- If the automation is wrong, what limits the damage it can do in one run?

**On unknown versus empty**
- Does this code distinguish "no results," "failed to fetch," "not yet available," and "not applicable"?
- What happens downstream if this list is empty? If it is truncated? If it is stale?

**On interactions**
- How do our retries, timeouts, caches, pools, autoscalers, and health checks behave together during a slowdown?
- What load does recovery itself create?
- Which two protective mechanisms could work against each other?

**On data**
- What is the grain of this table or report (one row per what)?
- What do we do with data that arrives late, twice, out of order, or corrected later?
- What does "deleted" mean here, and where else does the data still live?
- Is this number reconcilable against an independent source, and is it reconciled?

**On scale and limits**
- What is the largest customer's version of this, and what does it do to the shared system?
- Which resource hits its limit first, and what is the failure mode at that limit (error, slowdown, silent drop, crash)?
- How long until this runs out, and does anything alert before then?

**On change**
- What state can data be in during this change that neither old nor new code expects?
- Is this control (flag, config, rollback) truly reversible once data has been written?
- What changed outside our team that we would not know about?

**On recovery**
- Can we start, restore, and operate from nothing without any circular dependency?
- What does recovery require (access, tools, people, network, third parties), and does any of it depend on the failed system?
- When did we last do this for real, at realistic scale, with the people who would actually be on call?

**On people**
- What would a capable, tired engineer under pressure plausibly do wrong here, and what stops them?
- Who would notice if this silently stopped working, and how soon?
- What knowledge is in one person's head, and what happens if they are unreachable?

**The hardest questions (worth asking of any critical system)**
1. What is the worst thing one bad input, one bad deploy, or one bad automation run can do, and what bounds it?
2. What would we do if we discovered today that our data has been subtly wrong for the last three months?
3. What is our most dangerous "it has always worked" assumption?
4. What would fail first if traffic, data, or customers grew tenfold overnight, and would we see it coming?
5. What are we relying on that nobody on the team could rebuild or explain?

---

## Part 28: Additional Principles (Extending Parts 8 and 17)

29. **Empty is not the same as unknown.** Design APIs, jobs, and automation to distinguish them, and never let "unknown" drive a destructive action.
30. **Bound the blast radius of every automated action** (maximum items, maximum percentage, rate of change), especially deletions, scaling, failovers, and reconciliations.
31. **Protection belongs at the resource,** not with the actor: fencing tokens, constraints, row-level policies, deletion protection, permission checks at the data boundary.
32. **Design for the pause.** Assume any process can freeze for seconds to minutes at any instruction.
33. **Treat time as data with a source, a type, and a failure mode** (instant vs. local time vs. duration vs. logical order).
34. **Make state transitions explicit and visible;** intermediate states are real and must be legitimate, observable, and time-limited.
35. **Everything that can expire, fill, rotate, or run out has an owner, a runway metric, and a rehearsal.**
36. **Stagger and jitter by default.** Synchronization is the natural tendency of independent systems.
37. **Prefer a slow safe recovery over a fast unsafe one;** ramp gradually, and plan for the catch-up load.
38. **Keep compatibility in both directions during transitions** (backward and forward), for code, data, messages, caches, and configuration.
39. **Reconcile against an independent source,** because a system cannot reliably audit itself with the same logic that might be wrong.
40. **Test with the ugliest real data and the most hostile realistic conditions,** then keep the weird cases as permanent fixtures.
41. **Question every default** (timeouts, limits, isolation levels, retry policies, sizes, time zones, collations, modes). A default is someone else's assumption.
42. **Make the dangerous path hard and the safe path easy,** in tooling, naming, environment cues, and approval steps.
43. **Record decisions to accept risk,** with an owner and an expiry. An accepted risk that is forgotten is an unaccepted risk.
44. **Assume your understanding is partial.** Build mechanisms (drills, differential tests, anomaly queries, production audits) that find what you do not know you do not know.

---

## Operational Verification Checklist

For the actionable distributed systems, locking, and infrastructure scale review checklist derived from Volume 3, see:
👉 **[Checklist 03: Distributed Systems & Infrastructure Scale](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/03-distributed-systems-and-infrastructure-checklist.md)**  
👉 **[Master Engineering Checklist Index](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/00-master-engineering-checklist.md)**