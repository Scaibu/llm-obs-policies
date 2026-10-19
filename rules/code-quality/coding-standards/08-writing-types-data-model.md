# Writing Types and Data Models That Don't Break: First-Principles Rules (Language-Agnostic)

Confidence tags: **** hard evidence, **** strong inference, **[Guessing]** filling gaps.
Companion documents: *Key Normalization*, *Writing Conditions*, *Loops and Complex Logic*.

**The uncomfortable truth:**  Data outlives code. You can rewrite a function in an afternoon; you cannot cheaply rewrite a model that billions of rows, other services, exported files, and customer integrations already depend on. A model mistake is paid for every day, in every condition and loop written around it. Spend your design effort here first.

---

# Part 1: First principles

## 1.1 What a model is

 A data model is a **set of representable states** plus the operations that move between them. It has two jobs:
- **Represent every valid state** of the domain (otherwise the system cannot do its job).
- **Represent no invalid state** (otherwise every piece of code must defend against impossible data, and some will not).

The central rule: **the set of representable states should equal the set of valid states.** Every gap between them is a bug source, and it shows up as defensive conditions, "should never happen" comments, and incidents.

## 1.2 Information versus representation

 Separate *what the data means* from *how it is stored or transmitted*. The same logical fact (a price, a time, an identity) can have many representations. A good model has exactly one canonical representation per fact, and conversion code at the boundaries.

## 1.3 The properties of a good model

| Property | Meaning | Failure when violated |
|---|---|---|
| **Validity** | Only valid states are representable | Impossible data, defensive code everywhere |
| **Completeness** | All valid states are representable | Workarounds, overloaded fields, free-text hacks |
| **Single source of truth** | Each fact stored once, derived facts clearly marked | Drift, contradictions, "which one is right" |
| **Identity clarity** | Every entity has a stable, unique identity | Duplicates, broken references, failed merges |
| **Evolvability** | Can change without breaking readers, writers, or stored data | Frozen schemas, risky migrations |
| **Access-pattern fit** | Common reads and writes are cheap | Slow queries, hot spots, expensive joins or scans |
| **Boundedness** | Growth is limited or paginated | Huge rows/documents, supernodes, unbounded arrays |
| **Explicitness** | Units, time zones, nullability, meaning visible in the model | Silent misinterpretation |

## 1.4 The nineteen root causes of model bugs

1. **Illegal states representable:** combinations of fields that should not exist (`status = shipped` with `shipped_at = null`).
2. **Primitive obsession:** everything is a string or number, so nothing distinguishes an email from a name or dollars from cents.
3. **Stringly-typed fields:** free text standing in for an enumerated set, with typos and drift.
4. **Nullable by default:** null meaning "unknown", "not applicable", "not yet", and "none" all at once.
5. **Boolean flag clusters:** N flags allowing 2^N states, mostly invalid.
6. **Duplicated truth:** the same fact stored in two places that drift apart.
7. **Missing or unstable identity:** natural keys that change, no key at all, reused ids.
8. **Wrong cardinality:** one-to-many modeled as one-to-one (or the reverse) and discovered in production.
9. **Overloaded fields:** one column meaning different things by row type or time.
10. **Implicit units, currencies, zones, or encodings.**
11. **Floating-point for exact quantities** (money, counts, identifiers).
12. **Time modeled wrongly:** local times without zones, dates as timestamps, no history where history is needed.
13. **Unbounded growth:** arrays, documents, or relationships that grow forever.
14. **Leaking internal storage shape into the public API or events.**
15. **No versioning:** no way to change the model safely over time.
16. **Missing constraints in storage:** rules enforced only in application code, bypassed by every other writer.
17. **Model fits writes but not reads, or the reverse:** correct but unusable at scale.
18. **Weak ownership and tenancy boundaries:** data mixed across tenants, no clear owner per fact.
19. **Sensitive data scattered with no classification or retention.**

---

# Part 2: Before you model

**D1. Write the invariants in plain words.**  "An order has at least one line. A shipped order has a shipment date and an address. A refund never exceeds the amount paid." These are the rules the model must enforce, and the source of your constraints and tests.

**D2. Identify the concepts and their nature.**  For each concept decide: is it an **entity** (has identity and a lifecycle; two with the same attributes are still different) or a **value** (defined entirely by its attributes; interchangeable; immutable)? Then list relationships and their cardinalities (one-to-one, one-to-many, many-to-many) including the minimum (optional or required).

