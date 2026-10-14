# Part 5: Dynamic, streaming, temporal, parallel and distributed graph processing (#201–250)

Same format and the same contract (roles; rules GR1–GR8; guardrails GX1–GX5).

## E1. Dynamic graph algorithms

### 201. Dynamic single-source shortest paths (Ramalingam-Reps)

**Definition:** Updating shortest-path distances from a source after edge insertions, deletions or weight changes, touching only the affected vertices.

**Complexity:** Bounded by the size of the change ("output-sensitive"), not the graph size.

### 202. Incremental topological ordering (Pearce-Kelly)

**Definition:** Maintaining a valid topological order of a DAG as edges are added, and detecting immediately when an addition would create a cycle.

**Complexity:** Proportional to the size of the affected region, which is usually small.

### 203. Dynamic minimum spanning tree

**Definition:** Maintaining a minimum spanning tree (or forest) under edge insertions, deletions and weight changes.

**Complexity:** O(log n) insertion with link-cut trees. Polylogarithmic amortized for full dynamics.

### 204. Dynamic PageRank with residual push

**Definition:** Updating PageRank after edge changes by pushing only the resulting "error" through the graph, instead of recomputing from scratch.

**Complexity:** Small per update for typical graphs.

### 205. Incremental triangle counting

**Definition:** Keeping exact triangle counts (global and per vertex) up to date as edges arrive and depart.

**Complexity:** O(min(deg u, deg v)) per update with hash sets.

## E2. Streaming graphs and sketches

### 206. Semi-streaming algorithms (connectivity, matching, spanners in one pass)

**Definition:** Graph algorithms that read edges as a stream, using memory O(n polylog n): enough for the vertices, not for all the edges.

**Complexity:** O(n polylog n) memory, O(1) or polylog time per edge.

### 207. Linear graph sketches (AGM sketches, ℓ₀-sampling)

**Definition:** Small linear summaries of each vertex's edges that support both insertions and deletions, and still allow recovering connectivity and spanning forests.

**Complexity:** O(n polylog n) total space.

### 208. Graph stream frequency sketches (Count-Min, TCM)

**Definition:** Compact, approximate counters for edge frequencies and vertex activity in high-volume graph streams.

**Complexity:** O(d) per update. Memory O(d × w) or O(d × w²).

### 209. Distinct-neighbor counting (per-vertex HyperLogLog)

**Definition:** Estimating how many distinct neighbors each vertex has had in a stream, with small fixed memory per vertex.

**Complexity:** O(1) per update, a few hundred bytes to a few KB per vertex.

### 210. Reservoir sampling of edges

**Definition:** Keeping a fixed-size uniform random sample of all edges seen so far in a stream.

**Complexity:** O(1) per edge, O(k) memory.

### 211. Sliding-window graph maintenance

**Definition:** Maintaining a graph (or its statistics) over only the last W time units or the last N edges, with expiring edges removed.

**Complexity:** Amortized O(1) to O(log n) per edge, depending on the statistic.

## E3. Temporal graphs

### 212. Temporal reachability (foremost, fastest, shortest journeys)

**Definition:** Path problems where edges are only usable at specific times and paths must move forward in time, with several notions of "best".

**Complexity:** About O(number of contacts) for foremost. More for fastest and profiles.

### 213. Temporal motifs (δ-temporal motifs, Paranjape et al.)

**Definition:** Small patterns of edges that happen in a specific order within a time window δ.

**Complexity:** Near-linear in the number of edges for small motifs.

### 214. Temporal graph storage (time-indexed adjacency, event logs, interval structures)

**Definition:** Storing graphs whose edges and vertices exist during time intervals, so that both "graph at time t" and "history of this edge" queries are efficient.

**Complexity:** Trade-off between snapshot frequency (storage) and replay cost (query time).

### 215. Anomaly and change-point detection in graph streams (MIDAS, SpotLight, structural change)

**Definition:** Detecting sudden structural changes or unusual edge activity in streaming graphs, in real time.

**Complexity:** O(1) per edge for MIDAS.

## E4. Parallel graph processing models

### 216. Gather-Apply-Scatter (GAS, PowerGraph model)

**Definition:** A vertex-program model where computation is split into gathering information from edges, applying an update to the vertex, and scattering changes to neighbors. It's designed for power-law graphs.

**Complexity:** O(m) work per superstep, well balanced on skewed graphs.

### 217. Block-centric ("think like a graph") processing

**Definition:** Running whole subgraph partitions as units: each worker solves its partition locally (with sequential algorithms), and partitions only exchange messages at boundaries.

**Complexity:** Supersteps drop from about the graph diameter to about the diameter of the block graph.

### 218. Asynchronous graph processing (GraphLab consistency models)

**Definition:** Updating vertices as soon as possible, using neighbors' latest values, without global barriers between rounds.

