# Volume 5: Engine, Platform, and Runtime-Specific Edge Cases

Volumes 1 to 4 stay as they are. This volume continues from Part 44 and moves from general patterns to **the specific behaviors of common technologies**, because many disasters come from a platform doing exactly what it was designed to do while the team assumed something else. In the taxonomy of Part 25.1, this is the **platform gap**.

**How to read this volume.** Defaults, limits, and behaviors change between versions and managed-service offerings. Everything here is a **hypothesis to verify against your exact version and configuration**, not a guarantee. Part 54 gives a method for doing that cheaply.

---

## Part 44: Why Platform Knowledge Is a Root Cause

### 44.1 The mechanism

Every technology embeds design trade-offs: what it optimizes, what it sacrifices, and what it leaves to you. The edge cases live where your assumptions and its trade-offs disagree.

| Root cause | Platform form |
|---|---|
| **A** Hidden assumption | "A transaction means safe." "Replicated means durable." "Exactly-once means exactly once." |
| **B** Wrong model | Treating a cache as a database, a queue as a log, a search index as a source of truth |
| **D** Contract mismatch | The default timeout, ordering guarantee, or consistency level differs from what callers assume |
| **F** Unbounded resource | Internal structures (logs, slots, undo, pending lists, buffers) that grow silently |
| **H** Blindness | The internal metric that predicts failure (oldest transaction, consumer lag, pending entries) is not on any dashboard |

### 44.2 Five questions to ask of any technology

1. **What is it optimized for, and what does it sacrifice?** (Latency vs. durability, availability vs. consistency, throughput vs. ordering.)
2. **What does "success" actually mean when it returns?** (Written to memory, written to disk, replicated, applied, visible to readers.)
3. **What grows in the background that I do not control directly?** (Logs, versions, slots, buffers, tombstones, caches, connection state.)
4. **What happens at each limit?** Error, slowdown, silent drop, or crash.
5. **What does it do when a peer is slow rather than dead?**

### 44.3 The "documented but unread" problem

Most of what follows is in the official documentation. It is missed because documentation is read at setup time, when everything is small, and not again when scale, concurrency, or failure makes the behavior relevant. A useful habit: re-read the "limits," "caveats," "durability," and "high availability" pages of every critical dependency once a year, with an incident list in hand.

---

## Part 45: PostgreSQL

### 45.1 Isolation and concurrency behavior

- **Default is Read Committed:** each statement sees data committed before *that statement* began. A read-modify-write in application code can lose updates, and two queries in one transaction can disagree.
- **Repeatable Read is snapshot isolation:** no phantoms in this engine, but **write skew remains possible** (Part 10.1).
- **Serializable** uses a conflict-detection approach that can abort transactions with a serialization failure. **Your code must retry the entire transaction.** Serializable without a retry loop converts anomalies into user-visible errors.
- **Error codes to handle as normal outcomes:** serialization failure and deadlock detected. Both mean "retry the whole unit of work."
- **Row locking choices:** `SELECT ... FOR UPDATE` (exclusive), `FOR SHARE`, `FOR NO KEY UPDATE`, and `SKIP LOCKED` (job-queue pattern) and `NOWAIT`. A job queue using `SKIP LOCKED` is correct for claiming but still needs lease and stuck-job handling (Part 3.2).
- **An error inside a transaction aborts the whole transaction.** Catching a unique violation and continuing in the same transaction fails on the next statement unless you used a savepoint. ORMs that "handle duplicates gracefully" may hide this.
- **Advisory locks** are cheap mutexes, but session-level advisory locks are held until the session ends, and with a pooler in transaction mode they leak to other clients (Part 19.10).
- **Upsert (`ON CONFLICT`):** a single command cannot update the same target row twice (duplicate keys within one batch fail). Sequences advance even when the insert conflicts. `DO NOTHING` does not return the existing row unless you add handling.
- **`count(*)` is not free:** MVCC means every count visits row versions. Large exact counts are slow; decide when an estimate is acceptable.
- **Isolation is per transaction, not per session default:** ORMs and poolers may set it differently than you think.

### 45.2 MVCC, vacuum, and the quiet time bombs

Builds on Part 19.1.

- **Dead tuples** accumulate until cleanup. The oldest open transaction (or an abandoned prepared transaction, or a lagging replica with feedback enabled, or a replication slot) sets a horizon below which cleanup cannot proceed, **for the whole database**.
- **Transaction ID wraparound:** transaction IDs are a finite 32-bit counter compared modulo. Old rows must be "frozen" before the counter laps them. If freezing cannot keep up (blocked by long transactions, disabled or starved autovacuum, huge tables), the engine first warns, then forces aggressive anti-wraparound work, and near the limit refuses new write transactions until a manual fix completes. A related counter exists for multi-transaction row locks. **This is a months-to-years time bomb.** Monitor *age of the oldest unfrozen transaction* per database and per big table, and alert long before the limit.
- **Autovacuum tuned for small tables:** scale-factor thresholds mean a table with 500 million rows needs tens of millions of dead tuples before cleanup triggers. Hot large tables usually need per-table settings.
- **Autovacuum cancelled by conflicting locks:** frequent `ALTER TABLE` or lock-taking jobs can starve cleanup indefinitely.
- **Bloat:** space is reused inside the table but rarely returned to the operating system. Shrinking requires a rewrite (`VACUUM FULL` takes an exclusive lock for the duration) or an online repack tool.
- **Bulk update or delete** creates dead tuples equal to rows touched plus write-ahead log volume, index bloat, and replica lag.
- **Hint-bit and visibility map effects:** the first reader after a bulk load may write to pages, making a read-only query surprisingly write-heavy and slow.
- **Updates rewrite the whole row** (and every index entry unless the update is "heap-only"); wide rows and many indexes magnify write cost. Frequently updated columns in indexed positions defeat optimizations.
- **Replication slots:** an inactive slot retains write-ahead log indefinitely (Case 21). Newer versions allow capping retention per slot; verify and set it, and alert on retained bytes and inactive slots.
- **Temporary objects:** `work_mem` applies **per operation per connection**. A query with several sorts and hashes across many connections can multiply memory use far beyond the configured number and trigger an out-of-memory kill.
- **Out-of-memory kill of a backend** can force the whole server into crash recovery (all connections dropped) depending on configuration and platform.
- **Checkpoints:** the first write to a page after a checkpoint writes the whole page to the log (full-page writes), so log volume and I/O spike right after each checkpoint; poorly tuned checkpoints cause periodic latency saw-tooth patterns.

### 45.3 Schema changes and locks

Builds on Parts 10.3 and 10.4.

- **Most `ALTER TABLE` variants take the strongest table lock** briefly, but the lock must first *queue* behind every existing lock, and while queued it **blocks everything behind it**. Always set a short `lock_timeout` for DDL and retry (Part 10.3 pseudocode).
- **Adding a column:** with a constant default this is metadata-only in modern versions; a volatile default (random value, current time) or some type changes rewrite the table. Older versions behave differently. Verify for your version.
- **Changing a column type** usually rewrites the table and its indexes unless the change is binary-compatible.
- **`SET NOT NULL`** scans the table under a strong lock unless a validated check constraint already proves it (version-dependent). The safe sequence: add a `NOT VALID` check constraint, validate it (weaker lock, long-running but non-blocking for writes), then set NOT NULL.
- **Foreign keys:** adding one scans and locks both tables; add as `NOT VALID`, then `VALIDATE CONSTRAINT` separately.
- **Indexes:** `CREATE INDEX CONCURRENTLY` avoids blocking writes but takes longer, cannot run inside a transaction block, and **can fail leaving an invalid index** that still costs writes until dropped. Always check for invalid indexes after a failure.
- **Dropping a column** is fast (metadata) but irreversible in practice and breaks old code instantly.
- **DDL is transactional** (a strength): you can test a migration's effects atomically. But DDL inside a long transaction holds locks for the whole transaction.
- **Renames** are instant and break every old reference at once (Part 10.4 safe sequence).
- **Enum types:** adding values has had restrictions inside transactions in some versions, and removing values is not supported; old app code may not know new values.
- **Table partitioning changes** (attaching partitions, detaching) have their own lock behaviors, with concurrent variants in newer versions.
- **Migration tools** that wrap every migration in one big transaction hold locks for the duration. Decide per migration.

### 45.4 Identity, types, and data correctness

- **Sequences are not transactional and not gapless:** values are consumed by rolled-back inserts, conflicting upserts, cached sequence blocks, and some crash scenarios. Never use them for gapless numbering (invoices).
- **`serial`/32-bit integer keys** overflow at about 2.1 billion. Changing a huge primary key's type is a rewrite. Foreign key columns must match.
- **Commit order is not sequence order** (Part 10.5). Consumers polling by `id >` can skip rows.
- **NULL handling:** by default, NULLs are distinct in unique indexes (multiple NULLs allowed); newer versions offer an option to treat them as equal. `NOT IN` with NULLs (Part 3.1). `NULLS FIRST/LAST` defaults differ by sort direction.
- **Timestamps:** `timestamptz` stores an absolute instant and renders it in the *session* time zone; `timestamp` (without zone) stores a bare value with no zone meaning. Mixing them, or relying on server default zone, produces off-by-hours bugs. Intervals like "1 month" are calendar-dependent.
- **Text:** `varchar(n)` counts characters; fixed-width `char(n)` pads; `text` has no limit other than a very large one. Collation changes (especially operating system library upgrades) **can silently invalidate existing text indexes**, causing missed rows and broken uniqueness. Treat library and locale changes on database hosts, and replicas built on different OS versions, as risky, and rebuild or verify indexes afterward. Case-insensitive uniqueness needs `lower()` indexes or a case-insensitive type or collation.
- **Numeric:** `numeric` is exact but slower; `float` is approximate; `money` type has locale-dependent behavior. Overflow raises errors, but implicit casts in expressions can surprise.
- **JSON vs JSONB:** `jsonb` normalizes (drops duplicate keys, reorders), `json` preserves text. Large integers through JavaScript clients lose precision (Part 11.1).
- **`LIKE` and pattern indexes:** a normal index does not help `LIKE 'abc%'` in non-C collations unless a pattern operator class is used; trigram indexes help infix search.
- **`DISTINCT`, `GROUP BY`, and join fan-out** (Part 19.13): `DISTINCT` masks duplicate problems.
- **`ORDER BY` without a unique tiebreaker** is nondeterministic across executions and plans, and `LIMIT` without `ORDER BY` returns arbitrary rows.
- **Triggers and rules:** hidden behavior, firing per row in bulk operations, order by name, and surprising interaction with `COPY`, replication, and partition routing.
- **Generated columns and expression indexes:** expressions must be immutable; functions depending on time zone or locale cannot be used safely.
- **Extensions and version coupling:** extension upgrades, and major version upgrades changing planner behavior (test plans on your real data before upgrading).

