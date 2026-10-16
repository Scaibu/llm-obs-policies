# Gap Class 3: Code → Spec

Oct 16, 2026 · @Chief

## Purpose and scope

A code→spec gap is behavior the system exhibits that no requirement asked for. \[Certain\] This is the "hidden implementation": it is invisible from the spec side, so no checklist derived from requirements can reveal it.

Seven sources produce it:

| Source | Example | Risk |
| --- | --- | --- |
| Language and framework defaults | Zero values, no HTTP timeout, unknown JSON fields ignored | Silent data loss, hangs |
| Library behavior | SDK retries, batches, caches or reorders internally | Duplicates, latency, stale reads |
| Error handling nobody chose | Catch-alls, fallback to empty, `default:` branches | Silent wrong answers |
| Side effects | Payloads logged, cache writes, extra network calls | Data leaks, coupling |
| Historical residue | Special case for a past customer or incident | Load-bearing and undocumented |
| Implicit coupling | Ordering assumptions, shared mutable state | Breaks on refactor or scale |
| Debug and admin paths | Bypass flags, test hooks left enabled | Security exposure |

&#91;Likely\] Defaults and unchosen error handling are the largest sources by volume. Historical residue is the most dangerous, because removing it breaks something nobody remembers.

Confidence tags: **\[Certain\]** hard evidence or definition, **\[Likely\]** strong inference, **\[Guessing\]** verify before relying on it.

## Core assumption

**Assumption:** "The code does what I wrote. What I didn't write, it doesn't do."

**What is wrong:** \[Certain\] Runtime behavior is the product of your code, the language semantics, every library, the runtime, the configuration and the environment. In edge and failure regions, most behavior is chosen by layers you didn't write.

**Why it is wrong:** Three mechanisms.

1. &#91;Certain\] **Unhandled is not unspecified.** Every case you didn't handle is handled by something: null becomes empty, an exception becomes a 500, an unknown enum hits `default:`, a missing key yields a zero value, a lost offset triggers a reset policy.
2. &#91;Certain\] **Exhaustive discovery is impossible.** What a program does is a semantic property, and no tool can decide arbitrary semantic properties of arbitrary programs (Rice's theorem). "Find all hidden behavior" can't be completed.
3. &#91;Likely\] **Authors hold a partial map.** You know the paths you designed. Library internals, past patches and copy-paste leftovers aren't in anyone's head.

**Correct model:** \[Certain\] The unit of analysis is the composed system, and your code is one component whose behavior is only partly yours. Each implicit choice is a business decision (loss, duplication, exposure, availability) made without a business owner.

**Meta question:** Who or what made this decision, and did anyone with authority over its consequences know it was being made?

**Second-order question:** If I constrain or remove this behavior, who depends on it, and what does the replacement default to?

**How to identify:** Default audit, effect inventory, backward trace, characterization tests, sibling diffing and observed production behavior (see the detection playbook).

**First-principles fix:** Replace the impossible goal (find every hidden behavior) with a possible one: make hidden behavior impossible or visible. Enumerate decision points, make each explicit, and restrict what code is allowed to do (see the derivation section).

## Sub-assumptions

Six beliefs let unrequested behavior reach production unnoticed.

### 1. "Defaults are neutral"

**What is wrong:** \[Certain\] Defaults are design choices made by library authors for their own general case, not yours. Go's `http.Client` has no timeout. Kafka consumers auto-commit offsets on a timer by default. Many ORMs default to unbounded queries.

**Why, and what is correct:** \[Likely\] Defaults are optimized for getting started, not for production correctness. Correct: every default on a critical path is a decision you inherited and must either confirm or override explicitly.

**Meta question:** For each client and framework on this path, which settings am I relying on without having set them?

**Second-order question:** When I upgrade the library and a default changes, what will notice?

**How to identify:** The default audit table in this doc. Grep for client constructors without explicit options. Diff library changelogs for default changes on upgrade.

**First-principles fix:** Set every behavior-relevant option explicitly in code or config, even when it matches the default. An explicit value survives upgrades and documents the decision.

### 2. "A fallback is safer than a failure"

**What is wrong:** \[Certain\] Fallbacks like `getOrDefault`, `?: ""`, `.get(key, {})` or `|| []` convert an error into a plausible-looking wrong answer. A failure is visible; a wrong answer propagates.

**Why, and what is correct:** \[Likely\] Developers add fallbacks to stop crashes, which optimizes for uptime over correctness without anyone choosing that trade-off. Correct: a fallback is acceptable only when the degraded result is specified and signaled.

