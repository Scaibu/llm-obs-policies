# Part 2: Vector search (#51–110)

Same format and the same contract (roles; rules V1–V8; guardrails VG1–VG6).

## B1. Exact search and distance computation

### 51. Brute-force kNN with matrix multiplication (GEMM)

**Definition:** Exact nearest-neighbor search that scores the query against every vector, done as one matrix multiply.

### 52. SIMD distance kernels

**Definition:** Computing dot products and distances many components at a time using vector instructions.

### 53. Top-k selection with a heap

**Definition:** Keeping the k best results while scanning many candidates.

### 54. GPU top-k selection

**Definition:** Selecting the k smallest or largest values out of millions of scores on a GPU.

### 55. Early abandoning (partial distance computation)

**Definition:** Stopping a distance calculation as soon as it's certain to be worse than the current k-th best.

### 56. Triangle-inequality pruning (pivots)

**Definition:** Using precomputed distances to reference points (pivots) to skip vectors that can't be close to the query.

## B2. Tree and partition indexes

### 57. KD-tree

**Definition:** A binary tree that recursively splits space along one coordinate at a time.

### 58. Ball tree

**Definition:** A tree where each node is a hypersphere (center and radius) containing its points.

### 59. VP-tree (vantage-point tree)

**Definition:** A tree that splits points by their distance to a chosen vantage point: inside versus outside a radius.

### 60. Random projection tree forest (Annoy-style)

**Definition:** Many trees, each splitting space by random hyperplanes, searched together.

### 61. IVF (inverted file index)

**Definition:** Partitioning vectors into clusters and searching only the clusters nearest the query.

### 62. IVF-PQ

**Definition:** IVF partitioning combined with product-quantized codes inside each list.

### 63. nprobe and multi-probe tuning

**Definition:** Choosing how many partitions to search per query: the main speed/recall dial in IVF-style indexes.

### 64. Inverted multi-index (IMI)

**Definition:** An IVF variant that splits vectors in two halves and clusters each half separately, producing a very large number of fine cells.

## B3. Graph indexes

### 65. NSW (navigable small world graph)

**Definition:** A proximity graph where each vector links to nearby vectors, plus some long links, so greedy walking finds near neighbors fast.

### 66. HNSW search

**Definition:** Searching a layered navigable graph: coarse greedy steps in sparse top layers, then a careful search in the dense bottom layer.

### 67. HNSW insertion and neighbor-selection heuristic

**Definition:** How new vectors join the HNSW graph, with pruning that keeps the links diverse.

### 68. Beam search on graphs (ef / L parameter)

**Definition:** Exploring a proximity graph with a bounded list of best candidates instead of a single greedy path.

### 69. Vamana / DiskANN

**Definition:** A single-layer proximity graph designed for SSD-resident billion-scale search.

### 70. RobustPrune (α-pruning)

**Definition:** The neighbor-pruning rule in Vamana that keeps diverse links and, with α > 1, long-range ones.

### 71. NSG (navigating spreading-out graph)

**Definition:** A single-layer graph built from an approximate kNN graph, with pruning that guarantees the graph is navigable from one entry point.

### 72. CAGRA (GPU-built graph)

**Definition:** A proximity graph designed for building and searching on GPUs.

### 73. Entry-point selection

**Definition:** Choosing where graph search begins, which strongly affects speed and recall.

### 74. Graph connectivity repair

**Definition:** Detecting and fixing nodes in a proximity graph that are unreachable or poorly connected.

### 75. Filtered-DiskANN (label-aware graphs)

**Definition:** Graph indexes built so that search restricted to a label (tenant, category) still has connected paths.

### 76. SPANN (memory-disk hybrid partitions)

**Definition:** An IVF-like design keeping centroids in memory and posting lists on disk, with boundary vectors duplicated into several lists.

## B4. Hashing indexes

### 77. Random-hyperplane LSH

**Definition:** Hashing vectors with random hyperplane bits, so similar vectors land in the same bucket with high probability.

### 78. Multi-probe LSH

**Definition:** LSH that also checks buckets near the query's bucket, reaching the same recall with fewer tables.

### 79. E2LSH (p-stable LSH for L2)

