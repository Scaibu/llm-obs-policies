## A5. Index structures (continued)

### 51. FM-index

**Definition:** A compressed full-text index that answers substring queries directly on the BWT (#50), without decompressing the text.

### 52. Trie (prefix tree)

**Definition:** A tree where each edge is one character and each path from the root spells a key.

### 53. Radix (Patricia) tree

**Definition:** A compressed trie where chains of single-child nodes merge into one edge labeled with a string.

### 54. FST (finite state transducer)

**Definition:** A minimized automaton that maps keys to values, sharing both common prefixes and common suffixes.

### 55. B+ tree

**Definition:** A balanced search tree with many keys per node, where all data lives in leaves linked side by side.

### 56. LSM tree (log-structured merge tree)

**Definition:** A storage structure built for heavy writes: buffer in memory, flush sorted files, and merge them in the background.

### 57. Bloom filter

**Definition:** A compact bit array that answers "definitely not present" or "maybe present".

### 58. Xor and binary fuse filters

**Definition:** Static membership filters that are smaller and faster than Bloom filters.

## A6. Posting lists and set operations

### 59. Posting list

**Definition:** The sorted list of document IDs (optionally with positions) for one term in an inverted index.

### 60. Delta (gap) encoding

**Definition:** Storing the differences between consecutive sorted IDs instead of the IDs themselves.

### 61. Varint (variable-length integers, LEB128)

**Definition:** Encoding integers in a variable number of bytes, so small numbers use fewer bytes.

### 62. Bit-packing and PForDelta

**Definition:** Packing a block of numbers at the smallest bit width that fits them, with rare large values stored separately.

### 63. Elias-Fano encoding

**Definition:** A near-optimal compression for sorted integer lists that still supports direct access and fast skipping.

### 64. Roaring bitmap

**Definition:** A compressed bitmap that picks the best storage format for each chunk of 65,536 IDs.

### 65. Merge intersection

**Definition:** Intersecting two sorted lists by walking both with two pointers.

### 66. Galloping (exponential search) intersection

**Definition:** An intersection method that's fast when one list is much shorter than the other.

### 67. k-way merge with a min-heap (union)

**Definition:** Merging many sorted lists into one sorted list without duplicates.

### 68. WAND and Block-Max WAND

**Definition:** Top-k ranked retrieval that skips documents which can't score high enough to enter the top k.

## A7. Query planning and execution

### 69. Regex → trigram query

**Definition:** Converting a regex into a boolean query over trigrams, so an index can find candidate files.

### 70. Boolean query simplification

**Definition:** Rewriting a query tree into a smaller, equivalent, cheaper form.

### 71. Rarest-first ordering

**Definition:** Evaluating the most selective query term first, so the candidate set shrinks fastest.

### 72. Candidate verification

**Definition:** Confirming every index candidate against the actual file content.

### 73. Early termination (top-k and caps)

**Definition:** Stopping a search once enough results are found.

### 74. Scatter-gather

**Definition:** Sending one query to many shards in parallel and merging their answers.

### 75. Hedged requests

**Definition:** Sending a backup copy of a slow request to another replica and taking whichever answer comes first.

### 76. Result cache keyed on index version

**Definition:** Caching query results with a key that changes automatically whenever the index changes.

## A8. Structural (syntax-aware) search

### 77. Tokenizer-based search

**Definition:** Searching over a language's tokens instead of raw characters.

### 78. Concrete syntax tree (CST)

**Definition:** A parse tree that keeps every token, including whitespace and comments, so the original source can be reproduced exactly.

### 79. Abstract syntax tree (AST)

**Definition:** A tree of the program's meaning, without formatting, parentheses or comments.

### 80. Tree-sitter incremental parsing

**Definition:** A fast, error-tolerant parser generator that re-parses only what changed after an edit.

### 81. Tree-sitter queries

**Definition:** S-expression patterns that match tree shapes and capture named nodes.

### 82. Pattern matching with metavariables (ast-grep style)

**Definition:** Writing a search pattern as ordinary code with placeholders, then matching it structurally.

### 83. Semgrep-style matching with equivalences

**Definition:** Pattern matching that also matches code which is semantically equivalent to the pattern.

### 84. Comby (balanced-delimiter matching)

**Definition:** Language-light structural search and replace that understands balanced brackets, strings and comments.

### 85. Subtree hashing (clone detection)

**Definition:** Hashing each syntax subtree so that structurally identical code gets the same hash.

### 86. Tree diff (GumTree)

**Definition:** Computing an edit script between two syntax trees: inserted, deleted, updated and moved nodes.

## A9. Symbol, semantic and program-analysis search

### 87. Symbol table

**Definition:** A map from names to what they mean in a given scope: kind, type, definition location.

### 88. Scope graphs and name resolution

**Definition:** A graph model of which names are visible where, used to resolve every reference to its declaration.

### 89. Stack graphs

**Definition:** Incremental, per-file name-resolution graphs that can be combined across files without a full build.

### 90. Language Server Protocol (LSP)

**Definition:** A standard JSON-RPC protocol through which editors and tools ask a language server for code intelligence.

### 91. SCIP and LSIF (precomputed code-intelligence indexes)

**Definition:** File formats that store precomputed definitions, references and hover data for an entire repo, so lookups don't need a running language server.

### 92. Call graph

**Definition:** A graph of which functions call which functions.

### 93. Import (dependency) graph

**Definition:** A graph of which modules or files import which others.

### 94. Control flow graph (CFG)

**Definition:** A graph of the possible execution paths inside a function.

### 95. SSA form (static single assignment)

**Definition:** An intermediate code form where every variable is assigned exactly once.

### 96. Dataflow analysis (worklist algorithm)

**Definition:** Computing facts about values at every program point, such as which definitions reach here or which variables are live.

### 97. Taint analysis

**Definition:** Tracking whether untrusted data (sources) can reach dangerous operations (sinks) without passing through a sanitizer.

### 98. Datalog program analysis (CodeQL style)

**Definition:** Turning code into a relational database and asking questions about it with a logic query language.

## A10. Vector and hybrid retrieval

### 99. AST-based chunking

**Definition:** Splitting code into retrieval units along syntax boundaries (functions, classes, methods), instead of fixed-size windows.

### 100. Embeddings for code

**Definition:** Dense vectors produced by a neural model, such that semantically similar code or text lands close together.
