# Part 4: Knowledge graphs with LLMs, operations and observability (#151–200)

Same format and the same contract (roles; rules K1–K8; guardrails KG1–KG6). This is the final part.

## D1. Knowledge graphs with LLMs

### 151. Text-to-query (text-to-SPARQL / text-to-Cypher)

**Definition:** Translating a natural-language question into a formal graph query with a language model.

### 152. Schema-grounded prompting (schema subset selection)

**Definition:** Giving the model only the part of the schema relevant to the question, with clear descriptions, so it uses real names correctly.

### 153. Query validation and repair loop

**Definition:** Checking a generated query before execution, and fixing it using concrete error feedback.

### 154. Entity linking for questions

**Definition:** Finding which graph entities a user's question refers to.

### 155. GraphRAG community summaries (global search)

**Definition:** Answering broad, corpus-wide questions by summarizing graph communities in advance and combining those summaries at query time.

### 156. GraphRAG local search

**Definition:** Answering questions about specific entities by gathering their neighborhood: related entities, relations, community summaries and source text chunks.

### 157. Subgraph retrieval (k-hop neighborhoods with pruning)

**Definition:** Extracting a small, relevant subgraph around the question's entities to use as context or reasoning input.

### 158. Path retrieval and ranking

**Definition:** Finding and ranking the paths that connect question entities, as explanations or as evidence chains.

### 159. Hybrid vector and graph retrieval

**Definition:** Combining semantic search over text with graph traversal over structured facts.

### 160. Graph-aware reranking

**Definition:** Reranking retrieved passages or facts using graph signals, alongside text relevance.

### 161. Context linearization (turning subgraphs into text)

**Definition:** Converting retrieved triples and subgraphs into compact text the model can read reliably.

### 162. Grounded generation with fact-level citations

**Definition:** Generating answers where every claim is tied to specific graph facts or source passages.

### 163. Fact verification against the knowledge graph

**Definition:** Checking whether a claim (from text or a model) is supported, contradicted or not covered by the graph.

### 164. Hallucination detection with the knowledge graph

**Definition:** Detecting statements in model output that are unsupported by, or conflict with, the graph and sources.

### 165. LLM-guided graph exploration (Think-on-Graph style)

**Definition:** Letting the language model choose which edges to follow, step by step, as a beam search over the graph.

### 166. ReAct-style agent with graph tools

**Definition:** An agent that alternates reasoning and tool calls (entity search, neighbor lookup, query execution) to answer questions over a graph.

### 167. Temporal knowledge graph as agent memory

**Definition:** Storing what an agent learns from conversations and documents as a time-aware graph of entities and facts.

### 168. Memory consolidation and forgetting

**Definition:** Merging, summarizing and expiring agent memory, so it stays accurate, compact and appropriate.

### 169. LLM-assisted curation with human review

**Definition:** Using a language model to propose graph changes, with structured human approval before they're applied.

### 170. KG-to-text generation (verbalization)

**Definition:** Turning graph facts into natural-language descriptions.

## D2. Operations and updates

### 171. Incremental graph updates from change data capture

**Definition:** Streaming changes from source systems into the graph continuously, instead of periodic full reloads.

### 172. MERGE and upsert semantics

**Definition:** Writing nodes and edges by matching on keys first, creating them only if they don't exist.

### 173. Entity and fact versioning (bitemporal updates)

**Definition:** Updating facts in a way that keeps their history and the record of corrections.

### 174. Entity merge and split operations

**Definition:** Combining duplicate entities into one, or separating a wrongly merged entity, safely and reversibly.

### 175. Change propagation to derived data

**Definition:** Updating everything computed from the graph (inferences, embeddings, summaries, caches, indexes) when the graph changes.

### 176. Incremental community detection and summary refresh

**Definition:** Updating communities and their LLM summaries after graph changes, without recomputing everything.

### 177. Incremental PageRank

**Definition:** Updating PageRank scores after graph changes, without starting from scratch.

