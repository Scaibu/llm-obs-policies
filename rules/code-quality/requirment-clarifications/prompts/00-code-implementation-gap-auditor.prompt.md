---
agent_activation_trigger: "ON_REFERENCE | ON_PULL_REQUEST | ON_FULL_AUDIT"
agent_role: "Chief Systems Reliability & Specification Verification Auditor"
target_scope: "Entire Package Ingress, Domain Logic, Database Adapters & Written Specifications"
execution_mode: "Strict End-to-End 3-Stage Gap Analysis"
enforcement: "Absolute (Zero-Omission Policy)"
contract_version: "2.0"
---

# Master Prompt: 3-Stage Code & Specification Implementation Gap Auditor

(Universal Operational Rule for Polyglot Sub-Packages in Go, Python, Rust, Dart, Java, C#, C++, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Unified Verification Lifecycle Invariant
Auditing code or specifications in isolation is strictly prohibited. Every comprehensive audit MUST execute the full 3-phase cycle in sequence:
1. `Phase 1 (Intent → Spec)`: Discover unwritten invariants and populate the 5x5 Adversity Grid.
2. `Phase 2 (Spec → Code)`: Atomize written claims, assign Evidence Grades (1–5), and evaluate adversarial outcome tables.
3. `Phase 3 (Code → Spec)`: Backward-trace real code for dangerous defaults, swallowed errors, and unbudgeted side effects.

Guardrail 2: Cross-Check Against Workspace Architectural Rules
All audits MUST strictly evaluate compliance against the core folder-structure writing rules:
- [2-apis.writing.rule.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folder-structure/2-apis.writing.rule.md): Closed schemas, response envelopes, W3C trace propagation, root-cause DB idempotency, optimistic concurrency (`If-Match`), zero inline comments.
- [3.shared.code.writing.rule.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folder-structure/3.shared.code.writing.rule.md): Pure shared libraries, zero business logic or IO in `src/shared/`, centralized constants, centralized config isolation in `config/`.
- [4-functions-and-classes-writing-rule.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folder-structure/4-functions-and-classes-writing-rule.md): Deeply immutable parameters, typed `Result<T, E>` returns, explicit `try / catch / finally` per async IO function, max 30 lines, zero comment doctrine.
- [05-db-writing-rules.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folder-structure/05-db-writing-rules.md): Entity field contracts, 5 mandatory identifier roles (`id`, `public_id`, `tenant_id`, `source + external_id`, `correlation_id`), DB-level constraint enforcement, Transactional Outbox pattern.

Guardrail 3: Zero Subjective Hand-Waving Invariant
Every reported gap MUST provide:
- The exact file and line number.
- The concrete adversity scenario under which it fails.
- The violated architectural guardrail.
- The exact code diff or schema modification required to remediate it.

---

## 2. Multi-Phase Audit Workflow Instructions

### Instruction 1: Execute Phase 1 (Intent → Spec Audit)
Invoke [01-intent-to-spec-audit.prompt.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/code-quality/requirment-clarifications/prompts/01-intent-to-spec-audit.prompt.md):
- Check for undefined load-bearing terms.
- Populate the 5x5 Adversity Grid.
- Derive failure contracts for timeouts, unseen successes, and concurrent duplicates.

### Instruction 2: Execute Phase 2 (Spec → Code Verification)
Invoke [02-spec-to-code-verification.prompt.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/code-quality/requirment-clarifications/prompts/02-spec-to-code-verification.prompt.md):
- Classify gaps into `Omission`, `Partial`, `Divergence`, `Phantom`, `Weakened`, or `Drift`.
- Assign Evidence Grades 1 to 5.
- Fill the 8-condition Outcome Table for each external effect.
- Execute sabotage mental tests.

### Instruction 3: Execute Phase 3 (Code → Spec Hidden Behavior Audit)
Invoke [03-code-to-spec-hidden-behavior.prompt.md](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/code-quality/requirment-clarifications/prompts/03-code-to-spec-hidden-behavior.prompt.md):
- Audit framework/library defaults (timeouts, pool limits, commit policies).
- Scan for swallowed errors and degraded fallbacks.
- Build the Effect Inventory and triage each item (`Promote`, `Constrain`, `Remove`).

---

## 3. Required Deliverable Output Format

```markdown
# Comprehensive Implementation Gap Audit Report: [Target Service / Feature]

## 1. Executive Scorecard
| Verification Stage | Total Vectors | Compliant (Grade 4/5) | Gaps / Violations | Risk Posture |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1: Intent → Spec** | [N] | [N] | [N] | High / Med / Low |
| **Phase 2: Spec → Code** | [N] | [N] | [N] | High / Med / Low |
| **Phase 3: Code → Spec** | [N] | [N] | [N] | High / Med / Low |

---

## 2. Phase 1 Audit: Unwritten Expectations & Invariants
- **Unclear Load-Bearing Terms**: [Definitions required]
- **Adversity Gaps**: [Unwritten cells in 5x5 grid]
- **Missing Failure Contracts**: [Timeouts, drop after commit]

---

## 3. Phase 2 Verification: Spec → Code Compliance
- **Traceability Matrix**:
  | Req ID | Requirement | Location | Sub-Type | Grade | Status |
  | :--- | :--- | :--- | :--- | :--- | :--- |
- **Outcome Table for External Effects**: [Populated 8-condition outcome table]
- **Sabotage Vulnerabilities**: [Checks passing with logic deleted]

---

## 4. Phase 3 Audit: Hidden Runtime Defaults & Side Effects
- **Dangerous Defaults Overridden**: [Timeouts, pools, commit flags]
- **Swallowed Errors / Silent Fallbacks**: [File and line citations]
- **Effect Inventory & Triage**: [Promote / Constrain / Remove table]

---

## 5. Prioritized Remediation Action Plan
| Priority | Action Item | Target File:Line | Remediation Description | Verification Test |
| :--- | :--- | :--- | :--- | :--- |
| **P0 (Critical)**| ... | `src/...` | ... | ... |
| **P1 (High)** | ... | `src/...` | ... | ... |
| **P2 (Medium)** | ... | `src/...` | ... | ... |
```
