## The mechanics every phase relies on

**Component contract.** Every long-lived component exposes three things: start (with a cancellation context and deadline), stop (with a deadline), and health. 

**Started-components stack.** `main` pushes each component after its start succeeds. Shutdown pops in reverse. This one structure covers partial-startup failure, normal shutdown, and ordering.

**Single fatal channel.** Every background task reports failure into one channel owned by `main`. The first fatal error wins and triggers shutdown. Later errors are logged, not lost.

**Error classification table**, written down before coding:

| Class | Meaning | Reaction |
|---|---|---|
| Fatal | Process can't be correct (hard dependency lost, store corrupt, listener died) | Begin shutdown, nonzero exit |
| Degrade | A soft dependency or optional component failed | Mark degraded, keep serving, alert |
| Ignore | Expected transient (one probe failed, one client disconnected) | Count in metrics only |

 If you skip this table, you will end up at one of two extremes: everything fatal (crash loops) or nothing fatal (half-alive process). Both are common.

## Phase 0: Process bootstrap

**Goal:** reach a state where the process can be stopped cleanly and can report, before doing anything that can fail.

**Steps, in this order:**
1. Parse flags: config location, validate-only, and nothing else. Every other setting belongs in config, not flags, so there is one source of truth.
2. Reject unknown flags with a usage error and a distinct exit code.
3. Install signal handlers for the termination signals your platform uses. Make them do one thing only: cancel the root context and record which signal arrived. No logic inside the handler.
4. Create the root cancellation context. Everything derives from it.
5. Create the instance identity: unique ID per process run, plus build version and start time. Attach it to every log line and metric.
6. Install the last-resort crash handler: on unrecoverable error, log with stack and instance ID, then exit with the runtime-fatal code.
7. Start the **bootstrap logger**: stderr, structured, conservative level. Metrics and tracing initialize here too, but in a no-op-safe mode if their backends aren't reachable. 

**Invariants after the phase:** signals are already captured, so an early termination signal cancels the context and later phases see it. The process holds no ports, files, or connections.

**Failure behavior:** flag errors exit with the usage code. Nothing needs cleanup yet.

**Common mistakes**
- Signal handlers installed after config load, so a termination signal during a slow load kills the process uncleanly.
- Doing work in the signal handler itself, which risks deadlocks and reentrancy bugs.
- Unbounded telemetry initialization that hangs startup.

**Verify:** send a termination signal at several points during startup (including immediately) and confirm exit is clean every time.

## Phase 1: Configuration

**Goal:** produce one immutable, fully validated configuration object, or exit with every problem listed.

**Steps**
1. **Layers, lowest to highest precedence:** built-in defaults, config file, environment, secrets source. Decide and document the precedence once.
2. **Secrets handled separately.** They are loaded through a distinct path and wrapped so they cannot be printed (redacting type or accessor).
3. **Schema validation:** types, ranges, required fields, enum membership, unknown keys. Reject unknown keys, because a typo like a misspelled timeout would otherwise silently use the default.
4. **Cross-field rules:** things like drain timeout must be shorter than the global shutdown deadline, probe timeout shorter than probe interval, port collisions between public and admin listeners, and any value that is only valid in combination.
5. **Collect all errors**, then report them together with the field path and why it's wrong. Don't stop at the first.
6. **Freeze.** After validation the object is read-only. Components receive the parts they need, not the whole object.
7. **Reconfigure the logger** from the frozen config, and emit a config **fingerprint** (a hash plus the list of which layer supplied each value, with secrets masked). The fingerprint helps debugging without leaking.

**Invariants after the phase:** all environment variable access is finished. Nothing later reads the environment.

**Failure behavior:** print all errors to stderr, exit with the config-error code, hold no resources.

**Common mistakes**
- Defaults scattered through components, so the "real" configuration can't be inspected anywhere.
- Validating lazily, so a bad value surfaces hours later.
- Logging the full config.
- Silent coercion (a string where a number belongs) that hides mistakes.

**Verify:** a test suite of invalid configs, each asserting the exact error list. A test that dumps a config containing secrets and asserts nothing sensitive appears in any output.

## Phase 2: Construct components

**Goal:** build the object graph without causing any side effects.

**Rule:** no network, no disk writes, no goroutine/thread/task spawning, no listening, in a constructor. If it touches the outside world, it belongs in start.

