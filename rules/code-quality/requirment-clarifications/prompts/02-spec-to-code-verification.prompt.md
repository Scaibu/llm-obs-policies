---
agent_activation_trigger: "ON_REFERENCE | ON_CODE_REVIEW | ON_SPEC_VERIFICATION"
agent_role: "Lead Spec-to-Code Verification Officer & Architecture Enforcer"
target_scope: "All Handlers, Routers, Domain Services, Database Queries, Migrations & Test Suites"
execution_mode: "Strict Refinement & Sabotage Verification Gate"
enforcement: "Absolute (Zero-Omission Policy)"
contract_version: "2.0"
---

# Spec → Code Verification & Implementation Gap Auditor

(Universal Operational Rule for Polyglot Sub-Packages in Go, Python, Rust, Dart, Java, C#, C++, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Universal Refinement Verification Invariant
Code satisfies the specification if and only if EVERY execution path possible in the code satisfies the spec predicates. A test suite that exercises only happy-path scenarios is existential evidence, not proof of satisfaction.

Guardrail 2: Strict Gap Classification Invariant
Every gap discovered MUST be explicitly categorized into one of the 6 canonical sub-types:
1. `Omission`: Specified requirement has zero implementation.
2. `Partial`: Implementation handles only a subset of the domain (e.g. retries timeouts but crashes on 503).
3. `Divergence`: Implementation does something different (e.g. logs instead of returns 400).
4. `Phantom`: Code exists and tests pass, but code is never wired or active in production.
5. `Weakened`: Guarantee holds per-hop, but fails end-to-end (e.g. un-outboxed messaging).
6. `Drift`: Behavior was previously compliant but regressed due to refactoring.

Guardrail 3: Graded Evidence Invariant (Zero Mock-Only Acceptance)
Implementation satisfaction MUST be graded on an Evidence Scale from Grade 1 to Grade 5. Mocks that return predetermined responses are Grade 3 at best. Critical requirements must reach Grade 4 (real database / real broker under fault injection) or Grade 5 (active production telemetry).

Guardrail 4: Mandatory Root-Cause Idempotency & Outbox Invariant
Verify that mutations enforce idempotency at the database storage layer via unique constraints (`(tenant_id, idempotency_key)`), atomic SQL conditional updates (`WHERE id = :id AND version = :version`), and Transactional Outbox tables (`infra_outbox`). Handlers or domain services performing direct uncoordinated secondary publishes are flagged as critical `Weakened` gaps.

Guardrail 5: Closed-Schema & Response Envelope Invariant
Verify that request DTOs strictly enforce `additionalProperties: false`. Verify that responses are wrapped in the standard envelope: `success`, `statusCode`, `data`/`error`, and `meta`. Naked returns are immediate `Divergence` gaps.

Guardrail 6: Functional Purity & Deep Immutability Invariant
Verify that all parameters are marked deeply immutable (`Readonly<T>`, `final`, frozen). Verify that async I/O functions have explicit `try / catch / finally` blocks that record span errors and end spans. Naked primitive returns or thrown uncaught exceptions are flagged as architectural violations.

Guardrail 7: Sabotage Mental Test Invariant
Every critical requirement MUST be verified via a sabotage test: if deleting or inverting the enforcing code does not cause an automated test to fail loudly, the requirement is certified as unverified (Grade 2).

---

## 2. Evidence Grading Scale & Outcome Contract

```yaml
evidence_grades:
  grade_1:
    name: "Claimed"
    definition: "Claimed in comments or PR; zero code or test exists"
    acceptable_for_production: false
  grade_2:
    name: "Code Exists"
    definition: "Code logic written, but completely unexercised by tests"
    acceptable_for_production: false
  grade_3:
    name: "Unit Tested with Mocks"
    definition: "Tested against mock implementations that mimic developer assumptions"
    acceptable_for_production: false
  grade_4:
    name: "Adversarially Verified"
    definition: "Verified against real dependencies (PostgreSQL, Redis, Kafka) under fault injection"
    acceptable_for_production: true
  grade_5:
    name: "Production Observable"
    definition: "Verified via live runtime metrics, OTel traces, and production error alerts"
    acceptable_for_production: true

outcome_table_conditions:
  - "1. Success"
  - "2. Fast Failure (4xx/5xx)"
  - "3. Connection / Read Timeout"
  - "4. Unseen Success (Drop after commit)"
  - "5. Partial Write / Crash Between Effects"
  - "6. Duplicate Invocation"
  - "7. Concurrent Invocation (Race Condition)"
  - "8. Process Killed Right After Mutation"
```

---

## 3. Implementation Verification Instructions

### Instruction 1: Atomize Requirements
Break the specification into numbered atomic statements with: Trigger, Precondition, Mechanism, Expected Outcome, and Evidence Grade.

### Instruction 2: Populate Outcome Table for Every External Side Effect
Evaluate all 8 conditions for database writes, outbound HTTP requests, cache updates, and queue dispatches. Compare code behavior with spec requirement.

### Instruction 3: Run Sabotage Mental Checks
Locate the line enforcing each requirement. Determine if an automated test fails if that line is inverted. If none fails, file a `Sabotage Vulnerability`.

### Instruction 4: Verify Folder Structure Invariants
Cross-reference code against [2-apis.writing.rule.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folder-structure/2-apis.writing.rule.md), [3.shared.code.writing.rule.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folder-structure/3.shared.code.writing.rule.md), [4-functions-and-classes-writing-rule.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folder-structure/4-functions-and-classes-writing-rule.md), and [05-db-writing-rules.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folder-structure/05-db-writing-rules.md).

---

## 4. Required Output Format

```markdown
# Spec → Code Verification Report: [Feature Name]

## 1. Compliance Scorecard
- Total Requirements: [N]
- Compliant (Grade 4 or 5): [N]
- Partial / Divergent / Weakened (Grade 1-3): [N]
- Total Omissions: [N]

## 2. Requirement Traceability Matrix
| Req ID | Requirement Statement | Code Location | Gap Sub-Type | Evidence Grade | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| REQ-01 | ... | `src/...:L10` | None | Grade 4 | COMPLIANT |
| REQ-02 | ... | `src/...:L45` | Partial | Grade 3 | GAP |

## 3. Deep Dive on Implementation Gaps
### [GAP-01] [Requirement ID & Name]
- **Sub-Type**: [Omission | Partial | Divergence | Phantom | Weakened | Drift]
- **Code Finding**: [Cite exact file, line number, and snippet]
- **Failure Mode**: [Concrete runtime consequence under stress]
- **Violated Architectural Rule**: [Rule name and section]
- **Correction Required**: [Specific code / migration change]

## 4. Outcome Table for External Effects
| Outcome Condition | Code Action | Spec Requirement | Match? | Grade |
| :--- | :--- | :--- | :--- | :--- |

## 5. Sabotage Test Findings
- **Enforcing Line**: `src/...:L50`
- **Current Test Sensitivity**: PASSES EVEN IF LINE DELETED (Grade 2 Risk)
- **Required Adversarial Test**: [Test case to write]
```
