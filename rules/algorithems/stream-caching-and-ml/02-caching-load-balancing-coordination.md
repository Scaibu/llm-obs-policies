# Part 2: Caching, load balancing and distributed coordination (#51–100)

Same format and the same contract (roles; rules T1–T8; guardrails TX1–TX5). Already covered elsewhere and not repeated: consistent hashing basics (G79), Raft (G76, V#136), leader leases and fencing (G74–G75), vector and Lamport clocks (G80), token bucket (G66), circuit breakers (G36), hedged requests (G75 in code ref), gossip (graph #309), two-phase commit (G86), quorums (V#137).

## B1. Cache eviction and admission

### 51. LRU (least recently used)

**Definition:** An eviction policy that removes the item that hasn't been accessed for the longest time.

**Cost:** O(1) per operation. Two pointers per entry.

### 52. LFU (least frequently used) in O(1)

**Definition:** An eviction policy that removes the item with the fewest accesses, implemented with constant-time operations.

**Cost:** O(1) per operation.

### 53. CLOCK and CLOCK-Pro

**Definition:** Approximations of LRU that avoid moving items on every access, by using a reference bit and a circular "clock hand".

**Cost:** O(1) access. Amortized O(1) eviction.

### 54. ARC (adaptive replacement cache)

**Definition:** An eviction policy that balances recency and frequency automatically, adapting to the workload by learning from recently evicted keys.

**Cost:** O(1) per operation. Ghost lists cost memory for keys.

### 55. 2Q and segmented LRU (SLRU)

**Definition:** Scan-resistant policies that require items to prove their value in a probationary area before entering the main (protected) area.

**Cost:** O(1).

### 56. W-TinyLFU (windowed TinyLFU admission)

**Definition:** A high-hit-ratio cache design combining a small LRU window for new items with a frequency-based admission filter that decides whether a newcomer deserves to replace an existing item.

**Cost:** O(1). The sketch uses about 1 byte per cached entry.

### 57. S3-FIFO

**Definition:** A simple, scalable eviction policy using three FIFO queues, which removes most one-hit items quickly and matches or beats LRU-based policies on many real workloads.

**Cost:** O(1), with very low per-access overhead.

### 58. Hierarchical timing wheels (TTL expiry and timers)

**Definition:** A data structure for managing very large numbers of timers (TTLs, timeouts) with O(1) insertion and expiry.

**Cost:** O(1) per timer operation.

## B2. Cache patterns and consistency

### 59. Write policies (write-through, write-back, write-around)

**Definition:** Rules for how writes are applied to the cache and the backing store.

**Cost:** Trades write latency against durability and consistency.

### 60. Cache-aside, read-through and refresh-ahead

**Definition:** Patterns for how data gets into a cache on reads, and how it's kept fresh.

**Cost:** Refresh-ahead costs extra background loads.

### 61. Cache stampede prevention (request coalescing, probabilistic early expiration)

**Definition:** Preventing many simultaneous misses on the same key (when a popular item expires) from overwhelming the backing store.

**Cost:** Small.

### 62. Cache invalidation (versioned keys, event-driven invalidation, leases)

**Definition:** Keeping cached data consistent with the source when the source changes.

**Cost:** Event pipelines or version tracking.

### 63. Negative caching

**Definition:** Caching "not found" results, so repeated lookups for missing keys don't hit the backing store every time.

**Cost:** Small.

### 64. Consistent hashing with bounded loads

**Definition:** Consistent hashing extended so no server receives more than (1 + ε) times the average load, by overflowing to the next server on the ring.

**Cost:** Small extra lookups when servers are full.

### 65. Multi-tier caching and hot-key replication

**Definition:** Layering caches (in-process near caches in front of a distributed cache in front of the store), and replicating extremely hot keys to many nodes.

**Cost:** Memory for duplicate copies. Invalidation traffic.

## B3. Load balancing and overload control

### 66. Smooth weighted round-robin

**Definition:** Distributing requests across servers in proportion to their weights, while spreading each server's turns evenly rather than in bursts.

**Cost:** O(n) per pick (fine for small server counts).

### 67. Least connections and least outstanding requests

**Definition:** Sending each request to the server with the fewest active connections or in-flight requests.

**Cost:** O(n), or O(log n) with heaps.

### 68. Power of two choices

**Definition:** Picking two servers at random and sending the request to the less loaded one, which gives nearly optimal balance with very little coordination.

**Cost:** O(1) per request.

### 69. Maglev hashing

**Definition:** A consistent hashing scheme that builds a lookup table for very fast, evenly balanced, minimally disruptive mapping of flows to backends.

**Cost:** O(1) lookups. O(M × number of backends) table rebuilds.

### 70. Rendezvous hashing (highest random weight)

**Definition:** Assigning each key to the server with the highest hash score for that (key, server) pair, which gives consistent assignment without a ring.

**Cost:** O(n) per lookup (fine for small n). Hierarchical variants for large n.

### 71. Jump consistent hash

**Definition:** A tiny, memory-free consistent hash that maps a key to one of n numbered buckets, moving only about 1/n of keys when n grows.

**Cost:** O(log n) time, no memory.

### 72. Peak-EWMA latency-aware load balancing

**Definition:** Choosing servers by a latency estimate that reacts instantly to spikes and decays slowly, combined with in-flight load.

**Cost:** O(1) per request.

### 73. CoDel (controlled delay queue management)

**Definition:** An active queue management algorithm that controls queueing delay (not queue length), dropping or rejecting requests when delay stays above a target too long.

**Cost:** Timestamps per request.

### 74. Adaptive concurrency limits (AIMD, Vegas, gradient)

**Definition:** Discovering a service's safe number of concurrent requests automatically from measured latency, like TCP congestion control applied to request concurrency.

**Cost:** O(1) per request.

### 75. Outlier detection and ejection

**Definition:** Automatically removing misbehaving backends from load-balancing rotation, based on their recent errors or latency compared with their peers.

**Cost:** Small.

## B4. Consensus and replication

### 76. Paxos (single-decree)

**Definition:** The classic algorithm for a group of processes to agree on a single value, tolerating crashes of a minority, with safety even under message delays and losses.

**Cost:** Two round trips to a majority.

### 77. Multi-Paxos

**Definition:** Paxos extended to agree on a sequence of values (a replicated log) efficiently, with a stable leader skipping phase 1 for most entries.

**Cost:** One round trip per command in steady state.

### 78. ZAB and viewstamped replication

**Definition:** Leader-based replication protocols with primary-backup structure: ZAB (ZooKeeper Atomic Broadcast) and viewstamped replication.

**Cost:** One round trip to a majority per update.

### 79. Chain replication (and CRAQ)

**Definition:** Replicating data along a chain of servers: writes go to the head and propagate down, reads go to the tail. This gives strong consistency with high throughput.

**Cost:** Write latency grows with chain length. Read throughput is high with CRAQ.

### 80. Linearizable reads in consensus systems (ReadIndex, lease reads)

**Definition:** Ways to serve reads that reflect every committed write, without writing each read through the log.

**Cost:** ReadIndex: one heartbeat round. Lease reads: none (with clock assumptions).

### 81. Cluster membership changes (joint consensus, single-server changes)

**Definition:** Safely adding or removing members of a consensus group without a moment where two separate majorities could both act.

**Cost:** Extra configuration entries.

### 82. Practical Byzantine fault tolerance (PBFT)

**Definition:** Consensus that tolerates nodes that behave arbitrarily or maliciously (not just crashing), using 3f + 1 replicas to tolerate f faulty ones.

**Cost:** O(n²) messages per request. 3f + 1 replicas.

## B5. Clocks and distributed transactions

### 83. Hybrid logical clocks (HLC)

**Definition:** Timestamps that combine physical time with a logical counter, so they stay close to wall-clock time while still respecting causality.

**Cost:** 64 bits per timestamp. O(1) updates.

### 84. TrueTime and commit wait (Spanner)

**Definition:** Using clocks with explicit uncertainty bounds to give externally consistent (linearizable) transactions across a global database.

**Cost:** A commit wait of about 2ε per write transaction.

### 85. Percolator (snapshot isolation over a key-value store)

**Definition:** A protocol for distributed transactions with snapshot isolation on top of a key-value store with single-row atomicity, using a timestamp oracle and locks stored in the data itself.

**Cost:** Several round trips per transaction. The timestamp oracle can be a bottleneck (batching helps).

### 86. Calvin (deterministic transaction ordering)

**Definition:** Distributed transactions that are first ordered globally by a sequencing layer, then executed deterministically by every replica in that order, avoiding two-phase commit.

**Cost:** Epoch batching adds latency. High throughput under contention.

## B6. CRDTs and causal consistency

### 87. G-Counter and PN-Counter

**Definition:** Conflict-free counters that can be incremented (and decremented) on any replica independently, and always converge when replicas sync.

**Cost:** O(number of replicas) per counter.

### 88. LWW-Register and MV-Register

**Definition:** CRDT registers that hold a single value: last-writer-wins by timestamp, or keeping all concurrent values (multi-value) for later resolution.

**Cost:** LWW: O(1). MV: grows with concurrent writes.

### 89. OR-Set (observed-remove set)

**Definition:** A CRDT set where adds and removes can happen concurrently on any replica, and an add concurrent with a remove wins.

**Cost:** Metadata grows with tags. Optimized versions bound it.

### 90. Sequence CRDTs (RGA, YATA)

**Definition:** CRDTs for ordered lists and text, allowing concurrent inserts and deletes at any position, with every replica converging to the same order.

**Cost:** Metadata per element. Efficient implementations compress runs of characters.

### 91. Delta-state CRDTs

**Definition:** CRDTs that sync only the recent changes (deltas) instead of the full state, which combines state-based robustness with small messages.

**Cost:** Messages proportional to the changes.

### 92. Causal broadcast and causal consistency

**Definition:** Delivering messages so that every message is delivered only after everything that causally preceded it, at every replica.

**Cost:** Vector-clock metadata per message. Buffering.

## B7. Replication repair, rate limiting and system utilities

### 93. Dynamo-style anti-entropy (hinted handoff, read repair, sloppy quorums, Merkle sync)

**Definition:** Techniques that keep eventually consistent replicas available during failures and repair their divergence afterward.

**Cost:** Background repair traffic.

### 94. GCRA and sliding-window rate limiting

**Definition:** Precise rate limiting algorithms: the generic cell rate algorithm (equivalent to a leaky bucket, with one stored timestamp) and sliding-window counters.

**Cost:** GCRA: one timestamp per key. Sliding counter: two counters per key.

### 95. Distributed rate limiting (global quotas with local leases)

**Definition:** Enforcing a global rate or quota across many servers without a central check on every request.

**Cost:** One quota call per lease period per server.

### 96. Deadline propagation

**Definition:** Passing an absolute deadline along with a request through every service it calls, so all work stops when the original caller no longer needs the answer.

**Cost:** Negligible.

### 97. Bulkheads (resource isolation)

**Definition:** Partitioning resources (thread pools, connection pools, queues, instances) per dependency, tenant or priority, so a failure or overload in one part can't consume everything.

**Cost:** Some idle capacity in reserved pools.

### 98. Distributed unique ID generation (Snowflake, ULID, UUIDv7)

**Definition:** Generating unique, roughly time-ordered identifiers across many machines without coordination.

**Cost:** Negligible.

### 99. Sharded counters

**Definition:** Splitting a heavily updated counter into many sub-counters, so concurrent increments don't contend on one record.

**Cost:** Reads cost N lookups (or a cached total).

### 100. Clock synchronization (NTP, PTP)

**Definition:** Keeping machines' clocks close to true time and to each other: NTP over networks, PTP for much higher precision.

**Cost:** Negligible network overhead.

---

Part 3 (#101–150) covers classical machine learning: linear and generalized linear models (OLS, ridge/lasso/elastic net, logistic regression, GLMs, GAMs), decision trees, random forests, extra trees, gradient boosting (Friedman's method, histogram-based LightGBM, XGBoost, CatBoost), monotonic and interaction constraints, feature importance, SVMs, kernel methods and random features, k-NN, naive Bayes, DBSCAN, HDBSCAN, Gaussian mixtures, mean shift, k-medoids, the EM algorithm, HMM training, LDA topic models, Gaussian processes, ALS matrix factorization, factorization machines, isolation forest, one-class SVM, robust covariance, seasonal anomaly tests, ARIMA, exponential smoothing, decomposable forecasting, intermittent demand, hierarchical reconciliation, time-series cross-validation, model selection, encoding, imputation, feature selection, SMOTE, stacking, bagging, AdaBoost, partial dependence, online learning (FTRL), and concept drift detection.
