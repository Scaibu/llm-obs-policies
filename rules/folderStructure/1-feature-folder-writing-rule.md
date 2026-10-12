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

## 1. Backend Role Table

Naming: `{feature}.{role}.[ext]` (`{feature}_{role}` for snake_case languages).  
Creation and population order = table order.  
Tier C = always created. Tier X = created only when the trigger applies.

| # | Role | Path | Tier | Trigger / Purpose |
|---|------|------|------|-------------------|
| 1 | context | `context.yml` | C | Durable only: boundaries, invariants, required ports |
| 2 | types | `types/{f}.types` | C | Domain models, input/output DTOs |
| 3 | schema | `schema/{f}.schema` | C | Validation + Anti-Corruption Layer `Mapper` (fromApi, toApi) |
| 4 | queries | `queries/{f}.queries` | C | Named parameterized `FLOW_{VERB}_{ENTITY}_{CRITERIA}` queries |
| 5 | port | `repository/{f}.repository.port` | C | Abstract hexagonal `Repository` port interface |
| 6 | repository | `repository/{f}.repository` | C | Concrete persistence adapter executing queries against DB pool |
| 7 | rules | `rules/{f}.rules` | X | Business logic decision tables evaluated as data (Tier X) |
| 8 | machine | `machines/{f}.machine` | X | Deterministic state machine DAG for entity lifecycle (>= 3 states) |
| 9 | workflow | `workflows/{f}.workflow` | X | Multi-step DAG automation step sequence (Tier X) |
| 10 | service | `service/{f}.service` | C | Pure domain orchestrator: owns `UnitOfWork` transactions; zero HTTP/DB imports |
| 11 | index | `index` | C | Public facade: exports domain service and public types only |
| 12 | handler | `src/api/rest/v1/handlers/{f}.handler` | C | Parse request, invoke schema ACL, call service, return RFC Envelope |
| 13 | router | `src/api/rest/v1/routers/{f}.router` | C | Mount endpoints onto API gateway router |
| 14 | tests | `tests/{f}.rules.test`, `tests/{f}.machine.test` | X | Required whenever rules / machine exist |

Agent scratch notes go in a git-ignored `.agent-notes.md`, never in `context.yml`.

## 2. Backend Flow & File Relationship DAG

```
[Inbound Client Request]
          │
          ▼
13. router ──(DELEGATES_TO)──► 12. handler ──(INVOKES_ACL)──► 3. schema (fromApi/toApi)
                                    │                             │
                                    │                             ▼
                                    │                      2. types (Domain DTOs)
                                    │
                         (INVOKES_DOMAIN)
                                    ▼
                             10. service ◄──(GOVERNS_BOUNDARY)── 1. context.yml
                                 │   ▲
                                 │   └───(EXPORTS_FACADE)──── 11. index (Public Facade)
                                 │
             ┌───────────────────┼───────────────────┐
             │                   │                   │
             ▼                   ▼                   ▼
      7. rules (as data)   8. machine (lifecycle)  9. workflow (DAG steps)
             │
             ▼
      5. repository.port ◄──(CONSUMES_PORT)── 10. service
             ▲
             │ (IMPLEMENTED_BY)
             │
      6. repository (Adapter)
             │ (EXECUTES_QUERY)
             ▼
      4. queries (FLOW_* SQL)
```

---

# PART II: FRONTEND FEATURE STRUCTURE (State-Controller-Model Triad)

## 1. Frontend Role Table

Frontend features manage interactive client-side state, user gestures, and presentation rendering.

| # | Role | Path | Tier | Trigger / Purpose |
|---|------|------|------|-------------------|
| 1 | model | `models/{f}.model` | C | Pure domain models & entity definitions (strictly separate from State & Controller) |
| 2 | state | `state/{f}.state` | C | Dedicated single state file: declares `State` class centralizing all variables, flags, counters |
| 3 | controller | `controller/{f}.controller` | C | Dedicated controller class: drives & mutates `State` class upon user/network events |
| 4 | view / ui | `ui/{f}.view` | C | Presentation UI components: consumes `State` for rendering; delegates user actions to `Controller` |
| 5 | adapter | `adapter/{f}.adapter` | C | Client API / HTTP adapter calling backend endpoints and returning domain models |
| 6 | tests | `tests/{f}.controller.test`, `tests/{f}.state.test` | C | Unit tests verifying state mutations, actions, and controller workflows |

## 2. Frontend Flow & State Triad DAG

```
   [User Gesture / Event]
             │
             ▼
         4. view (UI)
             │
             │ (DISPATCHES_ACTION)
             ▼
       3. controller ──(CALLS_API)──► 5. adapter ──► [Backend REST/gRPC API]
             │                              │
             │ (MUTATES_STATE)              ▼
             ▼                       1. models (Pure Data Models)
         2. state (Central State Class)
             │
             │ (EMITS_STATE_CHANGE / REACTIVE_RE-RENDER)
             ▼
         4. view (UI)
```

### State-Controller-Model Triad Responsibilities:
- **`state/{f}.state`:** Exactly **one state file** declaring the `State` class. Centralizes **all feature variables**, reactive values, flags (`isLoading`, `hasError`, `isDirty`), and form states.
- **`controller/{f}.controller`:** Dedicated controller class for the state class. Handles incoming events, coordinates async operations, invokes API adapters, and executes state mutations.
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