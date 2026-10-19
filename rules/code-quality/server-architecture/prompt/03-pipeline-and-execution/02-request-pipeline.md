---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_PIPELINE_CREATION"
agent_role: "Principal Systems Architect & Request Pipeline Auditor"
target_scope: "Request Middleware Chain, 12-Stage Pipeline Order, Envelope Wrapping & Ingress Enforcement"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Request Pipeline Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Strict 12-Stage Pipeline Order (Cheapest to Most Expensive)
Every incoming request MUST pass through the following 12 stages in exact sequence:
1. **Request Identity**: Generate UUIDv7 `x-request-id`; accept `traceparent` only from trusted hops (fallback: auto-generate).
2. **Peer Resolution**: Resolve authentic client IP via right-to-left proxy traversal.
3. **Global Admission**: Reject if global in-flight $\ge$ capacity (HTTP 503 + `Retry-After`).
4. **Route Resolution**: Pure pattern match (fail: 404 No Route / 405 Method Not Allowed + `Allow`).
5. **Per-Route Limits**: Check declared headers (413 Payload Too Large / 415 Unsupported Media Type / 431 Request Header Fields Too Large).
6. **Pre-Auth Rate Limiting**: Keyed by resolved peer IP (protects auth layer from credential stuffing; fail: 429 + `Retry-After`).
7. **Authentication**: Verify bearer tokens/mTLS over headers only (body remains unread; fail: 401 + `WWW-Authenticate`).
8. **Coarse Authorization**: Verify principal scopes $\supseteq$ route scopes (fail: 403 Forbidden).
9. **Per-Identity Quota**: Rate-limiting keyed by authenticated `principal_id` (fail: 429 + `Retry-After`).
10. **Deadline Computation**: Budget = $\min(\text{route.max}, \text{inherited} - \text{margin})$; fail fast with 504 / `DEADLINE_EXCEEDED` if budget $< \text{route.min}$.
11. **Priority Admission**: Per-class concurrency shedding (shed background/batch classes first; fail: 503 + `Retry-After`).
12. **Handler Ingress**: Send `100 Continue` (if requested), stream body under rate limits, invoke domain service.

Guardrail 2: RFC 9457 Problem Details Envelope
All error responses across all pipeline stages MUST wrap failure payloads in standard RFC 9457 JSON:
`type` (stable URI), `title`, `status`, `detail`, `instance` (echoed request ID). Naked errors are forbidden.

Guardrail 3: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies. Document the entire pipeline stage execution map in the file header docblock.

---

## 2. Pipeline Execution Contract

```yaml
pipeline_stages:
  1_identity: { cost: "trivial", actions: ["generate_request_id", "sanitize_traceparent"] }
  2_peer: { cost: "trivial", actions: ["resolve_client_ip_right_to_left"] }
  3_global_admission: { cost: "trivial", on_fail: "503_retry_after" }
  4_route: { cost: "pure_lookup", on_fail: "404_or_405_allow" }
  5_route_limits: { cost: "cheap_headers", on_fail: "413_415_431" }
  6_pre_auth_limit: { cost: "cheap_ip_bucket", on_fail: "429_retry_after" }
  7_auth: { cost: "expensive_crypto", headers_only: true, on_fail: "401_www_authenticate" }
  8_authz: { cost: "cheap_set_check", on_fail: "403_forbidden" }
  9_identity_quota: { cost: "medium_tenant_bucket", on_fail: "429_retry_after" }
  10_deadline: { cost: "trivial", calc: "min(route.max, inherited - margin)" }
  11_priority_admission: { cost: "trivial", shed_order: ["batch", "background", "interactive"] }
  12_handler: { cost: "unbounded_domain", stream_body: true }
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Authentication Denial of Service Fix**: Place Stage 6 (IP rate limit) before Stage 7 (Auth). Credential stuffing attacks are throttled by peer IP before expensive JWT signature verification or database lookups execute.
2. **Unchecked Inherited Deadline Fix**: Never trust an inbound `request-timeout` header blindly. In Stage 10, clamp: `deadline = min(route.max_timeout, client_timeout - 50ms)`. If `deadline < route.min_timeout`, return HTTP 504 immediately without executing the handler.
3. **Body Read Memory Exhaustion Fix**: In Stage 5, check the `Content-Length` header before reading a single byte. If `Content-Length > route.max_body_bytes`, return HTTP 413 immediately and do not buffer the body.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Strict Stage Sequencing
Never swap pipeline stages (e.g. running auth before route limits or reading body before auth). Follow stages 1 to 12 in linear order.

### Instruction 2: Wrap Pipeline in Outer Error Boundary
Catch unhandled exceptions at the root pipeline wrapper, format as RFC 9457 Problem Details with sanitized internal messages, and emit access log entries.
