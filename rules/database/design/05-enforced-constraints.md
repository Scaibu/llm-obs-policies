# Writing Key Conditions That Don't Break: First-Principles Rules (Language-Agnostic)

Confidence tags: **** hard evidence, **** strong inference, **[Guessing]** filling gaps.

**The uncomfortable truth:**  No normalizer is correct in isolation. It is correct only relative to a written definition of "same". If you can't state that definition, no rule list will save you. The rules below are mostly ways to make that definition enforceable.

---

# Part 1: First principles

## 1.1 What a key condition actually is

 A condition on keys asks one question: are these two raw values the same identity? You have an unknown, human-defined relation `~` (the spec) and an implementation `f(raw) -> canonical`, then you test `f(a) == f(b)`.

| Property | Formal statement | Failure when violated |
|---|---|---|
| **Soundness** | `f(a)==f(b) => a~b` | False positives: distinct things merge (wrong user gets data) |
| **Completeness** | `a~b => f(a)==f(b)` | False negatives: same thing doesn't match (duplicates, "not found") |
| **Idempotence** | `f(f(x)) == f(x)` | Re-normalizing stored data corrupts it; read and write disagree |
| **Determinism** | same input, same output, always | Flaky matching across machines, runs, versions |
| **Totality or explicit partiality** | defined for every input, or rejects it explicitly | Crashes, or silent garbage on unexpected input |
| **Stability** | same output across time, runtime, deployment | Stored keys orphaned after an upgrade |

 `~` must itself be an **equivalence relation**: reflexive, symmetric, transitive. Transitivity is the one people violate. Fuzzy matching (edit distance, similarity scores) is not transitive: A~B and B~C does not imply A~C. **Fuzzy matching can never define an identity key.** Use it only for suggestions.

## 1.2 Why breakage is inevitable without discipline

 `f` is **many-to-one** (lossy) by design:
- You can never recover the raw value from the canonical one, so store the raw value too.
- Every extra thing `f` ignores (case, whitespace, accents, scale, time zone) is a place where two distinct things can merge. Each normalization step is a deliberate merge decision.

 Every condition that compares keys is a second implementation of identity. Each copy is a chance for divergence. Aim for exactly one implementation that everything else calls.

## 1.3 The seven root causes of breakage

1. **Domain violation.** Input outside what the code assumed: null, wrong type, empty, huge, malformed, wrong encoding.
2. **Wrong spec.** The code does what the author intended, but the intent merges or splits the wrong things.
3. **Path divergence.** Write path, read path, batch job, and admin script normalize differently or not at all.
4. **Representation mismatch.** Same logical value, different bytes: encodings, precision, locale, time zone, collation, hash seeds.
5. **Temporal drift.** Rules, runtimes, libraries, or data change over time, and old keys no longer match.
6. **Concurrency.** Check-then-act races, stale reads, partial updates.
7. **Adversarial input.** Spoofing, injection, resource exhaustion.

---

# Part 2: Define before you build

**R1. Write the equivalence spec before any code.**  Complete: "Two raw values are the same key when ___." Answer for your key type:
- Is case significant? Is whitespace (leading, trailing, internal) significant?
- Is formatting significant (`1,000` vs `1000`, `(555) 123` vs `555123`)?
- Is precision or scale significant (`1.0` vs `1.00`, `2024-01-01` vs `2024-01-01T00:00:00`)?
- Is time zone or locale significant?
- Is order significant (for collections)?
- What is the identity of "absent"? (null, empty, missing: same or different?)

**R2. The spec's examples are the test oracle.**  Tests assert the spec's "equal" and "not equal" pairs, never the function's current output. Otherwise bugs get frozen in as expected behavior.

**R3. Classify the key's purpose.**  Different purposes need different rules and must not share one function:
- **Identity key:** decides "is this the same entity". Must be sound above all. Equality only.
- **Lookup key:** convenience matching ("find user by email"). May be looser, but must resolve to an identity key.
- **Search key:** fuzzy, prefix, ranked. Never used in identity conditions.
- **Security key:** secrets and signatures. Compared exactly (constant-time), never normalized.

