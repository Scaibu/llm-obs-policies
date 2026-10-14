# Parameter Specification: `Accept`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Accept` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 9110 Content Negotiation MIME Type |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Informs the server of the media types the client is prepared to process. Defaults to application/json.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Accept
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9/+*.-]+(;q=[0-9.]+)?$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Accept = #( media-range [ accept-params ] )
media-range = ( "*/*" / ( type "/*" ) / ( type "/" subtype ) ) *( OWS ";" OWS parameter )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL inspect `Accept` header for content negotiation.
2. IF absent or contains `*/*` or `application/json`, the server MUST return `application/json`.
3. IF client explicitly demands unsupported media types, the server MUST reject with HTTP 406 NOT_ACCEPTABLE.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header absent or permits application/json | `raw == null || '*/*' in raw || 'application/json' in raw` | `application/json` | Serialize JSON |
| Explicitly rejects application/json and demands foreign type | `!(supported_type in raw)` | `ERROR 406` | Reject with NOT_ACCEPTABLE |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!has(request.headers.accept) || request.headers.accept.contains("*/*") || request.headers.accept.contains("application/json")
  ? "application/json"
  : "ERROR_NOT_ACCEPTABLE"
```

---

### 7. Failure & Security Enforcement
- Must default to application/json if omitted.
- Must return 406 Not Acceptable if client explicitly rejects application/json.

---

### 8. Protocol Wire Example

```http
Accept: application/json
```
