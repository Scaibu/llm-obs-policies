---
agent_role: "Data Integrity Enforcer"
trigger: "ON_REFERENCE | ON_SCHEMA_CHANGE | ON_MIGRATION | ON_INGRESS_CHANGE"
scope: "Tables, columns, constraints, migrations, ingress validation, integrity checks"
mode: "Strict. Reject, never repair."
contract_version: "1.0"
assumed_engine: "PostgreSQL 14+"
---

# Data Contract

## 0. Principle

Invalid data must be rejected at write time, at the lowest layer that can reject it.
The database is the final authority. Application validation is a faster, friendlier first gate, never the only one.

Three gates, in order. A rule must exist in the DB gate, and may also exist in the earlier gates:

1. **Ingress gate** (`schema`): strict parse, normalize, reject unknown or malformed input.
2. **Domain gate** (`types`, `rules`, `machine`): illegal states are unrepresentable in types, transitions are validated.
3. **Storage gate** (DB constraints): the last line. If code has a bug, the DB still refuses bad data.

Corrupt data found later is a failure of gate 3, not of the reader. Readers never defensively handle impossible data. They trust the contract.

## 1. Entity Field Contract (mandatory per entity, lives in `context.yml`)

Every column is declared before any migration or code is written.

```
entity: orders
owner: <team>
fields:
  - name: id             type: uuid          null: no   default: uuidv7()            constraint: PK, UNIQUE(tenant_id, id), immutable
  - name: public_id      type: text          null: no   default: generated          constraint: UNIQUE, immutable, format 'ord_' + 26 chars
  - name: tenant_id      type: uuid          null: no   constraint: FK tenants(id) ON DELETE RESTRICT, immutable
  - name: source         type: text          null: no   constraint: FK id_source(code)
  - name: external_id    type: text          null: no   normalize: trim            constraint: UNIQUE(tenant_id, source, external_id), length 1..64
  - name: correlation_id type: uuid          null: no   constraint: immutable, no FK
  - name: status        type: text          null: no   constraint: FK order_status(code)
  - name: amount        type: numeric(18,2) null: no   constraint: CHECK >= 0
  - name: currency      type: char(3)       null: no   normalize: upper           constraint: CHECK ~ '^[A-Z]{3}$'
  - name: shipped_at    type: timestamptz   null: yes  constraint: CHECK (status = 'shipped') = (shipped_at IS NOT NULL)
  - name: version       type: bigint        null: no   default: 1
invariants:
  - shipped orders always have shipped_at
  - amount is never negative
pii: [none]
source_of_truth: db
```

A column without a declared type, nullability, normalization rule, and constraint is rejected in review.

## 1A. Identifier Contract (5 roles, each with one job)

Identifiers do not model relationships. Constraints do (section 3A). Identifiers give every row a stable, unambiguous address from each direction it is addressed. Each mandatory-id entity carries exactly these five roles, and no id serves two roles.

| # | Column | Role | Rules |
|---|--------|------|-------|
| 1 | `id` | Internal surrogate primary key | `uuidv7` (time-ordered, index-friendly; native in PG18, else extension or app-generated). Never exposed outside the service. Immutable. |
| 2 | `public_id` | External-facing opaque id | Prefixed per entity (`ord_...`), unique, immutable, non-guessable. The only id in APIs, URLs, and logs for external readers. Lets internal keys change without breaking clients. |
| 3 | `tenant_id` | Ownership scope and partition key | NOT NULL, immutable, leads every unique key and index. Part of every composite FK so cross-tenant references are impossible. |
| 4 | `source` + `external_id` | Natural key from an upstream system | Unique with `tenant_id`. The upsert conflict target. Normalized at ingress. Answers "which row is this record from system X". |
| 5 | `correlation_id` | Causation trace across features, events, and jobs | Set once at the request or event origin, copied to everything it causes. Immutable, no FK, not unique. Indexed only if queried. |

Optional, only when the entity needs it:
- `parent_id` and `root_id` for hierarchies (section 3A).
- `request_id` for per-request idempotency, if distinct from `correlation_id`.

Rules:
1. **Immutability is enforced by trigger** on `id`, `public_id`, `tenant_id`, and `correlation_id`. An update that changes them raises.
2. **Composite uniqueness enables composite FKs:** every tenant-scoped table declares `UNIQUE (tenant_id, id)`.
3. **No id is reused for another purpose** (no public id as join key, no external id as FK target).
4. **No id is derived from mutable business data.**
5. **Lookup and reference tables** (status codes, currencies) are exempt and use their natural `code` as the key.
6. **Cost is real:** each id adds an index and write cost. A role may be dropped for an entity only with a written reason in its field contract (for example, an internal-only table needs no `public_id`).

