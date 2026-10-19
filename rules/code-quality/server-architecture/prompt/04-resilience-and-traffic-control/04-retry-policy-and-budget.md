---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_RETRY_POLICY_CREATION"
agent_role: "Principal Systems Reliability Architect & Traffic Explosion Auditor"
target_scope: "Retries, Retry Budgets, Exponential Backoff, Jitter & Retry Layering"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Retry Policy and Retry Budget Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Idempotency Precondition for Retries
Retries MUST NEVER be attempted for non-idempotent operations (`POST`, non-idempotent `PATCH`) unless a verified `x-idempotency-key` is present. Retrying a blind `POST` that failed with a timeout risks duplicate state mutation (e.g. double charging).

Guardrail 2: Global Retry Budget Invariant (Max 10-20%)
Unbounded retries cause catastrophic retry storms (e.g. 3 retries across 3 tiers = $3^3 = 27\times$ load amplification). Every client MUST enforce a strict retry budget: retries MUST NOT exceed 20% of total outbound requests over a sliding window. Once the budget is exhausted, the client MUST return the original failure immediately without retrying.

Guardrail 3: Single-Layer Retry Ownership
Retries MUST be executed at **exactly one layer** along any call path. If the service mesh / Envoy proxy is configured to retry, client application libraries MUST NOT retry. Nested retries across multiple architectural layers are strictly prohibited.

Guardrail 4: Full Jitter Exponential Backoff
All retry backoff calculations MUST use full jitter:
$\text{Sleep} = \text{random}(0, \min(\text{max\_backoff}, \text{base\_backoff} \times 2^{\text{attempt}}))$.
Plain deterministic backoff without jitter (which causes synchronized thundering herds) is strictly forbidden. If an upstream response includes a `Retry-After` header, it MUST override the computed backoff.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside retry wrappers. Document the backoff formulas and budget mechanics in the file header docblock.

---

## 2. Retry Policy Contract

```yaml
retry_contract:
  eligible_status_codes: [408, 425, 429, 503, 504]
  eligible_network_errors: ["ECONNREFUSED", "ECONNRESET", "REFUSED_STREAM"]
  ineligible_status_codes: [400, 401, 403, 404, 409, 422]
  budget:
    max_retry_ratio: 0.20 # Max 20% of traffic
    sliding_window_seconds: 60
    min_retries_per_sec_floor: 5
  backoff:
    algorithm: "FULL_JITTER"
    base_backoff_ms: 50
    max_backoff_ms: 2000
    max_attempts: 3
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Retry Storm Cascade Fix**: When downstream service is struggling and returns 503, the retry budget tracks the error spike. When retries exceed 20% of requests, budget turns `EXHAUSTED`, halting further retry storms and allowing downstream to recover.
2. **Premature Retry on Expired Deadline Fix**: Before executing retry attempt $N$, check if `remaining_context_deadline < expected_attempt_duration`. If true, abort retry immediately with `DEADLINE_EXCEEDED`.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Inspect Error Code Before Retrying
Check whether the status code is in `eligible_status_codes` and ensure the request method is idempotent (`GET`, `PUT`, `DELETE`, `HEAD`) before scheduling a retry.

### Instruction 2: Attach Metrics
Increment `retries_total{upstream, attempt, result="success|failed|budget_exhausted"}` on every attempt.
