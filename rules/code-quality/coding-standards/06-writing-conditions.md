# Writing Conditions That Don't Break: First-Principles Rules (Language-Agnostic)

Confidence tags: **[Certain]** hard evidence, **[Likely]** strong inference, **[Guessing]** filling gaps.
Companion documents: *Key Normalization* (identity and equality of keys), *Loops and Complex Logic*, *Data Models and Types*.

**The uncomfortable truth:** [Certain] A condition is a claim about which states of the world get which behavior. Most condition bugs are not typos. The author never enumerated the states. If you cannot list the inputs and the expected outcome for each, you are guessing, and the code will encode the guess.

---

# Part 1: First principles

## 1.1 What a condition is

[Certain] A condition is a predicate over a domain: `P : D -> {true, false, unknown/error}`. Writing one means making four decisions:
1. What is `D`, including the invalid and unexpected values that can reach it?
2. Which points in `D` map to true and which to false?
3. What happens at the points where the answer is unknown (null, missing, NaN, error)?
4. What does each branch do, and is it correct for *every* point that can reach it?

## 1.2 Properties of a correct condition

| Property | Meaning | Failure when violated |
|---|---|---|
| **Totality** | Defined for every input that can reach it | Crash, or silent fall-through |
| **Precision** | True exactly where intent says true | False positives (acts when it should not) or false negatives (skips when it should act) |
| **Evaluation safety** | Evaluating it cannot throw, hang, or change state | Condition itself becomes the bug |
| **Refactor stability** | Equivalent rewrites give identical results | "Harmless" cleanups change behavior |
| **Atomicity with the action** | The state checked is the state acted on | Check-then-act races (TOCTOU) |

## 1.3 Branches are a partition

[Certain] An if / else-if / else chain, a switch, or a rule table is a partition of the input domain. A correct partition is:
- **Exhaustive:** every input lands somewhere. A missing `else` is a gap.
- **Disjoint, or explicitly ordered:** if two branches can both match, the result depends on their order. That order is invisible to readers and breaks on the first reorder.

Most branching bugs are a gap (an input nobody thought of falls through) or an overlap (an input matches the wrong branch first).

## 1.4 Fail direction is a design decision

[Certain] Every condition can be wrong in two directions, and the costs are rarely equal:
- **Fail open:** uncertain means allow, proceed, treat as true.
- **Fail closed:** uncertain means deny, stop, treat as false.

Authorization, payments, and safety checks fail closed. Best-effort enrichment and non-critical features may fail open. Decide per condition, in writing.

## 1.5 The thirteen root causes of condition bugs

Use these as a review lens. Every real bug I know of maps to one.

1. **Domain gap:** null, empty, NaN, negative, huge, wrong type, malformed input not considered.
2. **Boundary error:** `<` vs `<=`, off-by-one, inclusive vs exclusive.
3. **Negation error:** wrong De Morgan transformation, double negatives, `NOT` over a three-valued result.
4. **Precedence or grouping error:** `and`/`or` binding differently than the author assumed.
5. **Type coercion or truthiness:** `0`, `""`, `[]`, `null` treated alike, or `"1" == 1` matching.
6. **Numeric representation:** float equality, overflow, signed/unsigned mismatch, rounding.
7. **Evaluation order and short-circuit:** side effects skipped, or a guard placed after the dereference it should protect.
8. **Non-exhaustive or overlapping branches:** missing default, order-dependent matching.
9. **Stale or duplicated state:** condition reads a copy that drifted from the source of truth, or the same condition is written in several places and diverges.
10. **Time-of-check vs time-of-use:** state changes between the check and the action.
11. **Hidden environment dependence:** locale, time zone, clock, default encoding, feature flags.
12. **Wrong spec:** the condition does exactly what the author meant, and what the author meant is wrong.
13. **Condition changes state:** evaluating it mutates something, so evaluating twice differs from once.

---

# Part 2: Before you write the condition

**C1. State the rule in plain words with concrete examples first.** [Certain] Write "Allow the refund when ___, and refuse when ___" with at least three true and three false examples, including near-misses. If you cannot, you do not yet have a condition, you have a hunch. The examples become your tests.

**C2. Enumerate the input domain, including the invalid part.** [Certain] For each variable the condition reads, list: type, range, null/missing behavior, empty behavior, special values (NaN, infinity, negative zero), maximum size, and who controls it (trusted code, user, external system).

