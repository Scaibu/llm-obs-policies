# Performance and Durability: Measure, Find the Bottleneck, Fix It (Language-Agnostic)

Confidence tags: **** hard evidence, **** strong inference, **[Guessing]** filling gaps.
Companion documents: *Key Normalization*, *Writing Conditions*, *Loops and Complex Logic*, *Data Models and Types*.

**The uncomfortable truth:**  Developers' intuition about where time goes is wrong often enough that unmeasured optimization is guesswork. Worse, speed bought by removing a safety (a timeout, a sync-to-disk, a constraint, a retry limit) is not a win, it is debt that comes due during the first incident. The goal is not "fast". The goal is "fast enough, measurably, and still correct and recoverable when things fail".

**Scope note:** "Durability" here means (a) **data durability**: committed data survives crashes and failures; (b) **performance durability**: speed and reliability stay acceptable as data grows, load rises, time passes, and dependencies fail.

---

# Part 0: The ten highest-leverage moves

 If you read nothing else, these account for most real gains, in roughly this order:

1. **Define the target** (an SLO: metric, percentile, load, data size) so you know when to stop.
2. **Measure before changing anything**, on production-shaped data and load.
3. **Find the single biggest contributor** (profile, trace, query plan), not the code you suspect.
4. **Remove work**: redundant calls, unneeded fields, dead features, repeated computation.
5. **Fix I/O shape**: N+1 queries, round trips, missing indexes, over-fetching.
6. **Fix algorithmic complexity**: nested searches, repeated sorting, quadratic behavior.
7. **Cache, batch, or precompute** what is measured hot, with defined invalidation.
8. **Bound everything**: concurrency, queues, pools, caches, timeouts, retries.
9. **Protect durability while optimizing**: never trade it away silently.
10. **Guard the win** with a regression test or budget, and verify with soak and failure tests.

---

# Part 1: First principles

## 1.1 What performance is

 Performance is a relationship between a **workload**, a **system**, and a **goal**. It has no meaning without all three. Core quantities:

| Quantity | Meaning | Why it matters |
|---|---|---|
| **Latency** | Time for one operation (distribution, not a number) | What users feel |
| **Throughput** | Operations completed per unit time | What capacity you have |
| **Utilization** | Fraction of a resource busy | How close to the edge you are |
| **Saturation** | Work waiting because a resource is full (queue depth) | Where latency explodes |
| **Errors** | Failed or degraded operations | Fast and wrong is not fast |
| **Cost** | Money, energy, engineering effort per unit of work | The real constraint |

## 1.2 Laws and models that predict behavior

1. **Amdahl's Law.**  If a fraction `p` of total time is improved by a factor `s`, overall speedup is `1 / ((1 - p) + p/s)`. Speeding up a part that is 5% of the time can never give more than about 5% total. **Compute the maximum possible gain before doing the work.**
2. **Little's Law.**  `L = λ × W`: average items in the system equals arrival rate times average time in the system. Use it to size concurrency: in-flight requests = throughput × latency.
3. **Queueing and utilization.**  In a simple single-server queue, mean wait is `ρ/(1-ρ) × service time`, where `ρ` is utilization. At 50% busy, wait equals one service time; 80%: 4×; 90%: 9×; 95%: 19×.  Real systems vary but follow the shape: latency rises slowly, then explodes near saturation. Running hot means paying in tail latency.
4. **Tail amplification.**  If one call is slow with probability `p`, a request that waits on `n` parallel calls is slow with probability `1 - (1-p)^n`. With 100 calls and a 1% slow rate, about 63% of requests hit at least one slow call. Fan-out turns rare slowness into common slowness.
5. **Scalability limits.**  Adding workers stops helping (and can hurt) because of serialized sections (contention) and coordination costs (coherence): the Universal Scalability Law shape. More threads or nodes is not a plan until you know what serializes.
6. **Theory of constraints.**  Throughput is set by the single tightest bottleneck. Improving anything else changes nothing until that one moves, and then a new bottleneck takes its place.

## 1.3 The cost hierarchy: where gains come from

 In descending order of typical leverage:

1. **Eliminate the work** (do not do it at all).
2. **Do it less often** (cache, batch, precompute, lazy evaluation).
3. **Do it in a better place** (closer to the data, off the critical path, in parallel).
4. **Do it with a better algorithm or data structure.**
5. **Do it faster** (micro-optimization, language tricks, compiler flags).

Gains at levels 1 to 4 are often 10× to 1000×. Level 5 is usually 1.1× to 2×, and the one most developers reach for first.

## 1.4 Approximate cost of operations (orders of magnitude)

 These shift with hardware, but the ratios are what matter:

| Operation | Rough cost |
|---|---|
| CPU cache hit | ~1 ns |
| Main memory access | ~100 ns |
| Mutex lock/unlock (uncontended) | ~20 to 100 ns |
| SSD random read | ~10 to 100 µs |
| Network round trip, same data center | ~0.2 to 1 ms |
| Spinning-disk seek | ~5 to 10 ms |
| Round trip across a continent | ~50 to 150 ms |

 Consequence: one avoidable network or disk round trip costs as much as millions of CPU instructions. Reducing round trips beats tuning loops almost every time.

## 1.5 The fifteen root causes of slowness

