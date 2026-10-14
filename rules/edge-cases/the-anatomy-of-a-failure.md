# Beneath the Edge Cases: A Root-Cause Guide

The earlier lists described **where** edge cases appear. This article asks **why they exist at all**.

An empty list, a NULL, a duplicate message, and a full disk are not separate problems. They are a handful of deeper failures, such as wrong models, unenforced rules, and unseen limits, showing up in different places. If you fix only the symptom, the same root cause produces a new symptom next quarter.

---

## Part 1: The Anatomy of a Failure

Every incident has layers. Stopping at the wrong layer is the most common investigation mistake.

| Layer | Question it answers | Example (customer charged twice) |
|---|---|---|
| **Symptom** | What did we observe? | Customer has two charges |
| **Trigger** | What set it off? | Client timed out and retried |
| **Proximate cause** | What directly made the bad thing happen? | Server processed the same request twice |
| **Contributing conditions** | What made the trigger likely or the damage larger? | 3s timeout vs. 4s p99 latency; retries on by default; no backoff |
| **Root cause** | Which structural flaw allowed this whole *class* of failure? | The "charge once" rule is enforced nowhere authoritative; it depends on callers behaving well |
| **Latent conditions** | What long-standing weaknesses were waiting for a trigger? | No idempotency concept in the API; no reconciliation job; no alert on duplicate charges |

**Triggers are nearly random. Root causes are structural.** The trigger (a timeout) could have been a double-click, a queue redelivery, or a deploy restart. If your fix targets the trigger ("increase the timeout"), the next trigger still works. If your fix targets the root cause ("the database makes duplicate charges impossible"), every trigger is neutralized at once.

**A test for having reached a root cause:** if you fix it, does the *whole class* of failures disappear, including ones you haven't seen yet? If only this exact incident disappears, you are still at the proximate cause.

**Why "5 Whys" often fails.** It assumes a single linear chain. Real failures have several parallel causes, and people stop asking when they hit a person ("the engineer forgot") or a vague label ("human error"). "Human error" is never a root cause. It is a signal that the system allowed a single mistake to be catastrophic. The better question is: *why was it possible, easy, and undetected?*

---

## Part 2: A Taxonomy of Root Causes

There are about eleven families of root causes. Nearly every edge case, in code, databases, and infrastructure, traces back to one or more of them. For each family I cover the mechanism (why it happens), why it stays hidden, how it shows up, the questions that expose it, and the structural fix.

### Family A: Hidden Assumptions (we believed something false)

**Mechanism.** Every design rests on beliefs that feel too obvious to write down. They go unexamined because they were true when the design was made and stayed true for a long time.

**Subtypes**
- **Cardinality assumptions:** "there will always be at least one," "only one," "few."
- **Environmental assumptions:** "the network is reliable," "the clock is right," "the disk has space," "latency is low."
- **Behavioral assumptions:** "callers send valid data," "clients don't retry," "users don't double-click," "the other team won't change this."
- **Stability assumptions:** "this value never changes," "this enum has three values," "this field is always present."
- **Scale assumptions:** "this table stays small," "this loop runs a few times."

**Why it stays hidden.** Assumptions are invisible to their author, and tests are written by the same author from the same mental model. The test suite verifies your beliefs against your beliefs.

**Shows up as:** empty-list crashes, division by zero, overflow, disk full, clock skew bugs, enum-switch crashes on new values.

**Exposing questions**
- Complete the sentence "This works because ___" for every component. Each blank is an assumption.
- Which of these is *enforced* (by a constraint, type, or monitor) and which is merely *believed*?
- When did I last see this assumption fail? If never, is that because it cannot, or because I never looked?

**Structural fix.** Convert beliefs into enforced facts (constraints, types, limits) or monitored facts (alerts when violated). An assumption you cannot enforce should at least be *detectable*.

### Family B: Wrong or Incomplete Domain Models (we modeled reality poorly)

**Mechanism.** Software is a simplified model of the world, and the simplification leaves out or blurs things that matter.