### 45.5 Planner and statistics (Part 19.5, specifics)

- **Generic vs. custom plans for prepared statements:** after several executions the engine may switch to a generic plan if it looks no worse on average than custom plans, which can be dramatically wrong for skewed parameters. A behavior change "for no reason" after the fifth execution is a classic symptom. There is a setting to force custom or generic plans.
- **Correlated columns:** create extended statistics (multi-column, dependencies) for columns that move together.
- **Stale statistics after bulk loads:** run `ANALYZE` after large loads and migrations, and consider explicit analyze in batch jobs.
- **Planner cost settings** are often left at defaults tuned for spinning disks; on fast storage they favor wrong plans.
- **Join order limits** with many tables: the planner stops exhaustively searching beyond a threshold, producing inconsistent plans for very large joins (common with ORM-generated queries).
- **CTEs:** behavior differs by version (materialized by default in older versions, inlined in newer unless marked). Query behavior and performance changed when upgrading.
- **Partition pruning** fails when expressions or casts hide the key; parameterized queries need runtime pruning, which varies.
- **`SELECT ... FOR UPDATE` with joins and `LIMIT`** can lock more or fewer rows than expected.
- **Index-only scans** depend on the visibility map, which depends on vacuum. A table with stale vacuum state silently loses index-only performance.
- **Monitor with the statement statistics extension and automatic slow-plan logging**; alert on plan regressions for load-bearing queries.

### 45.6 Connections, poolers, and replication

- **One process per connection:** each connection costs memory and scheduling overhead. Thousands of direct connections degrade performance even when mostly idle. A pooler is usually required; size against **(instances x pool size)** (Case 22).
- **Pooler modes:** in transaction mode, session state (session settings, `SET`, temp tables, session advisory locks, listen/notify, and historically prepared statements) is unsafe. Verify pooler and driver versions for prepared-statement support.
- **Timeout triad:** set `statement_timeout`, `lock_timeout`, and `idle_in_transaction_session_timeout` at role or database level, and deliberately override them for maintenance and migration roles.
- **Streaming replication is asynchronous by default:** a failover can lose the un-replicated tail. Synchronous modes trade latency and availability for zero loss, and a synchronous standby that goes away can **stall all commits** unless configured with fallback behavior. Choose deliberately and document (Part 18.3).
- **Hot standby query conflicts:** long queries on a replica are cancelled or delay replay (configurable). Feedback from the replica can retard cleanup on the primary. Dedicate separate replicas to long analytics.
- **Logical replication and change data capture:** replication identity needed for updates and deletes (tables without a primary key cause errors or full-row identity overhead); DDL is not replicated automatically; sequences are not replicated; large transactions delay streaming; slot management (45.2).
- **Promotion and timeline divergence:** the old primary cannot simply rejoin after promotion; it must be rewound or rebuilt. Fence it first (Part 18.3).
- **Backups:** base backup plus continuous log archiving gives point-in-time recovery, but **a failing archive command silently lets the primary's log directory fill**, and a gap in the archive breaks recovery after that point. Monitor archive lag and failure, and restore-test PITR (Part 10.9).
- **Logical dumps** are consistent snapshots but slow to restore on large databases; restore time can be days. Know the measured restore time.
- **Major version upgrades** require dump/restore or upgrade tooling; extensions, collations, and planner behavior change; replicas are not rolled simultaneously. Rehearse with production-sized data.
- **Managed service behaviors:** forced minor-version maintenance, parameter changes needing restarts, storage that can grow but not shrink, failover with DNS changes and dropped connections, superuser restrictions affecting your tooling and migrations. Test failover with your actual driver and pool (Part 10.8).

---

## Part 46: MySQL (InnoDB) and Relatives

### 46.1 Isolation, locking, and surprising reads

- **Default Repeatable Read** with **consistent (snapshot) reads for plain `SELECT`** but **current reads for `UPDATE`, `DELETE`, and `SELECT ... FOR UPDATE`**. Within one transaction, a plain select and an update can see different versions of the same rows, so "I read it, it was X, and then the update affected a row I never saw" is normal behavior.
- **Next-key and gap locks:** range conditions lock gaps between index records to prevent phantoms. This blocks inserts into ranges that look unrelated and is a leading cause of deadlocks in insert-heavy workloads. Changing the isolation level to Read Committed reduces gap locking (with binary log format implications; verify).
- **Missing index on a locking query** can lock every scanned row (or the whole table), turning a selective update into table-level contention.
- **Deadlocks are routine,** particularly with unique-key inserts and concurrent upserts; retry the whole transaction.
- **`INSERT ... ON DUPLICATE KEY UPDATE`** with multiple unique keys updates whichever row conflicts first, and can consume auto-increment values. `REPLACE` deletes then inserts, which fires delete triggers, changes the auto-increment and cascades foreign keys.
- **Autocommit:** each statement commits unless a transaction is opened. Code assuming a transaction spans several statements may be in autocommit mode.
- **DDL is not transactional:** most DDL statements cause an implicit commit; a failed migration halfway leaves a partial schema with no rollback.

### 46.2 Metadata locks and online DDL

- **Metadata lock queue:** like Part 10.3 but very pronounced: a long-running transaction (even an idle one that once read the table) holds a metadata lock; an `ALTER` waits for it; all new queries on the table queue behind the `ALTER`. Set a short lock wait timeout for DDL and check for open transactions before running.
- **Algorithms:** `INSTANT` (metadata only, limited operations), `INPLACE` (no full copy but may still be heavy and need a brief lock), and `COPY` (full table copy, blocks writes). Specify the algorithm and lock explicitly so the statement **fails instead of silently choosing a blocking method**. Which operations qualify depends on version.
- **Replicas apply DDL serially:** a long `ALTER` on the primary replays on each replica, stalling replication for the duration (and lag grows). External online-schema-change tools exist to mitigate this, with their own edge cases (triggers, foreign keys, cutover locks).
- **Disk space:** rebuilds need temporary space roughly the size of the table.
- **Changing character set or collation on large tables** rewrites them and can change uniqueness and comparisons.

### 46.3 Keys, storage layout, and identity

- **Clustered primary key:** rows are stored in primary-key order, and **every secondary index entry contains the primary key**. A wide primary key (long string, composite) bloats every index. A random primary key (random UUID) causes page splits, fragmentation, and poor cache behavior; time-ordered keys or an auto-increment surrogate behave better.
- **Tables without an explicit primary key** get a hidden one; replication and some tools behave poorly.
- **Auto-increment:** gaps from rollbacks, failed inserts, and bulk inserts; historically the counter could reset after a restart in older versions (persisted in newer versions; verify). Exhaustion of signed 32-bit columns is a recurring outage.
- **Long transactions** make undo history grow; the purge lag slows reads that walk version chains. Monitor the history list length.
- **Large rows and off-page columns:** storing large text or blobs in frequently scanned tables harms cache efficiency; `SELECT *` pulls them.
- **`COUNT(*)`** scans an index; large exact counts are slow.
- **Foreign key cascades** do not fire triggers and can be long, locking operations; foreign keys require indexes on both sides.

### 46.4 Type and mode traps (strictness matters)

- **SQL mode:** strict modes turn silent truncation and invalid values into errors; non-strict modes silently truncate strings, clamp numbers, and accept invalid dates (including "zero dates"). Enforce a strict mode everywhere, including tests and scripts (Part 19.9). Also `ONLY_FULL_GROUP_BY` affects which queries are accepted.
- **Character sets:** the legacy 3-byte `utf8` alias cannot store 4-byte characters such as many emoji; use `utf8mb4` throughout (database, tables, connection, and client). A mismatch at any layer truncates or errors.
- **Collations:** default collations in recent major versions differ from older ones (case- and accent-insensitive, different trailing-space handling). Uniqueness and equality change accordingly: `'a'` and `'A'`, or `'a'` and `'a '` (depending on padding rules), may be "the same."
- **Implicit conversions in comparisons:** comparing a string column to a number converts the column to a number row by row, **disabling index use** and matching unexpected values (`'1abc'` converts to 1). Always bind parameters with the right type.
- **`TIMESTAMP` vs `DATETIME`:** `TIMESTAMP` is stored as UTC and converted using the session time zone, with a 2038 upper limit; `DATETIME` is a bare value. Automatic initialization and update defaults behave differently across versions.
- **`GROUP_CONCAT`** silently truncates at a session length limit (default is small).
- **Integer division and `DIV`, unsigned arithmetic underflow errors,** and `AUTO_INCREMENT` on unsigned columns.
- **Boolean** is a small integer; arbitrary values beyond 0 and 1 are accepted.
- **`ENUM`** ordering is by index not by text, adding values in the middle can rebuild the table, and invalid values in non-strict mode become an empty string.
- **Sorting and comparison of strings** depend on collation; moving data between servers with different defaults changes results.

### 46.5 Replication and durability

