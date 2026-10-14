# Parameter Specification: `traceparent`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `traceparent` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | W3C Trace Context / OpenTelemetry Distributed Tracing |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Transmits standard W3C distributed trace context across gateway and microservice boundaries. Binds incoming execution to an OpenTelemetry root trace or parent span. Ingested at edge ingress; if missing or malformed, the pipeline deterministically injects a synthetic root trace context.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: traceparent
in: header
required: true
schema:
  type: string
  pattern: "^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
traceparent    = version "-" trace-id "-" parent-id "-" trace-flags
version        = 2HEXDIG
trace-id       = 32HEXDIG
parent-id      = 16HEXDIG
trace-flags    = 2HEXDIG
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST extract the raw `traceparent` header string from the inbound HTTP request headers map.
2. The server SHALL validate that the string strictly matches the four-part W3C lowercase hexadecimal representation.
3. The server MUST verify that neither `trace-id` nor `parent-id` consists entirely of hexadecimal zeros (`00...00`).
4. IF valid, the server SHALL bind the parsed trace context to the active OpenTelemetry request span.
5. IF absent, malformed, or invalid, the server MUST generate and inject a synthetic 128-bit `trace_id` and 64-bit `span_id` with flags `01`.
6. The server MUST echo the resolved `traceparent` in the outbound HTTP response header.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Matches 4-part W3C hex format and IDs non-zero | `regex.matches(raw) && trace_id != 0 && parent_id != 0` | `Parsed W3C Context` | Bind to OpenTelemetry Span |
| Header absent or empty string | `raw == null || raw == ''` | `Synthetic Root Context (Flags 01)` | Record telemetry trace creation event |
| Malformed delimiter, length, or all-zeros ID | `Parse error or zeros detected` | `Synthetic Root Context (Flags 01)` | Log warning and suppress error |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
raw_header.matches("^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$") &&
!raw_header.split("-")[1].matches("^0{32}$") &&
!raw_header.split("-")[2].matches("^0{16}$")
  ? {
      "version": raw_header.split("-")[0],
      "trace_id": raw_header.split("-")[1],
      "span_id": raw_header.split("-")[2],
      "trace_flags": raw_header.split("-")[3]
    }
  : {
      "version": "00",
      "trace_id": default_trace_id,
      "span_id": default_span_id,
      "trace_flags": "01"
    }
```

---

### 7. Failure & Security Enforcement
- Malformed headers MUST NOT crash the server; default synthetic context must be used.
- Outbound response header `traceparent` MUST echo the resolved trace context.
- Must be forwarded to all downstream microservices, gRPC calls, and messaging brokers.

---

### 8. Protocol Wire Example

```http
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```
