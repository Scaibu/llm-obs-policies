# Parameter Specification: `x-consent-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-consent-id` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional (Conditionally Mandatory for Regulated PII Processing)** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | RFC 4122 UUIDv7 Consent Ledger Reference |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Certifies that user explicit consent has been captured and recorded in the consent ledger prior to processing PII data under GDPR/CCPA.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-consent-id
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{16,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-consent-id = 16*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. On privacy-sensitive routes, the server MUST require `x-consent-id`.
2. IF missing on regulated processing operations, the server MUST reject with HTTP 403 CONSENT_REQUIRED.
3. The server MUST log consent reference in audit records.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Non-PII processing route | `!is_pii_regulated` | `PROCEED` | Bypass consent check |
| PII route with valid consent reference | `is_pii_regulated && has(raw)` | `PROCEED` | Record consent reference in audit |
| PII route without consent reference | `is_pii_regulated && !has(raw)` | `ERROR 403` | Reject with CONSENT_REQUIRED |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!is_pii_regulated || (has(request.headers["x-consent-id"]) && request.headers["x-consent-id"].size() >= 16)
  ? "PROCEED"
  : "ERROR_CONSENT_REQUIRED"
```

---

### 7. Failure & Security Enforcement
- Processing regulated personal data without valid consent reference triggers regulatory non-compliance.
- Must be recorded in audit log records.

---

### 8. Protocol Wire Example

```http
x-consent-id: cns-1700000000000-9a8b7c
```
