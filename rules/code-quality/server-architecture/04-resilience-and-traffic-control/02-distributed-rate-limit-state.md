Rate Limiting at Fleet Level
├── why: local limits multiply by replica count and drift with autoscaling
│
├── Per limit: DECIDE local or global
│   ├── Local
│   │   ├── per-replica limit = fleet limit / replica count (recomputed)
│   │   ├── + no dependency, no latency
│   │   ├── − approximate; skewed by uneven LB distribution
│   │   └── use for: pre-auth abuse protection (stage 6)
│   └── Global
│       ├── shared counter store
│       ├── + accurate fleet-wide limits
│       ├── − extra hop latency, new dependency, hot keys
│       └── use for: paid quotas, contractual tenant limits (stage 9)
│
├── Algorithm
│   ├── DECIDE: token bucket or GCRA (Generic Cell Rate Algorithm)
│   ├── [S] GCRA: one timestamp per key, cheap in shared stores
│   └── [M] same algorithm everywhere a limit is enforced
│
├── Failure of the shared store
│   ├── DECIDE per limit: fail open or fail closed
│   │   ├── abuse protection ⇒ fail open + local fallback limit
│   │   └── paid / contractual ⇒ fail closed or fail to a strict local limit
│   ├── [M] store call has its own short timeout + breaker
│   └── emit: ratelimit_store_errors_total, ratelimit_fallback_active
│
├── Hybrid [O]
│   └── local token cache leased from the global store in batches
│
└── Client signalling
    ├── [M] 429 + Retry-After
    └── [S] RateLimit / RateLimit-Policy headers (IETF draft, not yet RFC)