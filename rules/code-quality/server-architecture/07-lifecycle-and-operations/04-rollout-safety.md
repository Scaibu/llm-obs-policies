Rollout Safety
├── Config rollout
│   ├── why: valid config can still be wrong
│   ├── [M] staged: canary replicas → percentage → fleet
│   ├── [M] automatic rollback on error-rate / latency change
│   └── [M] config version labelled on metrics
├── Code deploys
│   ├── [M] canary with SLO-based success criteria
│   ├── [M] automated rollback
│   └── [M] version skew tolerated (old + new replicas serve together)
└── Warm-up
    ├── why: JIT + cold caches make the first minutes slow
    ├── [S] warm-up inside Starting (synthetic requests, cache preload)
    ├── [S] LB slow-start for new replicas
    └── [M] readiness only after warm-up completes