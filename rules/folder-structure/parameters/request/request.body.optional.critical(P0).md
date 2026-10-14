# Parameter Specification: `request.body`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `request.body` |
| **Category** | `request` |
| **Surface** | Inbound HTTP Request Body Payload |
| **Requirement Level** | **MANDATORY on POST / PUT / PATCH** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 7159 (JSON) / JSON Schema 2020-12 / OWASP Mass Assignment Prevention |
| **Schema Type** | `object` |

---

### 1. Architectural Purpose & Scope
Carries the mutation data payload for state-changing operations. Validated against a strict, closed JSON Schema (2020-12) where `unevaluatedProperties: false` prevents mass-assignment vulnerabilities. GET, HEAD, DELETE, and OPTIONS requests MUST NOT carry a request body.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
requestBody:
  required: true
  content:
    application/json:
      schema:
        $schema: "https://json-schema.org/draft/2020-12/schema"
        type: object
        required:
          - []
        properties: {}
        unevaluatedProperties: false
```

> **Note:** Request bodies are defined under `requestBody.content`, not as `parameters` with `in: body`. The `unevaluatedProperties: false` keyword (JSON Schema 2020-12) is the correct closed-schema enforcement mechanism — supersedes `additionalProperties: false` for schemas using `$ref` or `allOf`.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
request-body     = JSON-object
JSON-object      = begin-object [ member *( value-separator member ) ] end-object
begin-object     = ws %x7B ws
end-object       = ws %x7D ws
member           = string name-separator value
```

> Payload MUST be well-formed JSON per RFC 7159. Any binary or multipart payload MUST use appropriate Content-Type and is out of scope for this specification.

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST only accept a request body on HTTP methods POST, PUT, and PATCH.
2. The server MUST reject a request body on GET, HEAD, DELETE, or OPTIONS with HTTP 400.
3. The server MUST validate the inbound body against the endpoint-specific closed JSON Schema.
4. The server MUST reject any property key not declared in `properties` (`unevaluatedProperties: false`).
5. IF required fields are missing, the server MUST return HTTP 400 `VALIDATION_FAILED` with field-level `details` identifying each missing field.
6. IF undeclared additional properties are present, the server MUST return HTTP 400 `VALIDATION_FAILED` citing mass-assignment protection.
7. Validated body values SHALL be forwarded to domain logic; raw input MUST NOT be forwarded prior to full schema validation.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Non-mutating method with body (GET/HEAD) | `!is_mutation && body_present` | `ERROR 400` | Reject; body on read methods is forbidden |
| Mutating method, no body provided | `is_mutation && !body_present` | `ERROR 400` | Reject with BODY_REQUIRED |
| All required fields present, no undeclared fields | `has_required && !has_undeclared` | `VALID` | Forward to domain handler |
| Missing one or more required fields | `!has_required` | `ERROR 400` | VALIDATION_FAILED with field details |
| Undeclared additional property present | `has_undeclared` | `ERROR 400` | VALIDATION_FAILED — mass assignment blocked |
| Body is malformed JSON (parse error) | `!parseable` | `ERROR 400` | Reject before schema validation |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!is_mutation && body_present
  ? "ERROR_BODY_FORBIDDEN"
  : is_mutation && !body_present
    ? "ERROR_BODY_REQUIRED"
    : !parseable
      ? "ERROR_MALFORMED_JSON"
      : schema.required.all(f, has(request.body[f])) && request.body.keys().all(k, k in schema.properties)
        ? "VALID"
        : "ERROR_VALIDATION_FAILED"
```

---

### 7. Failure & Security Enforcement
- Closed schema enforcement (`unevaluatedProperties: false`) prevents mass-assignment vulnerabilities (OWASP API3:2023).
- Body MUST be deserialized only after verifying `Content-Type: application/json` is present.
- Maximum body size MUST be enforced at gateway level (recommended: 1 MB for standard endpoints; configurable per route).
- Validation errors MUST return HTTP 400 with field-level `error.details` — never expose raw schema paths or internal model names.
- Validated payload MUST be treated as immutable after passing domain logic boundary.

---

### 8. Protocol Wire Example

```json
{
  "customerEmail": "user@example.com",
  "totalAmount": {
    "amount": "99.50",
    "currency": "USD"
  }
}
```