1. **Wrong complexity:** quadratic or worse behavior hidden in nested searches, repeated sorts, string building.
2. **I/O amplification:** N+1 queries, chatty protocols, many small calls instead of one batch.
3. **Missing or unusable index, full scans.**
4. **Repeated work:** recomputation, re-parsing, re-fetching, no caching where warranted.
5. **Serialization and contention:** locks, single-threaded bottlenecks, hot rows and hot keys.
6. **Memory behavior:** allocation churn, GC pauses, cache-unfriendly layout, leaks, swapping.
7. **Data volume:** fetching or transferring far more than needed; no pagination or projection.
8. **Sequential waiting:** independent calls made one after another.
9. **Saturation and queueing:** running near capacity; unbounded concurrency creating overload.
10. **Setup costs:** new connections, TLS handshakes, cold caches, cold starts, JIT warm-up.
11. **Configuration:** pool sizes, timeouts, thread counts, buffer sizes, GC settings, defaults left unchanged.
12. **Serialization and logging overhead** in hot paths.
13. **Retries and amplification:** failures multiplying load.
14. **Platform limits:** CPU throttling, IOPS or bandwidth quotas, noisy neighbors, memory limits.
15. **Drift over time:** data growth, index bloat, fragmentation, accumulating state.

---

# Part 2: Define the goal first

**P1. Express the goal as an SLO.**  Metric, percentile, threshold, load, and data size: "p99 latency under 300 ms at 500 requests/second with 50 million rows." Without it you cannot know when to stop, and you will over-optimize one part and miss the real problem.

**P2. Choose the right metric families.**  For services: **RED** (Rate, Errors, Duration). For every resource (CPU, memory, disk, network, pools): **USE** (Utilization, Saturation, Errors). The four "golden signals" are latency, traffic, errors, saturation.

**P3. Use percentiles and histograms, not averages.**  Averages hide the tail, and the tail is what users and downstream timeouts experience. Track p50, p95, p99, and p99.9 for critical paths.  Never average percentiles across instances; merge histograms instead.

**P4. Define a representative workload.**  Data size, value distribution and skew (a few hot keys is normal), operation mix, request sizes, concurrency, arrival pattern (steady, bursty, daily peak). A test on 1,000 clean rows predicts nothing about 100 million skewed ones.

**P5. Set cost and resource budgets.**  Maximum CPU-ms per request, memory per instance, cost per million operations. An optimization that doubles memory may be a loss.

**P6. Define the guardrails that must not degrade.**  Correctness, durability guarantees, consistency level, security, and error rate. Write them down as acceptance criteria for every optimization.

**P7. Prioritize by impact.**  Rank by `frequency × cost per occurrence × user visibility`. Usually 1 to 3 operations dominate. Ignore everything else until they are fixed.

---

# Part 3: Measurement rules

**P8. Never optimize what you have not measured.**  Profile or trace first. A change not validated by a measurement is a rumor.

**P9. Record a baseline and the environment.**  Hardware, OS, runtime and library versions, configuration, data size, load shape, and date. A number without its environment cannot be compared later.

**P10. Change one thing at a time.**  Otherwise you cannot attribute the effect, and a harmful change can hide behind a helpful one.

**P11. Repeat and use statistics.**  Run multiple times; report median and spread (p95, standard deviation or confidence interval), not a single run. Compare with enough runs to separate real change from noise. Interleave A/B runs when possible so drift (thermal state, background load) affects both equally.

**P12. Measure both cold and warm.**  Cold start (empty caches, uninitialized pools, JIT/warm-up, first request after deploy) and steady state are both real. Report them separately, and do not let warm-up pollute steady-state numbers.

**P13. Use production-shaped data.**  Realistic size, distribution, and skew. Data that fits in CPU cache or memory in a test but not in production gives opposite conclusions. For databases, query plans change with data size and statistics.

**P14. Generate open-loop load to measure latency.**  A closed-loop generator (each client waits for the previous response before sending) slows down when the system slows, hiding the queueing delay real users would see (**coordinated omission**). Use a fixed arrival rate and measure latency from the *intended* send time.

**P15. Avoid benchmark pitfalls.** 
- The compiler or runtime eliminated "dead" code you thought you measured; consume the result.
- Constants folded or inputs identical on every iteration; vary inputs.
- Microbenchmarks that ignore cache effects, allocation, GC, and concurrency.
- Debug builds, assertions, or profilers left on.
- Test machine unlike production (CPU model, core count, disk type, network).
- Shared CI runners with noisy neighbors; pin or use dedicated hardware for trend benchmarks.
- Measuring the benchmark harness, not the code.
- Averaging away tail behavior.

**P16. Use the right type of test.** 
- **Microbenchmark:** a validated hot function, isolated.
- **Component benchmark:** one service or module with realistic inputs.
- **Load test:** expected peak, steady, to verify the SLO.
- **Stress test:** increase beyond capacity to find the breaking point and failure mode.
- **Soak test:** hours to days at normal load to reveal leaks and slow degradation.
- **Spike test:** sudden bursts, to test autoscaling and shedding.
- **Scalability test:** vary data size or instance count and plot the curve.
- **Failover and fault test:** performance and correctness during node loss, slow dependencies.

**P17. Profile the right dimension.** 
- **CPU profile** (sampling, flame graph): where compute time goes.
- **Wall-clock / off-CPU profile:** where threads *wait* (locks, I/O, sleeping); a service can be slow with low CPU.
- **Allocation and heap profile:** churn, leaks, large objects.
- **Lock/contention profile:** who waits on whom.
- **I/O profile:** syscalls, disk latency and queue depth, network.
Use sampling profilers in production-like load (low overhead); remember profilers perturb behavior.

**P18. Trace across services.**  Distributed tracing shows the critical path of a request across calls. Optimize spans on the critical path only; speeding up a parallel branch that is not the slowest changes nothing.

**P19. Read query plans on real data.**  Use the engine's plan tool with actual execution statistics (`EXPLAIN ANALYZE`, `PROFILE`, or equivalent). Compare estimated and actual row counts: a large mismatch means stale statistics or a poor plan.

