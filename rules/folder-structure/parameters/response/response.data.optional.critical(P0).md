# Parameter Specification: `data`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `data` |
| **Category** | `response` |
| **Surface** | Response JSON Envelope Root Field |
| **Requirement Level** | **MANDATORY on Success; FORBIDDEN on Failure** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 HTTP Semantics / JSON Schema 2020-12 (`oneOf` — object or array) |
| **Schema Type** | `object | array` |

---

### 1. Architectural Purpose & Scope
Container for domain payload. On success, holds resource object or list of objects. On failure, MUST BE OMITTED ENTIRELY.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
# data is a JSON response body field — defined under the response schema, not as a header parameter.
schema:
  oneOf:
    - type: object
      description: "Single entity payload on resource retrieval or mutation success."
      unevaluatedProperties: false
    - type: array
      description: "Collection payload on list operations."
      items:
        type: object
  description: "Domain payload container. Present on 2xx success only; MUST be absent on error responses."
```

> `data` is a root field in the JSON response envelope. On empty collections, MUST be `[]` (never `null`). On single entity success, MUST be an object. On 204 No Content, `data` MUST be omitted entirely.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
data = JSON-value
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF response is successful, the server MUST include `data` field.
2. Collections MUST return empty array `[]` when no items match, never `null`.
3. IF response is an error, the server MUST NOT include `data` key.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Success response with payload | `is_success && payload != null` | `payload` | Render data container |
| Success response on empty collection | `is_success && is_collection && size == 0` | `[]` | Render empty array (never null) |
| Failure / error response | `!is_success` | `OMITTED` | Data key must not exist |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
is_success ? (payload != null ? payload : {}) : null
```

---

### 7. Failure & Security Enforcement
- Collections must return empty array [] when no items exist, never null.
- Data key must not exist on failure responses.
- The `data` field MUST be omitted (key absent) on error responses — returning `data: null` alongside `error` creates ambiguous dual-state envelopes.
---

### 8. Protocol Wire Example

```json
"data": { "orderId": "018f6e2c-9999", "status": "CONFIRMED" }
```
