
# Part 3: Deploying and running in production

## 3.1 Deployment pipeline

```
PR → lint → unit tests (tiny fixture, Testcontainers Neo4j) →
plan checks (EXPLAIN: no AllNodesScan/Cartesian) →
perf tests (skewed fixture, db-hits ceilings) →
staging at scale → canary in prod → full rollout → soak watch
```

-  **Test against a real Neo4j in CI**, not a mock. Cypher semantics (nulls, uniqueness, planner behavior) can't be mocked meaningfully.
- Deploy queries and schema as **separate pipelines**.  Schema (expand phase) ships first, queries second, contract phase last.
- Infra as code: Terraform/Helm values in version control. Config changes (memory, timeouts) get the same review as queries. 
- Rolling restarts: one server at a time, secondaries first, then transfer leadership before restarting a primary, and wait for the replica to catch up and warm its cache before moving on. 

## 3.2 Production guardrails (the query gateway)
- Admission control per query ID: max concurrent executions, per-tenant rate limits. 
- Timeouts: transaction timeout at the server (`db.transaction.timeout`) and a shorter client-side deadline. [Likely, verify names]
- Memory caps per transaction (`db.memory.transaction.max`) so one query can't OOM a server. 
- Circuit breaker per query ID. When error rate or latency exceeds the threshold, fail fast or serve cached/stale results. 
- **Kill switch per query ID** (feature flag) to disable a bad query without a deploy. 
- Result caching for T1 reads (Redis, with short TTL plus invalidation on key writes). 

## 3.3 Observability and debugging

**Tag every query** [Certain this is the most valuable single practice]:
```python
session.execute_read(fn, metadata={"queryId": "recs.peer_products", "version": "v3", "traceId": trace_id})
```
Metadata appears in `SHOW TRANSACTIONS` and the query log, so you can map a slow log line to code.

**Query log** [Likely, verify settings in your version]:
```
db.logs.query.enabled=INFO          # VERBOSE only when investigating
db.logs.query.threshold=500ms       # log only slow queries
db.logs.query.parameter_logging_enabled=false   # privacy: parameters may contain PII
db.logs.query.time_logging_enabled=true
db.logs.query.allocation_logging_enabled=true   # memory per query
db.logs.query.page_logging_enabled=true         # page cache hits and faults
```
Ship logs to your log platform. Parse out `queryId`, elapsed time, allocated bytes, page hits and faults.

**Metrics to dashboard** :
- Latency p50/p95/p99 **per query ID**, not just overall.
- Page cache hit ratio, page faults per second.
- Transactions open, committed, rolled back; deadlock count.
- Raft: leader changes, commit lag, per-secondary replication lag.
- GC pause time, heap usage, tx log size, checkpoint duration, disk IO latency.
- Ingestion: Kafka consumer lag and writer batch time.

**Debug runbook by symptom** :

| Symptom | First checks | Typical cause and action |
|---|---|---|
| p99 spike on one query ID | Slow log for that ID, `PROFILE` with the offending parameter | Hub anchor, plan changed, missing cap → add cap, hint, or kill switch |
| p99 spike on everything | Page cache hit ratio, GC pauses, disk latency | Working set exceeded cache, long GC, noisy neighbor → scale up or shed load |
| Long-running query | `SHOW TRANSACTIONS YIELD * WHERE elapsedTime > duration('PT30S')` | `TERMINATE TRANSACTIONS '<id>'`, then find the query ID in metadata |
| Writes slow or timing out | Raft commit lag, log disk latency, lock waits | Hot-node contention or slow disk → re-partition writers, check deadlock logs |
| Deadlocks | `debug.log` and `neo4j.log`, error codes `DeadlockDetected` | Writers lock in different orders → sort keys, partition by node |
| Stale reads | Secondary lag, bookmark usage | Use causal bookmarks for read-your-writes paths only |
| Plan regression after growth or upgrade | Compare `EXPLAIN` to a stored baseline plan | Statistics skew, replan interval → store plans in CI and diff them |
| OOM kills | Allocation log, container limits | Unbounded `collect()` or sort → cap, and set requests = limits in Kubernetes |

**Plan baselines:**  store the `EXPLAIN` output (operator tree) for each query in the repo, and alert when production plans differ. Plan changes are the most common silent cause of regressions.

## 3.4 Scaling playbook

Order of operations when load grows :
1. **Fix the query** (caps, aggregation, materialization). It's cheaper than any hardware.
2. **Cache** results and expensive intermediates.
3. **Scale up** RAM first (page cache), then NVMe IOPS, then cores.
4. **Scale reads out** with more secondaries, dedicated per workload class (serving, analytics, backup). Warm each new secondary's cache before it takes traffic. 
5. **Split workloads** onto separate clusters (serving vs analytics) so they don't share a cache.
6. **Shard or tier the data** (composite databases, property sharding where available, or the polyglot design from my last answer). This is a modeling project, not a toggle. 

**Write scaling is different** : a database has one write leader, so read replicas won't help. Options are batching, partitioning by domain into multiple databases, and moving high-frequency counters out of the graph.

**Scale triggers (set from your own baselines)** [Guessing on numbers]:
- Page cache hit ratio below ~98% sustained → add memory or shrink the hot set.
- Replication lag above your freshness SLO → add capacity or reduce write burst size.
- CPU above 60-70% at peak on secondaries → add secondaries.
- Disk above 70% full → plan the expansion, because store copies and backups need headroom.

**Autoscaling:**  don't autoscale primaries. Automate secondary add/remove only with cache warmup and a gradual traffic ramp. Cold secondaries at TB scale cause latency incidents.

## 3.5 Incident handling
1. **Stop the bleeding:** flip the kill switch or rate limit for the offending query ID, or shed T3 traffic. 
2. **Identify:** use `queryId` metadata plus slow logs, and `SHOW TRANSACTIONS`.
3. **Mitigate:** terminate runaway transactions, route traffic away from the unhealthy server, roll back the query version via the registry.
4. **Fix forward:** reproduce with the exact parameter on a staging restore, `PROFILE`, patch, and add the case to the anchor tests so it can't recur. 
5. **Post-mortem:** what budget was missing, and which CI gate should have caught it.

## 3.6 Backup, restore, and DR (production readiness)
-  Run backups from a dedicated secondary, ship to object storage, and **time a full restore** so you know your real RTO.
- Run quarterly drills: restore into a fresh cluster, fail an AZ, and replay the Kafka offsets to verify T2 rebuild.
- Define which data is rebuildable (derived relationships such as `TOP_CONNECTION`) and which is source of truth. Don't pay backup cost for rebuildable data unless recompute exceeds your RTO. 
