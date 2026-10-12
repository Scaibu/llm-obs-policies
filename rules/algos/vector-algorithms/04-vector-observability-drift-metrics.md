# Part 4: Observability (#156–200)

Same format and the same contract (roles; rules V1–V8; guardrails VG1–VG6). This is the final part.

## D1. Retrieval quality metrics

### 156. Recall@k (against exact ground truth)

**Definition:** The fraction of the true k nearest neighbors that the approximate index actually returned.

### 157. Ground-truth sampling (shadow brute force)

**Definition:** Continuously computing exact results for a small sample of real queries, to monitor live recall.

### 158. Precision@k

**Definition:** The fraction of the top k results that are actually relevant to the query.

### 159. Mean Reciprocal Rank (MRR)

**Definition:** The average of 1 / (rank of the first relevant result) across queries.

### 160. nDCG (normalized discounted cumulative gain)

**Definition:** A ranking metric that rewards placing highly relevant results near the top, with graded relevance.

### 161. Hit rate (success@k)

**Definition:** The fraction of queries where at least one relevant result appears in the top k.

### 162. Relative distance error

**Definition:** How much worse the returned neighbors' distances are than the true neighbors' distances.

### 163. LLM-as-judge relevance evaluation

**Definition:** Using a language model to label retrieved results as relevant or not, at scale.

### 164. Golden query set regression testing

**Definition:** A fixed, curated set of queries with known relevant results, run against every retrieval change.

### 165. Online implicit feedback

**Definition:** Learning about retrieval quality from user behavior: clicks, citations used, follow-up questions, "thumbs down".

### 166. Interleaving experiments

**Definition:** Comparing two rankers by merging their results into one list and seeing which one's results users prefer.

### 167. Faithfulness and groundedness (RAG evaluation)

**Definition:** Whether a generated answer is actually supported by the retrieved passages.

## D2. Embedding drift and distribution monitoring

### 168. Centroid shift

**Definition:** Measuring how far the average embedding (or the cluster centers) of new data has moved from a reference period.

### 169. Maximum Mean Discrepancy (MMD)

**Definition:** A statistical test for whether two sets of vectors come from the same distribution.

### 170. PSI and KS tests on projections

**Definition:** Detecting drift by comparing the distributions of individual projected dimensions between periods.

### 171. Similarity score distribution monitoring

**Definition:** Tracking the distribution of retrieval scores (for example the top-1 and top-k cosine scores) over time.

### 172. Vector norm distribution

**Definition:** Monitoring the lengths of the vectors being written and queried.

### 173. Partition and cluster balance

**Definition:** Measuring how evenly vectors are spread across IVF lists, partitions or shards.

### 174. Hubness measurement (k-occurrence skew)

**Definition:** Measuring how unevenly vectors appear in other vectors' nearest-neighbor lists.

### 175. Intrinsic dimensionality estimation

**Definition:** Estimating how many dimensions the data really uses, regardless of the vector length.

### 176. Outlier detection on embeddings

**Definition:** Finding vectors that are unusual compared to the rest of the corpus.

### 177. Query out-of-distribution (OOD) detection

**Definition:** Detecting queries that fall outside what the corpus covers.

## D3. System metrics and SLOs

### 178. Latency histograms and percentiles

**Definition:** Recording the distribution of request latency, and reporting percentiles (p50, p95, p99), not averages.

### 179. RED and USE methods

**Definition:** Two checklists of core metrics. RED for services (Rate, Errors, Duration) and USE for resources (Utilization, Saturation, Errors).

### 180. SLOs and error-budget burn rate

**Definition:** Explicit targets for reliability (for example "99% of searches under 200 ms"), and alerts based on how fast the allowed failures are being used up.

### 181. Distributed tracing (OpenTelemetry)

**Definition:** Following one request across all services, with timing for each step, linked by a shared trace ID.

### 182. Freshness lag (ingest-to-searchable)

**Definition:** The time between a change at the source and that change being reflected in search results.

### 183. Graph index health

**Definition:** Monitoring the structural quality of graph-based ANN indexes.

### 184. Tombstone ratio

**Definition:** The share of stored vectors that are marked deleted but not yet physically removed.

### 185. Cache hit ratio and memory pressure

**Definition:** Monitoring how often data is found in memory, and whether memory is running out.

### 186. Capacity planning with Little's Law

**Definition:** Relating throughput, latency and concurrency to size the system: L = λ × W.

### 187. Consumer lag (stream backlog)

**Definition:** How far behind the ingestion consumers are relative to the newest events in the stream.

### 188. Cardinality-safe metric labels

**Definition:** Designing metric labels (dimensions) so the number of distinct time series stays bounded.

### 189. Anomaly detection on metrics

**Definition:** Automatically detecting unusual metric behavior, with smoothing and seasonality.

### 190. Quantile sketches (t-digest, DDSketch)

**Definition:** Compact data structures that estimate percentiles from huge streams, and can be merged across machines.

## D4. Debugging, audit and feedback

### 191. Query explain (per-stage breakdown)

**Definition:** A per-query report of what each retrieval stage did: candidates in, candidates out, timing and decisions.

### 192. Retrieval trace logging with sampling

**Definition:** Recording, for a sample of requests, the full context of a retrieval: query, parameters, results and versions.

### 193. Embedding-space visualization

**Definition:** Projecting embeddings to 2D or 3D to visually inspect structure, clusters and problems.

### 194. Failure clustering

**Definition:** Grouping failed retrievals by similarity to find shared root causes.

### 195. Canary queries and synthetic probes

**Definition:** Fixed test queries and test documents that run continuously to check the system end to end.

### 196. Shadow traffic comparison

**Definition:** Sending a copy of real queries to a new configuration and comparing its results with production, without affecting users.

### 197. Data lineage

**Definition:** Being able to trace any vector back to its source data and the exact transformations that produced it.

### 198. Reconciliation checks

**Definition:** Regularly comparing what should be in the index with what is actually there.

### 199. Cost per query and per item

**Definition:** Measuring what each retrieval and each indexed item costs, across all components.

### 200. Feedback loop into improvement

**Definition:** Systematically turning observed failures into fixes, test cases and training data.

---

## How the 200 entries fit together

1. **Transform (Transformer):** chunk (#11–13), embed with the right prefix and pooling (#1–6), normalize (#15–18), cache by content hash (#50), and validate vectors before writing (#172).
2. **Index (Indexer):** choose the index by scale and dimension (#57–79), compress if needed (#33–46), and declare filter fields (#154).
3. **Search (Retriever):** hybrid retrieval (#85–88), filters inside the search (#80–84), re-scoring (#93), reranking (#94–96), MMR (#89), with bounded k and access filters on every query.
4. **Update:** upserts with stable IDs (#111), CDC or an outbox (#125–126), idempotency (#129), deletes first (#132), tombstones and compaction (#115–117), migrations with dual-write and alias swaps (#121–123).
5. **Observe (Observer):** recall against ground truth (#156–157), golden-set regression (#164), drift (#168–177), SLOs on latency, freshness and recall (#178–182), probes (#195), reconciliation (#198), and the feedback loop (#200).
