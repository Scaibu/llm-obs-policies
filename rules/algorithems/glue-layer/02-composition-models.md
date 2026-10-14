
## Layer 2: Composition models (the shapes flows can take)

### G7. Pipes and filters

**Definition:** The simplest composition: a linear chain where each step's output is the next step's input.

**Glue use:** For example: list files (Code ref #7) → ignore filter (Code ref #3) → binary filter (Code ref #5) → multi-literal search (Code ref #24) → dedupe → report.

**Guardrails:** Bounded buffers between filters (Code ref #168) stop one fast step from flooding the next.

### G8. DAG workflows

**Definition:** Representing a flow as a directed acyclic graph: steps are nodes, and edges mean "this step needs that step's output".

**Glue use:** The standard shape for most combined tasks. Example: vector search and BM25 search run in parallel, then fusion, then rerank, then graph expansion.

**Guardrails:** Run cycle detection (G49) on every DAG before execution.

### G9. Topological sort (Kahn's algorithm)

**Definition:** Ordering DAG steps so every step comes after all of its dependencies.

**Glue use:** Converts any composed DAG into a valid execution order. The nodes in the ready queue at the same moment can run in parallel.

**Guardrails:** Break ties deterministically (by node ID), so the same plan always runs in the same order. That makes runs reproducible.

### G10. Finite state machines (FSM)

**Definition:** A model where a process is always in exactly one state, and defined events move it to defined next states.

**Glue use:** Controls the high-level lifecycle of a task. The Scout → Planner → Editor → Verifier roles from the code reference map directly onto states. For example, "verification failed" moves back to "planning", up to N times.

**Guardrails:** Every state has a maximum time and a failure transition, so nothing gets stuck.

### G11. Statecharts (hierarchical state machines, W3C SCXML)

**Definition:** State machines with nested states, parallel regions and history. They're standardized for execution as W3C SCXML.

**Glue use:** Complex flows stay readable. A parent state "migration" contains parallel regions "backfill" and "live sync", with one shared "abort" transition.

**Guardrails:** Keep nesting shallow (3–4 levels at most) and test every transition.

### G12. Petri nets (ISO/IEC 15909)

**Definition:** A formal model of concurrent processes, with places, transitions and tokens. It's well suited to synchronization and parallel joins.

**Glue use:** Models "wait until all 5 shard searches are done, but at most 3 run at once". Resource limits become tokens.

**Guardrails:** Run the deadlock and boundedness analysis on complex flows before deployment.

### G13. Behavior trees

**Definition:** A tree of control nodes and actions that decides what to do next on every tick. Widely used in robotics and games for modular, reactive control.

**Glue use:** Ideal for "try the cheap algorithm, fall back to the expensive one". For example: exact search → fuzzy search (Code ref #23) → semantic search (Vector ref #108), stopping at the first success.

**Guardrails:** Every repeat or retry decorator has a maximum count.

### G14. Dataflow and Kahn process networks

**Definition:** Composition where steps run whenever their input data is available, connected by FIFO channels.

**Glue use:** Continuous flows such as ingest → chunk → embed → index (Vector ref #125–131) running indefinitely, with each stage at its own speed.

**Guardrails:** Bounded channels everywhere, and monitoring of queue depth.

### G15. BPMN 2.0 (OMG standard)

**Definition:** The Object Management Group's standard notation and execution semantics for business and technical workflows.

**Glue use:** A standard, tool-supported way to define and visualize flows that combine algorithms. Human approval steps (the G5 guardrails in the earlier references) fit in naturally.

**Guardrails:** Version the models, and never edit a running instance's model in place.

### G16. Workflow control-flow patterns (van der Aalst catalog)

**Definition:** The established catalog of reusable control-flow building blocks for any workflow system.

**Glue use:** A checklist that guarantees your engine can express any combination you'll need. If an engine supports these patterns, it can express your flows.

**Guardrails:** Check that your chosen engine supports the patterns you use, especially cancellation and multi-instance.

### G17. Composite pattern (flows as building blocks)

**Definition:** Treating a whole flow as a single step with its own contract, so flows can be nested inside other flows.

**Glue use:** Build once, reuse everywhere. "Safe file edit" (Code ref #157–165) becomes one block. "Hybrid retrieve" (Vector ref #86–94) becomes one block. Bigger tasks combine blocks, not 40 individual algorithms.

**Guardrails:** A composite's contract must be tested against its internal behavior, using fixtures.

---
