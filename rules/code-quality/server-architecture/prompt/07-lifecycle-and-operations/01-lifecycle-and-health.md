---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_LIFECYCLE_CREATION"
agent_role: "Principal Infrastructure Architect & Health Check Auditor"
target_scope: "Process States, Transitions, Liveness vs Readiness, Admin Health Probes"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Lifecycle and Health Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Five-State Finite State Machine
Every server component MUST adhere to an explicit five-state lifecycle:
`CREATED` $\rightarrow$ `STARTING` $\rightarrow$ `SERVING` $\rightarrow$ `DRAINING` $\rightarrow$ `STOPPED`.
- In `CREATED`, `STARTING`, `DRAINING`, and `STOPPED`, readiness MUST return `false`.
- Readiness flips to `true` strictly when the listener is bound and accepting traffic.

Guardrail 2: Strict Liveness vs Readiness Separation
- **Liveness (`/healthz`)**: Answers "Can this process make progress?" It MUST verify ONLY local process health (event loop responsive, deadlock watchdog healthy). Liveness MUST NEVER query external downstream dependencies (DB, Redis, downstream APIs); an external outage causing liveness failures triggers catastrophic cluster restart loops.
- **Readiness (`/ready`)**: Answers "Can this process accept user traffic right now?" It checks internal initialization state and hard dependency connectivity.

Guardrail 3: Idempotent Stop Invariant
The `stop(deadline)` method MUST be 100% idempotent and safe to call before `start()` has run, while `start()` is in progress, or multiple times concurrently.

Guardrail 4: Zero Inline Comments Doctrine
Never write mid-function inline comments inside lifecycle state managers. Document the state transition invariants in the file header docblock.

---

## 2. Lifecycle State Contract

```yaml
lifecycle_contract:
  states:
    CREATED: { ready: false, live: true }
    STARTING: { ready: false, live: true }
    SERVING: { ready: true, live: true }
    DRAINING: { ready: false, live: true }
    STOPPED: { ready: false, live: false }
  probes:
    liveness_path: "/healthz"
    readiness_path: "/ready"
    startup_path: "/startup"
  dependencies_in_liveness: false # STRICTLY PROHIBITED
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Cascading Pod Restart Loop (Downstream DB Outage) Fix**: Ensure `/healthz` never issues a `SELECT 1` to PostgreSQL. When Postgres goes down, pods report `/ready = 503` so traffic stops, but `/healthz = 200` remains healthy so Kubernetes does NOT restart the pods in a storm.
2. **Double-Stop Cleanup Race Fix**: Guard `stop()` with an atomic CAS or `threading.Lock`: if already `DRAINING` or `STOPPED`, return immediately.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Call External Services in Liveness
Write `/healthz` to check only local thread loop heartbeat; write `/ready` to check external connectivity.

### Instruction 2: Flip Readiness Before Stopping
In the shutdown handler, set `readiness = false` before tearing down any listeners.