## 2. Column Rules

1. **NOT NULL by default.** Nullable only when absence is a real business state, and then the reason is written in the contract. Never use null to mean "unknown yet" for a field that is required later: model it as a state with a CHECK.
2. **Exact types only:**
   - Money: `numeric(p,s)` or integer minor units. Never `float`/`double`.
   - Time: `timestamptz`, stored in UTC. Never `timestamp` without zone, never strings.
   - Identifiers: `uuid` or typed `bigint`. Never free text for ids.
   - Booleans: `boolean NOT NULL`. Never nullable tri-state, never `'Y'/'N'` text.
3. **Text is bounded and normalized.** Length CHECK on every `text`. `CHECK (col = btrim(col))` and `CHECK (col <> '')` where empty is invalid. Empty string is never a stand-in for null.
4. **Enumerations are enforced by the DB:** a lookup table with FK, or a `CHECK (col IN (...))` for small stable sets. Never an unchecked string.
5. **`jsonb` is not a junk drawer.** Core fields are real columns. If `jsonb` is unavoidable: `CHECK (jsonb_typeof(col) = 'object')`, required-key CHECKs, and schema validation (for example `pg_jsonschema`) where available.
6. **Reusable rules become `DOMAIN` types** (`email_t`, `money_t`, `percent_t`, `currency_t`), so a rule is defined once and applies everywhere.
7. **Derived values are generated columns,** never separately written fields that can disagree.

## 3. Constraint Rules

1. Every table has a primary key.
2. Every relationship has a foreign key with an explicit `ON DELETE` (`RESTRICT` by default). No orphan rows by design.
3. Every natural or business key has a `UNIQUE` constraint. Upsert targets (see queries contract) must match one exactly.
4. Cross-column rules are `CHECK` constraints (status implies timestamp, start before end, mutually exclusive columns).
5. Overlap rules use `EXCLUDE` constraints (no overlapping bookings for one resource).
6. Constraints are **named explicitly:** `{table}_{column(s)}_{kind}` (for example `orders_amount_nonneg_ck`). Auto-generated names are banned, since error mapping depends on stable names.
7. Partitioned tables: unique and primary keys include the partition key. Note this in the field contract.

## 3A. Relationship Contract (complex relationships live here)

1. **Tenant-safe foreign keys.** Reference with the composite key so a row can never point into another tenant:

```sql
FOREIGN KEY (tenant_id, customer_id) REFERENCES customers (tenant_id, id) ON DELETE RESTRICT
```

2. **One-to-many:** FK on the many side, indexed (an unindexed FK is a review failure).
3. **Many-to-many:** a join table with a composite primary key (`tenant_id`, `left_id`, `right_id`), composite FKs on both sides, and its own attributes. Never an array column of ids.
4. **Time-bound relationships:** `valid_from`, `valid_to` (`tstzrange`), with an `EXCLUDE` constraint preventing overlap for the same pair, and a CHECK that `valid_to > valid_from`.
5. **Hierarchies:** `parent_id` with composite FK, `CHECK (parent_id <> id)`, and `root_id` set on insert. Cycle prevention by trigger or closure table (`ancestor_id`, `descendant_id`, `depth`) maintained in the same transaction. Pick one model per entity and write it in the field contract.
6. **No generic polymorphic references** (`target_type` + `target_id`) without an FK. Use one nullable FK per target type with `CHECK (num_nonnulls(a_id, b_id, c_id) = 1)`, or one join table per type.
7. **Cross-feature references:** FK to the owning feature's `(tenant_id, id)` is allowed. Writes to that table remain owned by its feature only. Reference by id, never by copying its fields (copies drift).
8. **Cross-service or cross-database references** cannot have an FK. Use an outbox for delivery plus an invariant query (`FLOW_CHECK_{ENTITY}_ORPHAN_{TARGET}`) to detect dangling references.
9. **Every FK declares `ON DELETE` explicitly.** `CASCADE` only for true ownership (line items of an order) and listed in the field contract.
10. **Denormalized copies** (a count, a latest status) are allowed only as trigger-maintained or generated columns, with an invariant query proving they match the source.

## 4. State Integrity

1. Allowed states live in a lookup table or CHECK, never only in code.
2. Allowed transitions live in a `{entity}_transition` table (`from_status`, `to_status`). A trigger or the `TRANSITION` query rejects pairs not in the table.
3. The machine file in code mirrors the table. A contract test asserts they are identical, so they cannot drift.
4. Append-only data (events, ledgers, audit) has `UPDATE` and `DELETE` revoked from the application role, plus a trigger that raises on attempt.

## 5. Audit Columns

