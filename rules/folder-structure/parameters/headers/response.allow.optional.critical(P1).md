# Parameter Specification: `Allow`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Allow` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on 405 Method Not Allowed and OPTIONS** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | RFC 9110 HTTP Verbs Comma-separated List |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Informs the caller of the permitted HTTP verbs supported on the requested URI.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Allow
in: header
required: true
schema:
  type: string
  pattern: "^[A-Z]+(,\s*[A-Z]+)*$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Allow = #method
method = 1*ALPHA
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. When responding with HTTP 405 Method Not Allowed, the server MUST generate `Allow` header listing permitted verbs.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Status is 405 or request is OPTIONS | `status_code == 405 || method == 'OPTIONS'` | `Comma-delimited permitted methods` | Inject Allow header |
| Standard responses | `status_code != 405 && method != 'OPTIONS'` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
status_code == 405 || request.method == "OPTIONS" ? permitted_methods.join(", ") : null
```

---

### 7. Failure & Security Enforcement
- Mandatory under HTTP specification whenever 405 is returned.
- Must include HEAD and OPTIONS if GET is supported.

---

### 8. Protocol Wire Example

```http
Allow: GET, POST, HEAD, OPTIONS
```