**D3. List the questions and writes the model must serve.**  The top reads (by what key, filtered how, sorted how, how often) and the top writes (rate, concurrency, consistency needed). A model is judged against these, not in the abstract.

**D4. Estimate volume, growth, and retention.**  Rows per entity now, in a year, and at the maximum; size per record; how long data must be kept; the largest single record or the largest relationship fan-out. These numbers decide between embedding and referencing, partitioning, and indexing.

**D5. Assign an owner and a source of truth to every fact.**  For each datum: which system or module is authoritative, and who is allowed to write it. Everything else is a derived copy, to be marked as such.

**D6. Decide what history you need.**  Do you need only current state, or a past state ("what was the address on that invoice?"), or an audit of changes? "We might need it later" is cheap to add now and very expensive to reconstruct.

**D7. Decide consistency boundaries.**  Which facts must change together atomically (one unit of consistency: an aggregate) and which can be eventually consistent. Rules inside a boundary are enforced by the storage transaction; rules across boundaries need explicit design (events, sagas, reconciliation).

**D8. Decide data classification.**  Mark personal, financial, and confidential fields early: retention period, access control, encryption, deletion requirements.

---

# Part 3: Type design

## 3.1 Make illegal states unrepresentable

**D9. Replace flag clusters with a single explicit state.**  Not `is_active`, `is_deleted`, `is_suspended` (eight combinations, three meaningful) but one `status` from a closed set. Pair each state with the data it requires.

**D10. Use tagged unions (sum types) for "one of several shapes".**  A payment is either `Card(number_token, expiry)` or `BankTransfer(iban)` or `Cash`, not a record with every field optional and a `type` string. The type then forces each case to carry exactly its own fields. If the language or store lacks sum types, emulate them with a discriminator field plus a check constraint requiring the right fields to be present and the wrong ones absent.

**D11. Group fields that live and die together.**  If `street`, `city`, and `postal_code` are all present or all absent, make `Address` a single value that is itself optional, not three independent nullable fields.

**D12. Encode required relationships structurally.**  If an order must have at least one line, ensure the model or constraints enforce it (a non-empty collection type, or a transactional rule), rather than hoping callers comply.

## 3.2 Domain types instead of primitives

**D13. Give distinct concepts distinct types.**  `UserId`, `OrderId`, `Email`, `Money`, `Percentage`, `Quantity` rather than raw strings and numbers. This prevents passing a user id where an order id belongs, and gives one place for validation, normalization, and formatting. Where the language lacks cheap wrapper types, use naming conventions, schema-level domains, and validation at the boundary.

**D14. Validate once at construction.**  A value of a domain type is valid by construction ("parse, don't validate"). Downstream code does not re-check. Constructors reject invalid input explicitly.

**D15. Strings: bound them and say what they are.**  Maximum length (and which unit), allowed character set, encoding, normalization (see the key-normalization document), and whether it is identity, display text, or free text. Never store structured data (JSON, delimited lists, composite identifiers) in a string column when it should be fields or a related table.

**D16. Numbers: choose width, signedness, and range.**  State the valid range and enforce it with a check constraint. Choose integer widths that cannot overflow at your maximum volume. Never use floats for money, counts, or identifiers. Large integer ids can lose precision in systems that read them as double-precision numbers (notably some JSON consumers), so transmit them as strings where needed.

**D17. Money: integer minor units plus a currency code, or a fixed-scale decimal.**  Store the currency with every amount. Define rounding mode and where rounding occurs. Never mix currencies in arithmetic without explicit conversion with a recorded rate and date.

**D18. Units and magnitudes are part of the type or the name.**  `timeout_ms`, `weight_kg`, `distance_m`, or a typed quantity. A bare `timeout = 30` has cost real money in every industry.

**D19. Enumerations: closed sets with explicit unknown handling.** 
- Persist a stable string or code, never the ordinal position (inserting a value in the middle would silently change meanings).
- Enforce membership in storage (check constraint, enum type, or reference table).
- Decide what readers do with a value they do not recognize (usually: preserve and treat as unknown, never crash or coerce to a default meaning).
- Never reuse a retired value for a new meaning.

## 3.3 Null, absence, and defaults

**D20. Default to non-null.**  A field is required unless there is a specific, named reason it can be absent. Make optionality a deliberate, visible property of the model (an optional type, or a nullable column with a documented meaning).

**D21. One meaning per null.**  If a nullable field can mean "unknown" and "not applicable" and "not yet set", split it (a status, separate fields, or a tagged union). Distinguish "absent", "empty", and "zero" explicitly where they differ in meaning.

