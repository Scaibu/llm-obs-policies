---
agent_role: "Universal Observability, Distributed Tracing & Reliability Compliance Enforcer"
trigger: "ON_FEATURE_CREATION | ON_API_CREATION | ON_SERVICE_CREATION | ON_OBSERVABILITY_AUDIT | ON_CODEGEN"
scope: "Distributed Tracing, Structured Logging, Context Propagation, Error Path Telemetry, Ingress/Egress Boundaries, Cross-Signal Correlation"
mode: "Strict & Autonomous"
contract_version: "3.0"
enforcement: "Absolute & Non-Negotiable"
language_neutral: true
---

# Universal Distributed Tracing & Structured Telemetry Contract

> **The Axiom of Observable Distributed Systems:**  
> In a distributed systems architecture, any failure, rejected request, degraded execution, or state inconsistency that cannot be pinpointed within 60 seconds through correlated traces and logs is an architectural defect.  
> Telemetry is not an afterthought; it is a first-class operational invariant. Every runtime, service layer, background worker, and asynchronous event boundary—regardless of programming language (Go, Rust, C++, Python, TypeScript, Java)—MUST implement end-to-end trace propagation, explicit error span recording, and structured log-to-trace correlation.

---

# PART I: NON-NEGOTIABLE NEGATIVE GUARDRAILS (WHAT MUST NEVER BE DONE)

These are absolute prohibitions. Systems, AI agents, code generators, and software engineers must reject any implementation containing the following anti-patterns:

1. **NEVER Swallow or Map Errors Without Recording on the Active Span:**  
   Silently catching an exception, mapping an error to an HTTP status code, or recovering from a panic without explicitly marking the active span as `ERROR` and attaching the error description is strictly forbidden. An unrecorded error produces a deceptively "healthy" green trace in Grafana Tempo despite user-facing failures.
2. **NEVER Use Unstructured Standard Output (`stdout`/`stderr`) Prints:**  
   Raw `print`, `println`, `printf`, `console.log`, `std::cout`, or standard library `log.Print` calls are prohibited in production paths. Unstructured text lines lack context, tenant identity, and trace IDs, rendering them unsearchable in modern log aggregators.
