# Gap Class 2: Spec → Code

Oct 16, 2026 · @Chief

## Purpose and scope

A spec→code gap is a written requirement that the code does not fully satisfy. \[Certain\] It is the most tractable gap class, because there is an explicit statement to check against, yet it still escapes because "built and tests pass" is mistaken for "satisfied".

Six sub-types, each needing a different detector:

| Sub-type | Meaning | Example | Why it hides |
| --- | --- | --- | --- |
| Omission | No implementation at all | Spec says retry; no retry code | Happy path works without it |
| Partial | Implemented for some cases only | Retries on timeout, not on 5xx | Tests cover one failure type |
| Divergence | Implemented differently | Spec says reject; code logs and continues | Looks handled |
| Phantom | Built but not live | Handler unregistered, or flag off in prod | Code exists, so reviews pass |
| Weakened | Guarantee holds only under narrower conditions | Exactly-once per hop, at-least-once end to end | Works until the edge condition |
| Drift | Was correct, a later change broke it | Refactor removed a check | No test pinned the behavior |

Confidence tags: **\[Certain\]** hard evidence or definition, **\[Likely\]** strong inference, **\[Guessing\]** verify before relying on it.

## Core assumption

**Assumption:** "If the feature is built and the tests pass, the spec is satisfied."

**What is wrong:** \[Certain\] Spec statements are universal claims: "always", "on failure", "every event". Tests and demos are existential evidence: "this case worked". No number of passing examples proves a universal claim.

**Why it is wrong:** Three mechanisms.

1. &#91;Certain\] **Sampling.** Tests cover the inputs, states and failures the author thought of. The requirement covers all of them.
2. &#91;Likely\] **Compressed claims.** Spec phrases hide preconditions. "Retry 3 times" silently assumes the operation is idempotent, the error is retryable, and retry budgets aren't multiplied across layers.
3. &#91;Certain\] **Correlated verification.** The same person wrote the code and the tests from the same understanding. A consistent misunderstanding passes everything.

**Correct model: refinement.** \[Certain\] The code satisfies the spec only if every behavior the code can exhibit is permitted by the spec (safety), and every required outcome eventually happens (liveness). The question is not "does the tested path match?" but "what is the full set of behaviors this code allows, and is any outside the spec?"

**Correct model: graded evidence.** Satisfaction is not binary. Grade each requirement:

| Grade | Evidence | What it proves |
| --- | --- | --- |
| 1 | Claimed | Nothing |
| 2 | Code exists | Something was attempted |
| 3 | Test exists and passes | Works on the sampled path, possibly against mocks |
| 4 | Passes against real dependencies and injected faults | Works under realistic and adverse conditions |
| 5 | Observed in production telemetry | Works in reality, now |

&#91;Likely\] Most teams stop at grade 3 and report "done".

**Meta question:** What would I observe if this requirement were not implemented, and am I seeing the opposite, or only the absence of contrary evidence?

**Second-order question:** If this requirement is truly satisfied, what else must also be true, and is that implemented too?

**How to identify:** Traceability with evidence grades, the outcome table, sabotage tests and fault injection (see the detection playbook).

**First-principles fix:** Treat each requirement as a predicate over all executions. Shrink the set of possible executions, hunt counterexamples adversarially, and make violations observable at runtime (see the derivation section).

## Sub-assumptions

Six beliefs account for most spec→code gaps. Each maps to one sub-type.

### 1. "The happy-path test proves the requirement" (Partial)

**What is wrong:** \[Certain\] A requirement such as "retry on transient failure" covers every transient failure type. A test that simulates one timeout covers one.

**Why, and what is correct:** \[Likely\] Authors test the scenario they implemented, which is the one they pictured. Correct: a requirement is covered only when each distinct case in its domain is exercised: each error class, empty and maximum inputs, concurrency, repetition.

**Meta question:** What is the full domain this requirement quantifies over, and which part of it did my tests sample?

**Second-order question:** Are the untested cases rare in tests but common in production (timeouts under load, duplicates during rebalances)?

**How to identify:** For each requirement, list its case domain explicitly, then map tests to cases. Uncovered cases are partial implementations until proven otherwise.

**First-principles fix:** Partition the input and failure space into equivalence classes and require one test per class. Use property-based testing to generate cases inside each class.

### 2. "If the code exists, the feature is live" (Phantom)

**What is wrong:** \[Certain\] Code can exist and never run: handler not registered, consumer not subscribed, middleware not attached, migration not applied, flag off in production, config key never read.

**Why, and what is correct:** \[Likely\] Code review looks at the code that changed, not at the wiring that connects it. Correct: a feature is live only when a path from a real entry point reaches it in the deployed configuration.

