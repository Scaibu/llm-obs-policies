# Parameter Specification: `x-correlation-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-correlation-id` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 4122 UUIDv4 / UUIDv7 (IETF draft-peabody-dispatch-new-uuid-format) / Distributed Tracing Correlation Pattern |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Echoes the business transaction correlation identifier. Exactly matches meta.correlationId in the response envelope.

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

1. The server MUST echo the resolved `correlation_id` in response header `x-correlation-id` on every HTTP response.
2. The value MUST exactly match `meta.correlationId` in the JSON response envelope.
3. IF the inbound request provided a `x-correlation-id`, the server MUST propagate the identical value unchanged.
4. IF the inbound request lacked a `x-correlation-id`, the server MUST use the resolved `x-request-id` as the correlation boundary.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Inbound request provided x-correlation-id | `has(request_correlation_id)` | `request_correlation_id` | Echo unchanged; mirror in meta.correlationId |
| Inbound request lacked x-correlation-id | `!has(request_correlation_id)` | `resolved_request_id` | Use request-id as correlation root |
| response.meta.correlationId does not match header | `meta_val != header_val` | `ERROR_MISMATCH` | Log critical contract integrity defect |


---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request_correlation_id)
  ? request_correlation_id
  : resolved_request_id
```

---

### 7. Failure & Security Enforcement
- Must be present on all responses.
- Enables tracking end-to-end multi-step flows across services.
- Correlation ID MUST be included on ALL responses (success and error) — omission on error responses breaks distributed tracing chains.
- Correlation IDs MUST NOT contain PII — they are transmitted to logging pipelines and may be stored for extended retention periods.
---

### 8. Protocol Wire Example

```http
x-correlation-id: corr-1700000000000-x9y8z7
```
