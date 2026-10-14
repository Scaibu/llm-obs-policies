# Parameter Specification: `x-audit-log-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-audit-log-id` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional (Conditionally Mandatory on Audited Mutations & Security Failures)** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | NIST SP 800-92 Audit Log Guidelines / ISO/IEC 27001:2022 A.8.15 / RFC 9110 Custom Headers |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Cryptographically unforgeable audit ledger record identifier. Informs the caller that a state mutation or security failure was durably and immutably committed to the audit trail before response was transmitted. Enables compliance forensic correlation across distributed system components.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-audit-log-id
in: header
required: false
schema:
  type: string
  pattern: "^audit-[0-9]{13}-[a-f0-9]{8}$"
  minLength: 29
  maxLength: 29
  examples:
    - audit-1726908742123-a3f4b2c1
```

> Pattern breakdown: `audit-` prefix + 13 decimal Unix-ms timestamp digits + `-` separator + 8 lowercase hex random suffix.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-audit-log-id = "audit-" 13DIGIT "-" 8HEXDIG
```

> `HEXDIG` per RFC 5234 §B.1: `0-9 / A-F`. For case-insensitive matching, implementations MAY accept uppercase; canonical generation MUST use lowercase.

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. Upon completing a state mutation (POST/PUT/PATCH/DELETE that alters persistent data), the server MUST synchronously generate an immutable audit ledger entry before transmitting the response.
2. Upon recording a security event (401/403/409 from an authentication or authorisation failure), the server MUST generate an audit ledger entry.
3. The server MUST inject the generated `x-audit-log-id` into the HTTP response header immediately after ledger commit confirmation.
4. The value MUST exactly mirror `meta.auditLogId` in the response JSON envelope.
5. For read-only operations (GET/HEAD) that do not trigger an audit event, the header MUST be omitted entirely (not set to null or empty).
6. Audit ledger entries MUST be written with write-ahead durability guarantees before the header is emitted.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Successful mutating operation (POST/PUT/PATCH/DELETE 2xx) | `is_mutation && is_success` | `audit-{unix_ms}-{hex8}` | Inject header; mirror in `meta.auditLogId` |
| Security rejection (401/403) | `status_code in [401, 403]` | `audit-{unix_ms}-{hex8}` | Inject header for forensic compliance trace |
| Idempotency key conflict (409) | `status_code == 409 && conflict_type == "IDEMPOTENCY_KEY_REUSE"` | `audit-{unix_ms}-{hex8}` | Inject header; record replay attempt |
| Read-only query (GET/HEAD 2xx) | `!is_mutation && is_success` | `null` | Omit header |
| Server error (5xx) | `status_code >= 500` | `audit-{unix_ms}-{hex8}` | Inject header; mark entry as partial |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
(is_mutation || status_code in [401, 403, 409])
  ? "audit-" + string(unix_ms) + "-" + hex8_random
  : null
```

---

### 7. Failure & Security Enforcement
- MUST be present on any mutating operation (POST/PUT/PATCH/DELETE) that alters persistent state — absence on mutation is a compliance violation.
- MUST be present on security rejections (401/403/409) for compliance forensic verification (NIST SP 800-92).
- Value MUST be generated server-side; client-supplied values MUST be rejected and overwritten.
- Audit ledger entry MUST be written with WAL durability before the HTTP response is transmitted — prevents log loss on crash.
- Audit records MUST be retained per applicable regulatory retention policy (minimum 90 days; 7 years for financial operations).
- The header value MUST exactly match `meta.auditLogId`; a mismatch is a critical integrity defect.

---

### 8. Protocol Wire Example

```http
x-audit-log-id: audit-1726908742123-a3f4b2c1
```
