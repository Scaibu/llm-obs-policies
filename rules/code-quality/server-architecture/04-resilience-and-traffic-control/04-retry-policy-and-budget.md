Retries
├── why: retries multiply per layer (3 layers × 3 tries = 27× load)
│
├── Eligibility
│   ├── [M] idempotent methods (RFC 9110 §9.2.2) OR idempotency key present
│   ├── [M] retry-safe signals
│   │   ├── connection refused / reset before request sent
│   │   ├── HTTP/2 REFUSED_STREAM / GOAWAY above last stream ID
│   │   ├── 503 / 429 with Retry-After
│   │   └── gRPC UNAVAILABLE
│   ├── [M] never retry
│   │   ├── 4xx other than 408 / 425 / 429
│   │   ├── non-idempotent request that may have been processed
│   │   └── remaining deadline < expected attempt duration
│   └── DECIDE: retry on timeout? only if idempotent + budget available
│
├── Budget (the critical part)
│   ├── [M] retries ≤ X% of requests per upstream over a sliding window
│   │   └── DECIDE X  [Guessing: 10–20% is a common starting point]
│   ├── [S] minimum retries/sec floor so low traffic can still retry
│   ├── [M] budget exhausted ⇒ return the original failure, no retry
│   └── emit: retry_budget_remaining{upstream}, retries_total{result}
│
├── Backoff
│   ├── [M] exponential with full jitter
│   ├── [M] capped maximum delay
│   └── [M] Retry-After overrides computed backoff
│
├── Layering rule
│   ├── [M] retry at exactly one layer per call path
│   └── DECIDE: which layer owns retries (router or client library or mesh)
│
└── Hedging [O]
    ├── send second request after p95 latency, cancel the loser
    ├── [M] idempotent only, counted against the retry budget
    └── DECIDE: needed at all? (adds load; use only for tail-latency SLOs)