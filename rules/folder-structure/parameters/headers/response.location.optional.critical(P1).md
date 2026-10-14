# Parameter Specification: `Location`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Location` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on 201 Created and 202 Accepted** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | RFC 9110 Absolute or Relative URI |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Points the client to the canonical URI of the newly created resource (on 201) or to the status-polling monitor endpoint (on 202).

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Location
in: header
required: true
schema:
  type: string
  pattern: "^https?://.*|^/.*$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Location = URI-reference
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. On HTTP 201 Created responses, the server MUST include `Location` header pointing to the canonical URI of the newly created resource.
2. On HTTP 202 Accepted responses, the server MUST include `Location` header pointing to the asynchronous operation status monitor endpoint.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Status 201 or 202 with target URI | `status_code in [201, 202] && target_uri != null` | `target_uri` | Inject Location header |
| Other responses | `!(status_code in [201, 202])` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
status_code in [201, 202] && target_uri != null ? target_uri : null
```

---

### 7. Failure & Security Enforcement
- RFC 9110 requirement for 201 Created.
- Must point to polling endpoint for asynchronous 202 Accepted jobs.

---

### 8. Protocol Wire Example

```http
Location: https://api.example.com/v2/orders/018f6e2c-9999-7d4e-b3f2-1a2b3c4d5e6f
```
