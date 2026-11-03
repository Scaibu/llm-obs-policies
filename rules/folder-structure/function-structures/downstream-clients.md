The most frequent cascading platform failures stem from raw, un-resilient HTTP/gRPC clients that lack deadline propagation, circuit breakers, or retry budgets. [Certain] When a downstream service degrades, callers without timeouts or bulkheads pile up waiting goroutines, exhaust connection pools, and knock down the entire upstream fleet in a self-inflicted retry storm.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis
  ↺  registers cleanup
```

---

## 1. Outbound Downstream Client Execution Flow

```
clients.service.execute(context, input) → result                           ⚙
├── computeDeadline(context.deadline, operationTimeout, margin) → deadline
│   └── no time left → ⚠ fail fast immediately, do not execute network call
├── checkCircuit(dependency) → closed | open                       ⚠ open → fail fast (HTTP 503)
├── acquireBulkhead(dependency) → permit                           ⚠ full → fail fast (HTTP 429)
├── resolveEndpoint(discovery, loadBalancer) → endpoint
├── attachHeaders()
│   ├── traceparent, x-request-id, x-correlation-id, x-tenant-id
│   └── x-idempotency-key (mandatory on all mutating POST / PUT / PATCH / DELETE calls)
├── send(endpoint, input, deadline) → rawResponse
├── classify(rawResponse) → success | retryable | permanent
├── retryIf(retryable AND operation idempotent
│           AND retryBudget available AND deadline left)
│   └── exponential backoff with full jitter, alternate replica endpoint
├── recordOutcome(circuit, metrics, latency)                       ⚙
├── releaseBulkhead(permit)                                        ⚙ ↺
└── mapToDomainError(rawResponse) → domainError                    ▶
```

---

## 2. Resiliency Components: Circuit Breaker & Bulkhead

```
resiliencyChassis()                                                         ⚙
├── CircuitBreaker
│   ├── State: CLOSED (normal) → OPEN (tripped on error rate > 50%) → HALF_OPEN (probe)
│   └── Tripped state short-circuits calls without socket allocation
├── Bulkhead
│   ├── Concurrency clamp per downstream dependency (e.g. max 50 concurrent in-flight)
│   └── Prevents one sluggish dependency from starving memory or worker threads
└── RetryBudget
    ├── Token bucket allocating max 10% retries relative to total outbound traffic
    └── Prevents retry storms against failing downstream services
```

---

## 3. Strict Downstream Client Invariants

1. **Mandatory Deadline Budgeting**: Never initiate a network call if `context.Deadline() - margin < connect_timeout`. Failing fast preserves resources when the parent client has already disconnected.
2. **Deterministic Idempotency on Mutations**: All mutating calls (`POST`, `PUT`, `PATCH`, `DELETE`) must carry a deterministic `x-idempotency-key` derived from domain entities (e.g. `hash(order_id + step_name)`). Random UUIDs per retry are strictly prohibited.
3. **No Retries on Non-Idempotent Endpoints**: Retries are only permissible if the operation is explicitly declared idempotent. Blindly retrying non-idempotent operations causes duplicate charges and double processing.

