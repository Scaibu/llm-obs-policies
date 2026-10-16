# Gap Class 1: Intent → Spec

Oct 16, 2026 · @Chief

## Purpose and scope

An intent→spec gap is a requirement that exists in someone's expectations but was never written down, so no one built, tested or monitored it. \[Certain\] No code tool can find these, because the code has nothing to contradict.

&#91;Likely\] This is the largest and most expensive gap class. A missing written requirement does not mean the system behaves neutrally: the language, framework or library decides the outcome instead, and that decision ships to production with no owner.

Confidence tags used throughout:

- **\[Certain\]**: backed by hard evidence or definition.
- **\[Likely\]**: strong inference from experience and mechanism.
- **\[Guessing\]**: filling gaps; verify before relying on it.

How to use this doc: read the core assumption first, then work through the sub-assumptions as an audit checklist. Each one follows the same structure: assumption, what is wrong, why, correct model, meta question, second-order question, how to identify, first-principles fix.

## Core assumption

**Assumption:** "If it isn't in the spec, it isn't required." The softer form: "the spec describes what we want."

**What is wrong:** \[Certain\] Stakeholders judge the system by what it does, not by what the document says. A customer charged twice after a retry does not care that "no duplicate charges" was never written. The requirement existed and was violated.

**Why it is wrong:** \[Likely\] A spec is a lossy compression of intent, and the loss is biased, not random. Authors write the scenario they picture, which is the happy path. They drop what feels obvious, what belongs to another team, and what only matters under failure, at scale or over time.

**Correct model:** \[Certain\] The true requirement set is everything a stakeholder would reject if they saw it happen. The spec is an early, partial sample of that set. Where the spec is silent, the requirement still exists, but it has no owner and no decision.

**Meta question:** How was this spec produced, and what does that process systematically fail to capture? Who wrote it, which scenarios were they picturing, and who was not in the room (ops, security, compliance, downstream consumers)?

**Second-order question:** If I decide an unspecified case one way, what else does that decision force, and who is affected without having been asked?

**How to identify:** Probe with concrete scenarios and watch for hesitation. A hesitation means nobody decided, so the code is deciding by default.

**First-principles fix:** Derive requirements instead of collecting them. A system exists to preserve properties of the world under adversity, so cross every protected property with every adversity and force a decision in each cell (see the derivation section).

## Sub-assumptions

Six specific beliefs produce most intent→spec gaps. Audit each one separately.

### 1. "Obvious things don't need writing down"

**What is wrong:** \[Certain\] The more obvious a requirement feels, the less likely anyone writes it, and the more damage its violation causes. "Deleted means deleted everywhere" and "a retry must not double-charge" are classic examples.

**Why, and what is correct:** \[Likely\] Obviousness is relative to one person's context. The implementer may not share it, and libraries certainly don't. Correct: an unwritten requirement is unverified, however obvious.

**Meta question:** Obvious to whom? Would a new hire, a contractor, or the library's default arrive at the same behavior?

**Second-order question:** If this "obvious" rule is violated silently, how long until someone notices, and what accumulates meanwhile (duplicate rows, stale caches, leaked data)?

**How to identify:** Ask stakeholders "what would make you furious if it happened?" and "what did the old system do that you rely on without thinking?" Every answer not found in the spec is a gap.

**First-principles fix:** Write the obvious as an invariant with an observable signal. If writing it feels silly, it costs one line; omitting it costs an incident.

### 2. "The spec covers failures because it covers the feature"

**What is wrong:** \[Certain\] Most specs describe success only. They are silent on timeouts, duplicates, partial writes, late data, overload and rollback.

**Why, and what is correct:** \[Likely\] Authors picture the feature working. Failure behavior feels like implementation detail, so it is delegated to whoever writes the code, who delegates it to defaults. Correct: failure behavior is product behavior; users experience it directly.

**Meta question:** For each operation, what does the spec say happens when it fails halfway?

**Second-order question:** If failure handling is decided per-developer, are the decisions consistent across services, or does each module fail differently?

**How to identify:** For every spec verb (accept, store, send, update, delete), ask the outcome for: fails fast, times out, succeeds but caller didn't see it, partially succeeds, runs twice, runs concurrently. Blank answers are gaps.

**First-principles fix:** Every operation gets a failure contract choosing one of: retry to success, fail visibly, degrade with a signal, or accept loss with an owner's sign-off.

### 3. "Words in the spec mean the same thing to everyone"

**What is wrong:** \[Certain\] Load-bearing words like "accepted", "processed", "real-time", "exactly once", "deleted" and "consistent" routinely carry different meanings for different readers.

**Why, and what is correct:** \[Likely\] Each role defines words by its own concerns. Product hears "accepted" as "won't be lost"; the engineer implements "enqueued in memory". Correct: a term in a spec must have one operational definition, stated as an observable condition.

