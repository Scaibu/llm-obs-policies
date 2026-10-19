---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_CIRCUIT_BREAKER_CREATION"
agent_role: "Principal Reliability Engineer & Fault Tolerance Auditor"
target_scope: "Circuit Breakers, Outlier Ejection, Bulkheads, Slow Dependency Protection & Fallbacks"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Circuit Breaking and Outlier Ejection Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Three-State Circuit Breaker Invariant
Every outbound client calling an external dependency MUST implement a three-state circuit breaker:
- `CLOSED`: Normal operation; tracking error rates and latency.
- `OPEN`: Fail fast immediately locally without making external network calls; returns HTTP 503 + `Retry-After`.
- `HALF_OPEN`: Trial state allowing limited probe requests to verify downstream health before closing or reopening.

Guardrail 2: Latency-Based Trip Condition ("Slow is Down")
Breakers MUST NOT trip solely on HTTP 5xx errors. Breakers MUST monitor P99 latency: if downstream P99 latency exceeds the SLA threshold over a sliding window, the breaker MUST trip to `OPEN` to prevent worker thread pool exhaustion.

Guardrail 3: Outlier Ejection Cap Invariant
Outlier detection (ejecting bad backend instances based on consecutive failures or high latency) MUST NEVER eject more than 50% of the instance pool. If the entire pool degrades, traffic MUST be distributed across all instances rather than concentrating 100% of load onto 1 node.

Guardrail 4: Per-Upstream Bulkheads
Every external dependency client MUST be bounded by an independent concurrency semaphore (bulkhead). A slow or failing dependency MUST NEVER consume more than its allocated slice of application worker threads.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside circuit breaker logic. Document the state transition thresholds in the file header docblock.

---

## 2. Circuit Breaker & Ejection Contract

```yaml
resilience_contract:
  circuit_breaker:
    failure_rate_threshold: 0.50 # 50%
    latency_p99_threshold_ms: 1000
    sliding_window_seconds: 10
    minimum_requests_in_window: 20
    open_duration_seconds: 5
    open_jitter_ratio: 0.20
    half_open_probes: 3
  outlier_ejection:
    consecutive_5xx_threshold: 5
    base_ejection_seconds: 30
    max_ejected_percentage: 50
  bulkheads:
    max_concurrent_calls_per_upstream: 50
    queue_capacity: 10
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Slow Dependency Thread Pool Exhaustion Fix**: Set `latency_p99_threshold_ms: 1000`. When downstream database or external API slows down, the breaker trips to `OPEN`, immediately shielding application workers from getting trapped in pending I/O.
2. **Total Fleet Ejection Thundering Herd Fix**: Enforce `max_ejected_percentage: 50`. Even if all instances trigger consecutive failures, 50% remain active, avoiding cascading cluster failure.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Call Downstream When Breaker is Open
Ensure the client wrapper checks `breaker.state == OPEN` and raises an immediate `DownstreamCircuitOpenError` before allocating any socket.

### Instruction 2: Instrument State Transitions
Emit `breaker_transitions_total{upstream, from_state, to_state}` on every state change.