**Meta question:** What proves this code executes in production, not just that it compiles?

**Second-order question:** If it isn't live, what has been relying on it? Who believes a protection is in place that isn't?

**How to identify:** Reachability analysis from real entry points; feature-flag inventory with per-environment defaults; declared versus read config keys; production branch coverage or a per-feature metric.

**First-principles fix:** Require a runtime signal for every feature (a counter that increments when the path runs). A feature with a flat-zero signal in production is phantom.

### 3. "Our tests would catch it if it were wrong" (all sub-types)

**What is wrong:** \[Certain\] Tests can pass whether or not the requirement is implemented. Common causes: asserting only on status codes, mocks that return exactly what the code expects, assertions in loops that run zero times, swallowed exceptions in test helpers.

**Why, and what is correct:** \[Certain\] A test is evidence only if it fails when the behavior is absent. Correct: test sensitivity must be measured, not assumed.

**Meta question:** If I deleted the line implementing this requirement, which test would fail?

**Second-order question:** If the answer is none, how many other requirements are in the same state?

**How to identify:** Sabotage tests (delete or invert the enforcing line and run the suite); mutation testing on critical modules (PIT for JVM, gremlins or go-mutesting for Go, mutmut for Python, Stryker for TypeScript).

**First-principles fix:** Every requirement gets at least one test proven to fail without it. Replace mocks with real dependencies (Testcontainers, local brokers) for behavior that depends on them.

### 4. "The guarantee named in the code is the guarantee delivered" (Weakened)

**What is wrong:** \[Certain\] Names like "exactly-once", "transactional", "idempotent" or "durable" are claims with scope. Kafka exactly-once covers read-process-write within Kafka; an external database write in the same handler is outside it.

**Why, and what is correct:** \[Likely\] Configuration flags and library names create confidence without checking scope boundaries. Correct: a guarantee holds end to end only if every hop and side effect along the path provides it.

**Meta question:** Where exactly does this guarantee start and end, and what crosses that boundary?

**Second-order question:** If the guarantee is weaker than claimed, which downstream decisions (billing, counts, alerts) were built assuming the stronger one?

**How to identify:** Trace each guaranteed flow hop by hop and mark each hop's actual guarantee. The weakest hop is the real guarantee. Verify with fault injection: kill the process between side effects.

**First-principles fix:** Make every side effect idempotent with a stable key, or use an outbox or transactional pattern so all effects commit together. Then the guarantee doesn't depend on a single mechanism's scope.

### 5. "Error handling is present, so the requirement is handled" (Divergence)

**What is wrong:** \[Certain\] A `catch` or `if err != nil` block proves the error was noticed, not that it was handled as specified. Log-and-continue where the spec says reject is a divergence that looks like compliance.

**Why, and what is correct:** \[Likely\] Reviewers check for the presence of handling, not its semantics. Correct: each error path must produce the outcome the spec names (reject, retry, dead-letter, alert).

**Meta question:** What does the caller, the data and the operator observe after this error path runs?

**Second-order question:** If this path continues instead of failing, what corrupted or partial state does the next step build on?

**How to identify:** List every error branch in critical code. For each, write the observed outcome next to the spec's required outcome. Linters help find candidates: errcheck, staticcheck, detekt `SwallowedException`, ruff `BLE001`, `S110`.

**First-principles fix:** Make error outcomes explicit in types (result types or sealed error hierarchies) so each caller must choose an outcome, and count every non-success path with a metric.

### 6. "Once correct, it stays correct" (Drift)

**What is wrong:** \[Certain\] Refactors, dependency upgrades and config changes silently remove behavior that no test pins.

**Why, and what is correct:** \[Likely\] Requirements verified once during development are not re-verified unless a test encodes them. Correct: each requirement needs a standing check, not a one-time review.

**Meta question:** Which requirements are protected only by someone's memory?

**Second-order question:** When a library changes a default on upgrade, what will notice?

**How to identify:** Requirement-tagged tests with CI failing on orphans in both directions; diff dependency defaults on upgrade; re-run fault injection after major changes.

**First-principles fix:** Tag tests with requirement IDs and generate the traceability matrix from the code, so it can't go stale.

## Detection playbook

Match the detector to the sub-type. \[Certain\] No single technique finds all six.

| Detector | Finds | Effort |
| --- | --- | --- |
| Atomized spec + traceability matrix with evidence grades | Omission, phantom, drift | Medium, then standing |
| Outcome table per effect | Partial, divergence | Low per function |
| Sabotage and mutation testing | Unverified requirements of every type | Low (manual) to high (full mutation run) |
| Contract and schema diffs | Omission, divergence at interfaces | Low, automatable |
| Reachability, flag and config audit | Phantom | Low, automatable |
| Hop-by-hop guarantee trace | Weakened | Medium |
| Fault injection per requirement | Partial, weakened | Medium to high |
| Differential testing against a reference | Divergence | Medium, needs a reference |