- **Durability settings:** full durability requires flushing the transaction log on each commit and syncing the binary log; relaxed settings can lose recently committed transactions on a crash. Know which profile production runs.
- **Replication is asynchronous by default,** with optional semi-synchronous modes that acknowledge receipt (not application) and fall back to asynchronous after a timeout. Failover after async replication can lose transactions and can leave **divergent replicas** when the old primary had committed transactions the new one lacks (errant transactions).
- **Binary log format:** statement-based logging replicates nondeterministic statements incorrectly (current time, random, `LIMIT` without `ORDER BY`, some functions), producing **silent replica drift**. Row-based logging is safer but produces more log volume for bulk updates.
- **Replica lag** from single-threaded apply (improves with parallel replication settings), long DDL, large transactions, and bulk deletes.
- **Reading from replicas after writes** (Part 9.8).
- **Binary log retention:** logs expire, and a replica or backup offline longer than retention cannot catch up and must be rebuilt.
- **Global transaction identifiers** simplify failover and repositioning but require consistent configuration.
- **Group replication and cluster variants:** flow control can throttle writers to the slowest member; network partitions cost you majority; certification conflicts surface as commit-time errors that applications must retry.
- **Managed service failover:** connection endpoints flip; caches of resolved addresses (Part 12.4) and pooled connections to the old primary are the usual cause of extended outage.
- **Backups:** logical dumps versus physical backup tools; consistent snapshots need coordination; binary log archives enable point-in-time restore; test restores (Part 10.9).

---

## Part 47: Redis and In-Memory Stores

### 47.1 The design facts that cause most incidents

- **Commands execute on essentially one thread.** One slow command blocks **all** clients. Dangerous: enumerating all keys, reading or deleting very large collections, `FLUSHALL`, long scripts, big sorted-set range operations, and heavy transactions. Use incremental scanning, background deletion variants, and bounded collections. Watch the slow log and latency monitoring.
- **It is a memory store:** memory is the capacity. Data structures have overhead, fragmentation grows over time, and replication and client output buffers add to the footprint beyond the dataset.
- **Persistence is optional and weak by default:** snapshot files can lose minutes of writes; the append-only log with per-second sync can lose about a second. "Always sync" is slower. Know which mode your data needs, and never treat a cache configuration as durable storage.
- **Snapshot and log-rewrite use a forked child:** copy-on-write means memory use can **nearly double under heavy writes** during the fork; fork latency grows with memory size and is slower on some virtualized platforms. A host sized exactly to the dataset gets killed at the worst time. Leave headroom.
- **Replication is asynchronous:** acknowledged writes can be lost on failover; the `WAIT` command narrows but does not eliminate the window. Settings such as minimum replicas to write reduce split-brain damage by refusing writes without replicas, at the cost of availability.
- **Sentinel and cluster failover** can promote a stale replica; a partitioned old primary accepts writes until it learns otherwise (Part 18.3). Those writes are discarded on rejoin.

### 47.2 Memory, eviction, and TTL semantics

- **Eviction policy determines what "full" means:** with no-eviction, writes start failing; with all-keys policies, **any key, including ones you consider persistent, can be evicted**; with volatile-only policies, only keys with expiry are candidates and, if none exist, writes fail. Mixing cache data and "real" data in one instance under an eviction policy is a data-loss design (Family B).
- **Expiry is lazy plus sampled:** expired keys may linger and still consume memory; a mass expiry at the same instant causes a spike of deletion work (synchronized TTLs, Part 20.7).
- **Setting a key again typically removes its TTL** unless you explicitly keep it. Code that updates a value with a plain set quietly converts a temporary key into a permanent one. Accumulating keys with no expiry is the classic slow memory leak.
- **Counter and expire are not atomic:** incrementing a counter and then setting its expiry as two commands leaves an immortal key if the process dies in between (rate limiters, dedupe keys). Use an atomic script, a combined command, or set expiry on creation.
- **Big keys and hot keys:** one huge hash or list causes latency spikes on access, on deletion, and during replication and persistence; one hot key saturates one node (and in a cluster, one slot).
- **Client and replication buffers:** slow consumers (pub/sub subscribers, replicas, monitor clients) accumulate output buffers; limits disconnect them, or memory balloons.
- **Type confusion:** counters are strings; operations on the wrong type raise errors; integer overflow raises errors at range limits.

### 47.3 Locks, scripts, and transactions

- **Simple lock pattern:** set-if-absent with expiry. Required details: a **unique token** per holder and a **compare-then-delete** release done atomically (script), otherwise a slow holder deletes someone else's lock after its own expired. Expiry shorter than the work means two holders (Part 18.2). This provides *efficiency* locking, not *correctness* locking; there are no fencing tokens. Multi-node lock algorithms remain debated for correctness-critical use because they depend on timing assumptions; for correctness, put the guarantee in the data store (constraint, version check, fencing token).
- **`MULTI`/`EXEC` is not a rollback transaction:** commands queued are executed in order, and a runtime error in one does not undo the others. Use optimistic `WATCH` with retry for check-and-set.
- **Scripts are atomic but block the server** for their duration; a long or accidentally looping script stalls everyone. Scripts touching keys across slots fail in cluster mode.
- **Persistence and scripts/replication interplay** differs by version; verify script determinism assumptions.

### 47.4 Cluster and client behavior

- **Key-to-slot mapping:** multi-key operations require all keys in the same slot (use hash tags deliberately); hash tags can create hot slots.
- **Resharding and slot migration** cause redirects and transient errors; clients must handle them and refresh topology.
- **A cluster with majority loss** stops serving the affected slots by default; partial availability settings change semantics.
- **Client pool issues:** blocking commands occupy connections; pool too small causes waits that look like Redis slowness; reconnect storms after failover; missing command timeouts; clients caching resolved addresses or topology.
- **Pub/sub is at-most-once with no persistence:** subscribers that are disconnected miss messages. Streams with consumer groups add persistence, acknowledgement, and a **pending entries list** that grows when consumers die without acknowledging; pending items must be reclaimed or they are stuck.
- **Memory-only caches as dependencies:** a restart empties the cache and the backend must survive the refill (Part 9.2, 20.7). Warm-up strategy and request coalescing need to exist beforehand.
- **Security defaults:** historically open on the local network without authentication; exposed instances are a frequent breach path (Part 35.3). Require authentication, network isolation, and disable or rename dangerous administrative commands where appropriate.

### 47.5 What to monitor

Used memory vs. limit and fragmentation ratio, evicted and expired key rates, slow log entries, latency spikes (including fork time), connected and blocked clients, replica lag and replication buffer size, persistence status (last save success, rewrite duration), keys without TTL (sampled), biggest keys (sampled), cluster slot state, and pending entries per stream group.

---

## Part 48: Kafka and Message Brokers

### 48.1 Log-based brokers (Kafka-style): the model matters

A topic is a set of **partitions**, each an append-only log. Consumers track offsets. Many misunderstandings follow from this.

**Ordering**
- Ordering is guaranteed **only within a partition**. "Ordered by key" works only if all messages for a key go to one partition.
- **Increasing the partition count changes the key-to-partition mapping** for the default partitioner: new messages for an existing key may go to a different partition than old ones, breaking per-key ordering across the change. Plan partition counts generously up front, or migrate with care.
- Retries can reorder messages within a partition unless producer settings limit in-flight requests or enable idempotence (see below).
- Multiple producers writing the same key have no defined order between them.

**Producer durability and duplication**
- Acknowledgement level: waiting only for the leader risks loss if the leader fails before replication; waiting for all in-sync replicas is safer, but **only as safe as the minimum in-sync replica setting and the replication factor**. With a replication factor of 3 and a minimum in-sync setting of 1, "all acknowledged" can mean one copy.
- **Unclean leader election** (allowing an out-of-sync replica to become leader) trades data loss for availability. Know your setting.
- **Retries without idempotence duplicate messages** (the first attempt succeeded, the acknowledgement was lost). Idempotent producers deduplicate within a producer session; newer client versions enable this by default (verify your client), but it does not deduplicate across producer restarts or application-level resends.
- **Send buffering and timeouts:** a full producer buffer blocks or errors; delivery timeout expiry means the outcome is **unknown** (Part 9.5). Callbacks ignored means silent loss.
- Message size limits at producer, broker, topic, and consumer must be consistent; oversized messages fail at one layer only.

**Consumers**
- **Offset commit timing defines your guarantee:** commit before processing gives at-most-once (a crash loses work); commit after processing gives at-least-once (a crash repeats work). Automatic periodic commit can commit offsets of messages still being processed, or fail to commit processed ones.
- **Processing slower than the poll timeout** gets the consumer removed from the group, triggering a rebalance; the messages are redelivered to someone else while the slow one may still be working: duplicate processing and a rebalance storm.
- **Rebalances pause consumption** (less so with cooperative protocols). Frequent deploys, autoscaling, and flapping consumers keep the group in constant rebalance, with lag growing and no errors.
- **Lag beyond retention = silent data loss:** if a consumer is down longer than the topic's retention, unread data is deleted. On restart, the offset-reset policy decides: skip to the newest (losing data) or restart from the oldest (reprocessing a large history, with duplicate side effects). Neither is safe by default; alert on lag in **time** (oldest unconsumed message age) and on time remaining before retention.
- **Parallelism is capped by partitions:** more consumers than partitions sit idle. Hot partitions (skewed keys) make one consumer the bottleneck.
- **Poison messages** block a partition (the consumer retries the same offset forever) unless you build dead-letter handling (Part 3.1). The broker does not provide one.
- **Head-of-line blocking per partition:** one slow message delays all later messages in that partition.
- **Commit and external side effects:** there is no atomicity between your database write and the offset commit (dual-write, Part 9.6). Store offsets or processed IDs in the same database transaction as the effect, or make processing idempotent.