**Meta question:** Which words in this spec decide data loss, money or user trust, and are any of them defined?

**Second-order question:** Which downstream promises (SLAs, support scripts, compliance claims) were written using a different meaning of the same word?

**How to identify:** Pick the 5 to 10 load-bearing terms. Ask three stakeholders separately to define each. Any disagreement is a gap.

**First-principles fix:** Keep a glossary of operational definitions: "accepted = durably written to at least 2 replicas before the 202 is sent". Link spec terms to it.

### 4. "Non-functional requirements are implied by 'production-grade'"

**What is wrong:** \[Certain\] "Fast", "scalable" and "reliable" have no numbers, so no implementation can fail them, and therefore none is held to them.

**Why, and what is correct:** \[Certain\] A requirement without a threshold is not testable. Correct: each quality has a measurable target, a measurement method and a load profile.

**Meta question:** What number would make us say this system is too slow, too lossy or too expensive?

**Second-order question:** If we pick a number, what does it force elsewhere: capacity, cost, architecture, on-call?

**How to identify:** Search the spec for quality adjectives. Each one without a number, unit and percentile is a gap.

**First-principles fix:** Specify p50/p99 latency, sustained and peak throughput, recovery time objective, data-loss tolerance and cost ceiling, each with its measurement source.

### 5. "Requirements describe what the system does"

**What is wrong:** \[Likely\] Specs list capabilities and omit prohibitions. Many of the costliest failures are "must never" violations: cross-tenant leaks, ack before durability, PII in logs, reordering within a key.

**Why, and what is correct:** \[Likely\] Prohibitions are invisible in demos, since a demo shows what happens, not what didn't. Correct: safety properties ("nothing bad ever happens") are first-class requirements alongside capabilities.

**Meta question:** What must this system never do, even once, even under failure?

**Second-order question:** If a prohibition is violated, can we detect it after the fact, or is the damage silent and irreversible?

**How to identify:** Run a pre-mortem focused on irreversible harm: data exposure, money movement, deletion, ordering violation. Each harm without a matching "never" requirement is a gap.

**First-principles fix:** Write prohibitions as invariants, prefer structural enforcement (types, permissions, isolation) over checks, and add a detection signal for each.

### 6. "Once written, the spec stays true"

**What is wrong:** \[Certain\] Intent moves: new customers, new regulations, new downstream consumers. The spec keeps describing yesterday.

**Why, and what is correct:** \[Likely\] Per Hyrum's Law, consumers come to depend on every observable behavior, documented or not. Real intent grows through use while the document stays frozen. Correct: the spec is a living artifact with an owner and a review trigger.

**Meta question:** When was this spec last checked against what users and downstream systems actually rely on?

**Second-order question:** If we change undocumented behavior someone depends on, who breaks, and would we know before they told us?

**How to identify:** Compare the spec with incident postmortems, support tickets and downstream consumers' code from the last 6 to 12 months. Each expectation found there but not in the spec is a gap.

**First-principles fix:** Tie spec review to events: every incident, every new consumer and every contract change triggers a spec update or an explicit accepted deviation.

## Detection playbook

&#91;Certain\] Intent is found outside the code: in people, incidents, older systems and downstream consumers. Use these sources in order of yield.

| Source | What to extract | Signal of a gap |
| --- | --- | --- |
| Incident postmortems | The requirement that would have prevented each incident | No matching spec line |
| Support tickets and escalations | What users believed was promised | Promise absent from spec |
| Old or replaced system | Its actual behavior, via differential testing | New system behaves differently and spec is silent |
| Downstream consumers' code | What they assume about your outputs | Assumption not guaranteed by spec |
| Stakeholder scenario probes | Accept/reject judgments on concrete cases | Hesitation or disagreement |
| Source documents (PRD, tickets, runbooks, contracts) | Statements about the same behavior | Two sources contradict |

### Scenario probe bank

&#91;Likely\] People cannot list requirements, but they judge concrete scenarios instantly. Ask each as "is this acceptable?":

1. The same request arrives twice, 3 seconds apart. Stored once or twice?
2. A dependency is down for 10 minutes. Reject, buffer in memory, buffer durably, or drop?
3. The caller times out but the write succeeded. What does the caller see on retry?
4. An event arrives 6 hours late. Counted in its original window, the current one, or discarded?
5. A payload contains an unknown field. Reject, ignore, or pass through?
6. Traffic hits 10× normal. Which requests are shed first, and who is told?
7. A record is deleted. Which copies (caches, replicas, logs, analytics, backups) must also go, and by when?
8. A tenant's request is slow because of another tenant. Acceptable, and up to what point?
9. Processing is replayed from last week. Is the result identical, and are side effects repeated?
10. A deploy is rolled back mid-migration. What state is valid?

