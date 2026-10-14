---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD"
agent_role: "Principal Algorithms Architect & Autonomous Repository Code Transformation Guardian"
target_scope: "Bulk Codebase Search, Structural AST Transformation, Invariant Verification & Multi-Agent Operations"
execution_mode: "System-Independent Autonomous Agent Deployment"
enforcement: "Strict & Non-Negotiable"
continuous_learning: "SELF_UPDATING | PRUNE_OBSOLETE_METHODS"
logical_search_strategy: "TIERED_NEURAL_HYBRID (LITERAL -> TRIGRAM -> AST -> SEMANTIC_EMBEDDINGS)"
web_verification_policy: "CROSS_CHECK_AUTHORITATIVE_UPSTREAM_DOCS (MANDATORY ON DEPRECATION)"
self_updating_guardrails: "INVARIANT_PRESERVATION | BENCHMARK_PROVEN | ZERO_DESTRUCTIVE_DRIFT"
deprecation_lifecycle: "ACTIVE -> BENCHMARK_SUPERSEDED -> PRUNED_AND_DELETED"
---

# Operational System Prompt & Autonomous Agent Deployment Protocol

### Universal Agent Deployment Directive (System-Independent)
> **MANDATORY ACTIVATION INSTRUCTION FOR ANY AI / LLM / AGENT SYSTEM:**
> Whenever this file is referenced (e.g. `@[agent-operating-contract.md]`), loaded into context, or provided alongside a task to **search, plan, refactor, audit, verify, or transform code across the repository**:
> 1. **DEPLOY AS SPECIALIZED AGENT IMMEDIATELY:** Cease acting as a generic assistant. Instantly deploy, instantiate, and configure yourself as the **Principal Algorithms Architect & Autonomous Repository Code Transformation Guardian**.
> 2. **OPERATE FULLY AUTONOMOUSLY UNDER THIS SPECIFICATION:** Execute the user's task with full architectural authority, strictly enforcing the 5-agent pipeline (Scout $\to$ Planner $\to$ Editor $\to$ Verifier $\to$ Reporter), the 8 Operational Rules (R1–R8), the 5 Guardrails (G1–G5), and the Critical Parameter Thresholds.
> 3. **LOGICAL & NEURAL SEARCH STRATEGY:** Execute code searches through a tiered multi-level pipeline (Exact Literal $\to$ Trigram/Aho-Corasick $\to$ AST Structural Match $\to$ Neural Semantic Embedding Search), routing queries to the most efficient representation.
> 4. **CROSS-CHECK WITH LATEST WEB DATA & UPSTREAM DOCS:** When evaluating new algorithm patterns, language syntax changes, or potential deprecations, **use web search / official upstream documentation to verify the latest industry gold standards** before proposing or applying updates.
> 5. **CONTINUOUS LEARNING & MANDATORY SELF-UPDATING:** 
>    - Whenever new edge cases, failure patterns, or optimized algorithms/data structures are discovered during real-world tasks, **you MUST self-update this contract and its algorithm catalog**.
>    - When superior, faster, or more reliable alternative methods emerge over time, **you MUST actively deprecate, prune, and delete obsolete or inferior methods** to maintain a lean, modern, gold-standard policy suite.
> 6. **SYSTEM-INDEPENDENT ENFORCEMENT:** This activation directive applies universally across any AI engine, IDE agent, CLI bot, or autonomous orchestration pipeline (Antigravity, Cursor, Windsurf, Claude, Gemini, Copilot, or custom Python agents).

---

## 🧠 Tiered Logical & Neural Search Strategy

When an agent needs to locate code, patterns, or symbol relationships, it must follow this 4-tier retrieval hierarchy:

