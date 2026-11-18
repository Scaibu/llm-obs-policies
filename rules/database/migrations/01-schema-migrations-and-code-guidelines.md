# Data Contract × Code Guidelines — Integration Guide

Nov 18, 2026 · @Chief

How Data Contract v1.2 and the Code Guidelines + Migration Guide operate as one standard — including the places where they contradict each other and one of them has to yield.

## Read this first

Three rules in the Code Guidelines, taken literally, make Data Contract v1.2 impossible to implement. Decide these before any integration work. Nothing else in this guide is actionable until they are settled.

**1. "No stored procedures, triggers, or views. Logic lives in the application."**

This rule deletes the data contract. Every v1.2 enforcement that is not a plain CHECK is a trigger: the dispatcher, identity immutability, state transitions, status-dependent fields, currency scale, `updated_at`/`version`, lookup immutability, append-only protection. Remove them and the storage gate is gone, leaving application code as the only authority — exactly what Principle 0 forbids.

Proposed verdict: narrow the rule to **"No business logic in the database. Integrity enforcement is not business logic."** The test: a trigger may reject a write, and may set server-owned audit columns. It may not compute a value a feature decides, call anything outside the database, or branch on anything but the row being written and its lookup tables. Stored procedures and views stay banned outright.

**2. Shared database is the highest-severity coupling (CoI), and cross-package foreign keys are banned in any form.**

The data contract assumes one database in which features share lookup tables and reference each other by composite FK (3A.7). Read literally against the coupling rules, every one of those FKs is a CoI violation — fix priority "before any other work."

Proposed verdict: the two documents are describing different boundaries, not disagreeing. **Within one package**, features share a database, FKs are allowed, and write ownership is enforced by grants (3B). **Across packages**, there is no shared database and no FK; references go through an outbox plus an orphan check (3A.8). This holds only once "package" and "feature" are defined, which is section 3 of this guide.

**3. The database sits behind a port interface, with an eight-step vendor swap procedure.**

v1.2 is PostgreSQL-specific by design: row-level security, SQLSTATE error mapping, triggers, partial unique indexes, `NOT VALID` constraint recipes. A port that could genuinely swap engines would have to drop all of it.

Proposed verdict: declare PostgreSQL a **pinned, non-swappable dependency** for the primary store. The port stays, because dependency injection, testing, and trace instrumentation need it, but `.port-registry` records it as pinned and the Vendor Database Swap procedure does not apply to it. That procedure still applies to caches, queues, blob stores, and search.

## Conflict register

Every rule pair that collides, beyond the three above. "Yields" names the document that gives way under the proposed verdict. Each row needs the contract owner's sign-off before it becomes binding.

| # | Code Guidelines rule | Data Contract rule | Yields | Proposed verdict |
| --- | --- | --- | --- | --- |
| 1 | No triggers | Triggers enforce most rules | Guidelines | Integrity triggers allowed; business logic still banned |
| 2 | No cross-package FK, ever | Composite FK to `(tenant_id, id)` allowed cross-feature | Neither | FK legal within a package, banned across packages |
| 3 | Shared database = CoI, highest severity | One database, many features | Neither | CoI applies at the package boundary only |
| 4 | DB behind a swappable port | PostgreSQL-specific enforcement | Contract's portability | PostgreSQL pinned in `.port-registry` |
| 5 | Soft delete by default (`deleted_at`) | No DELETE grant; cancellation is a status; `ON DELETE CASCADE` for owned rows | Guidelines | Status-modelled lifecycle preferred; `deleted_at` only where declared, with the rules in section 7 |
| 6 | Every table has `id`, `created_at`, `updated_at` | Adds `tenant_id`, `public_id`, `correlation_id`, `version`; PK is `(tenant_id, id)` | Neither | Contract's set is a superset; `id` still exists, just not alone as the PK |
| 7 | Enums as varchar + CHECK, never a DB enum type | Lookup table with FK once the value carries attributes | Neither | Both ban PG `enum`; lookup table is the stronger form and wins when attributes exist |
| 8 | Every migration has a rollback file, no exceptions | Up and down, *or* a documented forward-only reason | Contract | Rollback file always required; `reversible: NO` still needs the file, even if it only raises |
| 9 | CI runs migrations on a clean database | A clean database proves nothing; use production-shaped data | Neither | Both runs required, for different reasons (section 10) |
| 10 | Migration changes at most 3 tables / 5 columns | Reference DDL creates schemas, functions, 5 tables, policies, grants | Guidelines, once | `0001_init.sql` in Phase 1 is the only exemption, and it is already the guidelines' own rule |
| 11 | Migrations run before the application starts | RLS must not be enabled before every caller sets tenant context | Neither | RLS enablement is split across two releases (section 4) |
| 12 | `scripts/*` may not call `src/*`; HTTP or CLI only | Invariant checks run SQL on a replica as `integrity_checker` | Neither | Invariant checks are an infra job, not a script; they get their own home (section 2) |
| 13 | Adapters map vendor errors to `shared/errors/codes.yaml` | Constraint-name registry maps SQLSTATE 23xxx | Neither | They are the same artifact (section 6) |
| 14 | No business logic gated on trace context | Everything gated on tenant context | Neither | Different contexts, opposite rules, both correct (section 5) |
| 15 | Span names are stable; a change is breaking | Constraint names are stable; error mapping depends on them | Neither | Same discipline, two namespaces; both get a deprecation path |

