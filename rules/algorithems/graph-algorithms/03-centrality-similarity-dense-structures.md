# Part 3: Centrality, similarity, dense structures, network measures and random graph models (#101–150)

Same format and the same contract (roles; rules GR1–GR8; guardrails GX1–GX5).

## C1. Centrality and ranking

### 101. Weighted degree (strength) and normalized degree

**Definition:** Measuring a vertex's direct connectedness by its edge count or total edge weight, separately for incoming and outgoing edges.

**Complexity:** O(n + m).

### 102. PageRank in depth (power iteration, dangling vertices, convergence)

**Definition:** The full computation details of PageRank (K#74): getting correct, fast, reproducible scores on real graphs.

**Complexity:** O(m) per iteration.

### 103. Push-based personalized PageRank (Andersen-Chung-Lang)

**Definition:** Computing personalized PageRank (K#75) approximately by pushing "residual" mass locally from the seed, touching only nearby vertices.

**Complexity:** O(1/(α ε)) pushes, independent of n.

### 104. Monte Carlo and bidirectional PPR estimation (FORA style)

**Definition:** Estimating personalized PageRank by combining local pushes with random walks, for accurate scores at low cost.

**Complexity:** Sublinear per query in practice.

### 105. SimRank

**Definition:** A similarity measure based on the idea that "two vertices are similar if they are referenced by similar vertices".

**Complexity:** The naive version costs O(k × n² × d²) and needs O(n²) memory. Only the approximate versions scale.

### 106. HITS and SALSA

**Definition:** Link analysis with two scores per vertex: hub (points to good authorities) and authority (pointed to by good hubs). SALSA is a random-walk variant that resists some manipulation.

**Complexity:** O(m) per iteration.

### 107. Katz centrality

**Definition:** Importance from all paths reaching a vertex, with longer paths counting exponentially less.

**Complexity:** O(m) per iteration.

### 108. Eigenvector centrality and non-backtracking centrality

**Definition:** Importance from being connected to important vertices, computed as the principal eigenvector of the adjacency matrix. The non-backtracking variant fixes localization on hubs.

**Complexity:** O(m) per iteration. The non-backtracking matrix has 2m × 2m dimensions, but there are efficient reduced forms.

### 109. Brandes betweenness (weighted and edge variants)

**Definition:** The exact computation of betweenness centrality (K#76) for vertices and edges, for weighted and unweighted graphs.

**Complexity:** O(n × m) unweighted, O(n × m + n² log n) weighted.

### 110. Approximate betweenness (Riondato-Kornaropoulos, KADABRA)

**Definition:** Estimating betweenness with guaranteed accuracy by sampling shortest paths instead of computing all of them.

**Complexity:** Sample count independent of n for a fixed ε. Each sample costs about one bidirectional BFS.

### 111. Closeness centrality via HyperBall (HyperLogLog counters)

**Definition:** Approximating closeness and harmonic centrality (K#77) for all vertices, using small probabilistic counters of reachable sets.

**Complexity:** O(m × diameter) operations on small counters. Memory O(n × counter size).

### 112. Current-flow (random-walk) betweenness and closeness

**Definition:** Centrality based on electrical current flow, which counts all paths weighted by how much current they carry, not just shortest paths.

**Complexity:** Exact versions are cubic or worse. Approximations are near-linear per solve.

### 113. Influence maximization (IC/LT models, CELF, reverse influence sampling)

**Definition:** Choosing k seed vertices that maximize the expected spread of a cascade in a diffusion model.

**Complexity:** IMM is near-linear in the graph size times k/ε².

### 114. Spreader ranking by coreness and collective influence

**Definition:** Identifying vertices that best spread (or block) diffusion, using core position and nonlocal measures instead of degree alone.

**Complexity:** Coreness O(m). CI with updates is about O(n log n) with heaps.

## C2. Similarity, roles and local structure

### 115. Local similarity indices (Jaccard, Salton, Sørensen, hub-promoted)

**Definition:** Similarity of two vertices measured from their shared neighbors, normalized in various ways.

**Complexity:** O(degree(x) + degree(y)) per pair.

### 116. Global similarity indices (Katz index, local path index, LHN)

**Definition:** Similarity from paths of several lengths between two vertices, not just shared neighbors.

**Complexity:** Full matrices are infeasible for large graphs. Per-row computation is about O(k × m).

### 117. Graph diffusion kernels (heat kernel, regularized Laplacian, von Neumann)

**Definition:** Similarity matrices defined by diffusion processes on the graph: how much "heat" or probability flows from one vertex to another.

**Complexity:** O(k × m) per row with k-term polynomial approximations.

### 118. Role discovery (RolX) and structural equivalence

**Definition:** Grouping vertices by their structural position (for example "hub", "bridge", "peripheral"), regardless of where they are in the graph.

**Complexity:** About O(m × iterations) for the features, plus the factorization.

### 119. Regular equivalence and role similarity

**Definition:** Two vertices are regularly equivalent if they connect to equivalent vertices, even if not the same ones. For example, two managers, each with their own team.

**Complexity:** About O(m log n) for partition refinement versions.

### 120. Graphlet counting and graphlet degree vectors (ORCA)

**Definition:** Counting small connected subgraph patterns (graphlets) and how often each vertex appears in each position (orbit) of each pattern.

**Complexity:** Roughly O(m × d³) for 5-vertex graphlets, where d is the maximum degree.

### 121. Exact triangle counting (forward / compact-forward with degree ordering)

**Definition:** Counting all triangles (three mutually connected vertices) in a graph efficiently.

**Complexity:** O(m^1.5), much faster in practice on skewed graphs because of the degree ordering.

### 122. Approximate and streaming triangle counting (DOULION, wedge sampling, TRIEST)

**Definition:** Estimating triangle counts with sampling, for huge or streaming graphs.

**Complexity:** Sublinear memory. Constant memory for TRIEST.

### 123. Clustering coefficients (local, global, transitivity)

**Definition:** Measures of how often a vertex's neighbors are also connected to each other.

**Complexity:** Like triangle counting (#121).

### 124. k-clique listing (Chiba-Nishizeki, kClist)

**Definition:** Listing or counting all complete subgraphs of exactly k vertices.

**Complexity:** O(k × m × (c/2)^(k−2)), where c is the degeneracy (small on real graphs).

### 125. Maximal clique enumeration (Bron-Kerbosch with pivoting and degeneracy ordering)

**Definition:** Listing every clique that can't be extended by adding another vertex.

**Complexity:** O(d × n × 3^(d/3)), where d is the degeneracy. Very fast on sparse real graphs.

### 126. Maximum clique (branch and bound with coloring bounds)

**Definition:** Finding the largest clique in a graph, an NP-hard problem solved exactly on many practical instances.

**Complexity:** Exponential worst case. Often fast on sparse real graphs.

### 127. k-truss decomposition

**Definition:** Maximal subgraphs where every edge is part of at least k−2 triangles inside the subgraph: a stronger cohesion notion than k-core.

**Complexity:** O(m^1.5).

### 128. Nucleus decomposition (generalized cores and trusses)

**Definition:** A unified hierarchy of dense subgraphs, defined by how many larger cliques each small clique belongs to.

**Complexity:** Depends on (r, s). (3, 4) is expensive but gives very dense, meaningful structures.

### 129. Densest subgraph (Goldberg exact, Charikar peeling, Greedy++)

**Definition:** Finding the subgraph with the highest average degree (edges divided by vertices).

**Complexity:** Peeling O(m + n) per round with bucket queues. Exact: several max-flows.

### 130. Camouflage-resistant dense block detection (Fraudar)

**Definition:** Detecting dense blocks of fraudulent behavior in bipartite graphs (users–items), even when fraudsters add normal-looking "camouflage" edges.

**Complexity:** O(m log n).

### 131. Quasi-clique mining

**Definition:** Finding groups that are almost cliques: each vertex connected to at least a fraction γ of the others in the group.

**Complexity:** NP-hard. Practical with strong pruning on sparse graphs.

### 132. Motif counting and statistical significance

**Definition:** Counting small subgraph patterns and testing whether they occur more (or less) often than expected by chance.

**Complexity:** Dominated by the counting, repeated over the random samples.

## C3. Network-level measures

### 133. Assortativity coefficient

**Definition:** The correlation between the degrees (or attributes) of connected vertices: do similar vertices connect to each other?

**Complexity:** O(m).

### 134. Rich-club coefficient

**Definition:** Whether high-degree vertices are more densely connected to each other than expected.

**Complexity:** O(m) per threshold, plus the randomized graphs.

### 135. Degree distribution fitting (Clauset-Shalizi-Newman power-law method)

**Definition:** Rigorously testing whether a degree distribution follows a power law, and estimating its parameters.

**Complexity:** O(n log n) per candidate x_min. The bootstrap repeats the fit many times.

### 136. Effective diameter and distance distribution (HyperANF)

**Definition:** Approximating the full distribution of pairwise distances, and the effective diameter (the distance within which, say, 90% of pairs are connected).

**Complexity:** O(m × diameter) counter operations.

### 137. Exact diameter (double sweep, iFUB)

**Definition:** Computing the exact largest shortest-path distance in a large graph, usually with only a few BFS runs.

**Complexity:** O(n × m) worst case. In practice, often a handful of BFS runs.

### 138. Eccentricity bounding (Takes-Kosters)

**Definition:** Computing every vertex's eccentricity (its maximum distance to any other vertex) using bounds, so most vertices never need their own BFS.

**Complexity:** Often a few dozen BFS runs on real graphs.

### 139. Small-world measures (σ and ω)

**Definition:** Quantifying whether a graph has both high clustering and short path lengths, compared with random and lattice reference graphs.

**Complexity:** Dominated by computing L and the reference graphs.

### 140. Bow-tie decomposition (directed graph structure)

**Definition:** Splitting a directed graph into a giant strongly connected core, plus the regions feeding into it (IN), reached from it (OUT), and the rest (tendrils, tubes, disconnected parts).

**Complexity:** O(n + m).

## C4. Random graph models and null models

### 141. Configuration model and degree-preserving rewiring

**Definition:** Generating random graphs with exactly the same degree sequence as a real graph, to serve as a null model.

**Complexity:** O(m) for the configuration model. O(swaps) for rewiring.

### 142. Generative graph models (Erdős–Rényi, Barabási–Albert, Watts–Strogatz, Kronecker)

**Definition:** Standard random graph models for testing algorithms, generating synthetic data and understanding structure.

**Complexity:** About O(m) generation for each.

### 143. Exponential random graph models (ERGM)

**Definition:** Statistical models of networks where the probability of a graph depends on its counts of chosen structures (edges, triangles, stars, attribute-based ties).

**Complexity:** Expensive. MCMC-based estimation suits graphs with up to tens of thousands of vertices.

### 144. Percolation and robustness analysis

**Definition:** Measuring how a network breaks apart as vertices or edges are removed, randomly (failures) or deliberately (attacks).

**Complexity:** O(m × α(n)) for the whole curve with Newman-Ziff.

### 145. Cascade failure models (load redistribution, Motter-Lai)

**Definition:** Simulating how the failure of one component overloads others, causing chains of failures.

**Complexity:** One load recomputation per round, which can be expensive (betweenness, #110 approximations help).

### 146. Epidemic spreading simulation (SIR/SIS, Gillespie algorithm)

**Definition:** Simulating spreading processes (infection, information, malware) on graphs, with exact event timing.

**Complexity:** O(events × log n) with efficient rate tracking.

### 147. Independent cascade and linear threshold simulation

**Definition:** Monte Carlo simulation of the two standard information diffusion models, used to estimate spread.

**Complexity:** O(m) per simulation.

## C5. Graph sampling and estimation

### 148. Graph sampling (node, edge, random walk, Metropolis-Hastings random walk)

**Definition:** Selecting a subset of a graph to estimate properties of the whole, when the full graph is too large or only accessible by crawling.

**Complexity:** O(sample size) plus the walk mixing time.

### 149. Snowball, forest fire and respondent-driven sampling with corrections

**Definition:** Sampling methods that expand from seeds through neighbors, with statistical corrections for their biases.

**Complexity:** O(sample size).

### 150. Graph size and property estimation from samples (collision counting, capture-recapture)

**Definition:** Estimating how many vertices or edges a graph has, or the frequency of a property, when you can't enumerate it.

**Complexity:** O(√n) samples are often enough for a size estimate (birthday bound).

---

Part 4 (#151–200) covers community detection (modularity theory, Leiden-CPM, Girvan-Newman, Infomap, Walktrap, spectral clustering, local clustering, Markov clustering, SBM inference, overlapping communities), partitioning (METIS, KL/FM refinement, streaming and vertex-cut partitioning, hypergraph partitioning), spectral methods (Laplacian eigensolvers, sparsification, Laplacian solvers, effective resistance, random spanning trees, graph signal processing), coloring and independent sets, isomorphism and subgraph matching, and structural decompositions (planarity, treewidth, chordal graphs, nested dissection).