**P20. Monitor each resource with the USE method.**  CPU (user, system, iowait, steal, run-queue length, throttling), memory (resident size, page faults, swap, GC time), disk (IOPS, throughput, queue depth, latency), network (bandwidth, retransmits, connection counts), and software resources (thread pools, connection pools, queues, file descriptors).

**P21. Count operations, not just time.**  Queries per request, bytes transferred, allocations per operation, cache misses, lock acquisitions. Counts are deterministic and stable across machines, so they make excellent regression tests where timings are noisy.

**P22. Guard against regression continuously.** 
- Deterministic budgets in tests (maximum queries per request, maximum allocations).
- Trend benchmarks on stable hardware with alert thresholds.
- Production dashboards and alerts on SLO burn.
- **Continuous profiling** in production to catch regressions between releases.

---

# Part 4: Finding the bottleneck

**P23. Follow a fixed method.** 
1. **Reproduce** the slowness with a measurable workload.
2. **Measure end to end** to confirm and quantify the problem.
3. **Decompose time**: CPU working, waiting on I/O, waiting on locks, waiting in a queue, waiting on a downstream service.
4. **Locate** the largest component (profile, trace, plan, resource metrics).
5. **Hypothesize** a specific cause and a predicted effect.
6. **Change one thing**, verify correctness, **re-measure**.
7. Repeat until the SLO is met.

**P24. Classify the bottleneck.**  Almost every case is one of:

| Class | Signature | Typical fix |
|---|---|---|
| **CPU-bound** | High CPU, profile shows hot compute | Algorithm, remove work, vectorize, scale out |
| **Memory-bound** | High GC or allocation, cache misses, swap | Reduce allocations, better layout, bound structures |
| **I/O-bound** | Low CPU, high iowait or waiting on network or DB | Fewer round trips, batching, indexes, caching |
| **Lock/contention-bound** | Low CPU, threads blocked, throughput flat as workers grow | Reduce shared state, narrower locks, partition |
| **Downstream-bound** | Time attributed to another service | Fix there, or cache, batch, parallelize, add timeouts |
| **Queue/saturation-bound** | High utilization, rising queue and tail | Capacity, shed load, reduce work per request |

**P25. Compute the maximum gain before starting (Amdahl).**  If the candidate is 4% of total time, the ceiling is 4%. Skip it. Spend effort where the ceiling is large.

**P26. Expect the bottleneck to move.**  After removing one, the next appears. Re-profile after every substantial change instead of continuing down the old list.

**P27. Stop when the SLO is met.**  Further optimization adds complexity and risk for gains nobody needs. Record the state and move on.

---

# Part 5: Rules for writing performant code

## 5.1 Algorithms and data structures

**P28. Know the complexity of what you call.**  Including hidden costs: list `contains`, string concatenation in a loop, lazy-loaded ORM relations, regex backtracking, copying large values, sorting inside a comparator.

**P29. Choose structures by access pattern.**  Hash map/set for exact lookup, sorted structure or tree for range queries and ordered iteration, array for scans, heap for top-k and priority, queue for FIFO, bitmap or Bloom filter for compact membership checks (accepting false positives where the spec permits).

**P30. Remove nested searches.**  A search inside a loop is `O(n × m)`. Build a map or set once, then use constant-time lookups; or sort and use two pointers.

**P31. Do not sort or scan more than you need.**  Top-k with a heap or partial selection, min/max in one pass, "does any match exist" with early exit, avoid sorting data already ordered by an index.

**P32. Hoist, precompute, and memoize.**  Compute loop-invariant values once; precompute lookup tables, compiled patterns, parsed configuration. Memoize pure, expensive computations with a bounded cache and a canonical key.

**P33. Do less work.**  Exit early, evaluate lazily, fetch only needed fields (projection), limit result size, skip unchanged items (change detection), and short-circuit with cheap checks before expensive ones.

**P34. Batch to amortize fixed costs.**  Fixed per-operation costs (syscall, network round trip, lock, transaction, parse) dominate small operations. Group many into one. Choose a batch size by measurement; too large increases latency, memory, and blast radius of failure.

**P35. Stream instead of materializing.**  Process data as it flows when the whole set is not needed. This bounds memory and starts producing output sooner.

**P36. Favor locality and compact layout in hot data paths.**  Contiguous arrays beat pointer-linked structures for scans; keep data accessed together stored together; column-oriented layout for scans over one field of many records; smaller numeric types where valid; avoid per-element boxing. Do this only for hot paths identified by profiling.

**P37. Use approximation only where the spec permits.**  Sampling, sketches (e.g., for cardinality or percentiles), and probabilistic filters give large savings, but they change results. State the accepted error in the spec first.

## 5.2 I/O and network

**P38. Count round trips and minimize them.**  Each round trip has a latency floor no hardware upgrade removes. Design APIs so a screen or operation needs one call, not twenty.

**P39. Eliminate N+1 and chatty patterns.**  Fetch related data in bulk (a join, an `IN` list, a batch endpoint, a data loader), not one call per item. This is the single most common large win.

**P40. Parallelize independent calls; pipeline dependent ones.**  If calls do not depend on each other, issue them concurrently (with a bound). Total latency becomes the slowest, not the sum. Do not parallelize dependent calls.

**P41. Reuse connections.**  Connection pooling, keep-alive, TLS session resumption, HTTP/2 or multiplexed protocols, DNS caching. Connection setup can cost more than the request.

**P42. Move less data.**  Projection (only needed fields), pagination, filtering at the source, delta updates, compact formats on hot paths. Compress when network or storage cost exceeds CPU cost; do not compress tiny payloads or already-compressed data.

**P43. Put compute near the data and near the user.**  Filter and aggregate in the database or at the storage layer instead of pulling raw data; co-locate chatty services in the same zone; use edge or CDN caching for cacheable content. Avoid cross-region calls on the critical path.

