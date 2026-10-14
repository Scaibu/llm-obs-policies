# Neo4j at Billion-User Scale: The Engineering Handbook

*Working assumptions: version, real numbers and workload are not yet known, so everything is conditional. Version-specific items must be checked against current release notes. Confidence tags: \[Certain\] hard evidence, \[Likely\] strong inference, \[Guessing\] filling gaps.*

**Core claim:** You can't scale Neo4j to billions of users by adding hardware, because the write leader and the traversal cost model are architectural limits and hardware only moves them. \[Certain\] Scaling is five separate problems: read throughput, write throughput, data volume, query cost, and operational blast radius. Each has a different fix, and mixing them up is how teams buy 10x hardware and get 1.2x results.

## How to use this handbook

**Start with the part that matches your question.** The parts follow the life of a graph platform: decide, write, change, run, secure, make safe, then look things up. \[Certain\]

| Part | Question it answers | Sections |
| --- | --- | --- |
| 1. Foundations | What should we build, how big, and how should the data be modeled? | 1 to 4 |
| 2. Writing complex queries | How do we write queries that stay bounded and correct at scale? | 5 to 10 |
| 3. Changing queries and schema safely | How do we modify, migrate and upgrade without breaking callers or data? | 11 to 13 |
| 4. Deploying, running and scaling | How do we configure, deploy, observe and scale it? | 14 to 25 |
| 5. Security | How do we protect data, access and the platform? | 26 |
| 6. Safety and criticality | How do we survive failures in a complex system? | 27 to 30 |
| Appendices | Worked example, templates, troubleshooting index, references | A to D |

**Reading paths by role**

| Role | Read first | Then |
| --- | --- | --- |
| Architect | 1, 2, 3, 4, 17, 27 | 14 to 16, 25, Appendix A |
| Query author | 5, 6, 7, 10 | 8, 9, 11, 12 |
| Platform or SRE engineer | 14 to 22 | 27 to 29, Appendix C |
| Security engineer | 26, 10.6 to 10.8, 10.11 | 7.3, 27.2 |
| Incident commander or manager | 28, 29, 27.9 | 30, Appendix A |

**Conventions used throughout**

- Confidence tags: **\[Certain\]** hard evidence, **\[Likely\]** strong inference, **\[Guessing\]** filling gaps.
- Query labels: **Admin** (run on a server or the system database), **Replica** (broad scans, analytics secondary only), **Anchored** (starts from one indexed node, safe for tier 1).
- Tiers 0 to 3 are defined in section 27.1, and the same tier names are used in every query header.
- Section numbers are stable references. Appendix C maps symptoms to the section and query to use.
- Nothing here has been tested against your environment. Check version-specific syntax and treat every number as a starting point for your own load tests.

# Part 1. Foundations: diagnose, size, architect and model

Decide before you build: which axis is saturated, what capacity you need, which architecture fits, and how to shape the data so that every query has a bounded cost.

## 1. Diagnose which scaling problem you have

Don't pick a technique until a measurement tells you which axis is saturated. \[Certain\]

| Symptom | Axis | Wrong fix | Right fix |
| --- | --- | --- | --- |
| p99 high, CPU low, disk reads high | Data volume (cache miss) | More CPU | More RAM, smaller hot set, tiering |
| p99 high, CPU high on secondaries | Read throughput | Bigger primaries | More secondaries, caching |
| Write latency rising, secondaries fine | Write throughput | More secondaries | Batching, partitioning by database, offload counters |
| One query class slow, others fine | Query cost | Hardware | Cap, materialize, rewrite |
| Everything degrades together during analytics | Workload isolation | Tuning | Separate clusters |

Establish a **saturation dashboard** first \[Certain\]: for each cluster member, track CPU, page cache hit ratio, disk read IOPS and latency, GC pause, open transactions, and Raft commit lag. The first one to saturate under load is your actual bottleneck, and it is usually not the one people assume.

## 3. Data-modeling patterns that keep queries cheap at scale

**Uncomfortable truth:** at this scale the model decides the cost of every query, and a query-level fix cannot rescue a model with a hub in the middle of every path. \[Certain\] Each pattern below trades an extra hop or extra write complexity for bounded work, so adopt one only where measurement shows the problem.

### 25.1 Supernode bucketing (high-fan-in nodes)

```cypher
CREATE CONSTRAINT follower_bucket IF NOT EXISTS
FOR (b:FollowerBucket) REQUIRE (b.ownerId, b.bucket) IS UNIQUE;

// Write: the application picks the bucket, for example stableHash(followerId) % 64
MATCH (owner:User {userId: $ownerId}), (follower:User {userId: $followerId})
MERGE (b:FollowerBucket {ownerId: $ownerId, bucket: $bucket})
MERGE (owner)-[:HAS_BUCKET]->(b)
MERGE (follower)-[:FOLLOWS_VIA]->(b);

// Read: exact follower count, touching one counter per bucket at most
MATCH (owner:User {userId: $ownerId})-[:HAS_BUCKET]->(b:FollowerBucket)
RETURN sum(COUNT { (b)<-[:FOLLOWS_VIA]-() }) AS followers;

// Read: a bounded sample of followers
MATCH (owner:User {userId: $ownerId})-[:HAS_BUCKET]->(b:FollowerBucket)
WHERE b.bucket IN $bucketSubset
CALL (b) {
  MATCH (b)<-[:FOLLOWS_VIA]-(f:User)
  RETURN f LIMIT 100
}
RETURN f.userId LIMIT 500;

// Read: does this follower follow this owner? Anchored on the follower, bounded by its own out-degree
MATCH (f:User {userId: $followerId})-[:FOLLOWS_VIA]->(:FollowerBucket {ownerId: $ownerId})
RETURN count(*) > 0 AS follows;
```

- &#91;Likely\] Choose the bucket count so each bucket stays near a target size: `buckets ≈ ceil(expected degree / target bucket degree)`. For 50 million followers and a 100,000-edge target, that is about 500 buckets.
- &#91;Certain\] Write contention on the hub drops by roughly the bucket count, because writers lock different bucket nodes.
- &#91;Certain\] The price is an extra hop on every traversal through the hub and more complex queries. Use a stable hash function (xxHash or MurmurHash), never a language built-in that is randomized per process, because the bucket for a given follower must be identical across every writer and every restart.
- &#91;Likely\] Apply bucketing only to nodes whose degree crosses a threshold. Keeping a degree property that the stream layer maintains lets you migrate hubs to bucketed form one at a time.

### 25.2 Time-bucketed event history

```cypher
CREATE CONSTRAINT activity_day IF NOT EXISTS
FOR (d:ActivityDay) REQUIRE (d.userId, d.day) IS UNIQUE;

MATCH (u:User {userId: $userId}), (i:Item {itemId: $itemId})
MERGE (d:ActivityDay {userId: $userId, day: date($day)})
MERGE (u)-[:HAS_DAY]->(d)
CREATE (d)-[:VIEWED {ts: datetime($ts)}]->(i);

// Read the last 7 days, newest first, bounded
MATCH (u:User {userId: $userId})-[:HAS_DAY]->(d:ActivityDay)
WHERE d.day >= date() - duration('P7D')
MATCH (d)-[v:VIEWED]->(i:Item)
RETURN i.itemId, v.ts ORDER BY v.ts DESC LIMIT 100;
```

&#91;Certain\] Unbounded event relationships on a user node are the usual reason p99 degrades slowly over months. Day buckets make retention a cheap batched delete of whole `ActivityDay` nodes, and make "last N days" an indexed range filter. Pair with roll-ups for old data.

### 25.3 Intermediate node (hyperedge) for multi-party facts

```cypher
// One Order node connects buyer, items, payment and shipment, so none needs a pairwise relationship
MATCH (buyer:User {userId: $buyerId})
CREATE (o:Order {orderId: $orderId, placedAt: datetime()})
CREATE (buyer)-[:PLACED]->(o)
WITH o
UNWIND $lines AS line
MATCH (p:Product {productId: line.productId})
CREATE (o)-[:CONTAINS {qty: line.qty, price: line.price}]->(p);
```

&#91;Likely\] Use an intermediate node whenever a fact involves more than two entities, has its own properties and lifecycle, or must be referenced by other relationships. A relationship cannot connect to another relationship, so reify instead.

### 25.4 Temporal (as-of) relationships

```cypher
// Close the current relationship and open a new one in one transaction
MATCH (e:Employee {employeeId: $id})-[old:REPORTS_TO]->()
WHERE old.validTo IS NULL
SET old.validTo = $effective
WITH e
MATCH (m:Employee {employeeId: $newManagerId})
CREATE (e)-[:REPORTS_TO {validFrom: $effective, validTo: null}]->(m);

// Who was the manager on a given date?
MATCH (e:Employee {employeeId: $id})-[r:REPORTS_TO]->(m)
WHERE r.validFrom <= $asOf AND (r.validTo IS NULL OR r.validTo > $asOf)
RETURN m.employeeId;
```

&#91;Certain\] Index the relationship properties you filter on, for example `CREATE INDEX reports_to_valid IF NOT EXISTS FOR ()-[r:REPORTS_TO]-() ON (r.validFrom)`. \[Likely\] If the graph holds history for audit, keep the current-state relationships separate from history relationships so hot queries never scan the past.

### 25.5 Multi-tenancy options

| Approach | Isolation | Cost and limits | Use when |
| --- | --- | --- | --- |
| `tenantId` property on every node, enforced in queries | Weak, one missed predicate leaks data | Cheapest, best density | Low sensitivity, strong query lint and invariant checks |
| Property-based access control on `tenantId` | Medium, enforced by the database | Per-access evaluation cost \[Guessing on size, measure it\] | Moderate sensitivity, many small tenants |
| **Database per tenant** | Strong | Per-database overhead, so there is a practical count limit per server \[Likely, measure\] | Regulated or large tenants |
| **Cell per tenant group** | Strongest, with separate blast radius | Most infrastructure | Very large tenants, strict SLAs |
| One label per tenant | None gained | **Label explosion** degrades the schema and planner \[Certain\] | Never |

### 25.6 Model anti-patterns to reject in review

- A single `RELATED_TO` relationship type with a `type` property. \[Certain\] Filtering by property after traversal defeats type-based degree grouping.
- JSON blobs or large strings on hot nodes. Keep them in an object store keyed by ID.
- Counters and last-seen timestamps on graph elements. Aggregate outside, sync in batches.
- A relationship per raw event with no retention plan.
- Lists of thousands of IDs stored as a property when you need to traverse them.
- Business-critical balances or inventory as graph properties for tier 0 workloads (section 17.3).

## 4. Cell router and resharding design

### 26.1 Logical buckets with an indirection table

```python
import xxhash

LOGICAL_BUCKETS = 4096            # far more logical buckets than cells, fixed forever

def bucket_of(user_id: str) -> int:
    return xxhash.xxh64_intdigest(user_id) % LOGICAL_BUCKETS   # stable across processes

def cell_for(user_id: str, table) -> str:
    return table.assignments[bucket_of(user_id)]               # bucket -> cell id, versioned by epoch
```

- &#91;Certain\] **Hash into many logical buckets, then map buckets to cells in a table.** Moving load becomes an edit to the table for a few buckets, never a rehash of every key.
- &#91;Certain\] Never use a language built-in `hash()`. Many are randomized per process, which silently routes the same user to different cells.
- &#91;Likely\] Store the table in a replicated configuration store with an **epoch** number. Routers cache it and keep serving from the last known table if the control plane is down (static stability).

### 26.2 Fencing with epochs

Every request and every write carries the routing epoch it was routed under. Each cell records, per logical bucket, the epoch at which it became owner. A cell **rejects writes for a bucket it no longer owns at the request's epoch**. \[Certain\] This prevents the classic resharding bug in which a stale router keeps writing to the old cell after ownership moved.

### 26.3 Moving a bucket set between cells

| Step | Action | Gate to proceed |
| --- | --- | --- |
| 1. Plan | Pick buckets and the target cell, check target capacity against the measured knee | Target stays under 60-70% utilization after the move |
| 2. Snapshot copy | Copy the bucket's nodes and their relationships to the target with keyset-paged batches or the offline import path | Row counts match the source |
| 3. Dual-write | The stream layer writes the bucket's events to both cells, tagged with the epoch | Consumer lag on both cells is within SLO |
| 4. Catch-up and verify | Compare per-bucket counts and checksums, run canary reads against both cells | Zero unexplained diffs |
| 5. Flip reads | Route a small percentage of reads, then all, to the target | No SLO regression, canary probes pass |
| 6. Flip writes | Bump the epoch, the source cell now rejects writes for those buckets | No fenced-write errors beyond the expected cutover window |
| 7. Soak and contract | Wait through a soak period, take a verified backup of the source, then delete the moved data in batches | Soak period passed with no rollback |

&#91;Certain\] The move is reversible until step 7, so build the rollback (flip the epoch and routes back, re-sync the delta) before you start, and rehearse it on a copy.

### 26.4 Cross-cell relationships

| Option | How | Consistency | Cost |
| --- | --- | --- | --- |
| **Shadow nodes** | Replicate a minimal copy of the remote user into the local cell | Eventually consistent through the stream layer | Extra storage and write fan-out \[Likely\] |
| **Application fan-out** | The service queries each involved cell and merges results | Per-cell consistency | Latency multiplies with fan-out, so cap it (section 14.5) |
| **Precomputed cross-cell edges** | The analytics tier computes them and loads them into each cell | Stale by the job interval | Needs a freshness SLO |

&#91;Certain\] Measure the cross-cell edge ratio on real data before fixing the cell key. A key that puts 40% of edges across cells turns most multi-hop queries into distributed queries.

### 26.5 Sizing the number of cells

`cells = ceil(users / users_per_cell × headroom)`, where `users_per_cell` comes from the measured knee of one cell under your real query mix at 60-70% utilization, and headroom covers growth and the loss of one cell. \[Certain formula, Guessing on inputs\] For example, if load tests show one cell comfortably serving 100 million users, then 2 billion users with 30% headroom needs about 26 cells. Replace the example numbers with measurements before planning.

&#91;Certain\] Global constraints (a username that must be unique across all users) cannot be enforced by per-cell uniqueness constraints. They need a small global service, separate from the graph, which the router consults at write time.

# Part 2. Writing complex queries

**Uncomfortable truth first:** most billion-scale graph failures come from running an exact algorithm with super-linear cost, or an unguarded query, on the wrong tier, not from a missing feature. \[Certain\] Exact betweenness centrality is O(V·E) with Brandes' algorithm and all-pairs shortest paths is worse, so neither is feasible on a billion-edge graph without sampling or approximation. Everything below is organized so you know which algorithm or query is safe, where it runs, and what it can break.

## 6. Query-cost scaling: bounding work by construction

This is the highest-leverage section. \[Certain\]

### 6.1 Work budgets

For each T1 query, define **maximum expansions** = product of per-hop caps. If hop 1 is capped at 100 and hop 2 at 50, the worst case is 5,000 regardless of data size. Enforce it in the Cypher itself with `LIMIT` inside `CALL {}` subqueries, not just by timeout.

### 6.2 Materialization strategies (ordered by when to use)

1. **Top-K neighbor lists** \[Likely\]: batch job computes the strongest K edges per node and stores them as `TOP_CONNECTION` relationships, or as a list property when you never filter on them. Queries then traverse K, not degree.
2. **Precomputed similarity** (`SIMILAR_TO {score}`) from GDS node similarity or an external job, refreshed on a schedule. Cap each node at K similar neighbors.
3. **Rollup nodes** for time-series or event history (`(:User)-[:ACTIVITY]->(:DailyRollup {date})`), so old data stays queryable without scanning raw events.
4. **Embedding or vector index** \[Likely\] for "find similar" at large scale. Approximate nearest neighbor lookup replaces multi-hop traversal for similarity use cases. Verify vector index availability and limits in your version.
5. **Reachability or label indexes outside the graph** for questions like "is A connected to B within 6 hops" (e.g. 2-hop labeling structures in a dedicated service). \[Guessing on fit, since it depends on how static the graph is\]

**Staleness is the price** \[Certain\]: every materialization is a consistency tradeoff, so state each one's freshness SLO in the query header and monitor the age of the derived data.

### 6.3 Sampling and approximation

- &#91;Likely\] Counts at scale: deterministic hash-bucket sampling (`WHERE u.hashBucket < 10`, then multiply). Accept a stated error margin.
- Degree-based sampling in traversals: expand at most N random or top-ranked neighbors per node. Random sampling needs `rand()` and breaks result determinism and caching, so prefer top-K with a stable ordering where possible. \[Likely\]

