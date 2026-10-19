---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_MAIN_CREATION | ON_SERVICE_BOOTSTRAP"
agent_role: "Principal Systems Architect & Process Bootstrap Auditor"
target_scope: "Process Lifecycle, Bootstrap Sequence, main.py Structure, Signal Handling & Clean Shutdown"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Process Bootstrap & 9-Phase Main Lifecycle Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: 9-Phase Lifecycle Sequence Invariant
Every application entrypoint (`src/main.[ext]`) MUST execute strictly in the nine sequential phases:
`Phase 0 (Bootstrap)` $\rightarrow$ `Phase 1 (Config)` $\rightarrow$ `Phase 2 (Construct)` $\rightarrow$ `Phase 3 (Validate Desired State)` $\rightarrow$ `Phase 4 (Admin Surface Up)` $\rightarrow$ `Phase 5 (Reconcile & Start Services)` $\rightarrow$ `Phase 6 (Data Plane Up)` $\rightarrow$ `Phase 7 (Run)` $\rightarrow$ `Phase 8 (Shutdown)`.

Guardrail 2: Single Fatal Error Channel
Every background task, service supervisor, and connection loop MUST report fatal errors into exactly ONE fatal channel/queue owned by `main`. The first fatal error triggers immediate shutdown. Later errors are logged, not lost.

Guardrail 3: Started-Components Stack Invariant
`main` MUST push components to an ordered stack as their start succeeds. On shutdown or partial-startup failure, `main` MUST pop and stop components in strict reverse topological order.

Guardrail 4: Zero Side-Effects in Constructors
Constructors (`__init__`) MUST be completely inert: zero I/O, zero network calls, zero thread/coroutine spawning, and zero socket binding. If an operation touches the outside world, it belongs strictly in `start()`.

Guardrail 5: Dedicated Admin Surface Separation
The admin listener (`/healthz`, `/ready`, `/metrics`, diagnostics) MUST bind to a dedicated, separate port from public traffic. Admin MUST never share public thread pools or socket listeners.

Guardrail 6: Immutable Configuration Snapshot Invariant
All environment variables and secret stores MUST be loaded and validated exclusively during Phase 1. Once validated, configuration is frozen into an immutable read-only snapshot. Zero `os.environ` reads are permitted inside domain features or request handlers.

Guardrail 7: Strict Anti-Patterns in Main
The `main` module MUST NOT contain:
- Business logic or request handling code of any kind.
- Names of specific external providers, models, or vendors.
- Circuit breaker, timeout, retry, or rate-limiting logic (handled by pipeline stages).
- Global mutable state reachable by other modules.

Guardrail 8: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies across any layer. Document the full architectural execution blueprint at the top of the file in the header docblock.

---

## 2. Nine-Phase Lifecycle Contract

```yaml
bootstrap_lifecycle:
  phases:
    0_bootstrap:
      action: "Parse flags (--config, --validate-only), install OS signal handlers, create root cancellation context, create instance ID"
      failure: "Usage error code (2)"
    1_config:
      action: "Load layers (defaults -> file -> env -> secrets), validate schema & cross-field rules, freeze snapshot, config fingerprint"
      failure: "Config error code (3)"
    2_construct:
      action: "Inert dependency injection graph, wire plugins, declare component dependencies"
      failure: "Config error code (3)"
    3_validate_state:
      action: "Verify descriptors, cycle detection, topological start order, exit early if --validate-only"
      failure: "Desired state error code (4)"
    4_admin_surface:
      action: "Bind admin listener (/healthz, /ready, /metrics) on separate internal port"
      failure: "Hard dependency error code (5)"
    5_start_services:
      action: "Start dependencies in topological order, push to started-stack, enforce start deadlines"
      failure: "Dependency error code (5)"
    6_data_plane:
      action: "Verify hard dependencies, bind public listener, flip readiness = true"
      failure: "Bind failure fatal code (6)"
    7_run:
      action: "Block main exclusively on root context cancellation (SIGTERM/SIGINT) OR first fatal channel error"
      failure: "Runtime fatal code (6)"
    8_shutdown:
      action: "Readiness = false, propagation wait, stop public ingress, drain in-flight, pop started-stack in reverse order, flush telemetry"
      failure: "Shutdown deadline exceeded code (7)"
```

---

## 3. Exit Code Standard

| Code | Meaning |
|---|---|
| 0 | Clean exit (normal signal-driven shutdown) |
| 2 | Usage or flag error |
| 3 | Invalid configuration (schema or cross-field validation failed) |
| 4 | Invalid desired state (cycle or missing capability) |
| 5 | Hard dependency failed at startup |
| 6 | Runtime fatal error (listener died or hard dependency lost) |
| 7 | Shutdown deadline exceeded (forced exit) |
