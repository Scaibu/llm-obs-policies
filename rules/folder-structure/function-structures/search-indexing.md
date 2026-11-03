Treating search indexes (Elasticsearch / OpenSearch) as authoritative transactional databases leads to catastrophic data loss. [Certain] Search engines are eventually consistent read models; they must never be the source of truth for transactional write decisions, and index mapping changes must execute zero-downtime reindexing via atomic alias swapping.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Asynchronous Ingestion & Document Upsert

```
searchIndexPipeline(sourceEvents) → searchIndex                             ⚙ + ▶
├── consume(order.created | order.updated | order.deleted)
├── reReadAuthoritativeState(entityId) → canonicalDocument       (never trust payload order)
├── toSearchDocument(canonicalDocument) → searchDoc              ▶
│   └── enforce strict projection: tenantId, version, allowed searchable fields
├── upsertIfNewer(index, searchDoc, searchDoc.version)           ⚙
│   └── Version check ensures out-of-order Kafka events cannot overwrite newer state
└── deleteIfDeleted(index, entityId)                             ⚙
```

---

## 2. Zero-Downtime Reindexing & Alias Swapping

```
executeReindexing(schemaChange) → newActiveIndex                            ⚙
├── createIndex(newMappingSchema) → index_v2
├── backfillData(primaryDatabase → index_v2) (chunked, throttled, checkpointed)
├── enableDualWrite(index_v1, index_v2) during backfill duration
├── verifyDataIntegrity(sampleQueries, docCounts)                ⚠ abort if mismatch
├── swapAlias(alias: "orders_search", from: index_v1, to: index_v2) (atomic swap)
└── dropOldIndex(index_v1, afterGracePeriod: 48h)
```

---

## 3. Search Query Execution

```
executeSearch(context, query) → searchHits                                  ▶
├── injectTenantFilter(query, tenantContext.tenantId)            (mandatory server-side filter)
├── executeIndexQuery(query) → rawHits
└── postFilterAuthorization(rawHits, principal)                  (catch up on access changes)
```

---

## 4. Strict Search Invariants

1. **Eventually Consistent Read Model Only**: Search query results must never be passed as direct input into mutating business decisions without re-verifying the state against PostgreSQL.
2. **Server-Side Mandatory Tenant Scoping**: Every search query DSL payload must enforce `filter: { term: { tenant_id: tenantContext.tenantId } }` injected by the service layer.
3. **Atomic Alias Swaps for Mapping Updates**: Direct in-place mapping updates that require reindexing are forbidden in production. Indexing must build a versioned index (`_v2`) and atomically swap the alias.