**"Exactly-once" in this ecosystem**
- Transactional guarantees cover **read from Kafka, process, write to Kafka** atomically. They do not cover writes to an external database, emails, or HTTP calls (Part 9.7).
- Consumers reading only committed transactions can be **blocked by a long-open or hung transaction** (they cannot read past the earliest open transaction), causing unexplained lag.

**Broker-side hazards**
- **Retention by time or size deletes data regardless of consumption.** Setting retention to "forever" shifts the risk to disk.
- **Disk full on a broker** is severe; under-replicated partitions, reassignments, and rebuilds consume bandwidth and disk exactly during trouble.
- **In-sync replica shrinkage** under load or network problems reduces durability without alerting anyone unless you monitor under-replicated and under-minimum-ISR partitions.
- **Rolling restarts** must wait for replicas to rejoin the in-sync set between brokers; restarting the next broker too soon takes partitions offline.
- **Too many partitions** increase leader election time after failure, file handle counts, memory, and metadata size.
- **Partition reassignment** moves large data and can saturate network; throttle it.
- **Compacted topics** keep the latest value per key: a missing key makes messages rejected or mis-handled; **tombstones (deletes) are retained for a limited time**, so a consumer or replica offline longer than that misses the delete and resurrects the record (Part 18.6).
- **Time semantics:** message timestamps may be producer-supplied (bad clocks) or broker-assigned; consumers using them for windows, expiry, or ordering inherit the difference.
- **Schema evolution:** without enforced compatibility, a producer deploy breaks all consumers; use a registry with a compatibility mode, and consider the reprocessing direction (old data read by new code, Part 20.5).
- **Security and multi-tenancy:** topic-level access control, quotas per client so one producer or consumer cannot starve others, and encryption key handling.
- **Control plane dependencies:** metadata quorum health; the loss of it stops leader changes and administrative operations.

### 48.2 Queue-style brokers (SQS, RabbitMQ, and similar)

- **Standard cloud queues** typically offer at-least-once delivery with best-effort ordering; duplicates and out-of-order delivery are normal. **FIFO variants** add ordering per group and deduplication within a **limited window** (minutes), so a duplicate arriving after the window is not detected. Throughput limits and per-group head-of-line blocking apply.
- **Visibility timeout** must exceed worst-case processing time (or be extended by heartbeat), or messages are processed twice concurrently. When a cloud function consumes from a queue, the queue's visibility timeout should comfortably exceed the function's timeout (providers recommend a multiple; verify).
- **Receive count and redrive:** poison messages cycle until a maximum receive count moves them to a dead-letter queue. Set it; monitor the dead-letter queue depth and age; and know how to replay (replay carries duplicate and ordering risk). Dead-letter retention must be **longer** than the source queue's, or messages expire in the graveyard.
- **Maximum retention** (days) means a queue backed up past it loses messages silently.
- **Long polling vs. short polling,** empty receives costing money and causing false-empty reads on sharded implementations.
- **Message size limits** require the claim-check pattern (store payload elsewhere, send a reference), which introduces the payload's own lifecycle (who deletes it, what if it expires before processing).
- **RabbitMQ-style brokers:** messages delivered to a consumer that dies before acknowledging are requeued (possibly reordered, possibly duplicated); the prefetch setting determines how many unacknowledged messages one consumer hoards (a slow consumer with a large prefetch starves others); publishing to a nonexistent route can be **silently dropped** unless mandatory publishing or confirms are used; publisher confirms are needed to know a message reached the broker; queues without limits consume memory and trigger flow control that blocks publishers; memory and disk alarms block all publishing cluster-wide; clustering under network partitions needs an explicit partition-handling policy, and some policies choose availability with data divergence; unacknowledged messages on a stuck channel hold capacity; the choice between transient and durable queues and persistent messages matters after restarts.
- **Fan-out and subscription semantics:** a new subscriber does not see earlier messages on a topic exchange (or pub/sub) unless the queue exists beforehand; subscriber queues that nobody consumes from grow forever.
- **Delay and scheduling features** have maximum delays and precision limits; scheduled messages are lost if the broker's scheduling store is lost.
- **Ordering across retries:** a retried message arrives after later messages; consumers needing order must detect it (sequence numbers, versions; Part 18.1).

### 48.3 Broker-agnostic rules

Every consumer is idempotent (Part 11.6). Every queue has a maximum age policy and a dead-letter path with an owner (Part 18.8). Lag is measured in **time to drain** and **time to data loss**. Retention, visibility, and timeout settings are documented together with the worst-case processing time. Replays and backfills are throttled and deduplicated (Part 22.4).

---

## Part 49: Search Engines and Secondary Indexes (Elasticsearch-style)

### 49.1 Conceptual traps

- **A search index is a derived copy, not a source of truth.** It needs a rebuild path and a reconciler (Part 14.1). If the only copy of some data lives there, the model is wrong (Family B).
- **Near-real-time, not real-time:** writes become searchable after a refresh interval (about a second by default, configurable, and may be reduced or paused under bulk load). A user who saves and searches immediately may not see their change. Forcing a refresh per write is expensive at scale.
- **Get-by-ID is real-time; search is not,** so two lookups of the "same" data can disagree.
- **Replicas can return different results** for the same query (differences in segment state and relevance statistics between shards and copies), so scores and ordering can differ across requests unless you use a preference key.
- **Consistency with the database:** synchronization is a dual write or change stream. Missed events leave documents missing, stale, or ghosted. Out-of-order events overwrite new with old unless you use versions (external versioning) to reject stale updates.
- **Deletion:** deletes in the database must propagate; soft-deleted rows must be removed or filtered; permission changes must update the index (search leaking data the main path protects, Part 31.1).

### 49.2 Mapping, analysis, and schema

- **Dynamic mapping guesses types from the first document seen:** a field first seen as a number or date decides the type for the index; a later document with a string fails or is dropped. The first document can be an odd test or a malformed input. Prefer explicit mappings and strict or controlled dynamic behavior.
- **Mapping explosion:** user-supplied keys as field names create unbounded fields, exhausting cluster state and memory. Use key-value arrays or flattened types, and set field limits.
- **Existing field mappings generally cannot be changed;** analyzer changes, type changes, and sharding changes require **reindexing**. Design an alias-based zero-downtime reindex procedure early, and test how long a full reindex takes (it is a recovery-time figure).
- **Analyzers and normalization:** tokenization, stemming, case and accent folding determine matching. A query-time analyzer that differs from the index-time analyzer silently returns no results. Unicode and language-specific behavior (Part 20.2).
- **Keyword vs. text fields:** exact match, sorting, and aggregations need the right field type; sorting on analyzed text fails or uses expensive structures.
- **Field data and high-cardinality aggregations** consume heap; one unbounded aggregation can destabilize a node.

### 49.3 Shards, capacity, and failure

- **The number of primary shards is fixed at index creation** (resizing exists through split and shrink operations with restrictions). Too few prevents scale; too many (oversharding) wastes memory and slows cluster operations. A shard-per-tenant or shard-per-day design can create tens of thousands of shards and a cluster-state crisis.
- **Hot shards and routing skew** for large tenants or popular routing keys (Part 10.7).
- **Deep pagination:** from-plus-size windows are capped (by default ten thousand) and get expensive before that; use search-after cursors or point-in-time views, with the same consistency caveats as Part 11.7.
- **Heap pressure and garbage collection** (Part 21.2) cause long pauses that make nodes appear dead, trigger shard reallocation storms, and cascade.
- **Disk watermarks:** at progressively high disk usage the cluster stops allocating shards, then relocates them, and at the highest threshold marks indices **read-only** so writes fail; behavior on recovery differs by version. Alert well below the first watermark and keep capacity for rebalancing.
- **Split brain / quorum:** modern versions use a voting-based election; misconfiguring the number of master-eligible nodes (even counts, two-node clusters) still breaks availability.
- **Bulk API partial failure:** the HTTP response is successful even when individual items failed; ignoring the per-item results **silently loses documents** (Part 20.11). Check the errors flag and retry failed items selectively.
- **Backpressure:** write queues rejecting requests (rejected executions) under load; clients must back off, not hammer.
- **Snapshots:** repository misconfiguration, incompatible versions on restore, and restore times; test restore of the index *and* application behavior.
- **Query cost controls:** wildcard and regex queries with leading wildcards, scripts, and very large result or aggregation sizes; set limits and timeouts, and protect the cluster from user-controlled query shapes (Part 36.1).
- **Security:** historically exposed on open ports without authentication; exposed instances leak and are wiped by attackers (Part 47.4); field- and document-level security must match your authorization model.

---

## Part 50: Kubernetes and Orchestration, Additional Edge Cases

Extends Part 12.2 (probes, termination race, requests and limits, autoscaling).

