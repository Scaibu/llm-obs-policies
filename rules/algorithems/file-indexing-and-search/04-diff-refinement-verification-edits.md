### 151. Word- and character-level diff refinement

**Definition:** After a line diff, a second diff inside each changed line pair shows exactly which words or characters changed.

### 152. Semantic (syntax-aware) diff

**Definition:** A diff computed over syntax trees, so it ignores formatting and shows structural changes.

### 153. Three-way merge (diff3)

**Definition:** Combining two independent changes to the same original file, using the original (the "base") as the reference.

### 154. Merge base (lowest common ancestor in the commit graph)

**Definition:** The most recent commit that two branches both descend from.

### 155. Fuzzy patch application

**Definition:** Applying a diff hunk even when line numbers or nearby context have shifted slightly.

### 156. diff-match-patch (fuzzy matching and patching)

**Definition:** A library combining character-level diff, fuzzy matching and patch application with configurable tolerance.

## B5. Safe application

### 157. Dry run (plan/apply separation)

**Definition:** Computing and showing every change without writing anything, then applying exactly that computed change.

### 158. Atomic file write (temp file + fsync + rename)

**Definition:** Writing a file so that readers only ever see the complete old version or the complete new version, never a half-written one.

### 159. Compare-and-swap by content hash (optimistic concurrency)

**Definition:** Writing a file only if it still matches the version you read.

### 160. Advisory file locks

**Definition:** Cooperative locks that processes agree to respect, to keep two writers from working on the same file or repo at once.

### 161. Write-ahead journal (rollback log)

**Definition:** Recording what you're about to change, before changing it, so the change can be undone or completed after a crash.

### 162. Git worktree or branch staging

**Definition:** Doing all the edits in a separate working copy or branch, so the main checkout is never touched until the change is approved.

### 163. Saga with compensating actions

**Definition:** Managing a multi-step change across systems that can't share one transaction, by giving each step an undo step.

### 164. Checkpointing and resumable jobs

**Definition:** Saving progress during a long job so it can continue after an interruption without redoing or double-applying work.

### 165. Preserving file identity (encoding, line endings, BOM, mode)

**Definition:** Keeping everything about a file except the intended change exactly as it was.

### 166. Expand-and-contract (parallel change)

**Definition:** Changing an interface used by others in three safe phases: add the new form, migrate the users, then remove the old form.

## B6. Concurrency and scheduling

### 167. Worker pool

**Definition:** A fixed set of workers that take tasks from a shared queue and process them in parallel.

### 168. Bounded queues and backpressure

**Definition:** Limiting how much work waits between pipeline stages, so a fast stage slows down instead of flooding a slow stage.

### 169. Fork-join and map-reduce

**Definition:** Splitting a job into independent parts, processing them in parallel (map), then combining the results (reduce).

### 170. Topological sort (Kahn's algorithm)

**Definition:** Ordering tasks so that each one comes after everything it depends on.

### 171. Strongly connected components (Tarjan)

**Definition:** Finding groups of nodes in a directed graph where every node can reach every other, which means finding cycles.

### 172. Batching and chunking

**Definition:** Grouping many small units into batches of a sensible size for processing, review and merging.

### 173. Priority queue scheduling

**Definition:** Processing the most important tasks first, using a heap ordered by priority.

### 174. Retry with exponential backoff and jitter

**Definition:** Retrying failed operations with growing, randomized delays, so you don't hammer a struggling service.

### 175. Circuit breaker

**Definition:** Automatically stopping calls to a failing dependency for a while, instead of piling up failures.

### 176. Lease-based task queue (with idempotency keys)

**Definition:** A shared queue where workers claim tasks for a limited time, and tasks reappear if a worker dies.

## B7. Validation and verification

### 177. Parse check

**Definition:** Confirming that every edited file still parses without errors.

### 178. Formatter check

**Definition:** Running the project's own formatter so edited code matches the project's style.

### 179. Incremental type check and compile

**Definition:** Re-checking types and compiling only what's affected by the edits.

### 180. Test impact analysis

**Definition:** Selecting only the tests that could be affected by the changed files.

### 181. Build graph and affected targets

**Definition:** Using the build system's dependency graph to find exactly which build targets a change affects.

### 182. Golden (snapshot) tests for transformations

**Definition:** Testing a transformation on fixed input files and comparing the output against saved expected output.

### 183. Differential testing

**Definition:** Running the old and new versions on the same inputs and comparing their behavior.

### 184. Post-condition search (zero remaining)

**Definition:** Re-running the original search after the change, to prove the old pattern is gone and nothing unplanned changed.

## B8. Large-scale rollout

### 185. Large-scale change (LSC) sharding and canary waves

**Definition:** Splitting a huge change into independent pieces, rolled out gradually with early checks.

### 186. Ownership resolution (CODEOWNERS)

**Definition:** Determining which team or person owns each changed file, so the right reviewers approve it.

### 187. Campaign (batch change) orchestration

**Definition:** Managing one change across many repositories as a tracked campaign: generate, open, track, merge.

### 188. Automatic rebase and regeneration

**Definition:** Keeping open bulk-change pull requests current by regenerating them on the latest base, instead of hand-resolving conflicts.

### 189. Merge queue

**Definition:** A queue that tests each pull request together with everything ahead of it before merging, so the main branch never breaks.

### 190. Ratchets and baseline files

**Definition:** Allowing existing violations but blocking new ones, so a migration can only move forward.

### 191. Progress tracking (burndown)

**Definition:** Measuring the remaining work over time and reporting it.

### 192. Revert strategy

**Definition:** A pre-planned, fast way to undo a change that turns out to be harmful.

## B9. LLM agent editing patterns

### 193. Agentic search loop

**Definition:** The agent's repeated cycle of searching, reading, refining its understanding and searching again until it has what it needs.

### 194. Context window budgeting

**Definition:** Choosing what goes into the model's limited context to maximize usefulness for the current step.

### 195. Exact string replace with uniqueness check

**Definition:** The safest LLM edit primitive: replace one exact, unique text span with new text.

### 196. Diff-based edit format

**Definition:** The agent outputs its changes as a unified diff (#124), which a tool applies.

### 197. Whole-file rewrite

**Definition:** The agent outputs the complete new content of a file instead of targeted edits.

### 198. Plan-and-execute

**Definition:** Separating thinking about what to do from doing it: first produce an explicit plan, then execute it step by step.

### 199. Map-reduce sub-agents

**Definition:** A lead agent splitting a large task across sub-agents, each with its own fresh context, then combining their results.

### 200. Self-verification loop

**Definition:** After editing, the agent runs checks itself, reads the results and fixes problems before declaring success.

### 201. Error-feedback retry

**Definition:** Feeding concrete error output (compiler, test, linter) back into the agent's next attempt.

### 202. LLM-synthesized codemods

**Definition:** The agent writes a deterministic transformation program (codemod) instead of editing each site itself.

### 203. Speculative edits

**Definition:** Trying edits in an isolated copy and keeping them only if they pass checks.

### 204. Scratchpad and progress file

**Definition:** A working file where the agent records its plan, findings, decisions and progress outside its context window.

### 205. Human-in-the-loop checkpoints

**Definition:** Defined points where a human must review or approve before the agent continues.

### 206. Sandboxing and permission boundaries

**Definition:** Restricting what the agent's tools can access and do, so mistakes or malicious inputs can't cause damage beyond the task.

---