3. **NEVER Downgrade 4xx Client Errors to `INFO` or Silent Drops:**  
   Client-side rejections (`400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `409 Conflict`, `422 Unprocessable Entity`) represent broken contracts, malicious probes, or client integration failures. They MUST be logged as `WARN` or `ERROR` and stamped with contextual failure attributes.
4. **NEVER Emit Logs Without Active Context / Trace Correlation:**  
   Logging functions must never be invoked without passing the active request context. A log line emitted without an extracted `trace_id` and `span_id` breaks the trace-to-log drill-down in Grafana and is classified as "orphaned telemetry."
5. **NEVER Use a Dummy or Uninitialized No-Op Tracer in Production:**  
   Relying on a default global tracer without initializing an authentic OpenTelemetry SDK `TracerProvider` with an operational OTLP HTTP/gRPC exporter is prohibited. Telemetry must be backed by live network export to the OpenTelemetry Collector (port 4317/4318).
6. **NEVER Block the Main Execution Thread on Telemetry Export:**  
   Telemetry pipelines must never introduce synchronous network blocking on application threads. Traces must use background batch processors with ring buffers; log forwarding to external telemetry collectors must be asynchronous or managed via background daemons. A telemetry outage must NEVER take down API availability.
7. **NEVER Hardcode Trace Identifiers in Free-Form Log Strings:**  
   String formatting such as `"Handling request trace=" + id` is strictly banned. Trace identifiers, Span identifiers, and Tenant identifiers must reside in dedicated top-level JSON fields or structured metadata keys.
8. **NEVER Log Unsanitized PII, Raw Credentials, or High-Entropy Secrets:**  
   Passwords, API keys, JWT signatures, authorization bearer tokens, credit card numbers, and cryptographic private keys must NEVER appear in trace attributes or log payloads. Mask or drop sensitive fields at the boundary.

---

# PART II: THE UNIVERSAL TRACE HIERARCHY & LIFECYCLE

Regardless of the programming language or runtime, every transaction must traverse an immutable four-tier span hierarchy:

```
[External Request / Message Ingestion]
  │
  ├── 1. Ingress / Middleware Span (SERVER / CONSUMER)
  │     │   Name:   "{HTTP_METHOD} {ROUTE_TEMPLATE}" | "consume {TOPIC_NAME}"
  │     │   Role:   Extracts W3C TraceContext; generates root span if absent.
  │     │
  │     └── 2. Handler / Gateway Span (INTERNAL)
  │           │   Name:   "{feature_name}.{operation}"
  │           │   Role:   Validates inputs, maps headers, extracts Tenant ID.
  │           │
  │           └── 3. Domain Service Span (INTERNAL)
  │                 │   Name:   "{domain_service}.{business_action}"
  │                 │   Role:   Executes business logic, DAG evaluations, CAS state updates.
  │                 │
  │                 └── 4. Infrastructure / Storage Span (CLIENT / PRODUCER)
  │                         Name:   "{driver}.{query_type}" | "publish {TOPIC_NAME}"
  │                         Role:   Network I/O to Postgres, Redis, Kafka, or downstream APIs.
```

### Lifecycle Rules:
1. **Creation:** A span must be created at the exact entry point of a scope.
2. **Context Binding:** The span must be injected into the execution context so that child routines, helper functions, and database clients inherit the span.
3. **Completion:** Every span MUST be closed via a deterministic cleanup mechanism (`defer span.End()`, `finally { span.end(); }`, RAII destructor, or `try-with-resources`) to guarantee completion under all return paths and exceptions.

---

# PART III: THE LANGUAGE-AGNOSTIC THREE-STEP FAILURE INVARIANT

Whenever an execution branch encounters an error (validation rejection, database constraint error, lock conflict, timeout, or external dependency failure), the following three steps MUST be executed:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   THREE-STEP FAILURE INVARIANT                         │
├────────────────────────────────────────────────────────────────────────┤
│ 1. RECORD ON SPAN   │ Mark span status as ERROR; attach message & stack│
│ 2. EMIT STRUCTURED  │ Write log at WARN/ERROR level with context attrs │
│ 3. TYPED RETURN     │ Return typed domain/application error to caller  │
└────────────────────────────────────────────────────────────────────────┘
```

### Detailed Failure Class Specifications:

#### 1. Client Validation & Not-Found Paths (4xx Class)
- **Condition:** Missing required headers (`x-tenant-id`), malformed JSON payloads, invalid DAG dependencies, entity ID not found in database.
- **Span Action:** Set span status to `Error`. Record attribute `error.type = "VALIDATION_FAILED"` or `"NOT_FOUND"`.
- **Log Action:** Emit structured log at `WARN` (or `ERROR` if unhandled):
  - `message`: Clear failure explanation (e.g., `"missing tenant_id in request"`).
  - Attributes: `http.status_code`, `path`, `method`, `tenant_id`, `error`.

#### 2. Concurrency, CAS & Version Conflicts (409 Conflict Class)
- **Condition:** Optimistic concurrency control (OCC) version mismatch, stale fencing token detected, or duplicate idempotency key detected.
- **Span Action:** Set span status to `Error`. Attach attributes:
  - `conflict.current_version`, `conflict.expected_version`
  - `fencing.current_token`, `fencing.submitted_token`
- **Log Action:** Emit structured log at `WARN`:
  - `message`: `"optimistic concurrency CAS conflict"` or `"stale fencing token rejected"`.

#### 3. Storage, Broker & Infrastructure Outages (5xx Class)
- **Condition:** Database connection failure, query syntax error, Redis eviction/timeout, Kafka leader election failure, downstream HTTP timeout.
- **Span Action:** Set span status to `Error`. Set `span.RecordError(err)`. Attach attribute `error.stack`.
- **Log Action:** Emit structured log at `ERROR`:
  - `message`: `"database transaction failure"` or `"kafka publish failed"`.
  - Attributes: `db.system`, `db.operation`, `error`, `duration_ms`.

---

# PART IV: UNIVERSAL CONTEXT PROPAGATION & HEADERS

All services participating in the distributed transaction engine must comply with **W3C Trace Context (Level 1)**:

### 1. Inbound & Outbound Header Contract
| Header Name | Standard | Purpose | Format / Syntax |
|---|---|---|---|
| `traceparent` | W3C Recommendation | Carries version, trace ID, parent span ID, and trace flags. | `00-{trace_id_32hex}-{span_id_16hex}-{flags_2hex}` |
| `tracestate` | W3C Recommendation | Carries vendor-specific routing and filtering tags. | `congo=t61rcWkgMzE,rojo=00f067aa0ba902b7` |
| `X-Tenant-Id` | Enterprise Standard | Carries customer tenant partitioning identity. | String identifier (e.g., `tenant_corp_01`) |
| `X-Trace-Id` | Diagnostic Mirror | Mirrors the 32-character hex trace ID in HTTP responses. | `5a4ef20c3a12da631202557893a9f739` |
| `X-Span-Id` | Diagnostic Mirror | Mirrors the 16-character hex span ID in HTTP responses. | `37aa433afc8f8976` |

### 2. Message Broker Context Injection
When publishing messages to Apache Kafka or Google Cloud Pub/Sub:
- Do NOT serialize trace IDs into the business JSON body.
- Inject the active `traceparent` and `tracestate` directly into **Kafka Record Headers** or **Pub/Sub Message Attributes**.
- Consumers must extract the headers and start consumer spans linked to the producer's parent span.

---

# PART V: LOG-TO-TRACE CORRELATION SCHEMA (LOKI & TEMPO)

To ensure that logs and traces seamlessly cross-link inside Grafana without custom manual querying:

### 1. Canonical Structured JSON Log Schema
Every log entry formatted by the logging subsystem MUST serialize into this canonical JSON contract:

```json
{
  "timestamp": "2026-11-03T09:02:32.958145Z",
  "level": "ERROR",
  "service": "distributed-transaction-engine",
  "message": "HTTP request error",
  "trace_id": "5a4ef20c3a12da631202557893a9f739",
  "span_id": "37aa433afc8f8976",
  "tenant_id": "tenant_corp_1",
  "attributes": {
    "duration_ms": 12,
    "error": "stale version detected: reload required",
    "http.method": "POST",
    "http.status_code": 409,
    "http.target": "/api/v1/sagas/transitions",
    "saga_id": "saga_01J8ABC12345"
  }
}
```

### 2. Grafana Loki Derived Field Invariant
The Grafana Loki provisioning manifest (`deploy/docker/compose/grafana-datasources.yaml`) MUST configure the universal regex to identify the 32-character trace ID in both JSON and raw log formats:

```yaml
derivedFields:
  - datasourceUid: tempo
    matcherRegex: '(?:"trace_id"|"traceId"|trace_id|traceId)[":=\s]+([a-f0-9]{32})'
    name: TraceID
    url: '$${__value.raw}'
```

---

# PART VI: MULTI-LANGUAGE IMPLEMENTATION BLUEPRINTS

### 1. Go Implementation Pattern
```go
func HandleOperation(w http.ResponseWriter, r *http.Request) {
    ctx, span := tracer.StartSpan(r.Context(), "operation.execute")
    defer span.End()

    result, err := service.Execute(ctx, input)
    if err != nil {
        observability.RecordError(span, err)
        logger.Error(ctx, "operation execution failed",
            observability.String("error", err.Error()),
            observability.Int("status_code", http.StatusBadRequest),
        )
        writeErrorResponse(w, http.StatusBadRequest, err)
        return
    }
    writeSuccessResponse(w, http.StatusOK, result)
}
```

### 2. Rust Implementation Pattern
```rust
#[tracing::instrument(skip(service, input), fields(trace_id, span_id, tenant_id))]
pub async fn handle_operation(
    Extension(service): Extension<Arc<Service>>,
    Json(input): Json<OperationInput>,
) -> Result<Json<OperationOutput>, AppError> {
    match service.execute(input).await {
        Ok(res) => Ok(Json(res)),
        Err(err) => {
            tracing::error!(
                error = %err,
                status_code = err.status_code(),
                "operation execution failed"
            );
            Err(err)
        }
    }
}
```

### 3. TypeScript / Node.js Implementation Pattern
```typescript
async function handleOperation(req: Request, res: Response): Promise<void> {
  const tracer = trace.getTracer('operation-service');
  return tracer.startActiveSpan('operation.execute', async (span) => {
    try {
      const result = await service.execute(req.body);
      res.status(200).json(result);
    } catch (err: any) {
      span.recordException(err);
      span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
      logger.error('operation execution failed', {
        error: err.message,
        status_code: err.statusCode || 500,
        trace_id: span.spanContext().traceId,
      });
      res.status(err.statusCode || 500).json({ error: err.message });
    } finally {
      span.end();
    }
  });
}
```

### 4. Python Implementation Pattern
```python
def handle_operation(request):
    tracer = trace.get_tracer("operation-service")
    with tracer.start_as_current_span("operation.execute") as span:
        try:
            result = service.execute(request.data)
            return Response(result, status=200)
        except Exception as err:
            span.record_exception(err)
            span.set_status(Status(StatusCode.ERROR, str(err)))
            logger.error(
                "operation execution failed",
                extra={
                    "error": str(err),
                    "status_code": getattr(err, "status_code", 500),
                    "trace_id": format(span.get_span_context().trace_id, "032x"),
                },
            )
            return Response({"error": str(err)}, status=getattr(err, "status_code", 500))
```

---

# PART VII: PRE-MERGE TELEMETRY COMPLIANCE CHECKLIST

Before merging or approving any code relating to APIs, features, state transitions, or message handlers, verify every item:

- [ ] **Tracer Registration:** The runtime initializes an authentic OpenTelemetry SDK `TracerProvider` with active network export.
- [ ] **Span Wrapping:** Every public API route, queue consumer, and background worker wraps its execution in a named span.
- [ ] **W3C Context Propagation:** Ingress requests extract `traceparent`; egress clients and event publishers inject `traceparent`.
- [ ] **Three-Step Failure Invariant:** Every `return err` or exception block records the error on the span, emits a structured log with `trace_id` and attributes, and returns a typed error.
- [ ] **4xx Error Capture:** Validation rejections, malformed requests, and not-found misses are logged at `WARN` or `ERROR` with the active span marked as `Error`.
- [ ] **No Raw Prints:** Zero instances of standard library raw prints (`fmt.Print`, `console.log`, `print`, `std::cout`) in business logic.
- [ ] **Grafana Verification:** The log entry appears in Grafana Loki and contains a functional, clickable `TraceID` derived-field link that loads the corresponding trace in Grafana Tempo.
