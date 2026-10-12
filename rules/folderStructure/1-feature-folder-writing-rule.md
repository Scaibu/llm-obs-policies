---
agent_role: "Feature Structure Compliance Enforcer"
trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_FEATURE_CREATION"
scope: "Backend and Frontend Feature Creation, Refactoring, Code Generation, Maintenance"
mode: "Strict"
contract_version: "2.1"
---

# Feature Structure Contract (Backend & Frontend Segregated)

> **Architectural Separation Principle:**  
> Backend and Frontend features operate under fundamentally different execution models. They must **NEVER** be merged into a single blended folder structure:
> - **Backend Features:** Strictly **stateless**, hexagonal domain-driven architecture (`Router` -> `Handler` -> `Service` -> `Port` -> `Repository` -> `Queries`).
> - **Frontend Features:** Stateful client architecture strictly adhering to the **State-Controller-Model Triad** (`View` -> `Controller` -> `State` -> `Model`).

---

# PART I: BACKEND FEATURE STRUCTURE (Stateless Hexagonal Core)

## 1. Backend Role Table & Sequential Logical Flow

Naming: `{feature}.{role}.[ext]` (`{feature}_{role}` for snake_case languages).  
Tier C = always created. Tier X = created only when the trigger applies.  
The **Step #** indicates the logical request and execution flow sequence.

| Step # | Role | Path | Tier | Trigger / Purpose |
|:------:|------|------|:----:|-------------------|
| **01** | router | `src/api/rest/v1/routers/{f}.router` | C | Ingress routing: mounts endpoints, extracts W3C `traceparent` |
| **02** | handler | `src/api/rest/v1/handlers/{f}.handler` | C | Ingress delivery: parses request, runs try/catch, returns RFC Envelope |
| **03** | schema | `schema/{f}.schema` | C | Validation + Anti-Corruption Layer `Mapper` (fromApi, toApi) |
| **04** | types | `types/{f}.types` | C | Pure domain models, input/output DTOs |
| **05** | context | `context.yml` | C | Invariants, domain boundaries, required hexagonal ports |
| **06** | service | `service/{f}.service` | C | Domain orchestrator: owns try/catch, spans, `UnitOfWork` transactions |
| **07** | rules | `rules/{f}.rules` | X | Business logic decision tables evaluated as structured data |
| **08** | machine | `machines/{f}.machine` | X | Deterministic state machine DAG for entity lifecycles (>= 3 states) |
| **09** | workflow | `workflows/{f}.workflow` | X | Multi-step automation DAG steps traced under root span |
| **10** | port | `repository/{f}.repository.port` | C | Abstract hexagonal domain port interface |
| **11** | repository | `repository/{f}.repository` | C | Database persistence adapter executing queries against pool |
| **12** | queries | `queries/{f}.queries` | C | Named parameterized `FLOW_{VERB}_{ENTITY}_{CRITERIA}` SQL queries |
| **13** | index | `index` | C | Public facade: exports domain service and public types only |
| **14** | tests | `tests/{f}.rules.test`, `tests/{f}.machine.test` | X | Exhaustive unit tests for business rules and state machines |

Agent scratch notes go in a git-ignored `.agent-notes.md`, never in `context.yml`.

## 2. Backend Flow & Sequential Logical DAG

Every request traverses this exact logical step sequence under a **single shared OpenTelemetry trace context**:

```
[Inbound Client Request with W3C traceparent]
          │
          ▼
   (01) router ──────(DELEGATES_TO)────► (02) handler ───(INVOKES_ACL)───► (03) schema
   (Ingress Route)                       (Try/Catch + Root Span)           (fromApi/toApi)
                                                │                                 │
                                                │                                 ▼
                                                │                           (04) types
                                                │                           (Domain DTOs)
                                     (INVOKES_DOMAIN)
                                                ▼
                                         (06) service ◄──(GOVERNS_BOUNDARY)── (05) context.yml
                                     (Try/Catch + Child Span)
                                           │        ▲
                                           │        └──(EXPORTS_FACADE)─── (13) index
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
                    ▼                      ▼                      ▼
               (07) rules             (08) machine           (09) workflow
            (Business as Data)      (Lifecycle States)     (DAG Step Runner)
                    │
                    ▼
          (10) repository.port ◄──(CONSUMES_PORT)── (06) service
                    ▲
                    │ (IMPLEMENTED_BY)
                    │
          (11) repository (Adapter)
                    │ (EXECUTES_QUERY)
                    ▼
          (12) queries (FLOW_* SQL)
                    │
                    ▼
          [Database Connection Pool]
```

