Autoscaling
├── why: CPU stays low on I/O-bound routers while queues build
│
├── Signal
│   ├── [S] primary: in-flight requests per replica vs admission limit
│   ├── [S] secondary: queue wait p95
│   ├── [O] CPU only as a guard for CPU-bound routes
│   └── DECIDE: target utilization  [Guessing: 60–70% of admission limit]
│
├── Scale-up
│   ├── [M] fast reaction (short window)
│   ├── [M] new replicas use LB slow-start / warm-up (tree 21)
│   └── [M] max replicas bounded by upstream capacity, not just budget
│
├── Scale-down
│   ├── [M] slow reaction (long stabilization window)
│   ├── [M] every removal follows the full drain sequence
│   └── why: flapping causes repeated drains and connection churn
│
└── Interaction with other limits
    ├── local rate limits change effective value when replicas change (tree 6)
    └── connection age forces rebalancing onto new replicas