**R4. Decide the direction of your risk.**  False positives (merging distinct things) are usually far worse than false negatives for identity (accounts, payments, access control). If unsure, normalize less. A missed match is usually recoverable; a wrong merge often is not.

**R5. Name every normalization step as a separate, versioned decision.**  Each step (case folding, trimming, accent removal, scale fixing, zone conversion) gets one spec line and one test. Never add steps "just in case".

---

# Part 3: Designing the canonical form

**R6. Choose the canonical form deliberately and make it a real value.**  Options: a canonical value of the same type, a canonical string serialization, or a structured tuple. Write down which. "Whatever the library returns" is not a spec.

**R7. Parse, don't validate.**  Convert raw input to a trusted typed value once, at the boundary. After that point the system should never handle the raw form. Validating and then passing the raw value on means every downstream condition must re-trust it.

**R8. Reject at the boundary what you can't canonicalize.**  An explicit rejection is a correct outcome. "Best effort" coercion creates a second population of keys that look valid but match nothing.

**R9. Output must be pure.**  No dependence on locale, clock, environment variables, current time zone, system defaults, randomness, or I/O. The same input yields the same output on any machine, for a given version. Every implicit default in a runtime (locale, time zone, encoding, rounding mode) is a latent bug: set it explicitly or ban it.

**R10. Make it idempotent and prove it.**  `f(f(x)) == f(x)`. If this fails, any batch job that re-normalizes stored data silently changes keys. Check it as a post-condition or in tests (Part 8).

**R11. Define behavior at size limits.**  Cap input length before work and output length after. Normalization can expand data (compatibility mappings, escape sequences, padding), which creates storage and denial-of-service risk.

**R12. Normalize before validating, never after.**  Normalization can create characters or patterns your validator was meant to exclude (full-width `<` becoming `<`, escaped sequences decoding). Order: type-check, normalize, validate, then compare or store that same result.

**R13. Treat empty and absent as invalid keys by default.**  Whitespace-only input that normalizes to empty compares equal to every other empty value, so every blank record matches every other blank.

---

# Part 4: Normalization rules by key type

The principle is the same everywhere: identify every way the same logical value can have different representations, then collapse them to one.

## 4.1 Text
- **Unit of length is ambiguous.** A string has bytes, code units, code points, and user-perceived characters, and runtimes disagree on which "length" means. Specify the unit for any limit.
- **Encoding:** store and compare in one encoding. Reject malformed sequences instead of replacing them. Replacement characters silently merge distinct inputs.
- **Unicode forms:** the same visible text can be encoded multiple ways (composed vs decomposed accents). Pick one normal form. A compatibility form folds more (full-width, ligatures, superscripts) but is lossier.
- **Case:** use full case folding, not simple lowercasing, and never a locale-dependent case function.  A single global policy beats locale-sensitive matching for identity keys; document the tradeoff for Turkish and German.
- **Whitespace and invisible characters:** decide per category. Reject controls. Strip or reject zero-width and bidi characters by spec. Some scripts rely on joiners, so blanket-stripping can break legitimate keys. Reject, don't strip, characters that are unassigned in some Unicode versions, or two runtimes will disagree.
- **Confusables (look-alike characters across scripts)** survive normalization. For security-relevant keys, use a script allow-list or confusable-skeleton detection.

## 4.2 Numbers
-  **Never use floating-point values as keys.** `0.1+0.2 != 0.3`, `NaN != NaN`, and `-0 == 0` with different bit patterns.
- **Integers:** fix width and signedness. Overflow wraps silently in some runtimes and throws in others. Leading zeros, `+` signs, and hex/octal literals are parsing hazards (`"010"` is 8 in some parsers).
- **Decimals and money:** `1.0` vs `1.00` are different scales. Fix scale or compare by value, and record which. Never round implicitly.
- **Large integers across systems:**  some systems (notably JSON consumers using double-precision floats) lose precision above 2^53. Send big IDs as strings.

## 4.3 Date and time
-  Convert to a single absolute reference (UTC instant) or keep a civil date with no time zone. Never compare a local time to a UTC time.
- Fix precision (seconds, milliseconds, microseconds). Truncate versus round is a spec decision.
- Daylight saving makes civil local times ambiguous or nonexistent. Leap seconds and calendar differences exist. Date-only keys must say whose "today".
- Ranges: use half-open intervals `[start, end)`. Closed ranges double-count boundaries and cause off-by-one bugs.

