## Layer 7: Matching and data binding

### G53. Unification (pattern matching with variables)

**Definition:** Finding variable bindings that make two structured patterns identical, the core matching step inside planners and rule engines.

**Glue use:** The planner (G18–G22) uses unification to decide whether one step's guaranteed effects satisfy another step's preconditions, including generic types (G55).

**Guardrails:** Always enable the occurs check in planning and rule engines, so malformed contracts can't cause infinite loops.

### G54. Subtyping and structural compatibility

**Definition:** Rules deciding when a value of one type can be used where another type is expected.

**Glue use:** The type-directed composer (G23) accepts connections without needing an adapter for every small type difference, and still rejects truly incompatible ones.

**Guardrails:** Structural matches must also check meaning-carrying metadata (units, coordinate systems, byte versus character offsets). Same shape doesn't mean same meaning.

### G55. Generic (parametric) types for algorithms

**Definition:** Declaring algorithms over type parameters, so one algorithm works for many element types.

**Glue use:** Generic utilities (sort, dedupe, merge, filter, top-k, batch) work everywhere, which cuts the registry size and the adapter count.

**Guardrails:** Constraint checking at binding time is mandatory, so a generic algorithm is never applied to a type it can't handle.

### G56. Expression language for guards and scopes (CEL)

**Definition:** A small, safe, non-Turing-complete language for writing conditions, filters and scope rules. Google's Common Expression Language (CEL) is a widely used open specification.

**Glue use:** Every guard (G31), scope (G45), stop condition (G33) and rule condition (G26) uses one consistent language, instead of scattered custom code.

**Guardrails:** Set evaluation cost limits. Expressions are type-checked when flows are saved, not only when they run.

### G57. Data selection paths (JSONPath, RFC 9535)

**Definition:** A standard syntax for selecting parts of structured data, standardized by the IETF as JSONPath in RFC 9535.

**Glue use:** Wires steps together without adapter code ("pass `$.files[*].path` from step 3 into step 5 as `paths`"), so flows can be defined entirely in configuration.

**Guardrails:** Validate the selected values against the target input schema (G6). A path selecting nothing is an error, unless it's explicitly declared optional.

### G58. Structured data patching (JSON Patch RFC 6902, JSON Merge Patch RFC 7386)

**Definition:** IETF standard formats describing changes to structured data documents.

**Glue use:** Steps update shared context (G43) or configuration with precise, reviewable, revertible changes, instead of overwriting whole documents.

**Guardrails:** Use JSON Patch with `test` operations for concurrent updates. That gives an optimistic check, similar to G87.

### G59. Canonical serialization and hashing (JSON Canonicalization Scheme, RFC 8785)

**Definition:** A standard way to serialize data so identical content always produces identical bytes, and therefore identical hashes.

**Glue use:** Cache keys (G39), idempotency keys (G40), plan IDs and change detection (G41) all depend on stable hashes. Without canonicalization, the same parameters in a different key order miss the cache, or get processed twice.

**Guardrails:** Use canonical hashing for every key derived from structured data.

## Layer 8: Dependency and plugin management

### G60. Dependency resolution (SAT-based, PubGrub)

**Definition:** Choosing compatible versions of every algorithm and library a flow needs, or explaining why none exist.

**Glue use:** When a plan combines 40 algorithms with different library requirements, the resolver picks consistent versions automatically, or explains exactly which pair conflicts.

**Guardrails:** Lock the resolved versions for each saved plan, so reruns are reproducible.

### G61. Capability negotiation

**Definition:** At runtime, checking which features each component actually supports, and adapting the plan to match.

**Glue use:** The same flow works across environments with different engines or versions, choosing compatible paths automatically.

**Guardrails:** Never assume a capability without a positive answer from the component.

### G62. Plugin isolation (process and WebAssembly sandboxes)

**Definition:** Running each algorithm in an isolated environment with limited permissions and resources.

**Glue use:** You can combine many algorithms of varying quality safely. A buggy one fails alone, inside its sandbox.

**Guardrails:** Least privilege by default. Each plugin gets only the scope (G45) of its current step.

### G63. Parameterized flow templates (macros)

**Definition:** Reusable flow definitions with parameters that are expanded into concrete plans.

**Glue use:** Proven combinations are captured once and reused with different inputs, which gives a library of tested recipes alongside HTN methods (G21).

**Guardrails:** Templates are versioned (G3) and tested (G95–G98). Instantiation can't widen the scope passed in.

### G64. Plan diffing and versioning