## Where the data contract lives in the layer model

Every piece of v1.2 maps to exactly one layer. The layer call rules then hold unchanged.

| Data Contract piece | Lives in | Notes |
| --- | --- | --- |
| `context.yml` entity field contracts | `features/*/contract/` | Owned by the feature that owns the table |
| Generated migrations | `features/*/migrations/` | Numbered per the Migration Guide |
| Generated domain types | `features/*/types/` | Never hand-edited |
| Generated ingress schemas | `features/*/schema/` | Used by `fromApi` |
| `app.*` shared SQL functions | `shared/sql/` | Migrated once per database, not per feature |
| Lookup tables (`ref` schema) | `shared/sql/` | Shared read-only; writes only via migration |
| Triggers and constraints | Feature's own migrations | Part of the table they protect |
| RLS policies | Feature's own migrations | One policy per tenant-scoped table |
| `app.set_request_context()` call | `infra/adapters/postgres/` | In the transaction runner, not middleware |
| Transaction runner and retry | `infra/adapters/postgres/` | Behind the repository port |
| Constraint → error-code registry | `infra/adapters/postgres/` | This *is* the adapter's vendor error map |
| `FLOW_CHECK_*` invariant queries | `features/*/checks/` | Declared by the owning feature |
| Invariant check job | `infra/jobs/` | Not `scripts/`; it holds a database connection |

Three rulings this forces:

1. **Tenant context is set by the transaction runner, not by HTTP middleware.** `app.set_request_context()` is transaction-local, so it must run inside the same transaction as the query. Middleware runs outside any transaction, and under transaction-mode pooling the setting would be lost or leak. The API layer passes the authenticated tenant down; the adapter applies it.
2. **The repository never writes raw SQL against another feature's tables.** Grants already make that fail at runtime (3B), so a violation surfaces as a `42501` rather than a code review comment. That makes the coupling rule self-enforcing for the first time.
3. **The invariant check job is infra, not a script.** It opens a database connection as `integrity_checker`, which `scripts/*` is forbidden to do. Putting it in `infra/jobs/` keeps the script rule intact and gives the job a home that CI already lints.

## Package vs feature

The whole shared-database conflict comes from one undefined word. Fix the definitions and both documents hold without amendment.

**Package** = an independently deployable unit. It has its own database, its own release, its own `.package-meta.yaml`. The coupling rules govern this boundary.

**Feature** = a module inside a package. It owns a set of tables, has its own DB writer role, and is reached through `features/*/index`. The data contract governs this boundary.

| Relationship | Shared DB | Foreign key | Write path | Enforced by |
| --- | --- | --- | --- | --- |
| Feature → feature, same package | Yes | Composite FK to `(tenant_id, id)` | Only the owning feature writes | DB grants (3B) + linter on `features/A → features/B` |
| Package → package | No | Never | Outbox event, then the consumer's own write | Coupling-map entry + orphan check (3A.8) |

**The consequence people will resist:** a cross-feature FK commits those two features to the same deployment unit forever. If they later need to split into separate packages, the FK has to be dismantled through the full Shared Database Violation sequence — publisher, subscriber, dual write, flip reads, remove access. So a cross-feature FK is a statement that these two features will never be separately deployed.

