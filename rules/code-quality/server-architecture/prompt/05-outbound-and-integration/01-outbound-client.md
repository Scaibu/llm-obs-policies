---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_CLIENT_CREATION"
agent_role: "Principal Distributed Infrastructure Engineer & Client Pool Auditor"
target_scope: "Outbound Connection Pools, Egress Deadlines, Cancellation Cascade, DNS Discovery & Ephemeral Ports"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Outbound Client Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Per-Upstream Pool Isolation (Never Shared Globally)
Every outbound dependency MUST own an isolated connection pool with independent ceilings (max connections, max pending queue, max concurrent multiplexed streams). A shared global client connection pool is strictly prohibited; a single stalled downstream service must never consume connections allocated to healthy services.

Guardrail 2: Multi-Tier Egress Timeout Hierarchy
Outbound calls MUST enforce four distinct timeouts:
1. `connect_timeout`: Fast network dial deadline (maximum: 2000ms).
2. `request_timeout`: Clamped dynamically: $\min(\text{route\_budget}, \text{remaining\_inbound\_deadline} - 50\text{ms})$.
3. `client_idle_timeout`: Strictly less than the downstream server's idle timeout to prevent connection close race conditions.
4. `max_connection_lifetime`: Periodic connection cycling (default: 300s) to discover DNS updates and IP rotations.

Guardrail 3: Downstream Deadline & Cancellation Cascade
The remaining request deadline MUST be propagated downstream via standard headers (`grpc-timeout` or `request-timeout`). If `remaining_deadline < downstream_min_duration`, the call MUST NOT be sent. If the inbound client disconnects, all active outbound calls MUST be canceled immediately.

Guardrail 4: Stale-on-Error DNS Discovery Invariant
Service endpoint resolution MUST cache discovered IP endpoints. If the service discovery registry or DNS server becomes temporarily unreachable, the client MUST keep serving from its last-known-good endpoint set rather than dropping to an empty host list.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside outbound client wrappers. Document connection pool sizing and timeout budgets in the file header docblock.

---

## 2. Outbound Client Contract

```yaml
outbound_client_contract:
  pool:
    max_connections: 100
    max_pending_requests: 50
    http2_max_concurrent_streams: 100
  timeouts:
    connect_timeout_ms: 2000
    client_idle_timeout_ms: 55000
    max_connection_lifetime_ms: 300000
    safety_margin_per_hop_ms: 50
  discovery:
    refresh_interval_ms: 10000
    stale_on_error: true
  load_balancing: "POWER_OF_TWO_LEAST_REQUEST"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Premature Socket Reset on Idle Re-use Fix**: Configure `client_idle_timeout: 55s` when downstream server has a 60s idle timeout. The client closes the socket before the server does, preventing "Broken pipe" or "Connection reset by peer" errors.
2. **DNS IP Change Blackhole Fix**: Enforce `max_connection_lifetime: 300s`. Persistent HTTP/1.1 or HTTP/2 connections are gracefully re-established every 5 minutes, ensuring newly scaled Kubernetes pods receive traffic.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Send Outbound Calls Without Deadlines
Always compute and attach an explicit deadline to the outbound context before executing HTTP/gRPC requests.

### Instruction 2: Attach OpenTelemetry Client Metrics
Emit `http.client.request.duration` and track `pool_connections{upstream, state}`.
