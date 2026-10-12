
## Layer 3: Automatic composition (the engine picks the combination)

This layer solves "I myself won't know how to combine them". You state the goal; these algorithms find the combination.

### G18. STRIPS / PDDL classical planning

**Definition:** Automatically finding a sequence of actions that turns a starting state into a goal state, where every action has preconditions and effects. PDDL is the standard language of the International Planning Competition.

**Glue use:** You declare the goal "matches_replaced AND verified", and the planner discovers: list → filter → search → plan edits → check overlaps → apply → verify. You never wrote that sequence.

**Guardrails:** Give actions accurate preconditions and effects. Wrong contracts produce wrong plans. Cap planning time.

### G19. A* search over plan space

**Definition:** Finding the cheapest plan by searching through partial plans, guided by an estimate of the remaining cost.

**Glue use:** When several combinations reach the goal, the engine picks the cheapest. Brute force is chosen for a tiny corpus, an index for a huge one.

**Guardrails:** Cap the number of expanded nodes. If no plan is found within the cap, report it instead of searching forever.

### G20. Backward chaining (goal regression)

**Definition:** Planning backward from the goal: find a step that produces the goal, then find steps producing that step's requirements, and so on.

**Glue use:** Efficient when there are many algorithms but only a few relevant to the goal. Searching backward from "verified edits" skips every irrelevant algorithm.

**Guardrails:** Detect repeated sub-goals with memoization, to avoid infinite regress.

### G21. HTN planning (hierarchical task networks)

**Definition:** Planning by decomposing high-level tasks into subtasks using predefined "methods", like recipes, until only primitive actions remain.

**Glue use:** This is the most practical planner for your case. You encode industry recipes once as methods, such as the "How the entries fit together" sections at the end of each reference. The planner then adapts them to each task automatically.

**Guardrails:** Methods are reviewed like code. Cap the decomposition depth.

### G22. GOAP (goal-oriented action planning)

**Definition:** A lightweight planner, widely used in game AI, that chains actions by preconditions, effects and costs to reach a goal, re-planning quickly when the situation changes.

**Glue use:** A good fit when flows must adapt at runtime. For example, an index turns out to be stale, so the engine re-plans to "rebuild, then search".

**Guardrails:** Limit how often re-planning can happen, so the flow doesn't oscillate.

### G23. Type-directed composition (graph search over types)

**Definition:** Finding a chain of algorithms and adapters that converts an available input type into a required output type.

**Glue use:** Automatic "plumbing". To turn "natural-language concept" into "byte-range edits", the engine finds: embed → vector search → chunk-to-file mapping → structural search → edit list.

**Guardrails:** Prefer lossless paths. Lossy adapters (G4) carry a cost penalty.

### G24. Cost-based plan optimization (dynamic programming, Selinger-style)

**Definition:** Choosing the cheapest way to execute a plan by comparing alternative orders and implementations with cost models, as database query optimizers do.

**Glue use:** The same goal gets different combinations depending on data size and latency budget, chosen automatically.

**Guardrails:** Log the chosen plan and its estimated versus actual cost. Large estimation errors mean the cost models need updating.

### G25. Constraint satisfaction (CSP) for parameters and configuration

**Definition:** Choosing parameter values and component options that satisfy every constraint at once.

**Glue use:** Once the planner picks the algorithms, CSP picks their settings so the combined flow meets every budget and rule.

**Guardrails:** If no valid configuration exists, report which constraints conflict (a minimal conflict set) instead of silently relaxing them.

### G26. Rule engines (Rete) for algorithm selection

**Definition:** Declarative "if conditions then choose or do X" rules, evaluated efficiently by the Rete algorithm.

**Glue use:** Encodes your expert selection knowledge (the "when to use what" advice from all three references) as rules the engine applies automatically.

**Guardrails:** Test the rules with fixtures. Detect conflicting rules (two rules recommending incompatible choices).

### G27. Decision tables (DMN, OMG standard)

**Definition:** Tabular decision logic, where each row is an input-condition combination with an output. Standardized by OMG as DMN.

**Glue use:** A readable, reviewable alternative to code for selection logic, which non-programmers can audit.

**Guardrails:** Run completeness checks, so every input combination has a defined outcome.

### G28. Plan validation (VAL-style)

**Definition:** Independently checking that a generated plan is valid before running it.

**Glue use:** A safety net between automatic planning and execution: a bad plan is caught before any step runs.

**Guardrails:** Plans that include write or destructive steps always go through validation, plus human approval where required.

---
