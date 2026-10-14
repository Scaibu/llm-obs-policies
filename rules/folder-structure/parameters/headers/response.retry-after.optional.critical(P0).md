# Parameter Specification: `Retry-After`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Retry-After` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional (Conditionally Mandatory on HTTP 429 and 503)** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 Seconds Integer or HTTP-Date |
| **Schema Type** | `integer` |

---

### 1. Architectural Purpose & Scope
Instructs client exactly how many seconds it must wait before retrying the failed request. Crucial for circuit breaking and overload shedding.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Retry-After
in: header
required: false
schema:
  type: integer
  minimum: 0
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Retry-After = 1*DIGIT / HTTP-date
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. When returning HTTP 429 Too Many Requests, the server MUST include `Retry-After` specifying the seconds until quota resets.
2. When returning HTTP 503 Service Unavailable, the server MUST include `Retry-After` to direct clients away from the overloaded instance.
3. The server MUST prefer seconds-based integer format (delta-seconds) over HTTP-date format for machine-readable back-off.
4. IF the server cannot determine a precise reset time, it MUST use a safe default of 60 seconds — it MUST NOT omit the header.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Status is 429 or 503 with retry delay | `status_code in [429, 503] && retry_delay != null` | `string(retry_delay)` | Inject header |
| Other status codes | `!(status_code in [429, 503])` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
status_code in [429, 503] && retry_delay != null ? string(retry_delay) : null
```

---

### 7. Failure & Security Enforcement
- Must be respected by all SDK retry engines and backoff handlers.
- Prevents thundering-herd retry storms against overloaded backends.
- Clients MUST NOT retry before the `Retry-After` window expires — repeated violations MUST trigger exponential back-off with jitter on the client side.
- The server MUST NOT return `Retry-After: 0` on 429 — a zero value signals immediate retry and defeats the rate-limiting mechanism.
---

### 8. Protocol Wire Example

```http
Retry-After: 30
```
