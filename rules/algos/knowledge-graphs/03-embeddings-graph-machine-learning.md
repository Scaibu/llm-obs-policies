# Part 3: Embeddings and graph machine learning (#101–150)

Same format and the same contract (roles; rules K1–K8; guardrails KG1–KG6).

## C1. Knowledge graph embeddings

### 101. TransE

**Definition:** An embedding model where each relation is a translation (a vector shift) between entity vectors: head + relation ≈ tail.

### 102. TransH and TransR

**Definition:** TransE extensions that project entities into relation-specific spaces, so one entity can behave differently per relation.

### 103. DistMult

**Definition:** A bilinear embedding model whose score is the elementwise product of the head, relation and tail vectors, summed.

### 104. ComplEx

**Definition:** DistMult with complex-valued vectors, which can model both symmetric and asymmetric relations.

### 105. RotatE

**Definition:** An embedding model where each relation rotates the head entity in complex space to reach the tail.

### 106. TuckER

**Definition:** An embedding model based on Tucker tensor decomposition, with a shared core tensor that captures interactions between entities and relations.

### 107. ConvE

**Definition:** An embedding model that applies 2D convolution over reshaped head and relation embeddings to score candidate tails.

### 108. Negative sampling (uniform and Bernoulli)

**Definition:** Creating false triples to train embeddings, since knowledge graphs only store true facts.

### 109. Self-adversarial negative sampling

**Definition:** Weighting negative samples by how plausible the current model finds them, so training focuses on hard negatives.

### 110. Loss functions and scoring schemes for KG embeddings

**Definition:** The training objectives that turn triple scores into learning signals.

### 111. Filtered ranking evaluation (MRR, Hits@k)

**Definition:** The standard evaluation of link prediction: how highly does the model rank the true answer among all candidates?

### 112. DeepWalk

**Definition:** Learning node embeddings by treating random walks as "sentences" and training a word-embedding model on them.

### 113. node2vec

**Definition:** DeepWalk with biased random walks that can favor local (BFS-like) or exploratory (DFS-like) movement.

### 114. Metapath2vec

**Definition:** Random-walk embeddings for heterogeneous graphs, where walks follow given metapaths (type sequences).

### 115. Inductive entity representations (NodePiece and similar)

**Definition:** Representing entities by composing reusable parts (anchor nodes, relation types), so new, unseen entities get embeddings without retraining.

### 116. Text-enhanced KG embeddings (KG-BERT, SimKGC style)

**Definition:** Scoring or embedding triples using the text of entity names and descriptions, through language models.

## C2. Graph neural networks

### 117. Message passing (the general GNN framework)

**Definition:** A framework where each node updates its representation by collecting "messages" from its neighbors, repeated over several layers.

### 118. GCN (graph convolutional network)

**Definition:** A message-passing model that averages neighbor features with degree-based normalization, then applies a shared linear transformation.

### 119. GraphSAGE (sampling and aggregation)

**Definition:** An inductive GNN that learns aggregation functions over sampled neighbors, so it works on unseen nodes and large graphs.

### 120. GAT (graph attention network)

**Definition:** A GNN that learns how much attention to give each neighbor, instead of fixed averaging.

### 121. R-GCN (relational graph convolutional network)

**Definition:** A GCN extension for multi-relational graphs, with separate weights per relation type.

### 122. CompGCN

**Definition:** A GNN that learns both entity and relation embeddings together, by composing them in each message.

### 123. Heterogeneous graph transformer (HGT)

**Definition:** An attention-based GNN for graphs with many node and edge types, with type-specific attention parameters.

### 124. Graph transformers with positional encodings

**Definition:** Transformer models over graph nodes, with positional and structural encodings that tell the model where each node sits in the graph.

### 125. Mini-batch subgraph training (Cluster-GCN, GraphSAINT)

**Definition:** Training GNNs on large graphs by sampling small subgraphs as mini-batches.

### 126. Over-smoothing and over-squashing mitigation

