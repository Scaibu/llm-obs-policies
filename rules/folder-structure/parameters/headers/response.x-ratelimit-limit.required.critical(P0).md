# Parameter Specification: `X-RateLimit-Limit`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `X-RateLimit-Limit` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on All Responses** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | IETF draft-polli-ratelimit-headers-02 / RFC 6585 §4 / HTTP API Rate Limiting|
| **Schema Type** | `integer` |

---

### 1. Architectural Purpose & Scope
Communicates the maximum request budget allocated to the tenant or client IP in the current rate limit quota window.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: X-RateLimit-Limit
in: header
required: true
schema:
  type: integer
  minimum: 0
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
X-RateLimit-Limit = 1*DIGIT
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST compute the active quota ceiling for the requesting tenant or client from the rate limit registry.
2. The server MUST inject `X-RateLimit-Limit` on every HTTP response, including error responses.
3. IF the client is on a per-tenant plan, the limit MUST reflect the tenant-specific quota, not the global platform default.
4. The limit value MUST NOT change within a single quota window — it is fixed at window start.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Tenant has a custom quota plan | `tenant_quota != null` | `tenant_quota.limit` | Reflect tenant-specific ceiling |
| Default global plan applies | `tenant_quota == null` | `global_default_limit` | Reflect platform default ceiling |
| 429 response (quota exhausted) | `rate_quota.remaining <= 0` | `rate_quota.limit` | Inject limit; also set Retry-After and X-RateLimit-Reset |


---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
tenant_quota != null ? tenant_quota.limit : global_default_limit
```

---

### 7. Failure & Security Enforcement
- Informs callers of their burst and sustained throughput caps.
- Standard across API gateways.
- Rate limit headers MUST be present on 429 Too Many Requests responses — their absence prevents clients from implementing exponential back-off correctly.
- Quota values MUST NOT leak information about other tenants' plans — each client sees only its own allocated limit.
- Limit value MUST match the value returned in `X-RateLimit-Remaining` base calculation — inconsistency is a rate limit bypass vector.
---

### 8. Protocol Wire Example

```http
X-RateLimit-Limit: 1000
```
