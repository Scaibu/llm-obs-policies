# Parameter Specification: `x-region`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-region` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | ISO 3166-1 / Cloud Provider Region Conventions (AWS, GCP, Azure) / RFC 9110 §10.1 Custom Headers |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Identifies the physical cloud data center region that processed and returned the response.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-region
in: header
required: false
schema:
  type: string
  pattern: "^[a-z]{2}-[a-z]+-[0-9]$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-region = 2ALPHA "-" 1*ALPHA "-" 1*DIGIT
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The edge or server SHALL declare deployment cloud region in `x-region` response header.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Cloud deployment region known | `region != null` | `region` | Inject header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
region != null ? region : null
```

---

### 7. Failure & Security Enforcement
- Verifies compliance with data residency constraints.
- Enables clients to verify edge traffic routing.

---

### 8. Protocol Wire Example

```http
x-region: us-east-1
```
