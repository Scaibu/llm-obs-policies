# Category 1: Concurrent state changes and effect integrity

**Problem statement:** Many actors (requests, services, retries, consumers) change shared state at overlapping times, over unreliable networks and clocks. The system must keep business invariants true and make each real-world effect happen as intended. Failure here is silent: the system keeps running while the data becomes wrong.

**Subproblems:** 1A isolation and locking inside one database. 1B duplicates and lost effects across boundaries. 1C time and mutual exclusion in distributed settings.

## 1A. Isolation and locking

#### 1.1 "We use transactions, so we're correct" (was #13) [Certain]
- **Why wrong:** A transaction guarantees atomicity and durability for a unit of work. Isolation is a tunable level, and the common defaults (PostgreSQL Read Committed, InnoDB Repeatable Read) permit lost updates and write skew.
- **What is correct:** Correctness is an invariant plus a mechanism that makes violating interleavings impossible. The transaction is only part of that mechanism.
- **Problem it creates:** Rare interleavings corrupt data (double-booked seat, negative stock, two on-call doctors both leaving) with no error raised.
- **First-principles fix:** Write the invariant as a predicate over rows. List every pair of operations that can jointly violate it. Remove each pair with the cheapest mechanism that covers the predicate's full read set: an engine-enforced constraint, an atomic single-statement update, a lock on a shared row, or SERIALIZABLE with retry.
- **Meta:** Can I state the invariant as a predicate? Does my mechanism cover rows the check reads, including rows that don't exist yet (phantoms)?
- **Second-order:** What are the retry rate and latency under SERIALIZABLE at peak? Does serializing this pair create a hot row that becomes the next bottleneck?

#### 1.2 "Optimistic concurrency is always better than locking" (was #53) [Likely]
- **Why wrong:** Optimistic control wins only when conflicts are rare. Abort rate climbs with contention, and retried work compounds the load.
- **What is correct:** Choose control by conflict probability: validate-at-commit for low contention, lock-first for high contention.
- **Problem it creates:** Retry storms on hot rows, collapsing throughput, starved long operations.
- **First-principles fix:** Estimate conflict probability from the key distribution and concurrency. If waiting is cheaper than redoing work, serialize with a lock, a per-key queue, or a single-writer actor. Measure conflict rate per entity and switch strategy where it crosses your threshold.
- **Meta:** Are concurrent writes spread evenly or skewed onto a few keys? What does one retry cost compared with one wait?
- **Second-order:** Does locking introduce deadlocks and head-of-line blocking? Does per-key queuing hurt tail latency for cold keys?

#### 1.3 "Locks only affect the rows I modify" (was #59) [Certain]
- **Why wrong:** Lock scope follows the access path. FK checks lock referenced rows, InnoDB gap and next-key locks protect index ranges, and scans can lock what they examine.
- **What is correct:** A statement locks what its plan touches and what the isolation level must protect, not just what it finally changes.
- **Problem it creates:** Surprise blocking, deadlocks between unrelated-looking transactions, inserts stalled by range locks.
- **First-principles fix:** Reason from the plan, not the SQL. Narrow the access path with a selective index, acquire locks in one global order (for example by primary key), keep transactions short, and confirm real lock scope in the engine's lock-wait and deadlock views.
- **Meta:** Do I know this engine's locking rules at my isolation level? Which plan node touches rows I didn't intend?
- **Second-order:** Does the narrower index add write cost elsewhere? Does the global lock order conflict with the order business logic naturally touches rows?

#### 1.4 "Wrap the whole business operation, external calls included, in one transaction" (was #57) [Certain]
- **Why wrong:** A transaction holds locks and a connection until commit, so a slow external call sets your lock duration. If the commit fails after the call succeeded, the call can't be undone.
- **What is correct:** Transactions protect database state only. External effects need their own atomicity strategy.
- **Problem it creates:** Pool exhaustion, long lock holds, inconsistent outcomes (money moved, order not recorded).
- **First-principles fix:** Split into two phases. Atomically record the intent in the database (an outbox row), then perform the external effect from a retried, idempotent worker, and reconcile ambiguous outcomes.
- **Meta:** What happens if the process dies after the external call but before commit? What if it dies before the call?
- **Second-order:** Does the "pending" state leak to users or other services? Who owns reconciliation when the external system disagrees?

## 1B. Duplicates and lost effects across boundaries