## 4.4 Identifiers with formatting (UUID, hex, base64, IP, phone, email, URL, domain, path)
- **UUID/hex:** upper vs lower case, hyphens, braces, prefixes. Pick one canonical text form or store 16 raw bytes.
- **Base64:** padding, URL-safe vs standard alphabets, line breaks. Decode to bytes and compare bytes.
- **IP addresses:** compression (`::` in IPv6), leading zeros, mapped IPv4 in IPv6. Parse to a fixed-size binary form.  Some parsers treat leading zeros as octal, a classic security bug.
- **Domains:** case-insensitive, trailing dot, internationalized forms.  The local part of an email is formally case-sensitive but nearly always treated insensitively in practice; that is a spec decision, not a fact you can look up.
- **URLs and paths:** percent-encoding case, default ports, `.`/`..` segments, trailing slashes, symlinks, case-insensitive filesystems. Resolve and canonicalize before any permission or equality check.
- **Phone numbers:** convert to one international format; keep the original.

## 4.5 Collections and structured values
-  **Sets** have no order, **lists** do: decide, then canonicalize by sorting if unordered.
- **Maps/JSON objects:** key order, duplicate keys, number representation, and whitespace differ across serializers. Use a canonical serialization (sorted keys, defined number format) before hashing or comparing.
- **Composite keys:** never concatenate parts with a delimiter. `("a|b","c")` and `("a","b|c")` collide. Store as a tuple or separate fields, or length-prefix each part. Normalize each component with its own rules.
- **Hashing a canonical form** is only as stable as the canonicalization beneath it.

## 4.6 Null, missing, empty
 Define whether null, absent, empty string, zero, and false are distinct. They are distinct in data, equal in many languages' truthiness checks, and propagate differently in query languages. Make keys non-null at the schema level so conditions never depend on null semantics.

---

# Part 5: Writing the condition itself

**R14. One function owns identity.**  Every comparison goes through `same_key(a, b)` or `canonical(a) == canonical(b)` from one module. Zero inline normalization anywhere else. This single rule prevents the largest category of bugs (path divergence).

**R15. Make raw-vs-canonical comparison impossible.**  Give canonical keys their own type that only the normalizer can construct, and make comparison with any other type an error rather than `false`. A mismatch should crash in tests, not silently return "no match" in production. In weakly typed languages, use a naming convention, a lint rule, and a runtime check at module boundaries.

**R16. Equality only on identity keys.**  No `contains`, `startswith`, `endswith`, wildcard, or regex on canonical keys. `"ab"` matching `"abc"` is the standard false positive.

**R17. Know your language's equality.**  Before trusting `==`, answer: value or reference equality? Does it coerce types? Is string comparison byte-wise, code-unit-wise, or locale-aware? How does it handle NaN? Does `1 == "1"` hold? Weakly typed equality is a source of silent matches.

**R18. Avoid truthiness tests on keys.**  `if key` conflates empty, zero, null, and false. Test for the exact condition you mean.

**R19. Handle three-valued logic.**  SQL and graph query languages treat "unknown" as a third value: `NULL = NULL` is unknown, and `x NOT IN (..., NULL)` returns nothing. A row failing a condition and a row where the condition is unknown behave differently, especially under negation. Eliminate nulls at the schema level or handle them explicitly.

**R20. Be careful with negative conditions.**  `NOT`, `!=`, `NOT IN`, `NOT EXISTS` are where missing and null data hide. Prefer expressing the positive set and subtracting it. Verify De Morgan transformations with tests, not by eye.

**R21. Build lookup structures from canonical values once.**  Allow-lists, deny-lists, caches, and dedupe sets hold canonical members, built at load time, with raw and canonical never mixed in one structure.

**R22. Ordering needs a total order.**  Sorting and range conditions should compare canonical values, state the collation explicitly, and not rely on default sort order. Sort stability and locale-dependent ordering differ between systems.

**R23. Fail closed and loud.**  If canonicalization fails, reject the write or return no match, log it, and count it. Never fall back to the raw value, because that creates keys no later canonical lookup can find.

