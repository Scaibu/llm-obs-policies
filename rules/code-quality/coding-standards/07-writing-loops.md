# Writing Loops and Complex Logic That Don't Break: First-Principles Rules (Language-Agnostic)

Confidence tags: **** hard evidence, **** strong inference, **[Guessing]** filling gaps.
Companion documents: *Key Normalization*, *Writing Conditions*, *Data Models and Types*.

**The uncomfortable truth:**  A loop that "works on my test data" has proven almost nothing. Loops fail on the inputs you did not run: empty, one element, the maximum size, a duplicate, a concurrent writer, a crash halfway through, a million rows instead of a hundred. If you cannot state what is true at the top of every iteration, you do not understand the loop, you are observing it.

---

# Part 1: First principles

## 1.1 What a loop is, formally

 A loop is a repeated state transition. Its correctness rests on three things you can write down:

| Concept | Meaning | What breaks without it |
|---|---|---|
| **Postcondition** | What must be true when the loop finishes | You cannot tell whether the result is right |
| **Invariant** | A statement true before the loop, at the top of every iteration, and after the loop | Wrong initial values, wrong updates, wrong exit result |
| **Variant (progress measure)** | A quantity that strictly moves toward the exit condition each iteration and is bounded | Infinite or unbounded loops |

The proof pattern (Floyd/Hoare style) has three obligations:
1. **Initialization:** the invariant holds before the first iteration.
2. **Maintenance:** if the invariant holds at the top of an iteration, it holds at the top of the next.
3. **Termination:** the variant decreases and is bounded, and at exit, `invariant AND exit-condition` implies the postcondition.

You do not need formal proofs, but you must be able to state the invariant in one sentence. If you cannot, the loop is a candidate for a rewrite into something whose correctness is obvious.

## 1.2 What "complex logic" is

 Complex logic is a state space that is too large to hold in your head. Its difficulty grows with:
- the number of **states** the data can be in,
- the number of **paths** through the code (cyclomatic complexity),
- the number of **interactions** between pieces of mutable state,
- the number of **actors** (threads, requests, retries) that can run it concurrently,
- the number of **failure points** (any I/O call can fail halfway).

Managing complexity means shrinking the state space (fewer representable states), shrinking the paths (smaller units, tables), isolating mutation, and making failure and retry safe.

## 1.3 The sixteen root causes of loop and logic bugs

1. **Off-by-one and bound errors:** inclusive vs exclusive, `<` vs `<=`, fencepost errors.
2. **Non-termination:** no progress, wrong exit condition, float counters, a condition never becoming false.
3. **Wrong initialization or accumulator:** starting value is not the identity of the operation (e.g., min starting at 0, product starting at 0).
4. **Empty and single-element input:** loop body assumes at least one or two elements.
5. **Mutating a collection while iterating it:** skipped elements, duplicates, exceptions, undefined behavior.
6. **Aliasing and shared state:** two names for one mutable object, reused buffers, closures capturing a loop variable by reference.
7. **Early exit and skipped cleanup:** `break`/`return`/exception bypasses resource release or a required update.
8. **Scale blow-up:** quadratic nested search, N+1 queries, unbounded memory, loading everything at once.
9. **Numeric issues:** floating-point accumulation error, integer overflow, float counters, precision loss.
10. **Ordering assumptions:** hash/map iteration order, unstable sorts, "the first one" of an unordered set.
11. **Concurrency in loops:** parallel iterations sharing state, non-associative reduce, check-then-act inside iterations.
12. **Partial failure:** a crash or error at iteration k leaves k-1 effects applied and the rest not, with no way to resume or retry safely.
13. **Retry and polling hazards:** unbounded retries, no backoff, retrying non-idempotent actions, retry amplification across layers.
14. **Pagination and traversal errors:** unstable ordering, skipped or duplicated items under concurrent writes, cycles in graphs.
15. **Recursion hazards:** missing base case, no progress, stack overflow, exponential blow-up without memoization.
16. **Tangled logic:** many flags and nested branches, decision and action interleaved, illegal states representable.

---

# Part 2: Before you write the loop