**Subtypes**
- **Conflated concepts:** one representation used for different meanings. NULL used for "unknown," "not applicable," "not yet provided," and "deliberately empty" all at once. A single `status` field that mixes lifecycle state with outcome.
- **Identity confusion:** what makes two things "the same"? Same email? Same person with two emails? Same device? Is "user" one human or one account? Is an entity identified by a mutable attribute (email, phone, name)?
- **Representation vs. meaning:** a string is not a name, a float is not money, a timestamp is not a date, a number is not a quantity-with-unit. Text that looks equal but is not (Unicode forms) and values that differ but mean the same (casing, formatting).
- **Time modeled wrongly:** treating an instant, a local civil time, a duration, and a calendar date as interchangeable.
- **Missing states:** modeling only the states you imagined, not "partially created," "pending for years," "deleted but referenced," "legacy."
- **Snapshot vs. reference:** should this record point at the live value or freeze the value at that moment? (An order should freeze price and address.)

**Why it stays hidden.** The model works for typical data. It breaks only when reality contains a case the model has no slot for. These are the "falsehoods programmers believe about names/time/addresses" class.

**Shows up as:** normalization and comparison bugs, duplicate customers, timezone bugs, wrong totals from rounding, data that "can't exist" existing.

**Exposing questions**
- What are *all* the real-world situations this concept covers? Which does my model collapse together?
- What does each value (NULL, empty, zero, default) mean, in words, and does everyone agree?
- Is this field an identity, a label, or a description? Can it change?
- If a domain expert read my schema, what would they say is missing?

**Structural fix.** Model distinct meanings distinctly (separate fields or types). Use domain types (Money, EmailAddress, UtcInstant, CivilDate) instead of primitives. Write down the state machine, including forbidden transitions. Decide explicitly which data are snapshots and which are references.

### Family C: Unenforced Invariants and Split Ownership (the rules live in people's heads)

**Mechanism.** An invariant is a statement that must always be true ("a balance is never negative," "one active subscription per user," "an order has at least one item"). Failures occur when the invariant is not enforced at the single place that owns the data, so it depends on everyone else behaving correctly forever.

**Subtypes**
- **Enforced in the wrong layer:** only in the UI, or only in app code, while other writers (scripts, admin tools, other services, migrations, future code) bypass it.
- **Multiple sources of truth:** the same fact stored in two places, with no rule for which wins or how they converge.
- **Check separated from act:** validating in one step and acting in another, with time between (TOCTOU).
- **Invariants spanning entities:** rules across multiple rows or services ("total of children equals parent") that no single constraint covers.
- **Duplicated logic:** the rule implemented in four places; three get updated.
- **Implicit invariants:** nobody has listed them, so nobody knows which exist.

**Why it stays hidden.** With one writer and low concurrency, application checks appear to work. The gap opens only with concurrency, second writers, or bulk operations.

**Shows up as:** duplicates, negative balances, orphan rows, overselling, double booking, mismatched totals, tenant data leaks (a missing filter in one query), forgotten soft-delete filters.

**Exposing questions**
- List the invariants. For each: *who* enforces it, *where*, and what happens if a different writer arrives?
- Could I violate this with a raw SQL statement? If yes, the invariant is a suggestion.
- Is this fact stored once? If twice, which is authoritative and how is the copy repaired?
- What must be true *across* records, and what enforces it under concurrency?

**Structural fix.** Enforce each invariant at the lowest authoritative layer (the database for data rules, one service for business rules). Make illegal states unrepresentable. Keep one source of truth; treat copies as rebuildable caches. Centralize shared rules so they cannot drift.

### Family D: Boundary and Contract Failures (two sides, two meanings)

**Mechanism.** Most serious failures sit *between* components, not inside them. Each side is correct by its own understanding, and the understandings differ.

**Subtypes**
- **Semantic mismatch:** units (seconds vs. milliseconds, cents vs. dollars), nullability ("absent" vs. "null" vs. "empty"), timezones, inclusive vs. exclusive ranges, ID formats, case sensitivity.
- **Behavioral mismatch:** one side retries, the other is not idempotent. One side's timeout is longer than the other's. One side assumes ordering, the other does not guarantee it.
- **Implicit contracts:** the contract exists only as "how it happens to behave" (field order, rate of response, undocumented side effects). Consumers come to depend on accidents.
- **Schema without semantics:** the types match, but the meaning does not. A field named `status` is a string in both systems, with different allowed values.
- **Unversioned change:** a producer changes output; consumers learn from production.
- **Liberal acceptance:** accepting malformed input "to be friendly," which spreads garbage into the system and makes the accepted behavior a permanent contract.

