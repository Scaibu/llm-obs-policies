# Part 4: Communities, partitioning, spectral methods, coloring, isomorphism and decompositions (#151–200)

Same format and the same contract (roles; rules GR1–GR8; guardrails GX1–GX5).

## D1. Community detection

### 151. Modularity and its resolution limit

**Definition:** Modularity scores a partition by how many edges fall inside communities, compared with what's expected by chance. It's the most widely used community quality measure, with known limitations.

**Complexity:** O(m) to evaluate a partition. Maximizing it exactly is NP-hard.

### 152. Leiden with the constant Potts model (CPM)

**Definition:** Leiden community detection (K#82) with the CPM objective, which avoids modularity's resolution limit.

**Complexity:** About O(m) per iteration.

### 153. Girvan-Newman (edge betweenness removal)

**Definition:** Finding communities by repeatedly removing the edge with the highest betweenness, which tends to be a bridge between communities.

**Complexity:** O(m² × n) overall. Only feasible for small graphs.

### 154. Overlapping label propagation (SLPA)

**Definition:** A label propagation variant where vertices remember the labels they've received, allowing each vertex to belong to several communities.

**Complexity:** O(T × m).

### 155. Infomap (the map equation)

**Definition:** Community detection that finds the partition giving the shortest description of a random walk on the graph. Communities are regions where the walker stays for a long time.

**Complexity:** About O(m) per pass.

### 156. Walktrap

**Definition:** Hierarchical community detection using distances based on short random walks.

**Complexity:** O(m × n²) worst case, about O(n² log n) on sparse graphs.

### 157. Fast greedy modularity (Clauset-Newman-Moore)

**Definition:** Agglomerative community detection that repeatedly merges the pair of communities giving the largest modularity increase.

**Complexity:** O(m × d × log n), where d is the dendrogram depth. Near-linear on many sparse graphs.

### 158. Spectral clustering (normalized Laplacian + k-means)

**Definition:** Clustering vertices with the eigenvectors of the graph Laplacian, which turns graph structure into a geometry where clusters separate easily.

**Complexity:** Dominated by the eigensolver: about O(k × m × iterations) with sparse iterative methods.

### 159. Spectral bisection (Fiedler vector)

**Definition:** Splitting a graph in two using the eigenvector of the second-smallest Laplacian eigenvalue.

**Complexity:** One eigenvector computation (Lanczos, #176).

### 160. Conductance, sweep cuts and the Cheeger inequality

**Definition:** Conductance measures how cleanly a vertex set is separated from the rest (cut edges relative to the set's total degree). The Cheeger inequality links it to the Laplacian spectrum.

**Complexity:** O(m) for a sweep, using a sorted order and incremental updates.

### 161. Local graph clustering (PageRank-Nibble with sweep cut)

**Definition:** Finding a good cluster around a seed vertex while touching only a small part of the graph.

**Complexity:** Proportional to the cluster size and 1/ε, not to the graph size.

### 162. Markov clustering (MCL)

**Definition:** Clustering by simulating random-walk flow, alternately spreading it out (expansion) and strengthening strong flows (inflation), until flow settles into clusters.

**Complexity:** Sparse matrix products with pruning. Practical on large sparse graphs.

### 163. Stochastic block model inference (degree-corrected, Bayesian/MDL)

**Definition:** Fitting a statistical model where vertices belong to groups and edge probabilities depend only on group membership. That finds communities and other structures (core-periphery, bipartite) in a principled way.

**Complexity:** About O(m log² n) for efficient MCMC versions.

### 164. Overlapping communities with BigCLAM

**Definition:** A model-based method where each vertex has a non-negative affiliation strength with each community, and overlaps naturally increase the chance of edges.

**Complexity:** About O(m) per iteration (linear in edges).

### 165. Clique percolation

**Definition:** Communities defined as unions of adjacent k-cliques (two k-cliques are adjacent if they share k−1 vertices). That allows overlap naturally.

**Complexity:** Dominated by clique enumeration. Feasible on sparse graphs.

### 166. Hierarchical agglomerative clustering on graphs

**Definition:** Building a tree of nested clusters by repeatedly merging the most similar clusters, using graph similarities or distances.

**Complexity:** O(n² log n) generally. Single linkage is O(m log m) through an MST.

### 167. Correlation clustering (pivot / KwikCluster)

**Definition:** Clustering items from "same / different" pairwise judgments, minimizing disagreements, without choosing the number of clusters.

**Complexity:** O(m) per run.

### 168. Community evaluation (NMI, ARI, conductance, stability)

**Definition:** Measuring how good a community partition is, against ground truth or by internal quality, and how stable it is.

**Complexity:** O(n) to O(n log n) per comparison.

### 169. Dynamic community tracking

**Definition:** Following communities across graph snapshots over time, and detecting events: birth, death, growth, shrinkage, merge, split.

**Complexity:** Detection per snapshot, plus overlap matching (efficient with hashing).

## D2. Partitioning

### 170. METIS multilevel partitioning

**Definition:** The standard method for splitting a graph into k balanced parts with few edges between them: coarsen, partition the small graph, then refine while expanding.

**Complexity:** Near-linear: O(m) per level, with a logarithmic number of levels.

### 171. Kernighan-Lin and Fiduccia-Mattheyses refinement

**Definition:** Local improvement for graph partitions: move or swap vertices between parts to reduce the cut while keeping balance.

**Complexity:** FM passes are O(m) with bucket structures.

### 172. Streaming partitioning (LDG, FENNEL)

**Definition:** Assigning vertices to partitions in one pass as they arrive, using only already-placed neighbors and partition sizes.

**Complexity:** O(m) in one pass, with low memory.

### 173. Vertex-cut partitioning (PowerGraph greedy, HDRF)

**Definition:** Partitioning edges instead of vertices, so high-degree vertices are split (replicated) across machines. That's better for skewed graphs.

**Complexity:** O(m) streaming.

### 174. Hypergraph partitioning (hMETIS, KaHyPar, PaToH)

**Definition:** Partitioning a hypergraph so that hyperedges are split across as few parts as possible. It models communication cost more accurately than graph partitioning.

**Complexity:** Near-linear in the number of pins (vertex–hyperedge memberships), heavier than graph partitioning.

### 175. Graph coarsening by heavy-edge matching

**Definition:** Shrinking a graph by merging pairs of vertices connected by heavy edges, keeping its structure. The coarsening step of multilevel algorithms.

**Complexity:** O(m) per level.

## D3. Spectral methods and graph signal processing

### 176. Graph Laplacian eigensolvers (Lanczos, LOBPCG)

**Definition:** Computing a few eigenvalues and eigenvectors of large sparse graph matrices, using iterative methods based only on matrix-vector products.

**Complexity:** O(m × iterations × k) for k eigenpairs.

### 177. Spectral sparsification (effective resistance sampling)

**Definition:** Replacing a dense graph with a much sparser one that has nearly the same Laplacian, so it behaves almost identically for cuts, flows and spectral algorithms.

**Complexity:** Near-linear time with fast Laplacian solvers.

### 178. Laplacian solvers (conjugate gradient, preconditioning, algebraic multigrid)

**Definition:** Solving linear systems Lx = b with graph Laplacians, a core operation behind many graph algorithms (electrical flows, effective resistance, diffusion, semi-supervised learning).

**Complexity:** Near-linear per solve with good preconditioners.

### 179. Effective resistance and commute time

**Definition:** Treating edges as resistors, the effective resistance between two vertices measures how well connected they are through all paths. Commute time is the expected random-walk round-trip time, proportional to it.

**Complexity:** Near-linear for all edges, approximately.

### 180. Uniform random spanning trees (Wilson's algorithm)

**Definition:** Sampling a spanning tree uniformly at random from all spanning trees of a graph.

**Complexity:** Expected time = the mean hitting time, efficient on most graphs.

### 181. Graph signal processing (graph Fourier transform, Chebyshev filters)

**Definition:** Treating values on vertices as signals and filtering them by graph frequency (smooth versus rapidly varying across edges), using the Laplacian's eigenvectors.

**Complexity:** O(k × m) per filtered signal.

### 182. Laplacian eigenmaps and diffusion maps

**Definition:** Embedding vertices into low-dimensional space with Laplacian or diffusion eigenvectors, so that nearby vertices in the graph are nearby in the embedding.

**Complexity:** Dominated by the eigensolver (#176).

## D4. Coloring, independent sets and covers

### 183. Greedy coloring and DSatur

**Definition:** Assigning colors to vertices so that adjacent vertices differ, using few colors. Optimal coloring is NP-hard; greedy methods are standard.

**Complexity:** Greedy O(n + m). DSatur O((n + m) log n).

### 184. Parallel coloring (Jones-Plassmann)

**Definition:** Coloring vertices in parallel, by coloring in rounds the vertices that are local maxima of random priorities.

**Complexity:** O(log n / log log n) rounds expected on bounded-degree graphs.

### 185. Maximal independent set (Luby's algorithm)

**Definition:** Finding a set of vertices with no two adjacent, that can't be extended. Done in parallel with randomized rounds.

**Complexity:** O(log n) rounds expected. O(m) total work.

### 186. Vertex cover approximation (matching-based, LP rounding, kernelization)

**Definition:** Finding a small set of vertices touching every edge. NP-hard in general graphs, but with good approximations and exact methods for small covers.

**Complexity:** O(m) for the approximation. Exact: fixed-parameter tractable, about O(1.27^k + k × n).

### 187. Dominating set (greedy approximation)

**Definition:** Choosing a small set of vertices such that every vertex is in the set or adjacent to it.

**Complexity:** O(m log n) with priority structures.

### 188. Feedback arc set and feedback vertex set (Eades-Lin-Smyth and others)

**Definition:** Finding the smallest set of edges (or vertices) whose removal makes a directed graph acyclic.

**Complexity:** O(m) for Eades-Lin-Smyth.

## D5. Isomorphism, matching and pattern mining

### 189. Canonical labeling and graph isomorphism (nauty, Traces, bliss)

**Definition:** Computing a canonical form for a graph, so that two graphs are isomorphic exactly when their canonical forms are identical.

**Complexity:** Quasi-polynomial in theory (Babai). Usually fast in practice.

### 190. Advanced subgraph isomorphism (VF3, Glasgow subgraph solver, Ullmann)

**Definition:** Finding all occurrences of a pattern graph inside a larger target graph, with strong pruning methods.

**Complexity:** NP-complete. These solvers handle practical sizes with strong pruning.

### 191. Automorphism groups and symmetry detection

**Definition:** Finding the symmetries of a graph: the vertex permutations that preserve every edge.

**Complexity:** Like canonical labeling (#189).

### 192. Maximum common subgraph (McSplit)

**Definition:** Finding the largest subgraph appearing in both of two graphs.

**Complexity:** NP-hard. Practical for graphs of tens to a few hundred vertices.

### 193. Frequent subgraph mining (gSpan)

**Definition:** Finding subgraph patterns that occur in many graphs of a collection (or many times in one large graph).

**Complexity:** Exponential in pattern size. Feasible with a reasonable minimum support.

### 194. Graph kernels (random walk, shortest path, WL subtree)

**Definition:** Similarity functions between whole graphs, used for classification and clustering of graphs.

**Complexity:** WL is O(h × m) per graph. Random walk kernels are cubic or worse unless approximated.

## D6. Structural decompositions

### 195. Planarity testing and embedding (Boyer-Myrvold)

**Definition:** Deciding whether a graph can be drawn in the plane without edge crossings, and producing such a drawing's combinatorial structure (an embedding).

**Complexity:** O(n) (planar graphs have at most 3n − 6 edges).

### 196. Tree decompositions and treewidth heuristics (min-degree, min-fill)

**Definition:** Representing a graph as a tree of overlapping vertex groups (bags). Treewidth (the largest bag size − 1) measures how "tree-like" a graph is. Many hard problems become easy on low-treewidth graphs.

**Complexity:** About O(n × m) for the heuristics.

### 197. Dynamic programming over tree decompositions

**Definition:** Solving hard graph problems exactly by processing a tree decomposition bottom-up, keeping a table of partial solutions per bag.

**Complexity:** O(c^w × n), with w the treewidth and c depending on the problem (for example 2 for independent set, k for k-coloring).

### 198. Chordal graphs and perfect elimination orderings (maximum cardinality search)

**Definition:** Chordal graphs (every cycle of length 4 or more has a chord) have perfect elimination orderings, which make many hard problems easy. Chordal completion turns any graph into one.

**Complexity:** O(n + m) for MCS and recognition.

### 199. Graph separators (planar separator theorem, flow-based vertex separators)

**Definition:** Small sets of vertices whose removal splits a graph into balanced pieces. They're the basis of divide-and-conquer algorithms on graphs.

**Complexity:** O(n) for planar separators. Flow-based methods cost one or more max-flows.

### 200. Nested dissection ordering

**Definition:** Ordering the vertices for sparse matrix factorization by recursively finding separators and numbering separator vertices last. That minimizes fill-in and enables parallelism.

**Complexity:** For planar graphs, O(n log n) fill and O(n^1.5) factorization operations.

---

Part 5 (#201–250) covers dynamic graph algorithms (dynamic shortest paths, incremental topological order, dynamic MST), streaming graph algorithms and sketches, temporal graphs, and parallel and distributed processing models (Gather-Apply-Scatter, block-centric, GPU frontier models, GraphBLAS, Ligra, out-of-core engines, distributed BFS, connected components, triangle counting and MST), plus subgraph enumeration systems, color coding, graph summarization, spanners, sparsifiers, multi-version graph storage, graph transactions, incremental view maintenance and differential dataflow.