**C3. Decide what invalid input means before the main logic.** [Certain] Options: reject (error), treat as false, treat as true, or use a default. Each is a legitimate decision; leaving it to whatever the language does is not.

**C4. Draw the partition.** [Certain] For any condition with more than two outcomes, list the regions of the input space and the outcome for each. Check exhaustive and disjoint on paper before coding.

**C5. Build a boundary table.** [Certain] For every threshold, list the value just below, at, and just above it, with the expected result. Most boundary bugs are a `<` that should be `<=`, and this table is how you catch it. State explicitly whether each bound is inclusive.

**C6. Identify the source of truth for each fact in the condition.** [Certain] If the condition reads a cached, derived, or denormalized value, decide whether it can be stale and what happens when it is. Prefer reading the authoritative value.

**C7. Name the concept.** [Likely] Give each non-trivial condition a name that states the business meaning (`is_eligible_for_refund`), not the mechanics (`days < 30 and !flag`). If you cannot name it, you probably do not understand it yet.

---

# Part 3: Structure and readability

**C8. Guard clauses first.** [Certain] Handle invalid, missing, and exceptional cases at the top and exit early. The remaining body then runs only on valid input, which shrinks the domain every later condition must handle.

**C9. Keep nesting shallow.** [Likely] Beyond two or three levels, the reader cannot hold the path in their head, and bugs hide in the unreachable-looking corners. Flatten with guard clauses, extract named predicates, or use a table.

**C10. One condition, one reason.** [Likely] A line with five operators joined by `and`/`or` is several decisions fused. Split into named parts, each testable alone.

**C11. Always parenthesize mixed `and`/`or`.** [Certain] Never rely on operator precedence. `a or b and c` is `a or (b and c)` in most languages, which is rarely what a reader assumes. Parentheses cost nothing.

**C12. Prefer positive phrasing.** [Certain] `if is_valid` beats `if not is_invalid`. Avoid double negatives (`if not (not a or not b)`), which are where De Morgan mistakes live. When you must negate a compound condition, apply De Morgan explicitly and verify with a truth table:
- `not (a and b)` equals `(not a) or (not b)`
- `not (a or b)` equals `(not a) and (not b)`

**C13. Make branches exhaustive with a loud default.** [Certain] Every chain or switch ends with an explicit `else`/`default`. If the default should be unreachable, make it raise an error and log, not silently do nothing. A silent default is how new enum values get mishandled for years.

**C14. Make order irrelevant, or document and test it.** [Certain] If branches can overlap, the first match wins and reordering changes behavior. Rewrite to disjoint branches, or place a comment and a test at the ordering.

**C15. Use decision tables for many-input rules.** [Likely] With three or more inputs, a table of `(conditions -> outcome)` rows is easier to verify than nested ifs, can be tested for exhaustiveness automatically, and can be reviewed by non-programmers. Load it as data when rules change often.

**C16. Use closed types, not strings and booleans, to branch on.** [Certain] Branch on an enum or tagged union with exhaustive matching, so adding a case is a compile-time or test-time failure. Branching on raw strings (`if status == "actve"`) turns typos into silent false. See the data-model document.

**C17. Avoid boolean parameters and flag combinations.** [Likely] A function `f(a, true, false)` is unreadable, and N booleans create 2^N states of which few are valid. Use named options, enums, or separate functions.

**C18. Do not repeat a condition.** [Certain] The same rule written in two places will diverge. Define it once as a named predicate and call it everywhere, including in queries, validations, and UI.

**C19. Keep ternary and inline conditions trivial.** [Likely] One condition, two simple values, no nesting. Anything else becomes a named variable or function.

---

# Part 4: Evaluation correctness

**C20. Predicates must be pure.** [Certain] A condition must not mutate state, perform I/O with side effects, consume an iterator, or depend on a clock or randomness without that being explicit. If evaluating it twice gives a different answer or leaves a different world, you will eventually evaluate it twice (logging, retries, refactors, assertions).

**C21. Know short-circuit rules and use them deliberately.** [Certain] `a and b` may skip `b`; `a or b` may skip `b`. Put guards first (`x is not null and x.len > 0`), cheap checks before expensive ones. Never put a required side effect in the skipped operand. Also know whether your language has non-short-circuit variants and which operator you wrote.

**C22. Do not rely on evaluation order of unspecified operands.** [Likely] Some languages leave argument and operand evaluation order unspecified. Do not put two side-effecting expressions in one condition.

