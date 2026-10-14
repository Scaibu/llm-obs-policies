# Parameter Specification: `meta.executionTimeMs`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.executionTimeMs` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | OpenAPI 3.1 / JSON Schema 2020-12 / W3C Server Timing / IETF RFC 7234 |
| **Schema Type** | `integer` |

---

### 1. Architectural Purpose & Scope
Server-side execution time in milliseconds, measured from request receipt at gateway ingress to response serialization completion. Excludes network transit latency (client RTT). Provides the authoritative server-side latency baseline for SLA enforcement, performance regression alerting, and client-side timeout calibration.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: meta.executionTimeMs
in: body  # JSON body field — not a header parameter
required: true
schema:
  type: integer
  minimum: 0
  maximum: 300000
  description: "Elapsed server-side processing time in milliseconds. Excludes network transit."
  examples:
    - 14
    - 342
    - 5001
```

> **Note:** `pattern` is a string-only constraint in JSON Schema 2020-12. Integer fields MUST use `minimum`/`maximum` bounds, not `pattern`.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
executionTimeMs = 1*DIGIT
```

> Value range: `0` ≤ `executionTimeMs` ≤ `300000` (5-minute hard ceiling; exceeding this indicates a gateway timeout should have fired).

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST record `start_epoch_ms` at the moment the gateway receives the first byte of the HTTP request.
2. The server MUST record `completion_epoch_ms` at the moment the response payload is fully serialized and queued for transmission.
3. The server MUST compute `executionTimeMs = max(0, completion_epoch_ms - start_epoch_ms)`.
4. The server MUST inject the computed value into `meta.executionTimeMs` before transmitting the response.
5. The value MUST be a non-negative integer; negative values are forbidden.
6. IF the gateway applies a timeout and returns HTTP 504, the partial elapsed time at point of abort SHOULD be included.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Successful or error response, timing available | `completion >= start` | `completion_epoch_ms - start_epoch_ms` | Inject into `meta.executionTimeMs` |
| Clock skew produces negative delta | `completion < start` | `0` | Log anomaly; emit `0` as safe floor |
| Gateway timeout fires before completion | `timeout_fired == true` | `elapsed_at_timeout` | Include partial duration for diagnostics |
| Timer not initialised (edge bug) | `start_epoch_ms == null` | `null` | Omit field; log critical instrumentation error |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
start_epoch_ms != null
  ? max(0, completion_epoch_ms - start_epoch_ms)
  : null
```

---

### 7. Failure & Security Enforcement
- A negative or `null` value MUST be treated as a critical instrumentation defect and trigger an alerting event.
- The value MUST NOT be manipulated post-computation; it is a tamper-evident SLA signal.
- Enables clients to distinguish server-side latency from network transit delay for accurate SLA accounting.
- Crucial metric for P95/P99 latency tracking and performance regression detection in APM tooling (OpenTelemetry, Prometheus histogram).
- If `executionTimeMs` consistently exceeds the agreed SLA budget, the API gateway MUST trigger circuit-breaker escalation.

---

### 8. Protocol Wire Example

```json
{
  "meta": {
    "executionTimeMs": 14
  }
}
```
