# Parameter Specification: `Content-Type`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Content-Type` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY for Requests with Payloads** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 / RFC 6902 / RFC 7396 MIME Types |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Specifies the media type of the request payload. Enforces JSON parsing semantics and determines whether PATCH uses Merge-Patch (RFC 7396) or JSON-Patch (RFC 6902).

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Content-Type
in: header
required: true
schema:
  type: string
  pattern: "^(application/json|application/merge-patch\+json|application/json-patch\+json)(;\s*charset=utf-8)?$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Content-Type = media-type *( OWS ";" OWS parameter )
media-type   = type "/" subtype
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF a request carries an HTTP body, the server MUST require `Content-Type` header.
2. The server MUST verify that the media type matches accepted MIME types (`application/json`, `application/merge-patch+json`, `application/json-patch+json`).
3. IF missing or unsupported, the server MUST reject with HTTP 415 UNSUPPORTED_MEDIA_TYPE.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| No payload body present | `!has_body` | `PROCEED` | Bypass media type check |
| Supported media type presented | `has_body && mime in supported_mimes` | `PROCEED` | Parse body with appropriate deserializer |
| Unsupported media type or missing header | `has_body && !(mime in supported_mimes)` | `ERROR 415` | Reject with UNSUPPORTED_MEDIA_TYPE |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!has_body
  ? "PROCEED"
  : has(request.headers["content-type"]) && request.headers["content-type"].split(";")[0].trim().lowerAscii() in supported_mimes
    ? "PROCEED"
    : "ERROR_UNSUPPORTED_MEDIA_TYPE"
```

---

### 7. Failure & Security Enforcement
- Payloads without Content-Type must be rejected before reading body stream.
- Must never allow executable script or arbitrary binary MIME types on REST endpoints.
- Content sniffing MUST be disabled (`X-Content-Type-Options: nosniff`) on all endpoints that accept uploads.
- Requests with body payloads that omit `Content-Type` MUST be rejected before the body stream is read — never buffer unknown MIME type payloads.
---

### 8. Protocol Wire Example

```http
Content-Type: application/json; charset=utf-8
```
