---
agent_role: "Feature Structure Compliance Enforcer"
trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_FEATURE_CREATION"
scope: "Feature creation, refactoring, code generation, maintenance"
mode: "Strict"
contract_version: "2.0"
---

# Feature Structure Contract

Sections 1-3 are always loaded. Section 4 (CLI protocol) loads on `ON_FEATURE_CREATION` only.
Reference tree: `policies/rules/folderStructure/api-structure.md` (repo-relative).

## 1. Role Table (single source of truth)

Naming: `{feature}.{role}.[ext]` (`{feature}_{role}` for snake_case languages).
Creation and population order = table order.
Tier C = always created. Tier X = created only when the trigger applies.

| # | Role | Path | Tier | Trigger / Purpose |
|---|------|------|------|-------------------|
| 1 | context | `context.yml` | C | Durable only: boundaries, invariants, ports |
| 2 | models / types | `models/{f}.model` / `types/{f}.types` | C | Domain models, input/output DTOs (pure, separate from State & Controller) |
| 3 | state | `state/{f}.state` | C | Dedicated state file: declares State class with all variables, flags & state holders |
| 4 | controller | `controller/{f}.controller` | C | Dedicated controller class: manages & mutates State class (separate from models) |
| 5 | schema | `schema/{f}.schema` | C | Validation + `Mapper` (fromApi, toApi) |
| 6 | queries | `queries/{f}.queries` | C | Named `FLOW_{VERB}_{ENTITY}_{CRITERIA}` queries |
| 7 | port | `repository/{f}.repository.port` | C | `Repository` interface instance |
| 8 | repository | `repository/{f}.repository` | C | Adapter executing queries |
| 9 | rules | `rules/{f}.rules` | X | Any business branching (see rule test below) |
| 10 | machine | `machines/{f}.machine` | X | Entity has a lifecycle (>= 3 states) |
| 11 | workflow | `workflows/{f}.workflow` | X | Multi-step automation |
| 12 | service | `service/{f}.service` | C | Orchestrates port + rules + machine, owns transactions |
| 13 | index | `index` | C | Public facade: service + public types only |
| 14 | handler | `src/api/rest/v1/handlers/{f}.handler` | C | Parse, call service, return envelope |
| 15 | router | `src/api/rest/v1/routers/{f}.router` | C | Mount endpoints |
| 16 | tests | `tests/{f}.rules.test`, `tests/{f}.machine.test` | X | Required whenever rules / machine exist |

Agent scratch notes go in a git-ignored `.agent-notes.md`, never in `context.yml`.

**State-Controller-Model Triad:**
- **State (`state/{f}.state`):** Exactly one state file declaring the `State` class where all feature variables, flags, counters, and runtime attributes are declared.
- **Controller (`controller/{f}.controller`):** Dedicated controller class that operates on and mutates the `State` class.
- **Models (`models/{f}.model` / `types/{f}.types`):** Pure domain models and DTOs, strictly separate from both State and Controller with zero mutation or controller logic.

**Rule test:** "Would a non-engineer change this condition?" Yes -> it belongs in `rules`.
Guard clauses, null checks, and loop conditions stay in code.

## 2. File Relationship DAG & Operational Data Flow

Every file has exactly one architectural responsibility and connects through strict unidirectional contracts:

```
[Inbound Request / Client]
          │
          ▼
15. router ──(DELEGATES_TO)──► 14. handler ──(INVOKES_ACL)──► 5. schema
                                    │                             │ (fromApi/toApi)
                                    │                             ▼
                                    │                     2. models / types
                                    │
                         (INVOKES_ORCHESTRATION)
                                    ▼
                             12. service ◄──(GOVERNS_BOUNDARY)── 1. context.yml
                                 │   │   ▲
                                 │   │   └───(EXPORTS_FACADE)──── 13. index (Public Facade)
                                 │   │
             ┌───────────────────┴───┴───────────────────┐
             │                                           │
  [State & Action Controller]                 [Domain Behavior Pillars]
             │                                           │
             ▼                                           ├──► 9. rules (ENFORCES_RULES)
       4. controller                                     ├──► 10. machine (TRANSITIONS_STATE)
             │ (CONTROLS_STATE)                          └──► 11. workflow (RUNS_WORKFLOW)
             ▼
         3. state (holds variables)
             │
             ▼
  [Hexagonal Persistence]
             │
             ▼
     7. repository.port ◄──(CONSUMES_PORT)── 12. service
             ▲
             │ (IMPLEMENTED_BY)
             │
     8. repository (Adapter)
             │ (EXECUTES_QUERY)
             ▼
     6. queries (FLOW_* SQL)
```