**P44. Put a timeout and a deadline on every external call.**  No default "wait forever". A missing timeout converts a downstream slowdown into resource exhaustion in your service. (This is also durability: see Part 7.)

**P45. File I/O: sequential, buffered, batched.**  Large sequential reads and writes beat many small random ones; avoid reading a file repeatedly; know the cost of forcing data to stable storage and batch it (see P109).

**P46. Keep logging and instrumentation off the hot path.**  Use levels and sampling, avoid building expensive log strings unless the level is enabled, use bounded asynchronous logging, and never log inside tight loops. Metrics should be cheap counters and histograms.

## 5.3 Databases

**P47. Index for real access patterns.**  Put equality-filtered columns first, then range or sort columns; use covering indexes for hot read queries; match index order to `ORDER BY`. An index no query uses is pure write cost.

**P48. Verify with the plan on production-sized data, and keep statistics fresh.**  Confirm the index is used and row estimates are close to actual. Stale statistics cause bad plans after data growth.

**P49. Keep predicates index-friendly.**  No function or arithmetic on the indexed column (`WHERE lower(col) = ?`), no implicit type conversion, no leading wildcard on text search where an index is expected. Move the transformation to the parameter side or store the derived value in its own indexed column.

**P50. Select only the columns and rows you need; never allow an unbounded result.**  Avoid `SELECT *` on wide tables; always bound with a limit or pagination; do aggregation in the database.

**P51. Paginate with keyset (cursor), not deep offsets.**  Offset pagination reads and discards all skipped rows (cost grows with depth) and is unstable under concurrent writes. Use a total order with a unique tiebreaker and continue from the last seen key.

**P52. Batch writes and reuse prepared statements.**  Multi-row inserts, bulk-load tools for large imports, prepared or parameterized statements for plan reuse. Balance batch size against transaction duration and lock footprint.

**P53. Keep transactions short.**  Do not hold a transaction or lock open across network calls, user waits, or slow computation. Long transactions block cleanup (vacuum/compaction), hold locks, and amplify contention.

**P54. Avoid hot rows and contention.**  A single counter or row updated by every request serializes the system. Shard counters, append events and aggregate asynchronously, or partition by key.

**P55. Every index costs writes and storage.**  Each insert or update maintains all indexes. Drop unused or redundant indexes; measure write latency when adding one.

**P56. Size the connection pool for the database, not the application.**  More connections than the database can run efficiently increases contention and context switching, and lowers throughput. Use a bounded pool, queue excess requests briefly, and fail fast beyond that.

**P57. Offload reads only with staleness accepted.**  Read replicas, caches, and read models lag the source. Define which reads tolerate how much staleness, and route read-your-writes cases to the primary.

**P58. Partition, archive, and maintain.**  Partition large tables by time or key so queries touch less data and old data can be dropped cheaply; archive cold data; keep vacuum/compaction/reindex and statistics maintenance scheduled and throttled.

**P59. Graph and document store specifics.**  Graph: anchor every traversal on an indexed starting node, bound depth and fan-out, avoid expanding supernodes and cartesian products, and use the engine's profiling to see rows and database hits per step. Document: embed only bounded, co-read data; reference the rest; avoid ever-growing documents and hot keys.

## 5.4 Caching

**P60. Cache only what is measured hot, expensive, and repeatable.**  Caching a slow query hides the problem and adds invalidation risk. Fix the query first when you can, then cache the remaining hot reads.

**P61. Specify every cache.**  Key, value, size bound, TTL, invalidation trigger, acceptable staleness, and eviction policy. A cache without a bound is a memory leak with a delay.

**P62. Prevent stampedes.**  When a hot entry expires, many requests recompute it at once. Use single-flight (one computation, others wait), TTL jitter, and stale-while-revalidate (serve stale, refresh in the background).

**P63. Make keys canonical and correctly scoped.**  Normalize inputs (see the key-normalization document) and include everything that changes the result: tenant, user or permission scope, locale, schema or code version. Missing scope leaks data between users.

**P64. The system must stay correct with a cold or unavailable cache.**  The cache is an optimization, never the source of truth. Test with the cache empty and down, including the load surge from a cold start.

**P65. Handle errors and absence deliberately.**  Cache "not found" briefly (negative caching) to stop repeated misses, but never cache errors for long, and never cache partial or failed results as success.

**P66. Measure and prune.**  Track hit ratio, evictions, memory, and latency with and without the cache. Remove caches that do not pay their complexity.

## 5.5 Concurrency and parallelism

**P67. Decide whether parallelism helps.**  CPU-bound work scales with cores; I/O-bound work scales with concurrency (asynchronous or threaded) until the resource saturates; serialized sections cap everything (Amdahl). Parallelizing a lock-bound or database-bound path often changes nothing.

**P68. Size pools from measurement.**  CPU-bound pools near the core count; I/O-bound pools by Little's Law (target throughput × latency) and the capacity of the downstream resource. Revisit when latency changes.

**P69. Bound everything.**  Thread and connection pools, task counts, in-flight requests, queue lengths, retry counts. Unbounded concurrency turns a slowdown into a crash.

**P70. Reduce shared mutable state.**  Partition data so workers own disjoint pieces; use per-worker accumulators merged at the end; shard counters. Shared state forces coordination, which is the scaling limit.

**P71. Narrow lock scope; never do I/O under a lock.**  Hold locks for the shortest critical section, on the smallest data, in a consistent order (avoiding deadlock). Prefer immutable data and message passing where it fits.

**P72. Do not block an event loop or asynchronous worker.**  A blocking call (synchronous file or network I/O, heavy computation, a lock wait) in a single-threaded or small async pool stalls everything. Move blocking or CPU-heavy work to a separate bounded pool.