### 178. Distributed graph processing (Pregel / bulk synchronous parallel)

**Definition:** A model for running graph algorithms across many machines in synchronized rounds of vertex computation and message passing.

### 179. Access control on graphs

**Definition:** Enforcing who can see or change which nodes, edges and properties.

### 180. Supernode handling

**Definition:** Managing nodes with extremely many connections, which make traversals slow and results noisy.

### 181. Bulk import

**Definition:** Loading large datasets into a graph efficiently, bypassing the slower transactional write path.

### 182. Partition rebalancing

**Definition:** Moving graph data between machines to fix load imbalance or after adding capacity.

### 183. Backup, restore and consistency checks

**Definition:** Making recoverable copies of the graph and proving they can be restored correctly.

### 184. Schema migration in production

**Definition:** Applying schema changes to a live graph without downtime or data loss.

### 185. Right to erasure in knowledge graphs

**Definition:** Fully removing a person's data from the graph and from everything derived from it.

## D3. Observability and quality

### 186. Knowledge graph quality dashboard

**Definition:** Ongoing measurement of accuracy, completeness, consistency and coverage, per entity type and source.

### 187. Constraint violation monitoring

**Definition:** Continuously tracking schema and logical violations in the graph.

### 188. Query performance monitoring and plan regression

**Definition:** Tracking query latency, resource use and plan changes, to catch slow queries and regressions.

### 189. Degree distribution and growth drift

**Definition:** Monitoring how the graph's structure and size change over time.

### 190. Orphans, dangling edges and islands

**Definition:** Finding disconnected or broken parts of the graph.

### 191. Freshness lag

**Definition:** The delay between a change in the source and its appearance in the graph and derived data.

### 192. Duplicate entity rate estimation

**Definition:** Estimating how many entities in the graph are unrecognized duplicates.

### 193. Provenance coverage

**Definition:** The share of facts that carry complete provenance: source, method, version, time and confidence.

### 194. Text-to-query accuracy

**Definition:** Measuring how often generated graph queries return the correct answer.

### 195. GraphRAG and graph-grounded QA evaluation

**Definition:** Measuring the quality of answers that use graph retrieval.

### 196. Prediction quality monitoring

**Definition:** Tracking the real-world accuracy of predicted and inferred facts after they're used.

### 197. Canary queries and probes

**Definition:** Fixed test queries and test writes run continuously to check the graph system end to end.

### 198. Audit logging

**Definition:** A tamper-evident record of who accessed or changed what in the graph, and why.

### 199. Cost monitoring

**Definition:** Tracking the cost of graph storage, queries, analytics and LLM-based features.

### 200. Feedback loop for continuous improvement

**Definition:** Systematically turning observed failures into fixes in extraction, linking, schema, retrieval and prompts.

---

## How the 200 entries fit together

1. **Model:** standards-based schema (#1–12), shapes (#5), stable IDs (#8), time (#12), provenance (#9–10).
2. **Build:** extraction (#25–34) → entity resolution (#35–39) → normalization (#40, #49) → validation (#5, #47) → truth discovery (#50), with MERGE writes (#172) and review (#169).
3. **Reason:** rules and ontologies (#85–94), mined rules (#95), consistency (#97, #100), with inferred facts marked (K2).
4. **Learn:** embeddings and GNNs (#101–130) for completion, typing and alignment (#131–143), calibrated (#144), explained (#145), evaluated without leakage (#149).
5. **Answer:** entity linking (#154) → templates or text-to-query with validation (#61, #151–153) → subgraph, path and hybrid retrieval (#157–160) → GraphRAG local or global (#155–156) → grounded, cited answers (#161–164).
6. **Operate:** CDC updates (#171), versioning (#173), merges and splits (#174), change propagation (#175), access control (#179), supernode handling (#180), erasure (#185).
7. **Observe:** quality (#186–193), text-to-query and QA evaluation (#194–195), prediction monitoring (#196), probes (#197), audits (#198), cost (#199), and the feedback loop (#200).