- **Admission webhook deadlock:** a validating or mutating webhook configured to **fail closed** whose own pods are down (or cannot be scheduled because the webhook must approve their creation) blocks creation of pods, including the ones that would restore it. The same applies to policy engines, sidecar injectors, and certificate issuers. Scope webhooks to exclude their own namespace, and keep a documented break-glass path (Part 21.8).
- **Control plane store limits:** the cluster's key-value store has a size quota (default about two gigabytes, with recommended maxima); exceeding it makes the cluster read-only. Sources of growth: large objects, many events, custom resources, frequent status updates, leaked objects. Watch object counts by kind and size.
- **API server overload by your own controllers:** a reconcile loop that re-lists everything, a misbehaving operator hot-looping on an error, or thousands of watchers. Rate limits and backoff in controllers; priority and fairness settings protect critical traffic.
- **Reconciliation loops fighting** (Part 22.5): two controllers or a controller and a deployment pipeline both changing a field; configuration drift reverted endlessly.
- **Deletion edge cases:** objects stuck terminating because of finalizers whose controller no longer exists; namespace deletion hanging; persistent volume reclaim policy set to delete, making a mistaken claim deletion destroy the data; deleting a custom resource definition deletes every instance.
- **CronJobs:** missed schedules beyond a limit (when no starting deadline is set and more than a hundred runs are missed) stop the job from ever scheduling again until fixed; concurrency policy decides overlap (Part 11.5); time zone of schedule; history accumulation; jobs whose pods are evicted midway.
- **Jobs and retries:** backoff limits, pods that restart and rerun non-idempotent work, completion semantics, and orphaned pods after controller replacement.
- **StatefulSets:** ordered rollout can stall on one unhealthy pod; volume-zone binding prevents rescheduling into another zone; scaling down does not delete volumes (cost) and scaling back up reattaches old state (possibly stale).
- **Node failure handling:** a node becoming unreachable triggers pod eviction only after a default toleration delay (minutes); in between, stateful workloads may still be running on the isolated node while replacement pods start (a split-brain risk for single-writer volumes; storage and fencing behavior varies by driver).
- **Scheduling surprises:** pods without resource requests are scheduled as if they need nothing and are first to be evicted under pressure; priority and preemption let a high-priority deployment evict others; affinity and spread constraints can leave pods pending; disruption budgets can block node upgrades indefinitely or be ignored by forced deletions.
- **Configuration propagation:** values injected as environment variables are fixed at pod start (changes need a restart); mounted configuration files update eventually but **not when mounted via subPath**; applications must reload, and pods see changes at different times (mixed state, Part 20.6).
- **Networking:** endpoint propagation delay after readiness changes; DNS search-domain multiplication (Part 21.1); connection-tracking limits on nodes; service mesh sidecars adding startup ordering problems (application starts before the proxy is ready, or the proxy exits before the application drains), retries configured in the mesh **and** the application (amplification, Part 22.1), and mesh control plane as a dependency.
- **Autoscaling loops:** horizontal scaling on percentage of requested CPU interacts badly with low or missing requests; scaling on queue length without bounding downstream; vertical and horizontal autoscalers fighting; cluster autoscaler delays and node provisioning failures leaving pods pending; scale-down evicting pods running long jobs.
- **Upgrades:** API version removals break existing manifests and controllers when the cluster upgrades; kubelet and control plane version skew limits; node image changes; deprecations discovered at deploy time. Scan manifests against the target version before upgrading.
- **Multi-tenancy:** namespaces are an organizational boundary, not a security boundary without network policies, quotas, pod security controls, and access rules; shared nodes share kernels.
- **Secrets:** base64 is not encryption; default storage may be unencrypted at rest; any workload able to mount or read a secret can exfiltrate it; service account tokens granted by default.
- **Operational error:** wrong cluster or namespace context is the commonest destructive mistake. Make context visible in prompts, separate credentials per environment, and require confirmation for production deletion.

---

## Part 51: Cloud Provider Specifics (Patterns with Examples)

Names differ across providers; the pattern matters. Examples use commonly seen behaviors, all **to verify for your account and region**.

### 51.1 Load balancer and network edge

- **Idle timeout mismatch:** a managed load balancer with a default idle timeout (commonly around a minute) closes idle connections; if the backend's keep-alive timeout is *shorter*, the backend may close a connection at the same moment the balancer reuses it, producing sporadic 502 or 504 errors that are nearly impossible to reproduce. Make the backend keep-alive timeout **longer** than the balancer's idle timeout.
- **Deregistration delay and connection draining** on deploy: requests cut short if disabled or shorter than the longest request.
- **Slow-start / warm-up** for new targets; health check grace periods for slow booting instances.
- **Scaling behavior of managed balancers:** capacity scales with load over minutes; a sudden spike can see errors before scaling catches up. Load tests should include sudden steps, not only ramps.
- **Header and body size limits,** maximum request duration, and WebSocket idle limits differ from your application's assumptions (Part 12.3).
- **Client IP:** the original address arrives in a forwarded header; trusting it without controlling who can set it enables spoofing and breaks rate limits (Part 36.3).
- **Cross-zone traffic charges and latency,** and uneven zone distribution when zone-aware balancing is off.

### 51.2 Compute and storage behavior

- **Burstable instances and volumes:** CPU credits and storage burst balances; once exhausted, performance drops to baseline, sometimes weeks after launch (Case 12). "Unlimited" credit modes convert exhaustion into cost.
- **Ephemeral local storage** disappears on stop or hardware replacement.
- **Network and storage throughput caps** are per instance type and per volume, separate from capacity; a large disk on a small instance is still slow.
- **Instance retirement, spot or preemptible interruptions, and maintenance events:** graceful handling of a short termination notice; the workload must tolerate sudden loss (Part 11.3).
- **Capacity unavailability** of a specific instance type in a zone when you need to scale or fail over; diversify instance types and zones and keep capacity reservations for critical failover.
- **Snapshots and restored volumes:** restored block storage may load data lazily from the snapshot, making **initial reads slow** until blocks are warmed. A database restored from snapshot can look healthy and perform terribly at first (affects RTO assumptions; verify and pre-warm where supported).
- **Object storage:** strongly consistent for reads after writes in major providers today, but listing cost and latency, per-prefix request limits, lifecycle rules that delete (a wrong prefix or filter deletes the wrong data), versioning with delete markers (deleted objects that still cost money, or objects that are not actually gone), incomplete multipart uploads accumulating cost, public access configuration, and cross-region replication that copies deletions or lags.
- **Block storage detach/attach and zone binding:** volume cannot move across zones; failover needs replication or snapshot restore.

### 51.3 Managed databases

- **Failover mechanics:** typically a DNS endpoint flip after promotion, taking tens of seconds to minutes; existing connections drop; clients and pools that cache addresses or never retry extend the outage (Part 12.4 and 10.8). Test failover with real application drivers under load.
- **Synchronous standby for availability, asynchronous replicas for reads:** the standby in the same region is often synchronous and not readable; read replicas are asynchronous and can lag or stop.
- **Static parameters requiring a reboot,** maintenance windows applying patches and possible restarts, forced engine version end-of-life upgrades, and parameter group changes applied at different times.
- **Storage auto-scaling with cooldowns** and inability to shrink; storage full states that make the instance unusable.
- **Limits:** maximum connections derived from instance memory, IOPS ceilings, maximum table or database sizes, number of replicas, cross-region replication lag.
- **Restore creates a new instance** with a new endpoint; applications, secrets, security groups, parameter groups, and monitoring must be re-pointed; restore time for large datasets is hours.
- **Backups retention and deletion:** automated backups deleted with the instance unless final snapshot is configured; snapshots in the same account and region as the instance are vulnerable to the same mistakes or attacker (Part 35.3).
- **Serverless database variants:** scaling delays, cold starts after pause, connection limits, and cost surprises under steady load.

### 51.4 Functions and serverless

- **Concurrency limits** at the account and function level throttle silently or queue; a spike in one function can starve others sharing the account limit; reserved concurrency protects and also caps.
- **Retries:** asynchronous invocations retry automatically by default, so handlers must be idempotent (Part 11.6); event sources delivering from streams may retry a failing batch **forever, blocking the shard** (poison message, Part 48.1) unless bisect-and-discard or dead-letter settings are configured.
- **Timeouts:** maximum execution time, and partial work when the function is killed; queue visibility timeout must exceed it.
- **Database connections:** many concurrent function instances each open connections, exhausting the database (Case 22); use a pooling proxy and keep connection limits per instance minimal.
- **Cold starts** add latency spikes that interact with client timeouts and retries.
- **Payload, response, and temporary storage limits;** environment size limits; deployment package limits.
- **Statelessness assumptions:** global variables persist between invocations on the same instance (stale caches, leaked per-request data; Part 11.4) but not across instances.
- **Scheduled triggers** at round times across all customers (emergent synchronization, Part 22.2); at-least-once firing.
- **Cost:** recursive invocation loops (a function that triggers itself through a storage event or queue) can generate enormous cost within minutes; guard against recursion and set concurrency and budget limits.
- **Observability:** logs delayed or sampled; per-invocation tracing; cost of verbose logging.

### 51.5 Key-value and wide-column managed stores (DynamoDB-style)

- **Partition throughput limits and hot partitions:** adaptive capacity helps but does not remove hot key problems; throttling appears as errors that need exponential backoff with jitter.
- **Item size limits** (hundreds of kilobytes) and request size limits; large attributes require external storage.
- **Query design is schema design:** access patterns fixed in advance; scans are expensive and consume capacity; adding a new access pattern later may need a new index or table and a backfill.
- **Secondary indexes** are eventually consistent copies; **a throttled index can throttle writes to the base table**; index key choices can create hot partitions.
- **Reads default to eventually consistent** unless requested otherwise; conditional writes and transactions have limits on items, size, and cost.
- **Expiry (TTL) deletion is not immediate;** expired items can still be returned for some time (filter by timestamp in queries), and expiry deletions appear in change streams.
- **Change streams** have retention limits and at-least-once, possibly out-of-order, per-item semantics.
- **Pagination tokens** expire or become invalid; unbounded scans time out.
- **Global tables:** multi-writer conflict resolution (often last-writer-wins by timestamp, Part 18.1); cross-region replication lag; deletions and updates racing across regions.
- **Backups and point-in-time recovery** restore to a new table (indexes, autoscaling settings, permissions, streams, and TTL settings may not come with it).

### 51.6 Identity, control plane, and global dependencies

