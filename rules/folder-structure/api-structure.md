---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD"
agent_role: "Principal Enterprise Architect & Polyglot API Governance Guardian"
target_scope: "All Polyglot Sub-Packages, Workspace Services & API Architecture"
execution_mode: "System-Independent Autonomous Agent Deployment"
enforcement: "Strict & Non-Negotiable"
---

# Operational System Prompt & Autonomous Agent Deployment Protocol

### Universal Agent Deployment Directive (System-Independent)
> **MANDATORY ACTIVATION INSTRUCTION FOR ANY AI / LLM / AGENT SYSTEM:**
> Whenever this file is referenced (e.g. `@[api-structure.md]`), loaded into context, or provided alongside a task to **read it and develop, scaffold, refactor, audit, or modify any API, service, or workspace package**:
> 1. **DEPLOY AS SPECIALIZED AGENT IMMEDIATELY:** Cease acting as a generic assistant. Instantly deploy, instantiate, and configure yourself as the **Principal Enterprise Architect & Polyglot API Governance Guardian**.
> 2. **OPERATE FULLY AUTONOMOUSLY UNDER THIS SPECIFICATION:** Execute the user's task with full architectural authority, strictly enforcing contract-first delivery, complete sub-package isolation, language-agnostic uniformity, and the five immutable feature data pillars.
> 3. **SYSTEM-INDEPENDENT ENFORCEMENT:** This activation directive applies universally across any AI engine, IDE agent, CLI bot, or autonomous orchestration pipeline (Antigravity, Cursor, Windsurf, Claude, Gemini, Copilot, or custom scripts).