**P73. Apply backpressure end to end.**  When a consumer is slow, producers must slow down or reject, via bounded queues, flow control, and explicit "busy" responses. Silent buffering hides overload until memory runs out.

**P74. Profile contention before reaching for lock-free tricks.**  Watch for false sharing (independent data on one cache line), lock convoys, priority inversion, and thundering herds. Lock-free structures are complex and rarely the first or best fix.

## 5.6 Memory

**P75. Preallocate and reuse in measured hot paths.**  Set collection capacity up front, reuse buffers, use object pools only where profiling shows allocation cost, and be careful: reused mutable objects cause aliasing bugs (see the loops document).

**P76. Reduce allocation rate before tuning the garbage collector.**  Fewer short-lived objects (avoid boxing, avoid temporary strings in loops, use builders) usually beats GC parameter changes. Tune GC afterward, with measurements of pause time and throughput.

**P77. Bound every in-memory structure.**  Caches, queues, maps keyed by request or user, buffers, and result sets all need a maximum.

**P78. Hunt leaks by design.**  Typical sources: unbounded caches or maps, event listeners never removed, tasks never completed, unclosed files, sockets, and statements, thread-locals, accumulating metrics labels. Soak tests plus heap growth trends reveal them.

**P79. Reduce data size.**  Smaller numeric types, interned or deduplicated strings, compact encodings, compression for cold data, dropping unneeded fields. Less memory means fewer cache misses and less GC and I/O.

**P80. Avoid swap and out-of-memory kills.**  Set explicit memory limits, leave headroom for the runtime, alert before the limit, and know what your platform does when the limit is exceeded (often an abrupt kill, which is a durability event).

## 5.7 Computation hot paths

**P81. Optimize only profiled hot spots.**  If a function is not on the profile's top lines, leave it readable.

**P82. Prefer well-tested optimized libraries and built-ins over hand-rolled code.**  Standard sorting, hashing, compression, parsing, and numeric libraries are heavily optimized and correct on edge cases. Hand-written replacements usually lose on both.

**P83. Compile once, reuse.**  Regular expressions, templates, schemas, prepared statements, and routes should be built at startup, not per request. Avoid reflection, dynamic dispatch, and exception-based control flow inside hot loops.

**P84. Fast path for the common case, slow path for the rest.**  Handle the 95% case cheaply and keep a general fallback. Test both, and verify they produce identical results (differential tests).

**P85. Use optimized builds and correct runtime settings.**  Release builds, right compiler or interpreter flags, JIT warm-up handling, ahead-of-time compilation or profile-guided optimization where supported. Never benchmark or deploy a debug build.

**P86. Avoid repeated parse and serialize cycles.**  Parse once into a typed form and pass that; choose an efficient serialization format on hot internal paths; avoid converting through intermediate text formats.

## 5.8 Architecture

**P87. Take non-critical work off the request path.**  Emails, analytics, search indexing, and notifications go through a queue and are processed asynchronously. For durability, hand off with a transactional outbox or equivalent so the work is not lost if the process dies between steps.

**P88. Precompute heavy reads.**  Materialized views, read models, and pre-aggregated tables turn expensive queries into lookups. Define the refresh mechanism, staleness, and rebuild path (see the data-model document).

**P89. Partition by a key that spreads load.**  Choose the partition key to avoid hot partitions (skew), keep related data together for common queries, and allow growth without wholesale resharding.

**P90. Reduce fan-out and critical-path depth.**  Fewer sequential hops, fewer services per request, and aggregation done once. Every hop adds latency and failure probability.

**P91. Control tail latency.**  Deadlines on every hop, request coalescing for identical concurrent requests, and hedged requests (a second attempt after a high-percentile delay) for idempotent reads only, with a budget so hedging does not become overload.

**P92. Admission control and load shedding.**  Rate limit, reject early and cheaply when over capacity, and prioritize critical traffic. A fast "no" is better than a slow collapse.

**P93. Isolate failure domains.**  Bulkheads (separate pools and queues per dependency and priority class) and circuit breakers prevent one slow dependency from consuming all resources.

**P94. Fix inefficiency before scaling out; scale up when cheap.**  Adding nodes to a system with N+1 queries multiplies the waste. Compare engineering cost with hardware cost honestly; sometimes a bigger machine is the cheapest correct fix. Scale stateless layers horizontally; state needs a plan.

**P95. Pick the store and tool for the access pattern.**  A relational store for transactional integrity, a key-value or cache for simple hot lookups, a search index for text and faceting, a graph store for deep relationship traversal, a log or queue for streams, columnar storage for analytics. A mismatch costs more than any tuning.

---

# Part 6: Improving existing code (highest-leverage procedure)

**P96. Start from goal, baseline, and profile.**  Pick the top one to three contributors from real measurements.

**P97. Rank candidate fixes by `(gain × confidence) / (effort × risk)`, following the leverage ladder:** 
1. Remove unnecessary work (dead code, redundant calls, unused fields, features nobody uses).
2. Fix algorithmic complexity.
3. Fix I/O shape (N+1, round trips, missing index, over-fetching).
4. Cache, batch, or precompute.
5. Parallelize or make asynchronous independent work.
6. Fix contention, queueing, and pool configuration.
7. Reduce memory and allocation pressure.
8. Improve data layout and structures.
9. Micro-optimize.
10. Add hardware or scale out (sometimes cheaper than steps 3 to 9; weigh it explicitly).

**P98. Lock current behavior with tests before changing anything.**  Characterization tests or golden outputs from the existing code, covering edge cases. Optimizing untested code is how fast bugs ship.

**P99. Keep the simple version as an oracle.**  Run old and new implementations on the same randomized and real inputs and assert identical results (or defined tolerance) before removing the old one.

