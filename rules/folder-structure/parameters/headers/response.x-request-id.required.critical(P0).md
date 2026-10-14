# Parameter Specification: `x-request-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-request-id` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 4122 UUIDv4 / UUIDv7 / IETF draft-ietf-httpapi-request-id|
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Echoes the resolved request identifier on all outbound HTTP responses. Exactly matches meta.requestId in the response envelope.

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
x-request-id = 16*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST echo the resolved `request_id` in response header `x-request-id` on every HTTP response.
2. The value MUST exactly match `meta.requestId` in the JSON response envelope.
3. IF the inbound request provided a valid `x-request-id`, the server MUST echo the identical value unchanged.
4. IF the inbound request lacked a valid `x-request-id`, the server MUST echo the server-generated UUID that was assigned during ingress processing.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Client provided valid x-request-id | `has(client_request_id) && valid_format` | `client_request_id` | Echo; mirror in meta.requestId |
| Client provided invalid/missing x-request-id | `!has(client_request_id) || !valid_format` | `server_generated_uuid` | Inject server UUID; mirror in meta.requestId |
| meta.requestId does not match header value | `meta_val != header_val` | `ERROR_MISMATCH` | Log critical contract integrity defect |


---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-request-id"]) && request.headers["x-request-id"].matches("^[a-zA-Z0-9_-]{16,64}$")
  ? request.headers["x-request-id"]
  : server_generated_request_id
```

---

### 7. Failure & Security Enforcement
- Must be included in all success and failure responses.
- Crucial for client-side debugging and correlating support tickets.
- Request IDs MUST be present on ALL responses (2xx, 4xx, 5xx) — omitting on errors breaks support-ticket correlation workflows.
- Request IDs MUST NOT contain PII — they are shared with support teams and stored in log pipelines with extended retention.
---

### 8. Protocol Wire Example

```http
x-request-id: req-1700000000000-a1b2c3
```
