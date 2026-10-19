---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_AUTOSCALING_RULE_CREATION"
agent_role: "Principal Infrastructure Capacity Architect & Autoscaling Auditor"
target_scope: "Horizontal Pod Autoscaling (HPA), In-Flight Saturation Signals, Scale Stabilization & Flapping"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Autoscaling Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: In-Flight Concurrency as Primary Scaling Signal
CPU metrics are insufficient for I/O-bound microservices (e.g. LLM gateways or DB query workers), which stay at low CPU while queues build up. Autoscaling MUST use **in-flight concurrency per replica relative to the admission ceiling** or **P95 queue wait time** as the primary scaling trigger.

Guardrail 2: Asymmetric Scale-Up vs Scale-Down Policies
- **Scale-Up**: Fast reaction window (short stabilization window: 15–30s) to absorb sudden traffic surges.
- **Scale-Down**: Conservative reaction window (long stabilization window: 300s) to prevent thrashing and connection churn. Every removed replica MUST execute the complete graceful drain sequence.

Guardrail 3: Upstream Capacity Ceiling Invariant
Maximum autoscaling pod replicas MUST NOT be bounded by compute budget alone; `max_replicas` MUST be strictly bounded by downstream database connection pool limits. Scaling beyond DB connection capacity triggers total system collapse.

Guardrail 4: Zero Inline Comments Doctrine
Never write mid-function inline comments inside autoscaling controllers. Document the scaling math in the file header docblock.

---

## 2. Autoscaling Contract

```yaml
autoscaling_contract:
  signals:
    primary: "http_server_active_requests_per_replica"
    target_utilization: 0.70 # Scale when at 70% of admission limit
    secondary: "queue_wait_duration_p95_seconds"
  windows:
    scale_up_stabilization_seconds: 15
    scale_down_stabilization_seconds: 300
  bounds:
    min_replicas: 3
    max_replicas_capped_by_db_pool: 50
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Flapping Thrashing Loop Fix**: Enforce a 300-second scale-down stabilization window in Kubernetes HPA (`scaleDown.stabilizationWindowSeconds: 300`). This prevents pods from terminating right before a secondary traffic burst.
2. **Database Overload Cascading Crash Fix**: Calculate: $\text{max\_replicas} = \lfloor \frac{\text{DB Max Connections} \times 0.8}{\text{Per-Pod Pool Size}} \rfloor$. Hardcode this upper bound into the HPA manifest.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Export Concurrency Metrics to Prometheus
Export `http_server_active_requests` as a gauge labeled by pod name to drive external metric HPA controllers.

### Instruction 2: Never Scale Down Instantly
Ensure Kubernetes manifests declare `scaleDown` policies with rate-limiting step down rules.