### 6.4 Algorithms at scale

- &#91;Likely\] For PageRank, community detection, node similarity, and path-heavy analytics, use **GDS** on a dedicated analytics cluster or an exported projection, or Spark GraphFrames/GraphX for graphs beyond a single machine's memory. Neo4j's in-memory projections must fit in RAM on one machine. At billions of nodes, verify against your hardware before committing, and check whether the current GDS release offers a distributed or sharded option. \[Guessing\]
- Write the results back as properties or relationships in batches, and treat them as T2 derived data.

## 7. Cypher correctness traps (silent data bugs)

### 17.1 Statements that succeed while doing the wrong thing

| Trap | What actually happens | Safe pattern |
| --- | --- | --- |
| `MATCH` finds nothing, later `MERGE` or `SET` never runs | The statement returns success with zero rows, so the write silently did not happen | Check the result summary counters (`relationships_created`, `properties_set`) in the application and treat an unexpected zero as an error. \[Certain\] |
| `UNWIND []` | An empty list yields **zero rows**, so everything after it is skipped, including other writes in the same statement | Skip the call in the application when the list is empty, or isolate each write in its own `CALL` subquery. \[Certain\] |
| `SET n = $map` | **Replaces all properties** on the node, deleting any not in the map | Use `SET n += $map` to merge. This is a frequent cause of vanished properties. \[Certain\] |
| `WHERE n.status <> 'ACTIVE'` | Rows where `status` is `null` are dropped, because `null <> 'ACTIVE'` is `null` | `WHERE coalesce(n.status, '') <> 'ACTIVE'` or an explicit `IS NULL OR`. \[Certain\] |
| `MERGE (n:User {userId: $id})` with `$id = null` | Raises an error (cannot merge with a null property value) | Validate keys in the application before sending. \[Certain\] |
| `MERGE` on a full pattern | Creates the entire pattern, including duplicate nodes, if any piece is missing | Merge nodes first, then relationships, in separate clauses. \[Certain\] |
| `MERGE` without a uniqueness constraint | Two concurrent transactions can both create the node | Always back a `MERGE` key with a uniqueness constraint. \[Certain\] |
| `LIMIT` without `ORDER BY` | Returns arbitrary rows, so pagination skips and repeats | Order by a unique, stable key and paginate by keyset. \[Certain\] |
| `collect()` then use the order | List order is not guaranteed | `ORDER BY` before `collect()`. \[Certain\] |
| `DISTINCT` to "fix" duplicates | Hides a join fan-out and costs time | Fix the pattern or aggregate earlier. \[Certain\] |
| `5 / 2` | Integer division gives `2` | `toFloat(5) / 2`. \[Certain\] |
| Optional match with `count(*)` | Counts the null row as 1 | `count(x)` ignores nulls, `count(*)` does not. \[Certain\] |
| `DETACH DELETE` | Silently removes every relationship on the node | Inspect degree first, delete in batches for large nodes. \[Certain\] |

### 17.2 Type and identity traps

- &#91;Certain\] Comparing mismatched types (a string parameter against an integer property) can skip the index and return nothing, with no error. Keep types identical end to end. Use native `datetime` and `date`, and store everything in UTC.
- &#91;Certain\] Cypher integers are 64-bit. A JavaScript driver that converts them to `Number` loses precision above 2^53, so use string IDs, or the driver's `Integer` type, for large numeric identifiers.
- &#91;Certain\] `elementId()` and internal IDs are not stable across restores, imports or store copies. Use application keys with uniqueness constraints as cross-system identifiers.
- &#91;Certain\] Properties can hold primitives and homogeneous lists of primitives, but not nested maps. Model structure as nodes, or serialize deliberately.
- &#91;Likely\] Run a mixed-type audit (section 18.3), because a property stored as both string and integer across rows breaks index use unpredictably.

### 17.3 Concurrency and isolation

- &#91;Certain\] Neo4j's default isolation is **read committed**, not snapshot. Within one transaction, repeated reads can see other transactions' committed changes, and read-modify-write sequences can lose updates.
- &#91;Likely\] `SET n.count = n.count + 1` and "check balance, then subtract" patterns can race. Take the lock first, then read, then write:

```cypher
MATCH (a:Account {accountId: $id})
SET a._lock = true           // acquires the write lock on the node
WITH a
WHERE a.available >= $amount
SET a.available = a.available - $amount
REMOVE a._lock;
```

Verify this pattern under concurrent load in your version before trusting it, and check the summary counters to detect a not-applied update. \[Likely\]

- &#91;Certain\] For **tier 0 financial state, the graph should not be the ledger.** Keep balances and authoritative money movement in a system built for serializable transactions, and let the graph hold relationships and derived views.
- &#91;Certain\] Writers that touch multiple nodes must acquire them in a consistent order (sorted by key), or they deadlock. Neo4j detects deadlocks and aborts one transaction, so the application must retry with backoff, which managed transactions do.
- &#91;Likely\] Avoid `Eager` operators in write queries, because they buffer all rows and change when reads and writes interleave. Split the statement into two.

## 8. Critical algorithms you need to know

GDS procedure names are from the 2.x line. Names move between alpha, beta and product tiers across releases, so verify each against `SHOW PROCEDURES` and the release notes for your version. \[Likely\]

### 11.1 The safe GDS workflow (applies to every algorithm)

GDS (Graph Data Science) runs algorithms on an **in-memory projection**, not on the store. The projection lives on the JVM heap, not in the page cache. \[Certain\]

1. **Estimate**: `CALL gds.graph.project.estimate('User', 'FOLLOWS', {}) YIELD requiredMemory, nodeCount, relationshipCount`. Never project before you know the memory cost.
2. **Project**: `CALL gds.graph.project('social', 'User', {FOLLOWS: {orientation: 'UNDIRECTED'}})`. Project only the labels, types and properties the algorithm needs.
3. **Dry-run with `.stats`**: `CALL gds.pageRank.stats('social', {maxIterations: 20, dampingFactor: 0.85}) YIELD ranIterations, didConverge`. This verifies convergence without writing anything.
4. **Inspect with `.stream` plus `LIMIT`** on a sample before you commit to `.mutate` or `.write`.
5. **Persist results deliberately**: `.mutate` updates the projection for the next algorithm in a chain, `.write` writes back to the database.
6. **Drop**: `CALL gds.graph.drop('social')`. Leaked projections are a classic cause of heap exhaustion.

Safety rules for algorithm runs:

- &#91;Certain\] Run GDS on a dedicated analytics instance. A projection plus an algorithm can consume tens of GB of heap and all cores, and sharing a server with T1 traffic will evict its page cache and spike its latency.
- &#91;Guessing\] How write-back is routed in a cluster varies by version. The safest pattern is `.stream` the results and write them through your own batched writer to the primary, so you control batch size and retry behavior. Verify before relying on `.write` against a cluster.
- &#91;Likely\] Set `randomSeed` and `concurrency: 1` in tests, because Louvain, Leiden and Label Propagation are non-deterministic across runs with many threads.
- &#91;Certain\] Validate output before consumers read it: PageRank scores should sum to a stable total, community size distributions should not suddenly show one giant community, and similarity counts should stay inside the expected `topK` bound.
- &#91;Likely\] Version your results. Write to a run-stamped property (`pagerank_20261014`), and flip consumers to the new property through configuration only after validation. That gives you rollback.
- &#91;Likely\] GDS Community edition limits concurrency to 4, so at this scale you need the Enterprise license for any serious run.

### 11.2 Catalog: centrality (who matters)

| Algorithm | GDS procedure | Use it for | Scale note |
| --- | --- | --- | --- |
| Degree Centrality | `gds.degree` | Hub and supernode detection, bot screening | O(E). Cheapest, run it first. \[Certain\] |
| PageRank | `gds.pageRank` | Global importance, ranking, spam/trust seeds | O(iterations × E). The most scalable centrality. \[Certain\] |
| Personalized PageRank | `gds.pageRank` with `sourceNodes` | Recommendations and "what is relevant to this user" | Same cost, but run per seed set, so batch it. \[Likely\] |
| ArticleRank | `gds.articleRank` | PageRank variant that damps the influence of low-degree sources | Same cost as PageRank. |
| Eigenvector Centrality | `gds.eigenvector` | Importance by connection to important nodes | Can fail to converge on disconnected graphs. \[Likely\] |
| Betweenness Centrality | `gds.betweenness` | Brokers, bridges, single points of failure | Exact is O(V·E). Use `samplingSize` at scale. \[Certain\] |
| Closeness and Harmonic | `gds.closeness`, `gds.closeness.harmonic` | Spread speed, reach | Needs shortest paths from every node, so sample. \[Likely\] |
| HITS | `gds.hits` | Hub and authority scores on directed graphs | Iterative, O(iterations × E). \[Likely\] |
| CELF influence maximization | `gds.influenceMaximization.celf` | Choosing seed nodes for maximum spread | Expensive Monte-Carlo, alpha tier. \[Guessing on tier\] |

### 11.3 Catalog: structure and community (what groups exist)

| Algorithm | GDS procedure | Use it for | Scale note |
| --- | --- | --- | --- |
| Weakly Connected Components (WCC) | `gds.wcc` | First-pass fraud-ring candidates, graph fragmentation, giant-component check | Near-linear. **Hubs merge everything**, so filter shared identifiers with degree caps first. \[Certain\] |
| Strongly Connected Components (SCC) | `gds.scc` | Cycles in directed dependency graphs, mutual-trust groups | Linear. \[Certain\] |
| Leiden | `gds.leiden` | Community detection, preferred over Louvain | Guarantees well-connected communities, with similar cost to Louvain. \[Likely\] |
| Louvain | `gds.louvain` | Community detection and hierarchical communities | Can produce disconnected communities. \[Certain per the Leiden paper\] |
| Label Propagation | `gds.labelPropagation` | Very fast, rough communities | Non-deterministic and can oscillate. \[Certain\] |
| K-Core Decomposition | `gds.kcore` | Densest cores: coordinated fraud rings, resilient backbone | Linear. \[Likely\] |
| Triangle Count and Local Clustering Coefficient | `gds.triangleCount`, `gds.localClusteringCoefficient` | Spotting bot-like or too-perfect clusters, anomaly features | Cost grows with hub degree, so cap degrees. \[Likely\] |
| Conductance | `gds.conductance` | Scoring how isolated a community is (Sybil-like clusters have low conductance) | Needs communities as input. \[Likely\] |
| Modularity Optimization | `gds.modularityOptimization` | Alternative community detection | \[Likely\] |
| K-1 Coloring, Max k-Cut | `gds.k1coloring`, `gds.maxkcut` | Scheduling, partitioning experiments | Niche. \[Likely\] |
| Articulation Points and Bridges | `gds.articulationPoints`, `gds.bridges` | **Single points of failure** in infrastructure and supply graphs | Linear. \[Likely, verify availability\] |

### 11.4 Catalog: similarity and link prediction (what is alike or likely)

| Algorithm | GDS procedure | Use it for | Scale note |
| --- | --- | --- | --- |
| Node Similarity (Jaccard, Overlap, Cosine) | `gds.nodeSimilarity` | "Users who share neighbors" recommendations | Worst case O(n²). Always set `topK`, `similarityCutoff` and `degreeCutoff`. \[Certain\] |
| K-Nearest Neighbors | `gds.knn` | Similarity on properties or embeddings | Approximate (NN-Descent), so it scales much better. \[Likely\] |
| Topological link prediction | Adamic-Adar, Common Neighbors, Preferential Attachment, Resource Allocation, Same Community, Total Neighbors | Scoring a candidate edge `(a, b)` | Functions applied per pair, so you must generate candidates cheaply. Namespace varies by version. \[Guessing on namespace\] |
| Link prediction pipelines | `gds.beta.pipeline.linkPrediction.*` | Trained models with node features and embeddings | Training happens in memory, so budget heap. \[Likely\] |
| Node classification pipelines | `gds.beta.pipeline.nodeClassification.*` | Risk or label prediction | \[Likely\] |

### 11.5 Catalog: path finding and DAG algorithms (how things connect)

| Algorithm | GDS procedure | Use it for |
| --- | --- | --- |
| Breadth-First and Depth-First Search | `gds.bfs`, `gds.dfs` | Bounded reachability, blast radius |
| Dijkstra source-target, single-source | `gds.shortestPath.dijkstra`, `gds.allShortestPaths.dijkstra` | Weighted shortest paths, escalation paths |
| A\* | `gds.shortestPath.astar` | Spatial shortest paths |
| Yen's K-Shortest Paths | `gds.shortestPath.yens` | Top-K alternative attack or failure paths |
| Bellman-Ford | `gds.bellmanFord` | Negative weights, arbitrage-style cycles |
| Delta-Stepping | `gds.allShortestPaths.delta` | Parallel single-source shortest paths |
| Minimum Spanning Tree and Steiner Tree | `gds.spanningTree`, `gds.steinerTree` | Cheapest connecting backbone, network design |
| Random Walk | `gds.randomWalk` | Sampling, embedding training |
| Topological Sort and Longest Path (DAG) | `gds.dag.topologicalSort`, `gds.dag.longestPath` | Build and dependency ordering, **critical path** analysis |

&#91;Certain\] All-pairs shortest path (`gds.allShortestPaths.*` across every node) is not an option on a billion-node graph. Use single-source runs from a bounded seed set, or landmark approximations (section 11.7).

### 11.6 Catalog: embeddings (turning structure into vectors)

| Algorithm | GDS procedure | Why choose it |
| --- | --- | --- |
| FastRP | `gds.fastRP` | First choice at scale: fast, linear-time, no training. \[Certain\] |
| Node2Vec | `gds.node2vec` | Captures walk-based neighborhoods, heavier and slower. \[Likely\] |
| GraphSAGE | `gds.beta.graphSage` | **Inductive**, so new nodes get embeddings without retraining everything. \[Certain\] |
| HashGNN | `gds.hashgnn` | Fast binary embeddings. \[Likely\] |

Pair embeddings with a **vector index** or `gds.knn` for approximate nearest-neighbor search, which replaces many multi-hop similarity traversals. \[Likely\]

For algorithms GDS lacks, GDS exposes a **Pregel API** (`gds.pregel`) for writing custom bulk-synchronous message-passing algorithms in Java. \[Likely\]

### 11.7 Algorithms beyond GDS that you need at billion scale

These are what large systems use when exact in-memory graph algorithms stop fitting. \[Likely unless marked\]

| Family | Names to know | What they solve |
| --- | --- | --- |
| Probabilistic sketches | **HyperLogLog**, **Count-Min Sketch**, **Space-Saving / Misra-Gries**, **Bloom filter**, **Cuckoo filter**, **MinHash with LSH**, **HyperANF**, reservoir sampling | Distinct counts, frequency and degree estimates, heavy hitters (which nodes are becoming hubs), membership tests, near-duplicate detection without O(n²), neighborhood size and diameter estimates |
| Streaming graph partitioning | **LDG (Linear Deterministic Greedy)**, **Fennel**, **METIS** (offline), hash and consistent-hash partitioning, rendezvous hashing, Facebook's Social Hash Partitioner | Deciding which shard owns which node while minimizing cut edges |
| Distributed graph processing | **Pregel / BSP model**, Spark **GraphX** and **GraphFrames**, Apache Giraph, Flink Gelly | Algorithms on graphs that do not fit one machine's heap |
| Scalable connected components | Union-Find (disjoint set union), Hash-to-Min, Big-Star/Small-Star variants used in distributed engines | WCC at billions of edges, incremental connectivity as edges stream in |
| Reachability indexing | **Pruned Landmark Labeling (2-hop labeling)**, **GRAIL** and interval labeling for DAGs, landmark-based distance estimation (ALT), bidirectional BFS | "Is A connected to B?" answered in microseconds from an index |
| Sybil and trust propagation | SybilRank (random-walk based), TrustRank, personalized PageRank from trusted seeds | Detecting fake-account clusters |
| Dynamic graph updates | Incremental PageRank approximations, incremental Louvain, delta recompute | Avoiding a full recompute for each small change |

### 11.8 Problem to algorithm selection matrix

