# Parameter Specification: `x-cache-hit`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-cache-hit` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 9111 HTTP Caching / Surrogate-Control Header / CDN Cache Status Convention | 'false') |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Explicitly declares whether the response was served from cache (including idempotency replay) or freshly computed by the backend.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-cache-hit
in: header
required: false
schema:
  type: string
  pattern: "^(true|false)$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-cache-hit = "true" / "false"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF a response was returned from an idempotency cache replay or HTTP cache hit, the server MUST set `x-cache-hit: true`.
2. Otherwise the server MUST set `x-cache-hit: false`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Response served from cache or idempotency replay | `was_cached == true` | `true` | Inject header |
| Response freshly computed | `was_cached == false` | `false` | Inject header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
was_cached ? "true" : "false"
```

---

### 7. Failure & Security Enforcement
- Mandatory 'true' when replaying idempotent mutation responses.
- Useful for cache debugging and performance analysis.

---

### 8. Protocol Wire Example

```http
x-cache-hit: false
```