**Meta question:** When this fallback fires, does anyone know, and is the result still correct for the caller?

**Second-order question:** What downstream state gets built on the fallback value (zero balances, empty permissions, missing tenants)?

**How to identify:** Grep for fallback idioms and empty catches in critical code. For each, check whether a metric or log fires and whether the spec allows the degraded result.

**First-principles fix:** Fail loudly by default. Allow a fallback only with an explicit decision, a counter, and a type that marks the value as degraded.

### 3. "Libraries do only what I call them to do"

**What is wrong:** \[Certain\] SDKs and clients often retry, batch, buffer, cache, pool, spawn threads or reorder internally. A producer that batches can lose buffered messages on crash; a client that retries can duplicate non-idempotent calls.

**Why, and what is correct:** \[Likely\] The API surface looks like a single synchronous call while the library runs a small system underneath. Correct: each library on a critical path has its own failure behavior that must be known and bounded.

**Meta question:** What does this library do between my call and the network, and what happens to that work if my process dies?

**Second-order question:** Do its internal retries stack with my retries and the caller's retries into a retry storm?

**How to identify:** Read the library's configuration reference for retry, buffer, batch, pool and cache settings. Trace network calls under fault injection to see actual retry counts.

**First-principles fix:** Own retries at one layer only, disable or bound the rest, and flush or drain library buffers on shutdown.

### 4. "Side effects are harmless"

**What is wrong:** \[Certain\] Logging, metrics, caching and analytics calls are behavior. Logging a full request can leak PII or secrets. A metric labeled by user ID can explode cardinality and take down monitoring.

**Why, and what is correct:** \[Likely\] Side effects are treated as infrastructure rather than features, so nobody reviews them against requirements. Correct: every side effect is subject to the same scrutiny as primary behavior.

**Meta question:** Everything this function does that isn't its return value: which requirement authorizes each one?

**Second-order question:** Who can read the logs, caches and metrics this writes to, and what is retained, for how long?

**How to identify:** Effect inventory per function. Taint-track sensitive fields into logs, metrics and caches. Diff actual network egress and DB access against the design.

**First-principles fix:** Structured logging with allowlisted fields, bounded metric labels, explicit cache policies, and egress restricted to declared destinations.

### 5. "Similar modules behave the same"

**What is wrong:** \[Likely\] Modules that share a pattern drift apart through copy-paste, one-off fixes and partial migrations. One handler missing an auth check, audit hook or validator looks identical at a glance.

**Why, and what is correct:** \[Likely\] Reviewers check each module in isolation, never against its siblings. Correct: where many modules follow one pattern, the pattern itself is the spec, and deviations are findings.

**Meta question:** If I lined up every module of this kind side by side, which ones would look different?

**Second-order question:** Is the outlier the bug, or is it the only correct one and the rest are wrong?

**How to identify:** Extract structural features per module (middleware, hooks, validators, error policies, config keys) and cluster them. Inspect outliers.

**First-principles fix:** Generate the shared pattern from one definition (framework, base class, code generation or config), so modules cannot diverge structurally.

### 6. "Code I don't understand is dead or safe to remove"

**What is wrong:** \[Likely\] Odd-looking branches are often load-bearing residue: a fix for a past incident or a special case for a customer. Per Hyrum's Law, someone depends on every observable behavior.

**Why, and what is correct:** \[Likely\] The reason left with the person who wrote it. Correct: unexplained behavior is unknown intent, not noise, until proven otherwise.

**Meta question:** Why does this exist, and what was happening when it was added?

**Second-order question:** If I remove it, who breaks, and would I find out before they told me?

**How to identify:** `git log -S` and `git blame` to find the originating commit and ticket; production branch coverage to see whether it executes; characterization tests to capture what it does.

**First-principles fix:** Characterize, then decide: promote it into the spec, constrain it, or remove it behind a flag with a metric watching for dependents.

## Default audit reference

Each row is a decision your system makes unless you override it. Verify against the exact versions you run, since defaults change between releases.

