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
 
# PART I: STRICT GUARDRAILS (WHAT NOT TO DO AT ALL)

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

These are non-negotiable negative constraints and architectural invariants. Systems, AI agents, and engineers MUST review these first before taking any action:

1. **NEVER Mix Backend and Frontend Paradigms:** Never blend backend hexagonal roles (`service`, `handler`, `queries`) with frontend client roles (`state`, `controller`, `views`) inside the same package or feature folder.
2. **NEVER Create Mutable State Classes in Backend:** Backend feature services are strictly stateless. Never declare an in-memory mutable `State` class inside backend services.
3. **NEVER Split Frontend State Across Files:** Exactly one state file (`state/{f}.state`) per frontend feature declaring all state variables. Controller mutates; Views only render; Models hold pure data.
4. **NEVER Bypass Inversion of Control:** Backend `service` imports `repository.port` only. Never import concrete database drivers, ORM clients, Kafka producers, or HTTP fetch/axios into domain services.
5. **NEVER Write Inline Raw SQL:** SQL queries exist solely inside `queries/{f}.queries` as named `FLOW_*` constants. Never write ad-hoc SQL strings in repositories or services.
6. **NEVER Write Inline Comments:** Document algorithm blueprint at the top of the file in the header docblock. Function bodies must be 100% comment-free.
7. **NEVER Create More Than One File Per Role:** Exactly one file per canonical role. No duplicate, fragmented, or mixed naming conventions.
8. **NEVER Bypass Middleware or Drop W3C Trace Context:**
   - Ingress MUST use `TraceMiddleware` (`src/shared/middleware/`) to extract or initialize W3C `traceparent` (`traceId: X`).
   - Every downstream layer (`service`, `rules`, `machine`, `workflow`, `adapters`) MUST spawn a child span preserving the exact same `traceId`.
   - Every log message and the final RFC response envelope MUST carry `traceId`. Never execute untraced operations.
9. **NEVER Allow Uncaught Exceptions or Raw Error Leaks:**
   - Ingress MUST use `ErrorMiddleware` (`src/shared/middleware/`) as the global safety net.
   - Every execution boundary (`handler`, `service`, `rules`, `machine`, `workflow`, `adapters`, `controller`) MUST wrap logic in structured `try / catch`.
   - All caught errors MUST be recorded on the active span (`span.record_exception(err)` and `span.set_status(Status.ERROR)`).
   - Raw stack traces, database exceptions, or secrets must NEVER leak to the caller. Errors must be mapped to typed `Result.err()` and RFC envelopes.
10. **NEVER Create Arbitrary or Auxiliary Files (Closed File Set Invariant):**
    - After scaffolding canonical files, NO auxiliary, helper, or temporary utility files may ever be created.
    - Features must strictly adhere to the closed canonical set: Backend `(01)`–`(14)` and Frontend `(01)`–`(06)`. Any deviation is strictly prohibited.

---

# PART II: BACKEND FEATURE STRUCTURE (Stateless Hexagonal Core)

## 1. Backend Role Table & Sequential Logical Flow

Naming: `{feature}.{role}.[ext]` (`{feature}_{role}` for snake_case languages).  
Tier C = always created. Tier X = created only when the trigger applies.  
The **Step #** indicates the logical request and execution flow sequence.