**Definition:** Comparing two plans, or two versions of a plan, structurally, to see exactly what changed.

**Glue use:** When automatic planning (Layer 3) produces a different plan than last time, you can see why, and review only the differences.

**Guardrails:** Changes to write steps between plan versions require review before execution.

## Layer 9: Scheduling and resources

### G65. Weighted fair queuing and dominant resource fairness (DRF)

**Definition:** Sharing workers and resources fairly across many concurrent flows or tenants.

**Glue use:** Many flows built from different combinations can run at once without one large migration blocking everything else.

**Guardrails:** Every flow has at least a minimum guaranteed share, and a maximum cap.

### G66. Token bucket rate limiting

**Definition:** Limiting how fast operations happen, while allowing short bursts.

**Glue use:** Protects external services and shared indexes from bursts created by fan-out (G32) inside combined flows.

**Guardrails:** Set limits from the downstream service's real capacity, not guesses.

### G67. Admission control and load shedding

**Definition:** Deciding whether to accept new work, based on current load, and dropping or deferring low-priority work under overload.

**Glue use:** The engine stays stable even when many complex combinations are requested at once.

**Guardrails:** Never shed critical work, such as deletions, rollbacks or safety checks.

### G68. Bin packing for worker placement

**Definition:** Assigning steps to workers so that resources are used efficiently, without overloading any worker.

**Glue use:** Heavy steps (index builds, embedding batches) and light steps (filters, adapters) share hardware efficiently.

**Guardrails:** Leave headroom on every worker for bursts and system processes.

### G69. Work stealing

**Definition:** Letting idle workers take queued tasks from busy workers.

**Glue use:** Uneven sub-tasks (some repos huge, some tiny) finish without idle workers waiting.

**Guardrails:** Stealing must respect scope partition ownership (G47). Never steal a task assigned exclusively to one partition owner.

### G70. Priority aging

**Definition:** Gradually raising the priority of waiting tasks, so low-priority work eventually runs.

**Glue use:** Background flows (reindexing, quality checks) still complete while interactive flows get preference.

**Guardrails:** Cap the maximum aged priority below critical tasks.

### G71. Deadline scheduling (earliest deadline first)

**Definition:** Running the task with the nearest deadline first.

**Glue use:** Interactive requests with tight latency budgets get done in time, even when they're built from many steps.

**Guardrails:** Admission control (G67) rejects work that can't possibly meet its deadline, instead of accepting and failing.

### G72. Request coalescing (batching and deduplication of in-flight work)

**Definition:** Combining identical or similar requests that arrive close together, so the work is done once.

**Glue use:** When many flows need the same intermediate result at the same time, it's computed once.

**Guardrails:** Coalesce only read-only, deterministic steps. Keep permission scopes separate: different users' requests coalesce only if their access is identical.

### G73. Backpressure (Reactive Streams specification)

**Definition:** Consumers signal how much data they can accept, so producers never overwhelm them.

**Glue use:** In streaming flows (G14), a slow step automatically slows everything upstream, with no unbounded queues and no memory blowups.

**Guardrails:** Combine with timeouts. A consumer that stops requesting entirely must be detected.

## Layer 10: Distributed coordination (running the engine on many machines)

### G74. Leader election with leases

**Definition:** Choosing exactly one coordinator among several engine instances, with automatic takeover when it fails.

**Glue use:** One scheduler or planner is in charge at a time, so plans don't get executed twice by competing coordinators.

**Guardrails:** Always combine leases with fencing tokens (G75). A paused old leader may wake up still believing it leads.

### G75. Distributed locks with fencing tokens

**Definition:** Locks that come with an increasing number, so that stale lock holders are rejected by the resources they try to write.

**Glue use:** Safe exclusive access to shared targets (a repo branch, an index, a graph partition) across distributed workers.

**Guardrails:** Locks without fencing aren't safe for correctness. Use them only for efficiency.

### G76. Raft consensus for engine state

**Definition:** Keeping the engine's critical state (flow registry, plan states, locks) consistent across machines, tolerating failures.

**Glue use:** Flow states, budgets and locks never diverge between engine instances.

**Guardrails:** Run 3 or 5 nodes across failure zones, and keep large data out of the consensus log.

### G77. Transactional outbox for step results

**Definition:** Writing a step's result and its "completed" event in one local transaction, then publishing the event reliably.

**Glue use:** A step never finishes "silently". Its successors are always notified, even after crashes.

**Guardrails:** Alert on outbox backlog age.