#### 1.5 "The client retrying makes the write safe" (was #54) [Certain]
- **Why wrong:** A timeout doesn't reveal whether the first attempt happened, so retrying a non-idempotent operation can repeat it.
- **What is correct:** Safety under retry is a property of the receiver: the effect must depend on the operation's identity, not on how many times it was delivered.
- **Problem it creates:** Duplicate charges, emails, shipments, ledger entries.
- **First-principles fix:** The sender generates a stable operation ID. The receiver stores (operation ID → result) under a unique constraint in the same transaction as the effect, and returns the stored result on repeats.
- **Meta:** What identifies "the same operation," and who generates it? How long must I remember IDs?
- **Second-order:** What if the same ID arrives with a different payload? Does the dedupe table itself become a growth and hot-spot problem?

#### 1.6 "Our queue guarantees exactly-once delivery" (was #55) [Certain]
- **Why wrong:** Brokers can offer exactly-once processing only inside their own transactional scope. Across a network and a separate datastore, ambiguous failures cause redelivery.
- **What is correct:** Reliable messaging is at-least-once delivery plus idempotent processing, which produces effectively-once effects.
- **Problem it creates:** Duplicate side effects after rebalances, timeouts, and consumer restarts.
- **First-principles fix:** Make every handler a function of the message ID. Record processed IDs in the same transaction as the effect, or make the effect naturally idempotent (upsert by key).
- **Meta:** Where does my side effect sit relative to the offset commit? Which failure between them duplicates or loses a message?
- **Second-order:** How long do I retain processed IDs compared with the broker's redelivery window? Does dedupe interfere with ordering assumptions?

#### 1.7 "Write to the database, then publish the event" (was #56) [Certain]
- **Why wrong:** Two systems can't be updated atomically without a shared transaction, so a crash between the writes leaves them inconsistent.
- **What is correct:** One system is the source of truth, and the other is derived from it.
- **Problem it creates:** Lost events (state changed, nobody notified) or phantom events (notified, state never changed).
- **First-principles fix:** Write state and an outbox row in one local transaction. A relay publishes outbox rows at least once, and consumers dedupe. Alternatively, tail the database log (CDC).
- **Meta:** Which store is the source of truth? What is the maximum acceptable delay between state change and event?
- **Second-order:** Does the outbox need cleanup and partitioning? What ordering does the relay preserve, and do consumers depend on more than that?

#### 1.8 "IDs commit in order, so I can poll with id > last_seen" (was #58) [Certain]
- **Why wrong:** Allocation order differs from commit order. A transaction holding ID 100 can commit after one holding 101 was read, so the poller passes 101 and never sees 100. Rollbacks also leave gaps.
- **What is correct:** Visibility order is decided at commit, not at key allocation.
- **Problem it creates:** Silently skipped rows in syncs, exports, and event pipelines.
- **First-principles fix:** Read from a commit-ordered source: logical decoding/CDC, or an outbox whose cursor advances only below the oldest in-flight transaction. A fallback is to re-read a safety window with idempotent handling.
- **Meta:** What ordering does my consumer actually need? How would I detect one skipped row?
- **Second-order:** Does the safety window create duplicates that need idempotency? How much latency does waiting for in-flight transactions add?

## 1C. Time and mutual exclusion

#### 1.9 "Clocks are synchronized and monotonic" (was #91) [Certain]
- **Why wrong:** Physical clocks drift, jump (NTP steps, leap seconds), and stall (VM pauses), and machines disagree.
- **What is correct:** Wall-clock time orders events only within its error bound. Causality needs logical ordering.
- **Problem it creates:** Last-write-wins on timestamps drops newer writes, and expiries and token validation misbehave.
- **First-principles fix:** Use database-assigned versions or sequences, hybrid logical clocks, or compare-and-set on a version column. Use wall-clock time only for display and tolerant TTLs.
- **Meta:** Which decision depends on "which happened first"? What is the worst clock error across my machines?
- **Second-order:** Does a version allocator become a bottleneck? How do versions merge across regions?

#### 1.10 "A Redis lock guarantees mutual exclusion" (was #92) [Certain]
- **Why wrong:** A lock is a lease. A holder can stall past its lease and keep writing while a new holder also writes, and the lock service can't stop a stale holder.
- **What is correct:** Mutual exclusion holds only when the protected resource rejects stale holders.
- **Problem it creates:** Two workers act on the same entity with conflicting or duplicate writes.
- **First-principles fix:** Issue a monotonically increasing fencing token with each grant, and have the resource reject writes carrying an older token. Better, avoid the external lock: use a database row lock, unique constraint, or route each key to a single writer.
- **Meta:** What happens if the holder pauses 30 seconds mid-operation? Does the resource know who is current?
- **Second-order:** Where does the token come from, and does that source need consensus? Can key-to-single-writer routing replace locking entirely?

---