### Detailed Relationship Matrix

| File / Role | Primary Relationship | Interacts With | Data & Control Responsibility |
|---|---|---|---|
| **`context.yml`** | `GOVERNS_BOUNDARY` | `service` | Declarative contract of invariants, domain boundaries, and required ports. |
| **`models/{f}.model`** | `TYPED_BY` | `schema`, `service`, `types` | Pure, immutable domain entities & DTOs with zero state variables or controller logic. |
| **`state/{f}.state`** | `DECLARES_STATE` | `controller` | Central State class holding all runtime variables, flags, counters, and state holders. |
| **`controller/{f}.controller`** | `CONTROLS_STATE` | `state`, `handler`, `service` | Executes state transitions and mutations on the State class, separate from models. |
| **`schema/{f}.schema`** | `VALIDATES_AND_MAPS` | `handler`, `models` | Runtime validation and Anti-Corruption Layer (ACL) mapping (`fromApi` and `toApi`). |
| **`queries/{f}.queries`** | `EXECUTES_QUERY` | `repository` | Named parameterized SQL statements (`FLOW_*`), isolated from business logic. |
| **`repository.port`** | `CONSUMES_PORT` | `service`, `repository` | Abstract hexagonal interface decoupling domain service from storage tech. |
| **`repository`** | `IMPLEMENTED_BY` | `repository.port`, `queries` | Concrete database adapter executing queries against connection pool. |
| **`rules/{f}.rules`** | `ENFORCES_RULES` | `service` | Business logic decision tables evaluated as data with priority weights and deny-override. |
| **`machines/{f}.machine`** | `TRANSITIONS_STATE` | `service` | State transition graph enforcing deterministic guards on entity lifecycles (>=3 states). |
| **`workflows/{f}.workflow`** | `RUNS_WORKFLOW` | `service` | Multi-step DAG automation step sequence executed with distributed tracing. |
| **`service/{f}.service`** | `ORCHESTRATES` | Port, Rules, Machine, State | Pure domain orchestrator managing transactions (`UnitOfWork`) with zero HTTP/DB imports. |
| **`index`** | `EXPORTS_FACADE` | Other features | Public barrier exporting only domain service and public types; shields internal repositories. |
| **`handler`** | `INVOKES_DOMAIN` | `router`, `schema`, `service` | Parses request, invokes schema ACL, calls service/controller, returns RFC Envelope. |
| **`router`** | `DELEGATES_TO` | `handler` | Mounts HTTP endpoints onto API gateway routes and applies middleware/guardrails. |
| **`tests`** | `VERIFIES` | `rules`, `machine` | Unit test suites verifying business rule edge cases and state machine transitions. |

## 3. Shared Generic Kernel (written once, reused by every feature)

Location: `src/shared/kernel`. Features instantiate these types and never redefine them.

```
Result<T, E>              ok(T) | err(E)
Mapper<Api, Domain>       { fromApi(Api): Result<Domain, ValidationError>; toApi(Domain): Api }
Repository<T, ID, Q>      { get(ID); find(Q); save(T); remove(ID) }  all return Result
UnitOfWork                { run(fn): Result }   transaction boundary
State<T>                  Declares State class holding all variables, flags, and values in one file
Controller<S>             Drives, mutates, and orchestrates the State class; separate from Model
Model                     Pure domain entity / DTO definition; separate from State and Controller
RuleTable<Ctx, Decision>  { rules: Rule<Ctx, Decision>[]; priority; deny-override }
StateMachine<S, Ev, Ctx>  { initial: S; transitions: Map<S, Map<Ev, {to: S; guard?}>> }
Workflow<Ctx>             { steps: Step<Ctx>[] }   Step = { id; run(Ctx): Result; dependsOn[] }
Envelope<T>               { success; statusCode; data | error; meta: { traceId } }
```

A feature file is a typed instantiation, e.g. `RuleTable<OrderCtx, Discount>`, not custom plumbing.

## 4. Guardrails

