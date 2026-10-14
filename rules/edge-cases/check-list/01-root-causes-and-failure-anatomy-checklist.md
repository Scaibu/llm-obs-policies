# Checklist 01: Root Causes & Failure Anatomy (Exhaustive Verification)

**Source Reference**: [The Anatomy of a Failure (Parts 1–8)](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/the-anatomy-of-a-failure.md)  
**Scope**: Complete operational checklist across the 6 Failure Layers, 11 Root Cause Families (A–K), Worked Failure Chains, Diagnostic Depth Ladders, Question Banks, and the 15 Foundational Resilience Principles.

---

## 1. Incident Layering & Root-Cause Depth Analysis (Part 1 & Part 6)

When conducting architectural reviews, post-mortems, or debugging complex incidents, verify all six layers:

- [ ] **Layer 1: Symptom Identification**:
  - [ ] Exactly what customer-visible or system-visible anomaly occurred?
  - [ ] Has the symptom been isolated from the underlying mechanics (e.g. "Customer charged twice" vs "Timeout occurred")?
- [ ] **Layer 2: Trigger Characterization**:
  - [ ] What specific event initiated the sequence (network timeout, double click, pod restart, deploy, cron job)?
  - [ ] Is it acknowledged that triggers are semi-random and cannot be prevented solely by suppressing the trigger?
- [ ] **Layer 3: Proximate Cause**:
  - [ ] What direct code path or database action executed the failure (e.g. non-idempotent handler processed duplicate payload)?
- [ ] **Layer 4: Contributing & Amplifying Conditions**:
  - [ ] Did aggressive client timeouts (e.g. 3s timeout vs 4s p99 latency) trigger retries before work finished?
  - [ ] Were retries enabled without exponential backoff, jitter, or finite retry budgets?
  - [ ] Did connection pool saturation or autoscaling pressure amplify the incident?
- [ ] **Layer 5: Structural Root Cause**:
  - [ ] Which invariant was unenforced at the authoritative storage layer?
  - [ ] Does the proposed fix eliminate the *entire class* of failure across all potential triggers?
- [ ] **Layer 6: Latent Conditions**:
  - [ ] What long-dormant gaps existed (e.g. missing reconciliation cron, unmonitored integer sequence, absent DLQ)?
- [ ] **5-Whys & Parallel Causal Branching**:
  - [ ] Have parallel causal chains been explored rather than forcing a single linear story?
  - [ ] Has "human error" or "engineer forgot" been rejected as a root cause, investigating instead why the system allowed the mistake to occur and remain undetected?

---

## 2. Family A: Hidden Assumptions Verification (Part 2.A)

- [ ] **Cardinality & Nullability Assumptions**:
  - [ ] **Empty Collections**: Does every loop, aggregation, and function handle empty lists (`[]`) without crashing, returning `NaN`, or dividing by zero?
  - [ ] **Single-Item Assumption**: Where "only one" record is expected, is uniqueness enforced by a DB `UNIQUE` constraint or unique index rather than code assumptions?
  - [ ] **Upper Bounds**: Is there a hard ceiling on collection size, batch size, and pagination limits?
  - [ ] **SQL `NOT IN (NULL)` Trap**: Are `NOT IN` subqueries audited to ensure the subquery column is strictly `NOT NULL`, or converted to `NOT EXISTS`?
- [ ] **Environmental Assumptions**:
  - [ ] **Network Latency & Partitions**: Does code treat network calls as potentially delayed, dropped, or timed out?
  - [ ] **Clock Accuracy**: Are time intervals measured via monotonic clocks rather than wall clocks?
  - [ ] **Disk & Inode Space**: Are disk space and inode utilization monitored with alerts before exhaustion?
- [ ] **Caller & Consumer Assumptions**:
  - [ ] Does backend code validate all fields independently of UI/frontend client-side validation?
  - [ ] Are webhook handlers and internal endpoints hardened against double-clicks, concurrent retries, and out-of-order arrivals?
- [ ] **Stability & Schema Assumptions**:
  - [ ] Are enums handled with an explicit `default` branch in switch/match statements to prevent crashes when new enum values are added?
  - [ ] Are JSON parsers configured to tolerate new, unmodeled fields from upstream producers?

---

## 3. Family B: Domain Modeling & Semantic Integrity (Part 2.B)

- [ ] **Disambiguation of Conflated Concepts**:
  - [ ] Is `NULL` disambiguated: "unknown" vs. "not applicable" vs. "not yet provided" vs. "explicitly empty"?
  - [ ] Are lifecycle status (e.g. `DRAFT`, `SUBMITTED`, `ARCHIVED`) and operational outcome (e.g. `SUCCEEDED`, `FAILED`, `CANCELLED`) split into distinct fields?
- [ ] **Identity vs. Mutable Attribute Integrity**:
  - [ ] Are entities identified by immutable surrogate keys (UUIDv7, ULID, bigint ID), never mutable fields (email, phone, company name)?
  - [ ] Is "User" clearly defined: human person vs. tenant login account vs. client device?
