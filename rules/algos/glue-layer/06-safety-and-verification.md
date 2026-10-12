
## Layer 6: Safety and verification

### G48. Invariant checking

**Definition:** Conditions that must hold at every step of every flow, checked continuously.

**Glue use:** Global safety rules hold no matter how algorithms are combined.

**Guardrails:** Invariants can't be disabled by individual flows.

### G49. Cycle and deadlock detection

**Definition:** Detecting circular dependencies and waits that would make a flow hang forever.

**Glue use:** Automatically composed plans can't hang.

**Guardrails:** Run cycle checks at planning time and deadlock checks at runtime.

### G50. Model checking of flows (temporal logic)

**Definition:** Exhaustively verifying that a flow model satisfies properties such as "always eventually finishes" or "never writes before approval".

**Glue use:** For critical reusable flows (safe edits, migrations, deletions), it proves that no combination of events or failures breaks the safety rules.

**Guardrails:** Keep models small and abstract. Check the critical properties, not every detail.

### G51. Deterministic replay testing

**Definition:** Re-running a recorded flow with the same inputs and checking that it produces exactly the same decisions and outputs.

**Glue use:** Lets you upgrade any algorithm and prove that existing combined flows still behave the same, or see exactly where they differ.

**Guardrails:** Treat any unexplained divergence as a failure.

### G52. Distributed tracing of flows (OpenTelemetry)

**Definition:** Recording every step of every flow as linked, timed spans, using the CNCF OpenTelemetry standard.

**Glue use:** For any combination, you can see exactly what ran, in which order, how long each step took, and where it failed.

**Guardrails:** No sensitive data in span attributes. Record IDs and hashes instead.