| Problem | First choice | Then | Danger to guard |
| --- | --- | --- | --- |
| Find the hubs and supernodes | `gds.degree` plus a heavy-hitter sketch in the stream | PageRank for importance | Run exact degree scans on an analytics replica only |
| Fraud ring detection | WCC on the shared-identifier subgraph (device, phone, address, card) **after** capping identifier degree | Leiden inside each component, k-core, triangle count, cycle detection for money loops | One shared public Wi-Fi device merges millions of accounts, so cap and whitelist |
| Recommendations | Personalized PageRank or Node Similarity with `topK` | FastRP plus KNN, GraphSAGE for new nodes | O(n²) similarity with no cutoffs |
| Privilege escalation and attack paths | Shortest path from an identity to a privileged role | Yen's K paths for alternatives, bounded BFS | Unbounded path expansion through group hubs |
| Single points of failure | Articulation points, bridges, sampled betweenness | Reverse reachability for dependents | Treating soft dependencies like hard ones |
| Dependency cycles | SCC | Cycle listing queries (section 12) | Cycles through shared platform nodes are noisy |
| Critical path and build order | Topological sort, longest path on the DAG | Slack calculation per node | Cycles make the graph a non-DAG, so run SCC first |
| Bot and Sybil clusters | Leiden plus conductance | SybilRank, local clustering coefficient | Legitimate communities such as universities also look dense |
| Entity resolution | MinHash or LSH blocking, then Node Similarity | WCC over high-confidence match edges | Transitive closure can chain unrelated entities, so cap component size |
| Anomaly detection | Degree z-score, local clustering, KNN distance on embeddings | Pipeline classifier | Concept drift, so retrain on a schedule |

### 11.9 What not to run at full scale

| Do not run | Because | Run instead |
| --- | --- | --- |
| Exact betweenness or closeness on the full graph | O(V·E) | Sampled versions on a projected subgraph |
| All-pairs shortest paths | Quadratic output | Bounded single-source from seed nodes, or landmark labeling |
| Node Similarity with no `topK` or cutoffs | Quadratic candidate pairs | Set `topK`, `similarityCutoff`, `degreeCutoff` |
| Whole-graph WCC without hub filtering | One giant meaningless component | Filter identifier hubs, run on a typed subgraph |
| Triangle count on a graph with million-degree hubs | Cost grows roughly with sum of squared degrees around hubs | Cap degree or sample |
| A projection larger than heap | OOM kills the analytics server | Run `.estimate`, project a subgraph, or move to Spark |

## 9. The formulas and procedures behind the critical algorithms

These are the numbers you need to size sketches, partitions and limiters before you build them. \[Certain unless marked, the math is standard\]

### 19.1 Sketch sizing

| Structure | Sizing formula | Worked example |
| --- | --- | --- |
| **Bloom filter** (membership, no false negatives) | bits `m = −n·ln(p) / (ln 2)²`, hash functions `k = (m/n)·ln 2` | 1 billion items at 1% false-positive rate needs about 9.6 bits per item, so **about 1.2 GB** and `k ≈ 7` |
| **HyperLogLog** (distinct count) | standard error `≈ 1.04 / √m` for `m` registers | `m = 16,384` gives about 0.81% error in roughly 12 KB per counter (the Redis default) |
| **Count-Min Sketch** (frequency, overestimates only) | width `w = ⌈e/ε⌉`, depth `d = ⌈ln(1/δ)⌉`; estimate is at most true count plus `ε·N` with probability at least `1−δ` | `ε = 0.0001`, `δ = 0.01` gives `w = 27,183`, `d = 5`, about 136,000 counters |
| **Space-Saving** (heavy hitters) | `k` counters guarantee that any item with frequency above `N/k` is tracked | To catch every node taking more than 0.1% of events, use `k = 1,000` |
| **MinHash with LSH banding** (similarity search) | `b` bands of `r` rows: two items with Jaccard similarity `s` collide with probability `1 − (1 − sʳ)ᵇ`; threshold is about `(1/b)^(1/r)` | `b = 20`, `r = 5` gives a threshold near 0.55 |
| **Reservoir sampling (Algorithm R)** | Keep the first `k` items, then for item `i` replace a random slot with probability `k/i` | Uniform sample of a stream of unknown length |

Use these in the stream layer to maintain degree estimates, flag emerging hubs, and block known-bad identifiers before a query ever reaches Neo4j. \[Likely\]

### 19.2 Partitioning and placement

- **Linear Deterministic Greedy (LDG)** \[Likely\]: place each arriving vertex `v` in the partition `i` that maximizes `|N(v) ∩ P_i| × (1 − |P_i| / C)`, where `N(v)` are its already-placed neighbors and `C` is partition capacity. It favors partitions holding more neighbors while penalizing full ones.
- **Fennel** \[Likely\]: maximize `|N(v) ∩ P_i| − αγ|P_i|^(γ−1)`, commonly with `γ = 1.5` and `α = √k · m / n^1.5` for `k` partitions, `n` vertices and `m` edges. It generally cuts fewer edges than LDG at similar balance.
- **Quality metrics to track** \[Certain\]: edge-cut ratio (fraction of edges crossing partitions) and balance (largest partition divided by the average, target 1.05 to 1.1). A low cut ratio with poor balance, or the reverse, are both failures.
- **Consistent hashing** \[Certain\]: use 100 to 256 virtual nodes per server for even load, so adding or removing a server moves about `1/N` of keys. **Bounded-load consistent hashing** caps any server at `(1 + ε)` times the average, which protects against hot keys. **Rendezvous hashing** gives similar behavior without a ring.
- &#91;Guessing\] Social-graph partitioners tend to be hierarchical (geography or community first, then hash), because pure hashing maximizes cut edges. Measure on your own data before deciding.

### 19.3 Incremental connectivity (union-find)

```
find(x):  while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]   // path compression
union(a, b): ra = find(a); rb = find(b)
             if ra != rb: attach the smaller-rank root under the larger        // union by rank
```

&#91;Certain\] With path compression and union by rank, each operation costs near-constant amortized time, which makes it suitable for streaming a billion edges. It **cannot handle edge deletions**, so the common production pattern is a daily incremental union-find for freshness plus a periodic full recompute (GDS WCC or Spark) to correct for deletions. Cap component size and alert when a component suddenly merges, since a giant merge usually means one shared identifier connected everything. \[Likely\]

### 19.4 Rate limiting and adaptive concurrency

```
GCRA (leaky-bucket-as-meter), emission interval T, burst tolerance tau:
  on request at time t:
    tat = max(tat, t)                    // theoretical arrival time
    if tat - t > tau: reject             // too early
    else: tat = tat + T; allow

AIMD adaptive concurrency limit (per server):
  on success within latency target: limit = limit + 1/limit
  on timeout, error, or latency above target: limit = limit * 0.9
  reject new work when inflight >= limit
```

&#91;Certain\] GCRA needs one timestamp per key, so it scales to millions of limited keys. \[Likely\] AIMD finds the safe concurrency limit without manual tuning and reacts when a server degrades. Combine with priority shedding so tier 3 is dropped first.

### 19.5 Algorithm run parameters that matter

- **PageRank** \[Likely\]: damping factor 0.85, tolerance around `1e-7`, and 20 to 100 iterations. Check `didConverge`, and handle dangling nodes (no outgoing edges) deliberately. Run on the undirected or directed projection that matches the meaning you want.
- **Leiden and Louvain** \[Likely\]: set `maxLevels`, `tolerance` and `randomSeed`, run several seeds, and compare modularity and community size distribution for stability before trusting any one run.
- **Node Similarity** \[Certain\]: always set `topK`, `similarityCutoff` and `degreeCutoff`, because uncapped runs are quadratic around hubs.
- **Betweenness** \[Certain\]: use `samplingSize`, a fixed `samplingSeed` for reproducibility, and compare the ranking against a second sample to estimate stability.
- **FastRP** \[Likely\]: embedding dimension 128 to 256 is a typical start, and iteration weights control how far structure propagates. Validate with a downstream metric (recall at K), not by inspection.

## 10. The critical query library

Every query here is classified by where it may run. **Admin** queries run against the system database or a specific server. **Replica** queries scan broadly and must run on an analytics secondary, never on a serving one. **Anchored** queries start from one indexed node and are safe for T1. Syntax is Neo4j 5.x Cypher, and items flagged need checking against your exact version. \[Likely\]

### 12.1 Cluster and database health (Admin, run continuously)

```cypher
// Server membership and health
SHOW SERVERS YIELD name, address, state, health, hosting;

// Databases that are not in their requested state
SHOW DATABASES YIELD name, address, role, writer, requestedStatus, currentStatus, statusMessage
WHERE currentStatus <> requestedStatus OR currentStatus <> 'online';

// Which server currently holds write leadership per database
SHOW DATABASES YIELD name, address, role, writer WHERE writer = true;
```

&#91;Likely\] Alert on any server with `health <> 'AVAILABLE'`, on any database with `currentStatus <> requestedStatus` for more than a few minutes, and on repeated changes of the writer (leader flapping means network or disk trouble).

### 12.2 Runaway and blocked transactions (Admin, run per server)

```cypher
// Long-running transactions, with who and what
SHOW TRANSACTIONS YIELD *
WHERE elapsedTime > duration('PT30S')
RETURN transactionId, username, currentQueryId, currentQuery, elapsedTime,
       status, allocatedBytes, pageHits, pageFaults, metaData
ORDER BY elapsedTime DESC;

// Transactions waiting on locks (the status string names the blocker)
SHOW TRANSACTIONS YIELD transactionId, status, currentQuery, elapsedTime
WHERE status STARTS WITH 'Blocked';

// Stop one
TERMINATE TRANSACTIONS 'neo4j-transaction-123';
```

&#91;Likely\] `SHOW TRANSACTIONS` is per server, so in a cluster you query each member. Tag every application transaction with `queryId`, `version`, `traceId` metadata so `metaData` tells you which code path produced the offender. \[Certain this is the single most useful operational practice\]

### 12.3 Schema health (Admin)

```cypher
// Any index not ONLINE (building, failed, or populating)
SHOW INDEXES YIELD name, type, state, populationPercent, entityType, labelsOrTypes, properties
WHERE state <> 'ONLINE';

// Constraint inventory (diff this against your migration repo)
SHOW CONSTRAINTS YIELD name, type, entityType, labelsOrTypes, properties;

// Unused indexes (candidates to drop, they cost write throughput and cache)
SHOW INDEXES YIELD name, readCount, lastRead WHERE readCount = 0;
```

&#91;Likely\] `readCount` and `lastRead` appear in recent 5.x releases, so verify against yours. A query that depends on an index must never be deployed before the index is `ONLINE`. \[Certain\]

### 12.4 Configuration drift audit (Admin)

```cypher
SHOW SETTINGS YIELD name, value
WHERE name IN ['server.memory.heap.max_size', 'server.memory.pagecache.size',
               'db.transaction.timeout', 'db.memory.transaction.max',
               'db.memory.transaction.total.max']
RETURN name, value;
```

Run it on every server and compare. Servers that differ unintentionally behave differently under load, and that is a classic cause of one-node incidents. \[Likely\]

### 12.5 Data integrity invariants (Replica only, partitioned by `hashBucket`)

These verify that the graph still matches your rules. Run each over one `hashBucket` range at a time so no scan is unbounded, and store results as metrics.

```cypher
// 1. Duplicate keys (only possible if the uniqueness constraint is missing)
MATCH (u:User)
WITH u.userId AS key, count(*) AS n
WHERE n > 1
RETURN key, n ORDER BY n DESC LIMIT 100;

// 2. Orphans
MATCH (o:Order)
WHERE o.hashBucket = $bucket
  AND NOT EXISTS { (o)<-[:PLACED]-(:User) }
RETURN o.orderId LIMIT 100;

// 3. Relationships connecting illegal endpoint types
MATCH (a)-[r:PLACED]->(b)
WHERE a.hashBucket = $bucket AND NOT (a:User AND b:Order)
RETURN elementId(r) LIMIT 100;

// 4. Self-loops where they are meaningless
MATCH (a:Account)-[r:TRANSFERRED_TO]->(a)
WHERE a.hashBucket = $bucket
RETURN elementId(r) LIMIT 100;

// 5. Reconciliation against the source of truth: compare per-bucket counts and a checksum
MATCH (u:User)
WITH u.hashBucket AS bucket, count(*) AS n, sum(u.version) AS versionSum
RETURN bucket, n, versionSum ORDER BY bucket;

// 6. Derived-data freshness, using a run marker written by each batch job
MATCH (run:DerivedRun)
WHERE run.completedAt < datetime() - duration('PT26H')
RETURN run.name, run.completedAt, run.rowCount;

// 7. Degree budget violations on materialized neighbor lists
MATCH (u:User)
WHERE u.hashBucket = $bucket
WITH u, COUNT { (u)-[:TOP_CONNECTION]->() } AS k
WHERE k > 200
RETURN u.userId, k LIMIT 100;
```

&#91;Certain\] Prefer **constraints over detective queries** wherever your edition allows. Uniqueness constraints exist in Community, while property existence and node key constraints are Enterprise features. Detective queries are the backstop, not the primary defense.

Supernode detection (Replica only, sampled or bucketed, or maintained as a property by the stream layer):

```cypher
MATCH (n:User)
WHERE n.hashBucket = $bucket
WITH n, COUNT { (n)--() } AS degree
WHERE degree > 100000
RETURN n.userId, degree ORDER BY degree DESC LIMIT 100;
```

&#91;Likely\] The better design keeps `degree` as a maintained property updated in batches, because a full-label scan to find hubs is itself expensive.

### 12.6 Security administration queries (Admin)

```cypher
SHOW CURRENT USER;
SHOW USERS YIELD user, roles, passwordChangeRequired, suspended, home;
SHOW ROLES WITH USERS;

// Everyone holding the admin role
SHOW USERS YIELD user, roles WHERE 'admin' IN roles RETURN user;

// Export all privileges as re-runnable commands: store this in git and diff it in CI
SHOW PRIVILEGES AS COMMANDS;
```

&#91;Certain\] **Treat privileges as code.** Export `SHOW PRIVILEGES AS COMMANDS` on a schedule, commit it, and alert on any unreviewed diff. Silent privilege drift is how read-only service accounts become write-capable.

Least-privilege role for a T1 serving principal (Enterprise fine-grained access control):

```cypher
CREATE ROLE t1_reader;
GRANT ACCESS ON DATABASE social TO t1_reader;
GRANT MATCH {userId, createdAt, displayName} ON GRAPH social NODES User TO t1_reader;
GRANT MATCH {*} ON GRAPH social RELATIONSHIPS FOLLOWS, TOP_CONNECTION TO t1_reader;
DENY READ {email, phone, ssn} ON GRAPH social NODES User TO t1_reader;
DENY WRITE ON GRAPH social TO t1_reader;
DENY EXECUTE PROCEDURE apoc.* ON DBMS TO t1_reader;
```

&#91;Likely\] `DENY` overrides `GRANT`, which is why it is the right tool for the fields that must never leave the database through a serving path. Tenant isolation inside one database can use property-based access control (`GRANT MATCH {*} ON GRAPH social FOR (n:User) WHERE n.tenantId = 'acme' TO acme_reader`), but \[Guessing\] it adds per-access evaluation cost, so measure it, and prefer database-per-tenant when isolation matters more than density. Immutable privileges (`IMMUTABLE` keyword, Enterprise) let you lock critical denies so they cannot be altered at runtime. \[Likely, verify\]

### 12.7 Authorization inside the query (Anchored, T1)

**Do not rely on the application alone to check access.** Put the authorization predicate in the same query so an object ID alone is never enough. This stops insecure direct object reference (IDOR) bugs. \[Certain\]

```cypher
MATCH (viewer:User {userId: $callerId})
MATCH (viewer)-[:MEMBER_OF|OWNS*1..3]->(:Group)-[:CAN_VIEW]->(doc:Document {docId: $docId})
RETURN doc.title, doc.body
LIMIT 1;
```

If this returns no row, the caller is denied and the application never learns whether the document exists. \[Certain\] **Fail closed**: a timeout or error on an authorization query must mean deny, never allow.

&#91;Certain\] **Revocation lag is a security bug.** A secondary applies the transaction log asynchronously, so a permission revoked on the primary can still look valid on a stale secondary. Authorization decisions for revocable rights must either use bookmarks (causal consistency), run on the leader, or use a short-TTL cache with event-driven invalidation.

### 12.8 Attack-path and exposure queries for an identity graph (Anchored or Replica)

Model: `(:Identity)-[:MEMBER_OF|HAS_ROLE|CAN_ASSUME]->(:Role)-[:CAN_READ|CAN_WRITE]->(:DataStore)`.