- **Permission propagation is eventually consistent:** automation that creates a role and immediately uses it intermittently fails; deployments should retry with backoff.
- **Policy evaluation layers:** explicit deny wins; organization-level guardrails can silently override your account's permissions; boundary and session policies; resource policies; cross-account trust. Debugging "access denied" without tooling that explains the decision is slow during an incident.
- **Global services with regional control planes:** identity, DNS, and some global edge services have **control planes in a single region**. During that region's failure, you can still *use* existing resources (data plane) but may be unable to *change* them (fail over DNS, edit roles, rotate credentials). Recovery plans that require control-plane changes during the outage are fragile (Part 12.5 and 21.9). Pre-provision and pre-configure failover paths so failing over is a data-plane action.
- **Quotas and limits:** per region, per account, per service; some are hard, some raise slowly; discover all relevant ones and alert at a percentage (Part 12.5).
- **Regional service availability:** not all services, features, instance types, or quota levels exist in your DR region.
- **Monitoring services:** metric delay, resolution, statistic semantics (maximum vs. average), alarms entering an "insufficient data" state that is treated as OK, and alarm evaluation periods (Part 21.10).
- **Secrets and configuration services** as startup dependencies with their own rate limits: a fleet restarting at once can exceed them and fail to boot (Part 21.7).
- **Billing and account state:** payment failures, limits, and account suspension are availability risks; organization structure and delegated administrators as single points of failure (Part 35.3).

---

## Part 52: Protocols and Transport Edge Cases (HTTP, gRPC, WebSocket, TLS)

### 52.1 HTTP semantics that teams misuse

- **Method semantics:** GET, PUT, DELETE are defined as idempotent, POST is not. Clients, proxies, and libraries retry idempotent requests automatically, so a GET that changes state, or a DELETE with extra effects, gets executed repeatedly. Prefetching, link scanners, and email security tools follow GET links (a "confirm" or "unsubscribe" link that acts on GET gets triggered by scanners).
- **Redirects:** some redirect codes convert POST to GET and drop the body; others preserve method and body. Choosing the wrong code breaks form posts and APIs.
- **Status code semantics drive retry logic:** client errors should not be retried; gateway and unavailable statuses often should; some services return 200 with an error body (Part 20.11) and some use 500 for validation failures. Inconsistent mapping produces retry storms or silent drops.
- **`Retry-After` and rate-limit headers** must be honored; clients that ignore them amplify.
- **Conditional requests and optimistic concurrency:** entity tags and preconditions give lost-update protection for APIs (`If-Match`); weak vs. strong tags matter for ranges; many APIs omit them.
- **Caching:** absent explicit directives, caches may apply heuristic freshness from modification dates. The **`Vary`** header must list every request header that changes the response, or caches serve the wrong variant (language, encoding, authorization-dependent content); private vs. public directives; authenticated responses cached by shared caches (Part 33.5).
- **Body handling:** content length vs. chunked encoding disagreements (smuggling, Part 33.5); maximum body sizes per hop; the "expect-continue" handshake; compressed request bodies (decompression limits); charset defaults for text.
- **Range requests and partial content** with changing resources (resume a download of a modified file, getting corrupted data without validators).
- **Connection reuse:** a client reusing a connection that the server already closed fails the first request, and retrying non-idempotent requests on that failure risks duplication (Part 9.5).
- **Timeouts:** connection, TLS handshake, time to first byte, total request, idle-read, each separately; many defaults are "no timeout."
- **URL and encoding:** percent-encoding differences, double encoding, trailing slash significance, case sensitivity of paths, very long URLs truncated by proxies, query parameter ordering and duplication (Part 20.4).
- **Time in headers:** dates in headers and cookies depend on clocks (expiry, signatures; Part 21.4).

### 52.2 HTTP/2, gRPC, and multiplexed protocols

- **Long-lived multiplexed connections defeat connection-level load balancing:** a layer-4 balancer distributes *connections*, and one client's single connection sends all its requests to one backend. After scaling out, new backends get little traffic; one backend is overloaded while others idle. Use request-level (layer 7) balancing, client-side balancing, or connection-age limits with graceful recycling.
- **Deadlines:** gRPC calls have no deadline unless set; propagate deadlines through call chains (Part 18.9). Retry policies and hedging defined in service configuration interplay with application retries (amplification).
- **Status codes** map to retryability differently than HTTP; non-idempotent methods and streaming calls need care.
- **Message size limits** (commonly a few megabytes by default) apply per message in each direction; large payloads need streaming or chunking.
- **Streaming:** flow control and backpressure; a slow consumer makes the producer buffer; half-closed streams; cancellation propagation; a stream that lives for hours crosses deploys, certificate rotations, and token expiry.
- **Keepalive settings** must match infrastructure idle timeouts and server-side enforcement (servers may close connections for too-frequent pings).
- **Head-of-line blocking** moves from HTTP level to TCP level under packet loss for multiplexed connections.
- **Resource-exhaustion attacks specific to multiplexing** (abusive stream reset patterns, huge numbers of concurrent streams); configure stream and header limits and keep servers patched.
- **Reconnection storms** after a server restart or network blip: add jitter and backoff.
- **Schema evolution in binary formats:** field numbers never reused, unknown fields preserved or dropped intentionally, required fields discouraged, default value ambiguity (Part 20.5).

### 52.3 WebSockets and server push

- **Idle timeouts** in proxies and balancers close quiet connections; send periodic application-level pings.
- **Authentication happens once at connect:** tokens expire and permissions change while the connection lives; the server must re-validate or force reconnect.
- **Message ordering is per connection;** across reconnects, messages can be lost or duplicated; use sequence numbers and resume tokens, and tolerate gaps.
- **Backpressure:** a slow client makes the server buffer messages in memory; bound buffers and drop or disconnect slow clients.
- **Fan-out scaling:** many clients on many servers need a pub/sub layer; that layer's failure mode (at-most-once) determines what clients miss.
- **Deploys disconnect everyone:** reconnect storm; stagger with connection-age limits and drain gradually.
- **Connection limits** per process and per host (file descriptors, memory per connection).
- **Cross-site concerns:** origin checks and token placement (query strings leak to logs).

### 52.4 TLS and certificate handling in clients

- **Verification disabled or partial:** chain checked, hostname not; trust stores that are outdated or contain unexpected roots.
- **Outdated trust stores** in old devices, containers, and runtimes fail after a certificate authority or chain change (Part 12.4).
- **Pinning** without a backup pin or rotation plan causes outages when the pinned certificate rotates, sometimes impossible to fix for installed mobile apps.
- **Server name indication and virtual hosting:** clients that omit it reach the wrong certificate.
- **Session resumption and certificate rotation:** old sessions continue with old credentials until they expire.
- **Mutual TLS:** client certificate expiry and revocation, and certificate distribution to many clients.
- **Handshake cost:** storms of new connections (after restarts) are CPU-expensive; enable resumption and connection reuse.
- **Clock skew** and "not yet valid" errors on freshly issued certificates (Part 21.4).

---

## Part 53: Language and Runtime Traps (Examples by Ecosystem)

These are common, real behaviors that convert into production incidents. They are examples of Family A and B at the language level. Verify for your language version.

### 53.1 Python

- **Mutable default arguments** are created once and shared across calls (a list default accumulating state across requests).
- **Late-binding closures in loops** capture the variable, not its value at creation.
- **Naive vs. timezone-aware datetimes:** comparing or subtracting them raises an error, but mixing through conversions silently applies the local zone; functions returning the current UTC time as a naive value are a recurring source of zone bugs.
- **Floating point and decimal context:** `Decimal` constructed from a float carries binary error; construct from strings; context precision and rounding mode are global per thread.
- **Integer is arbitrary precision** (no overflow) until it meets a fixed-width type in a database, a file format, or a native library.
- **Global interpreter lock:** threads do not speed up CPU-bound work; blocking I/O in async code stalls the event loop; unawaited coroutines silently never run (and produce only a warning).
- **Exceptions in threads and tasks** can vanish unless collected; background tasks garbage collected when no reference is held.
- **Iterators/generators** are consumed once; exhausted generators evaluate as truthy; `len` of a generator fails; lazy evaluation defers errors and holds resources open.
- **Identity vs. equality** (`is` for small-integer and string interning coincidences), `==` between different types, truthiness of empty containers, zero, and `None` (conflating "absent" with "zero" in `if not x`).
- **Dictionary and set ordering:** insertion order for dicts in modern versions, but sets have arbitrary order; hash randomization for strings varies between processes (do not shard by built-in hash).
- **Copying:** shallow copies share nested structures.
- **String handling:** bytes vs. text, default encodings depending on platform and locale, universal newline translation.
- **Import-time side effects** and circular imports; module-level state shared across requests.
- **`datetime.strptime` and locale-dependent parsing;** two-digit years.
- **Subprocess and shell:** shell mode with string concatenation (Part 33.1).
- **Serialization of arbitrary objects** with unsafe native formats (Part 33.2).

### 53.2 JavaScript and TypeScript

- **All numbers are 64-bit floats:** integers above 2^53 lose precision (IDs, timestamps in nanoseconds, money in minor units of large values); decimal arithmetic errors; `NaN` is not equal to itself; `parseInt` without a radix and with trailing text.
- **`sort()` without a comparator sorts as strings** (10 sorts before 9); comparators returning booleans misbehave; sort stability and locale differences.
- **`Date`:** months are zero-indexed, parsing is inconsistent for non-standard strings, date-only strings are treated as UTC while date-time strings without offset are treated as local time (off-by-one-day bugs).
- **Type coercion and equality:** loose equality coercions, `typeof null`, truthiness of `0`, `""`, `NaN`, and empty arrays/objects (`[]` is truthy), `||` vs. `??` (zero and empty string treated as missing by the former).
- **JSON:** `JSON.stringify` drops undefined and functions, turns `NaN` and `Infinity` into `null`, cannot serialize big integers or circular references, and converts dates to strings (round trips lose the type); `JSON.parse` of huge numbers loses precision.
- **Event loop:** a CPU-heavy or synchronous call blocks all requests; unhandled promise rejections (behavior differs by runtime version: warn vs. crash); fire-and-forget async calls whose failures vanish; `forEach` with async callbacks does not wait; unbounded concurrency with `Promise.all` over a huge list (exhausting connections and memory); one rejection in `Promise.all` leaves other operations still running.
- **Prototype pollution** through merging untrusted objects; `in` and property enumeration include inherited properties; using objects as dictionaries with keys like `__proto__` or `constructor`.
- **Array quirks:** holes, `length` assignment, `delete` leaving holes, copying by reference, mutation by `sort` and `reverse` in place.
- **Regular expressions:** backtracking (Part 20.4), stateful `lastIndex` with the global flag causing alternating results.
- **Module and dependency ecosystems:** deep transitive trees, install scripts (Part 35.1), version ranges.
- **Numeric formatting and locale:** `toLocaleString` and `Intl` differences between runtimes and versions; time zone data from the runtime.
- **TypeScript types are erased:** runtime data does not match declared types unless validated at the boundary (Part 29.1); non-null assertions and casts hide absence.