**Steps**
1. **Plugin table:** one file mapping type names (for adapters, selectors, policies, stores, launchers, sources) to factories. It is the only place concrete implementations are named. A config value naming a type that isn't in the table is a Phase 1 or 2 error with a clear message.
2. **Construction order, by dependency:** store, registry, health aggregator, policy chain, selectors, transport adapters, router, supervisor, admin component.
3. **Explicit injection:** each constructor receives exactly what it needs. No lookups from a global registry, no "get instance" statics.
4. **Interface-typed fields:** components hold interfaces, never concrete types, so tests can substitute fakes.
5. **Register each component** in an ordered list with its dependencies declared. `main` computes start order from that list rather than from a hand-maintained sequence.
6. **Detect missing wiring here:** a component requiring a dependency that wasn't constructed fails immediately.

**Invariants after the phase:** every component exists and is inert. Calling stop on any of them is safe.

**Failure behavior:** exit with the config-error code (it is a wiring or config problem). Nothing to unwind.

**Common mistakes**
- "Lazy" constructors that connect on first use. That moves failures into the request path.
- Import-time or static initialization that creates hidden global state.
- A factory table that grows per-service entries. Services are data, only implementation *types* belong there.

**Verify:** construct the whole graph in a test with networking disabled, and assert no sockets or background tasks exist afterward.

## Phase 3: Load and validate desired state

**Goal:** know exactly what should run before anything starts.

**Steps**
1. Each Source returns descriptors. Sources run with a timeout, and a Source failure is classified (for the primary source, fatal at startup).
2. **Schema validation** of each descriptor, including the descriptor schema version.
3. **Uniqueness:** names and identifiers collide-check across all sources, with a clear rule for conflicts. The safe default is to reject, not to let the last one win.
4. **Capability resolution:** every required capability must have at least one provider or be explicitly marked optional. Report all unresolved ones together.
5. **Dependency graph:** build it, detect cycles, and print the cycle path in the error. Compute the topological order and keep it as data.
6. **Reference checks:** policies, adapters, and selectors named in descriptors must exist in the plugin table.
7. **Validate-only exit point:** if validate-only was requested, print the report (counts, order, warnings) and exit 0 on success or the desired-state-error code on failure.

**Invariants after the phase:** a validated, versioned desired-state set, and a start order.

**Failure behavior:** all errors reported together, exit with desired-state-error code.

**Common mistakes**
- Validating per descriptor only, missing problems that appear across descriptors (duplicates, cycles, dangling capabilities).
- Treating "empty desired state" as success without a warning.  It is nearly always a misconfiguration.
- Validate-only mode that skips steps the real run performs. Both must use the same code path.

**Verify:** fixtures for each failure type (duplicate, cycle, missing capability, bad reference), plus an assertion that validate-only and the real run produce the same verdict.

## Phase 4: Admin surface up (moved earlier)

**Goal:** be inspectable from the moment services begin starting.

**Steps**
1. Bind the admin listener on its own address, separate from public traffic. Admin must never be reachable by default from public networks. 
2. Require authentication or a network restriction on admin. Whichever you choose, make it explicit configuration, not an implicit assumption.
3. **Endpoints:** liveness (process responsive), readiness (initially false, with reason), startup status (which phase, which services pending), current desired-state revision, registry view, component health, metrics, and a reload trigger.
4. **Reload trigger semantics:** it signals the watcher, it doesn't apply anything itself. `main` takes no part in reload.
5. Liveness and readiness are separate. Liveness must not depend on any downstream, or a dependency outage causes restarts that make it worse.

**Failure behavior:** if admin can't bind, that is fatal at startup, because you would be running blind.

**Common mistakes**
- Readiness true before hard dependencies are ready.
- Liveness checking dependencies.
- Admin sharing the request thread pool with public traffic, so overload hides the diagnostics you need.

**Verify:** during an artificially slow service start, admin answers and reports which service is pending.

## Phase 5: Reconcile and start services

**Goal:** make actual state converge to desired state, with `main` as an observer only.