1. **DRY:** Generic behavior goes in the kernel. If two features repeat a pattern, move it to the kernel.
2. **SRP / logic placement:** Branching only in rules. Lifecycle only in machine. Orchestration only in service. Handler only parses, calls, and wraps the envelope.
3. **Strict typing:** No `any`, no untyped dicts, no unchecked casts. Public functions return `Result`, not thrown exceptions.
4. **Dependency direction:** service imports the port only (no drivers, ORMs, pools, HTTP). Other features import only the feature `index`.
5. **Transactions:** Start and end in the service via `UnitOfWork`. Never in handler or repository.
6. **SQL:** Only in `queries`, as named `FLOW_*` constants. Parameterized, never string-built.
7. **ACL:** Wire-contract changes are absorbed in `schema` (fromApi/toApi). Domain models and DB columns never change for them.
8. **Comments:** None inside function bodies. The algorithm and rationale go in one header docblock per file.
   Exception: a single `WHY:` line is allowed for a non-obvious workaround (vendor bug, race condition), with an ADR link if one exists.
9. **One file per role.** No duplicate or mixed dot/underscore variants.
10. **Envelope:** Every handler returns `Envelope<T>` with a W3C trace ID in `meta`.
11. **State-Controller-Model Triad Separation:** Exactly one state file (`state/{f}.state`) declares the State class containing all variables and fields. One dedicated controller class (`controller/{f}.controller`) manages and mutates that State class. Models (`models/{f}.model` / `types/{f}.types`) must be strictly separate, pure domain data definitions containing zero state-tracking variables and zero controller methods.

## 5. Agent Protocol (CLI only, never REST for file operations)

```bash
# 1. Feature Scaffolding
python3 -m src.api.cli.main scaffold-feature <name> [--base-dir src/features] [--package-root <pkg>]

# 2. Creating Single Files with Mandatory Knowledge Graph Relationships
# State Class (holds all feature variables)
python3 -m src.api.cli.main create-file --path src/features/<f>/state/<f>_state.py --role FeatureState --rel DECLARES_STATE --target src/features/<f>/controller/<f>_controller.py --direction incoming

# State Controller (drives and mutates the state class)
python3 -m src.api.cli.main create-file --path src/features/<f>/controller/<f>_controller.py --role FeatureController --rel CONTROLS_STATE --target src/features/<f>/state/<f>_state.py --direction outgoing

# Domain Models (pure data models, strictly separate from state & controller)
python3 -m src.api.cli.main create-file --path src/features/<f>/models/<f>_model.py --role DomainModel --rel DEFINES_MODEL --target src/features/<f>/service/<f>_service.py --direction incoming

# 3. Connecting Existing Architectural Components
python3 -m src.api.cli.main link-file --source src/api/rest/v1/handlers/<f>_handler.py --rel INVOKES_CONTROLLER --target src/features/<f>/controller/<f>_controller.py

# 4. Architectural Discovery & Graph Verification
python3 -m src.api.cli.main feature-files <name>        # List all canonical files in the feature
python3 -m src.api.cli.main feature-map <name>          # Inspect complete route/handler/service/port mapping
python3 -m src.api.cli.main file-lineage <file_path>    # Trace upstream & downstream dependency graph
python3 -m src.api.cli.main impact <target_id>          # Analyze blast radius of changes
python3 -m src.api.cli.main graph-scan [dir]            # Synchronize workspace files into Knowledge Graph
```

Sub-package scaffolding: add `--base-dir packages/<pkg>/src/features --package-root packages/<pkg>`.
Never hand-create directories or orphan files. Populate files in table order.

### Mechanical enforcement (tooling, not prose)

CI and CLI verification must check, so the agent does not self-certify:
- Required files exist for the declared feature, and naming matches the formula.
- Import boundaries: service -> port only; cross-feature imports via `index` only; no SQL outside `queries`.
- State-Controller-Model boundaries: state holds variables only; controller mutates state; models contain zero state logic.
- Banned patterns: `any`, inline comments (except `WHY:`), string-built SQL.

### Definition of Done

A feature task is complete only when all hold:
1. `feature-files <name>` and `feature-map <name>` verify all mandatory roles exist.
2. Type check compiles with no errors.
3. Tests pass, including rules and machine tests where those roles exist.
4. Knowledge graph is synced (every new file created via `create-file` or `scaffold-feature`).