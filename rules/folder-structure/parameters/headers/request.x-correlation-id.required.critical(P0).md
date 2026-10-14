# Parameter Specification: `x-correlation-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-correlation-id` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 4122 UUIDv4 / UUIDv7 (IETF draft-peabody-dispatch-new-uuid-format) / Distributed Tracing Correlation Pattern |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Distributed business transaction identifier unifying all microservice hops, background tasks, and event messages originating from a single user transaction.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-correlation-id
in: header
required: true
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{16,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-correlation-id = 16*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST inspect inbound headers for `x-correlation-id`.
2. IF a valid identifier is present, the server MUST preserve it across all downstream hops.
3. IF absent or malformed, the server MUST inherit the active `x-request-id` as the root correlation boundary.
4. The server MUST echo the resolved correlation identifier in the response header and `meta.correlationId`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Valid format and length | `raw.matches('^[a-zA-Z0-9_-]{16,64}$') == true` | `Trim(raw)` | Propagate unchanged downstream |
| Absent or invalid format | `raw == null || match fails` | `resolved_request_id` | Initialize correlation root from request_id |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-correlation-id"]) && request.headers["x-correlation-id"].matches("^[a-zA-Z0-9_-]{16,64}$")
  ? request.headers["x-correlation-id"].trim()
  : request_id
```

---

### 7. Failure & Security Enforcement
- Correlation ID must never change across downstream service calls within the same workflow.
- Must be mirrored in response headers and meta.correlationId.
- Correlation ID MUST be immutable once assigned — no downstream hop may modify it; a change mid-chain is a critical tracing violation.
- Correlation IDs MUST NOT contain PII, user identifiers, or predictable sequential integers — use UUIDv4/v7 or a CSPRNG-derived token.
---

### 8. Protocol Wire Example

```http
x-correlation-id: corr-1700000000000-x9y8z7
```
