---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_SLO_OR_CAPACITY_PLANNING"
agent_role: "Principal Reliability Architect & Capacity Planning Officer"
target_scope: "Service Level Objectives (SLOs), Service Level Indicators (SLIs), Error Budgets & Little's Law"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# SLOs and Capacity Model Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Route-Class SLO Decomposition Invariant
Every HTTP/gRPC route MUST belong to a declared route class (e.g. `Critical Read`, `Mutating Write`, `Batch/Async`, `Streaming/SSE`). Every route class MUST define:
1. **Availability Target**: e.g. 99.9% of valid non-client-error requests return non-5xx.
2. **Latency Target**: e.g. P99 latency $< 150\text{ms}$.
3. **Error Budget**: $1 - \text{Availability Target}$ over a rolling 30-day window.

Guardrail 2: Deterministic Capacity Derivations
Every configuration parameter for pools, timeouts, and limits MUST document which mathematical derivation produced it:
- **In-flight Concurrency per Pod**: Derived via Little's Law: $L = \text{Peak RPS} \times \text{Mean Latency (s)}$.
- **Admission Limit**: $L \times 1.5 \text{ (Headroom Margin)}$.
- **Replica Count**: $\lceil \frac{\text{Global Peak RPS}}{\text{Safe Per-Pod RPS}} \rceil$.
- **Drain Deadline**: Set to the P99.9 latency of the longest-running non-streaming route.

Guardrail 3: Zero Inline Comments Doctrine
Never write mid-function inline comments inside capacity math calculations. Document the SLI and Little's Law formulas in the file header docblock.

---

## 2. Capacity Model Contract

```yaml
capacity_model_contract:
  route_classes:
    critical_read:
      availability_target: 0.999 # 99.9%
      latency_p99_target_ms: 100
      slis_exclude: ["4xx", "admission_sheds"]
    mutating_write:
      availability_target: 0.9995
      latency_p99_target_ms: 250
      slis_exclude: ["4xx"]
    streaming:
      availability_target: 0.99
      latency_ttfb_p95_target_ms: 200
  derivations:
    headroom_multiplier: 1.5
    drain_deadline_quantile: "P99_9"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Uncalibrated Admission Crash Fix**: Do not guess `max_concurrent_requests: 10000`. Calculate Little's Law: if peak traffic is 500 RPS with 50ms average duration, $L = 500 \times 0.05 = 25$. Set admission limit to $25 \times 1.5 = 38$ requests per pod.
2. **Premature Drain Deadline Kill Fix**: If the slowest mutating route has a P99.9 latency of 12 seconds, setting `drain_deadline: 5s` causes dropped mutations during rolling deploys. Enforce `drain_deadline \ge 12s + 3s`.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Cross-Reference Config with Derivation Formats
Assert that timeouts and connection pool limits match the route class SLO targets.

### Instruction 2: Tag Route Class in Span Attributes
Ensure handlers record `route_class="critical_read|mutating_write"` on the active OpenTelemetry span.
