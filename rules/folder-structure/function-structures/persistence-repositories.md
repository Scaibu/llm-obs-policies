The most critical database vulnerabilities are cross-tenant data leaks and lost updates caused by blind SQL overwrites. [Certain] Forcing caller services to remember tenant isolation clauses in business logic inevitably leads to cross-tenant data exposure, and updating entities without optimistic locking corrupts state under concurrent traffic.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis
  ↺  registers cleanup
```

---

## 1. Repository Interface Contract

```
ordersRepository                                                            ▶
├── getById(context, tenantId, id) → order | NotFound
├── list(context, tenantId, query) → pageResult     (keyset cursor, index-backed sort)
├── insert(context, tx, order) → persistedOrder
├── update(context, tx, order, expectedVersion) → updatedOrder ⚠ → StaleVersionError (HTTP 412)
└── inTransaction(context, fn) → result
```

---

## 2. Repository Execution Invariants & Chassis Pipeline

```
everyRepositoryCall()                                                       ⚙
├── enforceTenantScope(query, tenantId)            (injected inside repo; caller cannot bypass)
├── applyQueryTimeout(context.Deadline())          (derived from request deadline)
├── verifyOptimisticConcurrency(expectedVersion)   (WHERE id = :id AND version = :expectedVersion)
├── routeDatabaseInstance() → primary | replica    (write: primary; read: primary or replica)
├── batchLoadRelatedEntities()                     (WHERE id = ANY(:ids); NO queries in loops)
├── recordQuerySpan(queryName, rowsAffected)       (child OpenTelemetry span)
└── recordDurationMetric(queryName, outcome)       (Prometheus duration histogram)
```

---

## 3. Transactional Outbox Integration

```
inTransaction(context, fn)                                                  ⚙
├── beginTransaction() → tx
├── executeBusinessMutations(tx)                                            ▶
├── writeOutboxEvents(tx, domainEvents)                                     ⚙
│   └── INSERT INTO outbox_events (event_id, payload, topic, partition_key, created_at)
├── commitTransaction() → success                                           ⚠
└── onFailure → rollbackTransaction()                                       ⚙
```

---

## 4. Strict Persistence Invariants

1. **Mandatory Repository-Level Tenant Scoping**: Tenant scoping must be enforced inside the repository adapter methods, never left to caller discipline. Every SQL query must bind `WHERE tenant_id = $1`.
2. **Optimistic Concurrency (Zero Blind Updates)**: All mutating updates must execute `UPDATE ... SET version = version + 1 WHERE id = :id AND version = :expected_version`. If zero rows are affected, the adapter must raise a typed `StaleVersionError` (mapped to HTTP 412 / Precondition Failed).
3. **Transactional Outbox for Domain Events**: Dual writes (writing to PostgreSQL and sending to Kafka in memory) are strictly forbidden. Domain events must be inserted into the `outbox_events` table within the same database transaction as the entity state mutation.
4. **Keyset Cursor Pagination (Zero `OFFSET`)**: Never use `OFFSET` for pagination on growing tables. Repositories must enforce keyset cursor pagination (`WHERE id > :cursor ORDER BY id ASC LIMIT :pageSize`).

