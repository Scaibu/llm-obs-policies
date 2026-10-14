# Parameter Specification: `x-auth-level`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-auth-level` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional (Conditionally Mandatory for High-Risk Routes)** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | NIST SP 800-63B Authentication Assurance Levels / OpenID Connect ACR Values (IETF RFC 6711) | 'mfa' | 'hardware_key') |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Communicates the verified authentication assurance level of the caller. High-risk actions (e.g. transfers, key rotations) enforce 'mfa' or 'hardware_key'.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-auth-level
in: header
required: false
schema:
  type: string
  pattern: "^(password|mfa|hardware_key)$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-auth-level = "password" / "mfa" / "hardware_key"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL extract `x-auth-level` from request headers.
2. The server MUST compare presented assurance level against route security policy minimum.
3. IF assurance level is insufficient, the server MUST reject with HTTP 403 INSUFFICIENT_AUTH_LEVEL.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Assurance score >= required score | `score(presented) >= score(required)` | `PERMITTED` | Allow route execution |
| Assurance score < required score | `score(presented) < score(required)` | `ERROR 403` | Reject with INSUFFICIENT_AUTH_LEVEL step-up demand |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
auth_score(request.headers["x-auth-level"]) >= required_route_auth_score
  ? "PERMITTED"
  : "ERROR_INSUFFICIENT_AUTH_LEVEL"
```

---

### 7. Failure & Security Enforcement
- Downgrading auth level on protected operations must be rejected at gateway.
- Reflected in security audit records.

---

### 8. Protocol Wire Example

```http
x-auth-level: mfa
```