**Rule:** every cross-feature FK is recorded in `coupling-map.md` as an accepted **CoM** (message-level) entry, not a violation, with the owning package named. If anyone later proposes splitting those features into packages, the map already lists the work.

**Lookup tables are the exception.** The `ref` schema (statuses, currencies, sources) is shared read-only across every feature in a package. It is not CoI, because nothing writes it at runtime — rows change only through migrations, and the attributes are immutable (section 4.6). A shared read-only table whose contents can only change through a reviewed migration is a shared constant, not shared state.

## Merging the two migration systems

The Migration Guide owns the file mechanics. The data contract owns what goes inside the files. The generator produces files that satisfy both.

**Generated, but still immutable.** `context.yml` is the source of truth, but the generator writes a numbered migration that is committed and reviewed like any other. Once merged, it is immutable. Changing an entity means a new `context.yml` revision plus a new numbered migration, never a regenerate-in-place. CI checks that regenerating from the current `context.yml` produces the committed files — a diff means someone hand-edited one.

**Extended migration header.** Four fields are added to the required header:

```markdown
-- migration:      0004
-- description:    add payment_status index to orders
-- author:         name
-- date:           ISO date
-- depends_on:     0003
-- reversible:     YES | NO
-- lock_risk:      LOW | MEDIUM | HIGH
-- rows_affected:  estimated count or schema only
-- reason:         query performance — orders by status scans full table
-- entity:         orders                     # new: which context.yml entity
-- contract_rev:   context.yml revision hash  # new: drift check anchor
-- lock_timeout:   3s                         # new: contract 9.3
-- recipe:         CHECK | FK | NOT NULL | UNIQUE | EXCLUDE | TRIGGER | RLS  # new: contract 9.4
```

**Rollback files always exist.** The data contract allows forward-only with a written reason; the guidelines do not. The guidelines win. A genuinely irreversible migration still ships a `.rollback.sql` file whose body raises an exception explaining why, so the rollback test has something to run and the gap is visible in the repository rather than in a header field.

**Size limit.** The data contract's reference DDL would breach the 3-table / 5-column limit. That is correct and expected: it belongs in `0001_init.sql`, which the Migration Guide already exempts as the Phase 1 schema capture. Every migration after that respects the limit, which fits the contract's expand-migrate-contract rule anyway.

### RLS enablement spans two releases

This is the one ordering hazard where the two documents actively work against each other. Migrations run before the application starts. If the RLS migration lands with the same release as the code that sets tenant context, there is a window where the new policy is live and the old code is still running. Every query in that window fails.

1. **Release N:** deploy the transaction runner that calls `app.set_request_context()` on every transaction. No migration. Add a metric counting transactions that touch a tenant table without context.
2. **Soak:** wait for the metric to read zero across a full business cycle, including month-end and any batch jobs.
3. **Release N+1:** the migration that creates the policy and runs `ENABLE` plus `FORCE`, one table at a time. Its rollback file is `DISABLE ROW LEVEL SECURITY`, which must be tested.

The `recipe: RLS` header field exists so CI can refuse an RLS migration whose PR body does not reference the soak metric.

## Tracing and the data contract

These two fit together better than anything else in the two documents, with one decision to make and one trap to avoid.

### Decision: is `correlation_id` the trace-id?

The data contract requires `correlation_id uuid NOT NULL`, immutable, set at the request origin and copied to everything it causes. A W3C trace-id is 128 bits, the same width as a UUID. The temptation to make them the same value is strong, and it is mostly right.

Recommended: **`correlation_id` is the W3C trace-id of the originating request, stored as `uuid`, when one exists.** This makes every row in the database directly joinable to its trace. Three cases need a rule, because the contract forbids nulls here:

- **No traceparent on the inbound request.** The root span is created anyway (tracing rule), so use that span's trace-id. Never null.
- **Backfills, migrations, scheduled jobs.** One generated `correlation_id` per run, recorded in the run log (contract 1A.8). Do not reuse across runs.
- **An all-zero trace-id** is invalid per W3C and must be rejected, not stored.

