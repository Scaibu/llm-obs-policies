# Part 7: Graphs in systems (#301–320)

Same format and the same contract (roles; rules GR1–GR8; guardrails GX1–GX5). This is the final part.

## G1. Scheduling and build systems

### 301. Register allocation by graph coloring (Chaitin-Briggs)

**Definition:** Assigning program variables to a limited number of CPU registers by coloring an interference graph, the classic compiler use of graph coloring.

**Complexity:** About O(n + m) per round, with a few rounds when spilling.

### 302. Critical path method (CPM) and PERT

**Definition:** Finding the longest chain of dependent tasks in a project DAG, which determines the minimum total duration, and computing each task's slack.

**Complexity:** O(n + m).

### 303. Coffman-Graham scheduling

**Definition:** Scheduling unit-time tasks with dependencies on a fixed number of processors (or arranging a DAG into layers of bounded width), using a lexicographic labeling.

**Complexity:** About O(n² ) straightforwardly, faster with careful implementation.

### 304. HEFT (heterogeneous earliest finish time)

**Definition:** A list-scheduling algorithm for assigning dependent tasks to machines of different speeds, minimizing the total completion time.

**Complexity:** O(n² × p) for n tasks and p machines.

### 305. Build system graphs (early cutoff, constructive traces)

**Definition:** Modeling builds as dependency graphs of tasks and files, and rebuilding only what's actually affected by a change.

**Complexity:** Work proportional to what actually changed.

## G2. Memory and resource graphs

### 306. Tracing garbage collection (mark-sweep, tri-color marking, write barriers)

**Definition:** Finding unused memory by traversing the object graph from roots: everything unreachable is garbage.

**Complexity:** O(live objects + pointers) per collection.

### 307. Cycle collection for reference counting (Bacon-Rajan)

**Definition:** Finding and freeing groups of objects that reference each other in cycles, which plain reference counting never frees.

**Complexity:** Proportional to the subgraph reachable from the candidates.

### 308. Distributed deadlock detection (Chandy-Misra-Haas edge chasing)

**Definition:** Detecting deadlock cycles in a wait-for graph spread across machines, by passing probe messages along wait edges.

**Complexity:** Messages proportional to the edges in the cycle.

## G3. Networks and protocols

### 309. Gossip (epidemic) protocols

**Definition:** Spreading information in a network by having each node repeatedly share what it knows with a few random peers.

**Complexity:** O(log n) rounds. O(n log n) total messages for one update.

### 310. Consensus averaging on graphs (distributed averaging, Laplacian dynamics)

**Definition:** Nodes reach agreement on the average of their initial values by repeatedly averaging with their neighbors.

**Complexity:** O(1/λ₂ × log(1/ε)) rounds.

### 311. Network reliability (terminal reliability, Monte Carlo estimation)

**Definition:** The probability that specified nodes stay connected when edges (or nodes) fail independently with given probabilities.

**Complexity:** Monte Carlo cost is samples × O(m α(n)).

### 312. Link-state and distance-vector routing (OSPF, RIP)

**Definition:** The two classic families of routing protocols: every router computes shortest paths from a full map (link-state), or routers exchange distance estimates with neighbors (distance-vector).

**Complexity:** Link-state: one Dijkstra per router per change. Distance-vector: iterative exchanges.

### 313. Path-vector routing (BGP)

**Definition:** The internet's inter-domain routing: each network announces full paths (lists of networks) to destinations, and chooses routes by policy, not just shortest distance.

**Complexity:** Convergence depends on topology and policies.

### 314. Spanning Tree Protocol (IEEE 802.1D, RSTP)

**Definition:** A distributed protocol that lets Ethernet switches with redundant links agree on a loop-free spanning tree, disabling the extra links until needed.

**Complexity:** Convergence time bounded by protocol timers or handshake rounds.

## G4. Layout and visualization

### 315. Force-directed layout (Fruchterman-Reingold, Barnes-Hut, multilevel)

**Definition:** Drawing graphs by simulating physical forces: edges pull connected vertices together, and all vertices push each other apart.

**Complexity:** O(n log n + m) per iteration with Barnes-Hut.

### 316. Hierarchical (layered) layout (Sugiyama framework)

**Definition:** Drawing directed graphs in layers so most edges point the same way (downward), with few crossings. The standard for dependency and flow diagrams.

**Complexity:** Each step is near-linear to polynomial with heuristics.

### 317. Edge bundling and large-graph visualization

**Definition:** Techniques that make large graphs readable by grouping similar edges into bundles and aggregating vertices.

**Complexity:** Bundling is about O(m × iterations) with spatial acceleration.

## G5. Geometry, maps and security

### 318. Geometric graphs (Delaunay triangulation, Voronoi diagrams, Euclidean MST)

**Definition:** Graphs built from points in space by geometric rules, with useful guarantees for nearest neighbors, coverage and networks.

**Complexity:** O(n log n) in 2D. Higher dimensions grow much more expensive.

### 319. Map matching (hidden Markov model with Viterbi)

**Definition:** Snapping noisy GPS points to the actual road path traveled, by treating road segments as hidden states.

**Complexity:** O(T × k²) shortest-path queries for T points with k candidates each. Speedups from CH (#33) or caching.

### 320. Attack graphs and attack path analysis (MulVAL-style)

**Definition:** Modeling how an attacker could chain vulnerabilities, misconfigurations and access rights through a system to reach critical assets, and finding the most important paths to break.

**Complexity:** Logic-based generation is polynomial in the number of facts (avoids the explosion of state-enumeration approaches).

---

## How the 320 graph algorithms fit together

1. **Represent** (#1–12): choose the structure for the job. Live data in adjacency or base-plus-delta storage; analytics on CSR snapshots with reordering; huge graphs compressed; versions pinned (#244, GR1).
2. **Traverse and route** (#13–50): direction-optimizing BFS for reach; Dijkstra variants or ALT for one-off paths; contraction hierarchies, hub labels or CRP for heavy query loads; resource-constrained, Pareto and temporal variants when constraints or time matter.
3. **Find structure** (#51–100, #121–131, #151–169): connectivity and weak points (bridges, articulation points, cuts, dominators); dense groups (cores, trusses, cliques, densest subgraphs); communities (Leiden, Infomap, SBM), always with stability checks.
4. **Rank and compare** (#101–120, #251–258, #285–294): PageRank and push PPR for relevance; approximate betweenness for brokers; similarity indices, embeddings and metapath measures for "like this"; alignment for matching across graphs.
5. **Optimize** (#61–100, #183–188, #197, #301–304): flows, cuts, matching and assignment, routing problems, coloring, covers and scheduling. Always with certificates (cuts for flows, covers for matchings) and approximation bounds.
6. **Scale** (#170–175, #201–250): partition (METIS, streaming, vertex-cut), process (GAS, Ligra, GraphBLAS, GPU, out-of-core, distributed), keep results current incrementally (dynamic algorithms, differential dataflow, IVM), and use sketches, samples and sparsifiers with stated error bounds.
7. **Infer and learn** (#259–284): GNNs suited to the graph (homophily checked), probabilistic inference with convergence checks, causal reasoning with explicit assumptions, graph construction choices recorded.
8. **Apply in systems** (#295–320): program analysis for code-aware tooling, build graphs and garbage collection for the glue engine's incremental work and cleanup, protocols for distribution, layouts for human review, attack graphs for security.

Each algorithm plugs into the composition engine through its contract (G1): the input graph type and its assumptions (GR2), the cost model (GR3), exactness (GR4), and the certificate it provides (GR6). With these, the planner can pick and combine graph algorithms just like the code, vector and knowledge graph algorithms.