### Step 1: Atomize the spec

&#91;Certain\] Rewrite each requirement as one numbered, testable statement with a trigger, a condition and an outcome. "The system is resilient" cannot be traced. "REQ-17: on broker timeout, retry up to 3 times with jittered exponential backoff, then route to DLQ and increment `ingest_dlq_total`" can.

### Step 2: Build the traceability matrix

One row per requirement: ID, code location, test IDs, evidence grade, deployed state, production signal. Run it in both directions:

- **Forward** (requirement → code): finds omissions and phantoms.
- **Backward** (code → requirement): finds untraced behavior, which feeds Gap Class 3.

### Step 3: Fill the outcome table for each effect

For every external call or state change in critical code, fill in what the code does and what the spec requires:

| Outcome | Code does | Spec requires | Match? |
| --- | --- | --- | --- |
| Success |  |  |  |
| Fast failure |  |  |  |
| Timeout |  |  |  |
| Succeeded but caller didn't see it |  |  |  |
| Partial success |  |  |  |
| Duplicate invocation |  |  |  |
| Concurrent invocation |  |  |  |
| Process dies right after |  |  |  |

&#91;Likely\] The "succeeded but unseen" and "process dies right after" rows produce the most findings in distributed systems.

### Step 4: Sabotage the enforcing lines

&#91;Certain\] For each requirement, delete or invert the line you believe enforces it, run the suite, and restore it. No failing test means the requirement is at evidence grade 2 at best.

### Step 5: Run mechanical diffs

- OpenAPI or proto definitions vs registered routes and handlers (oasdiff, buf breaking).
- ORM models vs migrations vs live schema.
- Declared config keys vs keys actually read.
- Feature flags with default state per environment.

### Step 6: Inject faults per requirement

For every requirement that mentions failure, inject each failure type it covers, not just one. Kill the process between side effects to test atomicity claims.

### Step 7: Differential test where a reference exists

&#91;Certain\] Run the old system, a reference model or a shadow deployment on identical input and diff the outputs. Divergences are either bugs or undocumented old behavior; both are findings.

## First-principles derivation

&#91;Certain\] Treat each requirement as a predicate P over executions. The code produces a set of possible executions E. The requirement is satisfied only if every execution in E satisfies P.

You cannot enumerate E: it spans inputs, states, interleavings, failures and timing. So there are exactly three levers.

### Lever 1: Shrink E structurally

Fewer possible behaviors means fewer to verify. \[Likely\] This is the highest-leverage lever and the most neglected.

- One code path per effect, not several that must stay consistent.
- Explicit state machines with enumerated transitions instead of flags combined ad hoc.
- Types that make illegal states unrepresentable: non-null types, sealed classes, newtypes for IDs and units, exhaustive `when` in Kotlin.
- Parse, don't validate: convert raw input to a validated type once at the boundary, so inner code can't receive invalid data.
- Outbox or transactional patterns instead of dual writes, which removes the partial-commit executions entirely.

### Lever 2: Hunt counterexamples adversarially

Search E for an execution that violates P, using sources that don't share the author's blind spots.

- Property-based tests that generate inputs inside each equivalence class.
- Fault injection across the outcome table.
- Model checking (TLA+, P) for protocol-level logic where a bug is costly.
- Tests written by someone who read the spec but not the code.

### Lever 3: Make violations observable

&#91;Certain\] Whatever survives levers 1 and 2 must announce itself when violated in production.

- A metric or reconciliation check per requirement.
- Conservation counts at boundaries: accepted = stored + rejected + dead-lettered + in flight.
- Alerts on invariant violations, not just on errors.

### Decompose each requirement before verifying it

| Part | Question | Example (REQ-17 retry) |
| --- | --- | --- |
| Trigger | When does it apply? | Broker returns a timeout or retryable error |
| Preconditions | What must already hold? | Publish is idempotent (producer idempotence on, stable key) |
| Mechanism | What code provides it? | Retry wrapper with capped jittered backoff |
| Outcome | What is observable after? | Published, or in DLQ with counter incremented |
| Evidence | What proves it? | Fault-injection test plus `ingest_dlq_total` in production |

&#91;Likely\] Most weakened and partial gaps come from an unverified precondition, not a missing mechanism.

## Worked example: retry and exactly-once in a consumer

The spec has three requirements:

- **REQ-17:** on transient failure, retry up to 3 times with jittered exponential backoff, then route to DLQ.
- **REQ-18:** invalid payloads go to DLQ with the reason.
- **REQ-21:** each payment changes the account balance exactly once.

