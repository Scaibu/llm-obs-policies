
# Category 6: Query and index performance

**Problem statement:** The cost of each access path changes as data volume, value distribution, concurrency, and planner state change. Performance must stay acceptable at p99 as all four move. The failure is a query that was fine for a year and then falls off a cliff.

**Subproblems:** 6A validating performance. 6B planner behavior. 6C index design. 6D specific query shapes.

## 6A. Validating performance

#### 6.1 "If it's fast in dev and staging, it's fast" (was #21) [Certain]
- **Why wrong:** Performance depends on volume, value distribution, concurrency, cache state, and plan choice, and dev reproduces none of them.
- **What is correct:** Performance is a property of the query together with the data shape, the load, and the chosen plan.
- **Problem it creates:** Surprises at production thresholds: plan flips, cache misses, lock contention.
- **First-principles fix:** Keep production-shaped data (volume and skew, anonymized) for performance tests, test under concurrency, inspect plans at 10x, and track p95/p99 per query shape in production.
- **Meta:** At what row counts do plans change? Which parameter values are worst case?
- **Second-order:** What does production-shaped data cost, and what are its privacy risks? Do hardware differences between test and production distort results?

#### 6.2 "Premature optimization is the root of all evil, so ignore performance early" (was #23) [Likely]
- **Why wrong:** The quote is about micro-optimizations. Structural choices (grain, keys, access paths, partitioning) are performance decisions and are expensive to change.
- **What is correct:** Defer micro-tuning, and decide structure with the top access patterns in view.
- **Problem it creates:** An architecture that can't serve its main queries without a rewrite.
- **First-principles fix:** Before building, list the top 5-10 queries and writes with volumes. For each, state the access path (index, partition, key) and a rough cost. Defer everything else.
- **Meta:** Which five queries matter, and what serves each?
- **Second-order:** Does focusing on the listed queries blind me to emergent ones? How and when do I revisit the list?

## 6B. Planner behavior

#### 6.3 "The query planner is smart, so trust it" (was #22) [Likely]
- **Why wrong:** Planner decisions rest on statistics and cost-model assumptions that fail on correlation, skew, and stale stats, and plans can flip.
- **What is correct:** The planner is a heuristic estimator whose output you must monitor.
- **Problem it creates:** A query regresses overnight with no code change.
- **First-principles fix:** Monitor top queries with plan fingerprints and alert on plan or latency change. Keep stats fresh, use multi-column statistics, compare estimated and actual rows in EXPLAIN ANALYZE, and for critical queries pin the plan or rewrite to remove the ambiguity.
- **Meta:** Which critical queries sit near a plan boundary? Which estimates are off by 10x?
- **Second-order:** Pinned plans go stale as data changes, and hints reduce portability. Who owns revisiting them?

#### 6.4 "Statistics maintain themselves" (was #45) [Likely]
- **Why wrong:** Auto-stats trigger on a percentage of changed rows, so huge tables rarely refresh. Bulk loads arrive without stats, and single-column stats miss correlation.
- **What is correct:** Stats are a monitored input to the planner.
- **Problem it creates:** Bad row estimates lead to wrong join orders and scan types.
- **First-principles fix:** ANALYZE after bulk loads and large changes, lower per-table scale factors on huge tables, raise statistics targets on skewed columns, and create extended statistics for correlated columns.
- **Meta:** When was each hot table last analyzed? Which columns are skewed or correlated?
- **Second-order:** More frequent analyze adds load, and larger stats targets increase planning time.

#### 6.5 "Prepared statements always get the best plan" (was #46) [Certain]
- **Why wrong:** A cached plan may be reused across parameter values that need different plans.
- **What is correct:** A plan is tied to a selectivity assumption.
- **Problem it creates:** Some parameter values run 100x slower with no query change.
- **First-principles fix:** Test with low, median, and high-skew parameters, use engine controls (plan_cache_mode in PostgreSQL, recompile hints elsewhere), split known skewed cases into separate query paths, and monitor latency per parameter class.
- **Meta:** Which parameter values are rare but expensive? How do my driver and pooler handle plan caching?
- **Second-order:** Forcing custom plans costs planning CPU, and pooler modes change prepared-statement behavior.

## 6C. Index design

#### 6.6 "Slow query? Add an index" (was #20) [Certain]
- **Why wrong:** An index adds write amplification, memory and storage cost, and planner options, and it may not match the query's shape. The real cause might be shape, stats, or volume.
- **What is correct:** An index is a bet on a workload, justified by a measured access pattern.
- **Problem it creates:** A pile of overlapping, unused indexes that slow writes and bloat the cache while the query stays slow.
- **First-principles fix:** Start from EXPLAIN and find where time goes (rows scanned versus returned, sort, join). Design the minimal index serving filter and order for the top patterns, test it, and periodically remove unused and duplicate indexes using usage stats.
- **Meta:** What does the plan say about why this is slow? Could an existing index serve it with a small change?
- **Second-order:** What is the write throughput impact and index build cost? Will the index stay useful when the query changes?