**Steps**
1. Hand the validated desired state and start order to the supervisor.
2. The supervisor starts services in topological order. Independent services at the same depth may start in parallel, with a concurrency cap.
3. Each service has a **start deadline** and a **readiness condition** (from its descriptor, with defaults).
4. Classify each dependency edge as hard or soft. A hard failure aborts startup. A soft failure marks the service degraded and continues, with dependents informed.
5. **Restart policy for startup failures:** distinguish "failed to become ready" (config or dependency problem, bounded retries with backoff and jitter, then give up) from "crashed after being ready" (restart with a budget). 
6. Keep reconciling continuously after startup. The same loop handles later descriptor changes (add, update, remove), so there is no separate "reload code path".
7. The supervisor pushes lifecycle events and failures into the single fatal channel using the classification table.

**Failure behavior:** a fatal failure triggers the shutdown path from the current started-stack, then exit with the dependency-error code.

**Common mistakes**
- `main` starting services directly, creating a second code path for reload.
- Treating "process started" as "ready".
- Starting everything in parallel and ignoring dependency order, which produces startup races that only appear under load.

**Verify:** inject a hard dependency that never becomes ready and confirm abort within the deadline, correct exit code, and no leaked processes.

## Phase 6: Data plane

**Goal:** accept traffic only when it can be served correctly.

**Steps**
1. Build the route table and capability index from the registry snapshot.
2. Verify hard dependencies are ready. If any aren't, don't listen.
3. Bind the public listener. Apply ingress limits (header size, body size, read timeouts, connection caps) at bind time.
4. Flip readiness to true only after the listener is accepting.
5. From now on, the data plane serves from its local snapshot and does not call the control plane per request.

**Failure behavior:** bind failure is fatal.

**Common mistakes**
- Listening first and becoming ready later, which sends traffic into an unready process during the gap.
- An empty route table treated as acceptable without a signal.

**Verify:** requests before readiness are rejected with a clear status, and requests after succeed.

## Phase 7: Run

**Goal:** stay alive correctly and notice every failure.

**Steps**
1. `main` blocks on exactly two events: root context cancelled (signal), or the first fatal error.
2. Log which one occurred and why, then enter shutdown.
3. Degrade-class events change readiness or flags according to descriptors but do not wake `main`.
4. A **watchdog** verifies the fatal channel itself is healthy and that critical components are heartbeating.  A silent stall is the failure mode that signals and error channels cannot see.

**Common mistakes**
- Background tasks that log an error and exit without reporting it.
- Fatal errors that are only logged.
- `main` doing periodic work, which gives it a second job.

**Verify:** kill a critical background task and confirm the process exits with the runtime-fatal code and not a hang.

## Phase 8: Shutdown

**Goal:** stop without dropping accepted work, and never hang.

**Steps, each with its own deadline**
1. Record the reason and the first-fatal or signal origin.
2. Flip readiness to false.
3. **Propagation wait:** pause for the configured interval so upstream routers can notice. This is a parameter, it can be zero if nothing sits in front of you.
4. Stop accepting new connections.
5. **Drain** in-flight requests until complete or the drain deadline hits. Cancel stragglers with a clear status. For streaming requests, signal the end of the stream explicitly.
6. Stop services in **reverse start order** by popping the started-stack, skipping anything that never started.
7. Stop the supervisor and registry, then close the store, then flush logs, metrics, and traces.
8. Exit with the code matching the original reason.


**Common mistakes**
- Summing per-step deadlines without checking them against the global one. Validate that in Phase 1.
- Closing the store before services that still write to it.
- Shutdown code that assumes startup completed.

**Verify:** shutdown at each of the nine points (mid-Phase 2, mid-Phase 5, during drain) leaves no orphan processes, open ports, or unflushed logs.

## Exit codes

Choose them once and document them. These numbers are arbitrary, only their consistency matters.

| Code | Meaning |
|---|---|
| 0 | Clean exit (including a normal signal-driven shutdown) |
| 2 | Usage or flag error |
| 3 | Invalid configuration |
| 4 | Invalid desired state (validation failed) |
| 5 | Hard dependency failed at startup |
| 6 | Runtime fatal error |
| 7 | Shutdown deadline exceeded, forced exit |



## What main must not contain (expanded)

- Business logic, request handling, or per-request code of any kind.
- Any name of a specific service, provider, vendor, model, or protocol.
- Retry, timeout, breaker, or rate-limit logic.
- Environment reads outside Phase 1.
- Global mutable state reachable from other files.
- Restart logic for services (supervisor's job).
- Reload logic (watcher and reconciler's job).
- A second startup path for "reload" versus "initial start".