**D22. No magic values.**  `-1`, `0`, `"N/A"`, `""`, `9999-12-31`, and `1970-01-01` as stand-ins for "missing" or "forever" will eventually be treated as real data. Use null or an explicit optional, or a named state; for open-ended ranges, use an explicit "no end" representation your queries handle.

**D23. Defaults are explicit, documented, and versioned.**  Defaults belong to the domain, not to whichever code path creates the row. When a default changes, existing rows keep their old stored value unless a migration says otherwise.

## 3.4 Identity and keys

**D24. Every entity has a stable, opaque, unique identity.**  An immutable surrogate identifier (UUID, sequence, or similar), never reused after deletion. Do not use a mutable attribute (email, name, phone, username) as the primary identity: when it changes, every reference breaks.

**D25. Keep natural identifiers as constrained attributes.**  Store the email or external code as a separate field, in canonical form, with a unique constraint, and a raw copy for display. See the key-normalization document for the equivalence rules.

**D26. Choose identifier generation deliberately.**  Sequential ids are compact and ordered but leak volume, need coordination, and can be guessable. Random UUIDs scale across writers but fragment some indexes. Time-ordered identifiers (e.g., ULID/UUIDv7-style) balance both. Decide on scale, security, and index behavior, and never infer meaning from id structure.

**D27. Scope identity by tenant where applicable.**  In multi-tenant systems, include the tenant in unique constraints and lookups (`unique(tenant_id, external_ref)`), and in every key used for access. Tenant isolation enforced only in application filters is one forgotten `WHERE` away from a breach.

**D28. Composite keys are structured, never concatenated strings.**  Store the components as separate fields with a composite constraint, to avoid delimiter collisions and parsing bugs.

## 3.5 Time

**D29. Store instants in UTC with a defined precision.**  For "when did this happen". Store the time zone identifier separately (not just an offset) when the *local* meaning matters, e.g., future appointments, recurring events, business-hours rules, because offsets change with daylight saving and legal changes.

**D30. Dates without times are a separate type.**  A birth date, a due date, an invoice date are civil dates. Do not store them as midnight timestamps in some zone, which shift by a day when the zone changes.

**D31. Durations and intervals are their own concepts.**  Store durations in explicit units; store intervals as half-open `[start, end)` with `start < end` enforced, and `end` as an explicit "open" marker when unbounded.

**D32. Model validity and history deliberately.**  If facts change over time and the past matters, choose: append-only history rows with `valid_from`/`valid_to` (and, if corrections must be tracked, a recorded-at time too), event logs, or snapshots. Do not overwrite and hope.

**D33. Timestamps for lifecycle events instead of booleans.**  `shipped_at` carries more information than `is_shipped`, and the null/non-null state of the timestamp *is* the boolean, with no chance of disagreement.

## 3.6 Collections and relationships

**D34. Pick the collection semantics.**  Ordered list, set (no duplicates, no order), or map. State the duplicate policy and ordering explicitly, and enforce it (a unique constraint, a position column).

**D35. Bound every collection, or paginate it.**  Arrays embedded in a record, one-to-many relationships, and graph fan-out all need a known maximum, or a design that handles the unbounded case (separate rows, cursors, chunking). The largest instance, not the average, breaks the system.

**D36. Reference by identity, enforce referential integrity.**  Relationships point to ids, with foreign-key constraints (or an equivalent mechanism) so a reference never dangles. Decide the delete policy for each: restrict, cascade, set null, or archive. Orphaned records are one of the most common silent corruptions.

**D37. Many-to-many relationships get their own entity.**  Model the association as a record with its own identity and attributes (role, since, status). It nearly always grows attributes later.

**D38. Hierarchies and graphs: choose representation by access pattern.**  Parent pointer (simple, slow subtree queries), materialized path (fast subtree reads, costly moves), nested sets (fast reads, costly writes), closure table (flexible, extra storage), or native graph traversal. Decide how cycles are prevented and how depth is bounded.

**D39. Prefer composition over inheritance.**  Deep type hierarchies couple unrelated variations. Compose behaviors; use a discriminated union for genuine "one of" variants; avoid inheritance for code reuse.

## 3.7 Lifecycle and state

**D40. Model lifecycles as state machines.**  Define the states, the allowed transitions, and the data each state requires. Enforce transitions in one place, and in storage where possible (a transition check, a conditional update `WHERE status = 'pending'`). Record when and by whom each transition happened.