### G78. Lease-based task claiming (visibility timeout)

**Definition:** Workers claim tasks for a limited time. Unfinished tasks return to the queue automatically.

**Glue use:** No task is lost when workers crash, across any number of combined flows.

**Guardrails:** Lease length must exceed typical task time. Long tasks must send heartbeats.

### G79. Consistent hashing for flow affinity

**Definition:** Routing related work to the same worker consistently, while moving as little as possible when workers change.

**Glue use:** The same repo's flows go to the same worker, which keeps its caches warm (G39) and avoids conflicting writes.

**Guardrails:** When ownership moves, hand off cleanly with fencing (G75).

### G80. Logical clocks (Lamport and vector clocks)

**Definition:** Ordering events across machines without relying on synchronized wall clocks.

**Glue use:** Correct ordering of results from distributed steps, and conflict detection for concurrent writes to shared context (G43).

**Guardrails:** Never order critical events by wall-clock time across machines.

### G81. Failure detection (heartbeats, phi accrual)

**Definition:** Deciding when a worker or component should be considered failed.

**Glue use:** Stuck or dead steps are detected and recovered automatically, inside any flow.

**Guardrails:** Tune thresholds to avoid flapping (marking healthy components as failed during short network hiccups).

## Layer 11: State management

### G82. Event sourcing

**Definition:** Storing every state change as an immutable event, and deriving the current state by replaying them.

**Glue use:** A complete, auditable history of every flow. It's the foundation of durable execution (G37) and deterministic replay (G51).

**Guardrails:** Events carry schema versions (G3). Replay code must handle old event versions.

### G83. CQRS (separate write model and read views)

**Definition:** Separating the model that records changes from the models that answer queries.

**Glue use:** Fast monitoring and progress queries over thousands of running flows, without slowing down execution.

**Guardrails:** Show view freshness. Decisions needing exact state read the write side.

### G84. Snapshots and log compaction

**Definition:** Periodically saving the full state, so replay starts from the snapshot instead of from the very first event.

**Glue use:** Long-running and repeated flows (G33) recover quickly, even after millions of events.

**Guardrails:** Verify snapshots by comparing them against a full replay periodically.

### G85. Copy-on-write branching of flow state

**Definition:** Creating cheap copies of the state to try alternatives in parallel, using persistent data structures.

**Glue use:** Speculative execution: try two combinations side by side, then keep the one that passes verification. No full copies needed.

**Guardrails:** Side effects (writes outside the engine) are never allowed on speculative branches.

### G86. Two-phase commit (when atomic multi-resource commits are available)

**Definition:** A protocol for committing changes to several resources all at once, or not at all.

**Glue use:** For steps writing to several transactional stores that support it, 2PC gives true atomicity. Otherwise use sagas (G38).

**Guardrails:** Use only within one trusted, reliable infrastructure. Across services, prefer sagas, because 2PC blocking hurts availability.

### G87. Optimistic concurrency (compare-and-swap)

**Definition:** Updating shared state only if it hasn't changed since you read it.

**Glue use:** Many parallel steps safely update the shared context (G43) and the registry (G2).

**Guardrails:** Cap the retries. Persistent conflicts mean the work should be partitioned (G47).

### G88. Lifecycle and garbage collection of intermediate artifacts

**Definition:** Cleaning up temporary results that are no longer needed by any flow.

**Glue use:** Combined flows produce many intermediate results. Without collection, storage grows without limit.

**Guardrails:** Never delete artifacts needed for running flows, rollbacks or required audits. Deletion of sensitive data follows the erasure rules.

## Layer 12: Adaptivity without AI (statistical learning, zero tokens)

### G89. Multi-armed bandits (UCB, Thompson sampling)

**Definition:** Learning which option works best by trying options and favoring the ones that perform well, while still occasionally testing the others.

**Glue use:** The engine learns from its own history which of several valid plans works best for each kind of task. It's cheap, statistical and needs no LLM.

**Guardrails:** Only choose among plans that already passed validation (G28). Bandits pick between safe options, never unsafe ones.

### G90. Online cost-model calibration

**Definition:** Continuously correcting the cost estimates used for planning, using real measurements.

**Glue use:** Plan selection improves automatically as the engine learns how each algorithm really behaves on your data and hardware.

**Guardrails:** Ignore outliers caused by incidents, and alert when estimates drift significantly.

### G91. Adaptive timeouts from latency percentiles

**Definition:** Setting each step's timeout from its observed latency distribution, instead of fixed guesses.