**Definition:** Fixing two failure modes of deep GNNs: node vectors becoming all alike (over-smoothing), and distant information getting squeezed through bottlenecks (over-squashing).

### 127. Temporal graph networks (TGN)

**Definition:** GNNs for graphs where edges arrive over time, keeping a memory per node that's updated with each event.

### 128. SEAL (link prediction from enclosing subgraphs)

**Definition:** Predicting whether a link exists by classifying the local subgraph around the two candidate nodes with a GNN.

### 129. Node classification setup (transductive and inductive)

**Definition:** Predicting labels for nodes (entity type, risk class, topic) from their features and graph neighborhood.

### 130. Graph pooling and readout

**Definition:** Combining node representations into a single representation of a whole graph or subgraph.

## C3. Graph machine learning tasks

### 131. Link prediction heuristics (common neighbors, Adamic-Adar, Jaccard, Katz)

**Definition:** Simple scores from graph structure that estimate how likely two nodes are to be linked.

### 132. Knowledge graph completion pipeline

**Definition:** The end-to-end process of predicting missing facts, validating them and adding approved ones to the graph.

### 133. Entity alignment across knowledge graphs

**Definition:** Finding which entities in two different knowledge graphs refer to the same real-world thing.

### 134. Entity typing with embeddings and models

**Definition:** Predicting an entity's types (classes) from its embedding, relations and text.

### 135. Relation prediction (which relation links two entities)

**Definition:** Predicting the relation type between two known-related entities.

### 136. Graph anomaly detection

**Definition:** Finding unusual nodes, edges or subgraphs that differ from normal patterns.

### 137. Fraud ring detection

**Definition:** Finding groups of accounts or entities working together, revealed by shared attributes and interactions.

### 138. Knowledge-graph-based recommendation

**Definition:** Using knowledge graph relations between items (and users) to improve and explain recommendations.

### 139. Collective classification

**Definition:** Classifying connected nodes together, using the predicted labels of neighbors as evidence for each other.

### 140. Weisfeiler-Lehman (WL) test and graph kernels

**Definition:** An iterative node-relabeling procedure that summarizes graph structure, used to compare graphs and to understand what GNNs can distinguish.

### 141. Graph edit distance and subgraph similarity

**Definition:** The minimum cost of node and edge insertions, deletions and substitutions to turn one graph into another.

### 142. Hyperbolic embeddings

**Definition:** Embedding nodes in hyperbolic space, which naturally represents tree-like hierarchies with low distortion.

### 143. Temporal knowledge graph completion

**Definition:** Predicting missing facts when facts are valid at specific times: (h, r, t, time).

### 144. Calibration of link prediction scores

**Definition:** Converting raw model scores into reliable probabilities that a predicted fact is true.

### 145. GNN explainability (GNNExplainer and similar)

**Definition:** Identifying which edges and node features were most important for a GNN's prediction.

### 146. Graph contrastive learning

**Definition:** Learning node or graph representations without labels, by making two augmented views of the same graph agree.

### 147. Few-shot and inductive relation learning

**Definition:** Predicting facts for relations with very few examples, or for entities and graphs not seen in training.

### 148. Active learning for knowledge graph curation

**Definition:** Choosing which candidate facts people should review next, to improve quality fastest with limited review time.

### 149. Leakage-free evaluation splits

**Definition:** Splitting data so test answers can't be inferred trivially from training data.

### 150. Bias and fairness in graph machine learning

**Definition:** Detecting and reducing systematic unfairness in graph-based predictions, often amplified by network structure.

---

Part 4 (#151–200) covers knowledge graphs with LLMs (text-to-query, entity linking for questions, GraphRAG local and global search, subgraph and path retrieval, hybrid vector-graph retrieval, fact verification, graph agents and agent memory), plus operations (incremental updates, MERGE semantics, change propagation, access control, distributed processing) and observability (quality, freshness, supernodes, text-to-query accuracy, GraphRAG evaluation).
