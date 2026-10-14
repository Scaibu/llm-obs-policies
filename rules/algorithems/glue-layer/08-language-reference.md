The first two glue parts defined the engine. This part applies it to your 606 algorithms, so the engine can combine them automatically:

1. A **shared type vocabulary**: the standard data types every algorithm exchanges. It's what makes any combination plug together.
2. A **capability taxonomy** for the registry.
3. **Standard adapters** between the types.
4. **Selection decision tables** (DMN-style) for the most common choices.
5. A **recipe library** of HTN methods: 15 ready-made decompositions for common tasks, with branches, loops and stop conditions.
6. **Global invariants** that every combination must respect.

References: **C#** = code search/update, **V#** = vector, **K#** = knowledge graph, **G#** = glue. No code, and no AI in the glue itself.

---

## 1. Shared type vocabulary (the plug shapes)

Every algorithm's inputs and outputs (G1) use these types. When everything speaks the same 20 types, any producer can feed any compatible consumer.

| Type | What it holds | Main producers | Main consumers |
|---|---|---|---|
| **T1 PathSet** | File paths, each with a content hash and language | C#1–8 | C#9–42, C#77–86 |
| **T2 RangeMatch** | Path, byte start/end, matched text, pattern ID, file hash | C#9–42, C#81–84 | C#117–126, adapters |
| **T3 ScoredList[T]** | Items with score, rank and which source produced them | V#51–98, C#68, K#68–75 | Fusion, rerank, top-k |
| **T4 TextEditSet** | Path, byte range, expected old text, new text, file hash | C#117, C#125, C#132 | C#120–123, C#157–165 |
| **T5 Changeset** | Grouped edits across files, plan ID, rule ID | C#118, C#202 | C#157–162, C#185–192 |
| **T6 Chunk** | Text, source ID, offsets, content hash, metadata | V#11–13, C#99 | V#1–14, K#25–31 |
| **T7 VectorRecord** | ID, vector, model version, lineage, access fields | V#2–6, V#15–46 | V#51–110, V#111–155 |
| **T8 QueryVector** | Vector, model version, prefix used | V#2, V#6 | V#51–98 |
| **T9 IndexHandle** | Index ID, version or snapshot, parameters | V#57–79, K#13–24 | Search and update steps |
| **T10 EntityRef** | Stable ID, labels, aliases | K#27, K#35–39, K#154 | K#51–84, K#151–166 |
| **T11 Fact** | Subject, predicate, object, status, provenance, valid time | K#29–34, K#85–100 | K#5, K#172, K#161 |
| **T12 Subgraph** | Nodes, edges, provenance | K#157, K#63–72 | K#161, K#124, K#155–156 |
| **T13 Path** | Ordered list of facts | K#65–68, K#158 | K#161, K#170 |
| **T14 GraphQuery** | Language, text, parameters, limits | K#61, K#151 | K#153, K#51–60 |
| **T15 VerificationReport** | Checks run, pass/fail, evidence, counts | C#177–184, V#156–167, K#186–197 | G31 guards, G33 loops |
| **T16 MetricSample** | Metric name, value, labels, time | All observability entries | G89–G91, alerts |
| **T17 Scope** | Predicate on repos, paths, tenants, types, time | G45 | Every step |
| **T18 Budget** | Steps, time, money, items, retries | G34 | Every step |
| **T19 PlanGraph** | Steps, edges, parameters, contracts, plan hash | G18–G28 | G29–G42 |
| **T20 EvidenceBundle** | Claims with citations to facts, chunks or ranges | K#162, V#94 | Reporter, answers |

**Rule:** a new algorithm enters the registry only if its inputs and outputs map to these types (or a new type is added to this vocabulary through review). That keeps the whole library composable.

## 2. Capability taxonomy (registry tags, G2)

The planner searches the registry by these hierarchical tags:

- **discover.** `files`, `language`, `scope`
- **search.** `literal`, `multi_literal`, `regex`, `fuzzy`, `structural`, `symbol`, `semantic`, `keyword`, `hybrid`, `graph_pattern`, `graph_path`
- **rank.** `fuse`, `rerank`, `diversify`, `calibrate`
- **transform.** `chunk`, `embed`, `normalize`, `reduce_dims`, `quantize`, `extract_entities`, `extract_relations`, `link_entities`, `resolve_entities`
- **edit.** `plan`, `codemod`, `apply`, `rebase`, `merge`
- **index.** `build`, `upsert`, `delete`, `compact`, `repair`, `swap`
- **reason.** `rules`, `ontology`, `closure`, `consistency`, `predict_links`
- **verify.** `parse`, `typecheck`, `test`, `postcondition`, `recall`, `consistency`, `faithfulness`
- **observe.** `quality`, `drift`, `latency`, `freshness`, `cost`
- **govern.** `access_check`, `erase`, `approve`, `audit`

Each tag also carries properties for filtering: `read_only` / `writes`, `deterministic`, `idempotent`, `uses_model` (an embedding or LLM call, so it has a token or GPU cost), `exhaustive` / `approximate`.

The `uses_model` and `approximate` flags matter most:
- The planner can be told "no model calls" and will build plans only from deterministic algorithms where possible.
- Steps needing completeness (edit scopes, deletions) can only use `exhaustive` algorithms. Approximate ones (ANN, ranked search) are blocked there.

## 3. Standard adapters (G4)

| Adapter | From → To | Based on | Lossy? |
|---|---|---|---|
| **A1** | line/column → byte range | C#142, C#119 | No |
| **A2** | RangeMatch + replacement template → TextEditSet | C#132 | No |
| **A3** | TextEditSet → unified diff | C#124, C#146 | No |
| **A4** | ScoredList → top-k set | C#73 | **Yes** (truncates) |
| **A5** | several ScoredLists → one ScoredList | V#87, V#88 | Ranking changes |
| **A6** | RangeMatch list → PathSet (distinct files) | — | No |
| **A7** | PathSet → Scope (narrowing) | G45 | No |
| **A8** | Chunk → VectorRecord | V#2–6, V#15 | `uses_model` |
| **A9** | vector hits → Chunks (fetch text and lineage) | V#197 | No |
| **A10** | structured records → Facts | K#34, K#42 | No |
| **A11** | text Chunk → Facts | K#26–33, K#31 | `uses_model` for the LLM variant |
| **A12** | Facts → Subgraph | — | No |
| **A13** | Subgraph / Path → linearized text | K#161 | No (template-based) |
| **A14** | EntityRef → Chunks (through chunk-entity links) | K#159 | No |
| **A15** | Path → explanation text | K#170 (template variant) | No |

The planner (G23) treats each adapter as an edge in the type graph. Lossy and `uses_model` adapters carry extra cost, so the planner only picks them when no cheaper lossless path exists.

## 4. Selection decision tables (DMN-style, G27)

These encode the "when to use what" advice from the three references as rules the engine applies automatically. Hit policy: first matching row wins.

**Table D1: Text search method**

