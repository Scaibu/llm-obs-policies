## How the glue fits together

| Layer | Question it answers | Entries |
|---|---|---|
| **1. Contracts** | What does each algorithm take in, produce, require and guarantee? | G1–G6 |
| **2. Composition models** | In what shapes can algorithms be connected (sequence, parallel, loop, branch)? | G7–G17 |
| **3. Automatic composition** | Which algorithms, in which order, reach this goal? | G18–G28 |
| **4. Execution control** | How does the plan actually run: scheduling, loops, retries, recovery? | G29–G42 |
| **5. Scope and data flow** | What data does each step see and pass on, and how far can it reach? | G43–G47 |
| **6. Safety and verification** | How do we prove the combined flow is correct, bounded and safe? | G48–G52 |

The key idea: **if every algorithm declares a precise contract (Layer 1), then Layer 3 can combine them automatically, like puzzle pieces whose shapes must fit.** That's what makes "any combination, any order" possible without you designing each flow by hand.

The format below matches the earlier references, with "Glue use" in place of "Agent use".

---

## Layer 1: Contracts (making algorithms pluggable)

### G1. Typed interface contract (16 Mandatory Properties)

**Definition:** A formal, machine-readable description of each algorithm's inputs, outputs, parameters, execution constraints, safety invariants, and performance bounds, allowing planners and orchestration engines to combine algorithms deterministically without runtime type errors.

**The 16 Standard Contract Properties:**

| # | Property Name | Type / Format | Example Value | Description |
|---|---|---|---|---|
| **1** | `id` | `string` | `"ALGO-SRCH-11"` | Unique immutable identifier across the catalog. |
| **2** | `name` | `string` | `"SearchEngineAhoCorasickAlgo"` | Canonical algorithm name. |
| **3** | `version` | `string (SemVer)` | `"1.0.0"` | Semantic versioning (`MAJOR.MINOR.PATCH`). |
| **4** | `category` | `enum` | `"search" \| "observability" \| "update"` | High-level classification partition. |
| **5** | `capability_tags` | `array[string]` | `["search.multipattern", "automaton.dfa"]` | G2 searchable indexing tags for capability queries. |
| **6** | `input_schema` | `JSONSchema` | `{"type": "object", "required": ["text"], "properties": {"text": {"type": "string"}}}` | Machine-checkable JSON schema of input payload. |
| **7** | `output_schema` | `JSONSchema` | `{"type": "array", "items": {"type": "object", "properties": {"pattern": {"type": "string"}}}}` | Machine-checkable JSON schema of output payload. |
| **8** | `parameters_schema` | `JSONSchema` | `{"type": "object", "properties": {"patterns": {"type": "array", "items": {"type": "string"}}}}` | Tunable execution hyperparameters, ranges, and defaults. |
| **9** | `purity` | `enum` | `"pure" \| "impure"` | `pure` if output depends solely on inputs with zero state access. |
| **10** | `determinism` | `enum` | `"deterministic" \| "non_deterministic"` | `deterministic` if identical inputs always produce identical output. |
| **11** | `idempotency` | `enum` | `"idempotent" \| "non_idempotent"` | `idempotent` if running $N$ times produces identical state as 1 run. |
| **12** | `reversibility` | `enum` | `"reversible" \| "irreversible"` | `reversible` if state can be rolled back via inverse patch/undo. |
| **13** | `side_effects` | `enum` | `"none" \| "read_only" \| "disk_write" \| "network"` | Environmental mutation scope. Enforces read-before-write safety. |
| **14** | `concurrency_model` | `enum` | `"thread_safe" \| "process_isolated" \| "single_threaded"` | Safe parallelization target (multiprocessing vs threading). |
| **15** | `hardware_target` | `enum` | `"cpu_scalar" \| "simd_vector" \| "gpu_accelerated"` | Hardware execution target & SIMD vector width requirements. |
| **16** | `complexity` | `object {time, space}` | `{"time": "O(N + M)", "space": "O(Σ PatternLengths)"}` | Asymptotic Big-O time and memory consumption bounds. |

