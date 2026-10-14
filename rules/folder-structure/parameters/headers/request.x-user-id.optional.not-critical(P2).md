# Parameter Specification: `x-user-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-user-id` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 6749 §4 OAuth Resource Owner / OpenID Connect Core sub Claim |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Carries verified user identity propagated from edge gateway to downstream internal microservices.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-user-id
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{3,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-user-id = 3*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The edge gateway SHALL authenticate credentials and inject `x-user-id` into internal requests.
2. Downstream microservices SHALL trust `x-user-id` only when received from internal private mesh network.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Internal request with user identifier | `is_internal && raw != null` | `Trim(raw)` | Bind user context |
| External request with unverified user header | `!is_internal && raw != null` | `STRIPPED` | Strip untrusted header at edge |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-user-id"]) && request.headers["x-user-id"].matches("^[a-zA-Z0-9_-]{3,64}$")
  ? request.headers["x-user-id"].trim()
  : null
```

---

### 7. Failure & Security Enforcement
- Must be stripped from external public traffic if not authenticated at edge.
- Must be sanitized against header injection attacks.

---

### 8. Protocol Wire Example

```http
x-user-id: usr_018f6e2c-9999
```
