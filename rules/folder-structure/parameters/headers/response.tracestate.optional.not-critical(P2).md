# Parameter Specification: `tracestate`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `tracestate` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | W3C Trace Context Tracestate String |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Returns updated or preserved vendor-specific trace context attributes to the calling client.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: tracestate
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_@=,;-]{0,512}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
tracestate = list-member *( OWS "," OWS list-member )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF vendor tracestate attributes exist, the server SHALL format and inject the `tracestate` response header.
2. IF empty, the server SHALL omit the header.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Tracestate entries present | `size(tracestate) > 0` | `Formatted vendor list` | Inject header |
| Tracestate empty | `size(tracestate) == 0` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
tracestate.size() > 0 ? tracestate : null
```

---

### 7. Failure & Security Enforcement
- Must omit header if tracestate is empty.
- Length must not exceed 512 characters.

---

### 8. Protocol Wire Example

```http
tracestate: rojo=1,congo=4
```