**D41. Soft delete is a design choice with costs.**  It preserves history and enables undo, but it breaks unique constraints (a deleted row still occupies the key), pollutes every query with `deleted_at IS NULL`, and complicates privacy-driven deletion. If used, make it uniform, build it into constraints (partial/filtered unique indexes) and query layers, and separate "deleted" from "legal erasure".

**D42. Include standard audit fields where they matter.**  Created and updated timestamps, and who or what made the change, plus a version number for concurrency. For regulated or financial data, an append-only audit trail.

**D43. Ledger-style data is append-only.**  For money and inventory, record immutable entries (debit, credit, adjustment) and derive balances. Corrections are new entries that reference the old, never edits. This gives auditability and removes a class of reconciliation bugs.

---

# Part 4: Structure, truth, and constraints

**D44. One fact, one place.**  Normalize until each fact is stored once (the relational ideas: no repeating groups, every non-key field depends on the whole key and nothing but the key). Duplication needs a reason, an owner, and a rebuild path.

**D45. Mark derived data as derived.**  Counters, denormalized copies, caches, search documents, and aggregates are *projections* of the source of truth. Document how each is updated, how it is rebuilt from the source, and what staleness is acceptable. A derived value with no rebuild path is a time bomb.

**D46. Denormalize deliberately and measure first.**  Denormalize for a measured read-path problem, and write down who maintains each copy and how drift is detected and repaired.

**D47. Enforce rules in storage, not only in application code.**  `NOT NULL`, `UNIQUE`, `CHECK`, foreign keys, enum types, and exclusion constraints (e.g., no overlapping bookings) apply to every writer: app, import job, admin script, and future service. Application validation gives friendly errors; storage constraints give guarantees. Use both, derived from the same rule definition.

**D48. Make concurrency safe in the model.**  Include a version (or updated-at used as a version) for optimistic concurrency, use conditional updates, and use unique constraints to resolve races. If two users can edit the same record, the model must say what happens.

**D49. Idempotency is a modeling concern.**  Operations that can be retried need a natural or explicit idempotency key stored with a unique constraint, so a duplicate request cannot create a second effect.

**D50. One field, one meaning.**  No fields whose meaning depends on another field's value or on the row's age ("if `type` is X this holds a date, otherwise a name"). Split the field or use a tagged union.

**D51. Naming is part of the contract.**  Use precise, consistent, unabbreviated names, with unit suffixes, and booleans phrased as facts (`is_`, `has_`). A name that lies (`end_date` holding an exclusive bound, `user` holding an account) will mislead every future reader. Choose one term per concept across the whole system.

---

# Part 5: Boundaries and evolution

**D52. Separate the models for different purposes.**  Persistence model, domain model, API/transport model, and event/message model serve different audiences and change at different rates. Coupling them makes the public API a mirror of the database, so a storage refactor becomes a breaking change. Map explicitly between them.

**D53. Validate at every trust boundary.**  Anything entering from outside (users, other services, files, queues) is untrusted until parsed into a domain type. Reject unknown or invalid data with a clear error, at the edge.

**D54. Schema-less is not model-less.**  Document stores and JSON columns still have an implicit schema, and the code that reads them assumes it. Define the schema, validate on write, and version it. "Flexible" storage without validation yields an archive of inconsistent shapes.

**D55. Design for forward and backward compatibility.**  Rules that hold across serialization formats and APIs:
- Add fields as optional with a defined default; never change a field's meaning or type in place.
- Never reuse a removed field's name or number for something else.
- Readers ignore unknown fields (and preserve them if they pass the data on).
- Treat a removed or unknown enum value as unknown, not as an error or a silent default.
- Use stable field identifiers (names or tags), not positions.

**D56. Version schemas and payloads.**  Store a schema version on persisted documents and messages. Support old and new versions during migration, and have a plan for the oldest data you still keep.

**D57. Migrations: expand, migrate, contract.** 
1. **Expand:** add the new structure alongside the old (new nullable column, new table), with no breaking change.
2. **Dual-write / backfill:** write both, backfill existing data in resumable chunks, verify equivalence.
3. **Switch reads** to the new structure; keep the old one until a full cycle is clean.
4. **Contract:** remove the old structure only after nothing reads or writes it.
Never do a destructive change in one step. Test migrations on production-sized, production-shaped data, and keep a rollback path until contraction.