**P100. One change, verify, measure, keep or revert.**  If the measured gain does not appear or is within noise, revert. Unproven optimizations are complexity with no return.

**P101. Check what the optimization changed semantically.**  Result ordering, floating-point rounding, staleness of cached data, error handling and retry behavior, determinism, transaction boundaries, memory behavior at the maximum size. Many "free" speedups quietly change one of these.

**P102. Prefer deleting work over adding machinery.**  The fastest code is code that does not run. A removed call has no cache invalidation, no race, no tuning knob.

**P103. Isolate and document optimized code.**  Put it behind a clear interface with a comment that states the measured reason ("batching reduced p99 from 900 ms to 120 ms at 500 rps") and the assumptions that would invalidate it.

**P104. Add a guard for every win.**  A benchmark, an operation-count budget (P21), or an alert so the gain cannot silently disappear in the next refactor.

**P105. Roll out safely.**  Feature flag or canary, compare latency, errors, and resource use against the baseline, optionally run old and new in shadow mode and diff outputs, and keep a fast rollback.

**P106. Record before and after.**  A short note: goal, baseline, change, measured result, tradeoffs, and assumptions. It prevents re-litigating and helps the next person.

---

# Part 7: Durability: speed without losing data or stability

## 7.1 Data durability

**P107. Define the durability guarantee per data class.**  What does "committed" mean: in process memory, on local disk after a forced sync, replicated to N nodes, replicated across zones or regions? State the **RPO** (maximum acceptable data loss) and **RTO** (maximum acceptable recovery time) for each data class. Payments and user-generated content differ from caches and metrics.

**P108. Never trade durability for speed silently.**  Disabling forced syncs, using asynchronous replication, acknowledging writes before they are persisted, or relying on a memory-only store are legitimate choices only when explicit, documented, bounded (maximum loss window), and monitored. "It was faster" is not a recovery plan.

**P109. Get throughput through batching, not by skipping safety.**  Group commit (many transactions share one sync), larger sequential writes, write-ahead logging, and pipelining raise throughput while preserving the guarantee.

**P110. Make multi-step writes atomic or recoverable.**  Use transactions within a store; across stores or services, use the transactional outbox, idempotency keys, and compensating actions (sagas) so a crash between steps cannot leave permanent inconsistency or duplicates.

**P111. Memory-only stores are not the source of truth.**  Caches, in-memory queues, and non-persistent brokers lose data on restart. If losing it matters, persist it first.

**P112. Replicate across failure domains and know the tradeoff.**  Synchronous replication protects against loss but adds latency and reduces availability under partition; asynchronous replication is faster but can lose the last writes on failover. Decide per data class. Monitor replication lag as a durability metric.

**P113. Back up, enable point-in-time recovery, and test restores.**  A backup that has never been restored is an assumption. Practice full restore regularly, measure the time (that is your real RTO), verify data integrity, and store backups in a separate failure domain with protection against accidental or malicious deletion.

**P114. Detect corruption.**  Checksums on data and on the wire, periodic scrubbing, validation on read for critical data, and reconciliation jobs comparing derived data to its source. Silent corruption is found by looking for it.

**P115. Test crash behavior.**  Kill the process abruptly, cut power (or simulate it), fill the disk, and inject partial and torn writes at random points, then verify recovery and data integrity. Graceful-shutdown tests do not prove crash safety.

**P116. Do not trust storage layers blindly.**  Volatile write caches, filesystem and mount options, virtualized or network volumes, and cloud disk types differ in what "synced" really guarantees. Verify the actual behavior of your stack and read the vendor's durability semantics.

**P117. Test failover end to end.**  Promotion of a replica, fencing the old primary to prevent split-brain, client reconnect and retry behavior, and data consistency after the event. Measure the time and the lost-write window.

**P118. Protect data during change.**  Migrations follow expand, migrate, contract (see the data-model document); never destroy old data before the new is verified; keep retention and deletion obligations (including from backups and derived stores) in the design.

## 7.2 Performance durability

**P119. Test at projected scale, not current scale.**  Run the critical queries and jobs at ten times today's data and traffic. Cost curves bend (an index that fit in memory now does not; a join spills to disk), and the cliff is invisible at small size.

**P120. Run soak tests.**  Hours to days at realistic load while tracking memory, heap, file descriptors, threads, connections, queue depths, disk usage, and latency percentiles over time. Any steady upward trend is a defect waiting for the right uptime.

**P121. Plan capacity with headroom.**  Use the queueing shape (Part 1.2): keep peak utilization well below saturation so latency stays predictable and there is room for failures (losing one node must not overload the rest).  Many teams target peak utilization in roughly the 50 to 70% range for latency-sensitive services; choose yours from measured latency-versus-load curves.

**P122. Design overload behavior explicitly.**  Under more load than capacity, a system should degrade gracefully (shed or reject excess, serve reduced functionality) not collapse (queues grow, timeouts cascade, everything fails). Use bounded queues and fast rejection, and test beyond capacity to see what actually happens.

**P123. Propagate deadlines.**  Pass the remaining time budget down every call. A downstream call should never outlive the upstream caller's patience; each hop's timeout is shorter than the remaining budget, so abandoned work stops.

**P124. Retry with a budget.**  Bounded attempts, exponential backoff with jitter, retry only idempotent and retryable failures, and retry at one layer. Use a retry budget (a cap on the fraction of traffic that may be retries) so failures do not multiply load.

**P125. Use circuit breakers and fallbacks.**  Stop calling a failing dependency, probe periodically, and degrade (serve stale data, a default, or a reduced feature) instead of failing the whole request.

