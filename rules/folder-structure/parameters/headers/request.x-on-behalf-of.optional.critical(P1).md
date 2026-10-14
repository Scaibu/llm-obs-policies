# Parameter Specification: `x-on-behalf-of`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-on-behalf-of` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional (Conditionally Mandatory during User Impersonation)** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | RFC 8693 OAuth 2.0 Token Exchange / OpenID Connect Core §5.4 (subject_type) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Designates the target tenant or user identity when an administrative operator or support staff executes an action on behalf of a customer.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-on-behalf-of
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{3,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-on-behalf-of = 3*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL inspect `x-on-behalf-of` on administrative requests.
2. IF present, the server MUST verify that the calling actor holds `ACTION_IMPERSONATE` permissions.
3. IF unauthorized, the server MUST reject with HTTP 403 FORBIDDEN.
4. The server MUST record both operator and target identities in audit records.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header present and caller holds IMPERSONATE permission | `has(header) && 'ACTION_IMPERSONATE' in caller.permissions` | `ACTIVE` | Execute on target subject and write audit entry |
| Header present but caller lacks permission | `has(header) && !('ACTION_IMPERSONATE' in caller.permissions)` | `ERROR 403` | Reject with FORBIDDEN |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-on-behalf-of"])
  ? ("ACTION_IMPERSONATE" in caller.permissions ? request.headers["x-on-behalf-of"].trim() : "ERROR_FORBIDDEN")
  : null
```

---

### 7. Failure & Security Enforcement
- All impersonation requests must be written synchronously to immutable audit logs.
- Audit record must capture both the operator actor ID and the target customer ID.

---

### 8. Protocol Wire Example

```http
x-on-behalf-of: usr_customer_target_44
```
