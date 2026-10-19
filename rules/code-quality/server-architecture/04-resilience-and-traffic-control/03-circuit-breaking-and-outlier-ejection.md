Upstream Protection
├── why: one slow upstream holds workers until inbound admission sheds
│        healthy traffic
│
├── Circuit breaker (per upstream service)
│   ├── states
│   │   ├── Closed ...... normal; counting failures
│   │   ├── Open ........ fail fast locally; no calls sent
│   │   └── Half-open ... limited probe requests decide close / reopen
│   ├── trip conditions
│   │   ├── error rate > threshold over window (min request count)
│   │   └── latency p99 > threshold (slow is the new down)
│   ├── [M] open duration with jitter; exponential on repeated trips
│   ├── [M] open breaker ⇒ fast 503 + Retry-After upstream of the caller
│   ├── DECIDE: thresholds per upstream  [Guessing until SLOs exist]
│   └── emit: breaker_state{upstream}, breaker_transitions_total
│
├── Outlier ejection (per upstream instance)
│   ├── triggers
│   │   ├── consecutive 5xx / connection failures
│   │   └── latency far above peer instances
│   ├── [M] max ejected percentage (never eject the whole pool)
│   ├── [M] ejection time grows with repeat offences
│   └── emit: ejected_instances{upstream}
│
├── Bulkheads
│   ├── [M] per-upstream concurrency caps (tree 1) = bulkheads
│   └── why: a slow upstream can only consume its own slice of workers
│
└── Fallbacks
    ├── DECIDE per route: fail / serve stale cache / serve degraded / default
    └── [M] fallback path has its own limits — it can overload too