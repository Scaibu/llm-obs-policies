# Parameter Specification: `tracestate`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `tracestate` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | W3C Trace Context Specification (RFC draft-ietf-w3c-trace-context) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Carries opaque vendor-specific routing, filtering, and telemetry metadata alongside W3C distributed trace context. Must be forwarded without mutation to preserve monitoring state.

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
tracestate     = list-member *( OWS "," OWS list-member )
list-member    = vendor-name "=" vendor-value
vendor-name    = ( 1*ALPHA 0*255( ALPHA / DIGIT / "_" / "-" / "*" / "/" ) )
vendor-value   = 0*256( VCHAR )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL extract the raw `tracestate` header string from inbound request headers.
2. The server MUST enforce a maximum length limit of 512 characters.
3. The server SHALL parse opaque comma-separated `vendor=value` pairs into a key-value map.
4. The server MUST forward existing vendor keys downstream without mutation.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header present and length <= 512 | `size(raw) <= 512` | `Parsed key-value map` | Propagate downstream verbatim |
| Header absent or empty | `raw == null || raw == ''` | `Empty Map {}` | Omit from outbound propagation |
| Header length > 512 characters | `size(raw) > 512` | `Truncated / Sanitized Map` | Discard excess vendor pairs |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers.tracestate) && request.headers.tracestate.size() <= 512
  ? request.headers.tracestate
  : ""
```

---

### 7. Failure & Security Enforcement
- Opaque vendor tags must not be altered or stripped by intermediate gateways.
- Malformed entries must be ignored without interrupting trace context ingestion.

---

### 8. Protocol Wire Example

```http
tracestate: rojo=1,congo=4
```