| Step # | Role | Path | Tier | Trigger / Purpose |
|:------:|------|------|:----:|-------------------|
| **01** | router | `src/api/rest/v1/routers/{f}.router` | C | Ingress routing: mounts endpoints, extracts W3C `traceparent`, routes incoming async request |
| **02** | handler | `src/api/rest/v1/handlers/{f}.handler` | C | Ingress delivery: parses request, executes root try/catch, manages root span, serializes response envelope |
| **03** | schema | `schema/{f}.schema` | C | Validation + Anti-Corruption Layer (ACL): bidirectional mapping (`fromApi` on input, `toApi` on output) |
| **04** | types | `types/{f}.types` | C | Pure domain models, input/output DTOs, domain error types |
| **05** | context | `context.yml` | C | Invariants, domain boundaries, required hexagonal ports |
| **06** | service | `service/{f}.service` | C | Domain orchestrator: coordinates rules, machine, workflows, transactions (`UnitOfWork`), and awaits outbound ports |
| **07** | rules | `rules/{f}.rules` | X | Business logic decision tables evaluated as structured data (priority, deny-override) |
| **08** | machine | `machines/{f}.machine` | X | Deterministic state machine DAG for entity lifecycles (>= 3 states) |
| **09** | workflow | `workflows/{f}.workflow` | X | Multi-step automation DAG steps traced under root span |
| **10** | ports | `repository/{f}.repository.port` (and outbound ports) | C | **Universal Hexagonal Outbound Ports Interface:** Abstract contracts decoupling domain service from **ANY** external subsystem (Database, 3rd-Party APIs, Kafka/Messaging, Redis/Cache, Cloud Storage, Network Sockets, GPU/OS Drivers) |
| **11** | adapters | `repository/{f}.repository` (and outbound adapters) | C | **Resilient Outbound Adapters:** Concrete adapters implementing ports, wrapped in decorator pipelines (`withTracing`, `withCircuitBreaker`, `withRetry`, `withCache`) that map raw external I/O responses back into domain entities |
| **12** | queries | `queries/{f}.queries` | C | Named parameterized `FLOW_{VERB}_{ENTITY}_{CRITERIA}` SQL queries (when persistence port is active) |
| **13** | index | `index` | C | Public facade: exports domain service and public types only; shields internal adapters |
| **14** | tests | `tests/{f}.rules.test`, `tests/{f}.machine.test` | X | Exhaustive unit tests for business rules, state machines, and domain workflows |

Agent scratch notes go in a git-ignored `.agent-notes.md`, never in `context.yml`.

## 2. Backend Flow: Bidirectional Asynchronous Pipeline

Backend execution runs in two distinct, non-blocking asynchronous directions bound within a **shared OpenTelemetry W3C trace space** (`traceId` propagated end-to-end), mediated by the **Centralized Middleware Pipeline (`src/shared/middleware/`)**:

### 2.1 Inbound Request Pipeline (↓ Ingress to Infrastructure)

```
   [Client / Consumer / Ingress Event]
                 │
                 │ (1. Ingress with W3C traceparent header)
                 ▼
      [Centralized Ingress Middleware Pipeline]
      • TraceMiddleware: Extracts/starts Root Span (traceId: X)
      • ErrorMiddleware: Wraps pipeline in global try/catch
                 │
                 │ (2. Forwards request with trace context)
                 ▼
          (01) router
                 │
                 │ (3. Matches route to feature handler)
                 ▼
          (02) handler
                 │ • Ingress delivery boundary
                 │ • Local try/catch error boundary
                 ▼
          (03) schema
                 │ • Anti-Corruption Layer (schema.fromApi)
                 │ • Validates payload & rejects invalid shapes
                 ▼
          (04) types
                 │ • Constructs strongly-typed Domain Input DTO
                 ▼
          (06) service
                 │ • Pure Domain Orchestrator
                 │ • Spawns Child Span under Root Span
                 │ • Domain try/catch + UnitOfWork transaction
                 │
                 ├─► (07) rules: Evaluates business rules as data
                 ├─► (08) machine: Verifies state machine transitions
                 └─► (09) workflow: Executes multi-step DAG
                 │
                 │ (4. Calls Outbound Port Contract)
                 ▼
          (10) ports (Universal Driven Port Interface)
                 │
                 │ (5. Implemented by decorated adapter)
                 ▼
          (11) adapters [Tracing + CircuitBreaker + Retry + Cache]
                 │
                 ├───────────────┬───────────────┬───────────────┬───────────────┐
                 ▼               ▼               ▼               ▼               ▼
          [Database Port] [3rd-Party APIs] [Kafka / Events][Cache / S3]   [Network Sockets]
          • (12) queries  • OpenAI / LLMs  • Topic Producer• Redis Cache  • TCP / UDP
          • SQL Pool      • Stripe / CRM   • CloudEvents   • Blob Storage • WebSockets
                 │               │               │               │               │
                 ▼               ▼               ▼               ▼               ▼
                       [External Subsystems / Infrastructure World]
```