**Why it stays hidden.** Each team's tests pass. The failure exists only in the integration, which no single owner tests.

**Shows up as:** off-by-factor bugs, parsing failures, lost updates, unexpected nulls, consumer crashes after a "harmless" producer change, retry-caused duplicates, timeout mismatches.

**Exposing questions**
- At each boundary: what does the other side *think* this means? Have we verified it or assumed it?
- What guarantees does the other side actually give (delivery, ordering, idempotency, latency, error behavior)? Where are they written?
- Who finds out first if the other side changes?
- What are we depending on that was never promised?

**Structural fix.** Make contracts explicit, typed, versioned, and machine-checked (schemas, contract tests, compatibility checks in CI). Validate strictly at the boundary. Document semantics, not just shapes. Put unit and meaning into names and types.

### Family E: Temporal and Causal Assumptions (we assumed a simple timeline)

**Mechanism.** Code reads as sequential and instantaneous. Reality is concurrent, delayed, reordered, and repeated.

**Subtypes**
- **Synchrony assumption:** a call either happens or it does not, instantly. In truth there is also "happened but I don't know," "will happen later," and "happened twice."
- **Atomicity assumption:** a multi-step operation succeeds or fails as a whole. In truth it can stop after any step.
- **Ordering assumption:** events arrive in the order they occurred. In truth: late, reordered, duplicated.
- **Single-version assumption:** one version of code and schema runs at a time. In truth: rolling deployments, old clients, old queued messages.
- **Single-instance assumption:** one process runs this job. In truth: several, or none.
- **Wall-clock trust:** using time as a reliable ordering or lock across machines.
- **Delivery assumption:** exactly-once, when what you have is at-least-once or at-most-once.

**Why it stays hidden.** Development runs one instance, on one machine, quickly. The timeline is trivially simple.

**Shows up as:** race conditions, lost updates, double processing, stuck states, out-of-order corruption, version-skew crashes during deploys, stale reads.

**Exposing questions**
- Between any two lines of this operation, what can change in the world?
- What if this stops after step 2 of 5? Who notices, and who cleans up?
- If two of these run simultaneously, or the same one runs twice, what happens?
- What if the old and new versions are both live for an hour?
- What does "success" mean when the response is lost?

**Structural fix.** Make operations idempotent and safe to repeat. Use atomic primitives (transactions, conditional writes) rather than read-then-write. Use leases with expiry rather than flags. Treat messages as at-least-once and dedupe. Design for old-and-new coexistence. Use logical ordering (versions, sequence numbers) rather than wall clocks. Add reconcilers for anything that could get stuck.

### Family F: Unbounded Resources and Missing Feedback Control (limits nobody set)

**Mechanism.** Anything without a limit will eventually meet one, and it will usually be the limit of the worst possible component at the worst possible time. Systems also contain *feedback loops*: when a component slows, the reaction to the slowness often makes it slower.

**Subtypes**
- **Unbounded growth:** tables, logs, queues, caches, temp files, in-memory maps, retry counts, result sets, payload sizes.
- **Finite counters and quotas:** integer IDs, sequences, file descriptors, ports, connection pools, API quotas, cloud service limits, disk and inodes.
- **Positive feedback loops:** retries add load to a struggling service; autoscaling floods the database; cache expiry triggers a stampede; a failing health check removes a node, which overloads the rest, which fail their health checks.
- **Missing backpressure:** producers can outrun consumers without any signal.
- **Hidden cost behind abstractions:** a method that looks cheap (`order.customer`) that triggers a query; a loop that looks small but multiplies (N+1, fan-out, nested loops).
- **Averages hiding tails:** planning for the typical customer and failing on the largest, the hottest key, or the p99.

**Why it stays hidden.** Early on, everything is small and fast, so the missing limit has no visible effect. Then growth is slow, so the threshold arrives without warning. Failures here are **nonlinear**: fine, fine, fine, outage.

**Shows up as:** N+1 queries, full-table scans at scale, disk full, queue backlogs, retry storms, cascading failures, out-of-memory kills, OFFSET pagination collapse, ID exhaustion, runaway cloud bills.

