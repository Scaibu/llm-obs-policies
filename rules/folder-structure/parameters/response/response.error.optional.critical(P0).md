# Parameter Specification: `error`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `error` |
| **Category** | `response` |
| **Surface** | Response JSON Envelope Root Field |
| **Requirement Level** | **MANDATORY on Failure; FORBIDDEN on Success** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 7807 Problem Details / IETF RFC 9457 (successor) / JSON Schema 2020-12 |
| **Schema Type** | `object` |

---

### 1. Architectural Purpose & Scope
Structured container for failure diagnostics. Conforms to RFC 9457 (Problem Details for HTTP APIs) for machine-readable error interoperability. Holds canonical machine-readable error code, sanitised human-readable message, retry classification, and field-level validation violation details. Forbidden on success responses to prevent ambiguous dual-state envelopes.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
schema:
  type: object
  required:
    - code
    - message
    - retryable
  properties:
    code:
      type: string
      description: "Machine-readable error code from Canonical Error Code Dictionary."
      examples:
        - VALIDATION_FAILED
        - UNAUTHENTICATED
        - RATE_LIMIT_EXCEEDED
    message:
      type: string
      description: "Human-readable sanitised error description. MUST NOT expose stack traces or internal paths."
      maxLength: 512
    retryable:
      type: boolean
      description: "Indicates whether the client MAY safely retry the operation."
    details:
      type: array
      description: "Field-level validation violations. Present only when code is VALIDATION_FAILED."
      items:
        type: object
        required:
          - field
          - issue
        properties:
          field:
            type: string
          issue:
            type: string
  unevaluatedProperties: false
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
error-object     = "{" code-entry "," message-entry "," retryable-entry [ "," details-entry ] "}"
code-entry       = DQUOTE "code" DQUOTE ":" DQUOTE 1*( ALPHA / "_" ) DQUOTE
message-entry    = DQUOTE "message" DQUOTE ":" DQUOTE *VCHAR DQUOTE
retryable-entry  = DQUOTE "retryable" DQUOTE ":" ( "true" / "false" )
details-entry    = DQUOTE "details" DQUOTE ":" "[" *violation-object "]"
violation-object = "{" DQUOTE "field" DQUOTE ":" DQUOTE *VCHAR DQUOTE "," DQUOTE "issue" DQUOTE ":" DQUOTE *VCHAR DQUOTE "}"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF the response indicates an operational failure (HTTP 4xx or 5xx), the server MUST include the `error` object.
2. The `error` object MUST contain `code`, `message`, and `retryable` properties.
3. The `code` value MUST be a member of the Canonical Error Code Dictionary.
4. IF the failure is a validation error (`VALIDATION_FAILED`), the server MUST populate the `details` array with at least one field-level violation object.
5. IF the response is a success (HTTP 2xx), the `error` key MUST NOT be present in the envelope.
6. The server MUST NOT include SQL error text, stack traces, file paths, or internal component names in `message`.
7. The `retryable` flag MUST be `true` only for transient failures (rate-limit, timeout, service unavailable).

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Success response (2xx) | `is_success` | `OMITTED` | `error` key MUST NOT exist in envelope |
| Validation failure | `!is_success && code == "VALIDATION_FAILED"` | `Error object with details[]` | Populate field-level violation list |
| Auth / authz failure | `!is_success && code in ["UNAUTHENTICATED","FORBIDDEN"]` | `Error object; retryable: false` | Trigger WWW-Authenticate header (401 only) |
| Transient failure (rate-limit, timeout) | `!is_success && is_transient` | `Error object; retryable: true` | Populate `Retry-After` header |
| Fatal server error | `!is_success && !is_transient` | `Error object; retryable: false` | Suppress internal cause from message |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!is_success
  ? {
      "code": error_code,
      "message": sanitised_message,
      "retryable": is_retryable,
      "details": (error_code == "VALIDATION_FAILED" ? validation_details : [])
    }
  : null
```

---

### 7. Failure & Security Enforcement
- `error` MUST be absent (key entirely omitted, not null) on success responses.
- `code` MUST match the Canonical Error Code Dictionary; unknown codes MUST be rejected by response validators.
- `message` MUST be sanitised before serialisation — forbidden tokens: SQL keywords, stack frame patterns, internal hostnames, file paths.
- `details` array MUST be empty (`[]`) or omitted for non-validation errors.
- Error responses MUST set `Cache-Control: no-store` to prevent error body caching by intermediaries.

---

### 8. Protocol Wire Example

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Field validation failed.",
    "retryable": false,
    "details": [
      { "field": "customerEmail", "issue": "Must be a valid RFC 5321 email address." }
    ]
  }
}
```
