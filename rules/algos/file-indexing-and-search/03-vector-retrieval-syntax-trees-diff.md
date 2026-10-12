# Part 3: entries 101–150

Same format and the same contract (roles, R1–R8, G1–G5).

## A10. Vector and hybrid retrieval (continued)

### 101. Cosine similarity and dot product

**Definition:** Measures of how close two vectors are in direction, used to score how relevant a chunk is to a query.

### 102. Exact (flat) k-nearest-neighbor search

**Definition:** Finding the k closest vectors by comparing the query against every stored vector.

### 103. HNSW (Hierarchical Navigable Small World graph)

**Definition:** A graph-based approximate nearest-neighbor index with layers, like a skip list for vectors.

### 104. IVF (inverted file index for vectors)

**Definition:** An approximate index that clusters vectors and searches only the clusters nearest to the query.

### 105. Product quantization (PQ) and vector compression

**Definition:** Compressing vectors into short codes so that huge collections fit in memory and distances are computed quickly.

### 106. BM25 (keyword relevance scoring)

**Definition:** A classic ranking formula that scores documents by term frequency, term rarity and document length.

### 107. Identifier-aware tokenization

**Definition:** Splitting code identifiers into their word parts so keyword search works on code.

### 108. Hybrid retrieval with Reciprocal Rank Fusion (RRF)

**Definition:** Combining keyword search and vector search results into one ranking.

### 109. Cross-encoder reranking

**Definition:** Re-scoring a short candidate list with a model that reads the query and each candidate together.

### 110. Repo map (graph centrality ranking)

**Definition:** A compact summary of a repository's most important symbols, ranked by how central they are in the reference graph.

## A11. Index freshness and distribution

### 111. Content-addressed storage

**Definition:** Identifying data by a hash of its content instead of by its name or location.

### 112. Merkle tree change detection

**Definition:** A tree of hashes where each folder's hash covers everything below it, so changed parts are found quickly.

### 113. File watchers with debouncing

**Definition:** Getting OS notifications when files change, and grouping rapid bursts into one update.

### 114. Segment-based indexing with merge policy

**Definition:** Building an index as many small immutable segments that are merged in the background.

### 115. Sharding and consistent hashing

**Definition:** Splitting an index across machines, and assigning data to machines so that adding or removing one moves little data.

### 116. MVCC snapshots (multi-version index)

**Definition:** Keeping several versions of an index so each query sees one consistent snapshot while updates happen.

---

### 117. Text edit (range + replacement)

**Definition:** The basic unit of a code change: replace the text in one range with new text.

### 118. WorkspaceEdit (multi-file changeset)

**Definition:** The LSP structure that groups text edits for many files, plus file operations, into one change.

### 119. Position encoding (UTF-8, UTF-16, columns)

**Definition:** The rules for what a "column" or "offset" counts: bytes, UTF-16 code units, or code points.

### 120. Reverse-order application

**Definition:** Applying a file's edits from the last position to the first, so earlier offsets stay valid.

### 121. Overlap detection (sorted sweep)

**Definition:** Detecting edits whose ranges overlap, before applying any of them.

### 122. Interval tree

**Definition:** A tree that stores ranges and quickly answers "which stored ranges overlap this one?"

### 123. Edit rebasing (operational transformation)

**Definition:** Adjusting an edit's ranges so it still applies correctly after other edits changed the text.

### 124. Unified diff format

**Definition:** The standard text format for describing changes between two versions of files.

### 125. Search/replace block format

**Definition:** An edit format that gives the exact old text and the new text, without line numbers.

### 126. Idempotent edits (fixpoint check)

**Definition:** Designing edits so that applying them a second time changes nothing.

## B2. Syntax trees and rewrite engines

### 127. Lossless syntax tree

**Definition:** A syntax tree that reproduces the exact original file, including formatting and comments, and also carries semantic information.

### 128. Red-green trees

**Definition:** A two-layer tree design that makes syntax trees immutable, shareable and cheap to update.

### 129. Trivia attachment (comments and whitespace)

**Definition:** The rules that decide which syntax node "owns" each comment and whitespace run.

### 130. Visitor pattern

**Definition:** A way to walk a syntax tree where you supply a callback for each node type you care about.

### 131. Tree transformer (rewriter)

**Definition:** A walk over a syntax tree that returns a modified tree, replacing nodes as it goes.

### 132. Pattern → template rewriting

**Definition:** Rewriting code by matching a code-shaped pattern with placeholders and filling a code-shaped template with the captured parts.

### 133. Semantic patches (Coccinelle style)

**Definition:** Patches written like diffs, but over code patterns with metavariables and "any code in between", applied across a codebase.

### 134. OpenRewrite recipes

**Definition:** Composable, type-aware refactoring programs that run over lossless semantic trees, for Java and other JVM and config formats.

### 135. LibCST (Python concrete syntax tree)

**Definition:** A Python library that parses code into a concrete tree preserving all formatting, designed for codemods.

### 136. jscodeshift / recast (JavaScript and TypeScript)

**Definition:** A codemod runner for JavaScript and TypeScript built on a printer that preserves the original formatting of untouched code.

### 137. Import management

**Definition:** Adding, removing and reorganizing import statements automatically as part of a code change.

### 138. Rename refactoring

**Definition:** Changing a symbol's name everywhere it's defined and used, without changing behavior.

## B3. Text buffers

### 139. Gap buffer

**Definition:** A text buffer that keeps an empty gap at the cursor, so typing there is cheap.

### 140. Rope

**Definition:** A balanced tree of text chunks that makes inserts and deletes anywhere in large text fast.

### 141. Piece table

**Definition:** A buffer that never changes the original text; it records edits as a list of pieces pointing into the original and an append-only "added" buffer.

### 142. Line index (line start offsets)

**Definition:** An array of the byte offset where each line starts, for fast conversion between offsets and line/column.

### 143. Persistent (immutable) data structures

**Definition:** Data structures that keep every old version intact when updated, sharing unchanged parts between versions.

### 144. Undo/redo stack (command pattern)

**Definition:** Recording each edit along with how to reverse it, so changes can be undone and redone.

## B4. Diff and merge

### 145. LCS (longest common subsequence) dynamic programming

**Definition:** Finding the longest sequence of lines common to both versions, in order. Everything else is an insert or a delete.

### 146. Myers O(ND) diff

**Definition:** The standard fast diff algorithm, which finds a shortest edit script in time proportional to the size times the number of differences.

### 147. Linear-space Myers (divide and conquer)

**Definition:** The Myers diff refined to use memory proportional to the input size instead of N × D.

### 148. Patience diff

**Definition:** A diff that first matches lines that are unique in both files, producing more readable diffs for code.

### 149. Histogram diff

**Definition:** An extension of patience diff that uses low-occurrence lines (not only unique ones) as anchors, which is also faster.

### 150. Line hashing and interning

**Definition:** Replacing each line with a small integer ID before diffing, so lines are compared as numbers instead of strings.