**Exposing questions**
- What grows without bound? What is the maximum that is *designed for*, and what enforces it?
- What happens to load when things go wrong? Does it go down (good) or up (dangerous)?
- What has a finite capacity, how full is it, and who is alerted at 70%?
- What is the cost (queries, memory, calls) of the innermost loop at 100× data?
- What does the largest customer's data look like, not the average?

**Structural fix.** Put an explicit limit on everything (size, time, count, rate, retries). Add backpressure and load shedding. Use backoff with jitter, circuit breakers, and timeout budgets so failure reduces load. Make cost visible (query counts in tests and metrics). Track *headroom* on every finite resource with alerts well before exhaustion. Test with production-scale and worst-case data.

### Family G: Hidden Coupling and Shared Fate (independent things that are not)

**Mechanism.** Components designed as independent share something invisible: a database, a DNS provider, a certificate authority, a config system, a cache, a person, a region, a library version, a clock. When the shared thing fails, all fail together.

**Subtypes**
- **Common-mode failure:** redundant replicas that share a power source, deployment pipeline, bad config, or bug. Redundancy protects against random failures, not common-cause ones.
- **Hidden hard dependency:** a component believed optional (a cache, a feature-flag service, an analytics call) that is in the critical path.
- **Dependency on the recovery tool:** the dashboard, login, runbook, or deploy system is hosted on the thing that is down.
- **Coupling through data:** many services depend on one table's shape.
- **Blast radius coupling:** one tenant, one query, one bad message, or one deploy can take down everything because nothing isolates failures.

**Why it stays hidden.** The diagram shows boxes and arrows you drew. The real dependencies include the ones you did not draw.

**Shows up as:** outages larger than any single failure should cause, "failover didn't help," inability to fix the problem because the fix tooling is also down.

**Exposing questions**
- What do these "independent" things have in common?
- If this one component vanished, what actually stops? (Try it and see.)
- What do we need *in order to* recover, and does it depend on the failed system?
- How far can one bad input, tenant, or release spread?

**Structural fix.** Map real dependencies (including implicit ones). Isolate with bulkheads, cells, and per-tenant limits. Stage changes (canary, gradual rollout). Keep recovery tooling independent. Convert soft dependencies to truly soft ones (defined degraded behavior when they fail).

### Family H: Blindness (we cannot see the failure)

**Mechanism.** A failure you cannot observe is a failure you cannot prevent from growing. Silent failures are the most expensive because they accumulate.

**Subtypes**
- **Measuring proxies, not outcomes:** "the server is up" instead of "customers can check out."
- **No invariant monitoring:** nothing checks that rules still hold (no duplicate-charge detector, no orphan scan, no reconciliation).
- **Swallowed errors:** empty catch blocks, default values that hide failure, logs nobody reads.
- **Alert quality problems:** too many alerts (fatigue), too few, wrong audience, unowned.
- **Aggregates hiding problems:** averages hiding tail latency; global metrics hiding one failing tenant or region.
- **Monitoring that shares fate** with the monitored system.
- **Normalization of deviance:** recurring warnings treated as background noise until one matters.

**Why it stays hidden.** By definition. You only discover blindness when something fails and you realize no signal existed.

**Exposing questions**
- How would we know this is happening? Which metric, log, or alert?
- Could the system be quietly wrong for a week? What would show it?
- Does every alert have an owner, a meaning, and an action?
- What are we *not* measuring that customers experience?

**Structural fix.** Monitor outcomes and invariants, not just health. Build reconcilers and audits that continuously verify the rules. Fail loudly on impossible states. Track tail latency and per-segment metrics. Regularly test that alerts actually fire.

### Family I: Change and Evolution Failures (the system is not static)

**Mechanism.** The design was correct for the system as it was. Code, data, dependencies, scale, and usage all keep moving, so a correct design drifts into incorrectness.

**Subtypes**
- **Irreversible changes:** migrations that lose information, deletes, sent messages, schema changes that cannot be rolled back.
- **Version skew:** old and new code or schema active at once.
- **Config as unreviewed code:** runtime configuration changes carrying code-level risk without code-level review or rollout discipline.
- **Drift:** staging differs from production; docs differ from reality; infrastructure differs from its definition.
- **Dead-but-reachable paths:** old clients, old flags, old queue messages that still exercise forgotten code.
- **Dependency drift:** upgraded libraries, unpinned images (`latest`), changed third-party behavior.
- **Usage drift:** the feature used in ways it was not designed for, at a scale never planned.