```cypher
// Shortest privilege-escalation path from one identity to a privileged role
MATCH (u:Identity {identityId: $id}), (target:Role {name: 'prod-admin'})
MATCH p = shortestPath((u)-[:MEMBER_OF|HAS_ROLE|CAN_ASSUME*..8]->(target))
RETURN [n IN nodes(p) | n.name] AS escalationPath;

// Who can reach a sensitive datastore (anchor on the datastore, walk inward)
MATCH (d:DataStore {name: $store, classification: 'PII'})
MATCH (d)<-[:CAN_READ]-(:Role)<-[:HAS_ROLE|CAN_ASSUME|MEMBER_OF*1..6]-(i:Identity)
RETURN count(DISTINCT i) AS identitiesWithAccess;

// Dormant privileged accounts
MATCH (i:Identity)-[:HAS_ROLE]->(r:Role {privileged: true})
WHERE i.lastLoginAt < datetime() - duration('P90D')
RETURN i.identityId, r.name, i.lastLoginAt;

// Separation-of-duties violation: one identity holding both sides of a control
MATCH (i:Identity)-[:HAS_ROLE]->(:Role {name: 'payments-initiator'}),
      (i)-[:HAS_ROLE]->(:Role {name: 'payments-approver'})
RETURN i.identityId;

// Cross-tenant leakage: edges whose endpoints belong to different tenants (bucketed)
MATCH (a)-[r]->(b)
WHERE a.hashBucket = $bucket AND a.tenantId <> b.tenantId
RETURN type(r) AS relType, count(*) AS crossTenantEdges
ORDER BY crossTenantEdges DESC;
```

&#91;Likely\] On Neo4j 5.21 and later, the `SHORTEST k` and `ANY` path syntax is the modern replacement for `shortestPath()`, and for ranked alternatives you can use Yen's algorithm in GDS. Always anchor and bound depth. Walking from the datastore inward is usually cheaper than from every identity outward, because the datastore anchor is the more selective end. \[Certain\]

### 12.9 Criticality and blast-radius queries (model your platform as a graph)

Model the platform itself in a small **meta-graph**: `(:Service {name, tier, owner})-[:DEPENDS_ON {kind: 'hard' | 'soft'}]->(:Component)`, `(:Service)-[:DEPLOYED_IN]->(:Cell)-[:IN]->(:AZ)`, `(:Service)-[:HAS_RUNBOOK]->(:Runbook)`, and `(:QueryVersion)-[:USES_PROPERTY]->(:Property)`. This is a different, small database, so it never competes with production.

```cypher
// Blast radius: everything that hard-depends (transitively) on a failing component
MATCH (x:Component {name: $name})
MATCH (dep:Service)-[:DEPENDS_ON*1..8 {kind: 'hard'}]->(x)
WITH DISTINCT dep
RETURN dep.name, dep.tier, dep.owner ORDER BY dep.tier, dep.name;

// Tier-0 services with a hard dependency that has no replica or standby
MATCH (s:Service {tier: 0})-[:DEPENDS_ON {kind: 'hard'}]->(d:Component)
WHERE NOT EXISTS { (d)-[:REPLICATED_BY]->() }
RETURN s.name, d.name;

// Dependency cycles (a cycle is a recovery deadlock waiting to happen)
MATCH p = (s:Service)-[:DEPENDS_ON*2..8]->(s)
RETURN [n IN nodes(p) | n.name] AS cycle LIMIT 20;

// Most depended-upon components (candidates for hardening and extra redundancy)
MATCH (d:Component)<-[:DEPENDS_ON]-(s:Service)
RETURN d.name, count(DISTINCT s) AS directDependents
ORDER BY directDependents DESC LIMIT 25;

// Tier-0 services concentrated in fewer than three availability zones
MATCH (s:Service {tier: 0})-[:DEPLOYED_IN]->(:Cell)-[:IN]->(az:AZ)
WITH s, count(DISTINCT az) AS azCount
WHERE azCount < 3
RETURN s.name, azCount;

// Tier-0 services without a runbook
MATCH (s:Service {tier: 0})
WHERE NOT EXISTS { (s)-[:HAS_RUNBOOK]->(:Runbook) }
RETURN s.name;

// Change impact: which active query versions break if a property changes
MATCH (q:QueryVersion {active: true})-[:USES_PROPERTY]->(:Property {label: 'User', name: $prop})
RETURN q.queryId, q.version, q.tier ORDER BY q.tier;
```

Pair these with the algorithms from section 11: articulation points and bridges for single points of failure, SCC for cycle groups, topological sort and longest path for recovery ordering and critical path. \[Likely\]

### 12.10 Fraud and abuse queries with hub guards

The defining rule: **never traverse through a high-degree identifier**. One shared public device can link millions of unrelated accounts and flood the query. \[Certain\]

```cypher
// T1, anchored: accounts sharing devices with this account (skip shared kiosks)
MATCH (a:Account {accountId: $id})-[:USED_DEVICE]->(d:Device)
WHERE COUNT { (d)<-[:USED_DEVICE]-() } <= 25
MATCH (d)<-[:USED_DEVICE]-(other:Account)
WHERE other <> a
RETURN other.accountId, count(DISTINCT d) AS sharedDevices, max(other.riskScore) AS maxRisk
ORDER BY sharedDevices DESC LIMIT 50;

// Velocity check: activity in the last hour (needs a relationship property index on ts)
MATCH (a:Account {accountId: $id})-[t:TRANSFERRED_TO]->(recipient)
WHERE t.ts >= datetime() - duration('PT1H')
RETURN count(t) AS txCount, sum(t.amount) AS totalAmount,
       count(DISTINCT recipient) AS distinctRecipients;

// Circular money flow, anchored and bounded; filter inside the pattern so it prunes early
MATCH (a:Account {accountId: $id})
      (()-[t:TRANSFERRED_TO WHERE t.ts >= $since AND t.amount >= $minAmount]->()){3,6}
      (a)
RETURN [r IN t | r.amount] AS amounts, size(t) AS hops
LIMIT 20;
```

&#91;Likely, verify\] The last query uses quantified path patterns (Neo4j 5.9 and later) so each hop is filtered as it expands. The older form (`[:TRANSFERRED_TO*3..6]` with an `all()` predicate on the path) filters after expansion and can explode. T2 batch detection (all accounts, not one anchor) belongs in GDS: WCC plus Leiden on the capped shared-identifier subgraph, not in Cypher.

### 12.11 The deny list: queries that must never reach production unguarded

| Pattern | Why it is dangerous | Defense |
| --- | --- | --- |
| `MATCH (n) DETACH DELETE n` | Wipes the database | Deny delete to app roles, separate admin credentials, immutable denies, backups with object lock |
| `MATCH (n) RETURN n` with no limit | Memory exhaustion, full export | Gateway rejects queries without `LIMIT`, server transaction timeout and memory caps |
| Disconnected `MATCH (a), (b)` | Cartesian product | CI check for `CartesianProduct` in the plan |
| Unbounded `[*]` paths | Combinatorial explosion | Static lint: bounds required |
| `SET n += $props` with a client-controlled map | **Mass assignment**: an attacker sets `isAdmin` or `tenantId` | Whitelist keys in the application, never pass raw maps |
| String-built labels, types or values | Cypher injection | Parameters only, allow-list for dynamic names |
| `LOAD CSV` from a user-influenced URL | Server-side request forgery and file reads | Disable file URLs (`dbms.security.allow_csv_import_from_file_urls=false`), restrict the import directory |
| `apoc.load.*`, `apoc.export.*`, `apoc.cypher.run*` | Exfiltration, SSRF, injection | Keep out of `dbms.security.procedures.allowlist`, leave file import and export flags off |
| `CALL dbms.*` admin procedures, `DROP DATABASE`, `DROP INDEX`, `DROP CONSTRAINT` | Outage or privilege escalation | Only a migration role, with approval and audit |
| `DETACH DELETE` on a node with millions of relationships | One giant transaction, memory blow-up | Delete relationships in batches (`CALL (r) { DELETE r } IN TRANSACTIONS OF 10000 ROWS`), then the node |
| Client-supplied internal IDs | IDOR | Authorization predicate inside the query (section 12.7) |
| Huge `SKIP` and unbounded `collect()` | Read-and-discard cost, memory | Keyset pagination, capped collection |

# Part 3. Changing queries and schema safely

Queries and models outlive the people who wrote them. This part covers versioning, migration, backfills and upgrades, so changes ship without breaking callers or corrupting data.

## 12. Migration, write-safety and diagnostic queries (a second critical query library)

### 18.1 Migration and backfill

```cypher
// Resumable, keyset-paged backfill. The application loops, storing nextKey as a checkpoint.
MATCH (u:User)
WHERE u.userId > $lastKey AND u.emailLower IS NULL
WITH u ORDER BY u.userId LIMIT $batchSize
SET u.emailLower = toLower(u.email)
RETURN max(u.userId) AS nextKey, count(*) AS updated;

// Verification per bucket: do not trust "the job finished"
MATCH (u:User) WHERE u.hashBucket = $bucket
RETURN count(*) AS total, count(u.emailLower) AS migrated,
       count(*) - count(u.emailLower) AS remaining;

// Dual-write consistency: old structure versus new structure
MATCH (a:User) WHERE a.hashBucket = $bucket
RETURN sum(COUNT { (a)-[:RELATED_TO {kind: 'follows'}]->() }) AS oldCount,
       sum(COUNT { (a)-[:FOLLOWS]->() }) AS newCount;

// Contract phase: delete the old structure in batches (implicit transaction required)
MATCH ()-[r:RELATED_TO {kind: 'follows'}]->()
CALL (r) { DELETE r } IN TRANSACTIONS OF 10000 ROWS;
```

&#91;Likely\] `CALL (r) { ... }` needs Neo4j 5.23 or later. On older 5.x use `CALL { WITH r DELETE r }`. The backfill's `WHERE u.userId > $lastKey` is an index range seek only if `userId` has a constraint or index, which is why every key needs one. Throttle the loop, watch page cache hit ratio and replica lag during it, and pause automatically when lag exceeds your freshness SLO. \[Certain\]

### 18.2 Write-path safety patterns

```cypher
// Idempotent, order-safe upsert: stale or replayed events cannot overwrite newer state
UNWIND $events AS e
MERGE (u:User {userId: e.userId})
  ON CREATE SET u.version = -1
WITH u, e
WHERE e.version > u.version
SET u.displayName = e.displayName,
    u.version     = e.version,
    u.updatedAt   = datetime();
```

&#91;Certain\] Version comparison makes duplicate delivery and out-of-order delivery harmless, which is the property a Kafka-fed writer needs. Rows filtered out by `WHERE` do no writes. Pair it with application checks that the summary counters make sense for the batch.

Other critical write patterns \[Likely\]:

- **Soft delete**: set `deletedAt` and exclude it in queries (or move to a `:Deleted` label), then hard delete in a delayed batch job. This gives you a recovery window and avoids giant delete transactions.
- **Two-phase relationship creation**: nodes first, relationships second, so a missing endpoint is visible rather than hidden by `MERGE` creating a stray node.
- **Dead-letter**: any event that fails validation goes to a dead-letter topic with the reason, and never blocks the partition.

### 18.3 Diagnostics and drift detection (Admin or Replica)

```cypher
// Version and edition
CALL dbms.components() YIELD name, versions, edition RETURN name, versions, edition;

// Who is connected, from where, with which driver
CALL dbms.listConnections() YIELD connectionId, connector, username, userAgent, clientAddress, connectTime
RETURN * ORDER BY connectTime;

// What the drivers will route to (verify routing is distributing correctly)
CALL dbms.routing.getRoutingTable({}, 'social') YIELD ttl, servers RETURN ttl, servers;

// Admin-level procedures present (audit against your allow-list)
SHOW PROCEDURES YIELD name, admin WHERE admin = true RETURN name;

// Fast counts from the count store (do not scan)
MATCH (n:User) RETURN count(n);
MATCH ()-[r:FOLLOWS]->() RETURN count(r);

// Mixed property types: the index-killer. This scans data, so run it on an analytics replica.
CALL db.schema.nodeTypeProperties()
YIELD nodeType, propertyName, propertyTypes
WHERE propertyTypes IS NOT NULL AND size(propertyTypes) > 1
RETURN nodeType, propertyName, propertyTypes;
```

&#91;Likely\] Label and relationship-type counts come from the count store and are fast, while `db.schema.*` procedures scan and are not. `dbms.routing.getRoutingTable` and `dbms.listConnections` exist in 5.x, but confirm availability and signatures in your version, and run `SHOW PROCEDURES` to see what you have. Compare routing output across servers in a cluster, because a server that routes differently from its peers is a misconfiguration signal.

### 18.4 Triage sequence for "the database is slow"

1. `SHOW SERVERS` and `SHOW DATABASES` (section 12.1): is anything unhealthy or in the wrong state?
2. `SHOW TRANSACTIONS` on each server (section 12.2): is one query or principal dominating, or is something blocked on locks?
3. Check page cache hit ratio, GC pauses and disk latency in metrics: is it the machine or the query?
4. Look up the offender's `queryId` and version from transaction metadata, flip its kill switch or rate limit if needed.
5. Reproduce with the exact parameters on a staging restore, `PROFILE`, fix, and add the case to the worst-case anchor tests. \[Certain\]

## 13. Versions, language and upgrade policy

- &#91;Likely\] Neo4j moved from semantic 5.x versions to calendar versioning (2025.x and later). Features discussed in this document were introduced at specific releases, so build a **feature-to-version table** for your own fleet and check it in CI.
- &#91;Likely\] Recent releases introduced a second Cypher language version (Cypher 25) alongside Cypher 5. You can pin a language version per query with a `CYPHER 5` or `CYPHER 25` prefix and set a database default. Pin explicitly in the query registry, and migrate query by query with differential tests, never by flipping a global default.
- &#91;Certain\] Treat every upgrade as a project: read the release notes and deprecation list, run the full query suite with its db-hits budgets and plan baselines on the target version with production-size data, rehearse the store migration, and keep a rollback path (a restorable backup and a rolled-back binary that can read the pre-upgrade store).
- &#91;Certain\] Upgrade order for a cluster: secondaries first, then primaries one at a time, with a health and lag check between each server.
- &#91;Certain\] Never upgrade the server, GDS and APOC in the same step. Change one, verify, then change the next, and keep them on mutually compatible versions.

# Part 4. Deploying, running and scaling in production

**Uncomfortable truth first:** every number in this part is a starting point for your own load tests, not a recommendation to copy. \[Certain\] A configuration that is right for a 512 GB serving node with a 300 GB hot set is wrong for an analytics node, and copying it blindly is how teams create their first outage. Config names are Neo4j 5.x and must be checked against `SHOW SETTINGS` and the configuration reference for your version.

## 14. Memory: the real scaling lever

### 14.1 Page cache math \[Likely, verify with your store\]

Hot working set = the part of the store touched by your T1 queries in a typical hour, not the total store size.

1. Enable page cache metrics and measure `page_cache.hit_ratio` and `page_cache.page_faults` under real load.
2. Run `neo4j-admin server memory-recommendation` for the starting split.
3. Estimate the hot set: sample query logs for the touched node IDs, and compute `distinct nodes touched × (node + avg rels + props)`.
4. Provision page cache at 1.2-1.5× the hot set. Headroom absorbs bursts. \[Guessing on the multiplier\]

**Rule of thumb for decisions** \[Likely\]: hit ratio above 99% means you're fine, 95-98% means latency tails are being driven by faults, and below 95% means T1 SLOs are unlikely to hold regardless of anything else.

### 14.2 Heap vs page cache

- &#91;Certain\] Page cache holds the store files. Heap holds query execution state (rows, sorts, aggregations, plan cache).
- &#91;Likely\] Heap beyond about 31 GB loses compressed object pointers and rarely helps. If you need more heap, your queries are materializing too much, and the fix is in the query.
- &#91;Certain\] Transaction memory caps (`db.memory.transaction.max`, `db.memory.transaction.total.max`) are your protection against one query consuming the heap. Set them below heap size.

### 14.3 Cache warmup

- &#91;Likely\] Enterprise supports page cache warmup on restart (`db.memory.pagecache.warmup.enable`, which reloads previously hot pages). Verify the exact setting names for your version.
- For new secondaries, replay a captured sample of production reads against them before they receive traffic. \[Certain\] This matters more at TB scale because a cold cache can mean hours of degraded latency.

## 15. Read scaling in depth

### 15.1 Secondaries and workload isolation