---

# PART II: FRONTEND FEATURE STRUCTURE (State-Controller-Model Triad)

## 1. Frontend Role Table & Sequential Logical Flow

Frontend features manage interactive client-side state, user gestures, and presentation rendering.

| Step # | Role | Path | Tier | Trigger / Purpose |
|:------:|------|------|:----:|-------------------|
| **01** | view / ui | `ui/{f}.view` | C | Presentation UI components: consumes `State`, dispatches actions |
| **02** | controller | `controller/{f}.controller` | C | Dedicated controller class: try/catch, mutates `State`, calls adapter |
| **03** | state | `state/{f}.state` | C | Dedicated single state file: declares `State` class centralizing all variables |
| **04** | model | `models/{f}.model` | C | Pure domain models & entity definitions (separate from State & Controller) |
| **05** | adapter | `adapter/{f}.adapter` | C | Client API / HTTP adapter calling backend endpoints within trace space |
| **06** | tests | `tests/{f}.controller.test`, `tests/{f}.state.test` | C | Unit tests verifying state mutations, actions, and controller workflows |

## 2. Frontend Flow & State Triad DAG

```
   [User Gesture / Event]
             │
             ▼
      (01) view (UI)
             │
             │ (DISPATCHES_ACTION)
             ▼
      (02) controller ───────(CALLS_API)──────► (05) adapter ──► [Backend REST/gRPC API]
    (Try/Catch + Child Span)                           │
             │                                         │
             │ (MUTATES_STATE)                         ▼
             ▼                                  (04) models (Pure Data Models)
      (03) state (Central State Class)
             │
             │ (EMITS_STATE_CHANGE / REACTIVE_RE-RENDER)
             ▼
      (01) view (UI)
```

### State-Controller-Model Triad Responsibilities:
- **`state/{f}.state`:** Exactly **one state file** declaring the `State` class. Centralizes **all feature variables**, reactive values, flags (`isLoading`, `hasError`, `isDirty`), and form states.
- **`controller/{f}.controller`:** Dedicated controller class for the state class. Handles incoming events, coordinates async operations, invokes API adapters, and executes state mutations within structured `try/catch` and child trace spans.
- **`models/{f}.model`:** Pure, immutable data structures and DTOs. Strictly separated from State and Controller, containing zero state-tracking variables and zero controller methods.

---

# PART III: SHARED GENERIC KERNELS

Features instantiate shared generic types and never redefine plumbing:

### Backend Kernel (`src/shared/kernel`):
```
Result<T, E>              ok(T) | err(E)
Mapper<Api, Domain>       { fromApi(Api): Result<Domain, ValidationError>; toApi(Domain): Api }
Repository<T, ID, Q>      { get(ID); find(Q); save(T); remove(ID) }  all return Result
UnitOfWork                { run(fn): Result }   transaction boundary
RuleTable<Ctx, Decision>  { rules: Rule<Ctx, Decision>[]; priority; deny-override }
StateMachine<S, Ev, Ctx>  { initial: S; transitions: Map<S, Map<Ev, {to: S; guard?}>> }
Workflow<Ctx>             { steps: Step<Ctx>[] }   Step = { id; run(Ctx): Result; dependsOn[] }
Envelope<T>               { success; statusCode; data | error; meta: { traceId } }
```

### Frontend Kernel (`src/shared/client-kernel`):
```
State<T>                  Central state container holding feature variables, status, and error states
Controller<S>             Base controller dispatching actions and mutating State<S>
Model                     Immutable domain entity / value object
ApiPort<T>                HTTP/transport facade returning Result<T, Error>
```

---

# PART IV: STRICT GUARDRAILS

1. **Architectural Segregation:** Never mix backend hexagonal roles (`service`, `handler`, `queries`) with frontend client roles (`state`, `controller`, `views`) inside the same package or feature folder.
2. **Backend Statelessness:** Backend feature services are strictly stateless. Never declare an in-memory mutable `State` class inside backend services.
3. **Frontend Triad Isolation:**
   - Exactly one state file (`state/{f}.state`) per frontend feature declaring all state variables.
   - Controller handles mutations; Views only render state and trigger controller actions.
   - Models are pure data structures with zero state logic.