**C23. Avoid truthiness on values that can legitimately be zero, empty, or false.** [Certain] `if count` treats `0` as missing; `if name` treats `""` and `null` alike; `if flag` fails on a legitimate `false`. Compare against exactly what you mean: `is null`, `== 0`, `is empty`.

**C24. No implicit type coercion in comparisons.** [Certain] Do not let the language decide that `"1" == 1`, `null == 0`, or `"" == false`. Convert once at the boundary to the intended type, then compare same-typed values. Know whether your equality operator is value or reference equality, and use the strict form where available.

**C25. Handle null, missing, and unknown as a distinct case.** [Certain] Decide explicitly what each means for the condition. In languages with three-valued logic (SQL, Cypher, spreadsheets), `NULL = NULL` is unknown, not true; `NOT unknown` is unknown; an unknown filter drops the row. Eliminate nullability at the data-model level where you can.

**C26. Be careful with negative and "absence" conditions.** [Certain] `!=`, `NOT IN`, `NOT EXISTS`, "does not contain" are where missing and null data silently pass or silently vanish. Prefer stating the positive set and subtracting it. For SQL: `x NOT IN (list containing NULL)` returns no rows; use `NOT EXISTS`.

**C27. Membership tests must compare like with like.** [Certain] `x in allowed` requires both sides in the same canonical form (case, whitespace, type, encoding). Build allow- and deny-lists as sets of canonical values once. Mixed raw and canonical members is a bug waiting.

**C28. Range conditions: use half-open intervals.** [Certain] `start <= x < end` composes (adjacent ranges neither overlap nor leave gaps), and the length is `end - start`. Closed ranges double-count shared boundaries. Overlap test for two half-open ranges: `a.start < b.end and b.start < a.end`.

**C29. Floating-point comparisons.** [Certain] Never test floats for exact equality, and never use floats as identity. For measurements, compare with an explicit tolerance (absolute for values near zero, relative for large values) and document the tolerance. [Certain] Tolerance equality is not transitive, so it cannot define a key or deduplicate. For money and exact quantities, use integers (minor units) or decimals. Remember `NaN != NaN` and that every comparison with NaN is false, including `NaN != NaN` being true in most languages.

**C30. Overflow and signedness in comparisons.** [Certain] `a + b < c` can overflow, and mixing signed with unsigned can turn `-1` into a huge number. Rearrange to avoid overflow (`a < c - b` when `c - b` cannot underflow), use wider types, or use checked arithmetic. Check the language's rules for implicit conversion in mixed comparisons.

**C31. Chained comparisons behave differently per language.** [Likely] `a < b < c` means a range check in some languages and `(a < b) < c` (a boolean compared to a number) in others. Write `a < b and b < c`.

**C32. Dates and times in conditions.** [Certain] Compare instants in one reference (UTC), or civil dates in one calendar and zone. Never compare a local time with a UTC time, or a date with a timestamp. Decide whose "today" and what the precision is. Never read the clock inside the condition; pass `now` in, so the condition is testable and consistent across the evaluation.

**C33. String conditions: equality, not substring, for identity.** [Certain] `contains`, `startswith`, `endswith`, and regex are search tools. Using them to decide identity or permission produces false positives (`"admin"` matches `"administrator"`, `"/data"` matches `"/data-private"`). For paths and URLs, canonicalize before comparing. See the key-normalization document.

