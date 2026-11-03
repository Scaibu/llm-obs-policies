The most dangerous mistake in multi-tenant SaaS architecture is treating tenancy as an afterthought to be retrofitted with a simple `tenant_id` column. [Certain] Changing tenancy models post-launch is a multi-quarter, multi-million dollar migration across every single service; selecting the proper model—shared schema, database-per-tenant, or cell-based—dictates database row-level security, blast-radius isolation, and GDPR crypto-shredding.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Tenancy Model Decision Engine

```
decideTenancyModel(requirements) → tenancyModel                             ▶
├── inputs:
│   ├── tenantCount() → current + 3-year growth projection
│   ├── loadSkew() → percentage of total traffic consumed by top 1% of tenants
│   ├── compliance() → SOC2 | HIPAA | PCI-DSS | GDPR residency
│   └── operationalBudget() → database instances team can realistically maintain
│
├── Option A: Shared Schema (Pool Model)
│   ├── Architecture: Every table has tenant_id column; single shared database pool
│   ├── Fits: Thousands of homogeneous, small-to-medium tenants
│   └── Risks: Noisy neighbors, accidental data leakage, complex single-tenant restore
│
├── Option B: Database-Per-Tenant (Silo Model)
│   ├── Architecture: Each tenant receives isolated database instance
│   ├── Fits: High-value enterprise / regulated tenants with contractual isolation
│   └── Risks: High infrastructure cost; schema migration fleet drift
│
└── Option C: Cell-Based Architecture (Hybrid Pool + Silo)
    ├── Architecture: Independent service stack replicas ("cells") serving tenant shards
    ├── Shared cells for standard tenants; dedicated cells for whales
    └── Fits: 100+ services, hyper-scale traffic, and strict regional residency
```

---

## 2. In-Flight Request Context Propagation

```
resolveAndPropagateTenant(request) → tenantContext                          ⚙
├── extractTenantId(token.claims | hostname | apiKey) → tenantId            ⚠ 401
├── lookupTenantDirectory(tenantId) → tenantRecord (in-memory cached, 60s TTL)
│   └── {tier, cellId, homeRegion, status, featureOverrides, encryptionKeyId}
├── checkStatus(tenantRecord)
│   ├── SUSPENDED → ⚠ HTTP 403 Forbidden
│   ├── MIGRATING → readOnly mode or ⚠ HTTP 503 (Retry-After: 5)
│   └── DELETED   → ⚠ HTTP 404 Not Found
├── routeToCell(tenantRecord.cellId, tenantRecord.homeRegion) → upstream
├── propagateInHeaders()
│   └── inject signed W3C tenant context into outbound HTTP, gRPC, and Kafka events
└── enforceAtStorage()
    ├── repository layer binds WHERE tenant_id = :tenant_id on every query
    └── PostgreSQL Row-Level Security (RLS) active as non-bypassable backstop ⚙
```

---

## 3. Tenant Lifecycle Saga & Cryptographic Shredding

```
tenantLifecycleOrchestrator()                                               ⚙
├── Provisioning Saga:
│   ├── createDirectoryEntry() → assignCell() → createStorage() → seedConfig()
│   └── emit(tenant.provisioned)
├── Migration Saga (Cell Rebalancing):
│   ├── bulkCopyData(fromCell → toCell) → streamReplicate() until lag ≈ 0
│   ├── freezeWrites(5s) → finalCatchUp() → atomicRoutingSwitch(toCell)
│   └── unfreezeWrites() → scheduleCleanupOldCell()
└── Deletion Saga (GDPR Right to be Forgotten):
    ├── setStatus(DELETING) → block all new traffic
    ├── emit(tenant.deletion_requested) across all 100+ microservices
    ├── trackDeletionAcks(ledger) → alert on missing service acks after 24h
    └── destroyEncryptionKey(tenantKeyId) (Crypto-Shredding: backups instantly unreadable)
```

---

## 4. Strict Tenancy Invariants

1. **Dual-Layer Isolation (App + DB RLS)**: Never rely solely on application code to filter `WHERE tenant_id = $1`. Database-level Row-Level Security (RLS) must be enabled on all tables as an absolute defense against accidental cross-tenant data leaks.
2. **Tenant Isolation in Cache Keys**: All cache keys must include the tenant identifier (`tenant:{id}:...`). Mixing tenant data in shared cache keys is strictly forbidden.
3. **Fair Queuing / Noisy Neighbor Protection**: Background workers and event consumers must partition queues by tenant to ensure a single tenant submitting 10 million events cannot starve normal tenants.