Trade-off to accept consciously: trace-ids are typically retained for days or weeks, while rows live for years. A `correlation_id` older than your trace retention resolves to nothing. That is fine — it is still a stable grouping key — but do not promise anyone that every `correlation_id` opens a trace.

### Trap: two kinds of context, opposite rules

These look identical and must never be conflated.

|  | Trace context | Tenant context |
| --- | --- | --- |
| Carried by | W3C `traceparent` | `app.set_request_context()` |
| Scope | Propagated across services | Transaction-local, one database |
| If missing | Request processes normally | Request **fails** with `42501` |
| Source | Inbound header | Authenticated principal, never request input |

The Code Guidelines say no business logic is gated on trace context. The data contract says everything is gated on tenant context. Both are right. Write them next to each other in the onboarding material, because a new engineer will otherwise generalise one into the other.

### Span attributes

The PII rule and the identifier contract point the same way, so make it explicit:

- Span attributes carry `public_id`, never the internal `id`. The contract already says `public_id` is the only id in logs for external readers.
- `tenant_id` is a UUID, not personal data, and belongs on the span — isolation bugs are untraceable without it.
- `actor_id` is only safe on a span if it is an opaque internal id. An email address or username is PII and triggers the P0 security protocol.
- Constraint names appear in error spans. They are schema metadata, not data, and are safe.
- The repository adapter's child span records the constraint name on a `23xxx` failure, which makes integrity violations queryable in the trace backend rather than only in logs.

## Error mapping: one artifact, not two

The Code Guidelines already require every adapter to map vendor errors into `shared/errors/codes.yaml`. The data contract's constraint registry is exactly that map for the PostgreSQL adapter. Do not build it twice.

**Where it lives:** `infra/adapters/postgres/error-map.yaml`, generated from `context.yml`, with targets resolving to codes in `shared/errors/codes.yaml`.

**What CI enforces:**

1. Every constraint, unique index, trigger rule, and `NOT NULL` column in the schema has an entry. This is checkable by querying `pg_constraint` and `pg_indexes` against the map, plus the generator's list of trigger rule names.
2. Every entry's target exists in `shared/errors/codes.yaml`.
3. No business code outside the adapter references a SQLSTATE or a constraint name. A linter rule, same class as the layer rules.

**Beyond class 23.** The contract adds non-integrity errors that the adapter must also own:

| SQLSTATE | Meaning | Handling |
| --- | --- | --- |
| 40001 | Serialization failure | Retried by the transaction runner, 3 attempts, jittered backoff |
| 40P01 | Deadlock | Same |
| 42501 | Tenant context missing, or a grant violation | `INTERNAL.*` — always a server bug, never shown to a client |
| 55P03 | Lock not available | Migration runner only; retried with backoff |

A retry is invisible to the feature layer. The repository port returns a result; it never surfaces a transient database state. The only retry-related code a feature ever sees is `CONFLICT.RETRY_EXHAUSTED` after the last attempt.

**Stable names, both namespaces.** The guidelines treat a span rename as a breaking change requiring deprecation. Constraint names deserve the same treatment for the same reason: dashboards, alerts, and the error map all key off them. A constraint rename is a breaking change, and the old name stays in the error map, marked deprecated, for one release cycle.

## Soft delete

The Migration Guide's `deleted_at` default is the rule most likely to cause a silent data bug under the data contract, because `deleted_at` interacts with four separate contract mechanisms and breaks three of them.

**What breaks:**

1. **Unique constraints.** A soft-deleted row still occupies its unique key, so a customer cannot re-register with an external id they "deleted". Every unique constraint on a soft-deletable table must become a partial unique index with `WHERE deleted_at IS NULL`.
2. **Foreign keys.** `ON DELETE RESTRICT` never fires, because nothing is deleted. A soft-deleted parent can be left with live children, and the database will not stop it. This needs an invariant check per relationship, and nothing else will catch it.
3. **`ON DELETE CASCADE`.** The contract allows it for owned rows such as order lines. Under soft delete it is dead code: cascading soft delete has to be a trigger or an application concern, and neither is free.
4. **RLS.** Policies filter by tenant, not by `deleted_at`. Soft-deleted rows stay visible to every query that forgets the predicate. That is the same class of bug RLS was added to prevent.

**The rule:**

