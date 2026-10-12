
## Layer 5: Scope and data flow

### G43. Blackboard pattern (shared context)

**Definition:** A shared, structured workspace where steps read inputs and write results, coordinated by a controller.

**Glue use:** Lets very different algorithms (search, graph, vector, edit) cooperate on one task without knowing about each other.

**Guardrails:** Steps can write only to their declared keys. Unexpected writes are rejected.

### G44. Lexical scoping (nested environments)

**Definition:** Each flow and sub-flow gets its own environment of variables, which inherits from its parent but can't change the parent's values.

**Glue use:** Sub-flows reused in many places (G17) can't accidentally interfere with each other's data, even when they run in parallel or repeatedly.

**Guardrails:** No global mutable state. Everything flows through declared inputs and outputs.

### G45. Scope expressions and predicate narrowing

**Definition:** A formal description of what a flow may touch (which repos, paths, tenants, entity types, time range), which can only stay the same or get narrower as it passes down.

**Glue use:** Guarantees "specific scope" across any combination, however deep: no step anywhere can touch something outside the original scope.

**Guardrails:** Scope checks are enforced by the executor, not left to each algorithm. Out-of-scope access fails the step.

### G46. Data lineage tracking

**Definition:** Recording which steps, inputs and versions produced every piece of data.

**Glue use:** Explains any result of a complex combined flow, and powers incremental recomputation (G41) and targeted rollback.

**Guardrails:** Lineage is recorded automatically by the executor, not by each algorithm.

### G47. Partitioning work by scope

**Definition:** Splitting the scope into independent partitions that can be processed separately and safely in parallel.

**Glue use:** Scales any flow to large scopes with no conflicts between workers.

**Guardrails:** Verify partitions are disjoint and complete: their union equals the full scope, and no item is in two partitions.

---