**L1. State the postcondition in one sentence.**  "Returns the total of valid line items, or zero if none." "Processes every pending job exactly once." If the sentence is vague, the loop will be too.

**L2. State the invariant.**  "At the top of each iteration, `total` equals the sum of the items before position `i`." Write it as a comment on the loop. For accumulation loops it is almost always "accumulator equals the result for the portion processed so far".

**L3. State the progress measure and its bound.**  "`remaining` decreases by at least one each iteration and starts at `n`." For loops over external input (queues, pages, retries), the bound is explicit: a maximum count, a maximum duration, or both.

**L4. Define behavior for the shape of input.**  Write expected results for: empty, one element, two elements, many, maximum size, duplicates, already-sorted, reverse-sorted, and containing invalid elements. This is your test list.

**L5. Choose the iteration abstraction deliberately.**  From most to least preferred for clarity:
1. **Declarative bulk operations** (map, filter, reduce, group, join, set operations) when they state the intent directly.
2. **For-each over a collection** when you need each element and no index.
3. **Indexed loop** when position matters or you must skip/step.
4. **While loop** when the iteration count is not known in advance (must have an explicit progress and bound).
5. **Recursion** when the structure is recursive (trees, nested data), with an explicit depth limit.

**L6. Decide who owns the data being iterated and whether it can change.**  Is it a snapshot, a live collection other code mutates, a stream, a database cursor, a paginated remote API? The rules differ.

**L7. Decide the failure policy up front.**  For each element that can fail: fail the whole loop (fail-fast), skip and record (continue), or retry. And decide whether earlier effects are rolled back, kept, or resumable.

**L8. Define scale.**  Expected and maximum element counts, time budget, memory budget. A loop that is fine at 1,000 may be fatal at 10 million.

---

# Part 3: Writing the loop

## 3.1 Structure

**L9. Prefer for-each over index arithmetic.**  Fewer places for off-by-one errors. Use an index only when you need it (pairs, windows, parallel arrays, in-place algorithms).

**L10. When using indexes, use half-open ranges `[start, end)`.**  Length is `end - start`, adjacent ranges compose without overlap or gap, and "empty" is `start == end`. Do not modify the loop variable inside the body.

**L11. Never use floating-point counters or termination tests.**  `for x = 0.0; x != 1.0; x += 0.1` may never terminate. Use an integer count and compute the float from it.

**L12. One loop, one responsibility.**  If the body does validation, transformation, aggregation, and I/O, split it into stages (filter, then map, then reduce, then write). Separate loops cost little and each is verifiable alone. Merge only when profiling proves you must.

**L13. Keep nesting at two levels or fewer.**  Extract the inner loop into a named function whose contract you can state. Deeper nesting is where the invariant is lost and cost multiplies.

**L14. Keep the body short and flat.**  Use guard clauses with `continue` for skip cases at the top of the body, so the main path is unindented. Limit `break` and `continue` to clear, commented purposes. Be careful that `continue` does not skip an update that must always happen (a counter, a cleanup).

**L15. Initialize accumulators with the identity element of the operation.**  Sum: `0`. Product: `1`. Min: positive infinity or the first element. Max: negative infinity or the first element. String join: empty. List build: empty list. For min/max over possibly empty input, decide what the empty result is (error or "none") and handle it, rather than returning the sentinel by accident.

**L16. Avoid sentinel values.**  `-1`, `0`, `""`, `9999`, `null` meaning "not found" collide with real values. Return an explicit optional, a result type, or raise.

**L17. Declare variables in the narrowest scope.**  A variable declared outside the loop and written inside carries hidden state across iterations. Reset per-iteration state at the top of each iteration, or declare it inside.