- **Prefer a status.** If an entity has a lifecycle, model the end state as a status with a transition. The reference `orders` does this: cancellation is a status, and `orders_writer` has no `DELETE` grant at all. This satisfies "never hard delete by default" more strongly than `deleted_at` does, and the contract machinery works unchanged.
- **`deleted_at` only when declared.** It goes in the entity field contract with a reason, and the entity then takes all four obligations above: partial unique indexes, an orphan invariant check per FK, an explicit cascade decision, and a documented query convention.
- **Never both.** An entity with a lifecycle status and a `deleted_at` column has two sources of truth about whether a row counts. Pick one per entity and write it in `context.yml`.

**Append-only tables are exempt from both.** Events, ledgers, and audit have `UPDATE` and `DELETE` revoked. They have no `deleted_at` and no delete status. This is also where the personal-data erasure problem concentrates, which is still an open item in the contract.

## Registry files

The Code Guidelines already run on a family of committed registry files that CI checks for drift. `context.yml` joins it, and the data contract adds two more.

| File | Scope | Records | Drift check |
| --- | --- | --- | --- |
| `.package-meta.yaml` | Package | Current stage | Existing |
| `coupling-map.md` | Repository | Open violations, accepted cross-feature FKs | Count must be 0 on main |
| `.port-registry` | Package | Infra dependencies, now with PostgreSQL marked pinned | Existing sync check |
| `.contract-lock` | Package | Pinned event schema versions | Existing sync check |
| `schema.lock` | Package DB | Last applied migration number | Existing consistency check |
| `sunset-registry` | Repository | Deprecations and expiry dates, now including deprecated constraint names | Expiry check |
| `context.yml` | Feature | Entity field contracts — the source of truth for schema | **New:** regenerate and diff |
| `error-map.yaml` | Package | Constraint name → error code | **New:** full coverage against `pg_constraint` |
| `grant-matrix.yaml` | Package DB | Role × table × privilege | **New:** asserted against `information_schema` |

Two rules keep this from becoming nine files nobody updates:

1. **Generated, not maintained.** `error-map.yaml` and `grant-matrix.yaml` are generated from `context.yml`. Only `context.yml` is hand-written. A hand edit to a generated file fails CI, which is the contract's own rule (0A.4) applied to the guidelines' registry family.
2. **One check, one failure message.** Each drift check names the file, the entity, and the regeneration command. A drift failure that says only "files differ" gets ignored within two sprints.

## Phase mapping

The production-readiness plan for the data contract maps onto the existing-project migration phases without adding a phase. Two things move earlier than instinct suggests.

| Migration Guide phase | Data contract work | Why here |
| --- | --- | --- |
| **Phase 0 — audit, zero code** | Write `context.yml` for every existing entity, as found, not as wanted. Add contract gaps to `coupling-map.md`: missing constraints, missing RLS, unmapped errors, hand-written types. Answer the six Phase 0 decisions. | The guidelines forbid implementation code here, and documenting the current schema is pure audit |
| **Phase 1 — contracts and ports** | Build the generator. Write `0001_init.sql` from `context.yml` and verify it reproduces the live schema. Create `error-map.yaml`, `grant-matrix.yaml`, `schema.lock`. Deploy the transaction runner. | `0001_init.sql` is already a Phase 1 deliverable, and the generator is what makes it reproducible |
| **Phase 2 — strangle, one violation per PR** | Enforce rules one at a time: one constraint, one trigger rule, one grant per PR. Build concurrency tests and the write benchmark. Run the RLS soak. Build the invariant check job. | Each rule is its own violation resolution, which is exactly the guidelines' one-violation-per-PR shape |
| **Phase 3 — harden** | Enable all CI gates. Enable RLS per table. Close the contract's open items. | Phase 3 is where checks become blocking |

**Two things move earlier than expected:**

- **The transaction runner ships in Phase 1, not Phase 2.** It carries tenant context, retries, and error mapping. Every Phase 2 PR depends on it, and retrofitting it later means touching every repository again.
- **The write benchmark runs in Phase 2, not Phase 3.** The contract's open item 1 is a budget that constrains design. Measuring after hardening means discovering an ingestion path cannot afford the dispatcher once it is already everywhere.

