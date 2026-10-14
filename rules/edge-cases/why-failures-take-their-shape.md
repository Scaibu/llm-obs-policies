# Volume 2: Going Deeper (Addendum to the Root-Cause Guide)

Everything from the previous parts stays as it is. This volume continues the numbering (Part 9 onward) and adds three things:

1. The **mechanisms underneath** the root-cause families (why systems fail in ways nobody predicts).
2. **Deep dives** into databases, application code, and infrastructure, each written as root cause, then how it hides, then the disaster, then the structural fix.
3. **Categorization, detection, and review tools** you can use directly.

---

## Part 9: Deeper Mechanisms (Why Failures Take Their Shape)

These are properties of complex systems. Knowing them explains why so many incidents look "impossible" in hindsight.

### 9.1 Queueing and the utilization knee

Latency does not rise in proportion to load. As utilization of a resource (CPU, DB connections, thread pool, disk IOPS) approaches 100%, queue length and wait time grow steeply. A rough intuition: a system at 50% utilization has little queuing, at 80% it is noticeable, at 95% small bursts create huge waits.

**Root cause it explains:** "The system was fine at 70% and dead at 95% with only a small traffic increase." Capacity planning based on averages ignores that the last 20% of utilization is not usable capacity.

**Little's Law** (concurrency in system = arrival rate × time in system) gives a practical check. If a request normally takes 100 ms and you receive 500 requests per second, about 50 requests are in flight. If the database slows and each request takes 2 seconds, the same traffic needs 1,000 in flight. A pool of 200 threads or connections is then exhausted, and the slowdown becomes an outage without any increase in traffic.

**Questions to ask**
- At what utilization does this resource degrade, and how far are we from it at peak?
- If latency of a dependency increases 10x, how many concurrent requests do we hold open, and what limit do we hit first?

**Fix:** keep headroom targets (for example, alert at 60-70% sustained utilization), bound concurrency with explicit limits so you shed load instead of collapsing, and size pools using Little's Law, not intuition.

### 9.2 Metastable failure (the outage that continues after the cause is gone)

Some systems have two stable states: healthy and failed. A trigger (a traffic spike, a brief dependency slowdown, a cache flush) pushes the system into the failed state, and a **sustaining feedback loop** keeps it there even after the trigger disappears.

Typical sustaining loops:
- Retries keep offered load above capacity, even though original demand has returned to normal.
- Cache is cold, so the database is overloaded, so responses are slow, so the cache cannot refill in time (or requests time out before populating it), so it stays cold.
- A backlog builds up, and processing the backlog plus new traffic exceeds capacity, so the backlog never drains.
- Health checks fail under load, nodes are removed, remaining nodes get more load, and they fail too.
- Garbage collection under memory pressure slows requests, which increases in-flight requests, which increases memory pressure.

**Why it is hard:** fixing the original trigger does not end the incident. Operators often must actively reduce load (shed traffic, disable retries, restart with a warmed cache, drain the queue in throttled fashion).

**Root cause family:** F (feedback loops) and G (coupling), invisible because it only appears under stress.

**Design defenses:** retry budgets (for example, retries limited to a fraction of the normal request rate), load shedding that prioritizes important traffic, circuit breakers, cache warming and request coalescing, throttled backlog processing, and a documented "big red switch" for reducing load.

### 9.3 Gray failure (partially broken, and nobody's sensors say so)

A component that is not dead but degraded: 5% of requests fail, one disk is slow, one network path drops packets, one replica is 40 seconds behind, a node has an intermittent DNS problem. The health check passes (it hits a trivial endpoint), so it stays in rotation, while users get errors or slowness.

**Why it is worse than a crash:** a crash is detected and handled by failover. A gray failure is invisible to the mechanisms designed to handle failure, and it affects a fraction of users, so aggregates look fine.

**Root cause family:** H (measuring health instead of outcomes), G (shared components in a request path).

**Defenses:** health checks that exercise real dependencies with meaningful work (with care not to cause cascading failures), per-node and per-path error rate and latency comparison (outlier detection: this node is much worse than its peers), user-perspective synthetic probes, and automatic ejection of outlier nodes.

### 9.4 The tail at scale (fan-out multiplies rare slowness)

If one backend is slow 1% of the time, a request that must wait for 100 backends will hit at least one slow call in about 63% of cases. Rare events at the component level become common at the request level.

**Root cause it explains:** "Every component's p99 looks fine, yet users experience slowness constantly."

**Where it hides:** microservice call chains, page composition from many services, scatter-gather search, batch operations touching many shards, N+1 queries (each individual query is fast; the sum is dominated by the slowest few).

**Defenses:** reduce fan-out, set deadlines and return partial results, hedged requests (send a second request after a short delay for the slow tail), and measure request-level latency, not only component latency.

### 9.5 Partial failure and the three-outcome problem

Local function calls have two outcomes: success or failure. Remote calls have three: succeeded, failed, or **unknown** (timeout, connection reset, lost response). Most code is written as if unknown does not exist and treats it as failure. That is the root of double charges, duplicate emails, and phantom orders.

**Consequence for design:** every remote side effect needs an answer to "what do I do when I do not know?" The answers are: make the operation idempotent so retrying is safe, make it queryable so you can ask "did it happen?", or reconcile later.

### 9.6 Dual writes and the impossibility of atomicity across systems

Writing to a database and then publishing an event (or updating a cache, or calling an API) is two separate operations. There is no atomicity between them. A crash between them leaves the systems inconsistent, and no amount of careful ordering fully fixes it.

```
# broken: crash between the two lines loses the event forever
db.commit(order)
queue.publish(OrderCreated)

# reversed is also broken: event published, but commit fails
queue.publish(OrderCreated)
db.commit(order)
```

**Root fix (outbox pattern):** write the business row and an "event to send" row in the same database transaction. A separate relay reads the outbox and publishes at least once, and consumers dedupe. The atomicity you need is provided by the single database, and the rest is at-least-once plus idempotency.

**Generalization:** whenever two systems must agree, ask which one is the source of truth, and make the other derive from it (with retries and reconciliation).

### 9.7 Why "exactly once" is usually a misunderstanding

Networks cannot guarantee that a message is delivered exactly once. What systems can achieve is **at-least-once delivery combined with idempotent processing**, which produces an *effectively once* outcome. Any design that says "exactly once" without naming where deduplication happens is hiding an assumption.

**Questions:** where is the dedupe key stored, how long is it kept, what happens for duplicates that arrive after the key expired, and is the dedupe check atomic with the effect?

### 9.8 Consistency is a spectrum, and users notice the seams

Any system with replicas, caches, or multiple services has moments where different readers see different truths. The specific anomalies users experience:
- **Read-your-writes violation:** user saves, refreshes, sees the old value (read hit a lagging replica).
- **Monotonic read violation:** user sees newer data, then on the next request sees older data (different replicas).
- **Causality violation:** a reply is visible before the message it replies to.
- **Stale decision:** an action is authorized or approved based on data that has since changed.

**Root cause:** treating "the database" as one consistent thing, when reads go to replicas or caches with lag.

**Defenses:** route a user's reads to the primary for a short window after their write, use session tokens or version stamps ("read at least version N"), and never use a lagging replica or cache to make a *decision* that must be correct (balances, permissions, inventory).

### 9.9 Why smart people miss these: cognitive mechanisms

Adding depth to the earlier "psychological reasons":
- **Curse of knowledge:** you know how the system is supposed to be used, so you cannot easily imagine misuse.
- **Local reasoning:** a reviewer sees a diff, not the system. Failures are properties of the *whole*.
- **Anchoring on the last incident:** teams over-protect against what just happened and under-protect against different classes.
- **Availability bias:** vivid failures (a hack, a data loss) get attention; slow ones (a gradual creep, a growing table) do not.
- **Optimism about rare events:** "one in a million" is dismissed, but with a million requests a day that is daily.
- **Diffusion of responsibility:** everyone assumes the edge case is handled by someone else (the caller, the database, the platform team, the vendor).
- **Complexity hides interactions:** each component is understood, but combinations (retry + timeout + cache expiry + deploy) are not.