**D58. Treat schema changes as releases.**  Review them, test them against real data, and plan for lock times, index build costs, and replication lag. A "quick column change" on a large table can take a system down.

---

# Part 6: Modeling by store paradigm

**D59. Relational.**  Model the domain first (normalized), then add indexes for the measured access patterns and denormalize deliberately. Use constraints heavily. Know your engine's behavior for nulls in unique indexes, trailing-space comparison, collation, and maximum sizes. Beware wide rows, unbounded text/blob columns in hot tables, and indexes that nobody uses (each costs every write).

**D60. Document and key-value stores.**  Model from the access patterns: embed what is read together and bounded; reference what is shared, large, or unbounded. Embedded arrays must have a ceiling. Beware hot keys, documents that grow without limit, and multi-document consistency (usually not transactional; design for it).

**D61. Graph stores.**  Model relationships as first-class, typed edges; use specific relationship types and directions that match traversal patterns, and indexed, constrained node properties for entry points (lookup by key, then traverse). Beware **supernodes** (a node with millions of relationships makes traversals and updates expensive): bucket, fan out through intermediate nodes, or split by time or category. Put properties on edges only when they describe the relationship itself. Bound traversal depth and fan-out in every query. Unique constraints are the safe way to avoid duplicate nodes under concurrent writes.

**D62. Time-series and event data.**  Partition by time, bound cardinality of labels/tags (high-cardinality tags cause blow-up), downsample or expire on a retention schedule, and keep raw events immutable.

**D63. Search indexes and caches are projections.**  They are not sources of truth. Build them from the authoritative store, keep a rebuild job, include a version, and tolerate their loss.

**D64. Events and messages are public contracts.**  Immutable facts ("OrderPlaced") with a version, a unique event id, a timestamp, and an identity for the subject. Prefer self-contained, meaningful events over "row changed" signals, and design consumers to be idempotent and tolerant of reordering and duplicates.

---

# Part 7: Safety, privacy, and operations

**D65. Classify and minimize sensitive data.**  Store only what you need, separate sensitive fields so they can be encrypted, access-controlled, and deleted independently, and record the retention period and legal basis. Never use sensitive values as identifiers or keys, which end up in logs, URLs, and indexes.

**D66. Design deletion from the start.**  How do you erase one person's data from tables, derived stores, caches, search indexes, backups (or through expiry), and event logs? If the answer is "we cannot", the model has a compliance defect.

**D67. Never put secrets in the model or in logs.**  Store credentials as hashes or references to a secret manager; store payment instruments as tokens.

**D68. Plan for operational limits.**  Maximum row/document/message size, maximum index key size, connection and transaction limits, replication and backup size. A model that works at the median but exceeds a limit at the maximum fails exactly for your largest customer.

---

# Part 8: Testing models

1. **Invariant tests.**  For each invariant from D1, a test that tries to violate it through every write path and expects rejection (by the type, the constraint, or the service).
2. **Valid-state generators.**  Property-based generators that produce only valid instances (and a second generator producing invalid ones). If you cannot write a generator for valid states, the model is not well-defined.
3. **Round-trip tests.**  Serialize then deserialize (and persist then load) for every type; assert equality, including edge values (maximum numbers, empty collections, Unicode, nulls, time zones, DST boundaries).
4. **Constraint tests.**  Insert violating rows directly, bypassing the application, and verify the database rejects them.
5. **Compatibility tests.**  Old writers with new readers and new writers with old readers; unknown fields and unknown enum values; missing optional fields.
6. **Migration tests.**  Run on a copy of production-shaped, production-sized data; check row counts, constraint validation, timing, locks, and rollback.
7. **Cardinality and scale tests.**  Load the largest realistic entity (the biggest customer, the longest list, the highest-degree node) and measure.
8. **Concurrency tests.** Two writers on the same record, duplicate requests, retries; verify unique constraints and versions prevent corruption.
9. **Reconciliation checks.**  Scheduled jobs that compare derived data to the source of truth and report drift. Production data is the final test of the model.
10. **Schema-diff checks in CI.**  Fail the build when a change is not backward compatible (removed field, narrowed type, new required field with no default).

---

# Part 9: Failure-mode catalog (review checklist)

