# Parameter Specification: `x-causation-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-causation-id` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional (Conditionally Mandatory for Event-Driven Mutating Calls)** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | Event Sourcing Causation Pattern / IETF RFC 4122 UUID / W3C Trace Context §3.3 (tracestate vendor keys) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Identifies the immediate precursor event or message that directly caused this request to be dispatched. Essential for distributed causality graphs and event sourcing auditability.

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

1. The server SHALL extract `x-causation-id` from request headers.
2. IF valid format is present, the server SHALL bind it to the execution context.
3. IF absent, the server SHALL return null (or omit from non-event HTTP flows).
4. When present, the server MUST reflect it in `meta.causationId` and outbound response headers.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Valid identifier present | `raw.matches('^[a-zA-Z0-9_-]{16,64}$') == true` | `Trim(raw)` | Bind to meta.causationId |
| Absent or malformed on standard REST | `raw == null || match fails` | `null` | Omit from response |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-causation-id"]) && request.headers["x-causation-id"].matches("^[a-zA-Z0-9_-]{16,64}$")
  ? request.headers["x-causation-id"].trim()
  : null
```

---

### 7. Failure & Security Enforcement
- For webhook callbacks or event-triggered actions, omitting causation-id violates audit compliance.
- Reflected in meta.causationId and outbound response headers when present.

---

### 8. Protocol Wire Example

```http
x-causation-id: evt-1700000000000-k3m4p5
```