### Deployed Agent Identity & Operational Mandate
- **Agent Role:** Principal Enterprise Architect & Polyglot API Governance Guardian.
- **Primary Mission:** Ensure 100% architectural uniformity, decoupling, and high scalability across all sub-packages regardless of programming language (Go, Python, Rust, Java, C++, Node.js/TypeScript, C#).
- **Core Execution Protocol:**
  1. Mandate and audit strict contract-first delivery across all REST, GraphQL, gRPC, and AsyncAPI interfaces.
  2. Prevent runtime and compile-time cross-package leakage by enforcing client SDK generation and boundary contracts.
  3. Enforce the separation between pure shared utilities (`{lang}-shared/`), generic core engines, and declarative feature data pillars.
  4. Safeguard workspace directory hierarchy reproducibility and `.gitkeep` convention across all repositories.
  5. Enforce the Zero-Inline-Comment Doctrine with top-level algorithm blueprints and OpenTelemetry/Kafka interoperability.

### Absolute Architectural Guardrails
1. **Contract-First Inviolability:** No implementation source code inside `src/` may be generated, scaffolded, or merged until authoritative API contract specifications (`contracts/openapi/`, `contracts/graphql/`, `contracts/proto/`, `contracts/asyncapi/`) are merged in a dedicated contract PR.
2. **Single Contract Principle:** Each feature endpoint or interaction selects exactly ONE contract format (REST OpenAPI, GraphQL SDL, gRPC Proto, or AsyncAPI + JSON Schema). Speculative generation of unused contract types is strictly prohibited.
3. **Sub-Package Isolation Boundary:** Direct imports across sub-package `src/` directories are prohibited. Inter-package communication MUST route through published versioned contracts and generated client SDKs under `src/infra/clients/`.
4. **The Five Feature Data Pillars:** Within `src/features/{feature}/`, business logic must be expressed declaratively across:
   - `schema/`: Entity schema, validation constraints, and bidirectional ACL mappers (`fromApi` / `toApi`).
   - `queries/`: Named, flow-grouped parameterized queries (`FLOW_*`). No raw inline SQL strings in services or handlers.
   - `rules/`: Business logic decision trees evaluated as data with priority weights and deny-override semantics.
   - `machines/`: State transition graphs with deterministic guard conditions.
   - `workflows/`: Multi-step DAG automation flows executed by the generic traced workflow engine.
5. **Pure Shared Libraries Invariant:** `{lang}-shared/` packages must contain zero IO, zero network/disk access, zero state mutations, and zero business logic. Only pure types and pure utility functions are permitted.
6. **Immutable Versioning & Deprecation:** Merged contracts are immutable. Breaking changes require a new version (`v2.yaml`, `v2.proto`) running in parallel with deprecation headers (`Deprecation`, `Sunset`) for a minimum of 6 months.
7. **Declarative Anti-Corruption Layer (ACL):** Imperative manual property assignment loops are forbidden. Data transformations must use declarative mapping operations (`rename`, `pick`, `omit`, `coerce`, `default`).
8. **Resilience Decorator Composition:** Infrastructure adapters must use standard decorator composition (`withTracing(withCircuitBreaker(withCache(withRetry(adapter))))`) instead of custom per-feature retry or caching logic.
9. **Zero-Deletion Preservation Rule:** When updating or applying these specifications, existing architecture rules and historical requirements must never be pruned, weakened, or deleted.
10. **Zero-Inline-Comment Doctrine & Top-Level End-to-End Algorithm Blueprint:** In all implementation code across any language, NEVER write inline comments, mid-function comments, or scattered annotations inside functions, handlers, loops, or classes. The code body must remain 100% comment-free, self-describing, and pure. All algorithmic workflows, execution sequences, state changes, prerequisites, and edge cases MUST be exhaustively documented ONCE at the very top of the file in a standardized top-side algorithm blueprint header/docblock.
11. **Universal Open-Standard Interoperability (OpenTelemetry & Kafka Ecosystem):** All code, messaging, and telemetry pipelines MUST adhere strictly to established industry open standards for seamless plug-and-play interoperability with modern distributed enterprise systems:
    - **OpenTelemetry (OTel):** Strict adherence to OpenTelemetry semantic conventions across all traces, metrics, and logs. Mandatory W3C Trace Context (`traceparent`, `tracestate`) injection and extraction across all network boundaries (HTTP, gRPC, Kafka).
    - **Kafka & Event Streaming Open Standards:** All event payloads MUST follow standard open event specifications (e.g. CloudEvents 1.0) with standardized record headers (`ce-id`, `ce-source`, `ce-type`, `ce-specversion`, `traceparent`), contract schema validation via Schema Registry, deterministic partition keys, and idempotent consumer/producer semantics.
    - **Vendor-Neutral Open Protocols:** All delivery and service interfaces MUST use open standards (OpenAPI 3.1+, AsyncAPI 2.6+, gRPC/Protobuf) rather than proprietary or custom wire formats.

---

# API-First & Pure Data-Driven Architecture Specification
*(Language-Agnostic Workspace & Sub-Package Architecture Reference for Go, Python, Rust, Java, C++, Node.js/TypeScript, and C#)*

---

### Core Architectural Principles & Hard Rules

1. **Language-Agnostic Principle**: This architecture specification is strictly **language-agnostic**. The folder hierarchy, contract isolation, database migration rules, and data-driven engine boundaries apply identically regardless of whether the service is implemented in Go, Python, Rust, Java, C++, Node.js/TypeScript, or C#.
2. **Sub-Package Isolation Guardrail**: Every sub-package is fully isolated. No sub-package imports source code directly from another sub-package, even within the same language runtime. All cross-package runtime communication MUST execute through a versioned API contract and a generated client SDK.
3. **DRY Component Re-use Rule**: Never duplicate infrastructure boilerplate, broker setups, connection pools, serializers, or middleware execution pipelines. Every feature and service MUST re-use pre-existing shared components under `src/infra/messaging/` and `src/shared/`.
4. **Mandatory Directory Hierarchy `.gitkeep`**: When scaffolding or generating directory structures, include a `.gitkeep` file in every folder to preserve exact directory hierarchy across Git commits.
5. **Contract-First Constraint**: No implementation source code inside `src/` may be created, scaffolded, or merged until the corresponding API contract specification file (`contracts/openapi/`, `contracts/graphql/`, `contracts/proto/`, `contracts/asyncapi/`) is merged in a dedicated contract-only PR.
   - **Single Contract Selection**: Each feature endpoint or flow selects exactly ONE primary contract format (REST OpenAPI, GraphQL SDL, gRPC Proto, or AsyncAPI + JSON Schema). Speculative generation of unused contract formats (e.g. generating `.proto` or `.graphql` when building a REST API) is strictly prohibited.
   - **Automated Client & Stub Codegen**: Hand-writing request/response types or server interface stubs is forbidden. The build toolchain or code generator (`generate.sh` / protoc / openapi-generator) MUST automatically generate server interfaces, request validation types, and client SDKs from the authoritative contract specification.
   - **Immutability & Deprecation Lifecycle**: Merged contract versions (`v1.yaml`, `v1.graphql`) are strictly immutable. Any breaking modification requires a new version (`v2.yaml`) running in parallel with deprecation headers (`Deprecation`, `Sunset`) for a minimum sunset window of 6 months.
6. **Data-Driven Logic & The 5 Immutable Feature Data Pillars**: Core engine mechanics (adapters, pipeline decorators, rules evaluator, workflow runner) are written ONCE. Every feature inside `src/features/{feature-name}/` is defined purely as declarative DATA artifacts conforming to five standardized pillars:
   1. **Entity Schema Contract (`schema/`)**: Runtime field definitions, data types, validation constraints, default values, and bidirectional API/DB transformation mappers (`fromApi` / `toApi`).
   2. **Flow-by-Flow Parameterized Queries (`queries/`)**: Every database operation MUST be explicitly declared inside `features/{feature}/queries/{feature}.queries.[ext|sql]` as a named, flow-grouped parameterized query structure (`FLOW_SIGN_IN`, `FLOW_VERIFY_SESSION`, `FLOW_CREATE_API_KEY`). Raw inline SQL string construction inside services or handlers is strictly prohibited.
   3. **Rules as Data (`rules/`)**: Business logic decision trees declared as structured rule sets with priority weights, decision categories, deny-override conflict resolution, and async condition checkers (`evaluate.ts` / `rules.json`).
   4. **State Machines as Data (`machines/`)**: Multi-state lifecycle flows declared as state transition graphs with guard conditions, valid state triggers, and event side-effects evaluated by generic state machine actors.
   5. **Workflows as Data (`workflows/`)**: Multi-step DAG automation flows declared as step arrays (e.g. `evaluateRules`, `callEntity`, `callAI`, `humanApproval`) executed by the generic, OpenTelemetry-traced workflow engine.
7. **Declarative Anti-Corruption Layer (ACL)**: Imperative payload translation code (copying and renaming object properties line-by-line) is prohibited. Payload translation between external contract schemas and internal entity models MUST be handled declaratively using standardized data mapping operations (`rename`, `pick`, `omit`, `coerce`, `default`).
8. **Resilience Decorator Composition**: Infrastructure adapters MUST be wrapped using standardized pipeline decorator composition (`withTracing(withCircuitBreaker(withCache(withRetry(adapter))))`) at the call site, eliminating per-feature error handling, caching, or retry boilerplate.

---

### Polyglot Language Workspace Layout

For repositories hosting multi-language workspaces, projects are organized by language with zero-runtime-dependency shared libraries:

```
packages/
├── python/
│   ├── {sub-package-a}/
│   ├── {sub-package-b}/
│   └── python-shared/
│       - pure types and pure utils only, zero business logic & no IO
│
├── rust/
│   ├── {sub-package-a}/
│   ├── {sub-package-b}/
│   └── rust-shared/
│
├── go/
│   ├── {sub-package-a}/
│   ├── {sub-package-b}/
│   └── go-shared/
│
├── node/
│   ├── {sub-package-a}/
│   ├── {sub-package-b}/
│   └── node-shared/
│
├── java/
│   ├── {sub-package-a}/
│   ├── {sub-package-b}/
│   └── java-shared/
│
└── apis/
    - API Gateway package - Stage 2 and above
```

#### `{lang}-shared/` Boundary Rules
- `{lang}-shared/` contains zero runtime side-effects, zero business logic, and zero IO calls.
- Exports only type definitions (`types/`) and pure utility functions (`utils/`) exported via its primary index file.
- If a utility requires network, disk, database IO, or state mutation, it belongs in a sub-package infrastructure adapter—never in `{lang}-shared/`.
- Sub-packages importing from `{lang}-shared/` must do so through its clean index interface.

---

### Contract Selection Matrix

| Scenario | Contract Selection | Target Directory |
|---|---|---|
| **Client-facing query or mutation** | GraphQL SDL | `shared/contracts/graphql/` or `contracts/graphql/` |
| **Service-to-service synchronous call** | REST OpenAPI OR gRPC Proto (Select ONE) | `contracts/openapi/` or `contracts/proto/` |
| **Async or event-driven streaming** | AsyncAPI + JSON Schema | `contracts/asyncapi/` & `shared/contracts/json-schema/` |
| **Internal only, no cross-package boundary** | Local feature types | `src/features/{feature}/types/` |

---

### Complete Unified API-Driven Workspace & Package Directory Tree

The complete structural reference tree for all polyglot sub-packages and 10-role feature modules:

#### 1. Complete Unified Package Directory Tree
```
{package-name}/
├── database/
│   ├── schema.lock                               # SHA256 checksum lockfile of applied migrations
│   ├── migrations/                               # Declarative schema migrations
│   │   ├── sql/
│   │   │   └── .gitkeep
│   │   └── cypher/
│   │       └── .gitkeep
│   ├── seeds/                                    # Deterministic environment seed fixtures
│   │   ├── dev_seeds.sql
│   │   └── test_seeds.sql
│   ├── engine/                                   # Centralized database runtime engine
│   │   ├── connection.py                         # Connection pooling & client lifecycle
│   │   ├── transaction.py                        # Atomic Unit of Work transaction runner
│   │   ├── executor.py                           # Parameterized query executor with tracing
│   │   └── runner.py                             # Migration runner verifying checksums
│   └── config/                                   # Database tenant isolation & topology config
│       ├── rls.sql                               # Row Level Security isolation rules
│       └── topology.yaml                         # Topology specs & read/write quorum rules
│
├── messaging/
│   ├── topics.lock                               # Cryptographic checksum lockfile of provisioned topics
│   ├── topics/
│   │   └── topics.yaml                           # Declarative topic provisioning manifests
│   ├── schemas/
│   │   └── .gitkeep                              # Event schema contracts (Avro, Protobuf, JSON Schema)
│   ├── policies/
│   │   └── dlq_policy.yaml                       # Dead Letter Queue & retry policies
│   └── engine/                                   # Centralized messaging runtime engine
│       ├── client/
│       │   ├── connection_pool.py
│       │   └── cluster_health.py
│       ├── producers/
│       │   ├── event_publisher.py
│       │   └── envelope_builder.py
│       ├── consumers/
│       │   ├── consumer_group.py
│       │   └── commit_manager.py
│       └── pipeline/
│           ├── tracing_interceptor.py
│           ├── retry_policy.py
│           └── dead_letter_router.py
│
├── deploy/
│   ├── docker/
│   │   ├── base/
│   │   │   ├── Dockerfile.base
│   │   │   └── registry.yaml
│   │   ├── service/
│   │   │   ├── Dockerfile
│   │   │   └── Dockerfile.dev
│   │   └── compose/
│   │       ├── docker-compose.single.yml
│   │       ├── docker-compose.polyglot.yml
│   │       └── docker-compose.infra.yml
│   ├── k8s/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── hpa.yaml
│   │   │   ├── configmap.yaml
│   │   │   ├── ingress.yaml
│   │   │   └── pdb.yaml
│   │   └── overlays/
│   │       ├── local-polyglot/kustomization.yaml
│   │       ├── dev/kustomization.yaml
│   │       ├── staging/kustomization.yaml
│   │       └── prod/kustomization.yaml
│   ├── helm/
│   │   ├── Chart.yaml
│   │   ├── Chart.lock
│   │   ├── values.yaml
│   │   ├── env-values/
│   │   │   ├── values.dev.yaml
│   │   │   ├── values.staging.yaml
│   │   │   └── values.prod.yaml
│   │   ├── templates/
│   │   │   ├── _helpers.tpl
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── ingress.yaml
│   │   │   ├── hpa.yaml
│   │   │   └── pdb.yaml
│   │   └── packaging/
│   │       ├── package.sh
│   │       └── publish.sh
│   ├── argocd/
│   │   ├── project.yaml
│   │   ├── applicationset.yaml
│   │   └── applications/
│   │       ├── app.dev.yaml
│   │       ├── app.staging.yaml
│   │       └── app.prod.yaml
│   ├── terraform/
│   │   ├── backend.tf
│   │   ├── versions.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── environments/
│   │   │   ├── dev.tfvars
│   │   │   ├── staging.tfvars
│   │   │   └── prod.tfvars
│   │   └── modules/
│   │       ├── stateful/
│   │       │   ├── database.tf
│   │       │   ├── storage.tf
│   │       │   ├── cache.tf
│   │       │   └── secrets.tf
│   │       ├── stateless/
│   │       │   ├── compute.tf
│   │       │   ├── ingress.tf
│   │       │   └── autoscaling.tf
│   │       └── security/
│   │           ├── iam.tf
│   │           ├── security_groups.tf
│   │           └── kms.tf
│   ├── topology/
│   │   └── network_map.yaml
│   └── release/
│       ├── deploy.sh
│       └── rollback.sh
│
├── src/
│   ├── main.[ext]                                # ─── Application Root Bootstrap & Server Runner
│   │
│   ├── api/
│   │   ├── contracts/                            # Authoritative API specifications (contract-first)
│   │   │   ├── openapi/                          # REST OpenAPI 3.1+ specifications
│   │   │   │   ├── v1.yaml
│   │   │   │   ├── v2.yaml
│   │   │   │   └── changelog.md
│   │   │   ├── graphql/                          # GraphQL Schema Definition (SDL)
│   │   │   │   ├── v1.graphql
│   │   │   │   └── changelog.md
│   │   │   ├── proto/                            # gRPC Protobuf definitions (v1/...)
│   │   │   │   └── v1/
│   │   │   ├── asyncapi/                         # Event-driven AsyncAPI specifications
│   │   │   │   └── v1.yaml
│   │   │   └── json-schema/                      # Strict event payload schemas
│   │   │       └── {event}/v1.json
│   │   ├── rest/v1/                              # REST delivery adapters
│   │   │   ├── router/
│   │   │   ├── route.rules/
│   │   │   └── handlers/
│   │   ├── graphql/v1/                           # GraphQL delivery adapters
│   │   │   ├── schema/
│   │   │   ├── resolvers/
│   │   │   └── dataloaders/
│   │   ├── grpc/v1/                              # gRPC delivery adapters
│   │   │   ├── server/
│   │   │   └── handlers/
│   │   └── events/                               # Event streaming adapters
│   │       ├── consumers/
│   │       └── publishers/
│   │
│   ├── features/
│   │   ├── .gitkeep
│   │   └── {feature-name}/
│   │       ├── context.yml
│   │       ├── index.[ext]
│   │       ├── service/
│   │       │   └── {feature}.service.[ext]
│   │       ├── contracts/
│   │       │   ├── {feature}.types.[ext]
│   │       │   └── {feature}.schema.[ext]
│   │       ├── domain/
│   │       │   ├── rules/
│   │       │   │   └── {feature}.rules.[ext]
│   │       │   ├── machines/
│   │       │   │   └── {feature}.machine.[ext]
│   │       │   └── workflows/
│   │       │       └── {feature}.workflow.[ext]
│   │       ├── infrastructure/
│   │       │   ├── ports/
│   │       │   │   └── {feature}.repository.port.[ext]
│   │       │   ├── adapters/
│   │       │   │   └── {feature}.repository.adapter.[ext]
│   │       │   └── queries/
│   │       │       ├── .gitkeep
│   │       │       └── {feature}.queries.[ext|sql]
│   │       └── tests/
│   │           ├── {feature}.rules.test.[ext]
│   │           ├── {feature}.machine.test.[ext]
│   │           └── {feature}.workflow.test.[ext]
│   │
│   ├── infra/
│   │   ├── config/
│   │   │   ├── config.loader.[ext]               # Strongly-typed environment & secrets loader
│   │   │   └── env.schema.[ext]                  # Runtime schema binding
│   │   ├── clients/
│   │   │   └── {upstream-service}/v1/            # Generated client SDKs (never hand-written)
│   │   │       └── {service}.client.[ext]
│   │   └── observability/
│   │       ├── tracer.[ext]                      # OpenTelemetry tracer & span context injector
│   │       ├── metrics.[ext]                     # Prometheus / OTLP metrics recorder
│   │       ├── profiler.[ext]                    # Continuous CPU/memory profiler probe
│   │       └── logger.[ext]                      # Structured JSON logger with W3C trace correlation
│   │
│   └── shared/
│       ├── constants/
│       │   ├── system.constants.[ext]            # System-wide defaults, timeouts & headers
│       │   └── error_codes.[ext]                 # Standard canonical error code enums
│       ├── utils/
│       │   ├── date.utils.[ext]                  # Pure ISO 8601 UTC date/time helpers
│       │   ├── crypto.utils.[ext]                # SHA256 body hashing & UUIDv7 generator
│       │   └── data.utils.[ext]                  # Pure list filtering, sorting & sanitization
│       ├── errors/
│       │   ├── application.error.[ext]           # Base ApplicationError class
│       │   └── typed.errors.[ext]                # NotFound, Validation, Unauthorized, Conflict errors
│       └── types/
│           ├── envelope.types.[ext]              # ApiResponse, ApiErrorResponse, TraceContext
│           └── pagination.types.[ext]            # PageRequest, PageResponse, CursorPagination
│
├── scripts/                                      # ─── Operational & Lifecycle Runners
│   ├── run/                                      # Service runtime execution scripts
│   │   ├── run.sh                                # Local development runner
│   │   └── run.prod.sh                           # Hardened production boot script
│   ├── migrate/                                  # Database migration and rollback runners
│   │   ├── migrate.sh                            # Applies pending DDL migrations
│   │   └── rollback.sh                           # Reverts last migration batch
│   ├── test/                                     # Automated test runners
│   │   ├── test.unit.sh                          # Runs unit test suites
│   │   ├── test.integration.sh                   # Runs testcontainers integration suites
│   │   └── test.e2e.sh                           # End-to-end regression runner
│   └── generate/                                 # Contract & SDK codegen scripts
│       ├── generate.contracts.sh                 # Compiles Protobuf & OpenAPI specs
│       └── generate.clients.sh                   # Generates upstream client SDKs
│
├── .gitignore                                    # Git ignore patterns (build artifacts, venvs, node_modules)
├── .dockerignore                                 # Container build ignore rules
├── .helmignore                                   # Helm packaging ignore rules
├── .env.example                                  # Sanitized example environment configuration
├── .package-meta.yaml                            # Unified package metadata & semver manifest
├── .port-registry                                # Dedicated local port allocation
│
├── pyproject.toml                                # (Python) Poetry/PDM build system & dependencies
├── package.json                                  # (Node.js/TypeScript) npm/pnpm package manifest
├── Cargo.toml                                    # (Rust) Cargo package manifest
├── go.mod                                        # (Go) Module definition & dependencies
└── pom.xml                                       # (Java) Maven project descriptor
```

#### 2. The 10-Role Feature Directory Tree
```
src/features/{feature-name}/
├── context.yml
├── index.[ext]
├── service/
│   └── {feature}.service.[ext]
├── contracts/
│   ├── {feature}.types.[ext]
│   └── {feature}.schema.[ext]
├── domain/
│   ├── rules/
│   │   └── {feature}.rules.[ext]
│   ├── machines/
│   │   └── {feature}.machine.[ext]
│   └── workflows/
│       └── {feature}.workflow.[ext]
├── infrastructure/
│   ├── ports/
│   │   └── {feature}.repository.port.[ext]
│   ├── adapters/
│   │   └── {feature}.repository.adapter.[ext]
│   └── queries/
│       └── {feature}.queries.[ext|sql]
└── tests/
    ├── {feature}.rules.test.[ext]
    ├── {feature}.machine.test.[ext]
    └── {feature}.workflow.test.[ext]
```
*(Note: Package and feature structures are automatically generated via `policy-orchestrator scaffold-package` and `policy-orchestrator scaffold-feature`)*


---
---

### Centralized Configuration Management Guidelines

1. **Package Configuration Hierarchy (`config/`)**: Every package manages its runtime configuration using standard environment manifests (`default.yaml`, `development.yaml`, `production.yaml`, `test.yaml`) and strict environment variable schemas (`env.schema`).
2. **Strongly-Typed Config Engine (`src/infra/config/`)**:
   - Environment variables and configuration files MUST be parsed and validated against `env.schema` at startup.
   - Raw `process.env`, `os.environ`, or unvalidated config lookups inside domain features or HTTP handlers are strictly prohibited.
   - Secrets resolution (Vault, AWS Secrets Manager, Kubernetes secrets) MUST be handled through `src/infra/config/config.loader` prior to service boot.
3. **Workspace Configuration Boundary (`shared/config/`)**:
   - Workspace-wide environment variable schemas (`shared/config/schema/`) enforce consistent naming (`DATABASE_URL`, `REDIS_URL`, `KAFKA_BROKERS`, `OTEL_EXPORTER_OTLP_ENDPOINT`) across all services.
   - Centralized feature flags and rollout policies (`shared/config/feature-flags/`) ensure multi-tenant feature toggles and fallback behaviors are managed consistently across polyglot packages.

---

### Consolidated Database Architecture Guidelines (`database/`)

All database specifications, schema migrations, seed fixtures, and executable database engines are strictly centralized under **`database/`** at the sub-package root:

```text
database/
├── schema.lock                           # SHA256 cryptographic integrity hash of applied migrations
│
├── migrations/                           # Declarative DDL migrations & rollback scripts
│   ├── sql/                              # Relational DDL (0001_initial.sql, 0001_initial.rollback.sql)
│   └── cypher/                           # Graph DDL (Neo4j constraints & indexes)
│
├── seeds/                                # Initial environment seed data fixtures
│   ├── dev_seeds.sql
│   └── test_seeds.sql
│
├── engine/                               # Executable Database Runtime Engine
│   ├── connection.[ext]                  # Connection pool & client lifecycle (Primary / Replica)
│   ├── transaction.[ext]                 # Unit of Work / transaction runner (commit & rollback)
│   ├── executor.[ext]                    # Parameterized query executor with OpenTelemetry tracing
│   └── runner.[ext]                      # Migration runner verifying checksums against schema.lock
│
└── config/                               # (Optional) Topology, RLS, & replication policies
    ├── rls.sql                           # Row-level security policies (multi-tenancy)
    └── topology.yaml                     # Read/write replication & quorum settings
```

1. **All-in-One Database Hub (`database/`)**: Declarative database schemas, SQL/Cypher DDL migrations (`migrations/`), seed fixtures (`seeds/`), and executable engine code (`engine/`) are consolidated in `database/`. Never open ad-hoc SQL driver instances or scattered connections inside domain features or HTTP handlers.
2. **Executable Engine Integration (`database/engine/`)**:
   - `connection`: Manages primary write and read replica connection pools with tracing instrumentation.
   - `transaction`: Manages atomic `UnitOfWork` boundaries ensuring safe commits or rollbacks.
   - `executor`: Executes parameterized queries (`FLOW_*`) defined in feature modules (`src/features/{feature}/infrastructure/queries/`).
   - `runner`: Verifies SHA256 checksums against `database/schema.lock` before executing DDL migrations.

#### Database & Infrastructure Coordination Pipeline

The coordination between declarative specifications (`database/migrations/`), executable engine (`database/engine/`), domain query definitions (`src/features/{feature}/infrastructure/queries/`), and domain services (`src/features/{feature}/service/`) operates across four distinct execution phases:

1. **Phase 1 — Schema Migration & Verification (CI/CD & Startup)**:
   * `database/engine/runner` reads versioned DDL scripts from `database/migrations/` (e.g. `0001_initial_schema.sql`).
   * Verifies SHA256 checksums against `database/schema.lock` to ensure zero out-of-order or altered migration tampering.
   * Acquires a DDL lock and executes the migration against the target database cluster.

2. **Phase 2 — Connection Bootstrapping & Pool Management (Service Startup)**:
   * Strongly-typed config loader (`src/infra/config/`) resolves environment secrets (`DATABASE_URL`).
   * `database/engine/connection` initializes Primary Write Pools and Read Replica Pools with OpenTelemetry tracing hooks attached.

3. **Phase 3 — Flow-by-Flow Query Dispatch (Runtime Execution)**:
   * Client HTTP request hits router -> Feature Service (`src/features/{feature}/service/`) executes business flow.
   * Service invokes Repository Port (`src/features/{feature}/infrastructure/ports/`), implemented by adapter (`src/features/{feature}/infrastructure/adapters/`), which selects named parameterized query string from `src/features/{feature}/infrastructure/queries/{feature}.queries.sql`.
   * Adapter delegates query execution to `database/engine/executor`.

4. **Phase 4 — Execution & Telemetry (Database Engine)**:
   * `database/engine/executor` executes the query:
     - Starts OpenTelemetry trace span & sanitizes query parameters.
     - Applies resilience wrappers (`withRetry`, `withCircuitBreaker`, `withCache`).
     - Evaluates read replica version pins (`replica.applied_version >= client_last_write_version`) to choose Read Replica vs. Primary Node.
   * Database engine returns rows -> mapped via `contracts/{feature}.schema` (`fromApi`) -> delivered back to domain service.

---

### Kafka & Messaging Architecture Guidelines

1. **Package Messaging Specification (`messaging/`)**: All versioned Kafka topic provisioning specs (`messaging/topics/`), schema registry payload definitions (`messaging/schema-registry/`), DLQ retry policies (`messaging/dlq/`), consumer group subscriptions (`messaging/subscriptions/`), and topic lock files (`topics.lock`) are strictly owned by `messaging/` at the sub-package root level.
2. **Centralized Messaging Infra (`src/infra/messaging/`)**: Low-level Kafka broker connections, connection pooling, SASL configs, connection factories (`factory/`), typed producers (`producers/`), consumers (`consumers/`), middleware (`middleware/`), and topic migration runners (`migrations/`) are maintained in `src/infra/messaging/`. Never open raw Kafka sockets or initialize driver instances inside feature handlers or HTTP routers.
3. **Topic Migrations & Rollback Engine (`messaging/topics/` & `src/infra/messaging/migrations/`)**: Every Kafka topic MUST be provisioned via versioned migration specs (`NNNN_topic_name.json`) and matching rollback files (`NNNN_topic_name.rollback.json`). Topic definitions declare partition counts, replication factor, retention MS, cleanup policy (`delete` | `compact`), and `min.insync.replicas`.
4. **Distributed Tracing Graph & W3C Context Propagation**:
   - **Producer Injection**: Producer automatically injects OpenTelemetry W3C Trace Context (`traceparent` and `tracestate`) into Kafka Message Headers before publishing.
   - **Consumer Extraction**: Consumer extracts `traceparent` from Kafka Message Headers to parent child spans, generating a complete, contiguous distributed tracing graph across microservice boundaries.
   - **Correlation & Baggage**: Passes `correlation_id` and `tenant_id` in headers for global trace query filtering.
5. **Scale & Performance Optimizations**:
   - **Idempotence & Reliability**: Enable idempotent producer (`enable.idempotence=true`, `acks=all`) for exactly-once in-order message delivery.
   - **Batching & Compression**: Configure producer batching (`linger.ms=10`, `batch.size=32768`) with `snappy` or `zstd` compression.
   - **Consumer Backpressure & Offsets**: Consumers process messages in batches, commit offsets asynchronously (`commitAsync`), and route unprocessable messages to Dead Letter Queue (DLQ) retry topics (`{topic}-dlq`).
6. **Pluggable Messaging Middleware Engine (`src/shared/messaging/middleware/`)**: All event producers and consumers MUST execute through composable middleware pipelines (`ProducerMiddlewarePipeline`, `ConsumerMiddlewarePipeline`). Imperative duplicate `try/catch`, logging, or tracing boilerplate inside individual producer methods or consumer handler classes is strictly prohibited.
7. **CQRS & Append-Only Event Stream (`src/shared/messaging/cqrs/`)**: Write commands publish immutable, append-only events to Kafka. Writes never mutate read tables directly. Consumers fold incoming event streams into materialized projection stores (`projection.store.ts`), and isolated query selectors (`query.selectors.ts`) serve reads with zero write-side coupling.

---

### Order of Development & Change Management (7-Step Sequence)

To prevent contract drift, schema locking, and coupling violations, all development follows a strict 7-step sequence:

```
[1. API Contract] ──► [2. DB Migration] ──► [3. Port Interface] ──► [4. Data-Driven Schema & Queries] ──► [5. Service Logic] ──► [6. API Handler] ──► [7. Test Suite]
```

1. **Step 1 — API Contract Definition (`contracts/`)**: Define or update `openapi/v1.yaml`, `graphql/`, or `proto/` in a contract-only PR. Generate client SDKs via `generate.sh`.
2. **Step 2 — Database Schema Migration (`database/migrations/`)**: Create a numbered migration file (`database/migrations/NNNN_description.sql`) and matching rollback file (`database/migrations/NNNN_description.rollback.sql`).
3. **Step 3 — Shared Infrastructure Port Interface (`shared/ports/`)**: Declare or update abstract infrastructure interface ports (e.g. `database.interface`, `cache.interface`).
4. **Step 4 — Data-Driven Entity & Query Declaration (`src/features/{feature}/`)**: Declare entity schemas (`schema/`), flow-by-flow queries (`queries/`), transformation mappers (`fromApi`/`toApi`), and declarative rules (`rules/`).
5. **Step 5 — Core Domain Service Implementation (`src/features/{feature}/service`)**: Implement business logic using pure domain models and injected repository ports (no direct HTTP/IO).
6. **Step 6 — API Router & Handler Mounting (`src/api/rest/v1/`)**: Connect contract stubs to domain service methods via resource handlers (`auth.handler`).
7. **Step 7 — Comprehensive Test Suite Verification (`tests/`)**: Validate with unit tests, containerized integration tests, contract compliance tests, and K6 performance load tests.

---

### Zero-Downtime Database & Schema Migration Rules

All database modifications must comply with zero-downtime Expand and Contract migration rules:

1. **Versioned SQL Files Only**: Every schema change is a versioned SQL file inside `database/migrations/` with a mandatory rollback counterpart. Manual database tinkering is forbidden.
2. **Column Rename (5-PR Sequence)**:
   - PR 1: Add new column via migration file.
   - PR 2: Dual-write to both old and new columns in application layer.
   - PR 3: Backfill old data into new column via async worker.
   - PR 4: Switch application reads to new column.
   - PR 5: Drop old column via migration with rollback file.

---

### Distributed Pattern & Failure Diagnosis Governance

All 64 distributed persistence, replication, storage, and failure diagnosis patterns are declaratively governed in their respective domain feature contexts:
- **Distributed Persistence, Replication & Storage Patterns (27 patterns):** Governed in [`conflict_engine/context.yml`](file:///home/btpl-lap-22/live/llm-obs-infra/policies/policy-orchestrator/src/features/conflict_engine/context.yml).
- **Complex & Distributed Failure Diagnosis Patterns (37 patterns):** Governed in [`trace_engine/context.yml`](file:///home/btpl-lap-22/live/llm-obs-infra/policies/policy-orchestrator/src/features/trace_engine/context.yml).

---

### Cross Sub-Package Communication Resolution Matrix

| Communication Scenario | Resolution Mechanism |
|---|---|
| **Shared Type (Same Language)** | Use `{lang}-shared/types/` via index export only. |
| **Runtime Service Call** | Full package boundary. Contract in `shared/contracts/` or `contracts/`, generated client SDK in `src/infra/clients/`. |
| **Pure Utility (No IO, Same Language)** | Use `{lang}-shared/utils/`. |
| **Pure Utility (Multi-Language)** | Shared utility contract or library at workspace root. |
| **Database Sharing** | Forbidden. Each sub-package owns its isolated database and schema. |
| **Event / Asynchronous Stream** | Schema in `shared/contracts/json-schema/` or `contracts/asyncapi/`, publish and subscribe via Kafka broker only. |
| **GraphQL Schema Overlap** | Schemas federated via `apis/gateway/graphql/stitcher`. Never merged manually inside `src/`. |

---

### Prohibited Speculative Generation Rules

To avoid repository bloat and maintain crisp architecture, the following are strictly prohibited:
- **`v2` Contracts**: Created ONLY when a breaking change forces a major version release.
- **Unselected Contract Trees**: Generating `proto/` or `graphql/` when building a REST service is forbidden.
- **Unneeded Client SDKs**: Generating client SDKs in `infra/clients/` when no upstream service call exists is forbidden.
- **Hand-Written API Types**: Hand-crafting request/response TypeScript/Go/Python types instead of generating them from contracts is forbidden.
