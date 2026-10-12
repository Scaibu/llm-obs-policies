# Part 3: Vector update (#111–155)

Same format and the same contract (roles; rules V1–V8; guardrails VG1–VG6).

## C1. Write path and index maintenance

### 111. Upsert by stable ID

**Definition:** Insert-or-replace keyed by a deterministic ID, so writing the same item twice updates it instead of duplicating it.

### 112. Write-ahead log (WAL)

**Definition:** Recording every write in an append-only durable log before applying it to the index.

### 113. Fresh buffer (in-memory write segment)

**Definition:** A small, searchable in-memory area holding the newest vectors until they're merged into the main index.

### 114. Segment-based (LSM-style) vector storage

**Definition:** Storing vectors in many immutable segments, each with its own small index, merged over time.

### 115. Segment merge and compaction

**Definition:** Combining segments into larger ones and dropping deleted vectors for good.

### 116. Tombstone deletion (deletion bitmap)

**Definition:** Marking vectors as deleted with a bit, instead of removing them from the index immediately.

### 117. Deleting from HNSW (mark plus repair)

**Definition:** Handling deletions in a graph index without breaking navigation.

### 118. In-place updates for disk graphs (FreshDiskANN style)

**Definition:** Supporting continuous inserts and deletes on a large disk-based graph through a small in-memory graph plus periodic batch merges.

### 119. Incremental IVF assignment

**Definition:** Adding new vectors to an existing IVF index by assigning them to the nearest existing centroid.

### 120. Centroid drift detection and retraining

**Definition:** Detecting when IVF centroids or PQ codebooks no longer fit the data, then retraining them.

### 121. Re-embedding pipeline (model migration)

**Definition:** Re-computing every vector with a new embedding model and moving traffic to the new vectors.

### 122. Dual-write (shadow index)

**Definition:** Writing every change to both the current and the new index during a migration.

### 123. Blue-green index swap (alias cutover)

**Definition:** Serving queries through an alias that can be switched atomically between two complete indexes.

### 124. Idempotent ingestion with content-hash dedupe

**Definition:** Skipping the work of re-embedding and re-writing when the content hasn't changed.

## C2. Change capture and ingestion

### 125. Change data capture (CDC)

**Definition:** Streaming every insert, update and delete from a source database into the vector pipeline.

### 126. Transactional outbox

**Definition:** Writing a change event in the same database transaction as the business change, then publishing it reliably.

### 127. Merkle-tree sync (anti-entropy)

**Definition:** Comparing hash trees of the source and the index to find exactly what's out of sync.

### 128. Watermarks and freshness tracking

**Definition:** Tracking how far the pipeline has processed, in event time, so the delay from source change to searchability is known.

### 129. Exactly-once effects via idempotency keys

**Definition:** Making sure each change affects the index exactly once, even though messages may be delivered more than once.

### 130. Backfill with checkpoints

**Definition:** Processing an entire historical corpus in resumable chunks.

### 131. Batch versus streaming embedding (micro-batching)

**Definition:** Choosing between embedding changes immediately one by one, in small groups, or in large periodic batches.

### 132. Backpressure and prioritized ingestion

**Definition:** Controlling ingestion speed and order so that important changes go first and the system isn't overloaded.

## C3. Consistency, replication and recovery

### 133. MVCC snapshots

**Definition:** Each query reads a consistent snapshot of the index while writes continue.

### 134. Consistency levels (read-your-writes)

**Definition:** Choosing how up to date a read must be relative to recent writes.

### 135. Leader-follower replication

**Definition:** One node accepts writes and copies them to follower nodes, which serve reads.

### 136. Raft consensus

**Definition:** An algorithm that keeps a replicated log consistent across nodes, tolerating failures, with a single elected leader.

### 137. Quorum reads and writes

**Definition:** Requiring a minimum number of replicas to acknowledge a write (W) and to answer a read (R).

### 138. Snapshot plus log replay recovery

**Definition:** Restoring an index from a periodic full snapshot plus the log of changes since.

### 139. Consistent-hashing rebalancing

**Definition:** Redistributing vectors when shards are added or removed, moving as little data as possible.

### 140. Version vectors and conflict detection

**Definition:** Per-replica counters attached to each item, which reveal whether two versions are ordered or truly concurrent.

### 141. Schema and metadata versioning

**Definition:** Versioning the metadata fields stored with vectors (filters, lineage), so changes don't break queries or writers.

### 142. Multi-tenant isolation

**Definition:** Ensuring each tenant's vectors are only searchable and modifiable by that tenant.

## C4. Lifecycle management

### 143. TTL (time-to-live) expiry

**Definition:** Automatically removing vectors after a set time.

### 144. Orphan garbage collection

**Definition:** Finding and removing vectors whose source no longer exists.

### 145. Near-duplicate deduplication

**Definition:** Detecting and merging vectors whose content is nearly identical.

### 146. Rebuild scheduling

**Definition:** Deciding when to rebuild an index fully, instead of continuing incremental updates.

### 147. Online index build

**Definition:** Building a new index while the old one keeps serving, then catching up on changes made during the build.

### 148. Bulk loading

**Definition:** Building an index from a large dataset in one efficient operation, instead of inserting vectors one by one.

### 149. Requantization migration

**Definition:** Changing an index's compression (for example float32 → int8 → binary with re-scoring) as a controlled migration.

### 150. Deletion verification ("right to be forgotten")

**Definition:** Proving that deleted content no longer appears anywhere in retrieval, and is removed from storage within the promised time.

## C5. Transformation during updates

### 151. Backward-compatible embeddings (BCT)

**Definition:** Training a new embedding model so its vectors remain comparable to the old model's vectors.

### 152. Lazy (on-read) re-embedding

**Definition:** Re-embedding items gradually, prioritizing items as they're read or updated, instead of all at once.

### 153. Codebook retraining

**Definition:** Re-learning PQ or IVF quantization parameters when the data has shifted, then re-encoding vectors.

### 154. Metadata index maintenance

**Definition:** Keeping the indexes on filterable metadata fields (B-trees, bitmaps, inverted lists) in sync with the vectors.

### 155. Atomic vector and metadata commit

**Definition:** Making a vector and its metadata (including access fields) visible at the same moment.