**P126. Isolate with bulkheads.**  Separate pools, queues, and limits per dependency and per priority class, so a slow dependency or a bulk job cannot starve interactive traffic.

**P127. Handle cold starts and restarts.**  After deploys and scale-up, caches are empty, pools are unwarmed, and runtimes are unoptimized. Pre-warm, ramp traffic gradually (slow-start load balancing), stagger restarts, and protect the database from a cold-cache surge.

**P128. Configure autoscaling with limits and lead time.**  Scale on the right signal (queue depth, request concurrency, latency), with cooldowns and maximum bounds (cost and downstream capacity), and make sure instance start-up time is shorter than the demand ramp. Autoscaling cannot rescue a bottleneck that is not horizontally scalable (the database, a lock).

**P129. Know and respect platform limits.**  Container CPU throttling, memory limits (OOM kill), file-descriptor limits, ephemeral port exhaustion, disk IOPS and throughput quotas, burstable-instance credits, network egress limits. Hitting a quota looks like a mysterious slowdown.

**P130. Throttle maintenance work.**  Backups, compaction, vacuum, reindexing, large migrations, and batch jobs compete with live traffic. Schedule them, rate-limit them, and monitor their impact on latency.

**P131. Gate releases on performance.**  Performance tests in CI/CD, canary analysis comparing latency, errors, and resource use against the current version, and automatic rollback on regression.

**P132. Inject faults.**  Slow and failing dependencies, node loss, full disks, network partitions, packet loss, clock skew, expired certificates. Verify performance and correctness under each, on a schedule, not once.

**P133. Alert on symptoms and SLO burn.**  Alert on user-visible impact (latency and error budget burn) with runbooks, and keep cause-level metrics (CPU, queue, lag) for diagnosis, not paging noise. Track capacity and cost trends.

**P134. Re-measure after any change in the environment.**  Dependency upgrades, runtime or compiler versions, configuration, instance types, data growth, and traffic mix changes can each alter performance. Treat them like code changes.

## 7.3 Durability of the code itself

**P135. Keep optimized code tested and readable.**  Complexity added for speed is permanent maintenance cost. Comment the measured reason, keep oracle tests, and keep the interface simple.

**P136. Retire stale optimizations.**  An optimization tied to old data shapes, old hardware, or an old runtime may now be useless or harmful. When assumptions change, re-measure and remove it.

**P137. Prefer simple designs that sustain performance.**  The most durable performance comes from simple structure: few hops, bounded resources, clear ownership, predictable behavior under load. Cleverness is itself a reliability risk.

---

# Part 8: Anti-patterns

-  Optimizing without measuring, or measuring only an average.
-  Microbenchmarking in isolation and extrapolating to the whole system.
-  Testing on tiny or unrealistic data.
-  Adding caches to hide a bad query instead of fixing it, then having no invalidation plan.
-  Adding threads or instances to a system that is lock-bound, database-bound, or has an N+1 problem.
-  Unbounded queues, pools, caches, retries, or concurrency.
-  Removing timeouts, constraints, or forced syncs for speed.
-  Retrying everything, at every layer, without backoff or jitter.
-  Premature denormalization or sharding before measuring.
-  Logging, serialization, or reflection on the hot path.
-  Copying configuration from blog posts or vendor benchmarks without validating for your workload.
-  Piling up many small 1% micro-optimizations that make the code hard to change and give no measurable user benefit.
-  Changing behavior (ordering, rounding, staleness, errors) while "just optimizing".
-  Not re-measuring after the change.
-  Assuming all cloud instances, disks, and networks perform the same.

---

# Part 9: Back-of-the-envelope formulas

 The formulas are exact definitions; the example numbers are illustrative.

| Question | Formula |
|---|---|
| Concurrency needed | `in-flight = throughput × latency` (Little). 500 req/s × 0.2 s = 100 in flight |
| Instances needed | `peak rps × CPU-seconds per request / (cores × target utilization)` |
| Queue wait multiplier (simple model) | `ρ / (1 - ρ)` × service time: 0.5 → 1×, 0.8 → 4×, 0.9 → 9×, 0.95 → 19× |
| Slow-request probability with fan-out | `1 - (1 - p)^n`: p = 1%, n = 100 → ~63% |
| Maximum speedup | `1 / ((1 - p) + p/s)` (Amdahl) |
| Data size | `rows × bytes per row × (1 + index overhead)`; check against memory and disk |
| Bandwidth | `requests/s × bytes per response`, compared to the link limit |
| Batching benefit | `per-item cost = fixed cost / batch size + variable cost` |
| Time to scan | `data size / sequential throughput` (find out if "full scan" means seconds or hours) |

---

# Part 10: Symptom → likely cause → first check

| Symptom | Likely cause | First check |
|---|---|---|
| Fast in dev, slow in prod | data size, skew, network distance, N+1 | Query counts and plans on production-shaped data |
| Latency fine at p50, bad at p99 | queueing, GC pauses, lock waits, slow dependency, fan-out, cold caches | Percentile histograms, off-CPU profile, trace outliers |
| Throughput flat when adding threads | lock or downstream bottleneck, pool limit | Contention profile, pool wait times |
| Low CPU but slow | waiting on I/O, locks, or downstream | Wall-clock profile, iowait, traces |
| High CPU in a few functions | algorithmic issue or heavy serialization | CPU flame graph |
| Slows down over hours or days | leak, index bloat, data growth, accumulating state | Soak test with heap, handles, and size trends |
| Slow right after deploy or restart | cold caches, pools, JIT, herd on database | Cold-start measurement, warm-up |
| Spikes at regular intervals | batch jobs, maintenance, GC, cron, cache expiry | Correlate with schedules and GC logs |
| Collapses under load rather than degrading | unbounded queues, retry storms, no shedding | Stress test beyond capacity |
| One tenant or key is slow | hot partition, skew, large entity | Per-key latency and size distribution |
| Query got slow after data growth | plan change, stale statistics, missing index | Plan with actual rows, statistics age |
| Writes slow down | too many indexes, contention, sync cost, replication lag | Write latency breakdown, lock waits |
| Memory climbs until restart | leak or unbounded cache | Heap profile diff over time |
| Intermittent timeouts | slow dependency without deadline, pool exhaustion | Pool saturation, dependency latency, timeouts |
| Works then "mysteriously" throttled | platform quota or CPU throttling | Container and cloud quota metrics |