**Complexity:** Often less total work than synchronous rounds. Results can vary with timing.

### 219. GPU frontier processing (Gunrock's advance and filter)

**Definition:** A data-centric GPU programming model where algorithms are sequences of operations on frontiers (sets of active vertices or edges).

**Complexity:** Same work as the CPU algorithm, with much higher throughput on suitable graphs.

### 220. GraphBLAS (graph algorithms as sparse linear algebra)

**Definition:** A standard API (the GraphBLAS specification) that expresses graph algorithms as sparse matrix and vector operations over custom semirings.

**Complexity:** Depends on the sparse operation. Optimized libraries are highly efficient.

### 221. Sparse matrix products for graph algorithms (SpMV, masked SpGEMM)

**Definition:** The core sparse matrix operations behind analytics: sparse matrix times vector (SpMV), and sparse matrix times sparse matrix (SpGEMM), often restricted by a mask.

**Complexity:** SpMV O(m). SpGEMM depends on the intermediate products, which masks reduce dramatically.

### 222. Frontier representation switching (sparse lists versus dense bitmaps)

**Definition:** Representing the set of active vertices as a sparse list when it's small and a dense bitmap when it's large, and switching automatically.

**Complexity:** Each step runs in the cheaper of the two modes.

### 223. Ligra (edgeMap and vertexMap)

**Definition:** A lightweight shared-memory framework where graph algorithms are written with two operations over vertex subsets, with automatic push/pull switching.

**Complexity:** Work-efficient. Very fast on multi-core machines.

### 224. Out-of-core graph processing (GraphChi PSW, X-Stream)

**Definition:** Processing graphs larger than RAM by streaming them from disk in a disk-friendly order.

**Complexity:** Several sequential passes over the edges per iteration.

## E5. Distributed graph algorithms

### 225. Distributed BFS with 2D partitioning

**Definition:** Breadth-first search on a cluster, where the adjacency matrix is split into a 2D grid of blocks, reducing communication compared to splitting by vertex.

**Complexity:** O(n + m) total work. Communication per processor is reduced to roughly O(n / √P) per level.

### 226. Distributed triangle counting

**Definition:** Counting triangles in graphs partitioned across machines, minimizing data exchange.

**Complexity:** O(m^1.5) work total. Communication depends heavily on the partitioning.

### 227. Distributed connected components (Shiloach-Vishkin, FastSV, min-label propagation)

**Definition:** Finding connected components in parallel and distributed settings with few rounds.

**Complexity:** O(log n) rounds for Shiloach-Vishkin variants.

### 228. Distributed minimum spanning tree (GHS algorithm)

**Definition:** The Gallager-Humblet-Spira algorithm builds an MST in a network where each vertex is a processor that knows only its own edges and communicates by messages.

**Complexity:** O(n log n + m) messages.

### 229. Distributed subgraph matching (worst-case optimal distributed joins)