- &#91;Certain\] Secondaries replicate by applying the primary's transaction log asynchronously. They add read capacity, not write capacity.
- Create **server groups/tags** by workload (`serving`, `analytics`, `backup`, `batch`) and route each application to its own group. \[Likely\] Never let analytics share a page cache with T1, because one big scan evicts your hot set.
- Replica count rule: size N so that **losing one secondary still meets peak load**. That is N+1 sizing, and at TB scale, losing one also means a long rebuild, so consider N+2. \[Likely\]

### 15.2 Consistency without killing performance

- &#91;Certain\] Reads on secondaries may be stale. Use **bookmarks** (causal consistency) only on the paths that need read-your-writes, such as "I just created this relationship and the next page must show it." A bookmark forces the secondary to wait until it has applied that transaction, which adds latency if replication is lagging.
- &#91;Likely\] For everything else, accept bounded staleness, and monitor replication lag against a stated freshness SLO per query class.
- Never route all reads through bookmarks "to be safe". That couples your read latency to your write burst behavior. \[Certain\]

### 15.3 Caching layers (cheaper than any Neo4j scaling)

Order of effectiveness for graph workloads \[Likely\]:

1. **Application result cache** (Redis/Memcached) for T1 queries, keyed by `queryId:version:paramsHash`. Short TTLs (seconds to minutes) already remove most hub-driven repeat load.
2. **Precomputed neighbor lists** (materialized `TOP_CONNECTION`, `SIMILAR_TO`) so the live query touches bounded data.
3. **Request coalescing**: if 5,000 requests ask for the same celebrity's profile expansion in one second, run it once and share the result (singleflight pattern). \[Certain this prevents thundering herds\]
4. **Negative caching** for "no result" answers, since otherwise cold or fraud-probe lookups bypass the cache entirely. \[Likely\]
5. **Cache invalidation by event**: the stream writer publishes the entity key to an invalidation topic when it changes the graph. \[Likely\]

Target \[Guessing\]: cache hit rates of 80-95% on T1 mean the database serves a fraction of the traffic. Measure your real distribution before assuming.

### 15.4 Hot-key (hub) protection

The most common cause of a billion-scale outage is one very popular node.

- &#91;Certain\] Per-key rate limiting at the gateway: cap requests per anchor key per second.
- &#91;Likely\] Degree-aware routing: look up the node's degree (kept as a property, maintained in batch) and route high-degree anchors to a precomputed or sampled path instead of live traversal.
- &#91;Likely\] Serve hubs from a dedicated cache tier with background refresh (stale-while-revalidate), so the hub never hits the database on the request path.
- &#91;Certain\] Hard row and time budgets per query so a surprise hub is truncated, not catastrophic.

## 16. Write scaling in depth

**Uncomfortable truth:** if your sustained write rate per logical database exceeds what one leader can commit, the only real answers are fewer writes, bigger batches, or more databases. \[Certain\]

### 16.1 Reduce write volume first

- &#91;Likely\] Pre-aggregate in the stream layer. A million "viewed" events become a single `VIEW_COUNT` update per entity per minute.
- Move high-frequency scalars (counters, last-seen, scores) to Redis, Cassandra/Scylla, or a column store, and sync to the graph in periodic batches. \[Likely\]
- Write only edges that queries will traverse. Events nobody traverses belong in the event store. \[Certain\]
- Collapse duplicates: if the same relationship is asserted 50 times, dedupe in the stream processor before it reaches Neo4j. \[Certain\]

### 16.2 Batch and partition correctly

- &#91;Certain\] Batch size is a tuning variable. Too small wastes commit overhead, and too large raises lock hold times and memory. Start at 2,000-5,000 operations per transaction and benchmark with your payloads.
- **Partition writers by node key** \[Certain\]: a hash of the primary entity ID routes all writes for a node to one writer. This reduces lock conflicts and deadlocks. For relationships touching two nodes, partition by the lower-degree endpoint, since that avoids locking the hub from many writers.
- **Hub writes are special** \[Likely\]: every new `FOLLOWS` edge to a celebrity locks that celebrity node (and its relationship chain). With the bucketed model, write to the bucket node instead, so contention spreads across N buckets.
- **Parallelism ceiling**: more writer threads helps only until lock contention or the leader's commit pipeline saturates. Find the knee by load testing, then stay below it. \[Certain\]

### 16.3 Multiple databases as the write-scaling mechanism

- &#91;Certain\] Each database has its own leader and transaction log. Splitting by domain (social, commerce, fraud) gives you independent write capacity, backups, and failure domains.
- &#91;Likely\] Servers can host many databases, with leaders distributed across servers so write load spreads. Check the allocation and server-role behavior in your version.
- **Cost** \[Certain\]: no cross-database transactions, and cross-database reads go through composite databases and execute in a coordination layer that doesn't traverse relationships across the boundary. Design so cross-database queries are rare and bounded.

### 16.4 Sharding approaches and their limits

| Approach | Scales | Doesn't scale | Notes |
| --- | --- | --- | --- |
| **Domain databases** | Writes, backup, failure isolation | Cross-domain traversals | Easiest. Do this first. \[Likely\] |
| **Composite database (federation)** | Unified querying over shards | Joins across shards; efficiency is limited | Fine for aggregation across regions or tenants. \[Likely\] |
| **Tenant sharding** (one DB per tenant or tenant group) | Multi-tenant B2B, noisy-neighbor isolation | Cross-tenant analytics | Strong fit if the graph is naturally partitioned. |
| **Property sharding** \[Guessing on maturity; check current release notes and edition support\] | Property-heavy data volume | Doesn't fix topology-bound traversal cost | Separates property storage from topology so the graph shard stays smaller. |
| **Application-level graph partitioning** (e.g. by community or geography) | Everything, if cut quality is good | Edges crossing partitions | Needs a partitioning algorithm (Louvain, METIS-style) and a plan for border nodes. \[Likely\] |

**Cut quality decides everything** \[Certain\]: if 30% of edges cross shards, 30%+ of multi-hop queries become distributed. Measure the cross-partition edge ratio on a real sample before choosing a shard key. A graph with no natural cut (a general social network) will punish any sharding scheme, which is why large social graphs use a purpose-built edge store for the online path.

## 17. Cluster topology at scale

### 17.1 Reference topologies \[Likely\]

**Single-region baseline**

- 3 primaries across 3 AZs per database, with 5 for stricter fault tolerance at slightly higher commit latency.
- Secondaries in groups: `serving` (N), `analytics` (M), `backup` (1-2).
- Gateway with query registry in front of everything.

**Multi-region**

- &#91;Likely\] One cluster per region. Cross-region replication happens through your stream layer (Kafka MirrorMaker / cluster linking) with idempotent writers, not by stretching a Raft group.
- Decide per entity: **single-writer region** (simple, no conflicts, cross-region write latency for remote users) or **multi-writer** (needs conflict resolution such as last-writer-wins with versions, or CRDT-style relationship semantics, and risks divergence). \[Certain this decision must be explicit\]
- Region-local reads, with global queries pushed to the analytics tier.

### 17.2 Growth runway planning

- &#91;Certain\] Build a capacity model: `nodes(t)`, `relationships(t)`, `bytes per element`, `hot set fraction`, `write rate`, `read QPS`. Project 6, 12, and 24 months, and trigger purchasing or re-architecture from thresholds, not incidents.
- Re-architecture lead time (sharding, model changes) is typically many months, so the trigger must fire at about 50% of capacity, not 90%. \[Likely\]

## 18. Reference configuration

### 22.1 `neo4j.conf` for a serving server (illustrative, 512 GB RAM, NVMe)

```
# ---- memory (heap + page cache + OS headroom must stay below physical RAM) ----
server.memory.heap.initial_size=31g
server.memory.heap.max_size=31g
server.memory.pagecache.size=360g
db.memory.transaction.max=2g
dbms.memory.transaction.total.max=40g

# ---- limits that bound the damage of one bad query ----
db.transaction.timeout=30s
db.lock.acquisition.timeout=10s
db.transaction.concurrent.maximum=1000
server.bolt.thread_pool_min_size=50
server.bolt.thread_pool_max_size=400

# ---- storage and transaction logs on separate devices ----
server.directories.data=/data
server.directories.transaction.logs.root=/txlogs
db.tx_log.rotation.size=256M
db.tx_log.rotation.retention_policy=2 days
db.checkpoint.interval.time=15m

# ---- network and security ----
server.bolt.tls_level=REQUIRED
dbms.ssl.policy.bolt.enabled=true
dbms.ssl.policy.bolt.base_directory=certificates/bolt
dbms.ssl.policy.cluster.enabled=true
dbms.ssl.policy.cluster.base_directory=certificates/cluster
dbms.ssl.policy.cluster.client_auth=REQUIRE
dbms.security.procedures.allowlist=apoc.coll.*,apoc.text.*
dbms.security.allow_csv_import_from_file_urls=false
dbms.cypher.forbid_exhaustive_shortestpath=true

# ---- observability ----
server.metrics.enabled=true
server.metrics.prometheus.enabled=true
server.metrics.prometheus.endpoint=0.0.0.0:2004
db.logs.query.enabled=INFO
db.logs.query.threshold=500ms
db.logs.query.parameter_logging_enabled=false
db.logs.query.allocation_logging_enabled=true
db.logs.query.page_logging_enabled=true

# ---- JVM ----
server.jvm.additional=-XX:+UseG1GC
server.jvm.additional=-XX:+AlwaysPreTouch
server.jvm.additional=-XX:+ExitOnOutOfMemoryError
server.jvm.additional=-XX:+HeapDumpOnOutOfMemoryError
server.jvm.additional=-XX:HeapDumpPath=/dumps
server.jvm.additional=-Xlog:gc*,safepoint:file=/logs/gc.log:time,uptime:filecount=5,filesize=20m
```

Why each group exists \[Likely\]:

- **Memory**: 31 GB heap stays under the compressed-pointer limit, and 360 GB of page cache leaves roughly 100 GB for the OS, native memory and burst. Run `neo4j-admin server memory-recommendation` on the real machine and treat its output as the baseline. \[Guessing on the exact split for your workload\]
- **`-XX:+ExitOnOutOfMemoryError`** makes a heap-exhausted server die and restart cleanly instead of limping with corrupted state, so it only makes sense behind a supervisor that restarts it and a cluster that tolerates the loss.
- **`-XX:+AlwaysPreTouch`** commits heap at startup so you pay page faults at boot, not during traffic.
- **Transaction limits** turn a runaway query into one failed request instead of a cluster-wide stall.
- **Cluster TLS with `client_auth=REQUIRE`** gives mutual authentication between members.
- **`db.format=block`** (Enterprise, newer 5.x and 2025.x releases) is a newer storage format aimed at better locality for large graphs. \[Guessing on availability and migration path\] Test it on a copy of your data before choosing it for new databases, and verify what the release notes say about format migration.

An **analytics server** differs: a large heap sized to the GDS projection (check with `gds.graph.project.estimate`), a smaller page cache, more cores, no latency SLO, and a separate server group so it never shares cache with serving. \[Certain\]

### 22.2 Linux host tuning (starting values, verify against the Neo4j operations manual)

```
# /etc/sysctl.d/99-neo4j.conf
vm.swappiness=1
vm.dirty_background_ratio=50
vm.dirty_ratio=80
vm.max_map_count=262144
net.core.somaxconn=4096
fs.file-max=2097152

# transparent huge pages off, at boot
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# open file limit for the neo4j user (systemd: LimitNOFILE=100000)
ulimit -n 100000
```

- &#91;Likely\] The dirty-page ratios let the page cache absorb write bursts before flushing. Neo4j manages its own checkpoints, so the right values depend on your disks, and you should test them rather than trust any single number.
- &#91;Certain\] Disable swap or set `vm.swappiness=1`, because a swapped page-cache or heap page produces multi-second pauses.
- &#91;Likely\] Use XFS or ext4 with `noatime`, a low-overhead I/O scheduler for NVMe (`none` or `mq-deadline`), and keep data and transaction logs on separate devices so log fsync latency is isolated from store reads.
- &#91;Certain\] Run NTP or chrony and alert on offset, since Raft and log correlation both depend on reasonable clocks.

### 22.3 Kubernetes StatefulSet (illustrative skeleton)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: neo4j-serving
spec:
  serviceName: neo4j-serving
  replicas: 3
  podManagementPolicy: Parallel
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels: {app: neo4j, group: serving}
  template:
    metadata:
      labels: {app: neo4j, group: serving}
    spec:
      terminationGracePeriodSeconds: 600
      securityContext: {runAsNonRoot: true, runAsUser: 7474, fsGroup: 7474}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector: {matchLabels: {app: neo4j}}
            topologyKey: kubernetes.io/hostname
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector: {matchLabels: {app: neo4j, group: serving}}
      containers:
      - name: neo4j
        image: neo4j:PINNED-ENTERPRISE-VERSION
        resources:
          requests: {cpu: 24, memory: 480Gi}
          limits:   {cpu: 24, memory: 480Gi}
        ports:
        - {name: bolt, containerPort: 7687}
        - {name: cluster, containerPort: 6000}
        - {name: raft, containerPort: 7000}
        - {name: metrics, containerPort: 2004}
        startupProbe:
          tcpSocket: {port: 7687}
          periodSeconds: 30
          failureThreshold: 240
        readinessProbe:
          tcpSocket: {port: 7687}
          periodSeconds: 10
        volumeMounts:
        - {name: data, mountPath: /data}
        - {name: txlogs, mountPath: /txlogs}
  volumeClaimTemplates:
  - metadata: {name: data}
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: local-nvme
      resources: {requests: {storage: 8Ti}}
  - metadata: {name: txlogs}
    spec:
      accessModes: [ReadWriteOnce]
      storageClassName: local-nvme
      resources: {requests: {storage: 1Ti}}
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: neo4j-serving
spec:
  maxUnavailable: 1
  selector:
    matchLabels: {app: neo4j, group: serving}
```

The decisions embedded in that skeleton \[Certain unless marked\]:

- **requests equal limits** gives Guaranteed QoS, so the kernel's OOM killer does not pick the database, and CPU is not throttled by neighbors.
- **A very long `startupProbe`** (here 240 probes at 30 s, so up to 2 hours) prevents Kubernetes from killing a server that is legitimately running crash recovery or a store migration. Readiness is separate and stays short.
- **`maxUnavailable: 1`** plus zone spread means a node drain can never take quorum. \[Certain\] For a primaries group of 3, one unavailable is the maximum you can afford.
- **Local NVMe** persistent volumes give the random-read latency page-cache misses need. If you must use network volumes, measure p99 read latency under load, because it sets your cache-miss penalty. \[Likely\]
- **Separate `data` and `txlogs` volumes** isolate store reads from log fsync.
- **Do not use a horizontal autoscaler on primaries.** Scale secondaries through a controlled procedure (section 22.4) and warm the cache before routing traffic.
- The official Neo4j Helm charts are a better base than hand-written manifests for cluster formation, and you should compare this skeleton with the chart's values before adopting either. \[Likely\]

### 22.4 Cluster and server lifecycle commands (Neo4j 5.x Enterprise)

```cypher
// Create a database with an explicit topology
CREATE DATABASE social TOPOLOGY 3 PRIMARIES 4 SECONDARIES;

// Scale read capacity without touching write capacity
ALTER DATABASE social SET TOPOLOGY 3 PRIMARIES 6 SECONDARIES;

// Make a newly joined server usable (new servers start as free)
ENABLE SERVER 'server-id';

// Constrain a server to secondaries only (analytics or serving read replicas)
ALTER SERVER 'server-id' SET OPTIONS {modeConstraint: 'SECONDARY'};

// Decommission safely: stop new allocations, move databases off, then remove
DEALLOCATE DATABASES FROM SERVER 'server-id';
DROP SERVER 'server-id';

// Rebalance database hosting across servers (review the proposal before applying)
SHOW SERVERS;
REALLOCATE DATABASES DRYRUN;
```

&#91;Likely\] These commands exist in Neo4j 5.x Enterprise with this general shape, but option names (such as server tags and allowed or denied databases) vary, so confirm each against the Cypher manual for your version before running it in production. Always run the dry-run forms first, and never deallocate a server that hosts a primary without confirming that remaining primaries still form a quorum. \[Certain\]

## 19. Implementation skeletons (Python, official `neo4j` driver 5.x)

These are structural skeletons that show where each control lives. They are **not production code**: they omit authentication wiring, TLS configuration, metrics instrumentation and most error taxonomy. \[Certain\] Check driver signatures against the version you install, and write tests for every branch before you depend on any of it.

### 24.1 Query registry entry

Each query lives in its own folder with a manifest next to the `.cypher` file, as described in section 1.4 of Part I.

```yaml
id: recs.peer_products
version: 3
tier: 1
database: social
access: read
timeout_ms: 100
max_rows: 50
params: {userId: string, limit: int}
cypher_file: v3.cypher
owner: recs-team
```

### 24.2 Query gateway with kill switch, rate limit, circuit breaker and tagging

```python
import time, threading
from neo4j import GraphDatabase, unit_of_work, READ_ACCESS
from neo4j.exceptions import TransientError, ServiceUnavailable