**Countermeasures that do not rely on willpower:** checklists, structured pre-mortems, adversarial reviewers who were not involved in the design, and automation that generates hostile inputs.

---

## Part 10: Database Deep Dive

### 10.1 Isolation anomalies in detail

The "I" in ACID is not a yes or no. Each isolation level permits specific anomalies. Most teams run the default and do not know which anomalies it allows.

| Anomaly | What happens | Example |
|---|---|---|
| Dirty read | See another transaction's uncommitted data | Read a balance that is later rolled back |
| Non-repeatable read | Same row read twice in a transaction gives different values | Total computed from two reads of the same row disagrees |
| Phantom read | Same query run twice returns different *sets* of rows | Count of active users changes mid-report |
| Lost update | Two transactions read-modify-write the same row; one overwrites the other | Two admins edit a record; the first save vanishes |
| Read skew | Read two related values at different points in time | Account A checked before a transfer, account B after; money appears to vanish |
| Write skew | Two transactions read overlapping data, make disjoint writes, each valid alone, jointly violating a rule | Two doctors both go off call because each saw the other still on call |

Key facts to verify for your engine and version (defaults differ between products, and vary by configuration):
- Many databases default to Read Committed, which allows non-repeatable reads, phantoms, and lost updates in read-modify-write code.
- Some engines' Repeatable Read is actually snapshot isolation, which prevents many anomalies but **still allows write skew**.
- Only true Serializable prevents write skew, at the cost of possible transaction aborts that your code must retry.

**Root causes:** A (assuming a transaction means "safe"), E (assuming the world does not change between read and write).

**Defenses, by anomaly**
- Lost update: atomic update expressions, row locks on read, or optimistic version checks.
- Write skew: serializable isolation, or materialize the conflict (lock a shared row that represents the rule), or enforce with a constraint.
- Phantoms: range or predicate locks, serializable, or a unique/exclusion constraint that makes the violation impossible.

```
# optimistic locking (pseudocode)
row = read(id)                       # includes version = 7
update table set ... , version = 8
   where id = X and version = 7      # 0 rows affected means someone else won
if rows_affected == 0: reload and retry, or tell the user there was a conflict
```

**Important design rule:** code running at Serializable, or using optimistic locking, must be written to *retry on conflict*. If there is no retry path, the anomaly is converted into an error instead of being removed.

### 10.2 Long transactions: the quiet infrastructure killer

A transaction that stays open (an idle-in-transaction session, a forgotten console, a slow batch job, an ORM session held across an HTTP call) causes damage far beyond its own work:
- Holds locks, blocking other writers.
- In MVCC databases, prevents cleanup of old row versions (dead rows), causing table and index bloat and slower queries over time.
- Holds back replication cleanup and can make replicas fall behind or cancel queries.
- Blocks schema changes (see next section).

**Where it hides:** application code that begins a transaction and then calls an external API or waits for user input, and a "read-only" analytical query left running for hours.

**Defenses:** statement and idle-in-transaction timeouts, never do network calls inside a transaction, alert on the age of the oldest open transaction.

### 10.3 The lock queue effect during schema changes

A widely repeated production outage:

1. A long-running query or transaction holds a shared lock on a table.
2. A schema change (add column, add index, change type) requests a strong lock and **waits** behind it.
3. Every new query on that table now queues behind the waiting schema change.
4. Within seconds, all traffic to the table is blocked, connection pool fills, the application is down.

The schema change itself takes milliseconds; the outage was created by *waiting* for the lock.

**Root causes:** F (unbounded waiting), G (one table is shared fate for many endpoints), E (assuming the DDL is instant).

**Defenses:** set a short lock timeout for migrations and retry (fail fast instead of queueing), check for long-running transactions before running DDL, use online or concurrent variants for index builds and large changes, and run migrations with the same review as code.

```
migration:
    set lock_timeout = short (e.g. 2s)
    loop up to N times:
        try apply change
        on lock_timeout: sleep with jitter, retry
    if still failing: abort and alert   # do not queue the whole application
```

### 10.4 Migration hazards beyond "add a column"

- **Table rewrites:** some operations (changing a column type, adding a column with a non-constant default in older versions) rewrite the entire table under a heavy lock. Whether it is metadata-only or a full rewrite depends on the engine and version, so check before running on a big table.
- **Index build blocking writes** unless built concurrently; concurrent builds can fail and leave an invalid index that must be cleaned up.
- **Adding constraints on big tables:** validating a foreign key or check constraint scans everything. Many engines allow adding it as "not validated," then validating in a lower-impact step.
- **Backfills:** one giant UPDATE creates a huge transaction, lock contention, replication lag, and a massive undo/WAL burst. Batch it: small ranges, sleep between batches, resumable (track progress), idempotent (safe to re-run), and monitor replica lag to auto-throttle.
- **Renames:** renaming a column or table breaks old code still running during deploy. Use expand, migrate, contract.
- **Dropping:** dropping a column that "nobody uses" without verifying (query logs, code search, dashboards, BI tools, exports) breaks the thing you forgot about.
- **Order of deploy vs migration:** new code needing a new column deployed before the migration, or old code breaking on a dropped column deployed after it. Every migration should be classified: compatible with both old and new code, or requires a specific ordering.

```
safe change sequence for "rename a column":
 1. add new column (nullable)
 2. deploy code that writes BOTH, reads OLD
 3. backfill new from old in batches
 4. deploy code that reads NEW (still writes both)
 5. verify equality with a check query
 6. deploy code that stops writing old
 7. wait, then drop old column   # one-way door: last step, after a soak period
```

### 10.5 Identifiers, sequences, and counters

- **Sequences and auto-increment values are not gapless:** a rolled-back transaction still consumes a value. Using them as "invoice numbers with no gaps" is a legal/accounting bug waiting to happen.
- **Ordering by ID is not ordering by time:** concurrent transactions commit out of order; a consumer that reads "everything with id greater than the last one I saw" can permanently skip a row that committed late.
- **Exhaustion:** a 32-bit signed integer key tops out around 2.1 billion. Tables with high insert rates (events, logs, sessions) can hit this in a few years, and changing the type of a huge primary key later is a painful migration. Foreign key columns referencing it must also be widened.
- **Guessable IDs** enable enumeration attacks and information leakage (total order count, growth rate).
- **Random UUIDs as primary keys** can cause poor index locality and write amplification on some engines; time-ordered variants exist. This is a performance trade-off to decide deliberately.
- **ID reuse:** if an ID can be reused after deletion, old references, caches, and logs now point at the wrong entity.
- **`MAX(id)+1` or `COUNT(*)+1`** as an ID generator is a race condition.

**The "skip a row" pattern in detail (a classic silent data-loss bug):**

```
# consumer polls: WHERE id > last_seen_id ORDER BY id
# tx A gets id 100 but commits slowly; tx B gets id 101 and commits first
# consumer reads 101, sets last_seen_id = 101
# tx A commits 100 -> consumer never sees it
```

Fix with a transactional outbox with a dedicated processed flag or claim mechanism, or read with a safety lag and reconcile.

### 10.6 Index and query planner failure modes

- **Plans change without code changes:** statistics get stale or refreshed, the planner picks a different plan, and a query that took 5 ms takes 50 s. It happens after data growth crosses a threshold, after a bulk load, or after a version upgrade.
- **Parameter-dependent plans:** the plan is good for a typical value and terrible for a skewed one (a huge tenant or a very common value). Data skew is the root cause; averages hide it.
- **Functions on indexed columns** (`lower(email)`, casting, date truncation) defeat a plain index unless a matching expression index exists.
- **Type mismatch** between the column and the parameter (string vs number) can force implicit casts and disable index use.
- **Leading wildcard `LIKE '%x'`** cannot use a normal index.
- **Composite index order matters:** an index on (a, b) helps queries on a or on a and b, not b alone.
- **Too many indexes** slow every write and consume memory; unused indexes are a cost with no benefit. **Too few** cause scans. Both drift over time as query patterns change.
- **Foreign keys without an index on the referencing column** make parent deletes and updates scan the child table and can cause long locks (in engines that do not create it automatically).
- **Low-selectivity indexes** (a boolean flag) may not be used at all.
- **`SELECT *`** breaks covering-index benefits, transfers unneeded data, and silently changes behavior when columns are added (including large blob/text columns).
- **`OFFSET` pagination** cost grows with page depth; **`COUNT(*)`** on big tables may be a full scan.
- **Implicit ordering:** without `ORDER BY`, result order is not guaranteed and may change after vacuum, index change, or plan change. Code that "works" by accident breaks later.

