# Part 2: Connectivity, trees, flows, cuts, matching and routing (#51–100)

Same format and the same contract (roles; rules GR1–GR8; guardrails GX1–GX5).

## B1. Connectivity

### 51. Union-find (disjoint set union) in depth

**Definition:** A structure that tracks a partition of elements into sets, supporting "merge two sets" and "which set is this in?" in nearly constant time.

**Complexity:** O(α(n)) amortized per operation, O(n) memory.

### 52. Fully dynamic connectivity (Holm–de Lichtenberg–Thorup)

**Definition:** Maintaining connected components under both edge insertions and edge deletions, answering "are u and v connected?" quickly.

**Complexity:** O(log² n) amortized per update, O(log n / log log n) per query.

### 53. Bridges and articulation points (Tarjan's lowlink)

**Definition:** Finding edges (bridges) and vertices (articulation points, or cut vertices) whose removal disconnects the graph.

**Complexity:** O(n + m).

### 54. Biconnected components and the block-cut tree

**Definition:** Splitting a graph into maximal pieces with no single vertex whose removal disconnects them, and connecting those pieces in a tree.

**Complexity:** O(n + m).

### 55. 2-edge-connected components

**Definition:** Maximal subgraphs that stay connected after removing any one edge.

**Complexity:** O(n + m).

### 56. SPQR trees (triconnected components, Hopcroft-Tarjan)

**Definition:** A tree decomposition of a biconnected graph into triconnected pieces, describing all its 2-vertex cuts (separation pairs).

**Complexity:** O(n + m), but complex to implement.

### 57. Parallel strongly connected components (forward-backward, coloring)

**Definition:** Finding SCCs on large graphs with parallel algorithms, since Tarjan's DFS (K#80) is inherently sequential.

**Complexity:** O(n + m) work expected in practice. Highly parallel.

### 58. Condensation and transitive reduction

**Definition:** Condensation collapses each SCC to one vertex, giving a DAG. Transitive reduction removes edges implied by other paths, giving the minimal graph with the same reachability.

**Complexity:** Condensation O(n + m). Transitive reduction is about as hard as transitive closure, O(n × m) in general, faster with bitsets.

### 59. Dominator trees (Lengauer-Tarjan, Cooper-Harvey-Kennedy)

**Definition:** In a graph with a start vertex, vertex d dominates v if every path from the start to v passes through d. The dominator tree organizes all these relationships.

**Complexity:** Iterative: about O(n + m) on typical graphs. Lengauer-Tarjan: O(m × α(m, n)).

### 60. Post-dominators and control dependence

**Definition:** Post-dominators are dominators on the reversed graph (relative to the exit). Control dependence says which branch decisions determine whether a step runs.

**Complexity:** O(n + m) to O(m × α) for the dominators. Control dependence is about linear in practice.

## B2. Spanning trees and Steiner trees

### 61. Kruskal's minimum spanning tree

**Definition:** Building a minimum-weight spanning tree by adding the cheapest edges that don't form cycles.

**Complexity:** O(m log m), dominated by the sort.

### 62. Prim's minimum spanning tree

**Definition:** Growing a minimum spanning tree from a start vertex by repeatedly adding the cheapest edge leaving the tree.

**Complexity:** O(m log n) with a binary heap. O(n²) with an array, which suits dense graphs.

### 63. Borůvka's algorithm (parallel MST)

**Definition:** An MST algorithm where every component simultaneously picks its cheapest outgoing edge, which suits parallel and distributed execution.

**Complexity:** O(m log n) total work. Highly parallel.

### 64. Minimum spanning arborescence (Chu-Liu/Edmonds)

**Definition:** The minimum-weight directed spanning tree rooted at a given vertex: every vertex reachable from the root along tree edges.

**Complexity:** O(n × m) simple version, O(m + n log n) with Gabow et al.'s improvements.

### 65. Steiner tree approximation (Kou–Markowsky–Berman / Mehlhorn)

**Definition:** Connecting a required subset of vertices (terminals) at minimum total edge cost, optionally through extra vertices. The exact problem is NP-hard; good approximations are standard.

**Complexity:** O(m + n log n) with Mehlhorn's method. Approximation factor 2 (within twice the optimum).

### 66. Prize-collecting Steiner tree (Goemans-Williamson)

