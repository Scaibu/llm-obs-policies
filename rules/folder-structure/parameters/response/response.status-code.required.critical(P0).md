# Parameter Specification: `statusCode`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `statusCode` |
| **Category** | `response` |
| **Surface** | Response JSON Envelope Root Field |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 §15 HTTP Semantics — Status Codes / JSON Schema 2020-12 |
| **Schema Type** | `integer` |

---

### 1. Architectural Purpose & Scope
Mirror of the actual HTTP transport response status code, embedded in the JSON payload envelope. Ensures that clients operating behind proxies, API gateways, or load balancers that mangle, normalise, or override HTTP status codes can reliably inspect the authoritative outcome status. Eliminates reliance on transport-layer status inspection alone.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
schema:
  type: object
  required:
    - statusCode
  properties:
    statusCode:
      type: integer
      minimum: 200
      maximum: 599
      description: "Exact mirror of the HTTP transport status code. Defined in RFC 9110 §15."
      examples:
        - 200
        - 201
        - 400
        - 401
        - 404
        - 409
        - 422
        - 429
        - 500
        - 503
```

> **Note:** `pattern` is a string-only keyword in JSON Schema 2020-12. Integer fields MUST use `minimum`/`maximum` bounds. The range 200–599 covers all 2xx, 3xx (excluded from this API), 4xx, and 5xx classes.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
statusCode = 3DIGIT
```

> Range: `200` ≤ `statusCode` ≤ `599`. Values outside this range are invalid per RFC 9110.

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST set the `statusCode` field in the JSON envelope root to exactly mirror the HTTP response status line code.
2. IF the HTTP status is in the 2xx class, `statusCode` MUST equal the transport status code and `success` MUST be `true`.
3. IF the HTTP status is in the 4xx or 5xx class, `statusCode` MUST equal the transport status code and `success` MUST be `false`.
4. The server MUST NEVER set `statusCode` to a value that does not match the HTTP transport status code.
5. 3xx redirect status codes MUST NOT appear in `statusCode` — redirects are handled at the transport layer before reaching the JSON envelope.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Successful creation (201 Created) | `http_status == 201` | `201` | Set `success: true`; set `Location` header |
| Successful read/update (200 OK) | `http_status == 200` | `200` | Set `success: true` |
| Validation error (400) | `http_status == 400` | `400` | Set `success: false`; populate `error` object |
| Unauthenticated (401) | `http_status == 401` | `401` | Set `success: false`; emit `WWW-Authenticate` |
| Rate limit exceeded (429) | `http_status == 429` | `429` | Set `success: false`; emit `Retry-After` |
| Server error (500) | `http_status == 500` | `500` | Set `success: false`; trigger alert |
| `statusCode` ≠ HTTP transport code | `statusCode != http_status` | `ERROR_STATUS_MISMATCH` | Log critical integrity defect |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
http_status_code >= 200 && http_status_code <= 599
  ? http_status_code
  : "ERROR_INVALID_STATUS_CODE"
```

---

### 7. Failure & Security Enforcement
- MUST exactly match the HTTP transport status code on every response — divergence is a critical contract integrity defect.
- 3xx codes MUST NOT appear in the JSON envelope `statusCode`.
- Discrepancies between transport status and body `statusCode` MUST trigger a critical alert and be treated as a routing/middleware defect.
- Clients MUST use this field as a fallback when the transport status has been overridden by an intermediary proxy.

---

### 8. Protocol Wire Example

```json
{
  "statusCode": 200,
  "success": true
}
```
