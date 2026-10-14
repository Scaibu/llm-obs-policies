# Parameter Specification: `Sunset`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Sunset` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on Deprecated Endpoints** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 8594 / RFC 7231 HTTP-Date (GMT) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Specifies the exact date and time after which the deprecated API contract will be retired and return 410 Gone.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Sunset
in: header
required: true
schema:
  type: string
  pattern: "^[A-Z][a-z]{2},\s[0-9]{2}\s[A-Z][a-z]{2}\s[0-9]{4}\s[0-9]{2}:[0-9]{2}:[0-9]{2}\sGMT$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Sunset = HTTP-date
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF `Deprecation: true` is returned, the server MUST include `Sunset` header with formatted HTTP-date.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Deprecated endpoint with configured sunset date | `is_deprecated && sunset_date != null` | `sunset_date` | Inject Sunset header |
| Active endpoint | `!is_deprecated` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
is_deprecated && sunset_date != null ? sunset_date : null
```

---

### 7. Failure & Security Enforcement
- Mandatory companion to Deprecation header.
- Minimum 180-day migration window before sunset date.

---

### 8. Protocol Wire Example

```http
Sunset: Sat, 01 Aug 2026 00:00:00 GMT
```
