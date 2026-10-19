---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_CONFIG_VALIDATION"
agent_role: "Principal Systems Architect & Configuration Safety Enforcer"
target_scope: "Configuration Schema, Cross-Field Validation, Pre-Start Verification & Invariant Checks"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Configuration and Pre-Start Validation Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Pre-Start Execution Invariant (Zero Ports Open)
Configuration loading and validation MUST execute in Phase 1 before any socket is opened, port is bound, or external resource is initialized. If validation fails, the process MUST exit immediately with exit code `3` (Invalid configuration), reporting all validation errors together.

Guardrail 2: Strongly-Typed Durations & Units
All duration fields MUST be declared as strongly-typed duration strings or objects with explicit units (e.g. `30s`, `500ms`, `2m`), NEVER ambiguous bare integers. Bare integers representing seconds or milliseconds are strictly prohibited.

Guardrail 3: Cross-Field Timeout Hierarchy Invariants
Configuration MUST enforce the following cross-field mathematical constraints:
- `header_read_timeout < idle_connection_timeout`.
- `idle_connection_timeout > upstream_lb_idle_timeout` (prevents race conditions with edge proxy keepalives).
- `handshake_timeout <= header_read_timeout`.
- For every route: `route.timeout <= server.max_request_timeout`.

Guardrail 4: Lifecycle Shutdown Arithmetic Consistency
Configuration MUST validate that total shutdown grace period accommodates all internal stages:
`propagation_wait + drain_deadline + force_cleanup_margin < orchestrator_kill_timeout` (e.g. Kubernetes `terminationGracePeriodSeconds`).

Guardrail 5: Network Exposure Separation Invariants
- `public.bind` port MUST NOT collide with `admin.bind` port.
- `admin.bind` MUST NOT listen on public interfaces (`0.0.0.0`) unless explicit authentication and IP allowlisting are declared.
- `tls.mode = "off"` is strictly prohibited on non-loopback, public network interfaces.

Guardrail 6: Immutable Configuration Object & Secret Redaction
Once validated, the configuration object MUST be completely frozen (read-only). Runtime mutations of configuration are forbidden. All secrets (passwords, tokens, keys) MUST be wrapped in redaction types to prevent accidental leakage in logs or dumps.

Guardrail 7: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies. Document all validation rules in the file header docblock.

---

## 2. Configuration Schema Contract

```yaml
config_schema_spec:
  server:
    public_bind: "0.0.0.0:8000"
    admin_bind: "127.0.0.1:9090"
    max_request_timeout: "60s"
    idle_connection_timeout: "65s"
    header_read_timeout: "10s"
    handshake_timeout: "5s"
    upstream_lb_idle_timeout: "60s"
  lifecycle:
    propagation_wait: "2s"
    drain_deadline: "15s"
    force_cleanup_margin: "3s"
    orchestrator_kill_timeout: "30s" # sum must be < 30s
  limits:
    total_connection_cap: 10000
    per_client_cap: 100
    max_body_bytes: 10485760 # 10 MiB
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Upstream LB Race Condition (Premature TCP RST) Fix**: Ensure `idle_connection_timeout` (65s) is strictly larger than AWS ALB or NGINX keepalive timeout (60s). This prevents the backend from closing the connection right as the LB sends a new request.
2. **Kubernetes SIGKILL Mid-Drain Fix**: In CI/CD deployment checks, assert `propagation_wait (2s) + drain_deadline (15s) + force_margin (3s) = 20s < terminationGracePeriodSeconds (30s)`. If violated, abort CI build.
3. **Admin Surface Exposure Leak Fix**: If `admin_bind` is set to `0.0.0.0` without an active bearer token or mTLS configuration, raise a fatal `ConfigurationError` during Phase 1 boot.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Execute Complete Validation Before Bind
Run JSON Schema / Pydantic validation and CEL cross-field assertions before calling any network initialization.

### Instruction 2: Collect All Errors Together
Do not fail-fast on the first missing environment variable; aggregate all missing fields and path locations into a single clear report.