### Stakeholder prompts

Ask these instead of "what are the requirements?":

- What would make you furious if it happened, even once?
- What did the previous system do that you rely on without thinking about it?
- What is the worst thing this could do silently?
- What would you have to tell a customer or regulator if it went wrong?

## First-principles derivation

Requirements can be derived, not just collected. \[Certain\] A system exists to preserve properties of the world under adversity, so the full requirement space is the product of those two lists.

### Step 1: List protected properties

Data integrity, no loss, no duplication, ordering, privacy and isolation, availability, latency, money correctness, auditability, cost.

### Step 2: List adversities

Dependency failure, slowness, duplicate delivery, reordering, late arrival, clock skew, overload, malformed or malicious input, operator error, deploy and rollback, schema change, long passage of time.

### Step 3: Fill the grid

Every cell needs one explicit decision. A blank cell is unwritten intent. Starter grid (adapt rows and columns to your system):

| Property ↓ / Adversity → | Dependency down | Duplicate delivery | Late arrival | Overload | Malformed input |
| --- | --- | --- | --- | --- | --- |
| No loss |  |  |  |  |  |
| No duplication |  |  |  |  |  |
| Ordering |  |  |  |  |  |
| Isolation |  |  |  |  |  |
| Latency |  |  |  |  |  |

### Step 4: Choose a decision type per cell

1. **Guarantee:** the property holds under this adversity, with a named mechanism.
2. **Degrade:** the property weakens in a defined way, with a signal when it happens.
3. **Accept loss:** the property can break, with an owner's sign-off and a recorded rationale.

&#91;Certain\] "Accept loss" is legitimate. "Never decided" is not, because it is still a decision, made by a default.

### Step 5: Test each requirement's quality

A requirement is usable only if it passes all three tests:

- **Falsifiable:** a specific observation would prove it violated.
- **Observable:** the running system can emit that observation (metric, reconciliation count, audit record).
- **Owned:** a named person decides if it changes.

&#91;Certain\] A requirement that fails the observability test cannot be known to hold in production. It is a hope.

### Step 6: Record accepted deviations

Keep a list: requirement, decision, owner, date, revisit trigger. \[Likely\] Without it, teams rediscover the same "gaps" every audit and argue the same decisions again.

## Worked example: event ingestion endpoint

The written spec says only: "Clients POST events to /ingest. The service validates and publishes them to Kafka, returning 202." It demos fine and passes its tests. Running the probes exposes seven unwritten requirements.

| Probe | Unwritten intent found | Decision needed |
| --- | --- | --- |
| What does 202 mean? | Product assumes "won't be lost" | Define accepted = durably acked by broker before 202 |
| Same event sent twice? | Analytics assumes deduplicated counts | Require an event ID and a dedupe window, with its length stated |
| Broker down 10 minutes? | Ops assumes no data loss | Choose: reject with 503, or buffer durably to a stated limit |
| Per-user ordering? | A downstream consumer assumes it | Partition by user ID, or state that ordering is not guaranteed |
| Unknown fields? | Data team expects new fields to flow through | Choose strict reject or pass-through, and version the schema |
| 10× traffic spike? | Nobody had an answer | Define a shedding policy and the response clients get |
| Late events (hours)? | Reporting assumes event-time windows | Define the lateness bound and what happens beyond it |

&#91;Likely\] The code for this endpoint could pass every review and still violate four of these, because reviewers check code against the spec, and the spec never stated them. That is the defining property of this gap class.

## Failure modes and checklist

### Where this method goes wrong

- &#91;Likely\] **Over-specification.** Filling every grid cell for every component produces a spec nobody maintains. Prioritize cells whose violation is silent, irreversible or cross-tenant.
- &#91;Likely\] **Interviewing the wrong people.** Authors confirm their own intent. The yield is in ops, support, security and downstream owners.
- &#91;Likely\] **Lost history.** If the people who knew why behavior exists have left, the old system's actual behavior is the only record. Capture it with characterization or differential tests before replacing anything.
- &#91;Certain\] **Treating "accepted deviation" as failure.** Recording a conscious decision not to meet something is a valid outcome. Hiding it is not.

### Audit checklist

- [ ] Load-bearing terms have operational definitions in a glossary
- [ ] Every operation has a failure contract (retry, fail visibly, degrade, accept loss)
- [ ] Every quality adjective has a number, unit, percentile and measurement source
- [ ] Prohibitions ("must never") are written as invariants
- [ ] Properties × adversities grid is filled for critical flows
- [ ] Every requirement is falsifiable, observable and owned
- [ ] Last 12 months of incidents are mapped to requirements
- [ ] Downstream consumers' assumptions are captured
- [ ] Accepted deviations are recorded with owner and revisit trigger
- [ ] Spec review is triggered by incidents, new consumers and contract changes