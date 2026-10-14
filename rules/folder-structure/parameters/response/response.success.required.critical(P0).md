# Parameter Specification: `success`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `success` |
| **Category** | `response` |
| **Surface** | Response JSON Envelope Root Field |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 §15 HTTP Status Code Semantics / RFC 7159 §3 JSON Boolean / JSON Schema 2020-12 |
| **Schema Type** | `boolean` |

---

### 1. Architectural Purpose & Scope
Unambiguous binary indicator of the operation's outcome at the application layer. Provides a single, authoritative, language-neutral signal that allows any client SDK — regardless of its HTTP library or proxy configuration — to determine success or failure before attempting to unpack the payload. MUST be `true` for all 2xx HTTP responses; MUST be `false` for all 4xx and 5xx responses.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
schema:
  type: object
  required:
    - success
  properties:
    success:
      type: boolean
      description: "True for 2xx responses; false for 4xx/5xx responses. Never null."
      examples:
        - true
        - false
```

> **Note:** `pattern` is a string-only keyword in JSON Schema 2020-12. `boolean` type has no `pattern` constraint. The allowed values (`true` / `false`) are fully defined by the `type: boolean` declaration.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
success = "true" / "false"
```

> Per JSON RFC 7159 §3, boolean literals MUST be lowercase `true` or `false` — no other representations (e.g., `1`, `0`, `"true"`) are conformant.

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF the HTTP response status code is in the 2xx class, the server MUST set `success: true`.
2. IF the HTTP response status code is in the 4xx or 5xx class, the server MUST set `success: false`.
3. The server MUST NEVER set `success: true` on any non-2xx response.
4. The server MUST NEVER set `success: false` on any 2xx response.
5. `success` MUST be a strict JSON boolean — string representations (`"true"`, `"false"`) or integer representations (`1`, `0`) are non-conformant.
6. `success: true` responses MUST include a `data` field; `success: false` responses MUST include an `error` field.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| HTTP 200 OK | `status_code == 200` | `true` | Render `data` field; omit `error` field |
| HTTP 201 Created | `status_code == 201` | `true` | Render `data` field; set `Location` header |
| HTTP 204 No Content | `status_code == 204` | `true` | Omit both `data` and `error` fields |
| HTTP 4xx Client Error | `status_code >= 400 && status_code < 500` | `false` | Render `error` field; omit `data` field |
| HTTP 5xx Server Error | `status_code >= 500 && status_code < 600` | `false` | Render `error` field; omit `data` field |
| Any inversion (`true` on 4xx or `false` on 2xx) | `(success == true && status >= 400) || (success == false && status < 300)` | `ERROR_INVARIANT_VIOLATION` | Log critical; trigger alert |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
status_code >= 200 && status_code < 300
  ? true
  : status_code >= 400
    ? false
    : "ERROR_UNEXPECTED_STATUS_CLASS"
```

---

### 7. Failure & Security Enforcement
- `success: true` MUST NEVER accompany a 4xx or 5xx HTTP status — inversion is a critical contract defect.
- `success: false` MUST NEVER accompany a 2xx HTTP status.
- This is the first field evaluated by all client SDKs before payload unpacking — inaccuracy causes silent data corruption at the consumer layer.
- JSON boolean literals ONLY — no truthy/falsy string or integer equivalents are permitted.
- Automated contract tests MUST verify `success` ↔ `statusCode` invariant on every endpoint.

---

### 8. Protocol Wire Example

```json
{
  "success": true,
  "statusCode": 200
}
```
