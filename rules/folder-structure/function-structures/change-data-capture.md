Treating Change Data Capture (CDC) streams as private internal database implementation details causes silent, catastrophic failures downstream. [Certain] The moment an analytics warehouse, machine learning model, or cache-invalidation pipeline subscribes to a Debezium or PostgreSQL logical replication stream, that change stream becomes a public API contract governed by strict schema compatibility rules.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. CDC Streaming Architecture

```
cdcPipeline(database) → analyticsSink                                        ⚙
├── readChangeLog(database.wal) → rawWalStream (Debezium log-based, NOT polling queries)
├── transformToChangeEvents(rawWalStream) → events {op: c|u|d, before, after, tenantId, ts}
├── applyDataContract(dataContract, events)
│   ├── scrubPIIColumns() → hash or drop RESTRICTED columns
│   └── enforceSchemaCompatibility() → validate against registered Protobuf/Avro schema
├── publish(cdcTopicPerTable: "cdc.orders.v1")                               ⚙
└── landInWarehouse() → raw Iceberg / BigQuery tables → dbt modeled datasets
```

---

## 2. CDC Data Contract Definition

```
dataContract(tableName) → contractSpec                                       ▶
├── ownerTeam() → owningServiceTeam
├── table() → canonical database table name
├── piiClassification() → {columnName: KEEP | HASH | DROP}
├── schemaCompatibility() → BACKWARD_TRANSITIVE (enforced in CI)
└── breakingChangeGating() → CI blocks PR if column dropped without 6-month deprecation
```

---

## 3. Strict CDC Invariants

1. **Log-Based WAL Tapping Only**: CDC must tap the database write-ahead log (WAL) via logical replication slots (e.g. `pgoutput`). Polling queries (`SELECT ... WHERE updated_at > :t`) are strictly prohibited due to high CPU load and missed intermediate deletions.
2. **Schema Registry Validation in CI**: Database migrations that alter CDC-replicated tables must validate against the central Schema Registry in CI to prevent downstream warehouse breaks.
3. **Partition Key Consistency**: All change events for a given table must partition Kafka streams by the primary key or tenant ID to ensure strict ordering of updates and deletions per entity.

