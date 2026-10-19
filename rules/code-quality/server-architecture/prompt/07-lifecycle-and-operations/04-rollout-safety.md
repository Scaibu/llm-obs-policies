---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_DEPLOYMENT_PLANNING"
agent_role: "Principal Release Engineer & Deployment Safety Officer"
target_scope: "Canary Deployments, Automated Rollbacks, Version Skew & Cache Warm-Up"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Rollout Safety Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Staged Canary Progression Invariant
All application code and configuration deployments MUST progress through phased canary stages (e.g. 1 pod $\rightarrow$ 10% traffic $\rightarrow$ 50% traffic $\rightarrow$ 100% fleet). Direct 100% instantaneous fleet cutovers are strictly prohibited for production workloads.

Guardrail 2: Automated Rollback on SLO Error Spikes
Deployment pipelines MUST evaluate automated rollback gates continuously during the canary phase. If canary error rate or P99 latency breaches established SLO thresholds, the deployment MUST abort and roll back automatically without human intervention.

Guardrail 3: Forward/Backward Version Skew Compatibility
Database schemas, inter-service API contracts, and message bus schemas MUST tolerate version skew (old version $N-1$ and new version $N$ running concurrently for a minimum of 60 minutes). Non-additive breaking schema changes are strictly prohibited.

Guardrail 4: Warm-Up Before Readiness
New replicas MUST execute synthetic warm-up routines (JIT compilation, connection pool pre-warming, cache pre-loading) during the `STARTING` phase before flipping `/ready` to `true`.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside rollout scripts or warm-up routines. Document the canary evaluation gates in the file header docblock.

---

## 2. Rollout Safety Contract

```yaml
rollout_contract:
  canary_stages:
    - { step: 1, traffic_percentage: 5, duration_minutes: 10 }
    - { step: 2, traffic_percentage: 25, duration_minutes: 20 }
    - { step: 3, traffic_percentage: 100, duration_minutes: 0 }
  rollback_triggers:
    error_rate_threshold: 0.01 # 1% error rate
    latency_p99_increase_percentage: 25.0
  warmup:
    synthetic_requests_count: 50
    prewarm_db_pool: true
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Cold Cache Thundering Herd Fix**: During pod startup, issue 50 synthetic warm-up calls to cache adapters and database pools before signaling readiness to Kubernetes, preventing cold-cache latency spikes.
2. **Version Skew Serialization Error Fix**: Enforce `additionalProperties: true` or backwards-compatible field deprecation policies across wire DTOs so version $N-1$ pods can deserialize payloads produced by version $N$.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Label Config Versions on Telemetry
Ensure all emitted metrics include `config_version` and `build_version` tags to enable split canary metric comparisons.

### Instruction 2: Include Warm-Up in Start Method
Place synthetic cache pre-warming inside the async `start()` method before public listening begins.