| Symptom | Likely root cause | Rule |
|---|---|---|
| "Impossible" data keeps appearing | illegal states representable | D9, D10, D11, D47 |
| Code full of defensive null/state checks | weak types, nullable everywhere | D13, D20, D21 |
| Wrong value passed to the right parameter | primitive obsession | D13 |
| Typos or drift in status values | stringly-typed enums | D19 |
| Order of enum values changed meaning of old data | ordinal persisted | D19 |
| "Not set" confused with zero or empty | magic values, overloaded null | D21, D22 |
| References to records that no longer exist | no referential integrity | D36 |
| Duplicate customers or accounts | weak identity, no unique constraint | D24, D25, D47 |
| Everything linked to an email breaks when it changes | mutable identity used as key | D24 |
| One tenant sees another's data | tenancy not in keys and constraints | D27 |
| Money off by cents; wrong currency | float money, no currency | D16, D17 |
| Timeouts wrong by 1000x | implicit units | D18 |
| Events an hour off, dates a day off | time zone and date/time confusion | D29, D30 |
| Cannot answer "what was true then" | no history | D32, D43 |
| Two copies of a fact disagree | duplicated truth, no rebuild | D44, D45 |
| Huge records, slow queries on big customers | unbounded collection, supernode | D35, D61 |
| Unique constraint blocks re-creation after delete | soft delete vs unique | D41 |
| API breaks clients after a DB refactor | storage model leaked into API | D52 |
| Old data unreadable after a change | no versioning, incompatible change | D55, D56 |
| Migration took the system down | destructive, untested migration | D57, D58 |
| Concurrent edits lose data | no version or conditional write | D48 |
| Retries create duplicates | no idempotency key | D49 |
| Cannot delete a person's data everywhere | deletion not designed | D66 |
| Documents/JSON in many incompatible shapes | schema-less with no schema | D54 |

---

# Part 10: Design procedure (fourteen steps)

1. Write the invariants and the top reads and writes in plain words.
2. Identify entities, values, relationships, and cardinalities (with minimums).
3. Estimate volume, growth, largest instance, and retention.
4. Assign an owner and a source of truth to every fact.
5. Decide history, consistency boundaries, and data classification.
6. Define closed state sets and lifecycle state machines.
7. Choose domain types for every identifier, quantity, time, and money value (with units).
8. Make nullability explicit; remove magic values and overloaded fields.
9. Choose stable identity and keys (surrogate identity, constrained natural keys, tenant scoping).
10. Model relationships with referential integrity and defined delete behavior; bound every collection.
11. Put every enforceable rule into storage constraints, derived from the same definition as application validation.
12. Mark and plan every derived copy (rebuild, staleness, drift checks).
13. Separate persistence, domain, API, and event models; version them; define compatibility rules and migration steps.
14. Write invariant, round-trip, constraint, compatibility, migration, and scale tests before shipping.

## Pre-release checklist

- [ ] Invariants written; each enforced by a type or constraint and tested
- [ ] No flag clusters; lifecycle is a state machine with defined transitions
- [ ] Domain types for ids, money, time, units; no floats for exact values
- [ ] Nullability explicit; no magic values; one meaning per field
- [ ] Stable surrogate identity; unique constraints on natural identifiers; tenant in keys
- [ ] Referential integrity and delete policy defined; every collection bounded
- [ ] Each fact stored once; every derived copy has an owner and a rebuild path
- [ ] Schema and payload versions; compatibility rules; expand/migrate/contract plan
- [ ] Retention, deletion, and sensitive-data handling defined
- [ ] Scale-tested on the largest realistic entity

---

# Part 11: What still breaks

-  A wrong understanding of the domain. A beautifully typed model of the wrong concepts is still wrong, and renaming fields will not fix it. Only review with the people who run the business will.
-  The domain changes. Rules that were invariants become exceptions (a new kind of order, a new regulation, a new market). Evolvability, versioning, and migrations reduce the cost but do not remove it.
-  Constraints and types cover the invariants you thought of. Cross-record and cross-system rules (balances reconcile, inventory matches orders, both services agree) still need reconciliation jobs and monitoring.
-  Scale and distribution effects: hot keys, supernodes, skewed tenants, replication lag, and limits that only bind for your largest data. Load tests with realistic skew help; production reveals the rest.
-  Data that predates the model. Old rows, imported data, and rows written by retired code violate rules you have since added; every new constraint needs a cleanup plan first.
- [Guessing] Which rules matter most depends on your store and domain, which I do not know. Most real systems are dominated by D1, D9, D19, D24, D27, D44, D47, and D57.

If you tell me the domain, the store (relational, document, graph, or mixed), and the scale, I can cut this document to the rules that apply to you, or review a specific model against it once you approve sharing it.