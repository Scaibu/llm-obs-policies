Targets
├── why: every limit, timeout, and pool size is a guess without them
│
├── SLOs per route class
│   ├── DECIDE: route classes (e.g. critical-read / write / bulk / streaming)
│   ├── per class
│   │   ├── availability target   (e.g. 99.9% of valid requests non-5xx)
│   │   ├── latency target        (e.g. 99% under T ms)
│   │   ├── SLI definition        (what counts: exclude 4xx? exclude sheds?)
│   │   └── measurement point     (LB logs vs server metrics — must pick one)
│   └── error budget = 1 − availability target over the window
│
├── Capacity model
│   ├── inputs
│   │   ├── peak rps per route class (+ growth assumption)
│   │   ├── latency p50 / p99 per route class
│   │   ├── per-request CPU and memory cost (from load tests)
│   │   └── upstream capacity limits
│   ├── derivations
│   │   ├── in-flight per replica = rps × mean latency  (Little's Law)
│   │   ├── admission limit = in-flight × headroom
│   │   ├── replica count = peak rps / safe per-replica rps
│   │   ├── outbound pool sizes = per-upstream rps × upstream latency
│   │   └── drain deadline = p99.9 latency of the longest normal route
│   └── [M] each config value records which derivation produced it
│
└── Review loop
    ├── [M] re-derive after any significant latency or traffic change
    └── emit: actual vs modelled in-flight per replica