Every mutable table has `created_at`, `updated_at` (maintained by a trigger, never by application code), and `version bigint NOT NULL` for optimistic concurrency. Tables with regulatory or traceability needs add `created_by`/`updated_by` populated from a session setting, not a client-supplied field.

## 6. Ingress Contract (strict parse, reject, never repair)

1. `fromApi` returns `Result`. Failure is a typed `ValidationError` carrying field paths. It is never a thrown exception and never a silently fixed value.
2. **Unknown fields are rejected.** Missing required fields are rejected. No silent defaults for required data.
3. **No implicit coercion** (`"5"` to `5`, `"true"` to `true`, `""` to null). Types match exactly or the request fails.
4. **Normalization is explicit and lives in `schema`:** trim, case-fold where declared, Unicode NFC, timezone to UTC, decimal scale fixed. The stored value is canonical, so equality and uniqueness behave.
5. **External and bulk data (partners, imports, webhooks, queues)** goes through staging:
   - Land raw in a staging table with source, received time, and payload hash.
   - Validate with the same schema. Valid rows are promoted by a single upsert. Invalid rows go to a quarantine table with the reason.
   - Quarantine is monitored and has an owner. Rejected data is never dropped silently.
6. Validation rules are generated from, or tested against, the DB contract. A hand-written duplicate that can drift is banned.

## 7. Single Source of Truth

1. The DB schema is the source of truth for field shape. Types and schema are **generated** from it (or from the entity contract that also generates the migration). No hand-maintained parallel definitions.
2. CI fails if generated artifacts differ from committed ones.
3. Contract tests (required):
   - **Negative test per constraint:** inserting a violating row is rejected with the expected constraint name.
   - **Round-trip test:** `fromApi` then persist then `toApi` returns an equal value for generated valid inputs (property-based).
   - **Machine/table parity test** from section 4.

## 8. Error Mapping (the only code-level handling allowed)

DB constraint violations (`SQLSTATE 23xxx`) are translated in one place, a registry keyed by constraint name:

```
orders_amount_nonneg_ck      -> VALIDATION.AMOUNT_NEGATIVE
orders_tenant_ext_uk         -> CONFLICT.DUPLICATE_EXTERNAL_ID
orders_status_fk             -> VALIDATION.UNKNOWN_STATUS
```

- A constraint with no registry entry fails CI.
- Unmapped DB errors are internal errors, never exposed raw.
- Business code never inspects error text.

## 9. Migrations

1. **Expand, migrate, contract.** Add nullable or defaulted structure first, backfill, then enforce, then remove the old one. No big-bang changes.
2. **Adding a constraint to a populated table:** `ADD CONSTRAINT ... NOT VALID`, then fix violations, then `VALIDATE CONSTRAINT`. `NOT VALID` is temporary: a ticket and a deadline are required, and CI flags constraints left unvalidated.
3. **Before enforcing:** run the named violation-count query for the new rule. Enforcement is blocked while the count is above zero.
4. **Backfills are batched and resumable,** idempotent, and verified by a post-check query.
5. **Every migration ships with:** an up and a down (or a documented forward-only reason), a data-check query, and a lock-impact note (`CREATE INDEX CONCURRENTLY`, no long `ACCESS EXCLUSIVE` locks).
6. **CI runs migrations on a production-shaped snapshot** or realistic seed. Passing on an empty database proves nothing.
7. No destructive change (drop column, narrow type) without a prior release where nothing reads or writes it.

## 10. Continuous Integrity Checks

1. Each entity declares **invariant queries** as `FLOW_CHECK_{ENTITY}_{INVARIANT}` returning violating rows (orphans, status/timestamp disagreement, ledger sums that do not balance, duplicates by normalized key).
2. A scheduled job runs them on a replica, records counts, and alerts on any nonzero result.
3. A violation found by a check means a missing or weak constraint. The fix is a constraint plus a negative test, not a patch in code.

## 11. Banned

- Nullable columns without a written reason; `float` for money; `timestamp` without zone
- Unbounded or unchecked `text`; empty string as null; unchecked enum strings
- Business-critical rules enforced only in application code
- Auto-named constraints; constraints in `NOT VALID` state past their deadline
- Silent coercion, silent defaults, or silently dropped fields at ingress
- Hand-written types or schemas duplicating the DB contract
- Defensive reads that "handle" impossible data instead of tightening the contract
- Direct writes to a table by anything other than its owning feature

## 12. Definition of Done (per schema change)

1. Entity field contract updated and reviewed.
2. Every rule exists at the storage gate, with a named constraint.
3. Violation-count query returns zero on existing data before enforcement.
4. Negative, round-trip, and machine-parity tests pass.
5. Constraint names are registered in the error map.
6. Invariant check query added for any rule that cannot be a constraint.
7. Migration passes on a production-shaped dataset with a verified lock impact.