**Invariants & Boundary Attachments:**
- `preconditions` (`array[string]`): Invariant boolean assertions that must evaluate to `True` before execution (e.g. `len(parameters.patterns) > 0`).
- `postconditions` (`array[string]`): Guaranteed invariants that must evaluate to `True` after execution (e.g. `is_sorted_by_offset(output)`).
- `compatible_adapters` (`array[string]`): List of registered G4 Type Adapters that can directly consume or convert this algorithm's output.
- `is_active` (`boolean`): Lifecycle toggle flag to deprecate/disable algorithms without deleting historical records.

**Glue use:** This 16-field contract is the foundational data model for the entire engine. When Step A (`ALGO-SRCH-01`) produces `filesystem.file_path[]` and Step B (`ALGO-OBS-17`) requires `source.text_content`, the Planner reads both `input_schema` and `output_schema`, identifies the mismatch, and auto-injects `ADAPTER-FILE-PATH-TO-CONTENT`.

**Guardrails:** No algorithm enters the registry without all 16 properties specified and validated against the database schema lock.

### G2. Capability registry (service catalog)

**Definition:** A searchable catalog of every available algorithm, indexed by what it consumes, produces and can do.

**Glue use:** All 606 algorithms from the three references become registry entries. Adding a new algorithm makes it instantly available to every future plan, with no rewiring.

**Guardrails:** Registry entries are reviewed before activation. Disabled or deprecated entries are kept but never planned.

### G3. Semantic versioning and compatibility checking

**Definition:** Versioning each algorithm's contract so that changes are classified as compatible or breaking (Semantic Versioning 2.0.0 specification).

**Glue use:** You can upgrade one algorithm without silently breaking every flow that uses it. Plans using a changed major version are flagged for re-planning.

**Guardrails:** A MAJOR change never auto-applies to existing plans.

### G4. Adapter (type conversion) pattern

**Definition:** Small converters that turn one algorithm's output into another algorithm's input format.

**Glue use:** This is what makes "any combination" practical. Code ref #14 (line numbers) to Code ref #117 (text edits) needs a line-index adapter (Code ref #142).

**Guardrails:** Lossy adapters are allowed only where the plan's goal accepts the loss. For example, never truncate a list that feeds an exhaustive edit scope.

### G5. Pre- and postconditions (design by contract)

**Definition:** Declared conditions that must hold before an algorithm runs and conditions it guarantees after.

**Glue use:** Galloping intersection (Code ref #66) requires sorted input; a sort step guarantees "sorted". The planner automatically inserts the sort when the previous output isn't declared sorted.

**Guardrails:** Conditions are checked at runtime, not just assumed. Expensive checks can be sampled, but checks on write steps are always full.

### G6. Data schemas and validation

**Definition:** Machine-checkable descriptions of the data passed between steps, validated at every boundary.

**Glue use:** A step that produces malformed output fails at its own boundary, not three steps later in a confusing way.

**Guardrails:** Validation can't be turned off for write steps.

## How it works end to end, with no AI involved

**Example task:** "Rename `getUser` to `fetchUser` in repos A and B, but only under `src/`."

1. **Goal and scope** become formal: the goal is `renamed(getUser→fetchUser) ∧ verified`, and the scope is repos {A, B} ∧ path src/** (G45).
2. **HTN planner** (G21) picks the "rename symbol" method. Its subtasks are: find references, plan edits, apply, verify.
3. **Rules and decision tables** (G26, G27) choose the implementations: the LSP rename is available for TypeScript, so use it (Code ref #90). For other files, use structural search (Code ref #81).
4. **Type-directed composition** (G23) inserts adapters, such as LSP positions → byte ranges (Code ref #119).
5. **CSP** (G25) sets the batch size and concurrency within the budgets.
6. **Plan validation** (G28) proves every precondition is satisfied.
7. **Executor:** scatter per repo (G32, G47) → topological order within each repo (G9) → idempotent writes (G40) → durable checkpoints (G37).
8. **Fixpoint loop** (G33): search for `getUser` again. If matches remain, re-plan for those only (G22), with at most 3 iterations (G34).
9. **On failure:** compensate (G38), and record the trace (G52) and lineage (G46).

Swap the goal for "keep the vector index fresh" or "answer a question from the knowledge graph", and the same six layers pick entirely different algorithms from the registry. That's the "any combination, any order, repeatable, scoped" property you asked for.

**Where AI is optional:** only to turn a natural-language request into the formal goal and scope in step 1. If you use fixed templates or forms for goals, the whole system runs with zero tokens.