**C34. Regular expressions as conditions.** [Likely] Anchor them (`^...$` or the language's full-match), escape user input, bound the input length, and beware catastrophic backtracking. Test against hostile input.

---

# Part 5: Time, concurrency, and state

**C35. Check-then-act is a race.** [Certain] `if not exists: create`, `if balance >= x: debit`, `if free_slot: book` are broken whenever two actors can run concurrently, which includes two requests, two threads, two jobs, or a retry. Make the check and the action one atomic step:
- a conditional update (`UPDATE ... WHERE version = ? AND balance >= ?`),
- compare-and-set,
- a unique constraint that makes the second insert fail,
- a lock held across both, with the condition re-evaluated inside it.

**C36. Re-validate after waiting.** [Certain] Any condition evaluated before a lock acquisition, network call, queue delay, or user pause may be false by the time you act. Re-check inside the critical section, or use optimistic concurrency (version numbers) and handle the conflict.

**C37. Conditions on distributed or replicated data may read stale values.** [Likely] If reads can hit a replica or cache, a condition based on them can be wrong. For decisions that must be correct, read from the authority, or use the atomic conditional write.

**C38. Make conditions idempotent-safe.** [Certain] If an action can be retried (and in distributed systems it will be), the condition guarding it must give the right answer the second time. Prefer "ensure state X" over "do X if not done", and use idempotency keys for side effects.

**C39. Conditions that depend on time need injected time.** [Certain] Expiry, cooldowns, and windows should take `now` as a parameter, handle clock skew and non-monotonic clocks (use monotonic time for durations), and define behavior exactly at the boundary instant.

**C40. Feature flags and configuration are inputs, not constants.** [Likely] A flag read twice in one request can change in between. Read it once, pass the value, and log it. Remove flags when finished, because stale flags are dead or half-live branches.

---

# Part 6: Conditions in query languages and databases

**C41. Know three-valued logic.** [Certain] A `WHERE` clause keeps only rows where the condition is *true*; unknown rows are dropped. So `WHERE x <> 5` silently excludes rows where `x` is null.

**C42. Outer joins: placement of the filter changes the meaning.** [Certain] A filter on the optional side placed in `WHERE` removes the null-extended rows and turns an outer join into an inner join. Put conditions about the join in `ON`, and conditions about the result in `WHERE`, deliberately.

**C43. Keep predicates index-friendly.** [Certain] Do not wrap the stored column in a function or cast (`WHERE lower(col) = ?`, `WHERE col + 1 = ?`, implicit type conversion). Move the transformation to the parameter side, or store the derived value in its own indexed column.

**C44. Parameterize, never concatenate.** [Certain] Building conditions by string interpolation causes injection and quoting bugs. Dynamic filters should be assembled from allow-listed column names with bound values.

**C45. Test emptiness and absence with the right construct.** [Certain] Use `EXISTS`/`NOT EXISTS` rather than counting or `IN` with nullable subqueries. `count(*) = 0` and `NOT EXISTS` differ in cost and null behavior.

---

# Part 7: Defensive practices

**C46. Default deny for security decisions.** [Certain] Access is granted only when an explicit rule says so. Unknown role, missing flag, parse failure, and error mean deny. Compare identities and resources in canonical form, and authorize on the same representation you act on.

**C47. Validation vs assertion.** [Certain] Validate untrusted input at the boundary and handle failure gracefully. Use assertions or invariant checks for conditions that "cannot happen" inside trusted code, so that a violated assumption fails loudly in tests and logs in production rather than continuing with corrupt state.

**C48. Log the decision, not just the outcome, for important conditions.** [Likely] For authorization, billing, and routing decisions, record the inputs (redacted where needed), the rule that fired, and the result, so a wrong decision can be reconstructed after the fact.

**C49. Do not use exceptions for ordinary control flow, and do not swallow them in conditions.** [Likely] A condition that catches every error and returns false converts bugs into silent denials. Catch narrowly, and treat unexpected errors as failures, not as "false".

**C50. Keep conditions at the right layer.** [Likely] Business rules in one domain layer, not scattered across UI, API, and database triggers with slightly different versions. Where the database must enforce a rule (uniqueness, not-null, check constraints), enforce it there and in the domain layer, derived from one definition.

---

# Part 8: Testing conditions

1. **Truth-table or decision-table tests.** [Certain] For each condition, test every row of the partition, not just the happy path. For up to about four independent inputs, enumerate all combinations.
2. **Boundary value tests.** [Certain] Just below, at, and just above every threshold; empty, one, max, max+1; zero, negative, negative zero.
3. **Equivalence partitioning.** One representative per region of the input space, plus every boundary between regions.
4. **MC/DC style coverage for compound conditions.** [Likely] For each operand in an `and`/`or` expression, show a case where flipping only that operand flips the outcome. This catches wrong operators and unused operands.
5. **Equivalence tests for refactors.** [Certain] When rewriting a condition (simplifying, De Morgan, extracting), run old and new exhaustively on a small domain, or on randomized input, and assert identical results before deleting the old one.
6. **Property tests.** Complementary conditions are exclusive and exhaustive; monotonic conditions stay monotonic; idempotent conditions are stable on re-evaluation.
7. **Negative and hostile tests.** Null, wrong type, NaN, huge values, injection strings, Unicode edge cases.
8. **Mutation testing.** [Certain] Automatically flip `<` to `<=`, `and` to `or`, delete a clause, negate a result. If the test suite still passes, those conditions are untested.
9. **Concurrency tests.** Many simultaneous actors on the same resource must not violate the invariant (no double-spend, no double-booking).
10. **Time tests.** Inject the clock; test at exact boundary instants, DST transitions, leap days, and clock rollback.
11. **Differential tests across implementations.** [Certain] If the same rule exists in application code and in a query or another language, run the same inputs through both and compare.

---

# Part 9: Failure-mode catalog (review checklist)

| Symptom | Likely root cause | Rule |
|---|---|---|
| Works for normal input, crashes on empty or null | domain gap | C2, C3, C8 |
| Off by one at limits | boundary error | C5, C28 |
| Rule fires for the wrong cases after "simplifying" | De Morgan or precedence error | C11, C12, test 5 |
| New enum value silently ignored | no loud default, string branching | C13, C16 |
| Result depends on branch order | overlapping branches | C14 |
| `0` or empty treated as "missing" | truthiness | C23 |
| `"1"` matches `1`, or `null` matches `0` | implicit coercion | C24 |
| Rows disappear from a filtered query | null in three-valued logic | C25, C41 |
| Left join behaves like inner join | filter in WHERE instead of ON | C42 |
| Float comparison flaky | exact float equality | C29 |
| Rare giant-number bug | overflow, signed/unsigned | C30 |
| Double-booking, double-spend | check-then-act race | C35, C36 |
| Retry causes duplicate effect | non-idempotent condition | C38 |
| Condition passes in test, fails near midnight or in another zone | clock and time-zone dependence | C32, C39 |
| Same rule behaves differently in two places | duplicated condition | C18, C50 |
| Permission bypass with look-alike input | substring match, non-canonical compare | C33, C46 |
| Query slow at scale | function wrapped around column | C43 |
| Silent denials, unexplained false | exceptions swallowed in conditions | C49 |
| Cannot reproduce a wrong decision | no decision logging | C48 |

---

# Part 10: Design procedure (twelve steps)

1. Write the rule in plain words with true, false, and near-miss examples.
2. Enumerate the input domain, including invalid values and who controls them.
3. Decide what invalid input means (reject, false, true, default).
4. Draw the partition and check it is exhaustive and disjoint.
5. Fill the boundary table with inclusive/exclusive decisions.
6. Identify the source of truth for every fact the condition reads.
7. Choose the fail direction (open or closed) and write it down.
8. Write guard clauses first, then the core condition in positive phrasing with explicit parentheses.
9. Extract named, pure predicates; define each rule once.
10. Make branching exhaustive with a loud default, on closed types where possible.
11. Make check and action atomic, or re-check under protection, and make retries safe.
12. Write decision-table, boundary, mutation, and concurrency tests from the examples in step 1.

## Pre-merge checklist

- [ ] Rule written in words with examples, and examples are tests
- [ ] Domain enumerated; null, empty, NaN, and out-of-range handled on purpose
- [ ] Partition exhaustive; default branch fails loudly
- [ ] Boundaries inclusive/exclusive decided and tested
- [ ] Mixed `and`/`or` parenthesized; no double negatives
- [ ] No truthiness or implicit coercion on keys, counts, or flags
- [ ] Predicate is pure; no side effects in short-circuited operands
- [ ] Check-then-act is atomic or re-validated; retries are safe
- [ ] Same rule defined once
- [ ] Time injected; floats and money handled correctly
- [ ] Mutation and boundary tests pass

---

# Part 11: What still breaks

- [Certain] A wrong spec. A flawless condition implementing the wrong rule is still a bug, and no test derived from the code will find it. Only review of the rule with the people who own the domain will.
- [Certain] Rules that depend on context you did not model (tenant, region, customer tier, regulation). Scope every condition with the context it depends on, and make that context an explicit input.
- [Certain] Conditions that were correct and became wrong because the data they read changed meaning (a status gained a new value, a field started allowing null). Guard with exhaustive matching, schema constraints, and tests that run when the model changes.
- [Likely] Real-world concurrency and distributed-state failures that only appear under load or partial failure. Atomic conditional writes and idempotency reduce them; only stress and fault-injection testing find the rest.
- [Guessing] Which rules matter most depends on your stack and risk profile, which I do not know. Most real systems are dominated by C1, C2, C13, C25, C35, and C18.

If you tell me the kind of conditions you write most (business rules, validation, authorization, queries, state transitions) and the language and store involved, I can cut this document to the rules that apply to you.