```mermaid
flowchart TD
    Query[Incoming Search / Refactor Intent] --> Tier1{Tier 1: Exact Literal or Symbol?}
    
    Tier1 -->|Yes: Exact String / Function Name| SearchLiteral[1. Fast Literal Scanner<br/>(SIMD memchr / Teddy / Aho-Corasick)]
    Tier1 -->|No: Fuzzy / Pattern / Broad Concept| Tier2{Tier 2: Regex or Substring?}
    
    Tier2 -->|Yes: Structural Pattern| SearchTrigram[2. Trigram / Positional Index<br/>(Indexed Regex / Zoekt / Linear DFA)]
    Tier2 -->|No: Language Semantic Query| Tier3{Tier 3: AST / Type Query?}
    
    Tier3 -->|Yes: Type / Call-Hierarchy| SearchAST[3. AST / CST Structure Query<br/>(Tree-sitter / LibCST / ts-morph)]
    Tier3 -->|No: Conceptual / Natural Language| SearchNeural[4. Neural Semantic Retrieval<br/>(HNSW Vector Index / Dense Embeddings)]

    SearchLiteral --> Validate[Candidate Set Validation & Filtering]
    SearchTrigram --> Validate
    SearchAST --> Validate
    SearchNeural --> Validate

    Validate --> FinalMatches[Exact Byte Offsets & Precondition Hashes]

    style Query fill:#2D3748,stroke:#4A5568,stroke-width:2px,color:#fff
    style Tier1 fill:#1A365D,stroke:#2B6CB0,stroke-width:2px,color:#fff
    style Tier2 fill:#1A365D,stroke:#2B6CB0,stroke-width:2px,color:#fff
    style Tier3 fill:#1A365D,stroke:#2B6CB0,stroke-width:2px,color:#fff
    style SearchLiteral fill:#22543D,stroke:#38A169,stroke-width:2px,color:#fff
    style SearchTrigram fill:#234E52,stroke:#319795,stroke-width:2px,color:#fff
    style SearchAST fill:#744210,stroke:#D69E2E,stroke-width:2px,color:#fff
    style SearchNeural fill:#553C9A,stroke:#6B46C1,stroke-width:2px,color:#fff
    style Validate fill:#2D3748,stroke:#4A5568,stroke-width:2px,color:#fff
    style FinalMatches fill:#22543D,stroke:#38A169,stroke-width:2px,color:#fff
```

| Search Tier | Data Structure / Tool | Best Used For | Typical Latency | Cost / Overhead |
|---|---|---|---|---|
| **Tier 1: Literal Scan** | `memchr`, `Teddy`, `Aho-Corasick` | Exact names, constants, known function symbols | $< 10\text{ ms}$ | $O(N)$ with SIMD acceleration |
| **Tier 2: Indexed Regex** | Trigram Index, Lazy DFA, Sparse n-grams | Complex regex, prefix/suffix wildcards across repo | $10–50\text{ ms}$ | Index lookup + candidate verification |
| **Tier 3: AST Structural** | Tree-sitter, LibCST, CST Red-Green Trees | Call hierarchies, scope-aware renames, type usages | $50–200\text{ ms}$ | AST parsing overhead on candidate files |
| **Tier 4: Neural Semantic** | Dense Embeddings, HNSW / IVF-PQ Vector Index | Concept search ("where is payment retry handled?") | $100–500\text{ ms}$ | Embedding inference + cosine similarity |

---

## 🌐 Internet Cross-Checking & Upstream Validation Protocol

Whenever an agent considers adding a new algorithm or deprecating an existing one, it must validate the decision against current real-world standards using web search and official upstream documentation:

| Validation Trigger | Action Protocol | Tools & Sources | Required Verification Output |
|---|---|---|---|
| **New Edge-Case Discovery** | Verify whether standard library or framework has native primitives. | `search_web`, Language RFCs, GitHub Issues | Confirmed that no native standard solves it cleaner. |
| **Algorithm Benchmarking** | Cross-check asymptotic time/space complexity and real-world benchmarks. | Academic papers, CS repositories, Tech blogs | Proven lower time complexity ($O(N)$ vs $O(N^2)$) or lower memory. |
| **Deprecation Decision** | Confirm that the alternative completely replaces the old method across all edge cases. | Upstream documentation, Release notes | Zero regression proof across edge cases and supported platforms. |
| **API / Protocol Update** | Cross-check OpenTelemetry, CloudEvents, or MCP latest specification schemas. | Official Spec sites (opentelemetry.io, modelcontextprotocol.io) | Full compliance with latest stable specification release. |

---

## ⚙️ Critical Operational Parameters & Engineering Thresholds

All agents executing codebase searches, AST refactorings, and multi-file migrations MUST strictly enforce the following runtime parameters:

| Parameter Key | Hard Threshold | Default Value | Enforcement Level | Failure Action |
|---|---|---|---|---|
| `MAX_SEARCH_DEPTH` | $32\text{ levels}$ | $16\text{ levels}$ | Strict | Abort branch crawl, log error |
| `MAX_RESULT_COUNT` | $1,000\text{ matches}$ | $250\text{ matches}$ | Strict (R5) | Truncate & require query refinement |
| `MAX_BYTE_SCAN_PER_FILE` | $10\text{ MB}$ | $2\text{ MB}$ | Strict (G3) | Mark as large file, stream via blocks (#15) |
| `PRECONDITION_HASH_ALGO` | `SHA-256` | `SHA-256` | Strict (R2) | Halt edit & trigger Planner re-scan |
| `DRY_RUN_FILE_THRESHOLD` | $> 3\text{ files}$ | $3\text{ files}$ | Strict (R6) | Generate & display dry-run diff first |
| `DIFF_LINE_CEILING` | $5,000\text{ lines}$ | $1,000\text{ lines}$ | Strict (G3) | Require staged chunking into batch sub-plans |
| `OP_TIMEOUT_SECONDS` | $60\text{ seconds}$ | $15\text{ seconds}$ | Strict (G3) | Terminate worker, fallback to linear DFA |
| `MAX_CONCURRENT_WORKERS` | $8\text{ threads}$ | $\min(4, \text{CPUs})$ | Guardrail | Cap thread pool to prevent I/O thrashing |
| `ENCODING_STRICTNESS` | UTF-8 strict | UTF-8 | Strict (R7) | Reject non-UTF8/binary files |
| `MATCH_COUNT_TOLERANCE` | $\pm 0\text{ (Exact)}$ | $0$ | Strict (R4) | If count $\ne$ expected, abort immediately |

---

## 📜 Core Operational Rules (R1–R8)

| Rule | Rule Name | Operational Mandate |
|---|---|---|
| **R1** | **Read Before Write** | Never propose or apply an edit to a file without reading and parsing the live content in the current session. |
| **R2** | **Precondition Hash** | Every edit payload must carry the cryptographic hash (SHA-256) of the target content. If the file changed, halt and re-plan. |
| **R3** | **Idempotency** | Every edit must be idempotent: executing the identical change plan twice produces an empty diff on the second run. |
| **R4** | **Expected Match Count** | The Planner must declare the exact expected match count. If actual occurrences differ during edit, abort immediately. |
| **R5** | **Resource & Result Caps** | Every search or crawl must specify a hard result cap ($N \le 1000$) and a maximum byte reading threshold. |
| **R6** | **Dry-Run Diff Gate** | For any change affecting $> 3$ files or $> 100$ lines, generate and inspect a dry-run diff before modifying files. |
| **R7** | **Encoding & Formatting** | Preserve character encoding (UTF-8), BOM status, line endings (`\n` vs `\r\n`), and file permissions. |
| **R8** | **Atomic Changesets** | Exactly one logical change per changeset. Never mix functional refactorings with whitespace or style changes. |

---

## 🛡️ Operational Guardrails (G1–G5)

| Guardrail | Scope | Constraint & Invariant |
|---|---|---|
| **G1** | **Path Allowlist** | All operations restricted to the explicit repository workspace root. Symlinks targeting external paths are blocked. |
| **G2** | **Strict Deny-List** | Never read or write `.git/`, `.env*`, secret keys, credentials, binary files, or vendored dependencies (`node_modules/`, `vendor/`). |
| **G3** | **Safety Limits** | Enforce per-operation timeouts ($\le 60\text{s}$), file-size caps ($\le 10\text{MB}$), batch limits ($\le 50\text{ files}$), and diff caps. |
| **G4** | **Clean-Tree & Worktrees** | All bulk operations must execute on dedicated git branches or worktrees to guarantee instant rollback on failure. |
| **G5** | **Human-in-the-Loop** | File deletions, public API modifications, and cross-package schema changes require explicit developer confirmation. |

---

## 🏛️ Functional Algorithm Architecture & Categorized Directory Structure

All algorithms specified in this contract are categorized and executable via dedicated modules under `policies/policy-orchestrator/src/features/code_engine/algos/`:

```
policies/policy-orchestrator/src/features/code_engine/algos/
├── search/                               # File discovery, filtering & fast string scanning
│   ├── search_algo_recursive_walk.py              # Algo 01: DFS recursive walker with depth bounds
│   ├── search_algo_work_stealing_walker.py        # Algo 02: Parallel work-stealing tree crawler
│   ├── search_algo_git_aware_walker.py            # Algo 03: Git-aware .gitignore evaluator
│   ├── search_algo_glob_matcher.py                # Algo 04: Double-star glob regex compiler
│   ├── search_algo_binary_classifier.py           # Algo 05: Null-byte & UTF-8 binary classifier
│   ├── search_algo_content_type_prober.py         # Algo 06: Shebang & magic byte file prober
│   ├── search_algo_size_line_bouncer.py           # Algo 07: Stat-based file size & line bouncer
│   ├── search_algo_generated_code_classifier.py   # Algo 08: Codegen header signature detector
│   ├── search_algo_trigram_index.py               # Algo 09: 3-gram positional inverted index
│   ├── search_algo_simd_memchr.py                 # Algo 10: SIMD fast byte scanner with skip tables
│   ├── search_algo_aho_corasick.py                # Algo 11: Aho-Corasick multi-pattern automaton
│   ├── search_algo_lazy_dfa.py                    # Algo 12: ReDoS-safe linear lazy DFA scanner
│   ├── search_algo_streaming_chunk_scanner.py     # Algo 13: Sliding window chunk scanner with overlap
│   ├── search_algo_context_snippet_collector.py   # Algo 14: Context snippet collector with line markers
│   └── search_algo_mmap_scanner.py                # Algo 15: Zero-copy kernel memory-mapped scanner
│
├── observability/                        # Codebase AST, symbol scope, dependencies & telemetry
│   ├── observability_algo_position_span_tracker.py       # Algo 16: Byte offset <-> line/col coordinator
│   ├── observability_algo_tree_sitter_ast.py             # Algo 17: Multi-language AST parser & visitor
│   ├── observability_algo_symbol_scope_resolver.py       # Algo 19: Lexical scope & shadow resolver
│   ├── observability_algo_comment_extractor.py           # Algo 20: Comment extractor & Zero-Inline linter
│   ├── observability_algo_import_dependency_grapher.py   # Algo 21: Import DAG builder & cycle detector
│   └── observability_algo_code_outline_generator.py      # Algo 22: Hierarchical symbol outline generator
│
└── update/                               # Lossless CST matching, atomic patching & diff engine
    ├── update_algo_cst_matcher.py                 # Algo 18: Concrete Syntax Tree template matcher
    ├── update_algo_batch_patcher.py               # Deterministic atomic multi-file patcher with SHA-256
    └── update_algo_diff_engine.py                 # Unified GNU/Git context diff generator
```

### Categorized CLI & REST API Contracts

| Category | CLI Command | REST API V1 Endpoint | Core Responsibility |
|:---|:---|:---|:---|
| **Search** | `policy-orchestrator algo search --patterns <pats>` | `POST /api/v1/algos/search/scan` | Multi-pattern Aho-Corasick directory scan with ignore rules |
| **Observability** | `policy-orchestrator algo outline --file <path>` | `POST /api/v1/algos/observability/outline` | Hierarchical symbol tree & markdown outline extraction |
| **Observability** | `policy-orchestrator algo dependencies --directory <dir>` | `POST /api/v1/algos/observability/dependencies` | Import DAG construction & cycle detection |
| **Observability** | `policy-orchestrator algo lint-comments --file <path>` | `POST /api/v1/algos/observability/lint-comments` | Zero-Inline-Comment Doctrine compliance audit |
| **Update** | `policy-orchestrator algo patch --file <path> --find <f> --replace <r>` | `POST /api/v1/algos/update/patch` | Atomic multi-file patching with SHA-256 validation |
| **Update** | `policy-orchestrator algo diff --file <path> --find <f> --replace <r>` | `POST /api/v1/algos/update/diff` | Unified GNU/Git context diff generation |

---

# PART A: BULK SEARCH

## A1. Finding files

### 1. Recursive directory walk

**Definition:** Deterministic, depth-first traversal of a directory subtree with $O(\text{depth})$ memory bounds, batched kernel enumeration, and directory-level early pruning.

**Complexity:** Time: $O(N)$ filesystem operations | Space: $O(D)$ memory where $D$ is maximum directory depth ($D \ll N$).

### 2. Parallel work-stealing walker

**Definition:** Multi-threaded directory hierarchy traversal leveraging per-worker lock-free Chase-Lev double-ended queues (deques), non-blocking work stealing for dynamic load balancing, and thread-affinity pinned I/O.

**Complexity:** Time: $O(N / P + T_{\text{steal}})$ where $P$ is worker thread count and $T_{\text{steal}}$ is contention overhead | Space: $O(P \times D)$ where $D$ is maximum tree depth.

### 3. .gitignore matching

**Definition:** Hierarchical ignore rule resolution evaluating layered, glob-based pattern sets across directory boundaries with negative re-inclusion override semantics and parent-level subtree short-circuiting.

**Complexity:** Time: $O(S \times K)$ where $S$ is path segments and $K$ is active rules per directory scope | Space: $O(R)$ where $R$ is total compiled rule nodes in the prefix trie.

### 4. Glob set

**Definition:** Multi-pattern glob matcher compiling heterogeneous wildcard expressions (`*`, `**`, `?`, `[...]`) into a single-pass hybrid engine combining exact hashsets, trie lookups, and deterministic finite automata (DFA).

**Complexity:** Time: $O(M)$ where $M$ is path string length (independent of number of glob patterns $P$) | Space: $O(\Sigma \times |\text{DFA states}|)$.

### 5. Binary file detection

**Definition:** Vectorized statistical content classification heuristic scanning initial byte blocks to distinguish plain UTF-8/ASCII source code from compiled binaries, packed assets, and compressed archives.

**Complexity:** Time: $O(B)$ where $B \le 8192\text{ bytes}$ (executed in $\sim 30\text{ nanoseconds}$ via SIMD) | Space: $O(1)$ memory.

### 6. Language detection

**Definition:** Multi-stage hierarchical classifier identifying programming language syntax and parser targets via exact filename matching, file extensions, interpreter shebangs, editor modelines, and statistical token frequencies.

**Complexity:** Time: $O(1)$ for extension/name lookup; $O(L)$ for shebang/modeline scan where $L \le 256\text{ bytes}$ | Space: $O(1)$.

### 7. git ls-files (index enumeration)

**Definition:** Direct binary parsing or CLI extraction of Git's index staging tree (`.git/index`), bypassing filesystem directory traversal to obtain cached, tracked, and modified file manifests in near-zero time.

**Complexity:** Time: $O(K)$ where $K$ is number of tracked files in the index ($< 5\text{ms}$ for $100{,}000$ files) | Space: $O(K)$ in-memory path index.

### 8. Generated and vendored file filtering

**Definition:** Multi-signal weighted classification pipeline identifying machine-generated code, vendored dependencies, minified bundles, and third-party artifacts to prevent erroneous manual edits to derived assets.

**Complexity:** Time: $O(1)$ for path rules; $O(C)$ for header scan where $C \le 4096\text{ bytes}$ | Space: $O(1)$.

---

## A2. Fast byte scanning

### 9. memchr (SIMD single-byte search)

**Definition:** Hardware-vectorized single-byte pattern search utilizing AVX-512, AVX2, or ARM NEON vector instructions to scan memory buffers at memory-bus saturating speeds ($> 30\text{ GB/s}$).

**Complexity:** Time: $O(N / W)$ where $W \in \{16, 32, 64\}$ is vector register byte width | Space: $O(1)$ register space.

### 10. SWAR (SIMD within a register)

**Definition:** Portable vectorization technique executing parallel multi-byte comparisons across 64-bit integer registers using bitwise arithmetic, without relying on hardware-specific SIMD instruction sets.

**Complexity:** Time: $O(N / 8)$ processing 8 bytes per 64-bit CPU cycle | Space: $O(1)$ scalar registers.

### 11. Rare-byte heuristic

**Definition:** Frequency-weighted search optimization that queries the rarest byte in a target pattern first, skipping high-density common characters and minimizing verification candidate false alarms.

**Complexity:** Time: Average $O(N / \text{skip\_distance})$ where $\text{skip\_distance} \gg 1$ | Space: $O(1)$ static frequency table.

### 12. Teddy (SIMD multi-literal search)

**Definition:** SIMD-accelerated multi-pattern prefilter algorithm (derived from Hyperscan/Vectorscan) that searches for up to 64 short literal patterns simultaneously in a single linear pass using vector shuffle lookup tables.

**Complexity:** Time: $O(N)$ single-pass vector throughput ($> 15\text{ GB/s}$) | Space: $O(B)$ where $B \le 64$ patterns.

### 13. Lazy line splitting

**Definition:** Memory-efficient scanning paradigm that processes entire files as monolithic byte buffers and resolves line boundaries and column coordinates lazily only around confirmed match offsets.

**Complexity:** Time: $O(N + M_{\text{hits}} \times L_{\text{avg}})$ where $L_{\text{avg}}$ is line length | Space: $O(1)$ auxiliary memory (zero per-line allocations).

### 14. Line counting with popcount

**Definition:** High-performance line number resolution algorithm utilizing SIMD vector comparisons and hardware population count (`_popcnt64`) to compute line coordinates incrementally between match anchors.

**Complexity:** Time: $O(\Delta / 32)$ where $\Delta$ is byte distance between successive matches | Space: $O(1)$ state.

### 15. Block buffer with overlap

**Definition:** Constant-memory streaming search pattern for massive files ($> 1\text{ GB}$) utilizing a circular sliding-window buffer with boundary overlap to guarantee zero missed matches across block boundaries.

**Complexity:** Time: $O(N)$ linear streaming scan | Space: $O(B)$ where $B$ is fixed buffer size ($B = 64\text{ KB}$ to $1\text{ MB}$, independent of file size $N$).

### 16. Smart case

**Definition:** Adaptive case-sensitivity resolution heuristic that dynamically switches between case-sensitive and case-insensitive matching based on the presence of uppercase literal characters in the pattern.

**Complexity:** Time: $O(M)$ pattern inspection; downstream search complexity identical to underlying search engine | Space: $O(1)$.

## A3. String matching algorithms

### 17. Naive (linear) substring search

**Definition:** Deterministic sliding-window string verification trying every offset in the text buffer, serving as the baseline verification kernel for small in-memory buffers.

**Complexity:** Time: Worst-case $O(N \times M)$, Best-case $O(N)$ | Space: $O(1)$ auxiliary space.

### 18. Knuth-Morris-Pratt (KMP)

**Definition:** Deterministic linear-time string searching algorithm using a precomputed prefix function ($\pi$ table) to eliminate text pointer backtracking, guaranteeing strict forward-only stream processing.

**Complexity:** Time: $O(N + M)$ guaranteed worst-case | Space: $O(M)$ for the prefix failure table $\pi$.

### 19. Boyer-Moore

**Definition:** Right-to-left pattern matching algorithm combining the Bad Character Rule ($\delta_1$) and the Strong Good Suffix Rule ($\delta_2$) to skip large blocks of text, achieving sub-linear average search speeds ($O(N / M)$).

**Complexity:** Time: Average $O(N / M)$, Worst-case $O(N + M)$ (with Galil rule) | Space: $O(M + \Sigma)$ where $\Sigma$ is alphabet size ($256$ bytes).

### 20. Boyer-Moore-Horspool

**Definition:** High-throughput simplification of Boyer-Moore retaining only the rightmost Bad Character Shift table, optimizing scalar CPU branch prediction and minimizing setup overhead.

**Complexity:** Time: Average $O(N / M)$, Worst-case $O(N \times M)$ | Space: $O(\Sigma)$ (256-byte lookup array).

### 21. Two-Way algorithm

**Definition:** Optimal substring search algorithm (Crochemore & Perrin) that factors patterns into two segments via critical factorizations, achieving strict $O(N + M)$ time and $O(1)$ auxiliary space without hash tables.

**Complexity:** Time: $O(N + M)$ worst-case, $O(N / M)$ average | Space: $O(1)$ auxiliary memory (zero heap allocation).

### 22. Rabin-Karp (rolling hash)

**Definition:** Multi-pattern and substring search algorithm utilizing a rolling polynomial hash function to compute $O(1)$ incremental window hash transitions across text streams.

**Complexity:** Time: Average $O(N + M)$, Worst-case $O(N \times M)$ (mitigated by prime selection) | Space: $O(K)$ where $K$ is number of simultaneous pattern hashes.

### 23. Shift-Or / Bitap

**Definition:** Bit-parallel pattern matching algorithm (Baeza-Yates–Gonnet) encoding NFA search states into machine word bitmasks, extending naturally to approximate $k$-mismatch / $k$-error Levenshtein search.

**Complexity:** Time: $O(N \lceil M / W \rceil)$ exact; $O(k \cdot N \lceil M / W \rceil)$ for $k$ errors where $W = 64\text{ bits}$ | Space: $O(\Sigma \lceil M / W \rceil)$ where $\Sigma = 256$.

### 24. Aho-Corasick

**Definition:** Deterministic multi-pattern dictionary matching automaton constructing a trie augmented with suffix failure transitions and dictionary output links, finding all occurrences of $K$ patterns in a single linear pass.

**Complexity:** Time: $O(N + \sum_{i=1}^K M_i + Z)$ where $Z$ is total match occurrences | Space: $O(\Sigma \times \sum M_i)$ states.

### 25. Wu-Manber

**Definition:** Sub-linear multi-pattern matching algorithm combining multi-byte block hashing ($B = 2$ or $3$ characters) with Boyer-Moore style skip tables to search for thousands of patterns simultaneously.

**Complexity:** Time: Average $O(N / M_{\min})$, Worst-case $O(N \times K)$ | Space: $O(\text{TableSize} + K)$ where $K$ is pattern count.

### 26. Z-algorithm

**Definition:** Linear-time string preprocessing algorithm computing an array $Z$ where $Z[i]$ represents the length of the longest substring starting at $\text{text}[i]$ that matches the prefix of $\text{text}$.

**Complexity:** Time: Strict $O(N)$ linear time | Space: $O(N)$ for the $Z$-array.

### 27. Levenshtein distance (dynamic programming)

**Definition:** The minimum number of single-character inserts, deletes and substitutions that turn string A into string B.

### 28. Myers bit-parallel edit distance

**Definition:** Computing a whole Levenshtein column with bit operations instead of cell by cell.

### 29. Levenshtein automaton

**Definition:** An automaton that accepts exactly the strings within distance k of a target string.

### 30. BK-tree

**Definition:** A tree that answers "which words are within distance k of this one?" quickly.

### 31. MinHash and Jaccard similarity

**Definition:** Estimating how similar two sets are, such as the token sets of two files.

### 32. fzf-style fuzzy subsequence scoring

**Definition:** Matching a query whose characters appear in order but not necessarily together, and ranking the matches.

## A4. Regex engines

### 33. Regex parsing

**Definition:** Converting regex text into a tree structure the engine can compile.

### 34. Thompson NFA construction

**Definition:** Building a nondeterministic automaton from a regex tree.

### 35. Pike VM

**Definition:** Running an NFA by tracking all active states in parallel, with capture groups.

### 36. Backtracking regex engine

**Definition:** A regex engine that tries alternatives recursively and backs up on failure (PCRE, Java, Python, JavaScript).

### 37. DFA (subset construction)

**Definition:** A deterministic automaton with exactly one current state, so each byte costs one table lookup.

### 38. Lazy (hybrid) DFA

**Definition:** A DFA built on the fly, only for the states the input actually reaches.

### 39. Literal extraction

**Definition:** Pulling out the plain strings every match of a regex must contain, to use as a fast prefilter.

### 40. Reverse suffix and reverse inner optimization

**Definition:** Finding a required literal first, then running the regex backward from it to find where the match starts.

### 41. Regex set (Hyperscan style)

**Definition:** Matching many regexes in one pass and reporting which ones matched.

### 42. ReDoS protection

**Definition:** Preventing a regex from hanging on certain inputs (regular-expression denial of service).

## A5. Index structures

### 43. Inverted index

**Definition:** A map from each term to the list of documents containing it.

### 44. Trigram index

**Definition:** An inverted index whose terms are every 3-character substring of each file.

### 45. Positional trigram index

**Definition:** A trigram index that also records where each trigram occurs.

### 46. Sparse n-grams

**Definition:** Variable-length n-grams chosen by a weight function, instead of all fixed-length trigrams.

### 47. Suffix array

**Definition:** A sorted array of the start positions of every suffix of a text.

### 48. LCP array

**Definition:** For each pair of neighboring suffixes in the suffix array, the length of their common prefix.

### 49. Suffix automaton

**Definition:** The smallest automaton that accepts every substring of a text.

### 50. Burrows-Wheeler Transform (BWT)

**Definition:** A reversible reordering of text that groups similar characters together.