class QueryDisabled(Exception): pass
class RateLimited(Exception): pass
class CircuitOpen(Exception): pass
class RowBudgetExceeded(Exception): pass

class CircuitBreaker:
    def __init__(self, fail_threshold=20, window_s=10.0, open_s=15.0):
        self.fail_threshold, self.window_s, self.open_s = fail_threshold, window_s, open_s
        self.failures, self.window_start, self.opened_at = 0, time.monotonic(), 0.0
        self.lock = threading.Lock()

    def allow(self):
        with self.lock:
            if self.opened_at and time.monotonic() - self.opened_at < self.open_s:
                return False
            self.opened_at = 0.0          # closed, or half-open: let a probe through
            return True

    def record(self, ok):
        with self.lock:
            now = time.monotonic()
            if now - self.window_start > self.window_s:
                self.failures, self.window_start = 0, now
            if not ok:
                self.failures += 1
                if self.failures >= self.fail_threshold:
                    self.opened_at = now

class QueryGateway:
    def __init__(self, uri, auth, registry, flags, limiter):
        self.driver = GraphDatabase.driver(
            uri, auth=auth,
            max_connection_pool_size=200,
            connection_acquisition_timeout=2.0)       # fail fast instead of queueing forever
        self.registry, self.flags, self.limiter = registry, flags, limiter
        self.breakers = {}

    def run(self, query_id, params, trace_id):
        q = self.registry.active(query_id)             # id -> active version, cypher, tier, limits
        if self.flags.killed(query_id):
            raise QueryDisabled(query_id)
        if not self.limiter.allow(query_id, params):   # per query class and per anchor key
            raise RateLimited(query_id)
        breaker = self.breakers.setdefault(query_id, CircuitBreaker())
        if not breaker.allow():
            raise CircuitOpen(query_id)

        meta = {'queryId': query_id, 'version': q.version, 'traceId': trace_id}

        @unit_of_work(timeout=q.timeout_ms / 1000.0, metadata=meta)
        def work(tx):
            rows = []
            for record in tx.run(q.cypher, params):
                rows.append(record.data())
                if len(rows) > q.max_rows:
                    raise RowBudgetExceeded(query_id)
            return rows

        try:
            with self.driver.session(database=q.database, default_access_mode=READ_ACCESS) as s:
                rows = s.execute_read(work)
            breaker.record(True)
            return rows
        except (TransientError, ServiceUnavailable):
            breaker.record(False)
            raise

    def authorize(self, caller_id, doc_id, trace_id):
        # Tier 0: any error or timeout is a DENY (fail closed)
        try:
            rows = self.run('authz.can_view_document', {'callerId': caller_id, 'docId': doc_id}, trace_id)
            return len(rows) == 1
        except Exception:
            return False
```

What each part enforces \[Certain\]: tagging gives you the `queryId` in `SHOW TRANSACTIONS` and the query log, the timeout is enforced server side through the transaction, the row budget stops a result that grew past its contract, the kill switch needs no deploy, and `authorize` fails closed. \[Likely\] Add a retry budget (a shared token bucket that caps retries at a small percentage of traffic) around `run` for tier 1 reads, and never retry non-idempotent writes outside the driver's managed transaction.

### 24.3 Idempotent stream writer with ordered locking and poison-event isolation

```python
from confluent_kafka import Consumer

UPSERT = '''
UNWIND $events AS e
MERGE (u:User {userId: e.userId})
  ON CREATE SET u.version = -1
WITH u, e
WHERE e.version > u.version
SET u.displayName = e.displayName, u.version = e.version, u.updatedAt = datetime()
'''

def write_batch(driver, events):
    events = sorted(events, key=lambda e: e['userId'])      # same lock order for every writer
    with driver.session(database='social') as s:
        s.execute_write(lambda tx: tx.run(UPSERT, events=events).consume())

def write_with_bisect(driver, events, dead_letter):
    try:
        write_batch(driver, events)
    except Exception as err:
        if len(events) == 1:
            dead_letter(events[0], str(err))                # isolated the poison event
        else:
            mid = len(events) // 2
            write_with_bisect(driver, events[:mid], dead_letter)
            write_with_bisect(driver, events[mid:], dead_letter)

def run_writer(consumer: Consumer, driver, decode, dead_letter, batch_size=2000, poll_s=0.5):
    consumer.subscribe(['graph.user.events'])               # keyed by userId: one worker owns each key
    buf = []
    while True:
        msg = consumer.poll(poll_s)
        if msg is not None and not msg.error():
            buf.append(msg)
        if buf and (len(buf) >= batch_size or msg is None):
            write_with_bisect(driver, [decode(m) for m in buf], dead_letter)
            consumer.commit(asynchronous=False)             # offsets only after the graph commit
            buf = []
```

Properties this skeleton relies on \[Certain\]: the consumer is configured with `enable.auto.commit=false`, the version guard in `UPSERT` makes replays and reordering harmless, sorting gives every writer the same lock order, and bisecting isolates one bad event without blocking the partition. \[Likely\] Production versions also need backpressure (pause consumption when write latency or replica lag rises), metrics on batch time and bisect depth, and a bounded dead-letter queue with an alert.

### 24.4 Plan and db-hits test harness (pytest with Testcontainers)

```python
import json, pytest
from collections import Counter
from testcontainers.neo4j import Neo4jContainer

def total_db_hits(profile):
    return profile.get('dbHits', 0) + sum(total_db_hits(c) for c in profile.get('children', []))

def operator_names(profile):
    names = [profile['operatorType']]
    for child in profile.get('children', []):
        names += operator_names(child)
    return names

def profile_query(driver, cypher, params):
    with driver.session() as s:
        return s.run('PROFILE ' + cypher, params).consume().profile

@pytest.fixture(scope='session')
def driver():
    container = (Neo4jContainer('neo4j:PINNED-ENTERPRISE-VERSION')
                 .with_env('NEO4J_ACCEPT_LICENSE_AGREEMENT', 'yes'))
    with container as c:
        d = c.get_driver()
        load_schema_and_fixtures(d)          # constraints, indexes, tiny and skewed graphs
        yield d
        d.close()

@pytest.mark.parametrize('anchor,budget', [('user-hub', 250_000), ('user-cold', 1_000)])
def test_db_hits_budget(driver, anchor, budget):
    q = load_query('recs.peer_products', 3)
    p = profile_query(driver, q.cypher, {'userId': anchor, 'limit': 20})
    assert total_db_hits(p) <= budget
    banned = ('AllNodesScan', 'CartesianProduct', 'NodeByLabelScan', 'Eager')
    assert not [n for n in operator_names(p) if n.startswith(banned)]

def test_plan_matches_baseline(driver):
    q = load_query('recs.peer_products', 3)
    ops = Counter(operator_names(profile_query(driver, q.cypher, {'userId': 'user-hub', 'limit': 20})))
    baseline = Counter(json.load(open('queries/recs/peer_products/v3.plan.json')))
    assert ops == baseline, 'plan changed: review it, then re-baseline deliberately'

def test_results_on_tiny_fixture(driver):
    rows = run_registered(driver, 'recs.peer_products', {'userId': 'u1', 'limit': 5})
    assert [r['productId'] for r in rows] == ['p9', 'p4']

def test_cold_anchor_returns_empty_not_error(driver):
    assert run_registered(driver, 'recs.peer_products', {'userId': 'user-cold', 'limit': 5}) == []
```

&#91;Likely\] Operator names in the profile carry a runtime suffix (for example `Eager@neo4j`), which is why the check uses `startswith`. Run the budget and plan tests on a **skewed** fixture with your real hubs, because a tiny uniform graph passes everything and proves nothing. \[Certain\] Keep the budget numbers in the repository next to each query version, and require a reviewed change to raise one.

### 24.5 Schema migration runner (checksummed, ordered, never edits history)

```python
import glob, hashlib, re

def apply_migrations(driver, folder='schema', database='social'):
    with driver.session(database=database) as s:
        s.run('CREATE CONSTRAINT schema_version IF NOT EXISTS '
              'FOR (v:SchemaVersion) REQUIRE v.version IS UNIQUE').consume()
        done = {r['v']: r['c'] for r in s.run(
            'MATCH (v:SchemaVersion) RETURN v.version AS v, v.checksum AS c')}
        for path in sorted(glob.glob(folder + '/V*.cypher')):
            version = re.search(r'V(\d+)', path).group(1)
            text = open(path).read()
            checksum = hashlib.sha256(text.encode()).hexdigest()
            if version in done:
                if done[version] != checksum:
                    raise RuntimeError(path + ' changed after it was applied')
                continue
            for stmt in [x.strip() for x in text.split(';') if x.strip()]:
                s.run(stmt).consume()                    # schema DDL runs in auto-commit mode
            s.run('CALL db.awaitIndexes(300)').consume()  # do not proceed until indexes are ONLINE
            s.run('MERGE (v:SchemaVersion {version: $v}) '
                  'SET v.checksum = $c, v.appliedAt = datetime()', v=version, c=checksum).consume()
```

What is deliberately missing, and must be added before production use \[Certain\]: a distributed lock so two deployers cannot run migrations at once, a dry-run mode that prints statements, per-migration timing and failure handling that stops without marking a half-applied file as done, and approvals for any file containing `DROP`. Data backfills do **not** belong in this runner. They run as separate resumable jobs (section 18.1) so a multi-hour backfill cannot block a deploy.

## 20. Observability implementation

### 27.1 Gateway metrics to export (the most important dashboard source)

- `gateway_query_duration_seconds` histogram, labeled `query_id`, `version`, `tier`, `outcome`.
- `gateway_query_rows` histogram per `query_id`, because a changing row distribution is an early signal of a model or data problem.
- `gateway_rejected_total` labeled `reason` (`killed`, `rate_limited`, `circuit_open`, `row_budget`, `timeout`).
- `gateway_inflight` per `query_id`, to compare against Little's Law expectations.
- `canary_probe_success` per probe, with the expected-answer check inside the probe.

### 27.2 Example alert rules (Prometheus)

```yaml
groups:
- name: graph-critical
  rules:
  - alert: PageCacheHitRatioLow
    expr: neo4j_dbms_page_cache_hit_ratio < 0.97       # verify metric name on your /metrics endpoint
    for: 10m
    labels: {severity: critical}
    annotations: {summary: Page cache hit ratio below 97 percent, runbook: neo4j-page-cache}
  - alert: GraphWriterLagHigh
    expr: sum(kafka_consumergroup_lag{consumergroup='graph-writer'}) by (topic) > 100000
    for: 5m
    labels: {severity: warning}
    annotations: {summary: Graph writer consumer lag is high, runbook: graph-writer-lag}
  - alert: DataDiskLow
    expr: node_filesystem_avail_bytes{mountpoint='/data'} / node_filesystem_size_bytes{mountpoint='/data'} < 0.2
    for: 10m
    labels: {severity: warning}
    annotations: {summary: Data volume below 20 percent free, runbook: neo4j-disk}
  - alert: CertificateExpiringSoon
    expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 14
    labels: {severity: warning}
    annotations: {summary: A certificate expires in under 14 days, runbook: cert-rotation}
  - alert: CanaryProbeWrongAnswer
    expr: canary_probe_success == 0
    for: 2m
    labels: {severity: critical}
    annotations: {summary: Canary probe failing, treat as possible corruption, runbook: graph-corruption}
  - alert: Tier1ErrorBudgetBurnFast
    expr: >
      (job:gateway_errors:ratio_rate1h{tier='1'} > (14.4 * 0.0005))
      and (job:gateway_errors:ratio_rate5m{tier='1'} > (14.4 * 0.0005))
    labels: {severity: critical}
    annotations: {summary: Fast burn of the tier 1 error budget, runbook: slo-burn}