**Exposing questions**
- Can we undo this change, including the data part? Have we rehearsed it?
- What runs during the transition, and is everything compatible with everything else?
- What changes in this system even if nobody touches it?
- How would we find out that reality drifted away from the design?

**Structural fix.** Expand → migrate → contract for any change in shared structures. Make changes small, staged, and reversible by default. Treat config like code. Pin dependencies. Automate drift detection. Keep tests for old formats and old clients for as long as they exist.

### Family J: Verification Failures (our tests cannot catch it)

**Mechanism.** The testing process is built from the same mental model as the code, so it shares the same blind spots. It also operates in conditions unlike production.

**Subtypes**
- **Author-shaped tests:** tests encode the author's expectations, not reality's variety.
- **Unrepresentative data:** small, clean, recent, unique, well-formed data in tests; huge, messy, old, duplicated data in production.
- **Missing dimensions:** nothing tests concurrency, failure midway, duplication, scale, slowness, or clock changes.
- **Untested recovery:** backups never restored, failover never run under load, rollbacks never rehearsed, runbooks never followed.
- **Environment mismatch:** different configuration, scale, topology, and versions.
- **Happy-path coverage:** high coverage numbers that test only expected flows.

**Exposing questions**
- What kind of failure could exist that none of our tests would ever produce?
- When did we last actually *do* the recovery, not just document it?
- How different is our test data from the worst production data?

**Structural fix.** Property-based and fuzz testing to escape the author's imagination. Production-shaped test data. Fault injection and game days. Periodic restore and failover drills. Test the recovery, not just the system.

### Family K: Human, Incentive, and Organizational Causes (why the system allows the above)

**Mechanism.** Technical root causes exist inside an organization whose incentives, structure, and communication determine which problems get noticed and fixed. Many "technical" failures are organizational failures wearing a technical costume.

