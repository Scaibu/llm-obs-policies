# Category 3: Overload, capacity, and failure amplification

**Problem statement:** Demand exceeds the capacity of a shared stateful component, usually the database. The system's own reactions (retries, autoscaling, queues, health checks) then make the overload worse. The failure is a feedback loop, so a 10% slowdown can become a total outage.

**Subproblems:** 3A admission and concurrency. 3B reaction amplification. 3C workload interference and skew.

## 3A. Admission and concurrency

#### 3.1 "More connections means more throughput" (was #68) 
- **Why wrong:** Throughput rises until CPU or I/O saturates, then falls from contention and context switching. Each connection also costs memory (a process each in PostgreSQL).
- **What is correct:** Useful concurrency is proportional to hardware parallelism with a small multiplier, and the rest should queue outside the database.
- **Problem it creates:** Memory exhaustion, lock contention, latency cliffs at peak, connection storms on restart.
- **First-principles fix:** Derive executable concurrency from cores and I/O. Size a pooler (pgbouncer-style) to that, give each service a budget so all budgets sum below max_connections with headroom, and queue or shed at the edge.
- **Meta:** What is the sum of maximum pool sizes across all instances at maximum autoscale? What happens when the pool is full?
- **Second-order:** Does transaction-pooling mode break session features (prepared statements, advisory locks, SET)? Does queueing delay cause client timeouts and retries?

#### 3.2 "Autoscaling the app tier scales the system" (was #72) 
- **Why wrong:** App instances share the database, and each added instance adds load and connections, so scaling out during a database slowdown deepens it.
- **What is correct:** System capacity is the minimum across all shared stateful components.
- **Problem it creates:** Latency triggers scale-up, which adds load, which worsens latency, which ends in an outage.
- **First-principles fix:** Express database capacity as a global budget and cap app scale-out to it. Add backpressure (bounded queues, concurrency limits) and load shedding that drops low-priority work first.
- **Meta:** Which component saturates first, with numbers? Could the scale-out trigger itself be caused by a downstream slowdown?
- **Second-order:** What do shed requests experience? Does the cap hide organic growth that needs a capacity plan?

#### 3.3 "Rate limiting is for abuse only" (was #87) 
- **Why wrong:** Overload comes from friendly sources too: batch jobs, one large tenant, client bugs, retry storms.
- **What is correct:** Limits are admission control that protects finite capacity from any source.
- **Problem it creates:** One tenant or job degrades everyone.
- **First-principles fix:** Allocate capacity per tenant, client, and traffic class using token buckets and concurrency limits. Reserve headroom for critical traffic and return explicit rejections with retry-after guidance.
- **Meta:** Who can generate load I didn't plan for? What is each tenant's fair share?
- **Second-order:** Will limits make clients retry harder? How do I retune limits as tenants grow?

## 3B. Reaction amplification

#### 3.4 "Timeouts and retries make calls reliable" (was #80) 
- **Why wrong:** Retries add load exactly when the dependency is struggling, and layers multiply: three layers with three attempts each can mean 27 requests per original one.
- **What is correct:** Retries are a controlled spend of extra capacity, justified only for transient, idempotent failures.
- **Problem it creates:** Retry storms, synchronized waves, prolonged outages.
- **First-principles fix:** Retry at one layer only. Cap retries as a percentage of original traffic (a retry budget), propagate deadlines downward, use exponential backoff with jitter, retry only idempotent operations, and add circuit breakers.
- **Meta:** How many layers retry? What happens to total load if the dependency becomes 10x slower?
- **Second-order:** Does a closing breaker cause a thundering herd? What do users see when retries are exhausted?

#### 3.5 "A queue decouples us from the bottleneck" (was #73) 
- **Why wrong:** A queue turns a spike into delay. If arrivals stay above service rate, delay grows without bound.
- **What is correct:** Queues absorb bursts only, and sustained overload needs rejection or more capacity.
- **Problem it creates:** Hours-old backlogs, storage exhaustion, long recovery, stale work processed after it stopped mattering.
- **First-principles fix:** Apply Little's Law (queue length = arrival rate × wait). Set consumer rate to downstream capacity, bound the queue, define an overflow policy (drop, shed, spill) and a maximum message age, and alert on oldest-message age.
- **Meta:** What are steady-state arrival and service rates? Is stale work still worth processing?
- **Second-order:** Does the bound push errors back to producers? In what order should the backlog drain after an outage?

#### 3.6 "A 200 from the health check means the service is healthy" (was #82) 
- **Why wrong:** Health signals are routing decisions. A shallow check keeps sending traffic to broken instances, and a deep check on a shared dependency removes every instance when that dependency blips.
- **What is correct:** Liveness (restart me) and readiness (send me traffic) are different questions with different dependencies.
- **Problem it creates:** Traffic to broken nodes, or degradation converted into total outage.
- **First-principles fix:** Check readiness against the instance's own ability and bounded local resources. Apply a minimum-healthy rule (fail open when too many instances fail at once), and degrade features rather than dropping the instance.
- **Meta:** If the database slows, should this instance stop receiving traffic? What happens if every instance fails readiness at once?
- **Second-order:** Does fail-open send traffic to genuinely broken nodes? How does my load balancer behave with zero healthy targets?

## 3C. Workload interference and skew

#### 3.7 "Analytics can run on the OLTP primary" (was #51) 
- **Why wrong:** Large scans evict hot cache pages, saturate I/O, and hold snapshots that block cleanup.
- **What is correct:** Workloads with different access patterns need isolated resources and, often, different physical layouts.
- **Problem it creates:** Latency spikes on user-facing queries when reports run.
- **First-principles fix:** Identify analytical queries by scan size and duration. Route them to a replica (understanding replication-conflict settings and lag) or a columnar store fed by CDC, and enforce statement timeouts on the primary.
- **Meta:** What freshness do analytics actually need? Which queries are scans in disguise?
- **Second-order:** Does the second store create a new consistency boundary? Who owns schema drift between the two?

#### 3.8 "Long-running read queries are harmless" (was #52) 
- **Why wrong:** In MVCC engines, a snapshot pins old row versions until it ends.
- **What is correct:** Read duration has a storage and maintenance cost, even without writes.
- **Problem it creates:** Table and index bloat, vacuum unable to advance, replica query conflicts, and in PostgreSQL, transaction-ID wraparound risk.
- **First-principles fix:** Cap statement and idle-in-transaction durations, monitor oldest-transaction age, and move long reads to dedicated replicas or chunk them.
- **Meta:** What is the oldest open transaction right now? Which clients leave transactions open?
- **Second-order:** Do timeouts break legitimate reports? Do chunked reads give inconsistent results across chunks?

#### 3.9 "Hot spots mean we need more capacity" (was #71) 
- **Why wrong:** Capacity helps only when load can be divided, and a single hot key, partition, or tenant can't be divided by adding nodes.
- **What is correct:** Hot spots are a distribution problem, so first measure the distribution.
- **Problem it creates:** One partition or row saturates while the rest sit idle, and added hardware changes nothing.
- **First-principles fix:** Measure per-key and per-partition load, then spread it: hash prefixes or salted keys, bucketed counters, caching or coalescing of hot reads, isolation of heavy tenants, and per-key rate limits.
- **Meta:** What is the hottest key's load relative to the median? Is hotness from key design or genuine popularity?
- **Second-order:** Does spreading keys make range reads scatter? How do I find the next hot key before it hurts?

---