---
agent_activation_trigger: "ON_REFERENCE | ON_REQUIREMENT_AUDIT | ON_FEATURE_DESIGN"
agent_role: "Principal Requirements & System Invariant Auditor"
target_scope: "PRDs, User Stories, API Specs, Domain Models & Business Invariants"
execution_mode: "Strict & Adversarial Extraction"
enforcement: "Absolute (Zero-Omission Policy)"
contract_version: "2.0"
---

# Intent → Spec Audit & Unwritten Requirement Extractor

(Universal Operational Rule for Polyglot Sub-Packages in Go, Python, Rust, Dart, Java, C#, C++, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Strict Invariant Derivation over Happy-Path Collection
Never treat a happy-path feature description as a complete specification. Every feature MUST be cross-examined against non-negotiable safety properties. What is omitted from the spec is not neutral; it is delegated to language defaults and uncontrolled library behaviors.

Guardrail 2: Operational Definition Invariant (Zero Ambiguous Jargon)
Terms such as "accepted", "idempotent", "processed", "deleted", and "real-time" MUST be accompanied by an unambiguous, observable engineering definition stating storage durability, replica count, and state machine transition before the requirement is approved.

Guardrail 3: Universal Adversity Grid Mandate
Every critical business property (No Data Loss, Root Idempotency, Causal Ordering, Tenant Isolation, Bounded Latency) MUST be crossed against the 5 primary environmental adversities (Dependency Outage, Duplicate Ingress, Overload Spike, Partition/Clock Skew, Malformed Input). Empty cells are classified as critical unwritten gaps.

Guardrail 4: Mandatory Failure Contract Invariant
Every state-changing verb (`create`, `update`, `cancel`, `transfer`, `delete`) MUST declare explicit observable behavior for:
1. Upstream timeout after partial execution.
2. Unseen success (write commits, but ACK is lost over network).
3. Concurrent duplicate invocations within microseconds.

Guardrail 5: Safety Prohibitions First-Class Invariant
Negative invariants ("The system must NEVER allow X, even under process crash or network partition") MUST be explicitly enumerated. Safety properties take strict precedence over operational capabilities.

Guardrail 6: Quantitative Non-Functional Metric Invariant
Adjectives such as "fast", "scalable", or "resilient" are strictly forbidden. Every non-functional requirement MUST specify numeric p50/p99 latency thresholds, max concurrent connection ceilings, RPO/RTO seconds, and telemetry collection keys.

---

## 2. Adversity Grid & Extraction Matrix Contract

```yaml
grid_dimensions:
  properties:
    no_data_loss: "Zero uncommitted or acknowledged data dropped"
    no_duplication: "Strict exactly-once side effects at storage layer"
    strict_ordering: "Causality preserved across tenant or aggregate root"
    tenant_isolation: "Zero cross-tenant leakage or shared mutable memory"
    bounded_latency: "Hard deadlines and backpressure under saturation"
  adversities:
    dependency_down: "DB, downstream API, or broker completely unreachable"
    duplicate_delivery: "Same payload retried repeatedly with network delay"
    overload_spike: "Ingress exceeds 10x rated capacity"
    network_partition: "Clock drift, split-brain, or severed connection mid-write"
    malformed_input: "Invalid types, extra unmapped fields, or injection probes"

decision_options:
  GUARANTEE: "Property holds under adversity; requires named storage mechanism"
  DEGRADE: "Property safely weakens; requires explicit error envelope and counter metric"
  ACCEPT_LOSS: "Property violated; requires named business owner sign-off and audit log"
  UNWRITTEN_GAP: "Cell is blank; blocks implementation until resolved"
```

---

## 3. Implementation Verification & Extraction Workflow

### Step 1: Interrogate Load-Bearing Terms
Identify all state verbs and extract operational definitions:
- If spec states "POST /orders returns 202 Accepted", determine whether accepted means in-memory queue or multi-replica durable WAL commit.

### Step 2: Populate the 5×5 Adversity Grid
Construct the matrix crossing every protected property with every adversity. Ensure no cell remains an `UNWRITTEN_GAP`.

### Step 3: Formulate Failure Contracts for Every External Action
Specify the client-visible status code, retry header (`Retry-After`), and state compensation for:
1. Timeout / Network Drop.
2. Concurrent Race Condition (HTTP 409 + Lock Contention).
3. Downstream Dependency Crash (Circuit breaker trip + Fallback policy).

### Step 4: Extract Safety Prohibitions ("Must Never")
Formulate safety invariants as unit-testable assertions before code is written.

---

## 4. Required Output Format

When analyzing any requirement or feature request, output your findings in this structured format:

```markdown
# Intent → Spec Audit Report: [Feature Name]

## 1. Load-Bearing Glossary & Operational Definitions
| Term | Spec Statement | Operational Engineering Definition | Risk if Undefined |
| :--- | :--- | :--- | :--- |

## 2. Populated Adversity Grid
| Protected Property \ Adversity | Dependency Down | Duplicate Delivery | Overload Spike | Partition / Skew | Malformed Input |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **No Data Loss** | [GUARANTEE/...] | ... | ... | ... | ... |
| **No Duplication** | ... | ... | ... | ... | ... |
| **Causal Ordering** | ... | ... | ... | ... | ... |
| **Tenant Isolation**| ... | ... | ... | ... | ... |
| **Bounded Latency** | ... | ... | ... | ... | ... |

## 3. Discovered Unwritten Invariants & Failure Contracts
- **Invariant 1**: [Description + Observable Telemetry Metric]
- **Scenario (Timeout mid-write)**: [Client response + Storage state]
- **Scenario (Concurrent Double-Click)**: [Lock acquisition + Rejection contract]

## 4. Safety Prohibitions ("MUST NEVER")
- [Explicit prohibition list]

## 5. Non-Functional Metric Contracts
- **p99 Latency SLA**: [Threshold in ms]
- **Throughput / Concurrency**: [Max connections / RPS]
- **Telemetry Counter**: [Exact Prometheus/OTel counter name]
```
