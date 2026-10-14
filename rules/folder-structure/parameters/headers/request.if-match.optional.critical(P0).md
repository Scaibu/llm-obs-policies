# Parameter Specification: `If-Match`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `If-Match` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional (Conditionally Mandatory on Versioned Mutations)** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 HTTP Semantics ETag / Strong Entity Tag |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Optimistic concurrency control token. Ensures updates are only applied if caller's view matches the current server state, eliminating lost-update race conditions.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: If-Match
in: header
required: false
schema:
  type: string
  pattern: "^"[a-zA-Z0-9_-]+"$|^\*$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
If-Match = entity-tag / "*"
entity-tag = [ "W/" ] DQUOTE 1*( VCHAR ) DQUOTE
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST require `If-Match` on mutations targeting versioned entities.
2. IF missing on a versioned entity mutation, the server MUST reject with HTTP 428 PRECONDITION_REQUIRED.
3. The server SHALL compare the header against the current persistent entity ETag.
4. IF values differ and header is not `*`, the server MUST reject with HTTP 412 PRECONDITION_FAILED.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Non-versioned entity mutation | `!is_versioned` | `PROCEED` | Bypass OCC check |
| Versioned mutation without If-Match | `is_versioned && raw == null` | `ERROR 428` | Reject with PRECONDITION_REQUIRED |
| If-Match matches current entity ETag or '*' | `raw == '*' || raw == current_etag` | `PROCEED` | Allow mutation to proceed |
| If-Match differs from current ETag | `raw != current_etag` | `ERROR 412` | Reject with PRECONDITION_FAILED |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!is_versioned
  ? "PROCEED"
  : !has(request.headers["if-match"])
    ? "ERROR_PRECONDITION_REQUIRED"
    : (request.headers["if-match"] == "*" || request.headers["if-match"] == current_etag)
      ? "PROCEED"
      : "ERROR_PRECONDITION_FAILED"
```

---

### 7. Failure & Security Enforcement
- Enforces OCC on all update operations.
- Server must return new ETag header in successful response.
- If a request omits `If-Match` on a mutating endpoint that declared it mandatory, reject with HTTP 428 PRECONDITION_REQUIRED.
- `If-Match: *` (wildcard) MUST be rejected on DELETE — it bypasses ETag-based conflict protection and could delete any version of a resource.
---

### 8. Protocol Wire Example

```http
If-Match: "018f6e2c-etag-rev3"
```
