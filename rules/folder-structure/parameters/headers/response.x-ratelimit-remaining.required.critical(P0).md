# Parameter Specification: `X-RateLimit-Remaining`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `X-RateLimit-Remaining` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on All Responses** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | IETF draft-polli-ratelimit-headers-02 / RFC 6585 §4 (429 Too Many Requests) / HTTP Rate Limiting |
| **Schema Type** | `integer` |

---

### 1. Architectural Purpose & Scope
Communicates remaining request budget remaining in the current sliding window.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: X-RateLimit-Remaining
in: header
required: true
schema:
  type: integer
  minimum: 0
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
X-RateLimit-Remaining = 1*DIGIT
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST compute remaining budget as `max(0, limit - consumed)` at time of response.
2. The server MUST inject `X-RateLimit-Remaining` on every HTTP response, including 429 responses.
3. When quota is exhausted, the value MUST be `0` — negative values are forbidden.
4. The remaining count MUST be decremented atomically to prevent race conditions in concurrent-request scenarios.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Quota remaining >= 0 | `rate_quota.remaining >= 0` | `string(rate_quota.remaining)` | Inject header |
| Quota exhausted | `rate_quota.remaining < 0` | `0` | Inject 0 |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
string(rate_quota.remaining >= 0 ? rate_quota.remaining : 0)
```

---

### 7. Failure & Security Enforcement
- Reaching 0 signals imminent 429 Too Many Requests rejection.
- Allows smart clients to proactively back off.
- The remaining count MUST be decremented atomically (e.g., Redis DECRBY in a transaction) — non-atomic decrement allows quota over-consumption under concurrency.
- Clients observing `X-RateLimit-Remaining: 0` MUST stop issuing requests and wait for `X-RateLimit-Reset` before retrying.
---

### 8. Protocol Wire Example

```http
X-RateLimit-Remaining: 994
```