- [ ] **Representation vs. Meaning (Value Objects)**:
  - [ ] Are monetary values represented as integers in minor currency units (cents/satoshis) or exact-precision decimals, never IEEE-754 floats?
  - [ ] Are physical units (milliseconds, seconds, bytes, kilograms) explicitly encoded in variable and column names?
  - [ ] Are Unicode strings normalized (e.g. NFC normalization) and trimmed before hashing, unique constraint checking, or equality testing?
  - [ ] Are email addresses case-folded and normalized before uniqueness checks?
- [ ] **Temporal Model Precision**:
  - [ ] Are UTC instants (`TIMESTAMPTZ`), civil dates (`DATE`), wall times (`TIME`), and durations modeled as distinct domain types?
- [ ] **Snapshot vs. Reference Discipline**:
  - [ ] Do immutable transactions (orders, invoices, receipts, tax filings) snapshot customer names, billing addresses, line-item descriptions, and tax rates at moment of creation?

---

## 4. Family C: Invariants & Ownership Enforcement (Part 2.C)

- [ ] **Storage-Layer Invariant Enforcement**:
  - [ ] Is every fundamental rule enforced by a DB constraint (`CHECK (balance >= 0)`, `CHECK (quantity > 0)`, `FOREIGN KEY`, `NOT NULL`, `EXCLUSION`)?
  - [ ] Can a direct SQL `INSERT` or `UPDATE` by an admin script or migration break business invariants? If yes, enforce at the schema level.
- [ ] **Single Source of Truth**:
  - [ ] Is every business fact stored in exactly one authoritative table?
  - [ ] Are derived counts, balances, and aggregations treated as disposable, recomputable caches?
- [ ] **Elimination of TOCTOU (Time-of-Check to Time-of-Use)**:
  - [ ] Are checks and mutations executed in a single atomic statement (`UPDATE ... WHERE version = X` or `INSERT ... ON CONFLICT`) rather than separate `SELECT` then `UPDATE` steps?
- [ ] **Cross-Row & Multi-Tenant Invariant Guards**:
  - [ ] Are multi-tenant queries protected by Row-Level Security (RLS) or repository-level tenancy interceptors?
  - [ ] Are soft-delete filters (`WHERE deleted_at IS NULL`) enforced systematically rather than relying on developer memory?

---

## 5. Family D: Boundary & Contract Robustness (Part 2.D)

- [ ] **Boundary Parsing & Anti-Corruption Layers**:
  - [ ] Is all external input parsed into typed value objects at the system boundary (using Zod, Pydantic, Protobuf) before entering domain logic?
  - [ ] Does boundary validation reject malformed payloads immediately with structured HTTP 400 errors?
- [ ] **Unit & Range Contracts**:
  - [ ] Are API contracts unambiguous regarding timestamp formats (ISO-8601 UTC), integer units (ms vs s, cents vs dollars), and range inclusivity (`[start, end)` vs `[start, end]`)?
- [ ] **Behavioral Contract Alignment**:
  - [ ] Does the consumer's timeout fit inside the producer's processing deadline with safety margins?
  - [ ] Are retrying callers paired with strictly idempotent server endpoints?
