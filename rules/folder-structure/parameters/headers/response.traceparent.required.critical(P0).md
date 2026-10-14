# Parameter Specification: `traceparent`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `traceparent` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | W3C Trace Context Specification |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Echoes the active OpenTelemetry W3C trace context back to the caller for end-to-end distributed observability and support ticket tracing.

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
traceparent = version "-" trace-id "-" parent-id "-" trace-flags
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST echo the resolved `traceparent` context in the outbound response header.
2. IF the incoming request had a valid `traceparent`, the server MUST echo that exact `trace-id` with its own `span-id` and resolved flags.
3. IF the incoming request had no `traceparent`, the server MUST echo the synthetic root context it generated during request processing.
4. The `trace-flags` byte in the echoed header MUST reflect the sampling decision that was applied to this request.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Request had valid traceparent | `incoming_trace_valid == true` | `00-{trace_id}-{response_span_id}-{flags}` | Echo original trace-id; use response span-id |
| Request had no traceparent (synthetic) | `incoming_trace_valid == false` | `00-{synthetic_trace_id}-{span_id}-01` | Echo synthetic root context |
| Sampling not applied (flags 00) | `trace_flags == "00"` | `00-{trace_id}-{span_id}-00` | Trace data not exported to backend |


---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
trace_context.version + "-" + trace_context.trace_id + "-" + trace_context.span_id + "-" + trace_context.trace_flags
```

---

### 7. Failure & Security Enforcement
- Must be present on every single 2xx, 4xx, and 5xx response.
- Enables clients and support engineers to correlate logs directly to traces.
- Response `traceparent` MUST match the trace-id of the request span — a mismatch indicates a middleware or proxy bug.
- Trace context MUST be forwarded to all downstream microservices, gRPC calls, and async event messages in the same transaction chain.
---

### 8. Protocol Wire Example

```http
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
```