**Root causes:** F (cost hidden and nonlinear), A (data distribution assumption), J (tests use small uniform data), H (no slow-query and plan-change monitoring).

**Defenses:** monitor slow queries and plan regressions, test with production-shaped skewed data, review query plans for the largest tenant, and maintain an index review process (add, prune).

### 10.7 Hot spots: rows, keys, partitions

- **Hot row:** a single counter row (`total_orders`, a "last activity" row, inventory for a flash-sale item) updated by many concurrent transactions serializes them all through one lock. Throughput collapses to one-at-a-time and latency stacks.
- **Hot partition or shard:** a key that receives disproportionate traffic (one celebrity, one big customer, a monotonically increasing key that always writes to the last partition).
- **Hot index page** from sequential keys under heavy insert.
- **Hot cache key** that every request reads.

**Defenses:** shard the counter (many rows, sum on read), buffer and batch updates, use append-only event rows and aggregate asynchronously, choose partition keys that distribute load, and add per-tenant limits.

### 10.8 Connection management

- **Connection pool math:** total connections = instances x pool size per instance. Autoscaling adds instances, which multiplies database connections, which can exhaust the database's connection limit *at the exact moment you scale because of load*.
- **Pool exhaustion:** a slow query or a held transaction keeps connections checked out; new requests wait for a connection; waits are counted as request time; timeouts trigger retries; retries need more connections.
- **Connection leaks:** code path that fails to return a connection on an error branch.
- **Stale connections:** the database, a firewall, or a load balancer silently drops idle connections; the app's pool hands out a dead one and the next query fails.
- **Failover behavior:** existing connections point to the old primary; the pool does not notice; errors persist until restart.
- **Per-connection state leakage:** session settings (timezone, search path, transaction state, temp tables) leaking to the next borrower of a pooled connection, especially with transaction-level pooling proxies.

**Defenses:** validate connections on checkout or use short lifetimes, set pool wait timeouts shorter than request timeouts, budget connections globally (with a pooler in front if needed), reset session state, alert on pool wait time and connection count as a percentage of the limit.

### 10.9 Replication, backup, and recovery depth

- **Replica lag under load:** replicas apply changes more slowly precisely when the primary is busiest. Lag causes stale reads (Part 9.8) and, for failover, potential loss of the un-replicated tail of writes.
- **Async replication failover = possible data loss** (RPO greater than zero). Whether that is acceptable is a business decision that should be explicit.
- **Split brain:** after a network partition, two nodes both accept writes. Reconciling divergent data can be impossible without loss. Requires fencing (the old primary must be *prevented* from writing, not merely believed dead).
- **Backups that are useless:** never restored, incomplete (missing config, secrets, or object storage that the database references), silently failing, corrupted from the start, replicated deletions (a replica or sync faithfully copies your mistaken `DELETE`), stored in the same account or region as the thing they protect, or deletable by the same credentials an attacker or a mistake would use.
- **Point-in-time recovery** is only real if log archiving is continuous and tested.
- **Recovery time is a measured quantity:** restoring a multi-terabyte database can take many hours. The claimed RTO must come from an actual timed drill.
- **Logical corruption vs. hardware failure:** replication protects against hardware loss but *copies* logical mistakes (bad deploy, bad script, malicious delete). Backups with history protect against that. They solve different problems.

**Drill checklist:** restore to a fresh environment, verify application-level integrity (not just "the database starts"), measure the time, and record what was missing.

### 10.10 Data-model traps that create edge cases forever

- **Unique constraints and NULL:** engines differ on whether multiple NULLs count as duplicates. A "unique when present" rule needs a deliberate design.
- **Soft delete + uniqueness:** a deleted user's email blocks re-registration unless the unique index is partial.
- **Status columns as free strings:** typos and unlisted values; no constraint. Combine with `CHECK` or a lookup table, and keep a written state-transition table.
- **Boolean flags multiplying:** `is_active`, `is_deleted`, `is_verified`, `is_suspended` create combinations (16 states for 4 flags) where most are meaningless and some are dangerous. Model a single state with defined transitions.
- **Polymorphic references** (type + id columns) cannot have a foreign key, so referential integrity is unenforced.
- **JSON blob columns** avoid schema migrations but move the schema into application code, where different writers and versions disagree. Old rows have old shapes forever.
- **Audit and history:** overwriting rows loses "what was true then" (crucial for finance, compliance, and debugging). Decide what needs history up front.
- **Time columns:** mixing `created_at` set by the application (client clock) with database time; clock skew makes ordering by it unreliable.
- **Cascade rules** that delete more than expected, or restricting rules that block legitimate cleanup.
- **Triggers and hidden side effects:** logic invisible to application developers, running in unexpected order, or slowing bulk operations.
- **Numeric types:** precision and scale too small, silent truncation or rounding in some modes, and `float` for money.
- **Text length semantics:** characters vs bytes, and silent truncation in permissive modes of some engines. Configure strict modes so errors are loud.
- **Timestamp precision:** different systems store seconds, milliseconds, or microseconds; round-tripping through one with lower precision breaks equality comparisons and version checks.
- **Collation changes:** an operating system or library upgrade that changes sort rules can invalidate existing indexes (some engines rely on the OS library), silently causing missed rows or uniqueness violations. Treat locale library upgrades on database hosts as risky.
- **Time zone in the session:** the same query returns different results depending on session time zone settings.

### 10.11 ORM-specific root causes

ORMs hide database behavior behind object-like code. The abstraction leaks in predictable ways:
- **Lazy loading** turns attribute access into queries (N+1).
- **Whole-row saves:** saving an object writes all fields it loaded, including stale values, silently overwriting concurrent changes to other fields. That is a lost-update bug even when two users edit different fields.
- **Implicit transactions and autocommit** differ from what code appears to say; a "transaction" may not cover what the developer thinks.
- **Object identity caches:** stale objects in a session; reading data that changed elsewhere.
- **Bulk operations bypass model logic:** `update()` on a queryset may skip validation, signals, or hooks that single saves run; the invariants enforced only in model code are violated by bulk paths.
- **Default scopes** (soft-delete, tenant) applied inconsistently or accidentally bypassed by raw queries and joins.
- **Migrations autogenerated** without review (dropping and recreating a column instead of renaming, losing data).
- **Model vs. actual schema drift.**
- **Generated SQL surprises:** joins multiplying rows (duplicates), `DISTINCT` masking the problem, unbounded `IN` lists.

**Root cause:** C (invariants enforced in the ORM layer, not the database) and F (hidden cost). **Rule:** treat the ORM as a convenience for the common path, and put invariants in the database so bulk paths, raw SQL, scripts, and other services cannot bypass them.

---

## Part 11: Application-Code Deep Dive

### 11.1 Representation and serialization boundaries

- **Large integers in JSON:** many parsers (notably JavaScript) use double-precision floats, safely representing integers only up to 2^53. 64-bit IDs can be silently corrupted (rounded) in transit. Send large IDs as strings.
- **Floats through text:** serializing and parsing floating-point values can change them; NaN and Infinity have no standard JSON form.
- **Missing vs null vs default:** a field omitted, set to null, and set to its default are three intents. Deserializers commonly collapse them (omitted becomes the default, null becomes zero or empty string). PATCH semantics depend on the distinction.
- **Unknown fields and unknown enum values:** strict deserializers crash when a producer adds something; lenient ones silently drop data. Decide deliberately, and make consumers tolerate additions ("tolerant reader") while validating what they use.
- **Dates and times over the wire:** ISO 8601 with explicit offset or UTC; never ambiguous local strings; watch for date-only values being converted through a timezone and shifting by a day.
- **Character encoding:** assume UTF-8 explicitly at every boundary (files, databases, HTTP, message bodies); a Byte Order Mark or a legacy encoding in an uploaded file corrupts the first field or non-ASCII names.
- **Locale-sensitive parsing and formatting:** decimal comma, thousands separators, date order, and case conversion rules (the classic Turkish dotless "i" problem: uppercasing and lowercasing are not universally reversible or ASCII-only).
- **Line endings, trailing newlines, and whitespace** in files and config values.
- **Numeric strings with leading zeros** (postal codes, phone numbers, IDs) lose the zeros when treated as numbers.