- [ ] **Rejection of "Liberal Acceptance" (Postel's Law Pitfall)**:
  - [ ] Does the API reject malformed or ambiguous data at the boundary rather than guessing user intent and propagating corrupt state?

---

## 6. Family E: Temporal & Concurrency Defenses (Part 2.E)

- [ ] **Asynchronous & Partial Failure Design**:
  - [ ] Is the system designed for three outcomes on every remote call: *Success*, *Failure*, and *Unknown / In-Flight*?
  - [ ] If a multi-step saga crashes midway, does a background recovery worker or compensation transaction resume or roll back cleanly?
- [ ] **Message Ordering & Duplication**:
  - [ ] Do consumers handle out-of-order, delayed, and duplicate message delivery safely using message deduplication IDs and version checks?
- [ ] **Multi-Version Coexistence**:
  - [ ] During rolling deployments, can Version $N$ and Version $N+1$ read and write to the same database simultaneously without errors?
- [ ] **Elimination of Wall-Clock Trust**:
  - [ ] Are concurrent updates serialized using sequence numbers, monotonic version columns, or transactional locks, never comparing machine wall clocks?

---

## 7. Family F: Resource Bounding & Feedback Loops (Part 2.F)

- [ ] **Explicit Ceilings on All Resources**:
  - [ ] Are all collection tables, queue sizes, cache keys, payload sizes, string lengths, and query result sets bounded by hard limits?
  - [ ] Is `LIMIT` enforced on 100% of open-ended SQL queries?
  - [ ] Are large tables migrated away from `OFFSET` pagination to keyset/cursor pagination?
- [ ] **Negative Feedback Loops (Load Shedding & Jitter)**:
  - [ ] Do retries employ exponential backoff with full randomized jitter to prevent synchronized retry waves?
  - [ ] Do service clients implement circuit breakers that fail fast when downstream error thresholds are breached?
  - [ ] Does server autoscaling protect downstream databases via connection pool bounds (e.g. PgBouncer)?
- [ ] **Headroom Alerts on Finite Counters**:
  - [ ] Are automated alarms configured to alert at 70% threshold for integer sequence IDs (`INT4` $\to$ `INT8`), disk space, inodes, connection pools, and cloud quotas?

---

## 8. Family G: Coupling & Shared-Fate Elimination (Part 2.G)

- [ ] **Common-Mode Failure Audit**:
  - [ ] Do redundant instances share a single point of failure (single database, common NAT gateway, shared config repository, identical deployment wave)?
- [ ] **Decoupling Critical Paths from Auxiliary Services**:
  - [ ] If analytics, recommendations, email notifications, or feature flag services go down, does the core transaction flow continue uninterrupted?
- [ ] **Independence of Emergency & Recovery Tooling**:
  - [ ] Are admin consoles, deployment tools, health dashboards, and runbooks accessible even when the primary database or auth cluster is experiencing an outage?
- [ ] **Blast Radius Isolation**:
  - [ ] Are high-throughput or erratic tenants segregated via tenant quotas, worker pool bulkheads, or cell-based architecture?

---

## 9. Family H: Observability & Blindness Elimination (Part 2.H)

- [ ] **Direct Business Outcome Monitoring**:
  - [ ] Are monitors tracking business invariants (successful checkouts/min, orders created, dollars processed) rather than merely HTTP 200 healthcheck pings?
- [ ] **No Swallowed Errors**:
  - [ ] Are catch blocks audited to ensure errors are never swallowed silently or converted into empty default responses without alerts?
- [ ] **Tail Latency & Per-Segment Observability**:
  - [ ] Are dashboards configured to display p95, p99, and p99.9 latency distributions rather than deceptive averages?
  - [ ] Can telemetry be filtered by tenant ID, route, and error code?
- [ ] **Alert Quality & Ownership**:
  - [ ] Does every automated alert have a documented runbook, an assigned owning team, and an actionable remediation step?

---

## 10. Family I: Change & Evolution Discipline (Part 2.I)

- [ ] **Phased Expand-Migrate-Contract**:
  - [ ] Step 1 (Expand): Add new columns/fields as nullable or with defaults.
  - [ ] Step 2 (Migrate): Deploy code that dual-writes to old and new fields; backfill historical rows.
  - [ ] Step 3 (Contract): Switch readers to new fields, deprecate old fields, and drop old columns in a later release.
- [ ] **Configuration as Code & Canary Releases**:
  - [ ] Are config changes, environment variables, and feature flags code-reviewed, schema-validated, and rolled out progressively (1% $\to$ 10% $\to$ 100%)?
- [ ] **Dependency Pinning**:
  - [ ] Are all third-party libraries, container base images, and GitHub Actions pinned to exact immutable hashes/versions (no floating `latest` tags)?

---

## 11. Family J & K: Verification & Organizational Rigor (Parts 2.J, 2.K, 4, 7 & 8)

- [ ] **Hostile & High-Scale Verification**:
  - [ ] Are database query execution plans verified against realistic production-scale table volumes and index distributions?
  - [ ] Are systems tested under simulated network delays, packet corruption, duplicate messages, and sudden worker termination (`kill -9`)?
- [ ] **Worked Failure Case Review**:
  - [ ] Case 1: Verified that SQL queries avoid `NOT IN` on nullable columns.
  - [ ] Case 2: Verified that ORM queries eagerly load relations (`joinedload` / `include`) to prevent production N+1 query storms.
  - [ ] Case 3: Verified that payment transactions enforce unique idempotency keys in the database.
  - [ ] Case 4: Verified that asynchronous jobs have lease timeouts and automated stuck-state reconcilers.
  - [ ] Case 5: Verified that downstream outages do not cause retry amplification cascades.
  - [ ] Case 6: Verified that SSL/TLS certificates and tokens have automated renewal monitoring with alerts 30 days prior to expiry.
- [ ] **The 15 Foundational Resilience Principles Applied**:
  - [ ] Invariants enforced where data lives.
  - [ ] Distinct meanings given distinct types.
  - [ ] Single source of truth with rebuildable caches.
  - [ ] Boundary inputs parsed into domain value objects.
  - [ ] Operations idempotent by construction.
  - [ ] Explicit upper bounds on all resources.
  - [ ] Degradation sheds load (circuit breakers & jitter).
  - [ ] Fail loudly on impossible states; degrade gracefully on dependencies.
  - [ ] Visible query budgets, queue ages, and invariant reconcilers.
  - [ ] Reversible changes with practiced rollbacks.
  - [ ] Isolated blast radius (bulkheads & quotas).
  - [ ] Continuous reality audits (reconciliation & disaster recovery drills).
  - [ ] Explicit ownership on all seams, tokens, and expiries.
  - [ ] Guardrails making the safe path the easiest path.
  - [ ] Learnings captured as structural code constraints and monitors.
