This is a new reference covering every Tier 1 area: **200 algorithms**, with no repeats from the earlier references (where something was touched before, only the parts not yet covered are added, with a cross-reference). Same format as before (definition, how it works, cost, agent use), no code, in 4 parts of 50.

**Map:**
- **Part 1 (#1–50): Stream processing.** Time semantics and watermarks, windowing, sliding-window aggregation, joins, complex event processing, state and fault tolerance, exactly-once, partitioning and consumption.
- **Part 2 (#51–100): Caching, load balancing and distributed coordination.** Eviction and admission, cache consistency, load balancing and overload control, consensus and replication, clocks and distributed transactions, CRDTs, rate limiting and IDs.
- **Part 3 (#101–150): Classical machine learning.** Linear models, trees and boosting, kernel and instance methods, clustering and mixtures, probabilistic models, anomaly detection, time series, model selection, online learning and drift.
- **Part 4 (#151–200): Experimentation and statistics.** Testing foundations, randomization and validity checks, variance reduction, sequential and Bayesian testing, multiple testing, complex designs, heterogeneous effects and uplift, observational causal inference, and robust statistics.

Standard definitions here are . Where details differ between systems (Flink, Kafka Streams, Spark, specific caches), entries say so.

---

# Tier 1 contract (referenced in every entry)

| Role | Job | Can write? |
|---|---|---|
| **Pipeline Builder** | Designs stream topologies: sources, operators, state, sinks | Configs only |
| **Processor** | Runs and operates streaming jobs | Job state, sinks, through approved deployments |
| **Coordinator** | Operates caches, load balancers, consensus and storage infrastructure | Infra changes, through approved plans |
| **Modeler** | Builds and evaluates classical ML models | Models, in staging |
| **Experimenter** | Designs and analyzes experiments and causal studies | Analysis results (decisions belong to owners) |
| **Verifier** | Checks correctness, delivery guarantees and statistical validity | No (can block) |

**Rules:**
- **T1. Time semantics declared:** every stream computation states event time or processing time, its watermark strategy and its allowed lateness.
- **T2. Delivery semantics declared end to end:** at-most-once, at-least-once or exactly-once, from source to sink, and verified by test.
- **T3. Bounded state:** every stateful operator has a retention rule (window, TTL, compaction) and a size estimate.
- **T4. Partitioning documented:** keys, partition counts and co-partitioning requirements for joins are explicit.
- **T5. Plan before data:** every model and experiment has a pre-declared metric, baseline and analysis plan.
- **T6. Uncertainty attached:** results carry confidence intervals or error bounds.
- **T7. Reproducible:** seeds, versions, offsets and data snapshots are recorded.
- **T8. Outputs are proposals:** decisions affecting people, money or production systems go through owners or approved policies.

**Guardrails:**
- **TX1. Resource caps:** state size, memory, CPU, compute cost and query limits.
- **TX2. Replay safety:** any reprocessing must not repeat external side effects. Sinks and actions are idempotent or transactional.
- **TX3. Data governance:** personal data in streams, caches and models follows retention, minimization and access rules.
- **TX4. Change approval:** consensus membership changes, partition and rebalance changes, and cache-cluster topology changes need approval and staged rollout.
- **TX5. No p-hacking:** no changing metrics, segments or stopping rules after seeing the data, unless declared as exploratory.

---

# PART 1: STREAM PROCESSING

## A1. Time, ordering and lateness

### 1. Event time, ingestion time and processing time semantics

**Definition:** The three clocks a stream system can use to assign a time to each record, which determine whether results reflect when things happened or when they were processed.

**Cost:** Event time adds buffering state and latency (waiting for late data). Processing time is cheapest but not reproducible.

### 2. Watermark generation strategies

**Definition:** Rules that produce watermarks, assertions that "no more events with timestamps earlier than T are expected", which let event-time operators finalize results.

**Cost:** The delay trades completeness (fewer late events) against latency (results come later).

### 3. Watermark propagation and alignment

**Definition:** How watermarks flow through an operator graph, and how to keep fast sources from running far ahead of slow ones.

**Cost:** Alignment bounds buffered state at the cost of throttling fast sources.

### 4. Allowed lateness and late-data side outputs

**Definition:** Policies for events that arrive after the watermark has passed their window: update results, route them elsewhere, or drop them.

**Cost:** Allowed lateness keeps window state longer (memory, T3).

### 5. Out-of-order buffering (K-slack reordering)

**Definition:** Restoring time order within a bounded delay, for operators that need strictly ordered input.

**Cost:** O(log n) per event. Memory for the buffered window of K time units.

### 6. Triggers and accumulation modes

**Definition:** Rules for when a window emits results (possibly several times) and how successive results relate to each other.

**Cost:** Each firing costs an emission and downstream processing.

### 7. Bounded-state stream deduplication

**Definition:** Removing duplicate events (from retries, at-least-once delivery or replays) using limited memory.

**Cost:** Memory proportional to keys seen within H.

### 8. Sequence numbers and gap detection

**Definition:** Using per-producer or per-key sequence numbers to detect missing, duplicated or reordered events.

**Cost:** One counter per producer or key.

## A2. Windowing and window aggregation

### 9. Tumbling windows

**Definition:** Fixed-size, non-overlapping, contiguous time windows. Each event belongs to exactly one window.

**Cost:** O(1) per event. State: one aggregate per key per open window.

### 10. Hopping (sliding) windows

**Definition:** Fixed-size windows that start at regular intervals smaller than their size, so they overlap and each event belongs to several windows.

**Cost:** Naive: O(S/H) per event. Efficient methods are much lower.

### 11. Session windows (gap-based)

**Definition:** Variable-length windows that group a key's events separated by less than a gap, ending after a period of inactivity.

**Cost:** State per active session. Merging cost is small.

### 12. Global and count windows with custom triggers

**Definition:** Windows not tied to fixed time boundaries: one window per key for all time (global), or windows of N events (count windows), emitting according to custom triggers.

**Cost:** Depends on the trigger and eviction logic.

### 13. Window assignment and merging

**Definition:** The algorithm that assigns each event to its windows, and merges windows when needed (for sessions), while keeping their state consistent.

**Cost:** Small per event. Merges cost proportional to the state merged.

### 14. Pane-based window slicing (Pairs, Cutty)

**Definition:** Computing overlapping windows by splitting the timeline into non-overlapping slices, aggregating each slice once, and combining slices into windows.

**Cost:** O(1) per event, plus combining (S/slice size) partial aggregates per window.

### 15. Two-stacks sliding window aggregation (non-invertible aggregates)

**Definition:** An amortized O(1) method to maintain aggregates like max, min or any associative operation over a sliding window, without needing to "subtract" elements.

**Cost:** Amortized O(1). Occasional O(n) flips.

### 16. FlatFAT and DABA (worst-case efficient sliding aggregation)

**Definition:** Sliding-window aggregation structures with worst-case (not just amortized) bounds, suited to low-latency systems.

**Cost:** FlatFAT O(log n) per update. DABA worst-case O(1).

### 17. Subtract-on-evict (invertible incremental aggregation)

**Definition:** Maintaining aggregates over a sliding window by adding new elements and subtracting expired ones, for aggregates that have an inverse.

**Cost:** O(1) per event.

### 18. Mergeable sketches for windowed approximate aggregates

**Definition:** Using sketches that can be combined (HyperLogLog, Count-Min, t-digest, KLL) as window and slice aggregates, so approximate distinct counts and quantiles can be computed over any window combination.

**Cost:** Fixed size per sketch, cheap merges.

## A3. Stream joins and enrichment

### 19. Windowed stream-stream join (symmetric hash join)

**Definition:** Joining two event streams on a key, for events that fall in the same time window.

**Cost:** State = events per window on both sides. O(matches) per event.

### 20. Interval join

**Definition:** Joining two streams where events match if their timestamps are within a relative time range of each other, such as a payment between 0 and 30 minutes after an order.

**Cost:** State depends on the interval width and event rates.

### 21. Stream-table join (changelog materialization)

**Definition:** Enriching each stream event with the current value from a table that is itself maintained from a changelog stream.

**Cost:** One local lookup per event. Table state size.

### 22. Temporal (as-of) join with versioned tables

**Definition:** Joining each event with the version of a table row that was valid at the event's time, not the current version.

**Cost:** O(log versions) per lookup. Version history state.

### 23. Foreign-key table-table join

**Definition:** Joining two continuously updated tables on a foreign key (for example orders → customers) as a streaming computation that stays correct as either table changes.

**Cost:** Subscription state on the right side. Extra network messages.

### 24. Lookup and async enrichment with caching

**Definition:** Enriching events by querying an external system (database, service), asynchronously with bounded concurrency and a local cache.

**Cost:** Bounded by the external service's capacity.

### 25. Join skew handling (hot-key splitting, salting)

**Definition:** Dealing with keys that have far more events than others, which overload one partition in joins and aggregations.

**Cost:** Extra stage and replication for hot keys.

### 26. Join state cleanup (TTL and watermark-driven eviction)

**Definition:** Removing join state that can no longer produce matches, so state doesn't grow forever.

**Cost:** Small. Background cleanup cost.

## A4. Complex event processing and pattern analytics

### 27. Complex event processing with NFAs

**Definition:** Detecting patterns of events (sequences, with conditions and time limits) by running a nondeterministic finite automaton over the stream.

**Cost:** Proportional to active runs, which can explode with permissive patterns.

### 28. Contiguity modes and after-match skip strategies

**Definition:** Rules that control which events may appear between pattern elements, and how matching resumes after a match is found.

**Cost:** Non-deterministic relaxed contiguity can be exponential. Strict is cheapest.

### 29. Row pattern recognition (SQL MATCH_RECOGNIZE)

**Definition:** The SQL standard syntax (ISO/IEC 9075, introduced in SQL:2016) for pattern matching over ordered rows, supported by several streaming SQL engines.

**Cost:** Like CEP.

### 30. Funnel and path analysis over streams

**Definition:** Computing how many users (or entities) complete an ordered sequence of steps within a time limit, and where they drop off.

**Cost:** One small state per active entity.

### 31. Autoscaling stream jobs (DS2)

**Definition:** Choosing the parallelism of each operator in a streaming job from measured processing rates, so the job keeps up with input without overprovisioning.

**Cost:** Light instrumentation. Rescaling costs a state redistribution (#41).

## A5. State and fault tolerance

### 32. Keyed state and key groups

**Definition:** Partitioning operator state by key, and grouping keys into a fixed number of key groups, so state can be redistributed when the parallelism changes.

**Cost:** None at runtime. Rescaling moves whole key-group ranges.

### 33. State backends and incremental checkpoints

**Definition:** Where operator state lives (in-memory heap or an embedded LSM store like RocksDB) and how checkpoints copy only what changed.

**Cost:** Heap: fast access, expensive full checkpoints. LSM: slower access, cheap incremental checkpoints.

### 34. Chandy-Lamport distributed snapshots

**Definition:** An algorithm for capturing a consistent global snapshot of a distributed system (every process's state plus the messages in flight) without stopping it.

**Cost:** Marker messages and recorded channel contents.

### 35. Asynchronous barrier snapshotting (aligned checkpoints)

**Definition:** The stream-processing version of Chandy-Lamport used by Flink-like systems: barriers flow through the data stream, and operators snapshot their state when barriers pass.

**Cost:** Alignment delays under backpressure. Asynchronous state upload.

### 36. Unaligned checkpoints

**Definition:** A checkpointing variant where barriers overtake buffered records, and the in-flight data is stored as part of the checkpoint, so checkpoints complete quickly even under heavy backpressure.

**Cost:** Larger checkpoints. Fast completion.

### 37. Exactly-once sinks with two-phase commit

**Definition:** Making external outputs exactly-once by committing them transactionally only when the checkpoint that covers them completes.

**Cost:** Output visible only at checkpoint completion (latency = checkpoint interval).

### 38. Kafka transactions (consume-transform-produce)

**Definition:** Kafka's protocol for atomically writing output records to several partitions together with the consumer's input offsets, making read-process-write loops exactly-once within Kafka.

**Cost:** Commit latency per transaction, and some throughput cost (batch transactions to amortize it).

### 39. Idempotent producers

**Definition:** A broker-side mechanism that discards duplicate writes caused by producer retries, using producer IDs and per-partition sequence numbers.

**Cost:** Negligible.

### 40. State TTL and retention

**Definition:** Automatic expiry of state entries after a time limit, to keep long-running stateful jobs from growing without bound.

**Cost:** Timestamp per entry. Background cleanup.

### 41. Rescaling stateful jobs

**Definition:** Changing the parallelism of a running stateful job while keeping state and exactly-once guarantees.

**Cost:** Downtime of a stop-restore cycle (shorter with local recovery).

### 42. Changelog topics, standby replicas and state restoration

**Definition:** Making local state durable by mirroring every state change to a compacted log, and keeping warm copies on other instances for fast failover (Kafka Streams model).

**Cost:** Changelog write amplification. Standby replicas double state storage.

## A6. Partitioning, consumption and log management

### 43. Producer partitioning strategies

**Definition:** How producers choose a partition for each record, which determines ordering, load balance and co-partitioning.

**Cost:** Negligible.

### 44. Consumer group partition assignment (range, round-robin, sticky, cooperative)

**Definition:** The protocols and strategies by which a group of consumers divides a topic's partitions among themselves, and rebalances when members join or leave.

**Cost:** Rebalances pause affected partitions.

### 45. Static membership (rebalance avoidance)

**Definition:** Giving each consumer a persistent identity, so short restarts don't trigger rebalances.

**Cost:** Slower detection of real failures (bounded by the timeout).

### 46. Offset management and commit strategies

**Definition:** How and when consumers record their progress (offsets), which determines delivery semantics.

**Cost:** Commit frequency trades overhead against replay amount.

### 47. Log compaction (key-based retention and tombstones)

**Definition:** Retention that keeps at least the latest record for each key in a topic, deleting older versions, so the topic becomes a durable table.

**Cost:** Background cleaner I/O.

### 48. Time and size retention, segment rolling and tiered storage

**Definition:** How logs expire old data by age or size, and how tiered storage moves older segments to cheap object storage while keeping them readable.

**Cost:** Tiered storage cuts disk costs. Remote reads are slower.

### 49. Dead-letter queues and retry topics

**Definition:** Routing records that fail processing to separate topics, with delayed retries, instead of blocking the partition or losing data.

**Cost:** Extra topics and consumers.

### 50. Repartitioning and co-partitioning for joins

**Definition:** Making sure records with the same join key are in the same partition number of each joined topic, and reshuffling (repartitioning) data when they aren't.

**Cost:** One extra write and read through the broker.

---