4. **Hexagonal Dependency Inversion (Backend):** Backend `service` imports `repository.port` only. No concrete database drivers or HTTP frameworks in services.
5. **Zero Raw SQL (Backend):** SQL queries exist solely inside `queries/{f}.queries` as named `FLOW_*` constants.
6. **Zero Inline Comments:** Document algorithm blueprint at the top of the file in the header docblock. 100% comment-free function bodies.
7. **One File Per Role:** Exactly one file per canonical role. No duplicate or mixed naming conventions.
8. **Shared Common Trace Space (End-to-End Distributed Tracing):**
   - Every operation, state mutation, network call, and database query MUST share a single, unbroken W3C Trace Context (`traceparent`, `traceId`, `spanId`).
   - The ingress boundary (`router`/`handler` in backend; user event in frontend) extracts or initializes the root span.
   - Every sub-layer (`service`, `rules`, `machine`, `workflow`, `repository`, `controller`) MUST spawn a child span under the same `traceId`.
   - The active `traceId` must be stamped onto all logs and echoed in the RFC Envelope (`meta.traceId`) so any operation can be inspected in a unified trace waterfall.
9. **Strict Try-Catch & Error Resilience Invariant:**
   - Every ingress and orchestration boundary (`handler`, `service`, `controller`) MUST wrap execution in structured `try / catch` blocks.
   - When an exception occurs:
     1. Record the exception on the active OpenTelemetry span (`span.record_exception(err)` and `span.set_status(Status.ERROR)`).
     2. Map the error into a standardized domain `Result.err()` or typed error DTO.
     3. Return the RFC standardized response envelope (`success: false`, `statusCode`, `error: { code, message, retryable, details }`, `meta: { traceId }`).
     4. Raw stack traces, internal database exception strings, and secret credentials must NEVER leak to the caller.

---

# PART V: AGENT CLI PROTOCOL

```bash
# ------------------------------------------------------------------------------
# 1. Backend Feature Scaffolding & Graph Registration
# ------------------------------------------------------------------------------
python3 -m src.api.cli.main scaffold-feature <name> [--base-dir src/features] [--package-root <pkg>]

# Inspect Backend Feature Architecture & Lineage
python3 -m src.api.cli.main feature-files <name>        # List all canonical feature files
python3 -m src.api.cli.main feature-map <name>          # Inspect route -> handler -> service -> port mapping
python3 -m src.api.cli.main file-lineage <file_path>    # Trace upstream/downstream dependency graph
python3 -m src.api.cli.main impact <target_id>          # Blast radius impact analysis

# ------------------------------------------------------------------------------
# 2. Frontend Feature Creation (State-Controller-Model Triad)
# ------------------------------------------------------------------------------
# Create Central State Class
python3 -m src.api.cli.main create-file --path src/features/<f>/state/<f>_state.ts --role FeatureState --rel DECLARES_STATE --target src/features/<f>/controller/<f>_controller.ts --direction incoming

# Create State Controller
python3 -m src.api.cli.main create-file --path src/features/<f>/controller/<f>_controller.ts --role FeatureController --rel CONTROLS_STATE --target src/features/<f>/state/<f>_state.ts --direction outgoing

# Create Pure Domain Model
python3 -m src.api.cli.main create-file --path src/features/<f>/models/<f>_model.ts --role DomainModel --rel DEFINES_MODEL --target src/features/<f>/controller/<f>_controller.ts --direction incoming

# Create View / UI Component
python3 -m src.api.cli.main create-file --path src/features/<f>/ui/<f>_view.tsx --role FeatureView --rel RENDERS_STATE --target src/features/<f>/state/<f>_state.ts --direction outgoing

# Connect View to Controller
python3 -m src.api.cli.main link-file --source src/features/<f>/ui/<f>_view.tsx --rel DISPATCHES_ACTION --target src/features/<f>/controller/<f>_controller.ts
```

### Definition of Done
A feature task is complete only when:
1. All canonical roles for the designated environment (Backend or Frontend) exist without cross-paradigm contamination.
2. Type check passes with zero errors.
3. Unit tests pass (rules/machine tests for backend; controller/state tests for frontend).
4. Knowledge graph is synchronized.