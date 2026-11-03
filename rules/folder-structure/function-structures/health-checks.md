The most disastrous Kubernetes outage pattern is tying liveness probes directly to database or Redis ping queries. [Certain] When PostgreSQL experiences a 30-second failover, database-bound liveness probes fail across all 100 replicas simultaneously, triggering a fleet-wide restart loop and a catastrophic reconnect storm that knocks the database over again.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Multi-Tier Probe Architecture

```
buildHealth(infra, clients) → health                                        ⚙
├── liveness() → HTTP 200 (alive) | HTTP 500 (deadlock)
│   └── ONLY asserts: event loop responsive, process not deadlocked
│       STRICT INVARIANT: NEVER checks databases, caches, or downstream APIs
├── readiness() → HTTP 200 (ready) | HTTP 503 (notReady)
│   ├── startupComplete == true
│   ├── notShuttingDown == true (flips to false immediately on SIGTERM)
│   ├── hardDependencies → evaluated via background cached health results
│   └── softDependencies → reported in payload, NEVER fail readiness
├── startup() → HTTP 200 (ready)
│   └── dedicated probe for slow starters, warm-up caches, schema validation
├── backgroundChecker(interval) → updates cached readiness booleans         ↺
└── details() → JSON status of each component (admin port only)             ⚙
```

---

## 2. Background Health Checker Daemon

Readiness checks must decouple HTTP probe handlers from live database ping calls:

```
backgroundHealthDaemon(ticker)                                              ⚙
├── for each hardDependency in [postgresPool, kafkaProducer]:
│   ├── checkWithTimeout(1s) → status
│   └── updateAtomicFlag(hardDependency, status)
└── sleep until ticker fires (every 2s)
```

Probe endpoints merely read the cached atomic booleans, guaranteeing $O(1)$ sub-millisecond responses regardless of downstream network stalls.

---

## 3. Strict Health Check Invariants

1. **Liveness Independence**: Liveness probes must strictly verify in-process health (goroutine deadlock, memory leak, loop hung). A service must never declare itself dead because a remote dependency is unreachable.
2. **Immediate SIGTERM Un-Readiness**: Upon receiving `SIGTERM`, readiness probes must immediately return HTTP 503 while the server enters its graceful shutdown margin, removing the pod from ingress load balancers before draining connections.
3. **Admin Port Isolation**: Detailed health diagnostic metrics and component dependency status trees must be served exclusively on an isolated admin port (e.g. `:8081`), never exposed on the public API gateway.

