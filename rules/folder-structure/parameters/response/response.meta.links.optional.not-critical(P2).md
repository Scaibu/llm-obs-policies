# Parameter Specification: `meta.links`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.links` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **Optional / Standardized for HATEOAS** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 5988 Web Linking / IETF RFC 8288 (successor) / HATEOAS REST Architectural Constraint (Fielding 2000) |
| **Schema Type** | `object` |

---

### 1. Architectural Purpose & Scope
Provides self-describing REST hypermedia controls (self, next, prev, help, documentation, support).

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: meta.links
in: body  # JSON body field — not a header parameter
required: false
schema:
  type: object
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
links = "{" link-entry *( "," link-entry ) "}"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL include canonical `self` URL.
2. On error responses, the server SHOULD include `help` and `documentation` URLs.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Standard response | `true` | `Links Object with self and optional help` | Inject into meta |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
{"self": endpoint_url, "help": error_help_url, "documentation": doc_url}
```

---

### 7. Failure & Security Enforcement
- Self link must be an absolute or canonical URI.
- Help links point directly to error documentation.

---

### 8. Protocol Wire Example

```json
"links": { "self": "https://api.example.com/v2/orders/018f6e2c", "help": "https://api.example.com/docs/errors/VALIDATION_FAILED" }
```
