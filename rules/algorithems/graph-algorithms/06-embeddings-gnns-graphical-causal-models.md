# Part 6: Embeddings, advanced GNNs, probabilistic graphical models, causal graphs and graph-based learning (#251–300)

Same format and the same contract (roles; rules GR1–GR8; guardrails GX1–GX5). Earlier references (K#101–150) covered TransE, RotatE, ComplEx, DeepWalk, node2vec, GCN, GraphSAGE, GAT, R-GCN and graph transformers. This part adds what they didn't.

## F1. Node embeddings

### 251. Adjacency spectral embedding (ASE)

**Definition:** Embedding vertices with the top eigenvectors of the adjacency matrix, scaled by the square roots of the eigenvalues. It's statistically justified under random dot product graph models.

**Complexity:** One partial eigendecomposition.

### 252. LINE (first- and second-order proximity)

**Definition:** An embedding method that preserves direct links (first-order proximity) and shared neighborhoods (second-order proximity), trained efficiently with edge sampling.

**Complexity:** O(m × d) per epoch.

### 253. struc2vec (structural role embeddings)

**Definition:** Embeddings where vertices with similar structural roles (for example, both are hubs or both are bridges) are close, even if they're far apart in the graph.

**Complexity:** Expensive without optimizations. Practical with them, for medium graphs.

### 254. HOPE (high-order proximity preserving embeddings)

**Definition:** Embedding directed graphs by factorizing a high-order proximity matrix (such as the Katz index) into separate "source" and "target" vectors, which preserves asymmetry.

**Complexity:** About O(m × d²) with the generalized SVD.

### 255. GraRep (multi-step transition factorization)

**Definition:** Embeddings capturing structure at several distances, by factorizing transition matrices of different step counts and concatenating the results.

**Complexity:** Dense k-step matrices limit it to small and medium graphs.

### 256. NetMF (DeepWalk as implicit matrix factorization)

**Definition:** The result that DeepWalk, LINE and node2vec implicitly factorize specific closed-form matrices, and computing those factorizations directly gives equal or better embeddings deterministically.

**Complexity:** Dense M for small graphs. NetSMF scales to large graphs.

### 257. ProNE (fast sparse factorization with spectral propagation)

**Definition:** A very fast embedding method: factorize a sparse proximity matrix first, then refine the embedding by propagating it through a spectral filter of the graph.

**Complexity:** About O(m × d) overall. Very fast on large graphs, even single-threaded.

### 258. Partitioned large-scale embedding training (PyTorch-BigGraph style)

**Definition:** Training embeddings for graphs with billions of vertices by partitioning the vertices and training on edge buckets, so only a few partitions sit in memory at once.

**Complexity:** Memory per machine is bounded by about two partitions.

### 259. Graph autoencoders (GAE, VGAE)

**Definition:** Unsupervised models that encode vertices with a GNN and are trained to reconstruct the graph's edges.

**Complexity:** About O(m × d) per epoch with sampled negatives.

## F2. Advanced graph neural networks

### 260. GIN (graph isomorphism network)

**Definition:** A GNN designed to be as powerful as the 1-WL isomorphism test (K#140), the theoretical maximum for standard message passing.

**Complexity:** O(m × d) per layer.

### 261. APPNP (personalized propagation of neural predictions)

**Definition:** A GNN that separates prediction from propagation: a neural network predicts per vertex, then personalized PageRank spreads those predictions over many hops without over-smoothing.

**Complexity:** O(K × m × classes) for propagation.

### 262. SGC (simplified graph convolution)

**Definition:** A linear GNN: smooth the features over K hops with the normalized adjacency once (no neural layers in between), then train a logistic regression.

**Complexity:** O(K × m × features) preprocessing, then cheap training.

### 263. Heterophily-aware GNNs (H2GCN, GPR-GNN)

**Definition:** GNNs designed for graphs where connected vertices tend to be different (heterophily), where standard GNNs fail.

**Complexity:** Similar to standard GNNs.

### 264. Positional and structural encodings (Laplacian eigenvectors, random-walk encodings)

**Definition:** Extra input features that tell a GNN or graph transformer where each vertex sits in the graph, which message passing alone can't express.

**Complexity:** Eigenvectors cost an eigensolve. RWSE costs K sparse matrix products.

### 265. Higher-order and subgraph GNNs (k-WL, nested GNNs, ESAN)

**Definition:** GNNs more expressive than 1-WL, distinguishing structures that standard message passing can't, by processing tuples of vertices or bags of subgraphs.

**Complexity:** Several times to orders of magnitude more expensive than standard GNNs.

### 266. Equivariant GNNs (geometric graphs, E(n)-equivariant networks)

**Definition:** GNNs for graphs embedded in physical space (molecules, meshes, sensor layouts), whose outputs transform correctly when the input is rotated or translated.

**Complexity:** Similar to standard message passing, typically on spatial neighbor graphs.

### 267. Masked graph autoencoder pretraining (GraphMAE)

**Definition:** Self-supervised pretraining that masks some vertex features and trains a GNN to reconstruct them, producing representations that transfer to tasks with few labels.

**Complexity:** Like GNN training.

### 268. Layer-wise and importance neighbor sampling (FastGCN, LADIES)

**Definition:** Training GNNs on large graphs by sampling a fixed set of vertices per layer (not per vertex), avoiding the exponential neighborhood growth of per-vertex sampling.

**Complexity:** Linear in layers × sample size.

## F3. Probabilistic graphical models

### 269. Belief propagation on trees (sum-product)

**Definition:** Exact computation of marginal probabilities in tree-structured probabilistic models by passing messages along edges.

**Complexity:** O(n × k²) for k states per variable.

### 270. Loopy belief propagation

**Definition:** Applying belief propagation's message updates to graphs with cycles, iterating until messages settle. It's approximate but widely effective.

**Complexity:** O(m × k²) per iteration.

### 271. Max-product belief propagation and Viterbi decoding

**Definition:** Finding the single most likely joint assignment (MAP), instead of marginals, by replacing sums with maximizations in message passing.

**Complexity:** Chains: O(T × k²).

### 272. Junction tree algorithm

**Definition:** Exact inference on graphs with cycles, by grouping variables into clusters that form a tree, then running belief propagation between clusters.

**Complexity:** Exponential in the largest clique size (the treewidth + 1).

### 273. Variable elimination

**Definition:** Exact inference by summing out variables one at a time in a chosen order, multiplying the relevant factors together as you go.

**Complexity:** Exponential in the induced width of the order.

### 274. Gibbs sampling on graphical models

**Definition:** Approximate inference by repeatedly resampling each variable from its distribution conditioned on its neighbors (its Markov blanket).

**Complexity:** O(local factor cost) per variable per sweep. The number of sweeps depends on mixing.

### 275. Mean-field variational inference

**Definition:** Approximating a complex distribution with a simpler, fully factorized one, optimized by coordinate updates.

**Complexity:** O(m × k) per iteration.

### 276. Conditional random fields (linear-chain and graph CRFs)

**Definition:** Models that predict labels for connected items jointly, conditioned on observed features, with learned label-compatibility between neighbors.

**Complexity:** Training requires inference at every step. Exact for chains and trees.

### 277. Factor graphs and general message passing

**Definition:** A bipartite representation of how a global function factorizes into local functions (factors connected to the variables they involve), the common framework for most inference algorithms.

**Complexity:** O(Σ over factors of k^(factor size)) per iteration.

## F4. Causal and statistical graph learning

### 278. Bayesian network structure learning (score-based: hill climbing, GES)

**Definition:** Learning the directed acyclic graph of a Bayesian network from data, by searching for the structure with the best score.

**Complexity:** Exponential in general. Heuristics work for hundreds of variables.

### 279. d-separation and the Bayes-ball algorithm

**Definition:** A graphical test that reads off conditional independencies from a DAG: whether X and Y are independent given Z.

**Complexity:** O(n + m).

### 280. Constraint-based causal discovery (PC and FCI algorithms)

**Definition:** Learning a causal graph (up to equivalence) from conditional independence tests in data.

**Complexity:** Exponential worst case. Feasible for sparse graphs with a moderate number of variables.

### 281. Do-calculus and adjustment criteria (backdoor and frontdoor)

**Definition:** Rules for deciding, from a causal graph, whether the effect of an intervention can be computed from observational data, and how.

**Complexity:** Polynomial for the identification algorithms.

### 282. Graphical lasso (sparse inverse covariance estimation)

**Definition:** Learning an undirected graph of conditional dependencies among variables, by estimating a sparse inverse covariance (precision) matrix.

**Complexity:** O(p³) per iteration for p variables. Practical for hundreds to a few thousand variables.

### 283. NN-descent (approximate k-nearest-neighbor graph construction)

**Definition:** Building an approximate k-nearest-neighbor graph quickly, using the principle that "a neighbor of a neighbor is likely a neighbor".

**Complexity:** Empirically about O(n^1.14) distance computations.

### 284. Similarity graph construction (ε-graphs, k-NN, mutual k-NN, adaptive kernels)

**Definition:** Turning a set of data points into a graph whose edges connect similar points, the step that defines what every later graph algorithm "sees".

**Complexity:** Dominated by neighbor search.

## F5. Graph-based ranking and recommendation

### 285. TextRank (graph-based keyword and sentence ranking)

**Definition:** Applying PageRank to graphs built from text (words linked by co-occurrence, or sentences linked by similarity) to extract keywords and summary sentences.

**Complexity:** O(text length) to build, plus PageRank.

### 286. Harmonic label propagation (Zhu-Ghahramani)

**Definition:** Semi-supervised classification on a graph: labeled vertices keep their labels, and every unlabeled vertex takes the weighted average of its neighbors' labels.

**Complexity:** One Laplacian solve.

### 287. Pixie (real-time random-walk recommendation)

**Definition:** A recommendation algorithm that runs many short random walks with restart on a bipartite user–item (or pin–board) graph, in real time.

**Complexity:** Bounded number of walk steps per query: milliseconds.

### 288. P3α and RP3β (item-based random-walk recommenders)

**Definition:** Simple, strong recommenders that score items by three-step random walks on the user–item graph, with popularity correction.

**Complexity:** Sparse matrix products with top-k pruning.

### 289. Path Ranking Algorithm (PRA)

**Definition:** Predicting relations in knowledge graphs by using the probabilities of reaching the target through typed relation paths as features.

**Complexity:** Path probability computation per candidate, which can be costly for long paths.

### 290. HeteSim (relevance along metapaths)

**Definition:** A relevance measure between objects of possibly different types in a heterogeneous graph, along a given metapath, symmetric by construction.

**Complexity:** Sparse matrix products along the metapath halves.

### 291. PathSim (metapath-based similarity via sparse products)

**Definition:** Similarity between objects of the same type based on the number of metapath instances connecting them, normalized so very popular objects don't dominate.

**Complexity:** Sparse matrix products. Compute rows on demand for large graphs.

## F6. Network alignment and graph matching

### 292. IsoRank (spectral network alignment)

**Definition:** Aligning vertices of two networks by an iterative similarity: two vertices match well if their neighbors match well, combined with prior similarity (for example, names).

**Complexity:** O(m₁ × m₂) per iteration on the product, often reduced by sparsifying the prior.

### 293. Embedding-based network alignment (REGAL, FINAL)

**Definition:** Aligning networks at scale by embedding both into a shared space with structural and attribute features, then matching nearest neighbors.

**Complexity:** Near-linear for REGAL.

### 294. Gromov-Wasserstein graph matching (optimal transport)

**Definition:** Matching two graphs (possibly of different sizes, without shared features) by finding a soft correspondence that best preserves pairwise distances, using optimal transport.

**Complexity:** About O(n³) per iteration naively. Faster with sparse or low-rank approximations.

## F7. Navigable graphs and program analysis

### 295. Proximity graph construction for approximate nearest neighbor search (RNG, Delaunay, k-NN refinement)

**Definition:** The graph-theoretic foundations of graph-based vector search: which edges a proximity graph needs so that greedy search finds nearest neighbors.

**Complexity:** Construction is near-linear to n^1.x with approximate methods.

### 296. Navigability and greedy routing (Kleinberg's small-world model)

**Definition:** The theory of when local greedy routing (always move to the neighbor closest to the target) finds short paths, which explains why graph-based search works.

**Complexity:** O(log² n) greedy steps in the navigable regime.

### 297. IFDS and IDE (interprocedural dataflow analysis as graph reachability)

**Definition:** Precise analysis of how dataflow facts move across function calls, by turning the analysis into reachability on an "exploded supergraph".

**Complexity:** O(E × D³), with E the supergraph edges and D the number of facts.

### 298. CFL-reachability (Dyck reachability)

**Definition:** Reachability where a path is valid only if its edge labels form a word of a context-free language, typically matched parentheses (calls matched with returns, or field stores matched with loads).

**Complexity:** O(n³) in general. Faster special cases exist.

### 299. Andersen's points-to analysis (inclusion-based constraint graphs)

**Definition:** Computing which objects each pointer or reference may point to, by solving subset constraints with propagation over a constraint graph.

**Complexity:** O(n³) worst case. Practical on large programs with these optimizations.

### 300. Steensgaard's points-to analysis (unification-based)

**Definition:** A fast, less precise points-to analysis that merges (unifies) pointer targets with union-find instead of tracking subset relations.

**Complexity:** Near-linear, O(n × α(n)).

---

Part 7 (#301–320), the final part, covers graphs in systems: register allocation by coloring, critical path scheduling, Coffman-Graham and HEFT scheduling, build-system graphs, garbage collection traversal, cycle collection, distributed deadlock detection, gossip and consensus averaging, network reliability, routing protocols (link-state, distance-vector, path-vector, spanning tree protocol), graph layout (force-directed, Sugiyama, edge bundling), geometric graphs, map matching, and attack graphs.
