# Parameter Specification: `x-causation-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-causation-id` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | Event Sourcing Causation Pattern / IETF RFC 4122 UUID / W3C Trace Context §3.3 |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Echoes the direct precursor causation identifier back to the client when applicable.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-causation-id
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{16,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-causation-id = 16*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF a causation identifier is active, the server SHALL format and inject `x-causation-id`.
2. The value MUST mirror `meta.causationId`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Causation ID present | `causation_id != null` | `causation_id` | Inject header |
| Causation ID absent | `causation_id == null` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
causation_id != null ? causation_id : null
```

---

### 7. Failure & Security Enforcement
- Must match meta.causationId in envelope.
- Included primarily for event-driven API interactions.

---

### 8. Protocol Wire Example

```http
x-causation-id: evt-1700000000000-k3m4p5
```
