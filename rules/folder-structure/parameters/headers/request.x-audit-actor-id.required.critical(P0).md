# Parameter Specification: `x-audit-actor-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-audit-actor-id` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY on Mutating Endpoints** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 4122 UUID / Actor Identity Slug |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Declares the authenticated human user, service account, or automated pipeline responsible for triggering the mutation. Recorded immutably in the audit log.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-audit-actor-id
in: header
required: true
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{3,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-audit-actor-id = 3*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST extract `x-audit-actor-id` on state-changing operations.
2. IF omitted, the server SHALL fallback to authenticated token subject claim or client ID.
3. The server MUST record the actor identifier immutably in synchronous audit records.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header present and valid | `raw.matches('^[a-zA-Z0-9_-]{3,64}$') == true` | `Trim(raw)` | Record in audit ledger |
| Header omitted, token subject present | `raw == null && has(token.sub)` | `token.sub` | Record authenticated subject ID |
| Header omitted, client ID present | `raw == null && has(client_id)` | `client_id` | Record client application ID |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-audit-actor-id"])
  ? request.headers["x-audit-actor-id"].trim()
  : (has(token.sub) ? token.sub : (has(client_id) ? client_id : "anonymous-actor"))
```

---

### 7. Failure & Security Enforcement
- Every state-changing HTTP operation must capture actor identity.
- Reflected in audit log entries and meta.auditLogId association.
- Actor ID MUST be written to the immutable audit ledger before any domain mutation is committed — the actor must be known before state changes.
- Actor ID MUST NOT be user-modifiable in authenticated flows — it MUST be derived from the validated JWT `sub` claim, not the raw header value.
---

### 8. Protocol Wire Example

```http
x-audit-actor-id: usr_9b2c3d4e5f607182
```