**One Phase 0 rule needs a carve-out.** "Do not write a single line of implementation code" would block writing `context.yml`. Treat `context.yml` as documentation of the existing schema, which it is — it ships no behaviour and changes no table. Generating a migration from it is Phase 1.

**The guidelines' phase gate is stricter than the contract's.** "Never proceed to the next phase while the current phase has open PRs" applies. The contract's phase gates are additive, not alternative.

## CI gate matrix

Every check both documents require, in the order they should run. Fast checks fail first.

| Stage | Check | Source | Blocks |
| --- | --- | --- | --- |
| Lint | Layer call rules | Guidelines | Merge |
| Lint | No cross-package imports | Guidelines | Merge |
| Lint | No SQLSTATE or constraint name outside the postgres adapter | New | Merge |
| Registry | `coupling-map.md` violation count = 0 | Guidelines | Merge to main |
| Registry | `.port-registry`, `.contract-lock`, `schema.lock` sync | Guidelines | Merge |
| Registry | `sunset-registry` expiry | Guidelines | Merge |
| Registry | `context.yml` regenerate-and-diff | Contract | Merge |
| Registry | `error-map.yaml` coverage vs `pg_constraint` | Contract | Merge |
| Registry | `grant-matrix.yaml` vs `information_schema` | Contract | Merge |
| Migration | Clean-database apply, both directions | Guidelines | Merge |
| Migration | Header validity, `depends_on` chain | Guidelines | Merge |
| Migration | `lock_timeout` present; recipe matches rule kind | Contract | Merge |
| Migration | Production-shaped apply with recorded lock times | Contract | Merge |
| Contract tests | Negative test per rule, as application roles | Contract | Merge |
| Contract tests | Round-trip, machine parity, canonical text parity | Contract | Merge |
| Contract tests | Grant matrix, tenant isolation, lookup immutability | Contract | Merge |
| Contract tests | Run on oldest and newest supported engine | Contract | Merge |
| Concurrency | Upsert race, transition race, version conflict, deadlock retry | Contract | Merge |
| Tracing | Required span attributes present | Guidelines | Merge |
| Tracing | New outbound call has a span in the same PR | Guidelines | Merge |
| Tracing | No PII in span attributes | Guidelines | P0 if it escapes |
| Deploy | `trace-check.sh` returns 0 | Guidelines | Deploy; auto-rollback in prod |
| Deploy | Staging migration passed before production | Guidelines | Deploy |
| Deploy | Tenant-context metric = 0 before an RLS migration | New | Deploy |

**Two checks are worth building first,** because they catch the largest class of silent damage: `error-map.yaml` coverage, which turns every unmapped integrity failure into a generic internal error for users, and the grant matrix, which is the only automated enforcement of write ownership you have.

## Merged non-negotiables and open decisions

### Non-negotiables

The Migration Guide's list, plus what the data contract adds. Order is by blast radius.

1. Never break a running production system.
2. Never touch a database manually, in any environment.
3. Never write a migration without a rollback file.
4. Never enable RLS on a table before the tenant-context metric has read zero for a full business cycle.
5. Never combine more than one violation fix in a single PR.
6. Never ship a rule that exists only in application code.
7. Never hand-edit a generated artifact: migration, type, schema, error map, or grant matrix.
8. Never grant `BYPASSRLS` to a role that can write.
9. Never skip the contract step to save time.
10. Never remove dual-write before the consumer database is verified stable.
11. Never rename a column, or a constraint, in a single migration.
12. Never merge a PR adding a coupling without a coupling-map entry and a phase plan.
13. Never proceed to the next phase while the current phase has open PRs.

### Open decisions

Each needs a named owner and a date before this guide becomes binding.

- [ ] The three verdicts in "Read this first" — triggers, package boundary, PostgreSQL pinning
- [ ] Existing tables or greenfield only, which sets the cost of the Phase 1 adoption work
- [ ] Which PostgreSQL versions actually run in production, which sets the real engine floor
- [ ] Whether tenant-scoped tables will be partitioned within a year
- [ ] Whether any entity holds personal data, which turns erasure from an open item into a blocker
- [ ] Whether `correlation_id` equals the trace-id, and the trace retention window
- [ ] Who owns this guide and the data contract — one named person who approves every change
- [ ] Whether a `context.yml` generator exists today; if not, it is the long pole for everything else