---

# Part 11: Quick playbooks

## 11.1 A slow API endpoint
1. Trace one slow request; list spans on the critical path.
2. Count queries and external calls; remove N+1; batch.
3. Check the plan of the slowest query on production-shaped data; add or fix an index.
4. Parallelize independent calls; cut payload (projection, pagination).
5. Cache what is hot and stable, with an invalidation plan.
6. Add timeouts, bounded pools, and a budget test (queries per request).

## 11.2 A slow batch job
1. Profile where the time goes (read, transform, write, waiting).
2. Replace per-item I/O with chunked bulk operations; stream rather than load all.
3. Add parallelism with bounded workers over independent partitions.
4. Make it idempotent and resumable (checkpoints), so failure costs one chunk.
5. Throttle it so it does not harm live traffic; soak-test for memory.

## 11.3 A slow database query
1. Run the plan with actual statistics; compare estimated and actual rows.
2. Check index use and predicate shape; remove functions on columns.
3. Reduce rows and columns early (filters, projection, limits).
4. Consider keyset pagination, covering index, or precomputed aggregate.
5. Check statistics freshness, bloat, and lock waits; measure write-cost side effects of new indexes.

## 11.4 A slow client or UI
1. Measure user-perceived metrics (time to first meaningful content, interaction latency).
2. Ship less (code splitting, remove unused dependencies, smaller assets, compression).
3. Do less on the main thread; defer non-critical work; virtualize long lists.
4. Cache and prefetch deliberately; reduce request count and size; use a CDN.
5. Test on slow devices and networks, not only developer hardware.

---

# Part 12: Procedure, report template, and checklist

## 12.1 Procedure (twelve steps)

1. Write the SLO: metric, percentile, load, data size, and guardrails.
2. Build a representative workload and data set.
3. Measure the baseline and record the environment.
4. Decompose time; classify the bottleneck (CPU, memory, I/O, lock, downstream, queue).
5. Compute the maximum possible gain (Amdahl) for each candidate.
6. Rank fixes with the leverage ladder.
7. Add characterization tests; keep the old version as an oracle.
8. Make one change; verify correctness; re-measure; keep or revert.
9. Check semantic changes and durability guarantees.
10. Add a regression guard (benchmark, budget, alert).
11. Roll out with canary and rollback; compare to baseline in production.
12. Soak, scale, and fault test; record the result and assumptions.

## 12.2 Measurement report template

```
Goal (SLO):            ...
Workload and data:     ...
Environment:           hardware / versions / config
Baseline:              p50 / p95 / p99 / throughput / errors / resource use
Bottleneck evidence:   profile / trace / plan summary
Change:                what, and why
Result:                p50 / p95 / p99 / throughput / errors / resource use
Correctness check:     tests / differential run
Durability impact:     none / what changed and the bounded risk
Regression guard:      test or alert added
Tradeoffs / assumptions: ...
```

## 12.3 Pre-merge checklist for a performance change

- [ ] SLO and baseline recorded; improvement measured, repeated, and above noise
- [ ] Bottleneck evidence attached (profile, trace, plan)
- [ ] Correctness verified (characterization and differential tests)
- [ ] No silent change to ordering, rounding, staleness, error handling
- [ ] No durability or safety guarantee weakened (or the change is explicit, bounded, approved)
- [ ] All new caches, pools, queues, and retries bounded and monitored
- [ ] Works with cold cache and under dependency failure
- [ ] Tested at projected data size; soak test run if state or memory is involved
- [ ] Regression guard added; rollback plan exists
- [ ] Optimized code commented with the measured reason

---

# Part 13: What still breaks

-  Benchmarks are models. Production has traffic mixes, data skew, noisy neighbors, and failure patterns no test fully reproduces. Production observability is the final judge, which is why continuous measurement and canaries matter.
-  Measurement changes the system (observer effect): profilers, tracing, and logging add overhead and can shift timing-sensitive bugs.
-  Workloads and data drift. An optimization correct today can become irrelevant or harmful after growth, a new feature, a runtime upgrade, or a change in access patterns. Re-measure on a schedule and after environment changes.
-  Rare failures (a power loss at the worst instant, a corrupt disk sector, a regional outage) cannot be fully tested. Durability rests on layered defenses (replication, backups with tested restores, checksums, idempotent recovery) and regular drills, not on any single test.
-  Distributed systems have nondeterminism (retries, reordering, partial failure, clock skew), so some performance and durability issues appear only at scale or under unusual timing. Fault injection and chaos testing reduce, but do not eliminate, this.
-  Speed, durability, consistency, cost, and simplicity trade against each other. No setting maximizes all of them; the work is deciding the tradeoff per data class and workload and writing the decision down.
- [Guessing] Which rules matter most for you depends on your stack, workload, and failure history, which I do not know. In most systems the gains and losses are dominated by P1, P8, P13, P39, P47, P69, P108, P113, and P120.

If you tell me the kind of system (API service, batch pipeline, database-heavy backend, graph store, UI), the scale, and the current symptom, I can cut this to the rules that apply, build a measurement plan for it, or review specific code or queries once you approve sharing them.