**L18. Beware closures capturing the loop variable.**  In several languages, a function created in a loop captures the *variable*, not its value at that iteration, so all closures see the final value. Bind the value per iteration (a parameter, a fresh scope, or the language's per-iteration binding).

## 3.2 Mutation and iteration

**L19. Never mutate a collection while iterating over it.**  Adding or removing elements during iteration causes skipped elements, repeated elements, or exceptions, depending on the language and container. Instead: build a new collection, collect changes then apply them after, or iterate over a snapshot/copy.

**L20. Understand aliasing before mutating.**  If two variables refer to the same mutable object, a change through one appears in the other. Copy when you need independence, and know whether your copy is shallow or deep. Reusing one mutable buffer or object across iterations and storing it is a classic bug (every stored entry is the same object).

**L21. Prefer immutable data and pure transformations inside loops.**  Mutation is the main source of loop-carried bugs. Keep mutation to a single clearly named accumulator.

## 3.3 Ordering and determinism

**L22. Do not depend on unspecified iteration order.**  Hash maps, sets, and some database result sets have no guaranteed order, or an order that changes between runs and versions. If order matters, sort explicitly by a total ordering.

**L23. Sorts need a total, deterministic order.**  Add a unique tiebreaker (such as an id) so equal keys have a defined order. Know whether your sort is stable, and do not depend on stability unless it is guaranteed. Compare using explicit, locale-independent rules.

**L24. "Pick the first" of an unordered set is a bug.**  State the rule (earliest by timestamp, lowest id) and implement it.

## 3.4 Scale and efficiency

**L25. Eliminate accidental quadratic behavior.**  A search (`contains`, `find`, `indexOf`, a nested loop) inside a loop is O(n·m). Build a set or map index once, then do constant-time lookups; or sort and use two pointers/merge. This is the most common cause of "fast in dev, dead in prod".

**L26. Eliminate N+1 I/O.**  A query, network call, or file read per iteration multiplies latency by n. Fetch in bulk (a single query with a set of ids, batch endpoints, a join), then iterate over the result in memory.

**L27. Hoist loop-invariant work.**  Compute anything that does not change across iterations (parsed config, compiled patterns, constants, lookups) once, outside the loop.

**L28. Bound memory.**  Do not load an unbounded input into memory. Stream, page, or chunk. Know the maximum size of anything you accumulate, and cap it. Watch string concatenation in a loop (quadratic in some languages; use a builder/join).

**L29. Process large work in chunks.**  Batch size is a tunable constant with a reason (transaction size, memory, rate limits). Each chunk is independently committed and recorded, so a failure costs one chunk, not everything.

**L30. Respect rate limits and apply backpressure.**  A loop that calls a limited resource must throttle itself. A producer loop feeding a slower consumer needs a bounded queue so memory does not grow without limit.

## 3.5 Numbers in loops

**L31. Floating-point accumulation is order-dependent and lossy.**  Summing many floats loses precision, and `(a+b)+c != a+(b+c)`. For money and exact totals use integers (minor units) or decimals. For scientific sums, use compensated summation or pairwise summation, and do not assert exact equality on results.

**L32. Guard against integer overflow.**  Sums, products, counters, and index arithmetic can wrap or throw. Use a wide enough type, checked arithmetic, or restructure (e.g., running average formulations). Check `mid = lo + (hi - lo) / 2` style overflow-safe forms.

**L33. Do not use the loop counter as a data identity.**  Positions change when data is inserted, removed, or re-sorted. Use stable ids.

## 3.6 Termination

**L34. Every `while` loop has a stated progress measure and a hard bound.**  Add a maximum iteration count or a deadline, and on exceeding it, fail loudly with state in the log. "It will always eventually finish" is the sentence before every production hang.

**L35. Loops over external systems always have timeouts.**  Each call inside the loop and the loop as a whole get timeouts. A loop waiting on something that never responds never ends.

**L36. Fixed-point and convergence loops need a monotonic measure and an iteration cap.**  Compare with a tolerance appropriate to the scale, cap iterations, and decide what to do when the cap is hit (error, best-effort with a flag).

## 3.7 Errors, cleanup, partial failure

**L37. Choose fail-fast, collect-errors, or continue, deliberately.** 
- *Fail-fast:* stop at the first error; right when later work depends on earlier work or partial results are harmful.
- *Collect:* process everything, return all errors; right for validation and batch reports.
- *Continue with a dead-letter record:* right for independent items where one bad item should not block the rest.
Never swallow errors silently inside a loop.

**L38. Make cleanup unconditional.**  Use `finally`/`defer`/`using`/context managers for anything that must be released (files, locks, connections, transactions) so `break`, `return`, and exceptions cannot skip it. Do not open a resource per iteration without closing it per iteration.

**L39. Define transaction boundaries.**  Decide what is atomic: per item, per chunk, or whole job. A whole-job transaction can be too large; per-item commits leave partial results, so the job must be resumable.

**L40. Make batch loops idempotent and resumable.**  Running the same item twice must have the same effect as once (use idempotency keys, upserts, "ensure state" semantics). Record progress durably (a checkpoint, a status per item, a high-water mark) so a restart skips completed work and continues. Assume the process can die at any line.

**L41. Do not assume "no error" means "all done".**  After the loop, verify counts: items in, items succeeded, items failed, items skipped must add up. Log them.

**L42. Support cancellation.**  Long loops check a cancellation signal between iterations and stop at a safe point.

## 3.8 Retry and polling loops

**L43. Retries are bounded, backed off, and jittered.**  Maximum attempts, exponential backoff with random jitter, and an overall deadline. Without jitter, many clients retry in lockstep and overload the recovering service.

**L44. Retry only idempotent operations, and only retryable errors.**  Retrying a non-idempotent call (charge, send, create) without an idempotency key duplicates its effect. Do not retry validation errors or permanent failures.

**L45. Avoid retry amplification.**  If three layers each retry three times, one failure becomes twenty-seven calls. Retry at one layer, or pass a shared retry budget and deadline down.

**L46. Polling loops have a bounded interval, a timeout, and a clear success and failure condition.**  Prefer events or callbacks over polling when available. Use monotonic time for durations.

## 3.9 Pagination and traversal

**L47. Pagination: prefer cursor (keyset) over offset for changing data.**  Offset pagination skips or repeats items when rows are inserted or deleted between pages. Keyset pagination requires a total order with a unique tiebreaker (`order by created_at, id`) and resumes from the last seen key. Terminate on the API's explicit end signal (no next cursor / empty page), and do not assume a short page is the last unless the API guarantees it.

**L48. Deduplicate when paging live data.**  Even with cursors, sources may return an item twice. Keep a set of seen ids for the run, or make the processing idempotent.

**L49. Graph and tree traversal: track visited nodes.**  Any structure that can contain cycles or shared substructure needs a visited set, or the traversal loops forever or repeats work. Mark a node visited when you *enqueue/push* it, not when you pop it, to avoid duplicate queue entries. Bound depth for untrusted input.

**L50. Choose traversal order on purpose.**  Breadth-first for shortest hops and level order; depth-first for exhaustive exploration and structural recursion. Use an explicit stack/queue instead of recursion when depth can be large.

## 3.10 Recursion

**L51. Recursion needs a base case that is always reached.**  State the measure that strictly decreases (size, depth, remaining input). Every recursive call must move toward the base case.

**L52. Bound depth and stack use.**  Deep recursion overflows the stack. Convert to an iterative form with an explicit stack for unbounded depth, and cap depth for untrusted structures.

**L53. Memoize overlapping subproblems.**  Naive recursion on overlapping subproblems (Fibonacci-like) is exponential. Cache results keyed by the full set of arguments that determine the result, with a bounded cache.

## 3.11 Parallel and concurrent loops

**L54. Parallel iterations must not share mutable state.**  Each iteration works on its own data and returns a result; combine results afterward. Shared accumulators need atomic operations or locks, and then are often the bottleneck.

**L55. Parallel reduce requires an associative operation (and commutative if order is not preserved).**  Floating-point addition is not associative, so parallel sums are nondeterministic. Decide whether bit-exact reproducibility is required.

**L56. Bound concurrency.**  Do not start one task per element for large inputs. Use a pool with a fixed maximum, and handle errors and cancellation across tasks.

**L57. Check-then-act inside iterations is a race.**  Same as in conditions: use atomic conditional operations, unique constraints, or locks, because two iterations or two workers can act on the same item.

---

# Part 4: Complex logic

**L58. Separate decision from action.**  Compute *what to do* in a pure function (input state to a list of intended actions), then execute the actions in a thin imperative layer. Pure decision logic is testable exhaustively without mocks, and replayable from logs.

**L59. Model workflows as explicit state machines.**  Define the states, the events, and a transition table of `(state, event) -> new state + actions`. Reject any transition not in the table. This replaces tangles of flags and nested conditions, and the table can be checked for completeness (every state handles every event, or explicitly rejects it).

**L60. Make illegal states unrepresentable.**  If the code is full of conditions defending against impossible combinations (`if shipped and not paid`), the data model allows them. Fix the model (see the data-model document), not the conditions.

**L61. Decompose by responsibility, not by line count.**  A function should do one thing you can name and whose contract you can state. As a heuristic, a cyclomatic complexity above roughly ten per function is a signal to split or use a table. [Guessing] The exact threshold varies by team and language.

**L62. Replace long if/else or switch chains on type with polymorphism, strategy tables, or lookup maps.**  When the same switch appears in many places, adding a case requires editing all of them. Keep one dispatch point.

**L63. Structure multi-step logic as a pipeline of pure stages.**  `parse -> validate -> normalize -> decide -> act`, each stage with a typed input and output. Errors are returned as values or raised at defined points, and each stage can be tested alone.

**L64. Keep the happy path linear and visible.**  Handle errors and special cases with early returns, so the main flow reads top to bottom.

**L65. Make hidden dependencies explicit.**  Time, randomness, configuration, environment, and I/O are passed in (or injected), not read from globals, so the logic is deterministic and testable.

**L66. Isolate side effects and make them replayable.**  Emit events or commands describing effects, assign each an idempotency key, and execute them with retries outside the decision logic. This makes crash recovery a replay.

**L67. Use invariants as runtime assertions at module boundaries.**  After a complex update, assert the properties that must hold (totals balance, no orphaned references, sorted order). Cheap checks in tests and sampled in production catch corruption at its source.

**L68. Avoid shared mutable global state.**  Anything two parts of the code both read and write is a coupling you must reason about everywhere. Prefer passing state explicitly, or owning it in one module with a narrow interface.

**L69. Beware of boolean flag accumulation.**  Each added boolean doubles the state space. Three flags are eight states, most invalid. Use an enumerated status or a state machine.

**L70. Write for the next reader.**  Name intermediate results, comment the *why* and the invariant (not the *what*), and keep a runnable example. Complex logic that only its author can verify is a liability.

---

# Part 5: Testing loops and complex logic

1. **Shape tests.**  Empty, one, two, many, max, max+1, duplicates, sorted, reverse-sorted, all-invalid, mixed valid/invalid.
2. **Invariant assertions.**  Put the loop invariant in code during testing (debug assertions), run it over many inputs, and see it hold at every iteration.
3. **Reference-implementation tests.**  Compare the optimized or clever version against an obviously correct but slow version over randomized inputs (differential/oracle testing).
4. **Property tests.**  Examples: output is a permutation of input (sorts); order-independence (set-like results); idempotence (running twice equals once); sum of parts equals the whole (chunked processing equals unchunked).
5. **Boundary and off-by-one tests.** First element, last element, window edges, chunk boundaries, page boundaries.
6. **Termination tests.**  Run with a timeout; try inputs designed to stall (cycles, no-progress, floats near tolerance).
7. **Scale tests.**  Run at realistic and worst-case sizes; check time and memory growth to catch quadratic and unbounded behavior. Plot against size, not just a single point.
8. **Mutation testing.**  Alter bounds, operators, initial values, and remove `break`/`continue`; if tests still pass, they are weak.
9. **Fault-injection tests.**  Kill or fail the process at each step and each iteration; restart; verify no loss, no duplication, correct final state. This is the only reliable test of resumability and idempotency.
10. **Concurrency stress tests.** Many workers, repeated runs, randomized scheduling or delays, then check the invariants.
11. **State-machine tests.** Every `(state, event)` pair tested, including the invalid ones; check every transition matches the table.
12. **Replay tests.** Feed recorded production inputs into the pure decision logic and compare to recorded decisions.

---

# Part 6: Failure-mode catalog (review checklist)

| Symptom | Likely root cause | Rule |
|---|---|---|
| Last (or first) element skipped | off-by-one, wrong bound | L10, test 5 |
| Crash or nonsense on empty input | no empty-case design | L4, L15 |
| Loop never ends | no progress measure, float counter | L3, L11, L34 |
| Wrong min/max/total | wrong initial value or accumulator | L15 |
| Skipped or duplicated items | mutating while iterating, unstable paging | L19, L47 |
| All stored objects identical | aliasing, reused buffer | L20 |
| Every callback sees last value | closure captures loop variable | L18 |
| Fast in dev, dead in prod | quadratic search, N+1 | L25, L26 |
| Memory grows until crash | unbounded accumulation, no streaming | L28 |
| Totals differ slightly run to run | float order, parallel reduce | L31, L55 |
| Result changes between runs | depends on map/set order | L22, L23 |
| Job rerun duplicates effects | not idempotent | L40, L44 |
| Job half-done after crash, cannot resume | no checkpoint, bad transaction boundary | L39, L40 |
| Resource leak or lock held | cleanup skipped by break/exception | L38 |
| Retry storm during an outage | no backoff/jitter, amplification | L43, L45 |
| Cycle in data hangs the traversal | no visited set | L49 |
| Stack overflow on deep input | unbounded recursion | L52 |
| Exponential slowdown | no memoization | L53 |
| Two workers process the same item | check-then-act race | L57 |
| "Impossible" combination happens | flag soup, illegal states representable | L59, L60, L69 |
| Logic only the author understands | tangled, no decomposition | L58, L61, L70 |

---

# Part 7: Design procedure (twelve steps)

1. Write the postcondition, invariant, and progress measure in words.
2. List behaviors for empty, one, many, max, duplicates, and invalid elements.
3. Decide scale limits (count, time, memory) and failure policy (fail-fast, collect, continue).
4. Choose the abstraction (declarative bulk operation, for-each, indexed, while, recursion).
5. Initialize with identity elements; scope all state as narrowly as possible.
6. Add explicit bounds (iterations, depth, time) to every non-obviously-finite loop.
7. Remove nested searches and per-iteration I/O (build indexes, fetch in bulk).
8. Make ordering explicit (total sort order, tiebreaker).
9. Make effects idempotent; define transaction boundaries; add checkpoints for long jobs.
10. Put cleanup in `finally`/`defer`; verify counts at the end.
11. For complex flows: pure decision function plus thin executor; explicit state machine table.
12. Write shape, property, reference, scale, and fault-injection tests.

## Pre-merge checklist

- [ ] Postcondition, invariant, and progress measure written
- [ ] Empty/one/many/max cases defined and tested
- [ ] Hard bound on every while/retry/poll/recursion
- [ ] No mutation of the collection being iterated
- [ ] No search or I/O inside the loop that could be hoisted or batched
- [ ] Order is explicit wherever it matters
- [ ] Numeric type and overflow/precision handled
- [ ] Idempotent and resumable for any job that can crash
- [ ] Cleanup unconditional; counts reconciled at the end
- [ ] Concurrency and retry behavior reviewed
- [ ] Complex flow expressed as a state table or pure decision function

---

# Part 8: What still breaks

-  A wrong postcondition. A loop that provably computes the wrong thing correctly is still wrong, and only review with the domain owner finds it.
-  Failures you did not inject. Real systems die at points no test imagined (between a database commit and a message send, during a deploy, on a full disk). Idempotency and durable checkpoints contain the damage; they cannot predict every point.
-  Data that changes under the loop (inserts, deletes, schema changes, reordering) in ways your snapshot assumptions did not cover.
-  Performance cliffs at sizes or shapes you never measured (skewed keys, huge single records, hot partitions). Scale tests with realistic data distribution reduce but do not eliminate this.
-  Emergent behavior across many cooperating loops and services (retry storms, thundering herds, feedback loops).
- [Guessing] Which rules matter most depends on your workload (batch ETL, request handlers, algorithms, UI), which I do not know. Most real systems are dominated by L19, L25, L26, L34, L40, L47, and L59.

If you tell me the kind of loops you write most (data processing, API pagination, algorithms, workflows) and the language and store involved, I can cut this document to the rules that apply to you.