**Subtypes**
- **Incentive misalignment:** shipping is rewarded; preventing invisible disasters is not. The team that saves an outage gets no credit because nothing visibly happened.
- **Ownership gaps:** a component, a dependency, a cron job, or a certificate that nobody owns. Or a boundary between two teams that neither owns (Conway's law: your system's seams mirror your org's seams).
- **Knowledge silos:** critical understanding held by one or two people; undocumented; lost on departure.
- **Time pressure and deferred risk:** known weaknesses accepted "temporarily" and never revisited.
- **Review blindness:** reviewers check the diff, not the assumptions. Nobody reviews what the code *doesn't* handle.
- **Error-inducing tooling:** dangerous commands indistinguishable from safe ones; production and staging that look identical; destructive operations without confirmation.
- **Normalization of deviance and drift into failure:** each small shortcut is safe on its own, and the safety margin erodes gradually until nothing is left.
- **Blame culture:** if people are punished for surfacing problems, problems go underground, and the organization loses its sensors.

**Exposing questions**
- Who owns this, by name, at 3 a.m.? Who owns the *boundary* between these two things?
- If the most knowledgeable person left tomorrow, what breaks?
- What risk did we knowingly accept, and who revisits that decision?
- Is it easier to do the dangerous thing than the safe thing?
- Do people feel safe reporting near-misses?

**Structural fix.** Assign explicit ownership (including orphans and boundaries). Make the safe path the easy path (guardrails, confirmations, environment cues, deletion protection). Keep a risk register with owners and review dates. Use blameless postmortems and track near-misses. Reward prevention visibly. Spread knowledge through rotation and documentation.

---

## Part 3: Mapping Symptoms to Root Causes

The edge cases you named originally are *symptoms*. Here is the root cause family behind each, and the question that reaches it.

| Symptom | Usual root cause family | The deeper question |
|---|---|---|
| Crash on empty list | A (cardinality assumption), D (unstated contract) | What did the caller promise, and who enforces it? |
| NULL surprises | B (conflated meanings), D (nullability mismatch) | What does "no value" mean here, in words? |
| Comparison or matching bugs | B (representation vs. meaning), D | What makes two values "the same," and who decides? |
| Normalization drift | B, C (logic duplicated across places) | Where is the single canonical form created? |
| Duplicate records | C (unenforced uniqueness), E (concurrency, retries) | Which layer guarantees uniqueness under concurrency? |
| Idempotency failures | E (delivery and atomicity assumptions), D (retry contract) | What happens when this runs twice, and who guarantees it? |
| Broken database contracts | C (enforced in wrong layer), D, I (drift) | Can a different writer violate this rule? |
| Code repetition bugs | C (duplicated invariant), K (ownership) | Where does this rule live, and how many copies exist? |
| N+1 queries | F (hidden cost behind abstraction), J (small test data), H (no cost visibility) | What does this line *cost*, and who would notice at scale? |
| Lost updates, double booking | E (check separated from act), C | What changes between the check and the action? |
| Stuck jobs | E (no timeout or lease), H (no reconciler) | What if the worker dies halfway? Who notices? |
| Retry storm or cascade | F (positive feedback), G (shared fate), D (timeout mismatch) | Does load rise when failure happens? |
| Cache stampede | F (feedback), G (hidden hard dependency) | Can the source survive the full load if the cache vanishes? |
| Certificate or key expiry | F (finite thing), H (unmonitored), K (no owner) | What has an expiry date, and who owns each one? |
| Disk or ID exhaustion | F (unbounded growth), H | What has a capacity, and what's the alert at 70%? |
| Failed rollback or migration | I (irreversibility), J (untested) | Have we rehearsed the undo, including the data? |
| Failover didn't work | G (shared fate), J (untested recovery) | When did we last fail over for real, under load? |
| Data leak across tenants | C (filter duplicated, not enforced), K | Is tenant isolation enforced structurally or by discipline? |
| "Nobody noticed for weeks" | H (blindness), K (alert fatigue, ownership) | What would show this, and who would look? |

Notice how few families appear repeatedly: **C, E, F, and H account for a large share of serious incidents.** Unenforced invariants, broken timeline assumptions, unbounded resources, and blindness are worth your deepest attention.

---

## Part 4: Causal Chains in Depth

### Case 1: The NOT IN query that returns nothing

- **Symptom:** a report that "excluded banned users" suddenly shows zero rows.
- **Trigger:** one row inserted into `banned_users` with a NULL id.
- **Proximate cause:** `NOT IN` against a set containing NULL evaluates to UNKNOWN for every row.
- **Contributing conditions:** the column allowed NULL; the query author did not know three-valued logic; test data had no NULLs.
- **Root causes:** **B** (NULL has several meanings; the model allows a state that should be impossible), **C** (no `NOT NULL` constraint, so the invariant "every banned row has an id" is unenforced), **J** (tests never contained the weird row).
- **Class-level fix:** make the column `NOT NULL`, and more broadly make NOT NULL the default for all columns. Change the team's query habits (prefer `NOT EXISTS`). Add NULL-containing rows to standard test fixtures.

*One constraint removes the trigger and every future NULL-related variant.*

### Case 2: N+1 in production only

- **Symptom:** a page that took 80 ms now takes 12 s for one customer.
- **Trigger:** that customer has 15,000 orders.
- **Proximate cause:** the code issues one query per order.
- **Contributing conditions:** the ORM lazily loads relations and makes a query look like a property access; dev data has 10 orders; nobody sees query counts.
- **Root causes:** **F** (an abstraction hides cost, so the code *looks* cheap), **J** (test data is small), **H** (no per-request query-count metric), and **K** (performance is nobody's explicit responsibility until it breaks).
- **Class-level fix:** make cost visible. Fail tests when a request exceeds a query budget. Log query counts per request. Test with the largest customer's shape. Consider disabling implicit lazy loading in hot paths so cost must be explicit.

*Fixing this one page via eager loading leaves every other lazy-loaded page as a time bomb. The root cause is invisible cost.*

### Case 3: The double charge

- **Symptom:** duplicate payment.
- **Trigger:** client timeout and retry.
- **Proximate cause:** the server processed both requests.
- **Root causes:** **E** (the "success or failure" model ignores "succeeded but the response was lost"), **D** (the client's retry behavior and the server's non-idempotency were never reconciled as a contract), **C** (uniqueness of a payment per intent not enforced by the database).
- **Class-level fix:** client-supplied idempotency keys enforced by a unique constraint; store and replay the original response; a reconciler that detects duplicates anyway (**H**). Now every trigger (retries, double-clicks, queue redelivery, deploy restart) is neutralized.

### Case 4: The stuck "processing" job

- **Symptom:** some orders never ship; nobody is alerted.
- **Trigger:** a worker crashed mid-job.
- **Proximate cause:** the job stayed `processing` forever.
- **Root causes:** **E** (atomicity assumption: the worker either finishes or reports failure; crashing is a third outcome not modeled), **H** (no age-based alert, no reconciler), **B** (the state model has no "abandoned" notion).
- **Class-level fix:** leases with expiry, a reconciler for anything in a non-terminal state too long, an alert on the *age of the oldest in-flight item*. This works for every kind of stuck workflow, not just this job.

### Case 5: The retry-driven cascade

- **Symptom:** total outage after a minor slowdown in one dependency.
- **Trigger:** the dependency's latency rises 3×.
- **Proximate cause:** callers time out and retry; load on the dependency triples; it collapses.
- **Root causes:** **F** (positive feedback loop; load increases as health decreases), **G** (shared fate; all callers depend on it with no isolation), **D** (each layer retries independently, with no shared budget), **H** (alerts fired only after total failure).
- **Class-level fix:** retry budgets, exponential backoff with jitter, circuit breakers, bulkheads, load shedding, and shorter timeouts on inner layers. The structural goal: *when a dependency degrades, load on it should fall.*

### Case 6: The expired certificate

- **Symptom:** everything fails at once, on a weekend.
- **Trigger:** a date passed.
- **Root causes:** **F** (a finite-lifetime item), **H** (no expiry monitoring), **K** (no owner; the person who set it up left), **I** (an old manual process that was never automated).
- **Class-level fix:** an inventory of everything that expires (certs, keys, tokens, domains, licenses), each with an owner, automated renewal, and alerts weeks ahead. Also a *test* that renewal works.

---

## Part 5: Why Systems Drift into Failure

Some of the deepest root causes are properties of complex systems themselves, not individual mistakes.

**Latent failures accumulate.** Complex systems run in a permanently "partly broken" state: a missing alert here, an unowned job there, a stale runbook. Each is harmless alone. A serious incident usually requires *several* latent weaknesses to align, like holes in slices of Swiss cheese. This means the incident's trigger is the *least* informative fact; the aligned latent conditions are the most.

**Safety margins erode gradually.** Teams are continuously pushed toward efficiency and speed. Each small shortcut is justified and survives. The margin shrinks invisibly until a normal event crosses the line. The danger is that "it has always worked" is evidence only that the margin has not yet run out.

**Success hides fragility.** A system that has run without incident may be robust, or may just be lucky. Without looking at near-misses, you cannot tell which.

**Safeguards create new risks.** Retries, failovers, caches, and autoscaling each solve a problem and introduce their own edge cases (storms, split-brain, stale data, oscillation). Every protective mechanism should itself be asked: *how does this fail, and does its failure make things worse?*

**Complexity outruns understanding.** Nobody holds the whole system in their head. Each person has a partial model, and failures live in the gaps between models. Hence the importance of explicit contracts and written assumptions.

**Metrics become targets.** Once a measure (coverage percent, uptime, tickets closed) becomes a goal, people optimize the number instead of the reality it represented (Goodhart's law). Coverage can be 95% and still test nothing meaningful.

---

## Part 6: Techniques for Digging to the Root

1. **Separate the layers explicitly.** Write symptom, trigger, proximate cause, contributing conditions, root cause, and latent conditions on separate lines. Most bad postmortems collapse them.
2. **Ask "what invariant was violated?"** Every incident breaks some rule that *should* have held. Name it. Then ask why nothing enforced it.
3. **Ask the counterfactual: "What would have made this impossible, not just unlikely?"** Impossible points to structural fixes; unlikely points to patches.
4. **Ask "why was it possible, easy, and undetected?"** Three separate questions: what allowed it, what made the mistake natural, and why didn't we see it?
5. **Barrier analysis.** List every safeguard that could have stopped this (validation, constraint, test, review, alert, limit, runbook). For each: did it exist? Did it work? Why not?
6. **Change analysis.** What was different from the last time it worked (code, data, config, traffic, dependency, date, person)? Many root causes are found here.
7. **Fault tree thinking.** Start from the disaster and work backward: what combinations of conditions (AND/OR) produce this? It exposes single points of failure and hidden combinations.
8. **Control-structure thinking.** Model the system as controllers, actions, and feedback. Ask: which control actions could be unsafe (given too early, too late, too often, too long, not at all), and what feedback would the controller need to notice?
9. **Stop at something you can change systemically.** "Engineer made an error" is not a stopping point. "The tooling permits this error without a guard" is.
10. **Generalize the finding.** After each root cause, ask: *where else in our system does this same condition exist?* Fix the class, not the instance. Then search for siblings.
11. **Study near-misses.** The incident that almost happened has the same causes as the one that did, without the pressure of an outage.

---

## Part 7: The Deep Question Bank (By Family)

**Assumptions (A):** What must be true? Which are enforced versus believed? What has never failed only because it was never tested?

**Model (B):** What does this value mean in words? What real-world situations collapse into one state here? What is the identity of this thing, and can it change? What states does the real world have that my model lacks?

**Invariants (C):** What must always be true? Who enforces it, where, and can a different writer bypass it? Where are the copies of this fact?

**Boundaries (D):** What does the other side think this means? What is actually guaranteed versus merely observed? Who finds out when it changes?

**Time and causality (E):** What can change between these two steps? What if this stops halfway? What if it runs twice, concurrently, or out of order? What does success mean if the reply is lost?

**Resources and feedback (F):** What grows, what has a limit, and how close are we? Does failure raise or lower load? What is the cost of the innermost loop at 100×? What do the largest and hottest cases look like?

**Coupling (G):** What do these "independent" parts share? What does recovery depend on? How far can one failure spread?

**Blindness (H):** How would we know? Could it be silently wrong for a week? Does every alert have an owner and an action? What do customers experience that we don't measure?

**Change (I):** Can we undo it, including the data? What runs simultaneously during transition? What drifts when nobody touches it?

**Verification (J):** What failure could exist that no test could produce? When did we last actually perform the recovery? How unlike production is our test data?

**Organization (K):** Who owns this at 3 a.m., and who owns the boundary? What happens if the expert leaves? Is the safe path the easy path? Do people feel safe reporting near-misses?

**The meta-question above all:** *Is this failure an instance of a class, and have we removed the class or only this instance?*

---

## Part 8: Principles That Eliminate Whole Classes

These are design stances that remove categories of edge cases rather than fixing individual ones.

1. **Make illegal states unrepresentable.** Use types, constraints, and state machines so the bad state cannot be created, rather than checking for it everywhere.
2. **One owner per invariant, enforced at the lowest authoritative layer.** Everything else may assume it.
3. **One source of truth; copies are disposable.** Anything derived can be rebuilt, and is periodically verified.
4. **Parse, don't validate, at boundaries.** Convert raw input into trusted domain types once; the interior code never sees raw data.
5. **Idempotent by construction.** Design operations as "set to state X," identified by a key, not "do an action."
6. **Bound everything.** Size, time, count, rate, retries, queue depth, memory. An unbounded thing is a future incident.
7. **Failure should reduce load.** Backoff, circuit breakers, shedding, and timeout budgets, so degradation does not amplify.
8. **Fail loudly, degrade deliberately.** Impossible states raise alarms; dependency failures have defined, tested degraded behavior.
9. **Make cost and state visible.** Query budgets, queue ages, resource headroom, invariant checks running continuously.
10. **Reversible by default; rehearse the exceptions.** Prefer changes that can be undone; for one-way doors, slow down and practice.
11. **Isolate blast radius.** Cells, bulkheads, per-tenant limits, staged rollouts.
12. **Verify reality, not just intention.** Reconcile, audit, restore from backup, fail over, inject faults.
13. **Own everything, including boundaries and expiries.** Anything unowned is already failing slowly.
14. **Make the safe path the easy path.** Guardrails, deletion protection, environment cues, confirmations.
15. **Learn from near-misses, and keep the learning as structure.** Each finding becomes a constraint, test, alert, limit, or owner, not a memo.

---

## Operational Verification Checklist

For the actionable SDLC and design review checklist derived from this root-cause taxonomy, see:
👉 **[Checklist 01: Root Causes & Failure Anatomy](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/01-root-causes-and-failure-anatomy-checklist.md)**  
👉 **[Master Engineering Checklist Index](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/00-master-engineering-checklist.md)**