**Definition:** LSH for Euclidean distance, using random projections divided into fixed-width slots.

## B5. Filtering, hybrid search and fusion

### 80. Pre-filtering

**Definition:** Applying metadata filters first, then searching only the vectors that pass.

### 81. Post-filtering with oversampling

**Definition:** Searching without filters, then removing results that fail the filter, retrieving extra results to compensate.

### 82. In-graph filtering (ACORN-style)

**Definition:** Graph search that traverses only allowed nodes, with a denser graph so the allowed subgraph stays navigable.

### 83. Selectivity-based query planning

**Definition:** Choosing the search strategy for each query from how many vectors pass its filter.

### 84. Partitioned (per-tenant or per-collection) indexes

**Definition:** Keeping a separate index for each tenant, collection or other hard boundary.

### 85. BM25 keyword retrieval

**Definition:** Classic keyword relevance scoring, used as the sparse half of hybrid search.

### 86. Sparse-dense hybrid retrieval

**Definition:** Running keyword (sparse) and semantic (dense) retrieval together and combining the results.

### 87. Reciprocal Rank Fusion (RRF)

**Definition:** Combining ranked lists using only ranks: score = Σ 1 / (k + rank).

### 88. Score-normalized fusion (convex combination)

**Definition:** Normalizing each channel's scores to a common scale, then combining them with weights.

### 89. Maximal Marginal Relevance (MMR)

**Definition:** Re-ranking to balance relevance and diversity, so the results aren't near-duplicates of each other.

### 90. Range (radius) search

**Definition:** Returning all vectors within a distance threshold, instead of a fixed k.

### 91. Multi-vector (MaxSim) retrieval pipelines

**Definition:** Searching with token-level vectors (late interaction), usually in candidate-generation plus exact-scoring stages.

### 92. Multi-query expansion

**Definition:** Rewriting one query into several variants, searching each, and fusing the results.

## B6. Re-scoring and reranking

### 93. Re-scoring with full-precision vectors

**Definition:** Retrieving extra candidates with a compressed index, then re-ranking them with full-precision vectors.

### 94. Cross-encoder reranking

**Definition:** Re-scoring the top candidates with a model that reads the query and the candidate text together.

### 95. Multi-stage retrieval funnel

**Definition:** A pipeline of progressively more expensive, more accurate scoring stages over shrinking candidate sets.

### 96. LLM listwise reranking

**Definition:** Asking a language model to order a small list of candidates by relevance to the query.

### 97. HyDE (hypothetical document embeddings)

**Definition:** Generating a hypothetical answer to the query, embedding that, and searching with it.

### 98. Query routing

**Definition:** Deciding which index, collection or retrieval strategy a query should go to.

## B7. Distributed search and performance

### 99. Sharded scatter-gather search

**Definition:** Splitting the vector collection across shards, querying all of them in parallel, and merging results.

### 100. Partition-aware shard routing

**Definition:** Placing vectors on shards by cluster, so each query only needs a few shards.

### 101. Replication and load balancing

**Definition:** Keeping several copies of each shard and spreading queries across them.

### 102. Hedged requests

**Definition:** Sending a backup request to another replica when the first is slow, and using whichever answers first.

### 103. k-way merge of shard results

**Definition:** Combining sorted top-k lists from many shards into one global top k.

### 104. Query-embedding and result caching

**Definition:** Caching the embedding of repeated queries, and the results of repeated searches.

### 105. Semantic cache

**Definition:** Reusing a previous answer when a new query is semantically close to a cached one.

### 106. Query batching

**Definition:** Grouping concurrent queries into batches, so they're processed together for better hardware utilization.

### 107. Memory tiering (RAM, mmap, SSD)

**Definition:** Placing hot index data in RAM and colder data on SSD, often through memory-mapped files.

### 108. Disk I/O scheduling for disk-based ANN

**Definition:** Organizing SSD reads during graph or partition search to minimize latency.

### 109. Admission control and rate limiting

**Definition:** Limiting incoming query and ingestion load so the system stays healthy under overload.

### 110. Search-parameter autotuning

**Definition:** Automatically choosing index parameters (ef, nprobe, re-score factor) to meet a recall target at the lowest latency.
