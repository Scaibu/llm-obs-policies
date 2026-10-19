---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_CONNECTION_MANAGER_CREATION"
agent_role: "Principal Infrastructure Engineer & Traffic Flow Auditor"
target_scope: "Connection Lifecycles, Registry, State Transitions, Limits & Concurrency Caps"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Connection Manager Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Complete Connection Lifecycle Registry
Every admitted socket connection MUST be registered with:
- Unique connection ID (string UUIDv7).
- Peer address (resolved client, not LB raw peer).
- Protocol identifier (`http/1.1`, `h2`, `grpc`).
- Strict state tracking: `HANDSHAKING` $\rightarrow$ `ACTIVE` $\rightleftharpoons$ `IDLE` $\rightarrow$ `CLOSING` $\rightarrow$ `CLOSED`.
- Timestamps: `opened_at`, `last_activity_at`.

Guardrail 2: Multi-Tier Concurrency Caps
The connection manager MUST enforce three distinct ceiling levels:
1. **Total Server Concurrency Cap**: Maximum global open connections (hard ceiling).
2. **Per-Client Concurrency Cap**: Maximum connections from any single resolved client identifier (keyed by peer resolver, never raw socket behind reverse proxy).
3. **HTTP/2 Stream Concurrency Cap**: Maximum concurrent multiplexed streams per connection (default: 100). Excess streams MUST be rejected with `REFUSED_STREAM`.

Guardrail 3: Deterministic Over-Limit Strategy
Never leave a client connection hanging on connect timeout when limits are reached. The connection manager MUST implement one of two declared strategies:
- **Soft Cap**: Accept connection, send HTTP 503 Service Unavailable with `Retry-After: 5`, then close cleanly.
- **Hard Cap / Attack Mode**: Accept socket and immediately issue TCP RST or clean close to prevent resource starvation.

Guardrail 4: Idle Connection Sweeper & Leak Detection
An asynchronous background task MUST periodically sweep connections in `IDLE` or `HANDSHAKING` states exceeding configured timeout thresholds. Handshakes stalled longer than 5000ms MUST be terminated immediately.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies. Document the entire algorithmic state machine in the file header docblock.

---

## 2. Connection Manager State Contract

```yaml
connection_manager_contract:
  limits:
    max_total_connections: 10000
    max_connections_per_client: 50
    max_handshake_rate_per_sec: 200
    http2_max_concurrent_streams: 100
  timeouts_ms:
    handshake_timeout: 5000
    idle_connection_timeout: 60000
    read_timeout: 30000
    write_timeout: 30000
  over_limit_policy: "ACCEPT_REJECT_503"
  metrics:
    active_gauge: "connections_active_total"
    rejections_counter: "connections_rejected_total"
    duration_histogram: "connection_duration_seconds"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Slow Handshake DoS (Slowloris SSL) Fix**: If TLS handshake or HTTP upgrade does not complete within `handshake_timeout` (5s), close socket directly with `TCP RST` and increment `handshake_timeouts_total`.
2. **HTTP/2 Stream Multiplex Starvation Fix**: When concurrent streams hit `http2_max_concurrent_streams`, send HTTP/2 `RST_STREAM` with error code `REFUSED_STREAM (0x7)`. This allows the client to retry on another connection without failing the business operation.
3. **Stale Connection Leak on NAT Reset Fix**: Periodically compare `now() - conn.last_activity_at > idle_connection_timeout`. If exceeded, gracefully close the connection with an HTTP `Connection: close` header or `GOAWAY` frame.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Keying Connections by Resolved Client
Never enforce client IP caps using the raw socket peer address when deployed behind an edge proxy or Kubernetes ingress; use the output of the Peer Resolver.

### Instruction 2: State Change Notifications
Emit metric transitions on every state shift (`active` $\rightleftharpoons$ `idle`) to ensure observability into connection pool saturation.