**Root cause:** B (representation vs. meaning) and D (contract semantics unspecified). **Principle:** parse at the boundary into strict domain types, and serialize deliberately with a documented schema.

### 11.2 Error-handling taxonomy

Most error-handling bugs come from not distinguishing kinds of errors:

| Kind | Example | Right response |
|---|---|---|
| Caller error (invalid input) | Bad parameter | Reject clearly; never retry |
| Transient error | Timeout, brief unavailability | Retry with backoff, limited |
| Permanent error | Not found, forbidden | Do not retry; surface |
| Conflict | Version mismatch, duplicate | Reload and retry, or resolve |
| Ambiguous outcome | Timeout after send | Verify state or use idempotency, do not assume |
| Bug / impossible state | Invariant violated | Fail loudly, alert, do not continue silently |
| Resource exhaustion | Out of memory, disk full | Shed load, protect the process |

Common failures:
- **One catch-all handler** treating all errors alike (retrying a permanent error forever, or giving up on a transient one).
- **Swallowed exceptions** and returning a plausible default (an empty list on failure is indistinguishable from "no results").
- **Error information lost** by rethrowing without context, or logging without identifiers needed to trace.
- **Errors in error handlers** (the cleanup code fails and hides the original).
- **Partial results returned as complete.**
- **Retrying inside retrying** (multiplication).
- **Exceptions crossing async or thread boundaries** and vanishing (unobserved task failures, fire-and-forget jobs that fail silently).
- **Fail-open vs fail-closed:** when an authorization or validation dependency fails, what does the code do? Deny (safe, but unavailable) or allow (available, but a security hole)? It must be a conscious per-case choice.

### 11.3 Resource lifecycle and cleanup

Everything acquired must be released on **every** path, including exceptions, timeouts, cancellations, and early returns: connections, file handles, locks, temporary files, threads, subscriptions, listeners, timers, memory buffers, and leases.

Failure patterns:
- **Leaks that only show under errors** (the release is on the success path only).
- **Unbounded in-memory structures:** caches without eviction, maps keyed by user or request ID, listeners never removed, queues in memory.
- **Lock held across slow operations** (network, disk) or across a suspension point in async code.
- **Cancellation and timeouts:** when the caller gives up, does the callee stop? If not, abandoned work continues to consume resources (and may still produce side effects).
- **Graceful shutdown missing:** in-flight work is cut off; jobs claimed but never finished.
- **Timers and schedulers** that overlap if one run exceeds the interval.

### 11.4 Shared mutable state and hidden statefulness

