Concurrency Model
├── [M] every pool and queue bounded
│
├── Admission limit
│   ├── basis: Little's Law  L = λ × W
│   │   └── e.g. 2,000 req/s × 0.05 s = 100 in flight
│   ├── phase 1: static limit = L × headroom (≈1.5)
│   ├── phase 2 [O]: adaptive (gradient / AIMD on observed latency)
│   │   └── latency up ⇒ limit down; latency recovers ⇒ limit grows slowly
│   └── emit: admission_limit, inflight, admission_rejections_total
│
├── Priority classes
│   ├── e.g. critical / normal / best-effort
│   ├── separate concurrency per class
│   └── shed order: best-effort → normal → critical
│
├── Queue
│   ├── [M] bounded size AND bounded time in queue
│   ├── [M] drop if wait ≥ remaining deadline — never execute late
│   ├── normal load: FIFO
│   ├── sustained overload [S]: LIFO + CoDel-style queue-time check
│   └── emit: queue_depth, queue_wait (histogram), queue_dropped_total
│
├── Thread / worker separation
│   ├── accept + parse ... never blocks
│   ├── handlers ......... bounded worker pool or async tasks
│   └── blocking I/O ..... dedicated bounded pool
│
└── Admin server
    ├── separate small pool
    ├── own low limits
    └── unaffected by public overload