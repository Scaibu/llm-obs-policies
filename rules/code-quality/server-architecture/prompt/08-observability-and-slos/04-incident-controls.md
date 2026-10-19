---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_INCIDENT_CONTROLS_CREATION"
agent_role: "Principal Operations Architect & Emergency Mitigation Auditor"
target_scope: "Dynamic Killswitches, Brownout Modes, Maintenance Overrides & Fast Degradation"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Incident Controls Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Zero-Deployment Hot-Reloadable Killswitches
Every non-essential route and external upstream integration MUST be covered by an in-memory policy snapshot killswitch. Enabling or disabling a killswitch MUST take effect immediately (within $< 5\text{s}$) via dynamic configuration reload without redeploying code or restarting the process.

Guardrail 2: Deterministic Killswitch Rejection Envelopes
- A disabled route MUST return HTTP 503 Service Unavailable with an RFC 9457 envelope detailing: `title: "Service Temporarily Disabled"`, `reason: "ROUTE_KILLSWITCH_ACTIVE"`.
- A disabled upstream integration MUST trigger the designated fallback path (e.g. cached response or degraded feature mode) rather than throwing uncaught errors.

Guardrail 3: Brownout (Graceful Degradation) Mode
Under sustained cluster overload (e.g. CPU $\ge 85\%$ or queue wait $\ge 500\text{ms}$), the server MUST support an automatic or manually triggered "Brownout Mode" that sheds heavy, non-critical computations (e.g. recommendation algorithms, trace enrichment, asynchronous analytics) to preserve core transactional throughput.

Guardrail 4: Zero Inline Comments Doctrine
Never write mid-function inline comments inside emergency controllers. Document the toggle mechanisms in the file header docblock.

---

## 2. Incident Controls Contract

```yaml
incident_controls_contract:
  killswitches:
    poll_interval_seconds: 5
    route_status_code: 503
    route_error_type: "https://llmobs.internal/errors/killswitch-active"
  brownout_mode:
    auto_trigger_queue_wait_ms: 500
    shed_capabilities:
      - "analytics.enrichment"
      - "model.recommendations"
      - "telemetry.verbose_traces"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Third-Party API Outage Dragging Cluster Down Fix**: Flip `killswitches.upstream_vendor_x = false` via dynamic config. All calls to Vendor X are instantly bypassed, serving default fallback data without exhausting server threads.
2. **Maintenance Mode Keepalive Fix**: In global maintenance mode, return HTTP 503 with header `Retry-After: 300`, but keep the `/healthz` liveness probe returning `200 OK` so Kubernetes does not terminate pods.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Check Killswitch Early in Route Matcher
Inspect route killswitches in Pipeline Stage 4 (Route Resolution) before allocating body buffers or executing authentication.

### Instruction 2: Atomic Pointer Swapping
Ensure runtime killswitch configurations are updated via atomic pointer swap (`atomic.Pointer` or immutable reference exchange) to avoid data races.
