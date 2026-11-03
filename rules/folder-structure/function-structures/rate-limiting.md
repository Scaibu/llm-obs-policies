Relying solely on external rate limiters (e.g., Redis) leaves service instances completely vulnerable to internal resource exhaustion when worker pools queue up. [Certain] Production resiliency requires local adaptive concurrency limits (load shedding) to protect individual pod event loops, combined with fleet-wide token bucket rate limiting to enforce tenant fairness.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Inbound Protection Pipeline

```
protectInbound(context, request) → proceed | reject                         ⚙
├── loadShedding (local instance safety)
│   ├── adaptiveConcurrencyLimit() → maxInflight   (gradient / Vegas latency algorithm)
│   ├── currentInflight ≥ maxInflight → shedByPriority(lowest first) ⚠ 503 Service Unavailable
│   └── queueWaitDuration > context.Deadline() → reject early        ⚠ 504 Gateway Timeout
├── rateLimiting (fleet-wide fairness)
│   ├── resolveKey(principal) → tenantId | userId | callingService
│   ├── resolvePolicy(key, operation.rateClass) → quotaTokens
│   ├── check(quotaTokens) → allowed               (local token bucket, periodic cluster sync)
│   └── exceeded                                                    ⚠ 429 Too Many Requests
└── priority(request) → critical | normal | background
    └── health probes and critical tenant operations are NEVER load-shed
```

---

## 2. Dynamic Priority Load Shedding

```
classifyPriority(request) → PriorityLevel                                   ▶
├── Priority 0 (Critical): Liveness/Readiness probes, auth handshakes, payment completions
├── Priority 1 (Normal): User-facing interactive reads and writes
└── Priority 2 (Background): Bulk analytics, exports, background reconciliations
```

When local p99 latency spikes above the adaptive threshold, Priority 2 requests are immediately shed with HTTP 503 (`Retry-After: 5`), preserving CPU and database connections for Priority 0 and 1.

---

## 3. Strict Rate Limiting Invariants

1. **Mandatory `Retry-After` Header**: Every HTTP 429 (Rate Limited) and HTTP 503 (Load Shed) response must emit a valid `Retry-After: <seconds>` header computed from token bucket replenishment or load cooldown.
2. **Local Token Bucket Caching**: Rate limiting checks must evaluate against local in-memory token buckets synchronized asynchronously to avoid placing Redis on the synchronous hot path of every request.
3. **Immunity for Health Probes**: Health check endpoints (`/health/live`, `/health/ready`) must never pass through rate limiters or priority shedding logic.

