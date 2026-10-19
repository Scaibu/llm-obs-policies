
# Category 10: Observability and operations

**Problem statement:** Operators must detect, diagnose, and fix failures faster than they harm users, and must know the real configuration and capacity of the system. Failure here means problems visible to users but not to the team, visible but undiagnosable, or caused by unexamined defaults and unclear responsibility boundaries.

**Subproblems:** 10A detection and diagnosis. 10B configuration. 10C managed services.

## 10A. Detection and diagnosis

#### 10.1 "Monitoring CPU and averages is enough" (was #93) 
- **Why wrong:** Users experience the tail, and database failures show up as saturation (connection waits, lock waits, queue depth, replication lag, vacuum lag), not CPU. Averages hide bimodal behavior.
- **What is correct:** Monitor user-visible symptoms and per-resource saturation.
- **Problem it creates:** Incidents detected by customers, and alerts that fire on harmless CPU while real deadlocks stay quiet.
- **First-principles fix:** Define SLIs per critical flow (latency percentiles, error rate, data freshness). Alert on SLO burn rate, collect saturation signals per resource for diagnosis, and track latency per query fingerprint from statement statistics.
- **Meta:** Which user-visible failure triggers no alert today? How far apart are my p50 and p99?
- **Second-order:** Alert fatigue, the cost of high-cardinality metrics, and SLO targets that drive perverse behavior.

#### 10.2 "Logging everything gives us observability" (was #94) 
- **Why wrong:** Volume buries signal, costs money, risks PII, and still can't answer questions unless events are structured and correlated.
- **What is correct:** Observability is the ability to ask new questions of the system using rich, correlated events.
- **Problem it creates:** Expensive logs that can't locate the one failing request.
- **First-principles fix:** Structured events with a trace ID and high-cardinality fields (tenant, query fingerprint), distributed tracing through services and database calls, tail-based sampling that keeps errors and slow requests, PII redaction at the source, and tiered retention.
- **Meta:** Can I trace one failing request across every hop in five minutes? What PII is in my logs right now?
- **Second-order:** Sampling drops rare events, trace context breaks at async boundaries, and the logging pipeline is itself a failure-prone system.

## 10B. Configuration

#### 10.3 "Database defaults are production-ready" (was #95) 
- **Why wrong:** Defaults are conservative so the engine starts on small machines (memory settings often far below what the hardware offers) and unbounded where you need bounds (statement time, idle-in-transaction time). They vary by version.
- **What is correct:** Defaults are a starting point of unknown fit.
- **Problem it creates:** Wasted hardware, runaway queries, unbounded waits, autovacuum too slow for big tables.
- **First-principles fix:** Build a baseline per workload: memory from RAM and concurrency, statement, lock, and idle-in-transaction timeouts, per-table autovacuum settings for large hot tables, checkpoint and WAL tuning, slow-query and lock-wait logging. Keep config in version control and load-test changes.
- **Meta:** Which settings differ from defaults, and why? Which unbounded resource can one bad query consume?
- **Second-order:** Tuned values drift as data and hardware change, per-table overrides get forgotten, and config changes need staged rollout (see 5.9).

## 10C. Managed services

#### 10.4 "A managed database means operations are handled" (was #99) 
- **Why wrong:** The provider runs the platform, not your workload. Query tuning, schema design, connection management, capacity planning, application behavior during failover, maintenance windows, quotas, and version end-of-life remain yours.
- **What is correct:** Responsibility is shared, with a boundary you must know.
- **Problem it creates:** Surprise failovers during maintenance, IOPS or burst-credit exhaustion, connection limits, forced upgrades, no low-level access during an incident.
- **First-principles fix:** Write a responsibility matrix. Alarm at 70% of every quota, test application behavior during provider failover and maintenance, run restore drills, track end-of-life dates, and keep an export path out.
- **Meta:** What can't I inspect or change during an incident? Which failures will the provider not fix for me?
- **Second-order:** Proprietary features create lock-in, provider support latency becomes part of your RTO, and the cost model (IOPS, storage tiers) can surprise you.

---