### 53.3 Java and JVM languages

- **Boxed-number comparisons:** reference equality works for small cached integers and fails beyond, giving "works in tests, fails with real data."
- **`BigDecimal`:** equality considers scale (2.0 vs. 2.00 are not equal; use comparison), constructing from a double imports binary error, division without rounding context throws for non-terminating results.
- **Integer overflow is silent;** integer division and modulo semantics with negatives; casting between widths truncates.
- **Hash-based collections:** mutable keys, inconsistent `equals`/`hashCode`, iteration order instability, a hash-collision denial-of-service risk mitigated differently across versions.
- **Date and time:** old mutable date classes and formatters that are **not thread-safe** (shared formatter produces corrupted dates under concurrency); use the modern immutable time API and explicit zones.
- **Thread pools:** some convenient factory pools use **unbounded queues**, turning overload into memory exhaustion (Part 18.8); thread-per-task without limits; blocking tasks starving shared pools; uncaught exceptions killing worker threads silently; leaked thread-local values in pooled threads (per-request data leaking to another request).
- **Default HTTP client behavior:** some legacy clients have **no timeouts by default**; connection pools with small per-route defaults that throttle silently.
- **Garbage collection:** pauses, heap sizing vs. container limits (Part 21.2), off-heap memory, finalization, and memory leaks through static collections, caches without eviction, and listeners.
- **Class loading and serialization:** native object serialization of untrusted data (Part 33.2); classpath conflicts between library versions; reflection-based frameworks hiding errors until runtime.
- **Checked exceptions** swallowed in empty catches; `finally` blocks that override return values or hide exceptions.
- **`Optional` and null:** `null` returned where `Optional` was promised; unboxing null throws.
- **String handling:** `String.format` and case conversion are locale-dependent (the Turkish-locale problem, Part 11.1); default charset depends on platform in older versions.
- **Time zone database** bundled with the runtime may be stale (Part 20.8).
- **Startup and JIT warm-up** (Part 21.2).

### 53.4 Go

- **Nil slices vs. empty slices** serialize differently (null vs. empty array), which breaks clients expecting arrays.
- **A nil pointer stored in an interface is not a nil interface,** so `err != nil` checks pass for a typed nil error value.
- **Zero values:** missing JSON fields become zero values, indistinguishable from explicit zero unless pointers or presence tracking are used (Part 11.1); integer overflow wraps silently.
- **Goroutine leaks:** goroutines blocked forever on channels with no receiver, or without context cancellation, accumulate until memory is exhausted; unbuffered channel deadlocks; closing a channel twice panics; sending on a closed channel panics.
- **Maps are not safe for concurrent write** and fail fatally (not recoverable) on detected concurrent access; map iteration order is randomized.
- **The default HTTP client has no overall timeout;** response bodies must be fully read and closed to allow connection reuse (otherwise leaks and pool starvation).
- **Loop variable capture** in closures and goroutines behaved per-loop in older language versions and per-iteration in newer; code moved between versions changes behavior.
- **`defer` inside loops** delays cleanup until function return, leaking resources in long loops; deferred calls and error returns interplay; ignored errors from `Close`.
- **Time:** wall vs. monotonic readings inside the same value; comparison and formatting pitfalls; durations are integers of nanoseconds (unit confusion).
- **Slices share backing arrays:** appending to a sub-slice can overwrite the parent's data; retaining a small slice of a large array keeps the whole array in memory.
- **Panics in goroutines** crash the process unless recovered in that goroutine.
- **Context cancellation must be checked and propagated;** otherwise abandoned work continues (Part 18.9).

### 53.5 Cross-language boundaries