**Definition:** Choosing which vertices to connect, trading the cost of edges against penalties for leaving vertices out (or the value gained by including them).

**Complexity:** About O(n² log n).

## B3. Tree algorithms

### 67. Lowest common ancestor (binary lifting, Euler tour + RMQ)

**Definition:** Finding the deepest vertex that is an ancestor of both given vertices in a rooted tree.

**Complexity:** Binary lifting: O(n log n) preprocessing, O(log n) per query. Euler + sparse table: O(n log n) preprocessing, O(1) per query.

### 68. Heavy-light decomposition

**Definition:** Splitting a tree into paths so that any root-to-vertex path crosses only O(log n) of them, turning path queries into range queries.

**Complexity:** O(log² n) per path query or update with a segment tree.

### 69. Centroid decomposition

**Definition:** Recursively splitting a tree at its centroid (a vertex whose removal leaves pieces of at most half the size), giving a recursion of depth O(log n).

**Complexity:** O(n log n) for the decomposition. Many path-counting problems solved in O(n log n) or O(n log² n).

### 70. Link-cut trees

**Definition:** A dynamic forest structure supporting linking trees, cutting edges and path queries, all in O(log n) amortized time.

**Complexity:** O(log n) amortized per operation.

### 71. Euler tour trees

**Definition:** Representing each tree of a dynamic forest by its Euler tour stored in a balanced search tree, so trees can be split and joined quickly.

**Complexity:** O(log n) per operation.

### 72. Tree isomorphism (AHU algorithm)

**Definition:** Deciding whether two rooted trees have the same shape, in linear time, through canonical encoding.

**Complexity:** O(n) with integer labeling, O(n log n) with sorting.

### 73. Tree dynamic programming with rerooting

**Definition:** Computing a value for every vertex as if it were the root, in linear total time, by reusing subtree results.

**Complexity:** O(n).

## B4. Maximum flow and minimum cut

### 74. Ford-Fulkerson and Edmonds-Karp

**Definition:** Computing the maximum flow from a source to a sink by repeatedly finding augmenting paths in the residual graph.

**Complexity:** Edmonds-Karp O(n × m²).

### 75. Dinic's algorithm

**Definition:** A maximum-flow algorithm that pushes flow along shortest paths in layers, using blocking flows.

**Complexity:** O(n² × m) in general. O(m × √n) for unit-capacity graphs, including bipartite matching.

### 76. Push-relabel (Goldberg-Tarjan)

**Definition:** A maximum-flow algorithm that pushes excess flow locally between vertices, guided by height labels, instead of finding whole paths.

**Complexity:** O(n² × √m) with highest-label selection. Very fast in practice with the heuristics.

### 77. Min cut extraction (max-flow min-cut theorem)

**Definition:** After a maximum flow, extracting the minimum s-t cut: the cheapest set of edges whose removal separates source from sink. Its capacity equals the maximum flow.

**Complexity:** O(n + m) after the max-flow.

### 78. Stoer-Wagner global minimum cut

**Definition:** Finding the minimum cut over all possible partitions of an undirected weighted graph, without choosing a source or sink.

**Complexity:** O(n × m + n² log n).

### 79. Karger and Karger-Stein randomized min cut

**Definition:** Finding a global minimum cut by randomly contracting edges, repeated many times.

**Complexity:** Karger-Stein: O(n² log³ n) for a high-probability result.

### 80. Gomory-Hu tree

**Definition:** A weighted tree that encodes the minimum s-t cut value for every pair of vertices, using only n−1 max-flow computations.

**Complexity:** n−1 max-flow computations.

### 81. Minimum-cost flow (successive shortest paths with potentials)

**Definition:** Sending a required amount of flow through a network at minimum total cost, respecting capacities.

**Complexity:** O(F × m log n), where F is the flow value. Capacity scaling makes it polynomial in the input size.

### 82. Network simplex

**Definition:** The simplex method specialized for min-cost flow, operating on spanning trees instead of matrices.

**Complexity:** Exponential in the worst case. Typically among the fastest min-cost flow methods in practice.

### 83. Circulation with demands and lower bounds

**Definition:** Finding a flow where every vertex has a fixed supply or demand, and every edge has a minimum and maximum flow.