**R24. Keep the raw value alongside the canonical key.**  Store `raw`, `canonical`, and `norm_version`. Raw is needed for display, audit, debugging, and re-canonicalizing under a new version.

---

# Part 6: Storage, databases, concurrency

**R25. Enforce uniqueness in the datastore, not in application code.**  "Check then insert" is a race whenever there are two writers. Use a unique constraint or index on the canonical key. Conditional upserts ("merge if not exists") are only safe against concurrent duplicates when backed by such a constraint. Check your engine's specific guarantee.

**R26. Never wrap the stored column in a function inside the predicate.**  `WHERE f(column) = param` usually cannot use an index (full scan) and recomputes a second, possibly different normalization. Store the canonical value as its own indexed column and compare it with a parameter computed by the shared normalizer. If the database supports generated columns, derive them from the same logic, not a re-implementation.

**R27. Don't use database collation as your normalizer.**  Collation rules vary across engines, versions, and OS libraries, and can change under an upgrade (which can corrupt existing indexes). If you use one, you have two normalizers that must agree.

**R28. Know your datastore's equality and null quirks.**  For every store, answer: Are trailing spaces significant? Is comparison case-sensitive by default? How are nulls treated in unique indexes? What are the maximum key and index sizes? Is text silently truncated or rejected on overflow? Does it normalize encodings on write?

**R29. Cover every write path.**  Bulk imports, ETL jobs, admin consoles, migrations, replicas, and manual scripts bypass your application normalizer. Enforce at the lowest layer you can (constraints, triggers, generated columns), and make every tool call the shared normalizer.

**R30. Parameterize, never concatenate, queries.**  Interpolating keys into query text causes injection and also quoting bugs for keys containing quotes or delimiters.

**R31. If you hash keys, use enough bits.**  128 bits or more, from a stable algorithm, over the canonical serialization. Keep the readable canonical key too. Language built-in hash functions are often randomized per process and are not safe for persistence.

**R32. Think about consistency across replicas and caches.**  A cache keyed by raw input and a database keyed by canonical input will disagree. Key caches by canonical values, and include `norm_version` in cache keys so a rule change doesn't serve stale entries.

---

# Part 7: Multiple languages, runtimes, services

**R33. One spec, shared test vectors, every implementation.**  If more than one language or service touches the key, they will diverge on case mapping, Unicode version, numeric parsing, rounding, date handling, and serialization. A checked-in file of `(raw -> expected canonical)` pairs plus equal/not-equal pairs must pass in every implementation, in CI.

**R34. Prefer a single owner.**  Where feasible, one library bound into each language, or one service that canonicalizes for everyone, beats N reimplementations. The cost is a dependency; the benefit is no drift.

**R35. Record the environment.**  Log the runtime, library, and data-table versions (character database, time zone database) at startup, and store `norm_version` on every record. Runtime upgrades change outputs for newly assigned characters, new time zone rules, and so on.

**R36. Portability checklist for any runtime.** Before trusting a language with key logic, answer:
- What is a string's "length" unit? Is it Unicode-aware?
- Is case conversion locale-dependent by default?
- Are default encodings, locales, time zones, and rounding modes implicit?
- What are its integer overflow and float semantics?
- Is hash iteration order stable? Is the sort stable?
- What does `==` do across types and with null/NaN?
- Does the JSON/serialization layer change number precision or key order?

---

# Part 8: Testing, from first principles

Test the properties from Part 1, because examples alone can't cover an unbounded input space.