This handler looks complete, and a happy-path test plus a "DB fails once" mock test both pass:

```go
func (c *Consumer) Handle(ctx context.Context, msg *kafka.Message) error {
    var ev Payment
    if err := json.Unmarshal(msg.Value, &ev); err != nil {
        log.Printf("bad payload: %v", err)
        return nil
    }
    for i := 0; i < 3; i++ {
        _, err := c.db.Exec(ctx,
            "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
            ev.Amount, ev.AccountID)
        if err == nil {
            break
        }
        time.Sleep(100 * time.Millisecond)
    }
    c.producer.Produce(ctx, "payments-applied", ev)
    return nil
}
```

### Findings

| # | Finding | Requirement | Sub-type |
| --- | --- | --- | --- |
| 1 | Invalid payload is logged and the offset commits; nothing reaches the DLQ | REQ-18 | Divergence |
| 2 | After 3 failures the loop falls through, never routes to DLQ, and still publishes "applied" | REQ-17 | Divergence |
| 3 | All errors are retried, including non-transient ones (constraint violations) | REQ-17 | Partial |
| 4 | Fixed 100 ms sleep with no backoff, no jitter and no context cancellation | REQ-17 | Divergence |
| 5 | The UPDATE is not idempotent; redelivery after a crash between write and offset commit applies the payment twice | REQ-21 | Weakened |
| 6 | DB write and produce are separate; a crash between them leaves the balance changed with no downstream event | REQ-21 | Weakened |
| 7 | Produce result is ignored, so a failed publish is silent | REQ-21 | Divergence |
| 8 | An UPDATE that matches zero rows (unknown account) is treated as success | REQ-21 | Divergence |

&#91;Certain\] Every finding survives both existing tests. The mock returns an error once and then success, so the exhausted-retry path, the crash windows and the zero-row case are never executed.

### Corrected shape (sketch, derived from the three levers)

```go
func (c *Consumer) Handle(ctx context.Context, msg *kafka.Message) error {
    ev, err := parsePayment(msg.Value) // parse into a validated type
    if err != nil {
        return c.dlq(ctx, msg, "invalid_payload", err) // REQ-18
    }
    err = retry.Do(ctx, retry.Policy{Max: 3, Base: 100 * time.Millisecond, Jitter: true},
        isTransient, func() error {
            return c.store.Tx(ctx, func(tx Tx) error {
                applied, err := tx.InsertProcessed(ev.EventID) // dedupe key, REQ-21
                if err != nil || !applied {
                    return err // already applied: idempotent no-op
                }
                n, err := tx.AddToBalance(ev.AccountID, ev.Amount)
                if err != nil {
                    return err
                }
                if n != 1 {
                    return ErrUnknownAccount // non-transient
                }
                return tx.Outbox("payments-applied", ev) // same transaction
            })
        })
    if err != nil {
        return c.dlq(ctx, msg, classify(err), err) // REQ-17
    }
    return nil
}
```

Lever 1 removes findings 5 and 6 structurally (dedupe key plus outbox in one transaction). Lever 2 needs new tests: exhausted retries, non-transient error, process killed after commit, duplicate delivery, zero-row update. Lever 3 needs counters on DLQ routing and on dedupe hits.

## Failure modes and checklist

### Where this method goes wrong

- &#91;Certain\] **Mocks as evidence.** A test against a mock that returns what the code expects is grade 3 evidence at best. Behavior that depends on a real broker or database needs a real one in the test.
- &#91;Likely\] **Same author, same blind spot.** If one person wrote the spec, code and tests, a consistent misunderstanding passes all three. Get at least one independent reader for critical requirements.
- &#91;Certain\] **A clean matrix against an incomplete spec.** This audit only covers what was written. It says nothing about Gap Class 1.
- &#91;Likely\] **Line coverage as a proxy.** High line coverage can coexist with untested requirements. Measure branch coverage, mutation score and per-requirement evidence grade instead.
- &#91;Likely\] **Staging that isn't production.** Different data volume, shape or config will certify gaps as closed.

### Audit checklist

- [ ] Every requirement is atomized with trigger, condition and outcome
- [ ] Traceability matrix exists, generated from requirement-tagged tests
- [ ] Every critical requirement is at evidence grade 4 or 5
- [ ] Outcome table filled for each external effect in critical paths
- [ ] Sabotage test run for each critical requirement
- [ ] Contract, schema and config diffs automated in CI
- [ ] Flag inventory reviewed per environment
- [ ] Every claimed guarantee traced hop by hop to its weakest link
- [ ] Fault injection covers each failure type a requirement names
- [ ] Every requirement has a production signal