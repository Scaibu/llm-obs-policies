---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_SERVER_CREATION"
agent_role: "Principal Systems Architect & Protocol Governance Auditor"
target_scope: "System Boundary Definition, Protocol Scope, Idempotency Storage, Tenant Isolation & Compliance"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Scope Decisions & Protocol Boundary Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: HTTP/3 & QUIC Termination Boundary Invariant
HTTP/3 (UDP/QUIC) MUST NEVER be terminated inside application backend processes. Termination of QUIC, 0-RTT handshakes, and UDP flood mitigation MUST occur strictly at the infrastructure edge proxy (Envoy, Cloudflare, ALB). Backend services MUST accept clean, proxied HTTP/1.1 or HTTP/2 transport.

Guardrail 2: Root-Cause Distributed Idempotency Invariant
Do not treat idempotency as an in-memory or purely HTTP-layer concern. Idempotency keys (`x-idempotency-key`) MUST be backed by an external distributed store (Redis/DB) with explicit TTLs (default: 24h). On concurrent duplicate requests, the server MUST NOT process in parallel: it MUST either return HTTP 409 with `Retry-After: 1` or atomically wait on a distributed lease. Replayed responses MUST preserve the original status, headers, and payload.

Guardrail 3: BREACH Defense & Secrets Compression Prohibition
Dynamic HTTP compression (gzip, brotli, zstd) MUST NEVER be applied to responses that contain both reflection of user/attacker input and sensitive tokens/secrets (CSRF tokens, session IDs, authorization keys). When secrets are present, compression MUST be disabled via header suppression.

Guardrail 4: Multi-Tenant Fair Queuing Invariant
Per-tenant rate quotas alone are insufficient. Server admission MUST implement fair queuing (e.g. Deficit Round Robin or per-tenant token buckets) across concurrent tenants so that a burst from tenant A cannot starve latency-critical requests from tenant B.

Guardrail 5: Contract-First Body Schema Source of Truth
Body schema validation MUST NOT be implemented ad-hoc inside handler code. Schemas MUST derive directly from the canonical contract artifact (`contracts/openapi/v1.yml` or Proto/JSON Schema). Validation MUST execute early in the pipeline with `additionalProperties: false`.

Guardrail 6: Tamper-Evident Audit Logging Separation
Audit logs (security mutations, privilege escalations, financial adjustments) MUST be strictly separated from ephemeral operational access logs. Audit logs MUST be write-only, tamper-evident (cryptographically hashed or forwarded to immutable append-only sinks), and retain a minimum 365-day compliance policy.

Guardrail 7: Clock Skew Tolerance Bounds
All cross-host time validations (JWT expiration, HMAC timestamps, distributed deadline timeouts) MUST enforce an explicit, bounded clock skew tolerance window (maximum: ±3000ms). Never assume zero clock drift across nodes.

Guardrail 8: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies. Document the entire architectural boundary rationale in the file header docblock.

---

## 2. Scope & Governance Matrix

```yaml
scope_decision_matrix:
  transport:
    http3_quic: "Edge proxy termination only; backend strictly HTTP/1.1 or HTTP/2"
    edge_protocol_negotiation: "ALPN enforced at proxy: h2, http/1.1"
  idempotency:
    storage: "Distributed key-value store (Redis) or SQL unique constraint"
    ttl_seconds: 86400
    concurrent_duplicate_behavior: "HTTP 409 Conflict with Retry-After: 1"
    replayed_header: "x-cache-lookup: IDEMPOTENT_REPLAY"
  compression:
    enabled_types: ["application/json", "text/plain", "application/xml"]
    minimum_bytes: 1024
    breach_defense: "Disabled if Authorization or Set-Cookie header present with query reflection"
  tenant_isolation:
    admission_policy: "Per-tenant concurrency caps + Deficit Round Robin queue"
  schema_validation:
    source_of_truth: "contracts/openapi/v1.yml"
    enforcement_point: "Pipeline Stage 7 (pre-handler)"
  clock_skew:
    max_tolerance_ms: 3000
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Concurrent Duplicate Mutation Fix**: Catch duplicate `x-idempotency-key` via distributed lock acquisition. If locked, return HTTP 409 immediately with `Retry-After: 1`. Do not execute business logic twice.
2. **BREACH Vulnerability Fix**: In response compression middleware, inspect response headers. If `Set-Cookie` or `x-sensitive-token` is present, bypass compression completely (`Content-Encoding: identity`).
3. **Noisy Neighbor Tenant Fix**: When total concurrency hits 80% capacity, throttle tenants exceeding their proportional fair-share limit by returning HTTP 429 with `Retry-After: 5`.
4. **Clock Skew Reject Fix**: In JWT/HMAC token validation, verify `nbf - 3000ms <= now <= exp + 3000ms`. If outside bounds, return HTTP 401 Unauthorized with detail `TOKEN_TIME_DRIFT_EXCEEDED`.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Verify Scope Boundaries Before Coding
Before generating server entry points or routers, verify whether edge proxy handles TLS/HTTP3 and ensure no raw UDP sockets are opened inside backend services.

### Instruction 2: Enforce Idempotency Storage Contract
Ensure all mutating operations (`POST`, `PUT`, `PATCH`) validate `x-idempotency-key` against the distributed cache interface before reaching the domain service.

### Instruction 3: Zero Comments In Function Bodies
Implement all scope checks, validations, and handlers with 100% comment-free function bodies.