#### Inbound Execution Steps:
1. **`[Middleware Pipeline]`** — `TraceMiddleware` extracts incoming W3C `traceparent` (or creates a root trace), starts **Root Span** (`traceId: X`), and binds trace context. `ErrorMiddleware` opens outer global `try/catch`.
2. **`(01) router`** — Matches route to feature handler under the active trace context.
3. **`(02) handler`** — Receives request, wraps execution in local `try/catch`, and forwards payload.
4. **`(03) schema`** — Runs `schema.fromApi()` validation (Anti-Corruption Layer). Rejects invalid payloads immediately.
5. **`(04) types`** — Packages validated data into strongly-typed domain input DTOs.
6. **`(06) service`** — Domain orchestrator: starts **Child Span**, manages domain `try/catch`, coordinates `UnitOfWork` transaction boundary.
7. **`(07-09) rules / machine / workflow`** — Evaluates business rules as data, validates state machine transitions, or executes automation DAG steps.
8. **`(10) ports` & `(11) adapters`** — Service awaits abstract outbound port contracts; resilient decorated adapters initiate external I/O.

---

### 2.2 Outbound Response Pipeline (↑ Infrastructure to Client)

```
                       [External Subsystems / Infrastructure World]
                 │               │               │               │               │
                 │ (DB Rows)     │ (HTTP JSON)   │ (Broker ACK)  │ (Cache Hit)   │ (Socket Buffer)
                 ▼               ▼               ▼               ▼               ▼
          [Database Port] [3rd-Party APIs] [Kafka / Events][Cache / S3]   [Network Sockets]
                 │               │               │               │               │
                 └───────────────┴───────────────┴───────────────┴───────────────┘
                                                 │
                                                 │ (1. Raw external response)
                                                 ▼
                                          (11) adapters
                                                 │ • Catches external timeouts/errors
                                                 │ • Anti-Corruption Layer maps to Domain Model
                                                 ▼
                                          (10) ports
                                                 │ • Delivers Result<DomainEntity, PortError>
                                                 ▼
                                          (06) service
                                                 │ • Commits or rollbacks UnitOfWork
                                                 │ • Sets Child Span status (OK / ERROR)
                                                 │ • Returns domain result
                                                 ▼
                                          (03) schema
                                                 │ • Serializes domain entity (schema.toApi)
                                                 │ • Wraps in RFC Envelope (success, data, traceId)
                                                 ▼
                                          (02) handler
                                                 │ • Returns HTTP envelope
                                                 ▼
                                          (01) router
                                                 │ • Routes response through middleware
                                                 ▼
                              [Centralized Egress Middleware Pipeline]
                              • Injects X-Trace-Id header matching active traceId
                              • Finalizes Root Span duration & status
                              • ErrorMiddleware formats Problem Details if error uncaught
                                                 │
                                                 ▼
                                [Client / Ingress Receives Response]
```

#### Outbound Execution Steps:
1. **`External Subsystems`** — Return async I/O results, broker ACKs, database rows, or network errors.
2. **`(11) adapters`** — Intercept raw response, map external shapes back to domain entities via Anti-Corruption Layer, catch timeouts/errors.
3. **`(10) ports`** — Deliver typed `Result<DomainEntity, PortError>` back to the domain service.
4. **`(06) service`** — Finalizes transaction (commit or rollback), sets child span status (`StatusCode.OK` or `ERROR`), and returns result to handler.
5. **`(03) schema`** — Serializes domain entity via `schema.toApi()` and wraps in standardized RFC envelope (`success`, `data`, `meta.traceId`).
6. **`(02) handler`** — Handles local controller response, returns envelope to router.
7. **`(01) router`** — Routes HTTP/gRPC response back through the middleware pipeline.
8. **`[Middleware Pipeline]`** — Injects `X-Trace-Id` header, completes Root Span, catches any unhandled exceptions in `ErrorMiddleware`, and streams response to client.