1. **Idempotence property:** `f(f(x)) == f(x)` over randomly generated input from your whole domain (property-based testing).  The single highest-value test.
2. **Totality/no-crash property:** for arbitrary input, `f` either returns a canonical key or raises your one declared error, nothing else.
3. **Soundness and completeness from the spec:** a table of pairs that must be equal and pairs that must not be. Include near-misses.
4. **Metamorphic tests:** apply a transformation the spec says is irrelevant (add padding, change case, reorder a set, re-encode) and assert the output is unchanged. Apply one the spec says is relevant and assert it changes.
5. **Differential tests:** run the same inputs through the write path, read path, batch path, and every language, and assert identical output.
6. **Golden vectors:** the shared cross-language file from R33.
7. **Boundary inputs:** empty, whitespace-only, null, max length, max length + 1, min and max numeric values, zero, negative zero, NaN, leap days, DST transitions, mixed-script text, malformed encodings, 1 MB inputs.
8. **Concurrency tests:** many simultaneous writers on the same canonical key must produce exactly one record.
9. **Collision scan on real data** before any rule change: count raw values that would now map to the same canonical key.
10. **Mutation testing:** deliberately break each normalization step and confirm a test fails. If none does, that step is untested.
11. **Fuzzing** at the boundary, with limits to catch performance blow-ups.

---

# Part 9: Versioning and migration

**R37. Version every canonical form.**  `norm_version` on every stored key. A rule change without a version silently orphans every old key.

**R38. Migration procedure:**
1. Add the new canonical column alongside the old.
2. Compute the new key for all rows (chunked, resumable, idempotent).
3. Scan for collisions (`group by new_key having count > 1`).
4. Decide per collision: merge, reject, or keep distinct with a disambiguator. Record an audit trail.
5. Run old and new conditions in shadow mode and compare results on live traffic.
6. Switch reads, then writes. Keep both keys until the diff is clean for a full traffic cycle.
7. Drop the old key. Keep a rollback path until then.

**R39. Never mutate a rule in place.**  Add a new version, support both during migration, then retire the old one.

---

# Part 10: Observability and security

**R40. Instrument the normalizer.**  Metrics: rejection count by reason, collision count, lookup-miss rate, version mismatches, input-length distribution, latency.

**R41. Log carefully.**  On a lookup miss, log the canonical key and a redacted or hashed raw value (raw keys may be personal data). Escape control characters in logs so keys can't forge log lines.

**R42. Treat keys as untrusted input.**  Bound length and complexity, avoid pathological regex, and canonicalize paths and URLs before authorization checks. Compare the canonical form you authorize on to the form you act on, to avoid check-versus-use gaps.

**R43. Don't let normalization weaken security keys.**  Secrets compare exactly. Usernames and emails that gate access need homoglyph and confusable defenses, plus reserved-name lists compared in canonical form.

**R44. Don't leak existence through behavior.**  Different errors or timing for "not found" versus "found but wrong" enable enumeration. Decide the policy.

---

# Part 11: Failure-mode catalog (review checklist)

| Symptom | Likely root cause | Rule |
|---|---|---|
| "User not found" but the record exists | write and read normalize differently | R14, R29, differential test |
| Duplicate records for the same entity | missing uniqueness constraint or completeness gap | R25, R2 |
| Wrong entity returned | soundness gap, over-normalizing, substring match | R4, R16 |
| Works on my machine, fails in prod | implicit locale/time zone/encoding/Unicode version | R9, R35 |
| Works until a library upgrade | temporal drift, no versioning | R35, R37 |
| Matches everything with blank input | empty-after-normalization allowed | R13 |
| Slow queries at scale | function wrapped around the column | R26 |
| Intermittent duplicates | check-then-insert race | R25 |
| Keys differ after a re-run job | non-idempotent normalizer | R10 |
| Off-by-one in ranges or dates | closed intervals, time zones, precision | 4.3 |
| Missing rows in a negative filter | null in three-valued logic | R19, R20 |
| Cross-language mismatch | divergent reimplementations | R33, R34 |
| Account takeover by look-alike | confusables not handled | R43 |
| Big numeric IDs corrupted | float precision in serialization | 4.2 |

---

# Part 12: Design procedure (ten steps)

1. State the key's purpose (identity, lookup, search, security).
2. Write the equivalence spec with equal and not-equal examples.
3. Choose the canonical representation and write its grammar.
4. List every domain violation and decide reject versus coerce for each.
5. Define each normalization step as a named, versioned decision.
6. Implement one pure, idempotent function in one place.
7. Create a canonical-key type or boundary so raw can't be compared with canonical.
8. Store raw, canonical, and version; enforce uniqueness in the datastore.
9. Route every write and read path through the function, including batch and admin.
10. Ship property tests, golden vectors, differential tests, metrics, and a migration plan.

---
