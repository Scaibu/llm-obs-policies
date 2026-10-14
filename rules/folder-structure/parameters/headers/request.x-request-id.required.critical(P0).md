# Parameter Specification: `x-request-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-request-id` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 4122 UUIDv7 / req-{unix_ms}-{random_hex} |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Unique execution identifier bound to a single HTTP exchange. Ingested at ingress or deterministically assigned if absent. Echoed in response header x-request-id and meta.requestId.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-request-id
in: header
required: true
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{16,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-request-id   = 16*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST extract `x-request-id` from the inbound request headers.
2. The server SHALL validate that the identifier consists exclusively of alphanumeric characters, dashes, or underscores, within 16 to 64 characters.
3. IF conforming, the server MUST preserve the client-submitted identifier.
4. IF absent, empty, or non-conforming, the server MUST assign a fresh generated identifier.
5. The server MUST bind `x-request-id` to the execution context and echo it in both response header `x-request-id` and `meta.requestId`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Matches allowed character set and length 16..64 | `raw.matches('^[a-zA-Z0-9_-]{16,64}$') == true` | `Trim(raw)` | Bind to context and meta.requestId |
| Header absent, empty, or whitespace | `raw == null || raw.trim() == ''` | `fallback_request_id` | Inject fallback identifier |
| Non-conforming characters or invalid length | `regex match fails` | `fallback_request_id` | Discard malformed value, use fallback |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-request-id"]) && request.headers["x-request-id"].matches("^[a-zA-Z0-9_-]{16,64}$")
  ? request.headers["x-request-id"].trim()
  : fallback_request_id
```

---

### 7. Failure & Security Enforcement
- Must be present in every single HTTP response header and meta block.
- Audit records and server diagnostics must link directly to this identifier.
- No PII or user-sensitive data may be embedded in request IDs.

---

### 8. Protocol Wire Example

```http
x-request-id: req-1700000000000-a1b2c3
```