```

&#91;Guessing\] Neo4j metric names differ between releases and are prefixed by configuration, so list your real names with a request to the metrics endpoint and update the rules. The burn-rate rule assumes a 99.95% SLO (error budget 0.0005) and a recording rule for the error ratio over 1 hour and 5 minutes. \[Certain structure\]

### 27.3 Dashboard layout

1. **SLO overview**: error budget remaining and burn rate per tier.
2. **Per-query-ID latency**: p50, p95, p99 and row counts for the top queries, plus rejection reasons.
3. **Cluster health**: servers, leader per database, Raft changes, replication lag per secondary.
4. **Memory and cache**: page cache hit ratio, page faults, heap after GC, GC pauses.
5. **Ingestion**: consumer lag, batch time, bisect rate, dead-letter depth.
6. **Security**: failed authentication, privilege changes, procedure calls, row-count outliers.
7. **Capacity forecast**: hot-set estimate, disk growth, and the projected date each hits its trigger.

### 27.4 Tracing and logs

- &#91;Certain\] Wrap every gateway call in a trace span with `query.id`, `query.version`, `db.rows` and the same `traceId` you send in Neo4j transaction metadata, so one identifier connects the request trace, the Neo4j query log and `SHOW TRANSACTIONS`.
- &#91;Likely\] Emit structured (JSON) logs, ship them to a central store, and keep authentication and privilege events in a write-once store.
- &#91;Certain\] Never log query parameters that can contain personal data.

## 21. Critical alert thresholds and SLOs

The numbers below are starting baselines, not facts about your system. \[Guessing\] Replace them with values measured under load tests, and alert on burn rate for SLOs rather than on single data points.

| Signal | Warn | Critical | Action |
| --- | --- | --- | --- |
| Page cache hit ratio (serving) | Below 99% | Below 97% | Add memory, reduce hot set, check for scans on serving |
| Heap in use after GC | Above 70% | Above 85% | Find unbounded `collect()` or sort, lower transaction memory cap |
| GC pause (p99) | Above 200 ms | Above 1 s | Review heap sizing and allocation-heavy queries |
| Data disk used | Above 70% | Above 85% | Expand before store copies and backups fail |
| Transaction log disk used | Above 60% | Above 80% | Check backup lag, retention policy, consumer lag |
| Replication lag (serving secondary) | Above your freshness SLO | Above 3× the SLO | Route around it, reduce write burst, add capacity |
| Raft leader changes | More than 1 per hour | More than 3 per 10 minutes | Investigate network and disk latency |
| Query p99 per query ID (tier 1) | Above 80% of target | Above target | Kill switch, cap, scale, or roll back the version |
| Error rate (tier 0 or 1) | Above 0.1% | Above 1% | Page on-call, check dependencies |
| Deadlocks | More than 5 per minute | More than 30 per minute | Check writer key ordering and partitioning |
| Open transactions older than 30 s | Any | Growing | `SHOW TRANSACTIONS`, terminate, trace to `queryId` |
| Stream consumer lag | Above 1 minute | Above 5 minutes | Add consumers, find poison events, apply backpressure |
| Certificate days to expiry | 30 | 7 | Rotate |
| Newest backup age | Above RPO target | Above 2× RPO | Page, fix backup pipeline |
| Newest successful restore test | Above 90 days | Above 180 days | Schedule a drill |
| Queries missing `queryId` metadata | Any | Rising | Unregistered code path in production |
| Failed authentication rate | Above baseline × 3 | Above baseline × 10 | Check for credential stuffing or a broken client |
| Unapproved privilege or role change | Any | Any | Security incident review |
| Canary probe wrong answer | Any | Any | Treat as data corruption until disproved |

&#91;Certain\] Every alert must name an action and an owner, and any alert nobody acts on gets removed, because noisy alerts train responders to ignore the real one.

## 22. Load testing for scale (non-negotiable)

1. **Data**: generate a power-law graph at target scale, plus your real top hubs. Uniform data produces misleading results. \[Certain\]
2. **Traffic shape**: replay production query mixes (from the query log) with realistic parameter skew. Include the long tail of anchors, not just popular ones.
3. **Ramp tests**: increase QPS in steps until p99 breaks, and record the knee. Your safe capacity is about 60-70% of the knee. \[Likely\]
4. **Soak**: 24-72 hours with mixed read, write, ingestion, and backup running together. \[Certain\] Many failures only show up from GC drift, log growth, or cache churn.
5. **Chaos**: kill a primary during load, partition an AZ, slow a disk, and trigger a backup mid-peak. Verify SLOs and recovery time.
6. **Regression gating**: record knee QPS per release, and fail the release if it drops more than a set percentage. \[Likely\]

## 23. Cost and efficiency at scale

- &#91;Certain\] At TB-scale RAM with NVMe, infrastructure is your largest cost. Reducing the hot set (fewer properties on hot nodes, smaller types, dropping unused relationships) saves more than negotiating instance prices.
- &#91;Likely\] Right-size by workload. Serving secondaries are memory-heavy, analytics secondaries are CPU-heavy, and backup secondaries are cheap and can use slower disk.
- Tier the data: archive cold subgraphs (inactive users, old events) to object storage or a cheaper store, and rehydrate on demand. \[Likely\]

## 24. Scaling anti-patterns to avoid

| Anti-pattern | Why it fails |
| --- | --- |
| Adding secondaries to fix write latency | Reads scale, writes don't. \[Certain\] |
| Autoscaling primaries | Quorum changes are risky, and new members cold-start. \[Certain\] |
| One cluster for serving and analytics | Cache eviction and CPU contention. \[Certain\] |
| Relying on timeouts as the only protection | Work is already done before the timeout hits. Cap the query itself. \[Certain\] |
| Sharding before measuring cross-shard edge ratio | You may build a distributed system for a graph that can't be cut. \[Likely\] |
| Putting counters on graph elements | Write contention and log bloat. \[Certain\] |
| Treating the cache hit ratio as a vanity metric | A 95% overall ratio can hide a 70% ratio on T1 data. Segment by workload. \[Likely\] |
| Big-bang migrations | Impossible to roll back at this size. Use expand-migrate-contract. \[Certain\] |

## 25. Decision playbook

1. &#91;Certain\] Measure which axis is saturated (section 1).
2. Cap and materialize the offending queries (section 5), because it's the cheapest fix.
3. Add caching and hub protection (sections 3.3-3.4).
4. Add RAM and separate workloads (sections 2 and 3.1).
5. Reduce write volume and tune batching (sections 4.1-4.2).
6. Split into multiple databases by domain (section 4.3).
7. Only then consider sharding or federating across partitions, after measuring the cut quality (section 4.4).
8. If the cut quality is poor and the online path needs whole-graph traversals, adopt the polyglot design: purpose-built edge store online, Neo4j for the high-value subgraph.

## Inputs needed to go further

Real numbers decide whether sharding is a decision for this year or a distraction: users, average and p99 degree, write rate, and read QPS. With those, the next deliverables could be a capacity-model spreadsheet, a hub-bucketing scheme with migration steps, a load-test harness (needs language and CI), or cluster topology and Helm values (needs cloud, regions, and Neo4j version).

# Part 5. Security

A graph exposes relationships, not only records, so access control, auditing and containment have to be designed in, not added later.

## 26. Security hardening in depth

**Uncomfortable truth:** a graph database is an unusually high-value target, because one successful traversal query reveals relationships, not just records, and relationships are what attackers and regulators care about most. \[Likely\] Default settings are tuned for convenience, so every item below is something you must turn on deliberately. Config names are Neo4j 5.x and must be verified against your version. \[Likely\]

### 13.1 Threat model

| Threat | Typical path | Primary defenses |
| --- | --- | --- |
| Cypher injection | String-built queries, dynamic labels | Parameters only, allow-listed dynamic names, mass-assignment whitelist |
| Credential theft | Leaked service password, over-shared secret | Per-service accounts, vault-issued secrets, rotation, SSO for humans |
| Insider misuse | Broad read access to PII | Fine-grained RBAC, `DENY` on sensitive properties, audit logging |
| Data exfiltration | Giant exports, APOC export, replica copy | Result-size limits, procedure allow-list, egress controls, DLP on logs |
| Privilege escalation | Role chains, over-broad admin role | Privileges-as-code, separation of duties, immutable denies |
| Tenant leakage | Missing tenant predicate | Database-per-tenant or property-based access control, cross-tenant invariant queries |
| Destructive attack or ransomware | Stolen admin credentials, wipe query | Immutable off-account backups, deny delete, two-person approval, restore drills |
| Resource exhaustion (DoS) | One expensive query repeated | Admission control, quotas, timeouts, memory caps, cost pre-checks |
| Supply-chain compromise | Malicious plugin or image | Pinned and verified artifacts, SBOM, minimal images |
| Cluster-plane abuse | Exposed Raft or discovery ports | Private networks, mutual TLS between members |

### 13.2 Configuration hardening checklist

| Area | Setting (verify names) | Rule |
| --- | --- | --- |
| Authentication | `dbms.security.auth_enabled=true` | Never disable, including in staging. \[Certain\] |
| Transport encryption | `server.bolt.tls_level=REQUIRED`, `dbms.ssl.policy.bolt.*`, `dbms.ssl.policy.https.*`, `dbms.ssl.policy.cluster.*` | TLS on client and cluster traffic, with mutual TLS (`client_auth=REQUIRE`) between members. \[Likely\] |
| Listen addresses | `server.bolt.listen_address`, `server.http.listen_address` | Bind to private interfaces only, expose Bolt only to the query gateway. \[Certain\] |
| Unneeded endpoints | `server.http.enabled=false` where Browser is not needed | Reduce attack surface. \[Likely\] |
| Cluster ports | Raft, discovery and cluster transaction ports | Open only between members, never to clients. \[Certain\] |
| Procedures | `dbms.security.procedures.allowlist`, `dbms.security.procedures.unrestricted` | Allow-list the minimum, keep `apoc.*` file and network procedures out. \[Certain\] |
| File access | `dbms.security.allow_csv_import_from_file_urls=false`, `server.directories.import` | No arbitrary file reads. \[Certain\] |
| Path explosion | `dbms.cypher.forbid_exhaustive_shortestpath=true` | Prevent exhaustive shortest-path searches. \[Likely\] |
| Transaction limits | `db.transaction.timeout`, `db.memory.transaction.max`, `db.transaction.concurrent.maximum` | Bound the damage of any single query or burst. \[Likely\] |
| Brute force | `dbms.security.auth_max_failed_attempts`, `dbms.security.auth_lock_time` | Lockout (Enterprise). \[Likely\] |
| Query logging | `db.logs.query.enabled`, `db.logs.query.threshold`, `db.logs.query.parameter_logging_enabled=false` | Log who and how long, keep parameters out of logs because they contain PII. \[Certain\] |
| Security log | `security.log` | Ship to the SIEM, keep authentication and authorization events. \[Certain\] |

### 13.3 Identity and access

- &#91;Likely\] Humans authenticate through **SSO** (OpenID Connect is supported in Enterprise 5.x) or LDAP, with group-to-role mapping, so offboarding someone removes access everywhere.
- &#91;Certain\] One database account per service and per query class (T1 reader, T2 writer, migration, analytics, backup), each with least privilege. A shared "app" account makes incidents impossible to attribute.
- &#91;Certain\] Secrets come from a vault with short-lived or rotated credentials, and no credential appears in images, environment dumps or logs.
- &#91;Certain\] **Break-glass** admin access exists, is separately stored, requires approval, and every use triggers an alert and a review.
- &#91;Likely\] Review `SHOW ROLES WITH USERS` and the exported privileges quarterly, and automatically on every change.

### 13.4 Data protection

- &#91;Likely\] Neo4j does not provide built-in transparent data encryption, so encrypt volumes and backups with KMS-managed keys (LUKS, cloud disk encryption), and verify the key-rotation story.
- &#91;Certain\] Do not store card numbers, government IDs, passwords or raw secrets in the graph. Store tokens or references, and keep the sensitive value in a vault or tokenization service. Field-level encrypt remaining sensitive properties in the application when the threat model includes database administrators.
- &#91;Certain\] **Erasure (GDPR and similar) touches more than the graph**: the node, its relationships, derived `TOP_CONNECTION` and `SIMILAR_TO` edges, caches, Kafka topics (use compaction with tombstones), search indexes, analytics exports and backups. Design a deletion pipeline, and for backups use **crypto-shredding** (encrypt per-subject data with a per-subject key and destroy the key) or a documented retention expiry.
- &#91;Certain\] Erase in batches: delete relationships first (`MATCH (u:User {userId: $id})-[r]-() CALL (r) { DELETE r } IN TRANSACTIONS OF 10000 ROWS`), then the node, so a hub never produces one giant transaction. \[Likely on exact syntax, which depends on version\]
- &#91;Certain\] Classify data (public, internal, confidential, restricted) and tag labels or properties accordingly, so access policy and the invariant queries can find restricted data automatically.

### 13.5 Supply chain and runtime

- &#91;Certain\] Pin Neo4j, APOC and GDS to exact, compatible versions. Plugin and server versions must match, and a mismatch often fails at startup or, worse, at runtime.
- &#91;Likely\] Verify checksums and signatures, build from a minimal base image, generate an SBOM, scan images, and subscribe to Neo4j security advisories.
- &#91;Likely\] Run as non-root, with a read-only root filesystem where possible, no extra capabilities, Kubernetes `NetworkPolicy` restricting ingress to the gateway and cluster peers, and pod security standards enforced.
- &#91;Certain\] Install only the plugins you need, since each procedure is attack surface.

### 13.6 Detection and audit

Alert on these events \[Likely\]:

- Failed or locked-out authentication spikes, and logins from new locations or at off-hours for admins.
- Any `CREATE USER`, `ALTER USER`, `GRANT`, `DENY` or role change that does not match an approved change record.
- Calls to `dbms.*` procedures or any `apoc.*` outside the allow-list.
- Result sizes or row counts far above a query ID's baseline, which signals exfiltration or a bug.
- Query volume per principal exceeding its quota, and queries without `queryId` metadata (unregistered code).
- Cross-tenant invariant query returning nonzero.

Ship logs to a SIEM with write-once retention, so an attacker who gains database access cannot erase their trail. \[Certain\]

### 13.7 Denial-of-service defenses specific to graphs

A single anchored query on a hub can cost millions of expansions, so request count is a poor proxy for load. \[Certain\]

- **Cost pre-check**: the gateway runs `EXPLAIN` on new or changed queries and rejects plans with `CartesianProduct`, unbounded expansion, or estimated rows above a threshold. Re-check when statistics change. \[Likely\]
- **Weighted quotas**: charge each principal by measured cost (db hits or elapsed time per call), not by request count.
- **Per-anchor-key limits** against hub abuse (an attacker repeatedly querying the biggest node).
- **Timeouts and memory caps** at the database (section 13.2) plus a shorter client deadline.
- **Isolation**: serving, analytics and ingestion run on separate servers, so abuse on one cannot starve another. \[Certain\]

### 13.8 Defense against destructive events

- &#91;Certain\] Backups go to a **separate cloud account** with **object lock** (immutable retention), so stolen production credentials cannot delete them.
- &#91;Likely\] Use differential backups and point-in-time restore (`neo4j-admin database restore` with a restore-until option, verify in your version) so you can recover to just before a bad write, not just to last night.
- &#91;Certain\] Run `neo4j-admin database check` on restored copies on a schedule to detect store corruption before you need the backup.
- &#91;Certain\] Require approval from a second person for destructive changes (drop database, mass delete, constraint or index drops) and take a verified backup first.
- Restore drills quarterly, with measured time, and record RTO as an actual number. \[Certain\]

# Part 6. Safety, criticality and complex-system resilience

Failures at this size come from interactions between components and people. This part gives the tiers, failure modes, risk register, readiness gate and checklists that keep a failure small.

## 27. Safety and criticality for a complex system

A billion-user graph platform is a complex system: many interacting components, partial failures, feedback loops and human operators. \[Certain\] In complex systems, failures rarely come from one broken part. They come from interactions, such as a retry storm meeting a cold cache meeting a slow disk. This section gives you the vocabulary, the controls, and the math.

### 14.1 Criticality tiers (classify every query, dataset and service)

| Tier | Examples | Availability target | RPO | RTO | Failure mode |
| --- | --- | --- | --- | --- | --- |
| **0 (safety, money, identity)** | Authorization checks, payment and fraud blocking, account recovery | 99.99%+ | Near zero | Minutes | **Fail closed** with explicit degraded mode |
| **1 (core product)** | Feed, profile, search | 99.95% | Seconds to minutes | Under 30 min | Degrade to cached or stale data |
| **2 (derived)** | Recommendations, scores, `TOP_CONNECTION` | 99.9% | Rebuildable | Hours | Serve last good snapshot |
| **3 (analytics)** | Reports, GDS jobs | Best effort | Rebuildable | Days | Pause and rerun |

&#91;Certain\] These numbers are placeholders you must set with the business. The discipline is that every query header carries its tier, and the tier decides its infrastructure, review rigor and failure behavior.

### 14.2 Fail-open versus fail-closed (decide explicitly, per capability)

| Capability | When the graph query times out | Reason |
| --- | --- | --- |
| Authorization or permission check | **Deny** (fail closed) | A wrong allow is a breach |
| Fraud or abuse blocking on a payment | Policy decision: **hold for review** or use a cached score, never silently approve high-risk | Business and regulatory risk |
| Recommendations | Serve cached or popular items (fail open) | Low harm, high availability value |
| Friend suggestions, feed | Serve stale list | Same |
| Audit logging | Buffer locally and retry, **never drop** | Compliance |

&#91;Certain\] Writing this table is the exercise. Teams that never wrote it discover their policy during an outage.

### 14.3 Complex-system failure modes and defenses

| Failure mode | What happens | Defense |
| --- | --- | --- |
| **Cascading failure** | One slow dependency exhausts threads upstream, which then fail their callers | Timeouts with deadline propagation, bulkheads, circuit breakers |
| **Retry storm and metastable failure** | Retries multiply load, so the system stays overloaded even after the trigger is gone | Retry budgets, exponential backoff with full jitter, load shedding, a global retry cap |
| **Thundering herd** | Many clients hit the same cold key at once | Request coalescing, stale-while-revalidate, jittered TTLs |
| **Gray failure** | A node is degraded, not dead, so health checks pass | Latency-aware health checks, outlier ejection, per-node SLO probes |
| **Hot partition or hub** | One key takes disproportionate load | Per-key limits, bucketing, cache tier (section 3.4) |
| **Split brain and leader flapping** | Two nodes believe they lead, or leadership changes repeatedly | Quorum (Raft) with an odd member count, fencing tokens for external writers, stable network |
| **Recovery deadlock** | System needs a dependency that needs the system to start (cache needs DB, DB needs cache, auth needs graph) | Dependency-cycle query (section 12.9), static stability, break-glass startup path |
| **Backpressure collapse** | Queues grow unbounded and latency explodes | Bounded queues, drop or defer low-priority work, consumer lag alerts |
| **Silent data corruption or drift** | Graph diverges from the source of truth with no error | Reconciliation jobs (section 12.5), checksums, canary probes |
| **Resource exhaustion** | File descriptors, connections, disk, heap | Limits, alerts at 70%, capacity model |
| **Configuration or deployment error** | A bad push breaks every node at once | Progressive rollout, cell-by-cell deploys, automatic rollback |
| **Clock skew** | Version and TTL logic misbehaves | Monotonic or hybrid logical clocks for ordering, never wall-clock alone |
| **Human error under stress** | Wrong command in the wrong environment | Runbooks, guard rails, two-person rule for tier 0, clear environment banners |

### 14.4 Resilience patterns and algorithms by name

| Pattern or algorithm | Use it for |
| --- | --- |
| **Raft** consensus (inside Neo4j clustering) | Leader election and log replication, tolerates minority loss. \[Certain\] |
| **Circuit breaker** | Stop calling a failing dependency and fail fast |
| **Bulkhead** | Separate thread pools or connection pools per query class |
| **Token bucket, leaky bucket, sliding window, GCRA** | Rate limiting |
| **Adaptive concurrency limits (AIMD, Vegas, Gradient)** | Automatically find the safe in-flight limit per server |
| **CoDel and adaptive LIFO** | Queue management under overload, serve fresh requests first |
| **Priority load shedding** | Drop tier 3 first, protect tier 0 |
| **Exponential backoff with full jitter** | Retries that do not synchronize |
| **Hedged requests** | Cut tail latency on idempotent reads, capped and only after the p95 delay |
| **Power of two choices, rendezvous hashing, consistent hashing** | Load balancing and partition assignment with minimal reshuffling |
| **Shuffle sharding** | Limit the blast radius of a bad tenant or query to a small random subset of servers |
| **Cell-based architecture** | Independent full-stack copies, each serving a slice of users |
| **Saga, outbox and change-data-capture** | Reliable propagation between systems without distributed transactions |
| **Idempotency keys and fencing tokens** | Safe retries and protection against stale writers |
| **Leases** | Time-bounded ownership for background jobs |

### 14.5 Quantitative laws you should actually compute

- **Little's Law**: `L = λ × W` (in-flight work equals arrival rate times latency). At 20,000 queries per second with 50 ms average latency, about **1,000 queries are in flight** across the fleet. If each server's Bolt worker pool is capped (the default maximum is on the order of a few hundred threads \[Likely, verify `server.bolt.thread_pool_max_size`\]), you can compute how many servers you need and where queueing begins. \[Certain math\]
- **Utilization knee**: for a simple queue, waiting time grows roughly like `ρ / (1 − ρ)`. Latency is flat at 50% utilization and rises sharply beyond 70-80%, so plan capacity for 60-70% at peak. \[Likely\]
- **Universal Scalability Law**: `C(N) = N / (1 + α(N−1) + βN(N−1))`, where α is contention and β is coherency cost. Throughput peaks near `N* = sqrt((1 − α) / β)`, then **falls** as you add more writer threads or servers. Fit α and β from your load tests to find your write-parallelism knee. \[Certain\]
- **Tail amplification**: a request that fans out to N sub-queries and waits for all is slow if any one is slow. With each sub-query under p99 with probability 0.99, a fan-out of 100 has `1 − 0.99^100 ≈ 63%` chance of hitting at least one slow sub-query. \[Certain math\] Fan-out is a latency multiplier, so cap it.
- **Error budget and burn rate**: a 99.95% monthly SLO allows about 21.9 minutes of unavailability. Alert on burn rate, using multi-window rules such as 14.4× over 1 hour (confirmed over 5 minutes) to page, 6× over 6 hours (confirmed over 30 minutes) to page, and 1× over 3 days to open a ticket. \[Certain per the Google SRE workbook\]

### 14.6 Cell-based architecture applied to Neo4j

Because one Neo4j database has a single write leader and a limited hot set, the most robust billion-user design is **many independent cells**. \[Likely\]

- A **cell** is a complete, small stack: a Neo4j cluster (3 primaries, a few secondaries), its ingestion workers, its cache, and its gateway instances, serving a fixed hash range of users.
- A thin **router** maps `userId` to a cell. The router is the only global component, so it must be extremely simple, replicated, and static-stable (it keeps working on its last known map if the control plane is down).
- **Blast radius is one over N**: a bad deploy, a poison query or a cluster loss affects one cell, not the whole product.
- **Deployments are staged by cell**: canary cell first, then 5%, then the rest, with automatic rollback on SLO regression.
- **Cross-cell edges** (a user in cell 7 following a user in cell 42) are the hard part. Options: replicate a lightweight "shadow" node of the remote user into the local cell, fan out queries across cells at the application layer for the rare cross-cell case, or precompute cross-cell relationships in the analytics tier. Measure the cross-cell edge ratio before choosing the cell key. \[Certain\]
- Resharding (splitting a cell) is a planned, rehearsed migration using expand-migrate-contract at cell level.

### 14.7 Change safety

- &#91;Certain\] Every change carries a **blast-radius label** (one cell, one region, global) and a rollback plan. Global changes need the highest approval.
- Progressive delivery: canary, then percentage steps, with automated halt on SLO burn.
- Feature flags and kill switches for every tier 0 and tier 1 query. \[Certain\]
- Change freezes around peak events, and no tier 0 changes without a second reviewer.
- **Pre-mortem** for each major migration: assume it failed, and list the three most likely causes before starting.
- Config, schema, queries and privileges are all code in version control. \[Certain\]

### 14.8 Verification beyond unit tests

- **Canary probes**: synthetic queries with known answers, run continuously against production from outside (a seeded test subgraph). A probe that returns a wrong answer catches silent corruption that latency metrics cannot. \[Certain\]
- **Property-based and metamorphic tests** for queries: for example, adding an unrelated node must not change a result, and shuffling input order must not change an aggregate.
- **Differential testing** between the old and new query version, and between Neo4j versions, on replayed traffic. \[Likely\]
- **Fault injection on the pipeline** (Jepsen-style thinking): duplicate, reorder, delay and drop events, then assert the graph converges to the right state. Idempotent MERGE-on-constrained-key writes should survive all four. \[Likely\]
- **Reconciliation** between the source of truth and the graph on a schedule, with alerts on drift.
- **Game days**: kill a primary, partition an AZ, fill a disk, expire a certificate, revoke a credential, and restore from backup, with the on-call team who will really respond. \[Certain\]

### 14.9 Incident severity and critical runbooks

| Severity | Definition | Response |
| --- | --- | --- |
| **SEV1** | Tier 0 down or data loss or security breach | Page immediately, incident commander, executive notification |
| **SEV2** | Tier 1 degraded beyond SLO | Page on-call, mitigation within the hour |
| **SEV3** | Tier 2 or 3 impact | Business-hours ticket |

Runbooks that must exist and be rehearsed \[Certain\]: loss of quorum or leader flapping, primary failure, secondary lag, disk full (data and transaction log), page cache collapse, runaway query and kill switch, bad query or schema deploy rollback, failed or slow backup, full restore into a fresh cluster, store corruption (`neo4j-admin database check`), credential compromise and rotation, accidental mass delete (point-in-time restore), certificate expiry, cell evacuation, and region failover.

## 28. Critical risk register

Use this as the starting agenda for a pre-mortem. Likelihood and impact are ratings you must set for your own system, so the table gives the detection signal and the control. \[Certain structure, Guessing on priorities\]

| # | Risk | Early detection | Primary control |
| --- | --- | --- | --- |
| 1 | Loss of quorum or leader flapping halts writes | `SHOW DATABASES` writer changes, Raft metrics | Primaries across 3 AZs, tested failover, buffer writes in Kafka |
| 2 | Page cache collapse after data growth | Hit ratio below 98%, page faults rising | Capacity model with 50% trigger, tiering, hot-set reduction |
| 3 | Hub query storm | Per-key request rate, `db hits` per call | Degree caps, bucketing, per-key limits, hub cache |
| 4 | Stale secondary honors a revoked permission | Replication lag per secondary | Bookmarks or leader reads for authorization, event-driven cache invalidation |
| 5 | Migration drops an index or constraint | `SHOW INDEXES` and `SHOW CONSTRAINTS` diff against the repo | Expand-migrate-contract, approval, restricted migration role |
| 6 | Backup exists but cannot be restored | Restore-test age and duration | Quarterly restore drill, `neo4j-admin database check` on restored copies |
| 7 | Credential compromise | Failed-auth spikes, off-hours admin use | Per-service least privilege, rotation, SSO, break-glass auditing |
| 8 | Poison event blocks a stream partition | Consumer lag on one partition | Dead-letter queue, bounded retries, idempotent writers |
| 9 | Transaction log or data disk fills | Disk above 70% | Separate volumes, retention policy tuning, expansion runway |
| 10 | Plan regression after statistics change or upgrade | Plan diff against stored baselines, p99 per query ID | Plan baselines in CI, upgrade rehearsal on production-size data |
| 11 | Heap exhaustion from `collect()` or sort | GC pause time, allocation log | Collection caps, `db.memory.transaction.max`, request limits |
| 12 | Cross-tenant data leak | Cross-tenant invariant query nonzero | Database-per-tenant or property-based access control |
| 13 | Derived data (`TOP_CONNECTION`) goes stale silently | `DerivedRun.completedAt` age | Freshness SLO, fallback to last good snapshot |
| 14 | Certificate expiry takes down the cluster | Days-to-expiry metric | Alerts at 30, 14 and 7 days, automated rotation |
| 15 | Upgrade store migration takes hours | Staging rehearsal duration | Rehearse on a production-size restore, rolling plan with rollback |
| 16 | Clock skew corrupts ordering or TTLs | NTP offset metric | Monotonic or hybrid logical clocks, NTP monitoring |
| 17 | Malicious or incompatible plugin or image | SBOM and checksum diff | Pinned, verified artifacts |
| 18 | Analytics job starves serving traffic | Latency on serving during batch windows | Separate servers for serving and analytics |
| 19 | Retry storm after partial outage | Request rate far above baseline during errors | Retry budgets, backoff with jitter, load shedding |
| 20 | Mass delete by mistake or attack | Delete counts per principal, `DETACH DELETE` in logs | Deny delete to app roles, second-person approval, point-in-time restore |

## 29. Production readiness gate and game days

### 21.1 Launch gate (do not go live with a tier 0 or tier 1 workload until all are true)

- [ ] Every query is in the registry with header, tier, owner, budgets and a kill switch
- [ ] The query set passes db-hits ceilings on a skewed, production-scale dataset, including the highest-degree anchor
- [ ] Plans are baselined, with no `AllNodesScan`, `CartesianProduct` or unexplained `Eager`
- [ ] Authorization is inside tier 0 and tier 1 queries, with revocation lag handled and fail-closed behavior tested
- [ ] Least-privilege roles exported to version control, `DENY` on sensitive properties, procedures allow-listed
- [ ] TLS everywhere, Bolt reachable only from the gateway, secrets from a vault
- [ ] Backups run from a dedicated secondary to an immutable, separate-account store, and a full restore has been timed
- [ ] Capacity model covers 24 months, with Little's Law concurrency, the utilization knee and the write-parallelism knee measured
- [ ] Observability in place: per-query-ID latency, page cache, GC, replication lag, Raft, consumer lag, canary probes
- [ ] Runbooks exist for each scenario in section 14.9 and were exercised by the people on call
- [ ] A rollback exists for every deployment type (query version, schema, config, binary)
- [ ] Cross-system reconciliation is running and alerting
- [ ] Erasure and retention pipeline is verified end to end
- [ ] Incident roles, severities and escalation contacts are published

### 21.2 Game-day scenarios

| Scenario | Injection | Pass criteria |
| --- | --- | --- |
| Primary loss during peak | Kill the leader under load | New leader elected, tier 1 writes resume within the target, no data loss, no duplicate events after replay |
| AZ partition | Isolate one AZ | Quorum holds, reads continue, alerts fire, recovery requires no manual data repair |
| Hub storm | Replay a burst of requests on your biggest node | Per-key limits and caches hold, other query classes keep SLO |
| Poison event | Inject a malformed event into the stream | Event dead-lettered, partition keeps moving, alert fires |
| Disk fill | Fill the transaction log volume on a secondary | Alert fires before failure, traffic drains, service recovers after expansion |
| Credential revocation | Revoke the gateway credential | Fail-closed behavior on tier 0, clean reconnect after rotation, no secrets in logs |
| Certificate expiry | Let a staging certificate lapse | Alerts fired at 30, 14 and 7 days, rotation procedure works |
| Bad query release | Deploy a query with a missing cap to a canary cell | Canary detects the regression, automatic rollback, kill switch works |
| Stale secondary | Delay replication on one secondary | Authorization paths use bookmarks or leader reads, stale reads confined to tolerant queries |
| Full restore | Restore the latest backup into a fresh cluster | Measured RTO within target, `neo4j-admin database check` passes, canary probes pass |
| Mass delete | Attempt a wipe with an application credential | Denied, alert fires, restore path rehearsed |
| Retry storm | Slow a dependency to trigger client retries | Retry budgets and shedding keep the system out of metastable overload |

&#91;Certain\] A scenario only counts as passed if the people who will be on call ran it using the real runbook, and the results (time to detect, time to mitigate, surprises) are recorded and fed back into the runbooks and alerts.

## 30. Master checklists

### 15.1 Safety

- [ ] Every query, dataset and service has a criticality tier, owner and SLO
- [ ] Fail-open or fail-closed is written down for each tier 0 and tier 1 capability
- [ ] Dependency cycles and single points of failure are queried and reviewed (section 12.9)
- [ ] Kill switches, circuit breakers, retry budgets and load shedding are in place and tested
- [ ] Canary probes with known answers run continuously
- [ ] Reconciliation against the source of truth runs on a schedule with alerts
- [ ] Restore from backup has been timed within the last quarter
- [ ] Changes carry a blast-radius label, and deployments go cell by cell

### 15.2 Security

- [ ] Parameters only, no string-built Cypher, and no raw client maps into `SET`
- [ ] Authorization predicate inside every tier 0 and tier 1 data query, with revocation lag handled
- [ ] Per-service least-privilege roles, `DENY` on sensitive properties, privileges exported to git
- [ ] TLS everywhere with mutual TLS in the cluster, Bolt exposed only to the gateway
- [ ] Procedure allow-list set, file import disabled, APOC minimized
- [ ] Query log without parameters, security log in the SIEM with write-once retention
- [ ] Backups encrypted, immutable, in a separate account, with restore drills
- [ ] Erasure pipeline covers graph, derived edges, caches, streams and backups
- [ ] Plugins and images pinned, scanned and tracked against advisories

### 15.3 Criticality and scale

- [ ] Algorithms follow the safe workflow: estimate, project, `.stats`, `.stream`, validate, then write
- [ ] No exact all-pairs, betweenness or unbounded similarity on the full graph
- [ ] Hub degree caps on every traversal and every shared-identifier join
- [ ] Capacity model includes Little's Law concurrency, the utilization knee and the USL write knee
- [ ] Cell key chosen from measured cross-cell edge ratio

## Open assumptions to confirm

1. Neo4j version and edition (several features above depend on 5.x and Enterprise).
2. Compliance regime (GDPR, PCI DSS, HIPAA, SOC 2), which decides erasure, encryption and audit scope.
3. Which capabilities are tier 0, and the agreed fail-open or fail-closed policy for each.
4. Whether the graph is the system of record or a derived view, which decides backup versus rebuild strategy.
5. Real numbers: users, average and p99 degree, write rate, read QPS, and cross-cell edge ratio.

# Appendices

A worked example, reusable templates, a symptom-to-section index, and the references.

## Appendix D. References and glossary

### 28.1 Papers and sources behind the algorithms and patterns

Where a year or venue could be misremembered, verify it before citing. \[Likely\]

| Topic | Source |
| --- | --- |
| Raft consensus | Ongaro and Ousterhout, "In Search of an Understandable Consensus Algorithm" (2014) |
| Pregel (bulk-synchronous graph processing) | Malewicz et al., "Pregel: A System for Large-Scale Graph Processing" (2010) |
| Facebook social graph store | Bronson et al., "TAO: Facebook's Distributed Data Store for the Social Graph" (2013) |
| Tail latency and fan-out | Dean and Barroso, "The Tail at Scale" (2013) |
| Metastable failures | Bronson et al., "Metastable Failures in Distributed Systems" (HotOS 2021) |
| Brandes betweenness | Brandes, "A Faster Algorithm for Betweenness Centrality" (2001) |
| Leiden community detection | Traag, Waltman and van Eck, "From Louvain to Leiden" (2019) |
| Streaming partitioning | Stanton and Kliot (LDG, 2012), Tsourakakis et al. (Fennel, 2014) |
| Social Hash Partitioner | Kabiljo et al., VLDB 2017 |
| HyperLogLog | Flajolet et al. (2007) |
| Count-Min Sketch | Cormode and Muthukrishnan (2005) |
| Space-Saving heavy hitters | Metwally, Agrawal and El Abbadi (2005) |
| Bounded-load consistent hashing | Mirrokni, Thorup and Zadimoghaddam (2016) |
| Reachability labeling | Akiba, Iwata and Yoshida, Pruned Landmark Labeling (2013) |
| Sybil detection | Cao et al., SybilRank (NSDI 2012) |
| SLO burn-rate alerting | Google, Site Reliability Workbook, chapter on alerting on SLOs |
| Neo4j operations | Neo4j Operations Manual (clustering, performance, security), Neo4j Cypher Manual, GDS Manual |

### 28.2 Glossary

- **Anchor**: the indexed node a query starts from.
- **Blast radius**: the portion of users or functions affected by one failure or change.
- **Cell**: an independent, complete copy of the stack serving a slice of users.
- **Cut ratio**: the fraction of edges whose endpoints sit in different partitions.
- **Epoch**: a version number on the routing table, used for fencing.
- **Fail closed**: deny or stop when a safety check cannot complete.
- **Fencing token**: a monotonically increasing number that lets a resource reject stale writers.
- **Hot set**: the part of the store touched by serving traffic in a typical period.
- **Metastable failure**: an overload that persists after its trigger is gone because of feedback such as retries.
- **Projection**: the in-memory graph that GDS algorithms run on.
- **Supernode (hub)**: a node with extremely high degree.
- **Tier**: the criticality class that decides SLO, recovery targets and failure behavior.