**Definition:** Finding pattern matches in distributed graphs, using worst-case optimal joins (K#56) adapted to distributed dataflow, so intermediate results don't explode.

**Complexity:** Worst-case optimal in total work, with bounded memory per batch.

### 230. Factorized representations for query results

**Definition:** Storing query results compactly as a structure of nested unions and products, instead of a flat list of rows, avoiding the blowup of repeated values.

**Complexity:** Results can be exponentially smaller than the flat output.

### 231. Hybrid query plans (binary joins plus worst-case optimal joins)

**Definition:** Query plans that use classic binary joins for acyclic, selective parts of a query and worst-case optimal joins for cyclic parts.

**Complexity:** Avoids worst-case blowups on cyclic patterns while staying fast on simple ones.

## E6. Subgraph enumeration and counting at scale

### 232. Pattern-aware subgraph enumeration systems (AutoMine, GraphPi, Arabesque)

**Definition:** Systems that enumerate all occurrences of patterns (or all subgraphs up to a size) efficiently, by compiling patterns into optimized nested loops or by exploring embeddings systematically.

**Complexity:** Exponential in pattern size. Compiled plans are often much faster than generic exploration.

### 233. Symmetry breaking in subgraph enumeration

**Definition:** Adding ordering constraints so each occurrence of a symmetric pattern is found exactly once, instead of once per symmetry.

**Complexity:** Reduces work by up to the size of the automorphism group.

### 234. Color coding for approximate subgraph counting

**Definition:** Randomly coloring vertices with k colors, then counting only "colorful" occurrences (all vertices differently colored). That's tractable by dynamic programming, and gives an unbiased estimate of the true count.

**Complexity:** O(2ᵏ × m) per coloring for tree patterns: exponential only in k.

### 235. Color coding for path detection (k-path)

**Definition:** Deciding whether a simple path of length k exists, using random colorings, in time exponential only in k.

**Complexity:** O(2ᵏ × eᵏ × m), polynomial for a fixed k.

## E7. Summarization, spanners and approximation structures

### 236. Graph summarization (SWeG and MDL-based summaries)

**Definition:** Grouping vertices into supernodes and edges into superedges, with a small list of corrections, to produce a compact summary of the graph (lossless or lossy).

**Complexity:** Near-linear with MinHash-based candidate grouping (SWeG).

### 237. Compression with virtual nodes (dense subgraph compression)

**Definition:** Replacing dense bipartite blocks (many sources each linked to the same many targets) with a virtual node in the middle, which drastically cuts edge counts.

**Complexity:** Mining is the expensive part. The edge savings can be large on web and social graphs.

### 238. Graph spanners (greedy k-spanner, Baswana-Sen)

**Definition:** A sparse subgraph that approximately preserves all distances: every distance in the spanner is at most k times the original distance (the stretch).

**Complexity:** Greedy O(m × (shortest path cost)). Baswana-Sen about O(k × m).

### 239. Cut sparsifiers (Benczúr-Karger)

**Definition:** A sparse weighted subgraph where every cut has nearly the same weight as in the original graph.

**Complexity:** Near-linear.

### 240. All-distances sketches (bottom-k, ADS)

**Definition:** A small per-vertex sketch that summarizes the vertex's distances to all other vertices, supporting estimates of neighborhood sizes, closeness and similarity.

**Complexity:** O(k log n) expected entries per vertex.

## E8. Engineering for scale and correctness

### 241. High-degree vertex splitting and degree-aware processing

**Definition:** Handling hubs specially (splitting their work, replicating them or processing them differently) so they don't create stragglers or memory spikes.

**Complexity:** Removes the straggler effect of single huge neighbor lists.

### 242. Load balancing for irregular graph work (edge-balanced chunking, merge-path)

**Definition:** Splitting graph work so each thread or machine gets about the same number of edges, not just the same number of vertices.

**Complexity:** O(n) setup with prefix sums, or O(P log n) with binary searches.

### 243. Checkpointing and recovery for graph jobs

**Definition:** Saving the state of long-running iterative graph computations so failures don't restart them from the beginning.

**Complexity:** Checkpoint cost is proportional to the state size.

### 244. Multi-version graph storage (LLAMA, delta chains)

**Definition:** Storing several versions of a graph efficiently by sharing unchanged parts, so analytics can run on stable snapshots while updates continue.

**Complexity:** Storage proportional to the changes. Reads slightly slower than plain CSR, depending on chain length.

### 245. Graph transactions and isolation (snapshot isolation, write skew, locking)

**Definition:** Making concurrent graph updates correct: what anomalies can occur, and which mechanisms prevent them.

**Complexity:** Serializable modes cost extra checks and more aborts.

### 246. Graph query result caching and materialized views

**Definition:** Storing the results of expensive graph queries (paths, neighborhoods, aggregates) and keeping them correct as the graph changes.

**Complexity:** The trade-off is storage and maintenance cost against query savings.

### 247. Ghost and mirror vertices (replica synchronization)

**Definition:** Local copies of remote vertices on each machine, so local computation can read their values without network calls, synchronized after each step.

**Complexity:** Communication proportional to the changed boundary vertices per superstep.

### 248. Incremental view maintenance for graph queries (delta queries, counting)

**Definition:** Updating the results of a graph query when the graph changes, by computing only the effect of the change.

**Complexity:** Proportional to the changes and their local neighborhoods.

### 249. Differential dataflow (incremental iterative computation)

**Definition:** A computation model that keeps iterative algorithms (connected components, shortest paths, PageRank, reachability) up to date under input changes, by tracking differences across both data changes and loop iterations.

**Complexity:** Updates cost roughly proportional to how much the output actually changes.

### 250. Approximate query processing on graphs (sampling with error bounds)

**Definition:** Answering aggregate graph queries (counts, averages, distributions) quickly from samples, with stated error bounds, instead of exact full scans.

**Complexity:** Proportional to the sample size, independent of graph size.

---

Part 6 (#251–300) covers graph embeddings (spectral, LINE, struc2vec, matrix factorization methods, NetMF, ProNE, large-scale partitioned training), advanced GNNs (GIN, APPNP, SGC, heterophily-aware models, positional encodings, higher-order and subgraph GNNs, masked graph pretraining), probabilistic graphical models (belief propagation, junction trees, variable elimination, Gibbs sampling, mean-field inference, CRFs), causal graphs (d-separation, PC/FCI, do-calculus), graph construction from data (graphical lasso, NN-descent), graph-based ranking and recommendation (TextRank, Pixie, P3α/RP3β, PRA, PathSim), network alignment, and program analysis on graphs (IFDS, CFL-reachability, points-to analysis).