**Glue use:** Combined flows fail fast on truly stuck steps, without killing steps that are just slow on big inputs.

**Guardrails:** Absolute maximum timeouts always apply (G34).

### G92. Offline parameter search (grid, random, Bayesian optimization)

**Definition:** Finding good parameter settings by testing many configurations against a benchmark, before deployment.

**Glue use:** Tunes the default parameters of reusable flow templates (G63) once, offline, with no runtime cost.

**Guardrails:** Tune on representative benchmarks, and validate on held-out data.

### G93. Decision trees learned from execution logs (CART)

**Definition:** Learning simple, readable "if-then" selection rules from past flow results.

**Glue use:** Converts experience into explicit, reviewable selection rules. A tiny, cheap model, nothing like an LLM.

**Guardrails:** Rules learned from logs are reviewed before activation. Retrain periodically as conditions change.

### G94. Fallback ladders and graceful degradation

**Definition:** An ordered list of alternatives for each capability, from best to most basic, used automatically when better options fail or are too slow.

**Glue use:** Combined flows keep working, at reduced quality, when parts fail, instead of failing entirely.

**Guardrails:** Degradation is always visible in results and metrics. Correctness-critical steps (verification, permission checks) never degrade.

## Layer 13: Testing the glue

### G95. Property-based testing of flows

**Definition:** Testing flows with many automatically generated inputs, checking that general properties always hold.

**Glue use:** Finds bugs in combinations that hand-written tests miss, especially at the boundaries between algorithms.

**Guardrails:** Run property tests in CI for every reusable template (G63).

### G96. Contract testing between steps

**Definition:** Verifying that each producer's actual output matches what its consumers expect, independently of full end-to-end runs.

**Glue use:** With hundreds of algorithms and many combinations, contract tests catch incompatible changes early, without testing every combination end to end.

**Guardrails:** Every registry entry (G2) has contract tests for its declared outputs.

### G97. Fault injection (chaos testing)

**Definition:** Deliberately introducing failures to verify that flows recover correctly.

**Glue use:** Proves the reliability machinery actually works for real combinations, not just in theory.

**Guardrails:** Production fault injection needs approval, a limited blast radius and an instant stop switch.

### G98. Golden-flow regression testing

**Definition:** Running a fixed set of representative flows with known inputs, and comparing their results to approved outputs.

**Glue use:** Ensures that improving one algorithm doesn't silently change how other combinations behave.

**Guardrails:** Unexplained differences block deployment.

### G99. Static plan linting

**Definition:** Automatically checking flow definitions and plans against best-practice rules before running them.

**Glue use:** Catches dangerous combinations immediately, whether they were written by hand or generated by the planner.

**Guardrails:** Errors (as opposed to warnings) block execution.

### G100. Termination proofs with ranking functions

**Definition:** Proving that a loop or repeated flow must finish, by showing that some measure strictly decreases each round and can't go below zero.

**Glue use:** For repeated flows (G33), proves termination by design. For example, "each round fixes at least one remaining match, or stops".

**Guardrails:** Loops without a ranking function must have strict budgets, and are flagged by the linter (G99).

---

## Minimal core: what to build first

You don't need all 100 on day one. This core of 20 gives you composition of any combination, in any order, with repetition and scoped execution, without AI:

1. **Contracts and registry:** G1, G2, G5, G6.
2. **Plumbing:** G4 (adapters), G56 (CEL expressions), G57 (JSONPath bindings), G59 (canonical hashing).
3. **Composition:** G8 and G9 (DAG plus topological sort), G13 (behavior trees for fallbacks), G17 (composite flows).
4. **Automatic composition:** G21 (HTN methods encoding your recipes), G23 (type-directed plumbing), G28 (plan validation).
5. **Execution:** G33 (fixpoint loops), G34 (budgets), G37 (durable execution), G40 (idempotency).
6. **Scope:** G45 (scope narrowing).

Then add the rest in this order: safety (G48–G52, G99, G100), reliability (G35, G36, G38, G78), scale (G29–G32, G65–G73), distribution (G74–G81), state (G82–G88), and adaptivity (G89–G94).

Existing industry engines already implement large parts of this, so you can adopt them instead of building from scratch: Temporal for durable execution, Camunda for BPMN and DMN, Bazel's model for content-addressed incremental computation, and CEL for expressions. Your own work then becomes the registry, the contracts, the HTN methods and the scope rules: the parts specific to your 606 algorithms.