#### 6.7 "Composite index column order doesn't matter much" (was #42) [Certain]
- **Why wrong:** An index is ordered by its first column, then its second, and so on. It is usable through its leftmost prefix, a range column stops later columns from narrowing, and sort satisfaction depends on order.
- **What is correct:** Column order encodes which queries the index can serve and in what order.
- **Problem it creates:** An index that exists but isn't used, or is used with filtering after the scan.
- **First-principles fix:** Put equality columns first, then the range or sort column. Verify in the plan that the predicates appear as index conditions rather than filters and that no extra sort remains.
- **Meta:** Which queries need this index, and what are their predicates and orderings?
- **Second-order:** Can one column order serve several queries, or do I need two indexes? Does my engine support skip-scan?

#### 6.8 "An index-only scan never touches the table" (was #43) [Certain]
- **Why wrong:** In PostgreSQL, visibility information lives in the heap, so index-only scans depend on the visibility map and recently modified pages need heap fetches. Other engines differ.
- **What is correct:** Index-only access is conditional on the engine and on table churn.
- **Problem it creates:** Covering queries that still hit disk.
- **First-principles fix:** Use INCLUDE columns for covering, keep autovacuum aggressive on hot tables, read "Heap Fetches" in EXPLAIN ANALYZE, and don't depend on index-only behavior for high-churn tables.
- **Meta:** How update-heavy is this table? What do plans show for heap fetches?
- **Second-order:** Wide covering indexes raise write cost and size, and tuning vacuum adds background I/O.

#### 6.9 "Search is a LIKE problem" (was #44) [Certain]
- **Why wrong:** Leading wildcards and locale collations defeat B-tree ordering, and LIKE has no relevance ranking, stemming, or typo tolerance.
- **What is correct:** Text search needs inverted or trigram structures, or a search engine.
- **Problem it creates:** Full scans on search queries and poor results.
- **First-principles fix:** Define the query types (prefix, substring, fuzzy, ranked). Use prefix indexes, trigram GIN, or built-in full-text for modest needs. Use a search engine as a derived store fed by CDC when relevance or facets matter.
- **Meta:** What does "found" mean to the user: exact, prefix, or ranked?
- **Second-order:** A derived search index lags the source, reindexing costs time, and permission or delete changes must propagate.

## 6D. Specific query shapes

#### 6.10 "ORDER BY ... LIMIT is cheap" (was #47) [Certain]
- **Why wrong:** Without an index matching filter and order, the engine finds all matching rows and sorts them before taking N. With OFFSET it also discards the skipped rows.
- **What is correct:** LIMIT bounds output, not the work of finding the top rows.
- **Problem it creates:** Latency that scales with matching rows, and slow deep pages.
- **First-principles fix:** Index on (filter equality columns, sort columns) so rows stream in order. Use keyset pagination (WHERE (sort_key, id) > (last values)) and cap maximum page depth.
- **Meta:** How many rows match before the limit? Is the sort order unique, or do ties exist?
- **Second-order:** Keyset pagination can't jump to arbitrary page numbers, and multi-column sort directions need matching index definitions.

#### 6.11 "COUNT(*) is fast" (was #48) [Certain]
- **Why wrong:** MVCC engines must check row visibility, so exact counts scan rows and cost grows with table size.
- **What is correct:** An exact count is an O(n) question unless you maintain it.
- **Problem it creates:** Dashboards and pagination totals that load the database.
- **First-principles fix:** Decide the precision required. Options are approximate counts (planner estimates, HyperLogLog), maintained counters with reconciliation, cached counts with a TTL, or dropping exact totals ("1000+").
- **Meta:** Does anyone make a decision that depends on the exact number?
- **Second-order:** Maintained counters add write contention, and approximate counts confuse users when they disagree with other views.

#### 6.12 "Joins are expensive, so avoid them" (was #49) [Certain]
- **Why wrong:** Indexed joins are the engine's core strength. Avoiding them through application-side joins adds round trips, and avoiding them through denormalization adds sync burden.
- **What is correct:** Join cost depends on index availability and selectivity, and network hops cost more.
- **Problem it creates:** N+1 patterns, drifting duplicate data, and slower overall performance.
- **First-principles fix:** Join on indexed keys, check join method and ordering in the plan, reduce rows early with selective filters, and denormalize only on measured need with an owner for the sync.
- **Meta:** What does the plan show: join method, rows in and out, index use?
- **Second-order:** Large multi-way joins hit planner limits and estimation errors, and ORM-generated joins may over-fetch.

#### 6.13 "Full table scans are always bad" (was #50) [Certain]
- **Why wrong:** When a large fraction of rows is needed, or the table is small, a sequential scan beats random index lookups. Forcing indexes can slow queries.
- **What is correct:** Cost is about total I/O relative to what the result needs.
- **Problem it creates:** Reflexive index additions while real problems, like scanning 99% of a table to return one row, go unnoticed.
- **First-principles fix:** Compare rows examined with rows returned and consider selectivity. A scan is fine when selectivity is low. Add an index when returning a small fraction of a large table.
- **Meta:** What fraction of the table does this query need?
- **Second-order:** Scans evict hot cache pages and compete under concurrency, so repeated "fine" scans can hurt other queries.

---