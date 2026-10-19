**Managing complex queries is a software-engineering problem, not a Cypher problem, and one 200-line query per feature will fail no matter how well it's written.**  The fix is to treat each query as a small, versioned, tested program with a contract. Everything below follows from that. Items depending on your Neo4j version are flagged, and I still don't know your version.

---

# Part 1: Writing complex queries you can manage

## 1.1 Design the query as a pipeline of stages with contracts

Every complex query becomes 3-6 named stages, each with a stated purpose and a **cardinality budget**. If you can't say how many rows a stage may emit, you can't control it. 

```cypher
// ===== recs.peer_products.v3 =====
// question : Which products should we recommend to a user, based on similar buyers?
// tier     : T1 (p99 < 100 ms, runs on secondaries)
// inputs   : $userId String, $limit Integer (max 50)
// outputs  : productId, name, score, peerCount
// budgets  : S1 ≤ 1 row | S2 ≤ 500 rows | S3 ≤ 50 rows | S4 = $limit rows
// indexes  : UNIQUE User.userId, UNIQUE Product.productId
// dbhits   : ≤ 250k for the p99 anchor user (see tests/anchors.json)
// owner    : recs-team | since v3: peer cap added (was unbounded in v2)

// --- S1: anchor ---
MATCH (me:User {userId: $userId})

// --- S2: peers by overlap, capped ---
CALL (me) {
  MATCH (me)-[:BOUGHT]->(shared:Product)<-[:BOUGHT]-(peer:User)
  WHERE peer <> me
  WITH peer, count(DISTINCT shared) AS overlap
  WHERE overlap >= 2
  RETURN peer, overlap ORDER BY overlap DESC LIMIT 500
}

// --- S3: candidates, aggregate, top-N ---
MATCH (peer)-[:BOUGHT]->(rec:Product)
WHERE NOT EXISTS { (me)-[:BOUGHT]->(rec) }
WITH rec, count(DISTINCT peer) AS peerCount, sum(overlap) AS score
ORDER BY score DESC LIMIT $limit

// --- S4: enrich only the survivors ---
RETURN rec.productId AS productId, rec.name AS name, score, peerCount
```

(`CALL (me) {...}` needs 5.23+. Older 5.x uses `CALL { WITH me ... }`. )

## 1.2 Rules that keep it manageable

1. **One query, one business question.**  If the header needs the word "and", split it into two queries and join them in the application.
2. **Do orchestration in the app, not in Cypher.**  Two 40-line queries with the application merging results are easier to test, cache, and time out independently than one 120-line query. Put in Cypher only what benefits from staying inside the database: traversal, aggregation, and set filtering.
3. **A stage is allowed to exist only if it either reduces rows or adds needed data.**  Stages that pass rows through unchanged are noise.
4. **Reduce before you enrich.** Aggregate, then `ORDER BY ... LIMIT`, then fetch names, categories, and flags. 
5. **Use subqueries (`CALL {}`, `COUNT {}`, `EXISTS {}`, `COLLECT {}`) for independent sub-logic** so variable scope stays small. 
6. **Name every variable for what it is** (`peerCount`, not `c2`), and never reuse a variable name across stages for a different meaning. 
7. **Hard caps everywhere.** Every variable-length path is bounded, every fan-out has a `LIMIT`, and every collected list has a ceiling. 
8. **Never use positional or implicit knowledge.** The inputs and outputs in the header are the interface, and nothing else may depend on the query's internals. 

## 1.3 Develop incrementally

1. Write S1 and `RETURN` it. Run `PROFILE`.
2. Add S2, comment out the rest, and `RETURN count(*)` plus a `LIMIT 20` sample. Check the row count against the budget.
3. Repeat for each stage.  This is how you find the stage that explodes. Debugging a finished 100-line query is much slower.
4. Test with a **hub anchor** (your highest-degree user) and a **cold anchor** (a user with zero edges), because queries usually break at the extremes. 

## 1.4 Repository layout

```
queries/
  recs/
    peer_products/
      v3.cypher            # the query, with header
      v3.test.yaml         # inputs, expected outputs on the fixture graph
      v3.budget.yaml       # row and db-hit ceilings per anchor type
      CHANGELOG.md         # why each version changed
  _shared/                 # reusable fragments (documented, versioned)
schema/
  V001__constraints.cypher
  V002__indexes.cypher
fixtures/
  tiny_graph.cypher        # hand-built, correctness
  skewed_graph.cypher      # generated, with hubs, for performance
```

 Cypher has no native include mechanism, so reuse fragments by string templating in your build step or by turning reusable logic into a **separate query** the app calls. Don't copy-paste fragments between queries without a shared test, because copies drift.

## 1.5 Self-review checklist before opening a PR
- Does the header's budget match what `PROFILE` shows? 
- Any `AllNodesScan`, `NodeByLabelScan` on a big label, `CartesianProduct`, or unexplained `Eager`? 
- Does the estimated-vs-actual row count diverge by more than 10x anywhere?  That means bad statistics or skew.
- Could a single user's data make S2 unbounded?  If yes, add a cap.