| Stack | Default | Hidden behavior | Override | Confidence |
| --- | --- | --- | --- | --- |
| Go `net/http` | `http.Client.Timeout` is 0 | Requests can hang forever | Set `Timeout` and per-request context deadlines | Certain |
| Go `net/http` | `http.Server` read, write and header timeouts are 0 | Slow clients hold connections indefinitely | Set `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`, `IdleTimeout` | Certain |
| Go `encoding/json` | Unknown fields ignored; missing fields become zero values | Schema drift and missing data are silent | `Decoder.DisallowUnknownFields()`; pointer or explicit presence checks | Certain |
| Go `database/sql` | `MaxOpenConns` is unlimited | Load spikes exhaust database connections | Set `MaxOpenConns`, `MaxIdleConns`, `ConnMaxLifetime` | Certain |
| Go `context` | No deadline unless set | Downstream calls inherit no bound | Derive with `context.WithTimeout` at each boundary | Certain |
| Kafka consumer | `enable.auto.commit=true`, every 5 s | Offsets commit whether or not processing finished; crash loses messages | Disable and commit after processing | Certain |
| Kafka consumer | `auto.offset.reset=latest` | A lost or expired offset skips all unread data | Set explicitly; alert on resets | Certain |
| Kafka consumer | `max.poll.interval.ms=300000` | Slow processing triggers rebalance and redelivery | Size to worst-case processing time; bound batch size | Certain |
| Kafka producer (3.0+) | `acks=all`, idempotence on, retries effectively unlimited within `delivery.timeout.ms` | Older clients and wrappers may differ; buffered records are lost on crash if not flushed | Set explicitly; flush on shutdown | Likely |
| Kafka Streams | `processing.guarantee=at_least_once`, commit every 30 s | Duplicates after failure; up to 30 s reprocessed | `exactly_once_v2` where needed, plus idempotent external sinks | Certain |
| Kafka Streams | Deserialization handler is log-and-fail | One poison record stops the task | Choose a handler deliberately and route to DLQ | Certain |
| Jackson (Spring Boot) | Spring Boot disables `FAIL_ON_UNKNOWN_PROPERTIES` | Unknown fields silently ignored | Set the feature explicitly per mapper | Likely |
| kotlinx.serialization | `ignoreUnknownKeys=false` | Unknown keys throw, which can break on producer schema change | Decide per boundary: strict or tolerant | Certain |
| HikariCP | Pool size 10, connection timeout 30 s | Requests queue for up to 30 s under load | Size pool to database capacity; shorter timeout | Certain |
| Python `requests` | No timeout | Calls can hang forever | Always pass `timeout=` | Certain |
| Python `json` | Duplicate keys: last one wins | Conflicting input silently resolved | Use `object_pairs_hook` to reject duplicates | Certain |
| Pydantic v2 | `extra="ignore"` | Unknown fields dropped silently | `model_config = ConfigDict(extra="forbid")` where strictness matters | Certain |
| Python functions | Mutable default arguments shared across calls | State leaks between requests | Use `None` and create inside | Certain |
| JavaScript `JSON.parse` | Numbers above 2^53 lose precision; duplicate keys last wins | Large IDs corrupted silently | Send IDs as strings; use a bigint-aware parser | Certain |
| Node.js `fetch` | No application-level timeout without an `AbortSignal` | Requests wait on internal timeouts of minutes | `AbortSignal.timeout(ms)` | Likely |
| Next.js `fetch` | Caching default changed between major versions (cached by default in 14, not in 15) | Stale or uncached data depending on version | Set `cache` or `revalidate` explicitly per call | Likely |

## Detection playbook

&#91;Certain\] You cannot list all hidden behavior, so sample the high-risk classes systematically.

### 1. Effect inventory

For each critical function, list everything it does besides returning a value, then map each effect to a requirement.

| Effect | Example | Authorized by | Finding if none |
| --- | --- | --- | --- |
| Network call | Calls enrichment API |  | Undocumented dependency |
| Database write | Updates `last_seen` |  | Hidden state change |
| Log line | Logs full request body |  | Possible PII leak |
| Metric | Counter labeled by `user_id` |  | Cardinality risk |
| Cache write | Caches response 10 min |  | Staleness nobody chose |
| Spawned work | Starts a goroutine |  | Unbounded concurrency, lost on shutdown |
| Global state | Mutates package-level map |  | Race, cross-request leak |

### 2. Backward trace

&#91;Certain\] For each significant branch in critical code, ask "which requirement justifies this?" Every branch without an answer is undocumented intent or an accident. Both are findings.

### 3. Default audit

Walk the reference table above for every client and framework on the path. Grep for constructors created without options, for example `&http.Client{}`, `http.Get(`, `requests.get(` without `timeout`, and Kafka configs missing explicit commit settings.

### 4. Fallback and swallow scan

Grep critical code for idioms that turn errors into values:

```bash
# Go: discarded errors and log-and-continue
grep -rnE "_ = |_, _ = " --include=*.go .
grep -rnE "if err != nil \{" -A2 --include=*.go . | grep -E "log\.|continue|return nil"
# Kotlin: empty or generic catches and fallbacks
grep -rnE "catch \(e: (Exception|Throwable)\)|getOrDefault|\?: \"\"|\?: emptyList" --include=*.kt .
# Python
grep -rnE "except( Exception)?:|\.get\([^,]+, (\{\}|\[\]|None|''|0)\)" --include=*.py .
```

Then confirm with linters: errcheck and staticcheck (Go), detekt (Kotlin), ruff `BLE001` and `S110` (Python).

### 5. Characterization tests

&#91;Certain\] Run the code against varied inputs (valid, empty, oversized, malformed, duplicate, unknown fields) and record outputs and side effects without judging them. Then review the recordings for surprises. This extracts the real behavior of legacy code with no spec.

### 6. Sibling diffing

&#91;Likely\] Where many modules follow one pattern, extract a feature vector per module: middleware applied, validators, hooks, error policy, config keys read, external calls. Cluster and inspect outliers. In config-driven systems with hundreds of similar units, this finds copy-paste divergence faster than any review.

### 7. Observed behavior

- &#91;Likely\] Branch coverage from canary or production builds (`go build -cover`, JaCoCo agent). Branches that fire reveal real behavior; branches that never fire are dead code or untested scenarios.
- &#91;Likely\] Distributed traces showing calls nobody listed in the design.
- &#91;Certain\] Network egress and database grants compared against the documented dependencies.

### 8. Git archaeology

&#91;Likely\] For odd branches, `git log -S "<snippet>"` and `git blame` find the originating commit and ticket. The reason tells you whether to promote, constrain or remove.

## First-principles derivation

&#91;Certain\] Finding all hidden behavior is undecidable, so the goal must change: make hidden behavior impossible where you can, and visible where you can't.

### Step 1: Enumerate decision points, not behaviors

Behaviors are infinite; the places where behavior branches are finite. \[Certain\] Behavior can only diverge at:

- **Effects:** every call that touches the network, disk, database, queue, log or shared memory.
- **Error returns:** every place an operation can fail.
- **Config reads:** every setting, explicit or defaulted.
- **Type boundaries:** every place external data becomes internal data (deserialization, parsing, casting).
- **Concurrency points:** every place work is spawned, shared or awaited.

List these for a critical path. The list is your audit surface.

### Step 2: Assign an owner and an explicit choice to each point

Each decision point needs: the chosen behavior, who chose it, and where it is written. \[Likely\] Most points in real code have "the default" as the choice and nobody as the owner. Each of those is a finding.

### Step 3: Make each choice explicit in code

- Set timeouts, retries, pool sizes, commit modes and caching explicitly, even if equal to the default.
- Make deserialization strict or tolerant on purpose, per boundary.
- Handle enums exhaustively so new values fail to compile instead of falling to `default:`.
- Return typed errors or results so every caller chooses an outcome.
- Encode degraded results in types, so a fallback value cannot pass as a normal one.

### Step 4: Apply least authority (deny by default)

&#91;Likely\] Restrict what code can do, so unrequested behavior fails loudly instead of succeeding silently:

- Egress allowlists per service.
- Narrow database grants per service (no write access where only reads are specified).
- Explicit dependency injection, no ambient global clients.
- Allowlisted log fields and bounded metric labels.
- Strict deserialization at trust boundaries.

### Step 5: Triage every finding

| Outcome | When | Action |
| --- | --- | --- |
| Promote | The behavior is valid but undocumented | Write it into the spec (feeds Gap Class 1) and add a test |
| Constrain | The behavior is a default that's wrong for you | Set it explicitly and record the decision |
| Remove | The behavior is accidental or obsolete | Characterize first, remove behind a flag, watch a metric for dependents |

### Step 6: Make the residue observable

Whatever you can't eliminate gets a signal: a counter on fallbacks, an alert on unexpected egress, reconciliation counts at boundaries. \[Certain\] Visible hidden behavior is manageable; invisible hidden behavior is how incidents start.

## Worked example: hidden behavior in an ingestion handler

The spec says: "Accept an event, enrich it with the user's country, store it, return 202." This handler does that, and its happy-path test passes:

```go
var cache = map[string]Profile{}

func (h *Handler) Ingest(w http.ResponseWriter, r *http.Request) {
    body, _ := io.ReadAll(r.Body)
    log.Printf("ingest: %s", body)
    var ev Event
    json.Unmarshal(body, &ev)

    p, ok := cache[ev.UserID]
    if !ok {
        resp, err := http.Get(h.profileURL + "/users/" + ev.UserID)
        if err == nil {
            json.NewDecoder(resp.Body).Decode(&p)
            cache[ev.UserID] = p
        }
    }
    ev.Country = p.Country

    metrics.Counter("ingest_total", "user", ev.UserID).Inc()
    h.writer.Write(ev)
    w.WriteHeader(http.StatusAccepted)
}
```

### Findings by decision point

None of this behavior appears in the spec. All of it ships.

| # | Decision point | Hidden behavior | Who decided | Triage |
| --- | --- | --- | --- | --- |
| 1 | `io.ReadAll` | No size limit; read error discarded | Default | Constrain: `http.MaxBytesReader`, handle error |
| 2 | `log.Printf` | Full payload, possibly PII, written to logs | Nobody | Remove; log allowlisted fields only |
| 3 | `json.Unmarshal` | Parse error ignored; unknown fields dropped; missing fields become zero values | Default | Constrain: strict decode, reject invalid |
| 4 | Global `cache` map | Concurrent writes crash the Go runtime; grows forever; never expires | Nobody | Constrain: bounded, concurrency-safe cache with TTL |
| 5 | `http.Get` | Default client with no timeout; one slow dependency hangs every request | Default | Constrain: dedicated client with timeout and context |
| 6 | Response handling | Body never closed (connection leak); a 404 or 500 body is decoded as a profile | Nobody | Constrain: check status, close body |
| 7 | Fetch failure path | Country silently becomes ""; an empty profile from a 404 is cached permanently | Nobody | Promote or constrain: specify behavior when enrichment fails, and signal it |
| 8 | URL construction | Unescaped user ID allows path manipulation against the profile service | Nobody | Constrain: `url.PathEscape` and validate the ID format |
| 9 | Metric label | One time series per user; monitoring cardinality grows with users | Nobody | Remove the label |
| 10 | `h.writer.Write` | Write error ignored; 202 returned even when storage failed | Nobody | Constrain: return an error status, count failures |

&#91;Certain\] Every finding survives a happy-path test with one user and a healthy profile service. \[Likely\] Findings 4, 5 and 7 are the ones that cause incidents under real traffic: a crash on concurrent writes, cascading hangs, and silently wrong enrichment that is cached forever.

Finding 7 also shows the link between classes: deciding what should happen when enrichment fails is a Gap Class 1 question the spec never answered, so the code answered it by accident.

## Failure modes and checklist

### Where this method goes wrong

- &#91;Certain\] **Removing before characterizing.** Deleting "weird" code without capturing its behavior first breaks hidden dependents.
- &#91;Likely\] **Chasing exhaustiveness.** Trying to document every behavior stalls the audit. Cover the high-risk classes: defaults, error paths, side effects on sensitive data, concurrency.
- &#91;Likely\] **Trusting the default table blindly.** Defaults change between versions and wrappers. Verify against what you actually run.
- &#91;Likely\] **Treating the outlier as the bug.** In sibling diffing, sometimes the outlier is the only correct module. Check against intent before normalizing.
- &#91;Certain\] **Constraining without signaling.** An explicit fallback with no metric is still a silent failure, just a documented one.

### Audit checklist

- [ ] Every client and framework on critical paths has explicit timeout, retry, pool and commit settings
- [ ] Deserialization is deliberately strict or tolerant at each trust boundary
- [ ] Effect inventory done for critical functions, each effect mapped to a requirement
- [ ] Fallbacks and swallowed errors are either removed or counted with a metric
- [ ] No sensitive fields in logs, metrics or caches without authorization
- [ ] Library-internal retries and buffers are known and bounded; one retry layer owns retries
- [ ] Sibling modules diffed and outliers explained
- [ ] Odd branches traced to their origin before change
- [ ] Egress and database grants restricted to documented dependencies
- [ ] Every finding triaged: promote, constrain or remove

### How the three classes connect

&#91;Certain\] Findings here that turn out to be valid behavior feed Gap Class 1 as unwritten intent. Gap Class 2 audits can only check what Gap Class 1 wrote down. \[Likely\] Running all three in a loop (intent grid, spec trace, hidden-behavior audit, back to intent) is what keeps a system's real behavior and its documented behavior converged.