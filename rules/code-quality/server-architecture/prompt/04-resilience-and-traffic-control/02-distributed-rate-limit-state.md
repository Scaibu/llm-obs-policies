---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_RATE_LIMITER_CREATION"
agent_role: "Principal Distributed Systems Architect & Quota Governance Officer"
target_scope: "Fleet-Wide Rate Limiting, GCRA / Token Bucket, Redis State, Fail-Open vs Fail-Closed"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Distributed Rate-Limit State Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Local vs Global Rate Limit Separation
- **Stage 6 Pre-Auth Abuse Limits**: MUST execute purely locally per replica (no external network hop) to defend against IP volumetric flooding and credential stuffing.
- **Stage 9 Contractual Tenant Quotas**: MUST execute against a centralized distributed counter store (Redis) to ensure accurate fleet-wide quotas regardless of horizontal pod autoscaling.

Guardrail 2: Single Algorithm Consistency (GCRA / Token Bucket)
All rate limiters MUST use the Generic Cell Rate Algorithm (GCRA) or Token Bucket. GCRA is strongly preferred in distributed key-value stores because it tracks only one key/timestamp per client rather than managing multi-field hashes or locks.

Guardrail 3: Explicit Store Outage Strategy (Fail-Open vs Fail-Closed)
Calls to the shared rate-limit store MUST be bounded by a 15ms timeout and wrapped with a circuit breaker.
- **Abuse Protection Limits**: MUST fail-open with a degraded local fallback bucket if Redis fails.
- **Monetized Paid Quotas**: MUST fail-closed or throttle to a strict safe local floor to prevent unpaid resource abuse.

Guardrail 4: Standard RFC Signaling Headers
Every rate-limit rejection MUST return HTTP 429 Too Many Requests and include:
- `Retry-After: <seconds>` (RFC 6585).
- `RateLimit-Limit`, `RateLimit-Remaining`, and `RateLimit-Reset` headers.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside rate-limiting algorithms. Document the GCRA mathematical calculation in the file header docblock.

---

## 2. Rate-Limiting Contract

```yaml
rate_limiting_contract:
  local_pre_auth:
    algorithm: "TOKEN_BUCKET"
    capacity: 100
    refill_rate_per_sec: 20
    store: "IN_MEMORY_LRU"
  global_tenant_quota:
    algorithm: "GCRA"
    emission_interval_ms: 100
    burst_tolerance_ms: 2000
    store: "REDIS_CLUSTER"
    timeout_ms: 15
    on_store_failure: "FAIL_OPEN_LOCAL_FALLBACK"
  signaling:
    status_code: 429
    retry_after_unit: "seconds"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Redis Latency Spike Bottleneck Fix**: Wrap Redis GCRA evaluation with a strict 15ms deadline. If Redis times out, fallback to an in-memory local leaky bucket and emit `ratelimit_store_fallback_total`.
2. **Horizontal Autoscaling Token Drift Fix**: Never hardcode local per-pod limits for tenant contracts. Derive local quotas dynamically: $\text{Per-Pod Limit} = \frac{\text{Global Quota}}{\max(\text{Active Replicas}, 1)}$.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Atomic GCRA Redis Scripting
Execute distributed GCRA using a single atomic Redis Lua script or Redis Cell module to eliminate round-trip concurrency race conditions.

### Instruction 2: Standard Headers
Always attach `Retry-After` on all 429 responses.
