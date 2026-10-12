This is a new reference: **320 advanced and critical graph algorithms**, in 7 parts. Same format as before, with one addition: a **Complexity** line, because for graph algorithms the cost often decides whether an algorithm is usable at all.

To avoid repeating earlier references, basics already covered in depth are cross-referenced (K# = knowledge graph reference, G# = glue reference) and only expanded where there's an important advanced variant.

**Map of all 320 entries:**
- **Part 1 (#1–50): Representations, traversal, shortest paths.**
- **Part 2 (#51–100): Connectivity, trees, flows, cuts, matching, routing problems.**
- **Part 3 (#101–150): Centrality, similarity, dense structures, network measures, random graph models.**
- **Part 4 (#151–200): Communities, partitioning, spectral methods, coloring, isomorphism, structural decompositions.**
- **Part 5 (#201–250): Dynamic, streaming, temporal, parallel and distributed graph processing.**
- **Part 6 (#251–300): Graph embeddings, advanced GNNs, probabilistic graphical models, causal graphs, program analysis on graphs.**
- **Part 7 (#301–320): Graphs in systems: scheduling, memory management, networking, layout, geometry, security.**

---

# Graph agent contract (referenced in every entry)

| Role | Job | Can write? |
|---|---|---|
| **Builder** | Constructs, transforms and indexes graph representations | Derived structures only |
| **Analyst** | Runs read-only computations: paths, centrality, communities, metrics | No |
| **Optimizer** | Solves optimization problems: flows, matching, routing, partitioning | No (produces proposals) |
| **Verifier** | Checks results with certificates, invariants and cross-checks | No |
| **Operator** | Applies approved results to real systems | Through approved plans only |

**Rules:**
- **GR1. Pin a snapshot:** every computation runs on a fixed graph version, recorded with the result.
- **GR2. Declare assumptions:** directed or undirected, weighted or not, negative weights allowed or not, multi-edges, self-loops. They're checked before running.
- **GR3. Estimate cost first:** compute the expected time and memory from |V|, |E| and the complexity, and refuse runs over budget.
- **GR4. Label exact versus approximate:** approximate results state their error bound or confidence.
- **GR5. Deterministic runs:** fixed seeds, fixed tie-breaking, recorded parameters.
- **GR6. Certificates where possible:** use results that prove themselves (a cut proving a flow is maximal, a negative cycle proving infeasibility) and verify them independently.
- **GR7. Bounded output:** result limits, and summaries before full results.
- **GR8. Results are proposals:** computed answers about real systems or people are acted on only through the Operator, with approval.

**Guardrails:**
- **GX1. Resource caps:** memory, time and visited-node limits for every algorithm.
- **GX2. Supernode protection:** degree-aware limits on expansion (K#180).
- **GX3. No sensitive inference:** don't infer protected attributes from structure (communities, similarity) without governance approval.
- **GX4. Human approval for actions:** routing changes, partition moves, fraud or risk flags, infrastructure changes.
- **GX5. Verify before trust:** run independent checks on results that drive decisions.

---

# PART 1: REPRESENTATIONS, TRAVERSAL AND SHORTEST PATHS

## A1. Representations and core structures

### 1. Adjacency matrix

**Definition:** A |V| × |V| matrix where entry (i, j) holds the edge weight (or 1) if an edge from i to j exists, and 0 otherwise.

**Complexity:** O(n²) memory regardless of edge count. O(1) edge lookup. O(n) to list neighbors.

### 2. Compressed sparse row (CSR) and column (CSC)

**Definition:** A compact array layout for sparse graphs: all neighbors stored contiguously, plus an offset array per vertex. CSR stores out-neighbors; CSC stores in-neighbors.

**Complexity:** O(n + m) memory. O(1) to find a vertex's neighbor range, then O(degree) to scan it. Updates are expensive (rebuild or batch).

### 3. Edge list (COO format)

**Definition:** The simplest representation: a list of (source, target, weight) records.

**Complexity:** O(m) memory. Finding a vertex's neighbors costs O(m) unless the list is sorted or indexed.

### 4. Incidence matrix and hypergraph representation

**Definition:** A vertex × edge matrix (or vertex × hyperedge matrix) marking which vertices belong to which edges. Hyperedges can connect any number of vertices.

**Complexity:** O(total membership count) memory in sparse form.

### 5. Dynamic adjacency structures (hash-set adjacency, packed memory arrays)

**Definition:** Representations that support fast edge insertions and deletions while keeping traversal reasonably fast.

**Complexity:** Updates in O(1) to O(log² n) amortized, depending on the structure. Scans are slower than pure CSR.

### 6. WebGraph compression (BV coding)

**Definition:** Compression for large graphs that exploits locality and similarity of neighbor lists, from the WebGraph framework (Boldi and Vigna).

**Complexity:** Often a few bits per edge for web and social graphs. Decoding cost per neighbor is small but not zero.

### 7. k²-tree (succinct graph representation)

**Definition:** A compact tree representation of the adjacency matrix that recursively skips empty regions.

**Complexity:** Very compact for sparse, clustered graphs. Neighbor queries cost roughly O(degree × log n).

### 8. Bitmap adjacency for dense subsets

**Definition:** Storing neighbor sets as bitmaps, so set operations (intersection, union) run at hardware speed.

**Complexity:** Set intersection in O(n / 64) word operations for plain bitsets, much less with compressed bitmaps.

### 9. Graph reordering for cache locality (RCM, degree sort, Gorder)

**Definition:** Renumbering vertices so that vertices accessed together are stored close together in memory.

**Complexity:** Degree sort O(n log n). RCM O(m). Gorder is more expensive but often gives the biggest speedups.

### 10. Vertex ID mapping (dictionary)

**Definition:** The two-way mapping between external identifiers (strings, UUIDs) and dense internal integer IDs.

**Complexity:** O(n) memory. O(1) expected lookups.

### 11. Multigraph and property-graph indexing by edge type

**Definition:** Organizing each vertex's edges by type and direction, so typed traversals don't scan unrelated edges.

**Complexity:** Slight extra overhead for the offsets. Typed traversal becomes O(typed degree) instead of O(total degree).

### 12. Hierarchical and multi-level graph representations

**Definition:** Representing a graph at several levels of detail, with coarse summary graphs above detailed ones.

**Complexity:** Building costs about O(m) per level with matching-based coarsening.

## A2. Traversal

### 13. Direction-optimizing BFS (Beamer's algorithm)

**Definition:** A BFS that switches between pushing from the frontier ("top-down") and pulling into unvisited vertices ("bottom-up"), depending on the frontier size.

**Complexity:** Still O(n + m) in the worst case, but often several times faster on real graphs.

### 14. Iterative DFS with edge classification

**Definition:** Depth-first search with an explicit stack that classifies every edge as a tree, back, forward or cross edge.

**Complexity:** O(n + m) time. O(n) memory for the stack.

### 15. Iterative deepening DFS (IDDFS)

**Definition:** Repeated depth-limited DFS with increasing depth limits. It finds shallow targets with BFS-like guarantees using DFS-level memory.

**Complexity:** O(b^d) time for branching factor b and depth d, with O(d) memory.

### 16. Lexicographic BFS (LexBFS)

**Definition:** A BFS variant that breaks ties using the order of previously visited neighbors, producing orderings with strong structural properties.

**Complexity:** O(n + m) with partition refinement.

### 17. Level-synchronous parallel BFS

**Definition:** BFS that processes each level's frontier in parallel across threads or machines.

**Complexity:** O(n + m) work. The span is proportional to the diameter.

### 18. Random walks and walk sampling

**Definition:** Generating sequences of vertices by moving to random neighbors, used for estimation, sampling and embeddings.

**Complexity:** O(walk length) per walk, with O(1) sampling per step using alias tables.

### 19. Euler tour technique

**Definition:** Turning a tree into a sequence by walking around it (each edge traversed down and up), so tree questions become array questions.

**Complexity:** O(n) to build. Fast range queries afterwards.

### 20. Topological sort and longest-path layering on DAGs

**Definition:** Ordering a DAG's vertices so every edge points forward, and assigning layers by longest path.

**Complexity:** O(n + m).

### 21. Cycle detection and cycle enumeration (Johnson's algorithm)

**Definition:** Detecting whether cycles exist, and listing all elementary cycles when needed.

**Complexity:** Detection O(n + m). Enumeration O((n + m)(c + 1)) for c cycles, and c can be exponential.

### 22. Bipartiteness testing (2-coloring)

**Definition:** Deciding whether vertices can be split into two groups with every edge crossing between the groups.

**Complexity:** O(n + m).

## A3. Shortest paths

### 23. Dijkstra with advanced priority queues

**Definition:** Dijkstra's algorithm (K#66) implemented with the priority queue best suited to the graph.

**Complexity:** As listed above, depending on the queue.

### 24. Bellman-Ford with negative cycle detection

**Definition:** Shortest paths with negative edge weights allowed, which also detects negative cycles.

**Complexity:** O(n × m).

### 25. SPFA (queue-based Bellman-Ford)

**Definition:** A Bellman-Ford variant that only re-processes vertices whose distance just changed.

**Complexity:** Worst case O(n × m), like Bellman-Ford, and adversarial inputs reach it. Often much faster on real data.

### 26. Johnson's algorithm (all-pairs with reweighting)

**Definition:** All-pairs shortest paths on sparse graphs with negative weights, by reweighting so that Dijkstra can be used.

**Complexity:** O(n × m log n) total.

### 27. Floyd-Warshall

**Definition:** All-pairs shortest paths by dynamic programming over intermediate vertices.

**Complexity:** O(n³) time, O(n²) memory.

### 28. Shortest and longest paths in DAGs

**Definition:** Linear-time path optimization on acyclic graphs, by processing vertices in topological order.

**Complexity:** O(n + m).

### 29. 0-1 BFS

**Definition:** Shortest paths when edge weights are only 0 or 1, using a double-ended queue instead of a priority queue.

**Complexity:** O(n + m).

### 30. Dial's algorithm (bucket queue)

**Definition:** Dijkstra using an array of buckets indexed by distance, for small integer weights.

**Complexity:** O(m + n × C).

### 31. Bidirectional Dijkstra

**Definition:** Point-to-point shortest path by running Dijkstra forward from the source and backward from the target at the same time.

**Complexity:** In practice, often a fraction of one-sided Dijkstra's work.

### 32. ALT (A*, landmarks, triangle inequality)

**Definition:** A* search with lower bounds computed from precomputed distances to a few landmark vertices.

**Complexity:** O(k × n) preprocessing memory. Queries explore far fewer vertices than Dijkstra.

### 33. Contraction Hierarchies (CH)

**Definition:** A preprocessing technique that orders vertices by importance and adds shortcut edges, so queries only go "upward" in importance and touch very few vertices.

**Complexity:** Preprocessing takes minutes for continental road networks. Queries take microseconds to milliseconds, touching only hundreds of vertices.

### 34. Hub labeling

**Definition:** Precomputing for each vertex a small label of (hub, distance) pairs, so the distance between any two vertices comes from their labels alone.

**Complexity:** Queries in microseconds or less. Memory can be large: label size times n.

### 35. Transit node routing

**Definition:** Precomputing distances between a small set of "transit" vertices that almost every long route passes through.

**Complexity:** Extremely fast long-distance queries. Large preprocessing and memory cost.

### 36. Arc flags

**Definition:** Precomputing, for each edge and each region of the graph, whether the edge lies on some shortest path into that region.

**Complexity:** Heavy preprocessing. k bits per edge. Queries explore only the relevant corridor.

### 37. Customizable Route Planning (CRP, multilevel overlay graphs)

**Definition:** A routing technique that separates the stable structure (preprocessed once) from frequently changing weights (applied quickly in a "customization" step).

**Complexity:** Customization in seconds. Queries in milliseconds. Supports frequent weight changes.

### 38. Delta-stepping (parallel single-source shortest paths)

**Definition:** A parallel shortest-path algorithm that processes buckets of vertices with similar distances at the same time.

**Complexity:** Good parallel performance on many graphs. Work depends on Δ and the weight distribution.

### 39. Eppstein's k shortest paths

**Definition:** Finding the k shortest paths between two vertices, allowing repeated vertices (walks), efficiently.

**Complexity:** O(m + n log n + k) after preprocessing.

### 40. Suurballe / Bhandari (disjoint shortest paths)

**Definition:** Finding two (or k) paths between two vertices that share no edges (or no vertices), with minimum total length.

**Complexity:** About two Dijkstra runs.

### 41. Resource-constrained shortest path (label-setting with dominance)

**Definition:** Shortest paths subject to limits on additional resources (time, fuel, budget, number of hops). This is NP-hard in general, but solved well in practice.

**Complexity:** Exponential in the worst case. Dominance makes it practical in many real cases.

### 42. Multi-criteria (Pareto) shortest paths

**Definition:** Finding all paths that are not worse in every criterion than another path: the Pareto front of trade-offs.

**Complexity:** The Pareto front can be exponential. ε-approximation keeps it manageable.

### 43. Time-dependent shortest paths

**Definition:** Shortest paths where an edge's travel time depends on when you enter it (traffic, timetables, network congestion).

**Complexity:** Like Dijkstra for single departure times. Profile queries are much heavier.

### 44. Widest path (maximum bottleneck path)

**Definition:** The path whose smallest edge capacity is as large as possible.

**Complexity:** O(m log n).

### 45. Karp's minimum mean cycle

**Definition:** Finding the cycle with the smallest average edge weight.

**Complexity:** O(n × m).

### 46. Thorup-Zwick distance oracles

**Definition:** A compact structure that answers approximate distance queries between any two vertices quickly, with a guaranteed error bound.

**Complexity:** Query in O(k). Trades memory against accuracy through k.

### 47. Seidel's algorithm (all-pairs for unweighted graphs via matrix multiplication)

**Definition:** All-pairs shortest path lengths in unweighted undirected graphs, using fast matrix multiplication recursively.

**Complexity:** O(M(n) log n), where M(n) is the matrix multiplication cost.

### 48. Multi-source bit-parallel BFS (MS-BFS)

**Definition:** Running many BFS searches at once, using one bit per search in each vertex's state.

**Complexity:** About the cost of a few BFS runs for 64 sources.

### 49. Temporal path queries (earliest arrival, Connection Scan Algorithm)

**Definition:** Finding paths that respect time order (each step must start after the previous one ends), as in transit timetables or event logs.

**Complexity:** O(number of connections) for earliest arrival.

### 50. RAPTOR (round-based public transit routing)

**Definition:** A transit routing algorithm that finds the best journeys for each number of transfers, working on routes and trips without a priority queue.

**Complexity:** Fast in practice, with good cache behavior. Easy to parallelize.

---

Part 2 (#51–100) covers union-find in depth, dynamic connectivity, bridges and articulation points, biconnected and triconnected components (SPQR trees), dominator trees, spanning trees and arborescences, Steiner trees, tree algorithms (LCA, heavy-light, centroid and link-cut trees), maximum flow (Dinic, push-relabel), minimum cuts (Stoer-Wagner, Karger, Gomory-Hu), min-cost flow, matching (Hopcroft-Karp, Hungarian, blossom, auction, stable matching), and routing problems (Euler, Chinese postman, Held-Karp, TSP and vehicle routing heuristics).