- **Integer widths, signedness, and endianness** across services written in different languages.
- **Different time, decimal, and string semantics** in each (what "null," "empty," "zero" mean, Part 11.1).
- **Different hash functions and sort orders** for the same data (partitioning and consistent hashing disagreements between producer and consumer).
- **Different regular expression dialects and Unicode versions** (validation passes in one service and fails in another).
- **Rounding mode defaults** differ (half-up vs. banker's rounding), making money calculations disagree by a cent at scale.
- **Different default character encodings and newline handling** when passing files and streams.
- **Floating-point formatting and parsing** differences in text interchange.

---

## Part 54: A Method for Verifying Platform Behavior Cheaply

The previous parts are hypotheses. This method converts them into facts about *your* system.

### 54.1 The verification lab

For each critical dependency, maintain a small automated test environment, same engine and version as production, with scripted experiments:

1. **Default audit:** dump the effective configuration (not the file, the live settings) and compare against a reviewed baseline. Flag every default you never chose.
2. **Kill and restart:** crash the process (forcefully), then check what acknowledged data survived. This measures real durability.
3. **Partition and pause:** freeze a node for a length longer than lease and election timeouts, then let it resume. Observe who acts on stale beliefs (Part 18.2).
4. **Fill it up:** fill disk, memory, connections, file descriptors, queue depth, and quota; record the failure mode at each limit (error, stall, drop, crash) and whether recovery is automatic.
5. **Slow it down:** inject latency and packet loss between the application and the dependency; measure retries, pool exhaustion, and timeouts.
6. **Concurrency probes:** run the invariants of Part 14.1 under many parallel identical and conflicting operations at each isolation setting you might use.
7. **Upgrade rehearsal:** restore a production-shaped dataset into the next version; compare query plans and results for the load-bearing queries; run the migration path and the rollback path.
8. **Failover drill:** promote a replica under load using your real driver and pool; record errors, duration, and data loss.
9. **Backup restore drill:** restore, then run application-level integrity checks; time it (Part 10.9).
10. **Schema change rehearsal:** run the migration on a production-sized copy while a load generator runs; record lock waits and replica lag.
11. **Skew test:** load one giant tenant or hot key and watch for throttling, plan changes, and noisy-neighbor effects.
12. **Clock test:** jump the clock forward and backward on one node and observe.

Record each result in a short "behavior sheet" per dependency. It becomes the source for design reviews (Part 16.4).

### 54.2 The behavior sheet (template)

```
dependency / version / managed or self-run:
what "success" means for a write (memory / disk / replicated / applied):
durability window on crash (measured):
isolation or consistency levels in use, anomalies permitted:
ordering guarantees and their scope:
delivery guarantee (at most / at least / effectively once, and where dedupe lives):
what grows in the background, and its alert:
limits (connections, size, rate, count) and failure mode at each:
timeouts and retries (client defaults, proxy defaults, server defaults):
failover: mechanism, measured duration, data loss, client behavior:
backup/restore: method, measured RTO, last drill date, what is NOT in the backup:
upgrade path and known behavior changes:
schema/config change locking behavior:
security defaults (authentication, network exposure, admin commands):
known sharp edges from this sheet and from incidents:
owner, last reviewed date
```

### 54.3 Reading release notes and incident reports as a practice

- **Release notes:** search for "default changed," "deprecated," "removed," "behavior change," "no longer," and "now requires." Each is a potential silent behavior change at upgrade.
- **Public postmortems** of your dependencies and of similar systems: extract the root cause family (Part 2) and ask whether your environment has the same latent condition.
- **Your own incident history:** for each dependency, list past surprises and confirm that each has a test or monitor now (Part 16.3 step 10).

---

## Part 55: Cross-Engine Comparison Table (What Differs Most Often)

A reminder that "a database" is not one thing. Verify every cell for your versions.

| Topic | What commonly differs between engines | Edge case when assumed equal |
|---|---|---|
| Default isolation | Read Committed vs. Repeatable Read (snapshot) vs. others | Code tested on one engine has races or deadlocks on another |
| Repeatable Read meaning | Snapshot isolation in some; gap locking in others | Phantoms and write skew appear or disappear |
| NULL in unique indexes | Multiple NULLs allowed vs. one | Duplicate "unique" rows, or unexpected conflicts |
| Empty string vs. NULL | Treated as equal in some engines | "Empty" checks and uniqueness change |
| String comparison | Case sensitivity, accent sensitivity, trailing-space handling | Duplicate accounts, missed lookups |
| Implicit casts | Permissive vs. strict; column cast vs. parameter cast | Index not used, wrong rows matched |
| DDL transactions | Transactional vs. implicit commit | Partial migrations |
| Schema change locking | Metadata-only vs. rewrite vs. online | Outage during deploy |
| Auto-generated IDs | Gaps, reuse after restart, ordering | Gapless numbering assumption, skipped rows |
| Date and time types | Zone handling, range, precision | Off-by-hours, 2038, precision loss |
| Numeric overflow | Error vs. silent wrap vs. clamp | Silent corruption |
| Sort of NULLs | First vs. last by default | Pagination and cursor bugs |
| `GROUP BY` leniency | Strict vs. permissive | Nondeterministic column values |
| Upsert semantics | Differences in conflict targets, returned rows, triggers | Duplicate or lost updates |
| Replication default | Async vs. semi-sync vs. sync | Data loss on failover |
| Locking reads | Row vs. gap vs. predicate locks; skip-locked support | Queue or claim patterns break |
| Transaction abort on error | Whole transaction vs. statement only | Broken "try and continue" code |
| Max identifiers and sizes | Name length, index key length, parameter count, row size | Fails at scale or with real data |
| Text length unit | Characters vs. bytes | Truncation or rejection of non-Latin text |
| Collation/library coupling | Internal vs. OS library | Index corruption after OS upgrade |

---

## Part 56: Worked Cases (Platform-Specific Root-Cause Chains)

### Case 34: The consumer that "caught up" by skipping a week

- **Symptom:** a downstream dataset is missing a week of events; no errors; consumer metrics looked normal afterward.
- **Trigger:** a consumer group was down for a long weekend, longer than the topic's retention.
- **Proximate cause:** on restart the committed offset no longer existed; the offset-reset policy jumped to the newest position.
- **Contributing conditions:** alerting was on message count lag, which reads "small" after the skip; retention was shorter than the longest plausible outage.
- **Root causes:** **A** (assumed retention exceeds any outage), **H** (lag measured in counts, not time-to-loss), **D** (reset policy chosen by default, not by requirement).
- **Class-level fix:** alert on oldest unconsumed message age versus retention remaining; set reset policy to fail loudly for critical consumers; retention sized to worst realistic outage plus replay time; an independent count reconciliation between source and sink.

### Case 35: The pool that hid behind "idle" connections

- **Symptom:** sporadic 502s from a balancer with no backend errors logged.
- **Trigger:** traffic patterns with gaps just longer than the backend's keep-alive timeout.
- **Proximate cause:** the backend closed an idle connection at the moment the balancer sent a request on it.
- **Root causes:** **D** (two timeouts tuned independently), **A** (assumed defaults are compatible), **H** (errors attributed to the balancer, not visible in the application's logs).
- **Class-level fix:** a documented timeout ordering (client < gateway < service, and backend keep-alive > balancer idle); an inventory of every timeout along the path; synthetic traffic with idle gaps in load tests.

### Case 36: The cache that became the database

- **Symptom:** after a routine failover, thousands of users lost their sessions and some lost queued carts.
- **Trigger:** a replica promotion after an asynchronous replication lag.
- **Proximate cause:** data written in the last seconds never reached the replica; other keys had been evicted earlier under an all-keys eviction policy.
- **Root causes:** **B** (an in-memory cache used as a system of record for sessions and carts), **A** (assumed replicated means durable), **D** (eviction policy and persistence setting chosen for caching, used for storage).
- **Class-level fix:** separate instances for cache and stateful data; durable store for carts; eviction policy and persistence matched to purpose; session design tolerant of loss.

### Case 37: The webhook that locked the whole cluster

- **Symptom:** after a node failure, no pods could be created anywhere, including those needed to restore service.
- **Trigger:** the pods of a policy admission webhook were on the failed node.
- **Proximate cause:** the webhook was configured to reject requests when unreachable; it had to approve creation of its own replacement pods.
- **Root causes:** **G** (circular dependency, Part 21.8), **E** (failure policy chosen without considering the failure of the component itself), **J** (never tested losing the webhook).
- **Class-level fix:** exclude the webhook's namespace from its own scope; multiple replicas spread across zones; documented break-glass removal procedure; test by killing the webhook in a staging cluster.

### Case 38: The second column that took two hours

- **Symptom:** a deploy hangs the application for minutes, then recovers.
- **Trigger:** a migration adding a column with a function-generated default to a very large table.
- **Proximate cause:** the statement rewrote the whole table under a strong lock, while readers queued behind it.
- **Root causes:** **A** (assumed "add column" is instant), **E** (lock queue effect, Part 10.3), **J** (migration tested on a tiny table).
- **Class-level fix:** add the column without default, backfill in batches, then set the default; lock timeout on all migrations; migration rehearsal on production-sized data; review checklist entry "does this rewrite?"

### Case 39: The search index that returned yesterday

- **Symptom:** users see deleted items and miss new ones; support cannot reproduce on the database.
- **Trigger:** a change-stream consumer crashed and restarted from an old position; out-of-order events overwrote newer documents.
- **Root causes:** **E** (ordering and replay assumption), **C** (no version check on index writes), **H** (no reconciliation between source and index), **B** (index treated as always current).
- **Class-level fix:** external version numbers on index writes so stale updates are rejected; periodic reconciliation sampling; a documented full-rebuild procedure with measured duration; staleness visible as a metric.

### Case 40: The function that paid for its own loop

- **Symptom:** a cloud bill multiplies overnight.
- **Trigger:** a function processing uploaded files wrote its output to the same storage location that triggered it.
- **Proximate cause:** each output triggered another invocation, indefinitely.
- **Root causes:** **F** (unbounded recursion and cost), **G** (trigger and output share a namespace), **H** (spend alert at monthly total only).
- **Class-level fix:** separate input and output locations; concurrency caps; budget alarms on rate of spend with automatic shut-off of the trigger; recursion detection features where available.

### Case 41: The restored database that was "up" but unusable

- **Symptom:** a restore finishes and the database accepts connections, yet queries are extremely slow for hours.
- **Trigger:** recovery from a storage snapshot.
- **Proximate cause:** blocks were fetched lazily from the snapshot on first access; additionally, statistics were stale.
- **Root causes:** **J** (recovery measured as "instance available," not "application performing"), **A** (assumed restored storage performs like the original).
- **Class-level fix:** define recovery time as time to healthy application latency; pre-warm procedures; drill with a production-shaped workload and record the warm-up curve.

### Case 42: The empty array that was null

- **Symptom:** a mobile app crashes for users with no items after a backend rewrite.
- **Trigger:** the new service serialized an empty collection as `null`.
- **Root causes:** **D** (contract said "array," never specified empty vs. absent), **B** (language-level zero value semantics leaking into the API), **J** (no contract test with empty and minimal data), **I** (old app versions cannot be updated instantly).
- **Class-level fix:** schema-validated responses in CI, contract tests with empty, single, and maximal fixtures; explicit serializer configuration; tolerant clients; response comparison in shadow traffic before cutover (Part 23.7).

---

## Part 57: Platform-Focused Question Bank

**For any data store**
- What does a successful write guarantee at the moment it returns, and what is the measured loss window on a hard crash?
- What is the consistency of a read right after a write, from each read path (primary, replica, cache, index)?
- What background processes consume resources and could be blocked by a long transaction, a dead consumer, or a slow replica?
- What happens at 100% of each limit: disk, memory, connections, file descriptors, transaction counters, quota?
- What does a schema or configuration change lock, rewrite, or restart?
- What does failover lose, how long does it take, and what do our clients do during it?
- What is in the backup, and what is not (configuration, secrets, keys, external files, other stores)?

**For any broker or queue**
- What is the ordering scope, the delivery guarantee, and where does deduplication happen?
- What is the maximum age of a message before it is lost, and do alerts fire before then?
- What happens to a message that always fails? Who owns the dead-letter path?
- What happens to in-flight messages on consumer death, deploy, rebalance, and timeout?
- What is the cost of replay, and is the consumer safe against it?

**For any cache or index**
- Is anything here the only copy? What is the maximum staleness we tolerate, and how is it bounded and measured?
- What is the cold-start load on the source, and can the source survive it?
- How do stale updates get rejected?

**For any orchestrator or cloud control layer**
- What does the system do by default when a controller, webhook, or agent is unavailable?
- Which dependencies does recovery itself need, and are they in the same failure domain?
- What changes without our action (maintenance, version upgrades, credit exhaustion, quota limits, deprecation)?

**For any language or library boundary**
- What does this type do with absent, empty, zero, overflow, and unknown values?
- Which defaults (timeouts, pool sizes, encodings, zones, rounding) are silently chosen here?
- What happens to errors in background execution contexts?

**The hardest platform questions**
1. Which of our dependencies have behaviors we have never intentionally tested (crash, pause, fill, partition, upgrade, restore)?
2. Which default settings are we running in production that nobody on the team chose?
3. If we replaced this dependency with another, which of our correctness properties would silently break? (That list is the set of properties we are relying on without enforcing.)
4. What is the most important thing the vendor's documentation says that none of us has read recently?

---

## Part 58: Additional Principles (Extending Parts 8, 17, 28, 43)

61. **Learn the failure modes of a technology before depending on it,** and record them in a behavior sheet (Part 54.2).
62. **Measure defaults and effective configuration, not configuration files.** Audit the live values.
63. **"Success" must be defined per layer:** accepted, persisted, replicated, applied, visible. Design for the weakest acknowledged level.
64. **Match the tool to the guarantee:** cache for speed, log for ordered history, database for invariants, index for search. Never trust a derived store as the only copy.
65. **Every internal accumulator needs an alert:** transaction age, slot lag, dead rows, pending entries, consumer age, tombstones, unflushed buffers, burst balance.
66. **Retry in the right place, once.** Decide which layer retries, with which budget; disable retries elsewhere.
67. **Align timeouts as a system,** with a written ordering and end-to-end budget.
68. **Verify version-specific behavior in a lab before relying on it,** and re-verify at every upgrade.
69. **Make failure policies explicit and symmetric:** fail-open versus fail-closed is decided per component and tested against the failure of that component itself.
70. **Rehearse recovery to "application healthy," not "service running."**
71. **Prefer boring, well-understood configurations,** and treat each deviation (custom isolation level, relaxed durability, exotic topology) as a documented, owned exception.
72. **Keep platform knowledge shared:** review roles for database, messaging, and cloud specifics; pair design reviews with someone who has been burned by the technology.
73. **Treat upgrades as behavior changes,** not as maintenance: read the notes, diff the plans, rehearse the rollback.
74. **At language boundaries, validate at runtime what types cannot guarantee,** and test with empty, absent, maximal, and hostile values.

---

## Operational Verification Checklist

For the actionable platform, database engine, Kubernetes, and runtime internals review checklist derived from Volume 5, see:
👉 **[Checklist 05: Engine, Platform & Runtime Deep Internals](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/05-engine-platform-and-runtime-checklist.md)**  
👉 **[Master Engineering Checklist Index](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/00-master-engineering-checklist.md)**