| Need | Pattern type | Corpus size | Index available | → Choose |
|---|---|---|---|---|
| exhaustive | ≤ 64 literals | any | no | Teddy / multi-literal scan (C#12) |
| exhaustive | > 64 literals | any | no | Aho-Corasick (C#24) |
| exhaustive | regex with literal | large | trigram | index query (C#69) + verify (C#72) |
| exhaustive | regex | small/medium | no | lazy-DFA scan (C#38) |
| exhaustive | code structure | any | — | tree-sitter / ast-grep (C#81, C#82) |
| exhaustive | symbol identity | any | LSP or SCIP | references (C#90, C#91) |
| exploratory | concept, unknown names | any | vectors | hybrid search (V#86) |
| near-match | snippet with drift | one file | — | Bitap / Myers fuzzy (C#23, C#28) |

**Table D2: Edit method**

| Change shape | Sites | Language tooling | → Choose |
|---|---|---|---|
| rename symbol | any | LSP rename available | LSP rename (C#90) → WorkspaceEdit |
| uniform pattern | > 20 | codemod engine available | pattern → template rewrite (C#132) |
| uniform pattern | > 20 | none | Comby (C#84) |
| non-uniform | ≤ 20 | any | exact search/replace (C#125) |
| path-sensitive (C) | any | Coccinelle | semantic patch (C#133) |
| public API change | any | any | expand-and-contract recipe (R4) |

**Table D3: Vector index**

| Vectors | Memory budget | Update rate | Filters | → Choose |
|---|---|---|---|---|
| < 200k | any | any | any | exact flat search (V#51) |
| ≤ RAM | enough | high | rare | HNSW (V#66) |
| ≤ RAM | enough | high | frequent, arbitrary | HNSW + in-graph filtering (V#82) |
| > RAM | tight | low/medium | any | IVF-PQ + re-scoring (V#62, V#93) |
| > RAM, SSD available | tight | medium | label-based | DiskANN / Filtered-DiskANN (V#69, V#75) |
| any | any | any | hard tenant boundary | per-tenant partitions (V#84) |

**Table D4: Graph question answering mode**

| Question type | Template exists | Entities linked | → Choose |
|---|---|---|---|
| frequent, structured | yes | yes | parameterized template (K#61) |
| structured, novel | no | yes | text-to-query + validate/repair (K#151–153) |
| about specific entities | — | yes | local search / subgraph (K#156, K#157) |
| how are X and Y related | — | both | path retrieval (K#158) |
| corpus-wide themes | — | — | global community search (K#155) |
| linking failed | — | no | hybrid vector + graph (K#159), then ask for clarification |

## 5. Recipe library (HTN methods, G21)

Each recipe is a method the planner can choose and adapt. Each lists its goal, steps, branches, loop and stop condition, scope rule and model usage. Recipes can call other recipes (G17).

### R1. Exhaustive find

- **Goal:** every occurrence of a pattern within scope, with exact locations.
- **Steps:**
  1. List files (C#7)
  2. Filter ignored, binary and generated files (C#3, C#5, C#8)
  3. Choose a search method with D1
  4. Verify candidates (C#72)
  5. Dedupe on (path, range) (C#67)
  6. Count
- **Branches:** if a trigram index exists and is fresh, use it, but verify against the working tree. If the language is unknown, use text search only and flag the results.
- **Stop:** the search is complete when it finishes without truncation (C#73).
- **Scope:** the repo, path and language predicate. Exclusions are recorded.
- **Models:** none.

### R2. Safe bulk replace

- **Goal:** replace a pattern everywhere in scope, verified.
- **Steps:**
  1. R1, recording the expected count (C#R4-style)
  2. Choose an edit method with D2
  3. Run fixtures and the idempotency check (C#182, C#126)
  4. Dry run (C#157)
  5. Detect overlaps (C#121)
  6. Batch by owner (C#172, C#186)
  7. For each batch: worktree (C#162), apply in reverse order (C#120) with hash preconditions (C#159), atomic writes (C#158), preserve file identity (C#165)
  8. Verify with parse, format and type checks (C#177–179)
  9. Run impacted tests (C#180)
- **Loop:** re-run R1 until zero old matches remain (C#184, G33). Maximum 3 rounds.
- **Branches:** if the actual count differs from expected, stop and re-plan (R4 rule). If verification fails, roll back the batch (C#161) and mark its rule faulty.
- **Models:** none.

### R3. Symbol rename

- **Goal:** rename one resolved symbol and every reference to it.
- **Steps:**
  1. Resolve the symbol (C#87–91)
  2. Get the references (C#90 or C#91)
  3. Check for conflicts (C#138)
  4. Text search for non-code uses (configs, strings, docs), as a separate list for review (C#77)
  5. Build one changeset (C#118)
  6. Run the R2 application steps
- **Loop:** the post-condition is that the symbol has zero remaining resolved references.
- **Branches:** if the symbol is public or serialized, switch to R4.
- **Models:** none.

### R4. API migration (expand and contract)

- **Goal:** move every caller from an old API to a new one, across repos.
- **Steps:**
  1. Expand changeset (add the new API)
  2. Merge it
  3. Run a campaign (C#187) of R2 per repo, in topological order of the dependency graph (C#170)
  4. Ratchet against new uses of the old API (C#190)
  5. Track the burndown (C#191)
  6. When the count is zero for N days, contract (remove the old API, with approval G5)
- **Loop:** regenerate stale pull requests on the new base (C#188) until merged or closed.
- **Models:** none required. An LLM is optional only for the leftover sites a codemod can't handle.

### R5. Duplicate code consolidation report

- **Goal:** find clone groups and propose a fix per group.
- **Steps:**
  1. Subtree hashing (C#85) and LCP repeats (C#48)
  2. MinHash similarity for near clones (C#31)
  3. Cluster the matches (C#38-style)
  4. Rank the clusters by size and churn
  5. Report the groups with locations
- **Branches:** groups in generated or vendored code are excluded.
- **Models:** none.

### R6. Build or refresh a vector index

- **Goal:** a searchable, validated index for a corpus.
- **Steps:**
  1. List sources
  2. Structure-aware chunking (V#13)
  3. Content-hash dedupe (V#124)
  4. Embedding cache lookup (V#50); embed only the misses (V#14)
  5. Normalize (V#15) and validate the vectors (V#172)
  6. Choose an index with D3
  7. Bulk load into a new index (V#148)
  8. Autotune parameters (V#110)
  9. Golden-set check (V#164)
  10. Reconcile counts (V#198)
  11. Warm the cache and swap the alias (V#123)
- **Branches:** if recall is below target, raise ef or nprobe, or the re-score factor, then re-check (G33, maximum 3 rounds).
- **Models:** embedding model calls only for cache misses.

### R7. Hybrid retrieval for a question

- **Goal:** the top evidence for a question, within a token budget.
- **Steps:**
  1. Route the query (V#98)
  2. Run BM25 and vector search in parallel, both with access filters inside the search (V#85, V#66, V#80)
  3. RRF fusion (V#87)
  4. Re-score (V#93)
  5. Optional rerank (V#94)
  6. MMR diversity (V#89)
  7. Calibrated cutoff (V#20)
  8. Assemble the evidence bundle (T20)
- **Branches:** if the top score is below the calibrated threshold, report "not covered" (V#177) instead of padding.
- **Models:** the query embedding; a cross-encoder only if reranking is enabled.

### R8. Embedding model migration

- **Goal:** move the corpus to a new embedding model with zero downtime.
- **Steps:**
  1. New index (V#121)
  2. Dual-write (V#122)
  3. Checkpointed backfill from the source data (V#130)
  4. Reconcile (V#198)
  5. Golden-set comparison and shadow traffic (V#164, V#196)
  6. Alias swap (V#123)
  7. Keep the old index for the rollback window
  8. Delete the old index after approval
- **Branches:** if shadow quality regresses, stop and keep the old index.
- **Models:** embedding calls for the whole corpus. This needs approval and a cost estimate (VG5).

### R9. Verified erasure across all stores

- **Goal:** a subject's data is gone from the code, vector and graph stores, and from everything derived.
- **Steps:**
  1. Resolve every ID through lineage (V#197, K#193)
  2. Delete from the vector indexes (V#150), the graph (K#185) and the caches (V#104–105)
  3. Propagate to derived data: inferences (K#91), summaries (K#176), memory (K#167)
  4. Verify with ID, content and similarity searches (V#150)
  5. Record the evidence and the backup expiry dates
- **Loop:** re-verify until zero hits, maximum N rounds, then escalate.
- **Priority:** the highest queue priority (V#132).
- **Models:** none, except embedding the deleted text once, for the similarity check.

### R10. Knowledge graph construction from sources

- **Goal:** validated facts from structured and unstructured sources.
- **Steps:**
  1. Structured sources first: mappings (K#34, K#42), producing facts
  2. Text sources: segmentation (K#25), then NER (K#26), coreference (K#28) and relation extraction (K#29 or K#31)
  3. Normalize values (K#33)
  4. Link entities (K#27)
  5. Entity resolution with blocking, Fellegi-Sunter and clustering (K#35–38)
  6. Canonicalize (K#39–40)
  7. Validate shapes (K#5)
  8. Truth discovery for conflicts (K#50)
  9. MERGE writes (K#172), with review for low-confidence facts (K#169)
- **Branches:** if the zero-model mode is required, use only structured sources plus rule- or dictionary-based extraction (K#6, K#26 with gazetteers). LLM extraction (K#31) is disabled.
- **Models:** optional (K#31).

### R11. Answer a question from the graph

- **Goal:** a correct, cited answer, or an honest "not found".
- **Steps:**
  1. Link entities (K#154)
  2. Choose a mode with D4
  3. Run it with limits (K6)
  4. Linearize the facts (K#161)
  5. Grounded answer with citations (K#162)
  6. Hallucination check (K#164)
- **Branches:** if the template fails, try text-to-query with up to N repairs. If that fails, fall back to local search, then hybrid retrieval (R7). If everything fails, say "can't answer from the graph" (G94 ladder).
- **Models:** none for templates and template-based verbalization (K#170). Text-to-query and generated answers use an LLM.

### R12. Keep the graph and vectors synced from change data capture

- **Goal:** continuous freshness for both stores.
- **Steps:**
  1. CDC stream (K#171, V#125), partitioned by key
  2. Per event: version check (V#129)
  3. Chunk and embed only changed content (V#124, V#50)
  4. Upsert vectors (V#111) and MERGE facts (K#172)
  5. Propagate to derived data (K#175)
  6. Track watermarks (V#128)
- **Priority:** deletes first (V#132).
- **Loop:** continuous dataflow (G14) with backpressure (G73).
- **Models:** embeddings for changed chunks only.

### R13. Index health maintenance loop

- **Goal:** keep vector and graph indexes within their health targets.
- **Steps:**
  1. Measure: tombstone ratio (V#184), list balance (V#173), graph reachability (V#183), recall sample (V#157), supernodes (K#180), constraint violations (K#187)
  2. Decide with a rule table (G26)
  3. Act: compact (V#115), repair (V#117), retrain (V#120), or rebuild and swap (V#146–147, V#123)
  4. Re-measure
- **Loop:** scheduled. Each action is followed by re-measurement.
- **Models:** none.

### R14. Retrieval quality regression gate

- **Goal:** block any change that makes retrieval worse.
- **Steps:**
  1. Golden sets: code (C#182), vector (V#164), graph QA (K#194, K#195)
  2. Run the baseline and the candidate
  3. Compare metrics per segment (V#156–161)
  4. Interleaving or shadow test if available (V#166, V#196)
  5. Pass or fail against tolerances
- **Branches:** on fail, cluster the failures (V#194) and report them.
- **Models:** only if an LLM judge (V#163) is enabled. Labeled sets need no model.

### R15. Recall drop diagnosis

- **Goal:** find why retrieval quality dropped.
- **Steps:**
  1. Confirm with ground-truth sampling (V#157)
  2. Check what changed: deployments, model or prefix (V#6), drift (V#168–171), index health (R13), freshness (V#182), filters (V#83)
  3. Run query explain on failing queries (V#191)
  4. Cluster the failures (V#194)
  5. Map them to a cause, then pick the matching recipe (R6, R8 or R13)
- **Branches:** the first check that fails points to the cause, as a decision tree.
- **Models:** none.

## 6. Global invariants (enforced by the engine on every combination, G48)

1. **Scope never widens** (G45). Every step's targets are inside the flow's scope.
2. **Exhaustiveness is preserved.** An `approximate` or lossy step can never feed an input marked `exhaustive` (edit scopes, deletions, post-conditions).
3. **No write without a precondition.** Every write carries the content hash or version of what it read (C#159, V#129, K#172).
4. **Every write is idempotent and recorded:** an idempotency key (G40), lineage (G46), and an audit entry (K#198).
5. **One vector space per comparison.** Never compare or fuse scores from different models or versions (V2). Use rank fusion (V#87) across sources.
6. **Access filters inside search, never after** (VG1, KG1). That includes caches and coalesced requests (G72).
7. **Fact status stays visible:** asserted, extracted, inferred and predicted are never merged into one status (K2).
8. **Every loop has a budget and a stop condition** (G33, G34), and ideally a ranking function (G100).
9. **Deletes outrank everything** in queues, propagation and verification.
10. **Model calls are opt-in per plan.** The default plan uses only steps without `uses_model`, unless the goal can't be met otherwise. In that case, the planner reports the extra cost before running.

---