- **Global and static variables** in a concurrent server; per-request data stored in shared places (leaking one user's data to another).
- **Mutable default values and shared references:** modifying a list you thought was a private copy; default arguments evaluated once and reused (in some languages).
- **Shallow vs deep copy** confusion.
- **Iterators and streams consumed once:** a second pass yields nothing, silently.
- **Lazy evaluation:** an error or side effect occurs later, elsewhere, or never.
- **Caches inside functions** ("memoize") keyed incompletely (missing user, tenant, locale, or time) returning wrong-context results.
- **Singletons with initialization races.**
- **Non-thread-safe libraries** used concurrently (date formatters, some parsers, random generators).

### 11.5 Time and scheduling in code

- Use monotonic clocks for measuring durations; wall clocks can jump backward or forward (NTP correction, manual change, VM pause, DST for local time).
- Never compute "one day later" as "add 24 hours" when you mean calendar days in a local time zone.
- Don't schedule critical jobs at times that are ambiguous or nonexistent locally (during DST changes).
- **Cron and job overlap:** a job that takes longer than its interval runs concurrently with itself; a job on several instances runs several times. Use a lock or lease and a "skip if running" rule.
- **Missed runs:** if the scheduler was down, does the job run on recovery, run once, or skip? Decide deliberately.
- **Retry timing:** synchronized retries from many clients (all at the same second) create spikes; add jitter.
- **Expiring tokens mid-operation:** a long job's credentials expire halfway through.
- **Timeouts everywhere:** unspecified means infinite in many libraries.

### 11.6 Idempotency, in real depth

Earlier sections introduced the idea. These are the details that decide whether it actually works.

**Scope and identity of the key**
- The key must be scoped (per user or account and per operation type); otherwise, two different users' requests can collide, or one user can replay against another's resource.
- The key must come from the *intent*, not the attempt. If the client generates a fresh key on each retry, idempotency does nothing. It must be generated once per logical operation and reused across retries.

**Payload fingerprint**
- The same key with a *different* payload is a client bug or an attack. Store a fingerprint of the original request and reject mismatches, instead of silently returning the old result.

**In-flight duplicates**
- Two identical requests arrive at once. The second must not run in parallel. Use a state machine for the key: `started`, `completed(response)`, `failed`. A second request during `started` either waits or gets a "in progress, retry later" response.

**Crash while in progress**
- The key is `started` but the process died. It must not stay stuck forever: use a lease/timeout, then allow takeover, which requires the operation itself to be safe to resume or repeat.

**Stored response**
- Store and replay the original response (including errors that were definitive) so a retry receives the same answer. Decide which failures are cached (permanent) and which are not (transient).

**Key lifetime**
- Keys must be retained longer than the longest realistic retry window (including queue delays and manual replays). If the dedupe record expires, an old duplicate becomes a new operation.

**Side effects beyond your database**
- Idempotency in your database does not make downstream calls idempotent (sending an email, calling a payment provider, publishing an event). Each external effect needs its own idempotency key passed downstream, or an outbox with deduplication, or an accepted risk that is written down.
- A failure after the external call but before recording the key is the hardest window; the safe pattern is to record intent first, then call downstream with a deterministic key derived from the intent, then record the result.

**Naturally idempotent designs**
- "Set status to shipped" is idempotent; "increment counter" is not. "Insert if not exists by natural key" is idempotent. Prefer designs where repeating is harmless without machinery.

```
handle(key, payload):
    record = atomic insert-if-absent (key, fingerprint(payload), state='started', lease=now+T)
    if record existed:
        if record.fingerprint != fingerprint(payload): reject (misuse)
        if record.state == 'completed': return record.response
        if record.state == 'started' and lease not expired: return "in progress"
        if lease expired: take over (only safe if the operation is resumable/repeatable)
    result = do_work(deterministic downstream keys derived from key)
    mark record completed with result
    return result
```

### 11.7 Pagination, sorting, and iteration over changing data

- **Offset pagination over changing data:** insertions and deletions shift positions, so items are duplicated or skipped across pages.
- **Cursor/keyset pagination requires a total, deterministic order:** a sort on a non-unique column needs a unique tiebreaker; otherwise rows with equal values may repeat or vanish at page boundaries.
- **Sort by a nullable column:** where do NULLs go, and does the cursor comparison handle them?
- **Exporting or processing "all" records:** what if the data changes mid-run? Use a snapshot, a consistent cursor, or accept and document at-least-once semantics.
- **Deleting while iterating** over the same collection or query.
- **Stable sort assumptions,** and locale-specific sorting differences between environments.
- **Unbounded page size** parameter allows a client to request everything.

### 11.8 Concurrency in application code

- **Check-then-act** in memory (`if not exists: create`) has the same race as in the database.
- **Read-modify-write on shared counters** without atomic operations.
- **Deadlock:** two locks acquired in different orders; lock held while calling unknown code (a callback that takes another lock).
- **Async pitfalls:** blocking calls inside event loops stall everything; unbounded task creation; fire-and-forget errors lost; cancellation not propagated; shared state mutated across suspension points assuming atomicity.
- **Thread pool starvation:** tasks that wait on other tasks in the same pool can deadlock the pool.
- **Memory visibility and ordering** issues in low-level shared-memory code (rare in application code but real in caches, flags, and lazy initialization).
- **Retry plus concurrency:** a slow first attempt still running while the retry starts, both applying effects.

### 11.9 Business-logic edge cases that look "obvious" afterward

- **Negative or zero quantities, prices, discounts, and amounts;** discounts exceeding the price; refunds exceeding the payment; totals that go negative.
- **Rounding and allocation:** splitting 100 among 3 (33.33 x 3 does not equal 100). Decide where the remainder goes, and make sums reconcile.
- **Currency:** conversions at what rate and when; refund at original or current rate.
- **Tax and rounding per line vs per invoice.**
- **State transitions:** cancel after ship, refund after refund, edit after submit, reactivate after delete, change plan mid-cycle, proration.
- **Concurrent business actions:** the last item bought by two users; two coupon redemptions; simultaneous cancel and renew.
- **Ownership and permissions changes** while an operation is in flight (user removed from the organization mid-request).
- **Time-based business rules:** trial ending at midnight in whose time zone; monthly billing on the 31st; subscriptions renewing on 29 February.
- **Bulk and import features:** duplicates within the file, duplicates against existing data, encoding, partial failure reporting, re-uploading the same file.
- **Feature flags:** combinations never tested together; a flag removed while data created under it still exists.
- **Names, addresses, phone numbers, and identity:** people with one name, no last name, very long names, non-Latin scripts, multiple addresses, addresses without postal codes, and phone numbers that change. Do not validate beyond what is truly required.

**Root cause:** B (model missing real-world cases), and C (rules spread across the code).

### 11.10 Logging, observability inside code

- Logging secrets, tokens, personal data, or entire request bodies.
- Logging inside hot loops (cost, and slows the request path); synchronous logging that blocks when the log sink is slow or down.
- Log volume as a cost and as a way to bury the signal.
- **High-cardinality metric labels** (user ID, request ID as a label) cause memory and cost explosions in metrics systems and can take down the monitoring itself.
- Missing correlation IDs, so one request cannot be followed across services.
- Error logs without the input that caused them (cannot reproduce), or with too much of it (privacy).
- Timestamps in mixed time zones or formats.

### 11.11 Dependencies and the supply chain

- Unpinned versions changing behavior between builds; transitive dependency updates.
- A dependency's default (timeouts, retries, pool size, buffer limits, TLS verification) that does not match your assumptions; defaults are often "infinite" or "unlimited."
- Deprecated or abandoned libraries with unpatched vulnerabilities.
- Library upgrades changing serialization, rounding, time zone handling, or sort behavior subtly.
- A registry or package source being unavailable during an urgent build.
- Dependencies that phone home, or are unavailable at startup, blocking your service from booting.

---

## Part 12: Infrastructure Deep Dive

### 12.1 Operating system limits that silently become outages

Each of these is a finite resource with a default set by someone long ago:
- **File descriptors:** each socket and file uses one; exhaustion produces "too many open files" errors that look like network failures. Leaks and high connection counts cause it.
- **Ephemeral ports:** outbound connections use a limited range; short-lived connections to the same destination can exhaust it (many connections lingering in a waiting state).
- **Connection tracking tables** (NAT, firewalls, container networking): when full, new connections are dropped intermittently. Pure infrastructure symptom: random timeouts under load with healthy applications.
- **Process and thread limits,** memory maps, and kernel buffers.
- **Inodes:** space is free, but no new files can be created (many tiny files).
- **Memory and swap:** overcommit, swapping causing latency collapse, and the kernel killing a process (which one is not obvious).
- **Clock:** NTP failure or drift; VM pause or live migration causing time jumps; container clocks share the host's.
- **Signal handling:** in containers, the main process may ignore termination signals if it is not designed for it, leading to forced kills after the grace period and dropped work.
- **Disk performance:** burstable storage running out of burst credits (throughput suddenly falls to baseline); noisy neighbors; the log disk shared with the data disk.
- **Log and temp growth** filling the root volume.

**Root causes:** F (finite resources with no headroom monitoring) and A (defaults assumed adequate).

**Defenses:** know every limit and its current usage, alert on percentage of limit, load test to find which limit hits first, and set explicit values instead of trusting defaults.

### 12.2 Kubernetes and container orchestration edge cases

(Adapt to whatever platform you use; the patterns generalize.)

- **Requests vs limits:** resource requests determine scheduling; limits determine throttling/killing. Missing or mismatched values cause noisy neighbors, unexpected evictions, or CPU throttling that shows up as latency spikes despite low average CPU.
- **Out-of-memory kills** are abrupt (no cleanup). Memory limits below the runtime's real peak (including garbage-collector overhead and off-heap memory) create restart loops.
- **Probes:**
  - A **liveness** probe that checks dependencies can restart healthy pods during a dependency outage, turning a partial outage into total.
  - A **readiness** probe that is too lax sends traffic to pods not ready; too strict removes all pods at once under load.
  - A slow-starting application with aggressive probes is killed before it finishes starting (restart loop).
- **Termination race:** when a pod is deleted, being removed from load balancer endpoints and receiving the termination signal happen concurrently and are not synchronized. Traffic can still arrive after shutdown begins. Typical mitigation: a short delay before shutdown, handling in-flight requests, and a grace period longer than the longest request.
- **Disruption during maintenance:** node drains and upgrades evicting all replicas of a service at once without a disruption budget; replicas concentrated on one node or one zone.
- **Rolling updates:** surge and unavailable settings; new version failing readiness stalls the rollout (good) but a bug that passes readiness rolls out everywhere; both versions live at once (Part 3.7).
- **Autoscaling:** metric lag, scaling too slowly for sudden spikes, scaling on the wrong metric (CPU for an I/O-bound service), flapping, scaling up beyond what the database or downstream can handle, and scale-down killing pods with in-flight work. Cluster capacity itself may be exhausted, leaving pods pending.
- **DNS inside the cluster:** default search-path settings multiply lookups per request; the DNS service becomes a bottleneck or single point of failure under load.
- **Configuration and secrets:** a changed config not picked up until restart, or picked up on some pods but not others; a bad config map rolled out everywhere immediately.
- **Image issues:** mutable tags (`latest`) changing under you; registry rate limits or outages blocking pod starts during an incident; huge images slowing scale-up.
- **Persistent volumes:** zone affinity (a pod cannot move to another zone with its disk), slow reattachment after node failure, storage class differences.
- **Control plane dependency:** if the control plane is unavailable, running workloads usually continue but cannot be rescheduled or scaled. Know what actually stops.
- **Cron jobs:** concurrency policy (overlap), missed schedules, and job history accumulation.

### 12.3 Load balancers, proxies, and network paths

- **Idle timeout mismatch:** if the proxy closes idle connections sooner than the application expects (or the reverse), the next request on a reused connection fails intermittently, producing rare random errors that resist reproduction. Rule of thumb: the layer closer to the client should have the *longer-lived* or the chosen relationship explicitly matched with the layer behind it, and keep-alive settings must be consistent end to end.
- **Health check semantics:** shallow checks pass while the app is broken; deep checks amplify dependency failures; check frequency and thresholds determine how quickly bad nodes are removed and healthy ones are restored, and thresholds that eject too many nodes cause cascading overload.
- **Connection draining** on deploy: without it, in-flight requests are cut.
- **Request size, header size, and timeout limits** at each hop differ; a large upload works in testing and fails in production at a proxy.
- **Long-lived connections** (websockets, streaming, gRPC): unbalanced distribution (old connections stay on old nodes), thundering herd on reconnect after any blip, and connection limits.
- **Retry behavior at the proxy layer:** proxies retrying non-idempotent requests, plus application retries, plus client retries.
- **Client IP and headers:** forwarded-header trust (spoofing), rate limits keyed on the wrong IP (all users behind one proxy or NAT appear as one).
- **MTU and fragmentation** causing failures only for larger packets (small requests work, big ones hang), especially across tunnels or VPNs.
- **Asymmetric routing, security group and firewall rules** changed for one path but not another; rules that work in one direction only.
- **NAT gateway limits and single points of failure;** egress through a shared IP that a third party rate-limits or blocklists.
- **Cross-zone and cross-region traffic:** latency and cost surprises; a service that works in one zone but chatters heavily across zones.

### 12.4 DNS and certificates, in depth

**DNS**
- Caching at multiple layers (resolver, OS, runtime, application, client library); actual TTL behavior often exceeds the configured TTL. Failover by DNS change is only as fast as the slowest cache, and some clients cache indefinitely.
- Applications that resolve a name once at startup and never again keep talking to a stale address.
- Negative caching: a brief lookup failure gets cached.
- DNS as a dependency for everything: its failure looks like failure of everything else; your own recovery tooling may depend on it.
- Domain registration and DNS provider account expiry, transfer locks, and single-owner accounts.
- Dangling records pointing to decommissioned resources (takeover risk).
- Split-horizon (internal vs external) differences causing "works from here, not from there."

**Certificates and trust**
- Expiry of leaf certificates, intermediate certificates, root certificates baked into clients, internal CAs, client-authentication certificates, code-signing certificates, and signing keys for tokens (JWT keys).
- Renewal automation failing silently (a changed DNS record or firewall rule breaks the validation) and no alert on days-remaining.
- Chain changes by the issuer breaking older clients or pinned certificates.
- Certificates on systems nobody remembers (an internal admin tool, a legacy endpoint, a vendor integration, an old mobile app version with pinned certs).
- Hostname mismatches, missing intermediates that work in browsers but fail in strict clients.
- Rotation of keys without an overlap window (old and new must both be valid during transition).
- Clock skew making a valid certificate or token appear expired or not yet valid.

**Inventory approach:** enumerate everything with a validity period (certificates, tokens, API keys, passwords, licenses, domains, cloud commitments, on-call schedules), record the owner and renewal method, alert at multiple thresholds (for example 60, 30, 14, 7 days), and test renewal end to end on a schedule.

### 12.5 Cloud-provider behaviors that surprise teams

- **Quotas and limits** (instances, IPs, API rates, load balancers, storage IOPS, email/SMS sending, function concurrency); hitting one during an incident blocks scaling exactly when needed; some increases take days to approve.
- **Burst credits:** instance CPU credits or storage burst balances that run out; performance falls to a fraction of the baseline, looking like a mysterious slowdown weeks after launch.
- **Control-plane vs data-plane:** during regional issues, the ability to launch, scale, or change resources (control plane) often degrades even while running resources (data plane) work. Recovery plans that depend on creating new resources in the failing region are fragile.
- **Eventual consistency in the platform:** a newly created resource or permission not yet visible everywhere; automation that creates then immediately uses a resource intermittently fails.
- **IAM/permission propagation and over-permissioning:** overly broad roles turn any compromise or bug into a large blast radius; missing permissions found only when the code path first runs in production.
- **Zone imbalance and capacity:** an instance type unavailable in a zone at the moment you need it; all replicas landing in one zone.
- **Managed service maintenance windows and forced upgrades** occurring at inconvenient times or changing behavior.
- **Service deprecations and end-of-life dates,** including runtime versions that stop receiving updates.
- **Cost as an availability risk:** an unexpected bill, a runaway autoscale, a data-transfer surprise, or an attack generating usage can lead to account suspension or forced shutdown. Budgets and anomaly alerts are part of reliability.
- **Account-level single points of failure:** one root account, one billing owner, one payment method, one cloud account containing prod, staging, backups, and logs together.
- **Shared responsibility gaps:** assuming the provider handles something (backups, encryption, patching, failover) that is actually the customer's job.

### 12.6 Infrastructure as code, CI/CD, and change pipelines

- **State file risks:** lost, corrupted, or concurrently modified state; two people applying at once; state containing secrets.
- **Plan vs apply divergence:** reviewed plan differs from what is applied because the world changed in between.
- **Replace vs update:** a small-looking change that forces resource *replacement* (destroying and recreating a database, a load balancer, or an IP address). Reviewers must scan specifically for destroy/replace markers.
- **Drift:** manual console changes not reflected in code, then reverted or destroyed by the next apply.
- **Deletion protection and prevent-destroy** flags off on critical resources.
- **Blast radius of one repo or pipeline:** one pipeline has credentials to all environments; a bad merge deploys everywhere; a compromised CI token owns production.
- **Secrets in CI logs,** environment variables, images, or repositories.
- **Pipeline as a single point of failure:** you cannot ship a fix because CI is down; there is no documented emergency path.
- **Non-reproducible builds:** rebuilding the same commit gives a different artifact; you cannot roll back to "what was running."
- **Rollback reality:** rolling back code without rolling back data or config; the previous artifact no longer exists in the registry (retention policy deleted it).
- **Environment parity:** staging has different versions, scale, data shape, config, and access rules, so a "green" staging proves little.
- **Deploy timing and freeze:** deploying on Friday or before a holiday, deploying during peak, or multiple simultaneous changes making causes impossible to isolate.

### 12.7 Observability, alerting, and incident response depth

- **Cardinality explosions** in metrics (unbounded label values) and log volume explosions during an incident (errors logged per request multiply) can take down monitoring and cost enormous amounts precisely when needed.
- **Sampling** that drops the rare events you care about.
- **Alerting on causes vs symptoms:** alerts for "CPU high" produce noise; alerts on user-visible outcomes (error rate, latency, successful transactions) with cause-level metrics for diagnosis are more useful. But *both* are needed: symptom alerts detect, cause metrics explain.
- **Missing-data alerts:** if the metric stops arriving (agent down, pipeline broken), most alerts stay silent because "no data" is not "bad data." Alert on absence of expected signals ("dead man's switch" / heartbeat).
- **Alert routing:** alerts to a person on leave, a channel nobody reads, a phone number that changed, or an escalation policy with a gap.
- **Runbook decay:** commands that no longer work, links that are dead, access that the on-call engineer does not have.
- **Access during incidents:** the break-glass procedure is untested; MFA device holder unavailable; the password manager depends on the failing system.
- **Communication dependencies:** incident chat, status page, and video calls hosted on the same infrastructure or SSO that is down.
- **Dashboards that look healthy** because they average across regions or tenants; percentiles computed incorrectly (averaging percentiles is not valid).
- **Time sources:** dashboards in different time zones, logs with skew between hosts, making incident timelines wrong.
- **Retention:** logs and metrics older than N days are gone when you need to compare with "last month" or investigate a slow-burn problem.

### 12.8 Security-driven infrastructure edge cases

- **Secrets rotation** breaking things because consumers cache old secrets, or because rotation is an untested manual procedure.
- **Least privilege vs operability:** permissions too tight break production at 3 a.m. in an untested path; too broad create large blast radius. Test the permission model, including the emergency paths.
- **Network exposure:** a database, admin panel, metrics endpoint, or debug port reachable from the internet through a rule change or default.
- **SSRF and metadata services:** application that fetches URLs can be made to reach internal endpoints, including the cloud instance metadata service, and obtain credentials.
- **Supply chain and build trust:** unverified base images and dependencies; compromised CI.
- **Logging as data leak:** personal data or credentials in logs shipped to third parties.
- **Insider and mistake risk:** broad standing production access, no audit trail, no second-person review for destructive operations.
- **Rate limiting keyed on the wrong identity,** or absent on expensive endpoints, turning normal abuse into an outage or a cost incident.
- **Denial via expensive input:** regex backtracking, huge payloads, deeply nested JSON, zip bombs, unbounded query complexity (GraphQL depth, huge filter lists), large file image processing.

---

## Part 13: Categorizing Issues (Multiple Lenses)

A single category list is not enough, because the same issue matters differently depending on the question you are asking. Classify each finding along several axes.

### Axis 1: By what breaks (impact type)
- **Data integrity** (wrong, lost, duplicated, or inconsistent data). Usually the most serious because it is often irreversible and silent.
- **Availability** (outage, partial outage, degradation).
- **Performance and capacity** (latency, throughput, saturation).
- **Correctness/semantic** (system runs but gives wrong results, e.g., wrong totals, wrong recipients).
- **Security and privacy** (unauthorized access, leakage, abuse).
- **Financial and cost** (money charged or lost, runaway bills).
- **Compliance and legal** (retention, erasure, audit, regulated data).
- **Operability** (cannot diagnose, cannot recover, cannot deploy).
- **Trust and reputation** (visible errors, wrong emails, lost user work).

### Axis 2: By how it manifests over time
- **Immediate and loud** (crash on first call).
- **Immediate and silent** (wrong result, no error).
- **Load-triggered** (appears only at scale or concurrency).
- **Time-triggered** (dates, expiries, counters).
- **Change-triggered** (deploy, migration, config, dependency update).
- **Accumulating** (slow creep: bloat, backlog, drift, leak).
- **Correlated/cascading** (one event triggers many).
- **Rare-combination** (needs two or three conditions to align).

### Axis 3: By detectability
- **Loud and immediate:** fails visibly, is caught quickly.
- **Loud but delayed:** fails visibly later (a job that fails the next night).
- **Silent, self-revealing:** silent now but will surface eventually (a growing table).
- **Silent, permanent:** never surfaces unless someone audits (wrong data that looks plausible).

The silent, permanent category deserves the most attention per unit of probability, because there is no natural moment where it announces itself.

### Axis 4: By reversibility
- **Reversible and cheap** (redeploy).
- **Reversible with effort** (restore from backup, backfill).
- **Partially reversible** (some data recoverable).
- **Irreversible** (sent emails, external payments, deleted data with no backup, leaked secrets, regulatory exposure).

### Axis 5: By blast radius
- One request, one user, one tenant, one feature, one service, one region, everything, and *everything including recovery tools*.

### Axis 6: By root cause family (from Part 2)
A through K. Every finding should carry one primary and possibly secondary families, so you can see which structural weaknesses recur across findings.

### Axis 7: By control that could have prevented it
- **Prevent:** type, constraint, design that makes it impossible.
- **Detect:** monitor, alert, reconciler, audit.
- **Limit:** rate limit, quota, isolation, circuit breaker, feature flag.
- **Recover:** backup, rollback, runbook, failover.
- **Learn:** postmortem, test, checklist, ownership.

### Prioritization

Rank by **likelihood x impact x (1 / detectability) x irreversibility**, then adjust for blast radius and time to manifest. A common ordering, from most to least dangerous per occurrence: silent and permanent and irreversible data corruption; irreversible security or financial exposure; unrecoverable loss of backups or recovery ability; total outages with slow recovery; degradations that reduce trust; cosmetic or self-healing issues.

A quick classification record for each finding:

```
finding:            <one line>
impact type:        <Axis 1>
manifests as:       <Axis 2>
detectability:      <Axis 3>
reversibility:      <Axis 4>
blast radius:       <Axis 5>
root cause family:  <Axis 6, primary + secondary>
current controls:   prevent / detect / limit / recover (which exist? do they work?)
class-level fix:    <what removes the whole class>
sibling search:     <where else does this same condition exist>
owner + review date
```

---

## Part 14: Detection Deep Dive (Invariant Monitoring and Reconciliation)

Prevention fails eventually, so the second layer is continuously checking that reality still matches your rules. This is the practical answer to "silent failure."

### 14.1 Invariant catalog (write these down, then check them on a schedule)

Examples of the kinds of invariants to convert into automated checks:

**Referential and structural**
- No orphaned child rows; no rows referencing deleted parents.
- Every entity in a lifecycle state has the fields required for that state.
- No duplicates on natural keys that should be unique (even where a constraint cannot exist, for example across systems).

**Cross-record and cross-system**
- Sum of ledger entries equals the account balance.
- Payments received at the provider equal payments recorded internally (reconcile both directions: recorded but not at provider, and at provider but not recorded).
- Search index or cache count roughly equals source-of-truth count.
- Every published event has a matching source row and vice versa.

**Lifecycle and time**
- Nothing sits in a transient state (pending, processing, in-flight) longer than its expected maximum.
- Every scheduled job ran within its expected window.
- Every subscription/trial/token that should have expired has.

**Capacity and headroom**
- Percent used of every finite resource (disk, inodes, IDs, connections, quotas, certificate validity days).

```
reconciler examples (pseudocode):

stuck_items:    select count(*), min(created_at) from jobs
                where state in ('pending','processing') and updated_at < now - max_expected
                -> alert if count > 0

orphans:        select count(*) from children c left join parents p on p.id = c.parent_id
                where p.id is null
                -> alert if > 0

ledger_balance: select account_id from accounts a
                where a.balance != (select sum(amount) from ledger where account_id = a.id)
                -> alert on any row

two_way_recon:  A = ids in our system for yesterday; B = ids at provider for yesterday
                alert on (A minus B) and (B minus A)

id_headroom:    current_max_id / type_max  -> alert at 50%, 70%, 85%
```

### 14.2 Leading indicators (signals that precede failure)

- Age of the oldest item in every queue and every "in progress" state (more useful than queue length).
- Replication lag and its trend.
- Age of the oldest open database transaction.
- Connection pool wait time and pool utilization.
- Percentage of every limit used; time-to-exhaustion projection based on growth rate.
- Retry rate, timeout rate, and circuit breaker state changes.
- Cache hit ratio and miss latency; drops indicate impending database load.
- Error budget burn rate.
- Rate of constraint violations, deadlocks, and serialization failures (they show concurrency stress).
- Slow-query count and plan changes.
- Dead-letter queue depth and age.
- Certificate and credential days remaining.
- Deploy frequency vs. rollback frequency; config change frequency.
- Number of "temporary" exceptions and known-risk items past their review date.

### 14.3 Testing the detectors

A detector that has never fired is unverified. Periodically inject a known-bad condition in a safe environment (an orphan row, a stuck job, a stopped metric) and confirm that the alert fires, reaches the right person, and that the runbook works. Also alert when detectors themselves stop running (heartbeat).

---

## Part 15: More Worked Cases (Root-Cause Chains)

### Case 7: The migration that took the site down (lock queue)

- **Symptom:** the whole application hangs for two minutes during a routine deploy.
- **Trigger:** an "instant" schema change ran while a slow reporting query held a lock on the same table.
- **Proximate cause:** the schema change waited for its lock, and every subsequent query queued behind it, exhausting the connection pool.
- **Contributing conditions:** no lock timeout on migrations; no check for long-running queries; the reporting query ran against the primary.
- **Root causes:** **F** (unbounded waiting), **G** (a hot table shared by every endpoint), **E** (the assumption that DDL is atomic and instantaneous), **K** (migrations are reviewed for correctness but not for locking behavior).
- **Class-level fix:** migrations run with a short lock timeout and retry; a pre-flight check for long transactions; reporting moved to a replica; connection pool wait limits so the failure sheds instead of hanging.

### Case 8: The replica read that approved an overdraft

- **Symptom:** an account went negative despite a "sufficient balance" check.
- **Trigger:** two withdrawals close together.
- **Proximate cause:** the balance check read from a lagging replica (and even from the primary, the read and the write were not atomic).
- **Root causes:** **E** (check separated from act), **C** (the invariant "balance is not negative" not enforced where the data lives), **A** (assuming replicas are current), plus the consistency spectrum of Part 9.8.
- **Class-level fix:** a conditional atomic update (`decrease only if balance is sufficient`) or a `CHECK` constraint on the primary; never use replica reads for decisions; add a ledger reconciler.

### Case 9: The silent skipped rows in an event consumer

- **Symptom:** a downstream report is missing about 0.01% of orders, with no errors anywhere.
- **Trigger:** transactions committing out of order under load.
- **Proximate cause:** the consumer tracked "highest ID seen" and skipped a lower ID that committed later (Part 10.5).
- **Root causes:** **E** (ordering assumption: ID order equals commit order), **H** (no reconciliation between source and downstream), **J** (never tested under concurrent commits).
- **Class-level fix:** an outbox with claim/processed state instead of an ID high-water mark, a reconciliation count job, and a concurrent-load test.

### Case 10: The "safe" liveness probe

- **Symptom:** a brief database blip becomes a full outage that lasts 20 minutes.
- **Trigger:** database latency increases for 30 seconds.
- **Proximate cause:** the liveness probe called the database; probes failed; the orchestrator restarted every instance; all instances restarted simultaneously and stampeded the database with cold caches and new connections.
- **Root causes:** **G** (a soft dependency turned into a hard one across the entire fleet), **F** (positive feedback: restarts increase database load), **D** (the meaning of "liveness" mismatched with "readiness"), and the **metastable** pattern (Part 9.2).
- **Class-level fix:** liveness checks only process health (no external dependencies); readiness reflects dependencies with limits so not all instances are removed at once; staggered restarts; connection ramp-up and cache warming; database connection limits protecting the database from client stampedes.

### Case 11: The unique constraint that was not

- **Symptom:** duplicate customer accounts with "the same" email.
- **Trigger:** signups with different letter case, and two concurrent signups.
- **Proximate cause:** the uniqueness check was in application code against a case-sensitive column.
- **Root causes:** **B** (identity of an email not defined: case, whitespace, aliases), **C** (uniqueness not enforced by the database), **E** (race between check and insert).
- **Class-level fix:** normalize at the boundary into a canonical form; unique index on the canonical form (partial if soft-deleting); handle the conflict error as the normal path for the race.

### Case 12: The burst-credit slowdown

- **Symptom:** database performance degrades sharply about three weeks after a launch, with no code change.
- **Trigger:** accumulated load crossed what the baseline allows.
- **Proximate cause:** the storage volume exhausted its burst balance and throttled to baseline throughput.
- **Root causes:** **F** (finite hidden resource), **H** (burst balance not monitored), **A** (the launch-week performance assumed to be steady-state), **J** (load tests too short to drain the balance).
- **Class-level fix:** identify every burstable resource, monitor credit balance, provision for sustained baseline, run soak tests long enough to deplete burst allowances.

### Case 13: The backup that restored nothing useful

- **Symptom:** after an accidental deletion, the restore succeeds technically but the application fails.
- **Trigger:** the data restore did not include files stored outside the database and encryption keys held elsewhere.
- **Root causes:** **J** (recovery never rehearsed end to end), **G** (hidden dependency of the data on other stores and keys), **K** (backup ownership limited to "the database").
- **Class-level fix:** define recovery as "application working," not "database restored"; enumerate all state (databases, object storage, queues, configs, keys); drill full restore on a schedule and time it.

---

## Part 16: Additional Review Tools

### 16.1 Deep questions by system element

**For every function or endpoint**
- What are all the outcomes (including "unknown")? Which are handled distinctly?
- What does it assume about its caller and its inputs, and where is that enforced?
- What does it change? Can it be run twice? Concurrently? Halfway?
- What is its worst-case time and memory as inputs grow?
- What does it depend on, and what does it do when each dependency is slow, failing, or lying?

**For every table**
- What are its invariants, and which are enforced by the database?
- How does it grow, how big is the largest tenant, and what is the archive/deletion plan?
- What are the hot rows and hot keys?
- What is every writer (services, scripts, admin tools, migrations, imports)?
- What happens on an empty table, and at 100x?

**For every queue or stream**
- Delivery guarantee, ordering guarantee, retention, maximum message size, poison message handling, and backlog behavior?
- What is the oldest-message-age alert, and who owns the dead-letter queue?

**For every external dependency**
- What is the timeout, retry policy, and circuit breaker? What is the defined degraded behavior? What is its documented rate limit and our headroom? What happens if it is down for a day? What is our exit or fallback path?

**For every scheduled job**
- What if it overlaps with itself? What if it runs on two nodes? What if it is skipped for a day? What if it takes 10x longer? Is it resumable and idempotent? Who is alerted on failure *and* on non-execution?

**For every deploy or change**
- Is it compatible with both old and new versions running? Is the data part reversible? Is it staged? What is the automated rollback trigger? Who is watching it?

**For every "temporary" solution**
- Who owns removal, and by when? What is the risk while it exists?

### 16.2 Adversarial review roles

Assign reviewers (real or mental) to attack from different roles:
- **The pessimist:** "Assume every dependency fails at the worst moment."
- **The malicious user:** "How do I get another customer's data or free money?"
- **The tired operator at 3 a.m.:** "What single wrong command is easiest to type?"
- **The future maintainer:** "What will I misunderstand about this in a year?"
- **The auditor/accountant:** "Can you prove every number reconciles?"
- **The scale skeptic:** "Show me the biggest customer at ten times growth."
- **The new hire:** "What is undocumented that everybody 'just knows'?"

### 16.3 A depth ladder for any single edge case

When you find one edge case, keep asking until you reach something structural:

1. **What** exactly happens? (reproduce it precisely)
2. **When** does it happen? (what conditions must align)
3. **Why** is that possible? (which assumption or missing rule)
4. **Why was it not prevented?** (which barrier is missing)
5. **Why was it not detected?** (which signal is missing)
6. **Why is it hard to recover?** (which reversibility or rehearsal is missing)
7. **Where else** does the same condition exist? (search for siblings)
8. **Why does our process allow this class?** (review, ownership, incentive, tooling)
9. **What single structural change removes the class?**
10. **How will we know the class stays removed?** (test, monitor, guard in CI)

### 16.4 Design-review prompts you can paste into any design document

- **Assumptions:** "This design is correct only if the following are true: ..." (each with: enforced, monitored, or merely believed).
- **Failure modes table:** for each component and dependency: how it fails (down, slow, wrong, duplicated, reordered), how we detect it, what the user experiences, how we recover.
- **Limits table:** for each resource, the limit, current usage, growth rate, alert threshold, and action at the threshold.
- **Invariants list:** each with owner, enforcement location, and reconciler.
- **Rollback plan:** including data and configuration, and whether it has been rehearsed.
- **Blast radius statement:** the worst thing one bad input, tenant, or release can do.
- **Not handled:** an explicit list of edge cases knowingly out of scope, with the reason and the revisit date. (Undocumented omissions are indistinguishable from oversights.)

---

## Part 17: Additional Principles (Extending Part 8)

16. **Never wait without a limit.** Every lock, connection, queue wait, and remote call has a timeout shorter than its caller's.
17. **Treat "unknown" as a first-class outcome.** For every remote effect, design what happens when you do not know.
18. **Put atomicity where a single system can provide it,** and use outbox plus idempotency for everything that crosses systems.
19. **Decisions require fresh, authoritative data.** Reads from caches and replicas are for display, not for enforcing rules.
20. **Design the sad path of every safeguard.** Retries, failovers, caches, health checks, and autoscalers each have a failure mode that can worsen the incident.
21. **Prefer many small, reversible, staged changes to few large ones.** Especially for schemas, data backfills, and configuration.
22. **Measure headroom, not just health.** "How far from the limit?" predicts failure; "is it up?" reports it afterward.
23. **Alert on outcomes and on the absence of expected signals.**
24. **Automate the boring recurrent risk:** expiries, renewals, rotations, backups, restore drills, drift detection.
25. **Keep recovery independent of the thing being recovered:** access, tooling, documentation, communication.
26. **Every exception to the rule has an owner and an expiry date.**
27. **Make the model match reality before optimizing anything:** most bugs in data code are modeling bugs that no amount of care downstream can fix.
28. **Quantify with simple math:** pool sizes (Little's Law), retry amplification, fan-out tail probability, growth-to-limit time. Back-of-envelope numbers reveal cliffs that intuition misses.

---

## Operational Verification Checklist

For the actionable SDLC and database/architecture review checklist derived from Volume 2, see:
👉 **[Checklist 02: Architecture, Database & Concurrency Mechanisms](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/02-architecture-database-and-mechanisms-checklist.md)**  
👉 **[Master Engineering Checklist Index](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/00-master-engineering-checklist.md)**
