---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_TELEMETRY_SETUP"
agent_role: "Principal Observability Architect & OpenTelemetry Semantic Auditor"
target_scope: "OpenTelemetry Standards, Metrics Cardinality, Structured Logging, Sampling & Traces"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Observability and Telemetry Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: OpenTelemetry Semantic Conventions Compliance
HTTP metrics and trace span names MUST follow OpenTelemetry Semantic Conventions:
- Duration: `http.server.request.duration` (histogram in seconds).
- In-flight: `http.server.active_requests` (gauge).
- Client Egress: `http.client.request.duration` (histogram in seconds).

Guardrail 2: Strict Cardinality Ceilings (Zero High-Cardinality Labels)
Metric tags/labels MUST NEVER include unbounded identifiers (user ID, tenant ID, raw request ID, email, or raw unparameterized URL paths). The `http.route` label MUST strictly use parameterized route patterns (e.g. `/api/v1/users/{id}`, never `/api/v1/users/1849204`). Unrecognized methods MUST map to `_OTHER`.

Guardrail 3: Closed Rejection Reason Enum
All admission, rate-limiting, and protocol rejections MUST increment a single unified counter `http_server_rejections_total` with a closed `reason` attribute:
`admission`, `rate_limit`, `quota`, `auth`, `authz`, `deadline_unviable`, `header_timeout`, `body_rate`, `header_too_large`, `body_too_large`, `smuggling_suspect`, `h2_reset_budget`, `client_cap`.

Guardrail 4: Structured Context-Propagated Logs
Every application log entry MUST be structured JSON and include: `timestamp_utc`, `level`, `instance_id`, `request_id`, `trace_id`, `span_id`, and `message`. Under heavy overload, successful 2xx logs MUST be sampled (e.g. 10%), while 100% of 4xx and 5xx errors MUST be retained.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside telemetry adapters. Document metrics schemas in the file header docblock.

---

## 2. Observability Contract

```yaml
observability_contract:
  metrics:
    namespace: "llmobs"
    semantic_conventions: "v1.24.0"
    duration_histogram_buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
    high_cardinality_prohibition: ["user_id", "tenant_id", "request_id", "raw_path"]
  rejections_enum:
    - "admission"
    - "rate_limit"
    - "quota"
    - "auth"
    - "authz"
    - "deadline_unviable"
    - "header_timeout"
    - "body_too_large"
  logging:
    format: "JSON"
    overload_success_sample_rate: 0.10
    error_sample_rate: 1.0
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Prometheus High-Cardinality Out of Memory Crash Fix**: Enforce route parameterization. Replace dynamic URLs (`/users/123/profile`) with route templates (`/users/{user_id}/profile`) before populating `http.route`.
2. **Missing Distributed Trace Correlation Fix**: In the root pipeline wrapper, extract `trace_id = span.get_span_context().trace_id` and inject it into the logger context filter so every downstream log line carries the trace ID automatically.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Use Raw Paths in Metric Labels
Ensure route templates are registered as metric labels; never use `request.url.path`.

### Instruction 2: Single Global Rejection Counter
Use `http_server_rejections_total{reason=...}` rather than creating distinct ad-hoc counters per failure mode.
