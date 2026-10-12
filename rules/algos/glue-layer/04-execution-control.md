
## Layer 4: Execution control

### G29. Work queue and scheduler

**Definition:** The runtime that dispatches ready steps to workers, respecting dependencies, priorities and resource limits.

**Glue use:** Runs any composed plan at full parallelism automatically.

**Guardrails:** Per-resource concurrency limits. Never let one flow starve all others.

### G30. List scheduling and critical path

**Definition:** Ordering parallel steps to minimize total completion time, prioritizing steps on the longest dependency chain.

**Glue use:** Big flows finish sooner, because bottleneck steps start first.

**Guardrails:** Update the duration estimates from real runs.

### G31. Conditional branching with guards

**Definition:** Choosing the next step based on data or results at runtime.

**Glue use:** "If exact search found nothing, try fuzzy. If more than 1,000 results, narrow the scope. Else continue."

**Guardrails:** Every decision point has a default branch, so there are no undefined paths.

### G32. Scatter-gather (fan-out / fan-in, multi-instance)

**Definition:** Running the same step on many items in parallel, then combining their results.

**Glue use:** "Apply this whole sub-flow to each of 400 repos" becomes one node in the plan.

**Guardrails:** Partial results are always marked as partial, and failures are listed per item.

### G33. Iteration until a fixpoint

**Definition:** Repeating a sub-flow until its output stops changing, or a condition is met.

**Glue use:** This is your "repeated flow". For example: search → edit → verify → search again until zero old matches remain. Or retrieve → expand → retrieve again until no new relevant entities appear.

**Guardrails:** Always set a maximum iteration count and a time budget (G34). Detect oscillation (results alternating between two states).

### G34. Budgets and bounded execution

**Definition:** Hard limits on iterations, time, cost and resources for every flow and sub-flow.

**Glue use:** Guarantees any combination, however complex or repeated, terminates within known limits.

**Guardrails:** No flow runs without budgets. Defaults apply when none are set.

### G35. Retry with exponential backoff and jitter

**Definition:** Repeating failed steps with growing, randomized delays.

**Glue use:** Makes long combined flows resilient to temporary failures in any single step.

**Guardrails:** Retry only idempotent steps (G40). Never retry non-retryable errors.

### G36. Circuit breaker

**Definition:** Temporarily stopping calls to a failing component, to protect the rest of the flow.

**Glue use:** One failing algorithm or service can't stall or overload every flow that depends on it. Flows reroute through fallbacks (G13) instead.

**Guardrails:** Log every state change, and alert when breakers stay open.

### G37. Durable execution (checkpointing, event-sourced replay)

**Definition:** Recording each completed step durably, so a flow resumes exactly where it stopped after a crash.

**Glue use:** Long, multi-hour combined flows (bulk migrations, re-embeddings, KG backfills) survive restarts and deployments. This is the model Temporal-style engines use.

**Guardrails:** Non-deterministic operations (time, random values, external calls) must be recorded as events, never recomputed during replay.

### G38. Saga with compensation

**Definition:** Undoing completed steps in reverse order when a later step fails, for flows that can't use a single transaction.

**Glue use:** Any combination that writes in several places stays recoverable.

**Guardrails:** Steps that can't be undone are marked irreversible, placed as late as possible in the flow, and require approval.

### G39. Memoization and content-addressed caching

**Definition:** Reusing a step's result when it's called again with exactly the same inputs.

**Glue use:** Repeated and overlapping flows become cheap. The 30 steps shared between two tasks run once. This is how build systems like Bazel avoid redundant work.

**Guardrails:** Only cache deterministic steps. Exclude secrets and access-restricted data from shared caches.

### G40. Idempotency keys

**Definition:** Unique keys that make repeated execution of a step have no extra effect.

**Glue use:** Retries, replays and resumed flows never double-apply anything.

**Guardrails:** Every write step must have an idempotency key.

### G41. Incremental recomputation (dirty propagation)

**Definition:** When an input changes, recomputing only the steps that depend on it, not the whole flow.

**Glue use:** When one file changes, a long combined flow updates in seconds instead of re-running everything. This is the model used by Bazel, the Salsa framework and spreadsheet engines.

**Guardrails:** The dependency tracking must be complete. A missed dependency produces stale results.

### G42. Event-driven triggering (publish/subscribe, CloudEvents)

**Definition:** Starting flows or steps automatically when events occur.

**Glue use:** Connects flows together without hard-wiring. "When the code index updates, re-run the affected search flows" is just one subscription.

**Guardrails:** Detect trigger loops (A triggers B, which triggers A) with event lineage and loop limits.

---
