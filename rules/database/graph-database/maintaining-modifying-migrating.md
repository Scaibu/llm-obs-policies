
# Part 2: Maintaining, modifying, and migrating queries

## 2.1 Classify every change first

| Change | Example | Handling |
|---|---|---|
| **Internal** | Rewrite for speed, same output | Same version number, patch note, must pass the same test suite and a perf diff |
| **Compatible** | New output column, optional param | Minor bump, consumers ignore unknown columns |
| **Breaking** | Column renamed or removed, semantic change, new required param | **New major version, run old and new in parallel** |

 Never edit a breaking change in place. Callers deploy on different schedules than you do.

## 2.2 Version and registry
- Query ID plus version (`recs.peer_products.v3`) is the unit the app calls.  The gateway holds a registry mapping the ID to the currently active version, so you can roll forward and back without redeploying callers.
- Keep old versions available until usage metrics show zero traffic, then delete. 
- Record `queryId`, `version`, and `traceId` in transaction metadata on every call so logs show which version ran.  (See 3.3.)

## 2.3 Schema migrations: expand → migrate → contract
For model changes (rename a property, split a relationship type, add a label) [Certain this pattern is required, because you can't atomically change billions of elements and every query at once]:

1. **Expand:** add the new structure alongside the old one (new property, new relationship type, new index). Both exist.
2. **Dual-write:** the ingestion path writes both old and new forms.
3. **Backfill:** populate the new form for existing data in batches, with `CALL { ... } IN TRANSACTIONS OF 5000 ROWS`, throttled and resumable (keyset by ID, with a checkpoint).  Run it off-peak and watch page cache hit ratio and replica lag.
4. **Verify:** compare counts and sampled records between old and new. Don't trust "the job finished". 
5. **Switch reads:** the registry points to the query version that uses the new structure, by canary percentage. 
6. **Contract:** after a soak period with no traffic on old queries, stop dual-write and drop the old structure, index, or property.  Deleting properties and relationships at scale is also a batched job.

Tooling : **neo4j-migrations** (the community tool) or Liquibase/Flyway-style versioned scripts for schema (constraints and indexes), run from CI/CD with a `SchemaVersion` node or its built-in tracking. Test migrations on a production-size restore before running them. 

## 2.4 Index and constraint changes at scale
-  `CREATE INDEX` populates in the background and the index is unusable until `ONLINE`. Check `SHOW INDEXES YIELD name, state, populationPercent`. Don't deploy queries that depend on it until it's online.
-  A uniqueness constraint fails if duplicates already exist, so clean up first and verify with an aggregation query.
-  Index builds consume IO and page cache. Schedule them off-peak and expect replicas to build their own copy.

## 2.5 Safe-change protocol for a query rewrite
1. Run old and new versions **in shadow** on a sample of real traffic against a secondary. Don't return the shadow result to users. 
2. Diff outputs automatically (set-equal or score-within-epsilon) and diff **db hits and latency distributions**.
3. Canary 1% → 10% → 50% → 100% with automatic rollback on error rate or p99 regression. 
4. Keep the previous version for one release cycle.

## 2.6 Neo4j version upgrades and language changes
-  Newer Neo4j releases introduce language versions (Cypher 5 vs Cypher 25). You can pin per query with a `CYPHER 5` prefix or database default. Pin explicitly, then migrate deliberately. [Guessing on exact version numbers; check the release notes]
- Before upgrading: run your whole query suite and its db-hits budgets on the new version in staging with production-size data, because planner changes can regress individual queries. 
- Watch for deprecations (`id()` → `elementId()`, old procedure names). Make deprecation warnings a CI failure. 

## 2.7 Impact analysis
Add `labels`, `relTypes`, and `properties` lists to each header, or parse them in CI.  Then a schema change gets an automatic list of the queries it touches. Without this, a property rename becomes archaeology.

---