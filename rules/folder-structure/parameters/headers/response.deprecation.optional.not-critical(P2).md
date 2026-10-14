# Parameter Specification: `Deprecation`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Deprecation` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on Deprecated Endpoints** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 8594 Sunset and Deprecation HTTP Header Fields |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Announces that the requested API version, route, or feature is deprecated and scheduled for future retirement.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Deprecation
in: header
required: true
schema:
  type: string
  pattern: "^(true|@[0-9]+|[a-zA-Z0-9, :]+)$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Deprecation = "true" / date
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF a requested endpoint or contract version is flagged as deprecated in the registry, the server MUST include `Deprecation: true` header.
2. The server MUST pair this with a `Sunset` header declaring final retirement date.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Endpoint is deprecated | `is_deprecated == true` | `true` | Inject Deprecation header |
| Endpoint is active | `is_deprecated == false` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
is_deprecated ? "true" : null
```

---

### 7. Failure & Security Enforcement
- Must be accompanied by Sunset header declaring final retirement date.
- Allows automated client monitoring to trigger migration warnings.

---

### 8. Protocol Wire Example

```http
Deprecation: true
```