**Complexity:** One max-flow (or min-cost flow).

## B5. Matching and assignment

### 84. Hopcroft-Karp (maximum bipartite matching)

**Definition:** The fastest classical algorithm for maximum-cardinality matching in bipartite graphs.

**Complexity:** O(m √n).

### 85. Hungarian algorithm (assignment problem)

**Definition:** Finding a minimum-cost perfect matching in a weighted bipartite graph: the optimal one-to-one assignment.

**Complexity:** O(n³).

### 86. Auction algorithm (Bertsekas)

**Definition:** Solving the assignment problem through a simulated auction where people bid for objects, adjusting prices.

**Complexity:** Pseudo-polynomial. With ε-scaling, very fast in practice, and easy to parallelize.

### 87. Edmonds' blossom algorithm (general graph matching)

**Definition:** Maximum matching in general (non-bipartite) graphs, handling the odd cycles ("blossoms") that break bipartite methods.

**Complexity:** O(n² × m) basic. O(m √n) with the Micali-Vazirani algorithm (cardinality).

### 88. Stable matching (Gale-Shapley)

**Definition:** Matching two sides with preference lists so that no pair would both rather be matched with each other than with their current partners.

**Complexity:** O(n²).

### 89. Approximate and greedy weighted matching

**Definition:** Fast matchings that are provably within a factor of the best weight, for graphs too large for exact algorithms.

**Complexity:** O(m log m) greedy, O(m) for the linear-time methods.

### 90. König's theorem (minimum vertex cover in bipartite graphs)

**Definition:** In bipartite graphs, the size of a maximum matching equals the size of a minimum vertex cover (a smallest vertex set touching every edge). The cover can be constructed from the matching.

**Complexity:** O(m √n), dominated by the matching.

### 91. Disjoint paths (Menger's theorem)

**Definition:** The maximum number of edge-disjoint (or vertex-disjoint) paths between two vertices equals the minimum number of edges (or vertices) that separate them.

**Complexity:** O(m √n) for unit-capacity flow with Dinic.

### 92. Multi-commodity flow

**Definition:** Routing several different flows (commodities), each with its own source, sink and demand, through shared capacities.

**Complexity:** Polynomial as an LP. Approximation schemes are faster in practice.

### 93. Graph cuts for labeling (Boykov-Kolmogorov, α-expansion)

**Definition:** Assigning labels to vertices by minimizing an energy function (data cost + smoothness cost), solved exactly or approximately with min cuts.

**Complexity:** Each expansion step is one max-flow. Usually converges in a few rounds.

### 94. Transportation problem and b-matching

**Definition:** Matching where vertices can have more than one partner (capacities b(v)), including shipping goods from suppliers to customers at minimum cost.

**Complexity:** That of the min-cost flow method used.

## B6. Routing problems

### 95. Chinese postman (route inspection)

**Definition:** The shortest closed walk that traverses every edge at least once.

**Complexity:** Polynomial: all-pairs shortest paths between odd vertices, plus a weighted matching.

### 96. Eulerian paths and circuits (Hierholzer's algorithm)

**Definition:** A walk that uses every edge exactly once (a circuit if it returns to the start).

**Complexity:** O(m).

### 97. Held-Karp (exact TSP by dynamic programming)

**Definition:** Solving the traveling salesman problem exactly by dynamic programming over subsets of vertices.

**Complexity:** O(n² × 2ⁿ) time, O(n × 2ⁿ) memory. Practical up to about 20–25 vertices.

### 98. TSP heuristics (Christofides, 2-opt, Or-opt, Lin-Kernighan)

**Definition:** Practical algorithms that find near-optimal traveling salesman tours for large instances.

**Complexity:** 2-opt passes cost O(n²) each, faster with neighbor lists. LKH is very effective on large instances.

### 99. Vehicle routing heuristics (Clarke-Wright savings, local search)

**Definition:** Planning routes for several vehicles from a depot to serve customers, with capacities and often time windows.

**Complexity:** Savings O(n² log n). Local search and metaheuristics trade time for quality.

### 100. Maximum weight closure (project selection)

**Definition:** Choosing a set of items with maximum total value, where choosing an item requires choosing all of its prerequisites. It's solved exactly with a minimum cut.

**Complexity:** One max-flow.

---
