# Part 2: Querying, graph algorithms and reasoning (#51–100)

Same format and the same contract (roles; rules K1–K8; guardrails KG1–KG6).

## B1. Query languages and execution

### 51. SPARQL 1.1 (W3C)

**Definition:** The W3C standard query and update language for RDF graphs.

### 52. Cypher / openCypher

**Definition:** A declarative property-graph query language built around ASCII-art patterns, with an open specification (openCypher).

### 53. GQL (ISO/IEC 39075:2024)

**Definition:** The ISO international standard query language for property graphs, published in 2024.

### 54. Gremlin (Apache TinkerPop)

**Definition:** A step-by-step traversal language for property graphs, from the Apache TinkerPop project.

### 55. Subgraph pattern matching (VF2 / backtracking)

**Definition:** Finding every place in the data graph where a small query pattern graph appears.

### 56. Worst-case optimal joins (Leapfrog Triejoin)

**Definition:** A join algorithm that processes one variable at a time across all patterns, avoiding huge intermediate results on cyclic queries.

### 57. Join ordering and cardinality estimation (query plans)

**Definition:** Choosing the order in which a query's patterns are evaluated, based on estimates of how many results each produces.

### 58. Regular path queries and property paths

**Definition:** Queries that match paths whose edge sequence follows a regular expression, such as "one or more `subClassOf` edges".

### 59. Federated queries

**Definition:** One query that combines data from several graph endpoints or databases.

### 60. Ontology-based query rewriting (OBDA, OWL 2 QL)

**Definition:** Answering queries over an ontology by rewriting them into queries over the underlying databases, without copying data into a graph.

### 61. Parameterized queries and query templates

**Definition:** Separating query structure from values, so values are passed as typed parameters instead of being pasted into the query text.

### 62. Pagination and result caching

**Definition:** Returning large results in pages, and reusing results for repeated queries.

## B2. Traversal and path algorithms

### 63. Breadth-first search (BFS)

**Definition:** Exploring a graph level by level from a start node: all neighbors first, then their neighbors, and so on.

### 64. Depth-first search (DFS)

**Definition:** Exploring a graph by going as deep as possible along each branch before backtracking.

### 65. Bidirectional BFS

**Definition:** Finding a shortest path by searching from both endpoints at once until the two searches meet.

### 66. Dijkstra's algorithm

**Definition:** Finding the lowest-cost paths from a start node in a graph with non-negative edge weights.

### 67. A* search

**Definition:** Dijkstra guided by a heuristic estimate of the remaining distance to the target.

### 68. Yen's k-shortest paths

**Definition:** Finding the k best simple paths (without repeated nodes) between two nodes, not just the best one.

### 69. Random walk with restart

**Definition:** Simulating random moves through the graph that jump back to the start node with some probability, to measure relevance to that start node.

### 70. Metapath-constrained traversal

**Definition:** Traversing only along a specific sequence of node and edge types, such as Author → Paper → Venue.

### 71. Reachability indexes (2-hop labeling)

**Definition:** Precomputed labels that answer "can node A reach node B?" without a traversal.

### 72. Transitive closure

**Definition:** Computing every pair (A, B) where B is reachable from A through some relation, such as all ancestors or all sub-parts.

## B3. Centrality and community detection

### 73. Degree centrality

**Definition:** Ranking nodes by their number of connections.

### 74. PageRank

**Definition:** Ranking nodes by importance, where a node is important if important nodes point to it.

### 75. Personalized PageRank (PPR)

**Definition:** PageRank where the random jumps return to a chosen set of seed nodes, measuring importance relative to those seeds.

### 76. Betweenness centrality (Brandes' algorithm)

**Definition:** Ranking nodes by how often they lie on shortest paths between other nodes: the bridges and brokers.

### 77. Closeness and harmonic centrality

**Definition:** Ranking nodes by how close they are, on average, to all others.

### 78. HITS and eigenvector centrality

**Definition:** Importance measures based on the principal eigenvector of the graph. HITS separates "hubs" (pointing to good authorities) from "authorities" (pointed to by good hubs).

### 79. Connected components (union-find)

**Definition:** Grouping nodes into sets where every node can reach every other through edges, ignoring direction.

### 80. Strongly connected components (Tarjan / Kosaraju)

**Definition:** Groups of nodes in a directed graph where each node can reach every other node following edge directions.

### 81. Louvain community detection

**Definition:** Finding groups of densely connected nodes by greedily maximizing modularity.

### 82. Leiden community detection

**Definition:** An improvement on Louvain that guarantees well-connected communities.

### 83. Label propagation

**Definition:** A fast community-detection (or classification) method where nodes repeatedly adopt their neighbors' most common label.

### 84. k-core decomposition

**Definition:** Finding nested subgraphs where every node has at least k connections within the subgraph.

## B4. Reasoning

### 85. RDFS entailment rules

**Definition:** The standard inference rules that derive new triples from RDFS schema statements.

### 86. OWL 2 RL rule-based reasoning

**Definition:** The OWL 2 profile designed to be implemented with rules, which scales to large data.

### 87. Forward chaining with the Rete algorithm

**Definition:** Applying rules to data proactively, deriving every consequence and storing it, using an efficient match network (Rete).

### 88. Backward chaining (goal-driven reasoning)

**Definition:** Starting from a question (goal) and working backward through rules to find supporting facts.

### 89. Datalog with semi-naive evaluation

**Definition:** A logic rule language (recursive, without functions) evaluated efficiently by only processing new facts each round.

### 90. Materialization versus query-time reasoning

**Definition:** Choosing whether to compute and store inferred facts ahead of time, or to compute them on demand during queries.

### 91. Incremental maintenance of inferences (DRed)

**Definition:** Updating materialized inferences when facts are added or deleted, without recomputing everything.

### 92. Equality reasoning (owl:sameAs handling)

**Definition:** Handling statements that two identifiers denote the same entity, without exploding the number of triples.

### 93. Description logics and tableau reasoning

**Definition:** The formal logic family behind OWL, with tableau algorithms that decide satisfiability, subsumption and consistency.

### 94. OWL 2 EL classification (consequence-based reasoning)

**Definition:** Fast computation of the full class hierarchy for large ontologies using the OWL 2 EL profile.

### 95. Rule mining (AMIE-style)

**Definition:** Automatically discovering logical rules that hold frequently in a knowledge graph.

### 96. Open-world versus closed-world assumption

**Definition:** Whether missing information means "unknown" (open world) or "false" (closed world).

### 97. Inconsistency detection and explanation (justifications)

**Definition:** Finding facts and axioms that contradict each other, and the minimal set of statements that causes each contradiction.

### 98. Probabilistic logic (Markov logic networks, probabilistic soft logic)

**Definition:** Combining logical rules with probabilities, so rules can be soft and facts uncertain.

### 99. Temporal reasoning (Allen's interval algebra)

**Definition:** Reasoning about how time intervals relate: before, meets, overlaps, during, starts, finishes, equals, and their inverses.

### 100. Inconsistency repair

**Definition:** Choosing which facts or axioms to remove or change to resolve contradictions, with minimal loss.

---
