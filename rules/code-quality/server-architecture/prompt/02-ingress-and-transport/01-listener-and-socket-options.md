---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_LISTENER_CREATION"
agent_role: "Principal Network Systems Engineer & Transport Security Auditor"
target_scope: "Socket Binding, TCP Sockets, Address/Port Reuse, TLS 1.2/1.3, ALPN & 0-RTT"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Listener and Socket Options Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Lazy Lifecycle Bind Invariant
Sockets MUST NEVER be bound in constructors, module initializations, or import side-effects. Sockets MUST bind strictly inside the component `start(ctx, deadline)` lifecycle method. If binding fails (e.g. `EADDRINUSE`, `EACCES`), the process MUST treat it as fatal and immediately abort with exit code `5` (Hard dependency failed).

Guardrail 2: Explicit Socket Options Invariant
Socket options MUST NEVER rely on operating system defaults. The listener MUST explicitly configure:
- `SO_REUSEADDR` = true (fast restart past TIME_WAIT state).
- `SO_REUSEPORT` = true only when multi-process load-balancing is declared.
- `TCP_NODELAY` = true for all interactive request/response protocols.
- `TCP_KEEPALIVE` enabled with an idle interval strictly shorter than any intermediate NAT/firewall timeout (default: 60s).
- Explicit accept backlog queue size (logged at startup; capped by kernel `somaxconn`).

Guardrail 3: Modern TLS Profile & Cipher Hardening
When TLS is terminated locally:
- Minimum TLS version MUST be TLS 1.2 (RFC 9325 / BCP 195); TLS 1.3 is strongly preferred. SSLv2, SSLv3, TLS 1.0, and TLS 1.1 are strictly forbidden.
- ALPN negotiation (RFC 7301) MUST explicitly declare supported protocol IDs (`h2`, `http/1.1`).
- Insecure cipher suites (RC4, 3DES, CBC mode ciphers) are strictly prohibited.

Guardrail 4: 0-RTT Early Data Safety
TLS 1.3 0-RTT Early Data MUST be disabled by default due to replay attack vulnerabilities (RFC 8446 §8). If explicitly enabled for performance, the application layer MUST enforce idempotency keys and reject non-idempotent mutations with HTTP 425 Too Early (RFC 8470).

Guardrail 5: Zero-Downtime Certificate Reload
TLS providers MUST support dynamic in-memory certificate rotation without restarting the process or terminating established connections.

Guardrail 6: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies. Document the entire algorithmic and socket configuration flow in the file header docblock.

---

## 2. Listener Configuration Contract

```yaml
listener_contract:
  bind:
    host: "0.0.0.0"
    port: 8000
    backlog: 2048
  socket_options:
    reuse_address: true
    reuse_port: false
    tcp_nodelay: true
    tcp_keepalive:
      enabled: true
      idle_seconds: 60
      interval_seconds: 15
      probes_count: 5
  tls:
    enabled: false
    min_version: "TLSv1.2"
    preferred_version: "TLSv1.3"
    alpn_protocols: ["h2", "http/1.1"]
    zero_rtt: false
    cipher_suites:
      - "TLS_AES_128_GCM_SHA256"
      - "TLS_AES_256_GCM_SHA384"
      - "TLS_CHACHA20_POLY1305_SHA256"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Port In Use (`EADDRINUSE`) Fix**: Catch the socket bind exception, log the structured error `{event: "bind_failed", host, port, errno: "EADDRINUSE"}`, and exit with code `5`. Do not enter a silent hang loop.
2. **Dynamic Ephemeral Port (Port 0) Fix**: For automated integration testing, allow binding to port `0`. After binding, immediately query `getsockname()` and export the allocated port to the test context.
3. **Stale Connection Drop Fix**: When intermediate cloud firewalls drop quiet connections, TCP keepalives (`idle: 60s`, `interval: 15s`) will trigger a TCP RST, cleaning up the dead socket without holding memory.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Separate Bind from Constructor
Never place `socket.bind()` inside `__init__`. Encapsulate binding strictly inside the async `start()` method.

### Instruction 2: Log Effective Address
Upon binding, extract and emit the structured metric `listener_bound{addr, protocol, effective_backlog}`.