---

### 2.3 Universal Outbound Subsystems (Any External Technology)

The domain service **never** connects directly to external technologies. It only talks to abstract ports `(10)`, which are implemented by resilient adapters `(11)`:
- **Databases:** Executes parameterized queries `(12)` via connection pool.
- **Third-Party APIs:** Calls external REST/gRPC endpoints (e.g., OpenAI/LLMs, Stripe, GitHub).
- **Messaging & Event Streaming:** Produces CloudEvents to Kafka topics or message queues.
- **Cache & Object Storage:** Interacts with Redis cache or AWS S3 blob storage.
- **Networking & Sockets:** Communicates with raw TCP/UDP drivers or WebSockets.

*All adapters are wrapped with resilience decorators:* `withTracing(withCircuitBreaker(withRetry(withCache(adapter))))`.

---

# PART III: FRONTEND FEATURE STRUCTURE (State-Controller-Model Triad)

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

# PART IV: SHARED GENERIC KERNELS

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

# PART V: DIRECT FEATURE CREATION PROTOCOL

Feature directories and canonical files are created directly via filesystem operations according to the strict canonical role hierarchy. No external or non-existent CLI scaffolding commands are required.

### 1. Backend Feature Directory & File Layout
Directly create the canonical files in their respective paths:
```
src/
├── api/rest/v1/
│   ├── routers/{f}.router.[ext]              # (01) Ingress routing & W3C traceparent extraction
│   └── handlers/{f}.handler.[ext]             # (02) Ingress delivery, root try/catch, RFC envelope
└── features/{f}/
    ├── schema/{f}.schema.[ext]                # (03) ACL validation, fromApi / toApi
    ├── types/{f}.types.[ext]                  # (04) Domain DTOs and entity models
    ├── context.yml                            # (05) Boundary invariants & port declarations
    ├── service/{f}.service.[ext]              # (06) Pure orchestrator, child span, UoW
    ├── rules/{f}.rules.[ext]                  # (07) [Tier X] Decision tables as data
    ├── machines/{f}.machine.[ext]             # (08) [Tier X] Lifecycle state machine
    ├── workflows/{f}.workflow.[ext]           # (09) [Tier X] Multi-step DAG runner
    ├── repository/
    │   ├── {f}.repository.port.[ext]          # (10) Abstract outbound port contract
    │   └── {f}.repository.[ext]               # (11) Decorated adapter (withTracing, withRetry)
    ├── queries/{f}.queries.[ext]              # (12) Parameterized FLOW_* SQL queries
    ├── index.[ext]                            # (13) Public facade (service & public types)
    └── tests/
        ├── {f}.rules.test.[ext]               # (14) [Tier X] Business rules unit tests
        └── {f}.machine.test.[ext]             # (14) [Tier X] State machine transition tests
```

### 2. Frontend Feature Creation (State-Controller-Model Triad)
Directly create the client files adhering to the state triad:
```
src/features/{f}/
├── ui/{f}.view.[ext]                          # (01) Presentation component; consumes State, dispatches actions
├── controller/{f}.controller.[ext]            # (02) State controller; try/catch, mutates State, calls Adapter
├── state/{f}.state.[ext]                      # (03) Dedicated State class centralizing all feature variables
├── models/{f}.model.[ext]                     # (04) Pure domain models & DTOs (immutable)
├── adapter/{f}.adapter.[ext]                  # (05) Client API adapter calling backend within trace context
└── tests/
    ├── {f}.controller.test.[ext]              # (06) Controller unit tests
    └── {f}.state.test.[ext]                   # (06) State transition & mutation tests
```

### Definition of Done
A feature task is complete only when:
1. All canonical roles for the designated environment (Backend or Frontend) exist without cross-paradigm contamination.
2. Inversion of Control is preserved: Service imports only abstract Port contracts; Controller drives State.
3. Type check passes with zero errors.
4. Unit tests pass (rules/machine tests for backend; controller/state tests for frontend).