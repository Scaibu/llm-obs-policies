---
agent_role: "Distributed Tracing, Logging & Observability Standard Enforcer"
trigger: "ON_FEATURE_CREATION | ON_API_CREATION | ON_SERVICE_CREATION | ON_OBSERVABILITY_AUDIT"
scope: "OpenTelemetry Traces, Loki Structured Logs, HTTP Middleware, Error Propagation, Grafana Correlation"
mode: "Strict"
contract_version: "2.1"
enforcement: "Absolute & Non-Negotiable"
---

# Enterprise Distributed Tracing & Structured Logging Contract (`src/infra/observability/`)

> **Architectural Golden Rule of Telemetry:**  
> In a distributed systems engine, an error without a correlated trace span and structured log entry is considered an undetected system failure.  
> Every request, background job, message consumer, and state transition MUST propagate context, record span errors on failure paths, and ship structured logs to Grafana Loki via the OpenTelemetry Collector.

---

# PART I: STRICT GUARDRAILS (WHAT NOT TO DO AT ALL)

1. **NEVER Swallow Errors Without Tracing:** Never catch an error and return early without calling `observability.RecordError(span, err)` on the active trace span. Unrecorded errors produce "healthy" green spans in Grafana Tempo despite client-side failures.
2. **NEVER Use Raw `log.Print`, `log.Fatal`, or `fmt.Println` in Production Code:** Unstructured standard logs do not carry `trace_id`, `span_id`, or `tenant_id`. Always use `observability.GetLogger()` methods (`logger.Error`, `logger.Warn`, `logger.Info`).
3. **NEVER Treat 4xx Errors as Information Logs (`INFO`):** Client-side validation errors, missing `tenantId`, `404 Not Found`, and `409 Conflict` represent operational failures. The HTTP middleware and handlers must log all status codes `>= 400` as `WARN` or `ERROR`.
4. **NEVER Log Without Active Context:** Never pass `context.Background()` or `context.TODO()` to logger functions if an active request/execution context `ctx` is available. Doing so breaks trace ID extraction and decouples the log from the Tempo trace waterfall.
5. **NEVER Rely on Default OpenTelemetry No-Op Tracer:** The global tracer (`otel.Tracer`) must always be backed by an initialized SDK `TracerProvider` with an active batch exporter targeting `OTEL_EXPORTER_OTLP_ENDPOINT` (port 4318/4317).
6. **NEVER Block the Request Thread on Telemetry Exporters:** Telemetry export must use batch processors (`sdktrace.WithBatcher(exp)`) and asynchronous log forwarding (`go l.forwardToOtel(...)`) with timeouts so that telemetry outages never degrade API latency.
7. **NEVER Hardcode Trace/Span Identifiers in Log Messages:** Do not manually concatenate trace IDs into log strings (e.g., `logger.Info("trace=" + id)`). Trace IDs and Span IDs must be automatically extracted from `trace.SpanFromContext(ctx)` and populated into the top-level structured JSON schema.

---

# PART II: THE TRACING & LOGGING CONTRACT

## 1. Trace Context Propagation Hierarchy

Every execution path must establish a clear trace hierarchy:

```
[HTTP Request / Incoming Event]
  │
  ├── 1. Root Span: ObservabilityMiddleware (e.g., "GET /api/v1/workflow-definitions")
  │     ├── Sets W3C Response Headers: X-Trace-Id, X-Span-Id
  │     │
  │     └── 2. Handler Span: (e.g., "workflow_definitions.get")
  │           │
  │           └── 3. Domain Service Span: (e.g., "workflow_service.get")
  │                 │
  │                 └── 4. Storage Adapter Span: (e.g., "postgres.query")
```

## 2. Required Span Attributes
Every span must be initialized with standard OpenTelemetry semantic conventions:

| Attribute Key | Type | Description | Example |
|---|---|---|---|
| `service.name` | `string` | Service emitting the span | `distributed-transaction-engine` |
| `http.method` | `string` | HTTP verb for API spans | `POST`, `GET` |
| `http.target` | `string` | Normalized route path | `/api/v1/sagas/execute` |
| `http.status_code`| `int` | Returned HTTP status code | `200`, `400`, `500` |
| `tenant.id` | `string` | Multi-tenant customer partition | `tenant_corp_1` |
| `saga.id` | `string` | Active saga execution instance ID | `saga_01J8ABC...` |
| `fencing_token` | `int64` | Concurrency lease owner token | `42` |

---

# PART III: CRITICAL ERROR PATH SPECIFICATION

Whenever an operation encounters a failure condition (validation error, CAS mismatch, DB network drop, timeout), you MUST execute the **Three-Step Failure Invariant**:

```go
// 1. Record error on the active span (Sets status to codes.Error and attaches error stack)
observability.RecordError(span, err)

// 2. Emit structured log with error level and failure attributes
logger.Error(ctx, "descriptive error message",
    observability.String("error", err.Error()),
    observability.String("saga_id", sagaID),
    observability.String("tenant_id", tenantID),
    observability.Int("status_code", http.StatusBadRequest),
)

// 3. Return typed application error to caller
return nil, err
```

### Specific Failure Path Requirements:

#### A. Read API Failures (Missing Parameters & Not Found)
- Missing query/header parameters (`tenantId`, `id`) must record the validation error on the span and log `logger.Warn` with `path` and `status_code: 400`.
- Missing database records (`404 Not Found`) must record the error and log `logger.Error` with `status_code: 404` and the target resource ID.

#### B. Optimistic Concurrency & CAS Failures
- Stale version detected (`expected_version != current_version`): Must record `conflictErr` and log `logger.Warn` containing both `current_version` and `expected_version`.
- Stale fencing token detected (`submitted_token < current_token`): Must record `conflictErr` and log `logger.Warn` containing `current_token` and `submitted_token`.

#### C. Asynchronous & Poller Failures
- Background goroutines (e.g. `SagaPoller`) must create their own root spans via `tracer.StartSpan(ctx, "poller.claim")` and log lease expirations, circuit breaker trips, or dispatcher retry counts.

---

# PART IV: LOG-TO-TRACE CORRELATION IN GRAFANA (LOKI -> TEMPO)

To guarantee that any engineer or agent viewing logs in Grafana Loki can click directly into the Tempo trace waterfall:

1. **Loki Log Entry JSON Schema**:
   Every log message shipped to Loki MUST conform to the canonical JSON structure:
   ```json
   {
     "timestamp": "2026-11-03T09:02:32.958Z",
     "level": "ERROR",
     "service": "distributed-transaction-engine",
     "message": "HTTP request error",
     "trace_id": "f477409357f6caf1b0fa089821556362",
     "span_id": "37aa433afc8f8976",
     "tenant_id": "tenant_corp_1",
     "attributes": {
       "method": "GET",
       "path": "/api/v1/workflow-definitions",
       "status_code": 400
     }
   }
   ```

2. **Grafana Datasource Derived Field Invariant**:
   In `deploy/docker/compose/grafana-datasources.yaml`, Loki's derived field regex must match both quoted JSON keys and logfmt:
   ```yaml
   derivedFields:
     - datasourceUid: tempo
       matcherRegex: '(?:"trace_id"|"traceId"|trace_id|traceId)[":=\s]+([a-f0-9]{32})'
       name: TraceID
       url: '$${__value.raw}'
   ```

---

# PART V: IMPLEMENTATION CHECKLIST FOR NEW FEATURES

Before marking any feature, API, or service as complete:
- [ ] Has `observability.InitTracer` been called in `src/main.go`?
- [ ] Does the HTTP router wrap handlers in `observability.ObservabilityMiddleware`?
- [ ] Does the handler extract `traceparent` or start a child span with `h.tracer.StartSpan`?
- [ ] Are all error returns preceded by `observability.RecordError(span, err)`?
- [ ] Are all errors logged via `h.logger.Error(ctx, ...)` with active `ctx`?
- [ ] Are 4xx validation and not-found paths logged as `WARN`/`ERROR` instead of being silenced?
- [ ] Have you verified in Grafana (`http://localhost:3000`) that clicking `TraceID` in Loki opens the Tempo waterfall?
