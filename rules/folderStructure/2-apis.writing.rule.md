---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_API_CREATION"
agent_role: "Chief API Standards Officer & Protocol Security Auditor"
target_scope: "All API Routers, Handlers, Request DTOs, Response Envelopes, Headers & Middleware"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# API Writing Rules & Delivery Ingress Standards

(Universal Language-Agnostic Operational Rule for Polyglot Sub-Packages in Go, Python, Rust, Dart, Java, C#, C++, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Strict Response Envelope Invariant
Every HTTP REST response MUST wrap its payload in `success`, `statusCode`, `data`/`error`, and `meta`. Naked JSON objects or arrays are strictly prohibited.

Guardrail 2: Root-Cause Database Idempotency & Concurrency Invariant
Do not treat idempotency and race conditions as HTTP-layer symptoms. Idempotency and mutation safety MUST be enforced at the root database storage layer via unique constraints (`(tenant_id, idempotency_key)`), atomic SQL conditional updates (`WHERE id = :id AND version = :version`), and Transactional Outbox tables to eliminate dual-write partial failures.

Guardrail 3: Mandatory Identifier & W3C Trace Header Ingestion
All API handlers MUST extract and propagate `traceparent`, `x-request-id`, `x-correlation-id`, `x-tenant-id`, and `x-client-id`.

Guardrail 4: Hexagonal Boundary Isolation (Zero DB/Driver in Handlers)
Handlers MUST interact only with Domain Services. Never import database drivers, connection pools, or SQL strings into delivery handlers or routers.

Guardrail 5: Zero Float for Currency & String-Serialized 64-Bit IDs
Floating-point numbers for money and unquoted 64-bit integers are strictly forbidden in wire contracts. Money MUST be a structured decimal string object or integer cents; large IDs MUST be strings.

Guardrail 6: Closed-Schema Request Validation
All request schemas MUST enforce `additionalProperties: false`. Undeclared fields trigger validation failure.

Guardrail 7: Optimistic Concurrency Invariant (`ETag` / `If-Match`)
All mutating updates on versioned resources MUST enforce the `If-Match` header against the current resource `ETag`, verified atomically in SQL storage.

Guardrail 8: Zero Inline Comments Doctrine
Never write mid-function inline comments inside handler or router functions. Document the entire algorithmic workflow in the file header docblock.

Guardrail 9: PII & Credential Shielding Invariant
Passwords, API secrets, raw stack traces, and internal hostnames MUST NEVER appear in response bodies, logs, or error metadata.

Guardrail 10: Mandatory OpenAPI Contract Sync Invariant (v1.yml)
Every API endpoint creation, modification, or deprecation MUST be immediately synchronized with the package OpenAPI contract file at `contracts/openapi/v1.yml`. Implementation routers/handlers and `v1.yml` must never diverge.

---

## 2. Unified Request & Response Contract

```yaml
request:
  protocol:
    content_type: "application/json"
    max_body_bytes: "Enforced at ingress gateway"
  headers:
    traceparent: { type: string, required: true, fallback: "auto_generate_w3c_trace_context" }
    x-request-id: { type: string, required: true }
    x-correlation-id: { type: string, required: true }
    x-causation-id: { type: string, required: true }
    x-idempotency-key: { type: string, required: true, applies_to: ["POST", "PUT", "PATCH", "DELETE"] }
    x-tenant-id: { type: string, required: true }
    x-client-id: { type: string, required: true }
    x-user-id: { type: string, required: true }
    Authorization: { type: string, required: true }
    x-api-version: { type: string, required: true }
    If-Match: { type: string, required: true, applies_to: ["PUT", "PATCH", "DELETE"] }
    x-audit-actor-id: { type: string, required: true, applies_to: ["POST", "PUT", "PATCH", "DELETE"] }
  body_rules:
    validation: "additionalProperties: false (strictly closed schema)"
    timestamps: "Strictly ISO 8601 UTC with milliseconds (YYYY-MM-DDTHH:MM:SS.sssZ)"
    currency: "Never float. Use structured decimal object {'amount': '249.50', 'currency': 'USD'} or integer cents"
    identifiers: "String-serialized UUIDv7 or prefixed strings (usr_99812)"
    booleans: "Strict boolean literals true or false"
    write_only: "Passwords, tokens, and secrets must never be echoed in responses or logs"

response:
  headers:
    traceparent: "Echoed W3C trace context"
    x-request-id: "Echoed x-request-id"
    x-correlation-id: "Echoed x-correlation-id"
    ETag: "Resource version ETag"
    Retry-After: "Mandatory on 429 and 503 responses"
  envelope:
    success: boolean # true for 2xx, false for 4xx/5xx
    statusCode: integer # HTTP status code
    data: "T | null" # Payload object/array on success; null on failure
    error: # Error object on failure; null on success
      code: string # Canonical error code (e.g. VALIDATION_FAILED, CONFLICT)
      message: string # Human-readable explanation
      retryable: boolean # Whether client may safely retry
      details: # Field-level constraint violation items
        - field: string
          issue: string
          rule: string
          rejectedValue: any
    meta:
      requestId: string # Echoed x-request-id
      correlationId: string # Echoed x-correlation-id
      causationId: string # Echoed x-causation-id
      timestamp: string # ISO 8601 UTC execution timestamp
      executionTimeMs: integer # Server processing duration in ms
      apiVersion: string # Resolved API contract version
      pagination: # Optional: list endpoints only
        page: integer
        pageSize: integer
        totalItems: integer
        totalPages: integer
        hasNextPage: boolean
        hasPreviousPage: boolean
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Storage Deduplication Fix**: Add a `UNIQUE (tenant_id, idempotency_key)` index in `database/migrations/`. In the repository adapter, catch the database unique violation and map it to a domain `ConflictError`.
2. **Optimistic Locking Fix**: In `queries/{feature}.queries.sql`, append `WHERE id = :id AND version = :expected_version` and set `version = version + 1`. If rows affected is 0, throw `PreconditionFailedError` (mapped to HTTP 412).
3. **Dual-Write Outbox Fix**: In the domain service transaction, write the event payload into the `infra_outbox` table in the SAME database transaction as the entity mutation. Never call Kafka producers directly inside the mutation block.
4. **Timeout / Unknown State Fix**: Wrap external calls with explicit deadline timeouts. When a timeout occurs, do NOT persist the failure in the idempotency store; return HTTP 504 so the client can safely retry with the same `x-idempotency-key`.
5. **Concurrent Double-Click Fix**: Before executing domain logic, acquire a distributed lock on `x-idempotency-key` with a 30s TTL. If lock acquisition fails, immediately return HTTP 409 with header `Retry-After: 1`.
6. **PATCH Partial Mutation Fix**: In request DTO deserialization, explicitly distinguish omitted fields (leave untouched) from explicit `null` values (set column to NULL in database).
7. **Read-Your-Writes Fix**: In mutating POST, PUT, and PATCH handlers, return the complete freshly persisted entity directly inside `data` in the response envelope so clients do not execute immediate secondary reads.
8. **Rate Limit / Backpressure Fix**: In rate-limiting and circuit-breaking middleware, compute reset window seconds and inject the `Retry-After: <seconds>` header on all 429 and 503 responses.
9. **PII & Topology Sanitization Fix**: In the global exception handler, strip raw SQL errors, database column names, and stack traces before serializing the error envelope.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Verify Domain Service Existence First
Verify `src/features/{feature}/service/{feature}.service.[ext]` and `types/` exist before creating handlers.

### Instruction 2: Implement Delivery Handler (`src/api/rest/v1/handlers/{feature}.handler.[ext]`)
1. Write top-level architectural blueprint in the file header docblock (zero mid-function comments).
2. Ingest transport headers (`traceparent`, `x-request-id`, `x-correlation-id`, `x-idempotency-key`).
3. Parse and validate request DTO with closed validation (`additionalProperties: false`).
4. Invoke Domain Service method inside an active OpenTelemetry span.
5. Catch domain exceptions and map to canonical envelope (`success: false`, `statusCode`, `error`, `meta`).
6. Return standard RFC envelope on success (`success: true`, `statusCode`, `data`, `meta`).

### Instruction 3: Implement Delivery Router (`src/api/rest/v1/routers/{feature}.router.[ext]`)
1. Mount endpoints using route paths and base prefixes declared in `config/` (`config/endpoints.yaml` or `config/default.yaml`) with explicit HTTP verbs (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`).
2. Attach authentication, rate-limiting, and validation middleware.
3. Wire route endpoints directly to handler methods with zero business logic in routers.

### Instruction 4: Synchronize OpenAPI Contract (`contracts/openapi/v1.yml`)
Immediately after adding or updating an API router/handler, update `contracts/openapi/v1.yml` with the endpoint path, HTTP method, request schema, response envelope, and status codes.

### Instruction 5: Verify Implementation via Tests
Run automated unit and router integration tests:
```bash
pytest tests/unit/ -k "{feature}"
```
