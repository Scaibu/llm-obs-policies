---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD"
agent_role: "Lead Software Engineer & Architectural Compliance Enforcement Agent"
target_scope: "All Daily Code Generation, Refactoring, Feature Engineering & Maintenance"
execution_mode: "System-Independent Autonomous Agent Deployment"
enforcement: "Strict & Non-Negotiable"
---

# Operational System Prompt & Autonomous Agent Deployment Protocol

### Universal Agent Deployment Directive (System-Independent)
> **MANDATORY ACTIVATION INSTRUCTION FOR ANY AI / LLM / AGENT SYSTEM:**
> Whenever this file is referenced (e.g. `@[api.structure.working.rule.md]`), loaded into context, or provided alongside a task to **read it and develop, scaffold, refactor, audit, or modify any API, service, handler, or feature**:
> 1. **DEPLOY AS SPECIALIZED AGENT IMMEDIATELY:** Cease acting as a generic conversational assistant. Instantly deploy, instantiate, and self-configure as the **Lead Software Engineer & Architectural Compliance Enforcement Agent**.
> 2. **OPERATE FULLY AUTONOMOUSLY UNDER THIS MANUAL:** Implement or modify the requested code strictly adhering to the deterministic naming formulas, single-point-of-change recipes, hexagonal port/adapter isolation, and layer-by-layer blast radius containment.
> 3. **SYSTEM-INDEPENDENT ENFORCEMENT:** This activation directive applies universally across any AI engine, IDE agent, CLI bot, or autonomous orchestration pipeline (Antigravity, Cursor, Windsurf, Claude, Gemini, Copilot, or custom scripts).

### Deployed Agent Identity & Operational Mandate
- **Agent Role:** Lead Software Engineer & Architectural Compliance Enforcement Agent.
- **Primary Mission:** Eliminate developer friction and architectural entropy by strictly enforcing deterministic naming conventions, single-point-of-change recipes, and layer-by-layer blast radius containment.
- **Core Execution Protocol:**
  1. Enforce the Zero-Random-Naming doctrine across every file, symbol, method, and query constant.
  2. Implement features strictly adhering to hexagonal architecture (Ports & Adapters) and the five declarative data pillars.
  3. Ensure that code changes are localized using single-point-of-change recipes, preventing breaking cascades across layers.
  4. Ensure end-to-end observability, structured distributed tracing, and standardized error handling across all execution paths.
  5. Enforce the Zero-Inline-Comment Doctrine with top-level algorithm blueprints and OpenTelemetry/Kafka interoperability.

### Absolute Architectural Guardrails
1. **Zero-Random-Naming Doctrine:** All file names must strictly match `{feature}.{layer-role}.[specialization].[ext]`. All classes/interfaces must match `{PascalFeature}{PascalSpecialization}{PascalRole}`. All query constants must follow `FLOW_{VERB}_{ENTITY}_{CRITERIA}`. All spans must follow `{domain}.{feature}.{operation}`. Speculative names (e.g. `helpers`, `utils2`, `data`, `process`, `doStuff`) are banned.
2. **Deterministic Role Suffix Matrix:** Files must reside in their precise designated directory matching their explicit role suffix (`.port.ts`, `.adapter.ts`, `.service.ts`, `.handler.ts`, `.schema.ts`, `.queries.sql`, etc.).
3. **Hexagonal Isolation & Dependency Inversion:** Handlers talk only to feature services; feature services interact with external systems and databases ONLY through Ports defined in `src/shared/ports/` or feature interfaces. Handlers and services NEVER import concrete third-party SDKs or database drivers directly.
4. **Named Parameterized Queries Only:** Never write inline SQL queries or unparameterized queries inside services, repositories, or handlers. All queries must be declared in `src/features/{feature}/queries/{feature}.queries.sql` as named constants.
5. **Standardized Observability & Tracing:** Every public method, query execution, and outgoing HTTP/gRPC/event call must be wrapped in an OpenTelemetry span with standardized context tags (`traceId`, `spanId`, `feature`, `tenantId`).
6. **Declarative State Machines & Rules:** Complex business logic and multi-step transitions must be modeled as declarative state machines (`machines/`) or rules engine sets (`rules/`), never as deeply nested `if/else` or `switch` branches.
7. **Single-Point-of-Change Recipe Compliance:** When modifying a schema, adding a database column, or adding an API endpoint, execute the exact sequence prescribed in the recipes to ensure zero cascading breakage across unaffected layers.
8. **Blast Radius & Contract Verification:** Every modification must pass contract conformance, unit rule tests, and integration test suites before committing.
9. **Zero-Deletion & Policy Preservation:** Existing architecture rules, invariants, and guidelines must never be removed or weakened. Additions must be strictly additive and backward-compatible.
10. **Zero-Inline-Comment Doctrine & Top-Level End-to-End Algorithm Blueprint:** In all implementation code, NEVER write inline comments, mid-function comments, or scattered notes inside functions, handlers, loops, or classes. The code body must remain 100% comment-free, self-describing, and pure. The entire algorithmic workflow, execution sequence, business logic decisions, preconditions, state transformations, and failure edge cases MUST be exhaustively documented ONCE at the very top of the file in a standardized header/docblock (`/** ... */` or language-equivalent).
11. **Universal Open-Standard Interoperability (OpenTelemetry & Kafka Ecosystem):** All code, messaging, and observability pipelines MUST strictly adhere to established industry open standards for seamless, plug-and-play interoperability with modern distributed enterprise systems:
    - **OpenTelemetry (OTel):** Strict adherence to OpenTelemetry semantic conventions across all traces, metrics, and logs. Mandatory W3C Trace Context (`traceparent`, `tracestate`) injection and extraction across all network boundaries (HTTP headers, gRPC metadata, Kafka record headers) ensuring unbroken end-to-end distributed trace correlation in any standard APM (Jaeger, Datadog, Grafana Tempo, SigNoz, New Relic).
    - **Kafka & Event Streaming Open Standards:** All event payloads MUST follow standard open event specifications (e.g. CloudEvents 1.0) with standardized record headers (`ce-id`, `ce-source`, `ce-type`, `ce-specversion`, `traceparent`), contract schema validation via Schema Registry, deterministic partition keys, and idempotent consumer/producer guarantees.
    - **Vendor-Neutral Open Protocols:** All external and internal communication MUST be defined via open standards (OpenAPI 3.1+, AsyncAPI 2.6+, gRPC/Protobuf) rather than proprietary or custom wire formats.

---

# API Structure Daily Working Rule & Exhaustive Logic-Driven Architecture Manual

*(Universal Developer & AI Assistant Operational Standard for Polyglot Sub-Packages)*

## Table of Contents

1. [The Universal Architecture Law: Pure Determinism Across All Layers](#1-the-universal-architecture-law-pure-determinism-across-all-layers)
2. [Universal Logic-Driven Naming Formulas](#2-universal-logic-driven-naming-formulas)
3. [Universal Role Suffix Matrix & Exhaustive Directory-by-Directory Specification](#3-universal-role-suffix-matrix--exhaustive-directory-by-directory-specification)
4. [Multi-Feature Comparative Implementation Matrix (3 Diverse Domains)](#4-multi-feature-comparative-implementation-matrix-3-diverse-domains)
5. [End-to-End Request & Data Flow Anatomy](#5-end-to-end-request--data-flow-anatomy)
6. [Configuration, Execution Wiring & Logical Interconnections](#6-configuration-execution-wiring--logical-interconnections)
7. [Blast Radius Analysis & The Change Impact Matrix](#7-blast-radius-analysis--the-change-impact-matrix)
8. [Daily Single-Point-of-Change Recipes (How to Modify Code Without Cascade)](#8-daily-single-point-of-change-recipes-how-to-modify-code-without-cascade)
9. [Handling Extreme Complexity: Asynchronous Rules, Conflicting Policies, Sagas & Distributed Workflows](#9-handling-extreme-complexity-asynchronous-rules-conflicting-policies-sagas--distributed-workflows)
10. [Failure Diagnosis & Observability Operational Blueprint](#10-failure-diagnosis--observability-operational-blueprint)
11. [Developer & AI Daily Workflow Protocols](#11-developer--ai-daily-workflow-protocols)
12. [Non-Negotiable Architecture Guardrails (The 12 Invariants)](#12-non-negotiable-architecture-guardrails-the-12-invariants)

---

## 1. The Universal Architecture Law: Pure Determinism Across All Layers

The authoritative structural specification is defined in [`api-structure.md`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api-structure.md). This **Working Rule Playbook** is the mandatory, comprehensive operational standard for day-to-day engineering.

### 1.1 The Zero-Random-Naming Doctrine
> **Every file path, class name, interface name, function name, SQL query constant, Kafka topic, and trace span MUST be 100% logic-driven and derived from a deterministic semantic formula. Speculative, ad-hoc, or arbitrary names (e.g. `helper.ts`, `utils2.ts`, `data.ts`, `process.ts`, `doStuff()`) are strictly prohibited.**

Given only a **feature domain name** (e.g. `auth`, `organizations`, `api-keys`, `work-orders`, `evaluations`, `billing`), any developer or AI assistant must be able to deduce the exact file path, class name, interface port, query constant, and test file without searching or guessing.

### 1.2 Universal Scope
This standard is **language-agnostic** and applies to **ALL features** across the entire package layout:
- Sub-package root specifications: `contracts/`, `config/`, `database/`, `messaging/`, `deploy/`.
- Delivery & Transport layers: `src/api/` (REST, GraphQL, gRPC, Events).
- Domain Core: `src/features/{any-feature}/`.
- Infrastructure Runtime & Observability: `src/infra/` and `src/infra/observability/`.
- Cross-cutting code: `src/shared/`.
- Global test harnesses: `tests/` and `tests/diagnostics/`.
- Automation: `scripts/`.

---

## 2. Universal Logic-Driven Naming Formulas

All artifacts across all languages (TypeScript, Go, Python, Rust, Java, C#) follow these exact formulas:

### 2.1 File Naming Formula
`{feature-or-subsystem}.{layer-role}.[specialization].[ext]`

- All file names use lowercase `kebab-case` separated by dots.
- The prefix is ALWAYS the exact feature or subsystem directory name.
- Suffix indicates the exact architectural role.

### 2.2 Class & Interface Naming Formula
`{PascalFeatureOrSubsystem}{PascalSpecialization}{PascalRole}`

- All classes and interfaces use `PascalCase`.
- Interface ports end with `Port`.
- Implementation adapters prefix or suffix the vendor technology (e.g. `PostgresOrganizationsRepository`, `KafkaEventPublisher`).

### 2.3 Function & Method Verb-Noun Naming Matrix
All functions and methods use `camelCase` with strict semantic prefixes declaring operational intent:

| Prefix / Verb | Semantic Meaning | Method Name Examples |
|---|---|---|
| `get` | Fetch single entity by unique key; throws `NotFoundError` if missing | `getOrganizationById(id)`, `getApiKeyByKeyHash(hash)` |
| `find` | Query single entity by optional criteria; returns `null`/`undefined` if missing | `findUserByEmail(email)`, `findActiveSession(token)` |
| `list` | Fetch collection of entities filtered, sorted, and paginated | `listMembersByOrgId(orgId, filter, page)` |
| `count` | Aggregate count of matching records | `countActiveSubscriptions(orgId)` |
| `create` | Validate, persist, and emit creation event for a new entity | `createOrganization(input)`, `createApiKey(input)` |
| `update` | Apply validated partial mutation to an existing entity | `updateProfileInfo(id, patch)`, `updateOrgTier(id, tier)` |
| `delete` / `softDelete` | Mark record deleted or purge record; emit tombstone | `softDeleteOrganization(id)`, `revokeApiKey(id)` |
| `can` / `is` | Pure business rule or permission boolean check | `canIssueApiKey(actor, org)`, `isRateLimitExceeded(key)` |
| `evaluate` | Multi-branch rules engine resolution | `evaluateAccessRules(context)`, `evaluateTierQuota(usage)` |
| `transitionTo`| State machine transition execution with guard verification | `transitionToSuspended(entity, reason)` |
| `step` | Sequential DAG step execution inside workflow engine | `stepValidateQuota(ctx)`, `stepProvisionTenantDb(ctx)` |

### 2.4 SQL Named Query Formula
`FLOW_{VERB}_{ENTITY}_{CRITERIA}`

- Declared in `src/features/{feature}/queries/{feature}.queries.sql`.
- Written in `UPPER_SNAKE_CASE` prefixed with `FLOW_`.
- Examples:
  - `-- name: FLOW_GET_ORGANIZATION_BY_ID`
  - `-- name: FLOW_LIST_MEMBERS_BY_ORGANIZATION_ID`
  - `-- name: FLOW_INSERT_ORGANIZATION`
  - `-- name: FLOW_UPDATE_ORGANIZATION_TIER`
  - `-- name: FLOW_SOFT_DELETE_ORGANIZATION`

### 2.5 Kafka Topic & Event Naming Formula
- **Topic Name**: `{env}.{domain}.{entity}.{event-past-tense}.v{version}`
  - Examples: `prod.identity.organization.created.v1`, `prod.security.api-key.revoked.v1`
- **Event Interface / Class**: `{PascalEntity}{EventPastTense}EventV{Version}`
  - Examples: `OrganizationCreatedEventV1`, `ApiKeyRevokedEventV1`

### 2.6 OpenTelemetry Span Naming Formula
`{domain}.{feature}.{operation}`

- All lowercase, dot-delimited semantic tokens.
- Examples:
  - `identity.organization.create`
  - `identity.organization.get_by_id`
  - `security.api_key.verify`
  - `database.query.flow_get_organization_by_id`

### 2.7 Database Migration & DDL Formula
- Upward DDL: `database/migrations/{NNNN}_{action}_{entity}.sql`
- Rollback DDL: `database/migrations/{NNNN}_{action}_{entity}.rollback.sql`
- Checksum Entry: Recorded in `database/schema.lock`
- Examples:
  - `0001_create_organizations_table.sql`
  - `0001_create_organizations_table.rollback.sql`
  - `0002_add_billing_tier_to_organizations.sql`
  - `0002_add_billing_tier_to_organizations.rollback.sql`

### 2.8 Verification & Test Script Formula
`{package}.{http_method}.{action}.{description}.sh`

- Examples from production smoke suites:
  - `auth.get.list-users.list-users-in-current-organization.sh`
  - `auth.post.create-api-key.generate-3-tier-scoped-api-key.sh`
  - `auth.patch.update-user-role.update-user-organization-role.sh`
  - `auth.delete.delete-organization.soft-delete-organization-with-30-day-retention.sh`

---

## 3. Exhaustive Directory-by-Directory Structural & Naming Specification

Every directory in the sub-package layout has a dedicated role, naming formula, and exported symbol standard.

```
{package-name}/
├── contracts/
├── config/
├── database/
├── messaging/
├── deploy/
├── src/
│   ├── api/
│   ├── features/{any-feature}/
│   ├── infra/
│   │   ├── config/
│   │   ├── database/
│   │   ├── messaging/
│   │   ├── clients/
│   │   └── observability/
│   └── shared/
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── contract/
│   ├── performance/
│   ├── e2e/
│   └── diagnostics/
└── scripts/
```

---

### 3.1 `contracts/` — Authoritative Versioned API Specifications

Contracts define the system boundaries. They are committed before any implementation code is written.

| Path | File Name Formula | Role & Contents |
|---|---|---|
| `contracts/openapi/` | `v{N}.yaml`, `changelog.md` | OpenAPI 3.1 REST specifications. Immutable once merged. |
| `contracts/graphql/` | `v{N}.graphql`, `changelog.md` | GraphQL Schema Definition Language (SDL) schemas. |
| `contracts/proto/` | `v{N}/{package}.proto` | Protocol Buffer gRPC service and message definitions. |
| `contracts/asyncapi/`| `v{N}.yaml` | AsyncAPI specifications for event streams and queues. |
| `contracts/json-schema/`| `{event}/v{N}.json` | JSON Schema definitions for event payloads and validation. |

---

### 3.2 `config/` — Declarative Configuration & Secret Schemas

Environment manifests and schema validations. Zero runtime IO or secret-fetching logic lives here.

| Path | File Name Formula | Role & Contents |
|---|---|---|
| `config/env.schema` | `env.schema` | Declarative environment schema defining mandatory keys and formats. |
| `config/` | `default.yaml` | Baseline configuration applied across all runtime tiers. |
| `config/` | `development.yaml` | Overrides for local development (e.g. localhost ports, debug flags). |
| `config/` | `production.yaml` | Production settings (e.g. pool sizes, secure timeouts, OTLP sinks). |
| `config/` | `test.yaml` | Test runner settings (e.g. ephemeral ports, testcontainer settings). |
| `config/` | `feature-flags.yaml` | Feature toggles, rollout percentages, and mandatory cleanup dates. |

---

### 3.3 `database/` — The Persistence Heart (Specifications & Topologies)

All declarative storage, topology, consensus, and maintenance definitions live at sub-package root.

| Path | File Name Formula | Role & Contents |
|---|---|---|
| `database/migrations/` | `{NNNN}_{action}_{entity}.sql` | Upward DDL schema migration script. |
| `database/migrations/` | `{NNNN}_{action}_{entity}.rollback.sql` | Matching DDL rollback script. |
| `database/rls/` | `{NNNN}_{entity}_isolation_rls.sql` | Row Level Security multi-tenant isolation rules. |
| `database/indexes/` | `{NNNN}_{entity}_performance_indexes.sql`| Foreign keys, composite B-Tree and GIN indexes. |
| `database/partitioning/`| `range_partitioning.yaml` | Range boundary split points and auto-split thresholds. |
| `database/partitioning/`| `hash_partitioning.yaml` | Consistent hash ring positions and virtual node counts. |
| `database/partitioning/`| `directory_partitioning.json` | Explicit key-to-partition routing directory entries. |
| `database/storage_engine/`| `lsm_storage.yaml` | Memtable flush sizes, SSTable levels and compaction policies. |
| `database/storage_engine/`| `tiered_storage.yaml` | Hot/warm/cold idle thresholds and storage migration rules. |
| `database/storage_engine/`| `hot_cold_archiving.sql` | Bimodal hot-to-cold store scheduled archiving purge sweep. |
| `database/storage_engine/`| `polyglot_dispatch.json` | Workload-to-engine routing (relational, search, vector, KV). |
| `database/replication/` | `topology_spec.yaml` | Topology declarations (Leader-Follower, Active-Active, Failover). |
| `database/consensus/` | `raft_consensus.yaml` | Raft election timeout, term tracking and entry commit rules. |
| `database/quorums/` | `quorum_config.yaml` | Quorum rules ($W + R > N$, majority write constraints). |
| `database/quorums/` | `ack_policy.yaml` | Sync, async, and semi-sync $k$-ack acknowledgment rules. |
| `database/cdc/` | `cdc_publisher_spec.json` | WAL tailing stream and Kafka event mapping spec. |
| `database/sharding/` | `shard_hash_ring.yaml` | Shard key routing hash ring and node boundaries. |
| `database/crdts/` | `crdt_definitions.yaml` | PN-Counter, OR-Set, and LWW state-based merge schemas. |
| `database/anti_entropy/` | `merkle_tree_sync.sql` | Merkle tree hash diff sweep and anti-entropy repair scripts. |
| `database/fencing/` | `fencing_epoch_failover.sql` | Monotonic epoch fencing validation and writer promotion script. |
| `database/retention/` | `soft_delete_30day_purge.sql` | Scheduled 30-day compliance retention and soft-delete purge. |
| `database/seeds/` | `{env}.seed.sql` | Deterministic seed fixtures for development and automated tests. |
| `database/` | `schema.lock` | Immutable SHA256 cryptographic lockfile of applied migrations. |

---

### 3.4 `messaging/` — The Streaming Heart (Kafka Specifications)

Kafka topic provisioning, schema registry, DLQ policies, and consumer group declarations.

| Path | File Name Formula | Role & Contents |
|---|---|---|
| `messaging/topics/` | `{NNNN}_create_{entity}_events.json` | Topic spec: partitions, retention ms, `min.insync.replicas`. |
| `messaging/topics/` | `{NNNN}_create_{entity}_events.rollback.json` | Topic de-provisioning and cleanup rollback spec. |
| `messaging/schema-registry/`| `{entity}_events.v{N}.json` | Schema registry contract payload (JSON Schema / Avro). |
| `messaging/dlq/` | `dlq_policy.yaml` | Dead Letter Queue retry backoff, max retries, and alert rules. |
| `messaging/subscriptions/`| `consumer_groups.yaml` | Consumer group IDs, topic subscriptions, and offset commit modes. |
| `messaging/` | `topics.lock` | Immutable lockfile of provisioned Kafka topics. |

---

### 3.5 `deploy/` — Deployment & Infrastructure Manifests

Zero business code. Only container orchestration and deployment configurations.

| Path | File Name Formula | Role & Contents |
|---|---|---|
| `deploy/k8s/` | `deployment.yaml`, `service.yaml`, `hpa.yaml`, `configmap.yaml` | Kubernetes core resources. |
| `deploy/helm/` | `Chart.yaml`, `values.yaml`, `values.{env}.yaml` | Helm packaging and environment values charts. |

---

### 3.6 `src/api/` — Delivery & Transport Layer (Thin Ingress Adapters)

Maps external protocols to internal domain services. Contains zero business logic and zero direct database queries.

```
src/api/
├── rest/v1/
│   ├── router/{feature}.router.ts       - Class: {Feature}RestRouter
│   ├── route.rules/{feature}.rules.ts   - Class: {Feature}RouteRules
│   └── handlers/{feature}.handler.ts    - Class: {Feature}RestHandler
│
├── graphql/v1/
│   ├── schema/{feature}.graphql         - Feature GraphQL SDL subset
│   ├── resolvers/{feature}.resolver.ts  - Class: {Feature}GraphQLResolver
│   └── dataloaders/{feature}.loader.ts  - Class: {Feature}DataLoader
│
├── grpc/v1/
│   ├── server/{feature}.server.ts       - Class: {Feature}GrpcServer
│   └── handlers/{feature}.grpc.ts       - Class: {Feature}GrpcHandler
│
└── events/
    ├── consumers/{feature}.consumer.ts  - Class: {Feature}{Event}Consumer
    └── publishers/{feature}.publisher.ts - Class: {Feature}{Event}Publisher
```

---

### 3.7 `src/features/{feature-name}/` — Isolated Domain Feature Core

Every feature directory implements the **5 Immutable Data Pillars** plus clean port-isolated domain logic.

| Sub-Folder / File | File Naming Pattern | Class / Symbol Name | Primary Responsibility |
|---|---|---|---|
| `index.ts` | `index.ts` | Public exports only | Facade export: domain service and public types. Never exports internal repository or SQL queries. |
| `context.md` | `context.md` | Markdown text | Business domain context, dependencies, ADR links. |
| `schema/` | `{feature}.schema.ts` | `{Feature}EntitySchema` | Zod runtime schema + declarative `fromApi`/`toApi` JSON transformation mapping operations. |
| `queries/` | `{feature}.queries.sql` | `FLOW_{ACTION}` | MANDATORY: Named, flow-grouped parameterized queries. Zero inline SQL strings anywhere else. |
| `rules/` | `{feature}.rules.ts` | `{Feature}RuleSet` | Business logic branches as structured rules with priority, category, and deny-override resolution. |
| `machines/` | `{feature}.machine.ts` | `{Feature}LifecycleMachine` | Multi-state lifecycle definition with state transitions, guards, and event side-effects. |
| `workflows/` | `{feature}.workflow.ts` | `{Feature}AutomationWorkflow`| Multi-step DAG automation step array executed by the traced workflow runner. |
| `service/` | `{feature}.service.ts` | `{Feature}DomainService` | Pure domain service logic. Injects repository port interface. Zero direct HTTP/DB/ORM driver imports. |
| `repository/` | `{feature}.repository.port.ts` | `{Feature}RepositoryPort` | Interface declaring data access contracts (`getById`, `create`, `update`, `delete`). |
| `repository/` | `{feature}.repository.ts` | `Postgres{Feature}Repository`| Concrete repository implementation invoking `SqlQueryExecutor` from `src/infra/database/executor/`. |
| `types/` | `{feature}.types.ts` | `{Feature}DomainModel` | Domain models, input commands, output results, and custom domain error classes. |
| `tests/unit/` | `{feature}.service.spec.ts` | `describe("{Feature}Service")`| Unit tests mocking the repository port. Zero network/DB calls. |
| `tests/integration/`| `{feature}.repository.test.ts`| `describe("{Feature}Repo")` | Integration tests executing queries against real testcontainer database. |
| `tests/contract/`| `{feature}.contract.test.ts` | `describe("{Feature}Contract")`| Compliance test asserting responses against OpenAPI specification. |

---

### 3.8 `src/infra/` — Centralized Infrastructure Runtime Engines

All reusable infrastructure adapters, connection pools, and client SDKs. Features NEVER write custom driver connections.

```
src/infra/
├── config/
│   ├── config.loader.ts                 - Class: StronglyTypedConfigLoader
│   └── env.schema.ts                    - Class: EnvironmentSchemaBinding
│
├── database/
│   ├── pool/connection.pool.ts          - Class: DatabaseConnectionPool
│   ├── factory/client.factory.ts        - Class: DatabaseClientFactory
│   ├── transaction/transaction.manager.ts - Class: DatabaseTransactionManager
│   ├── executor/query.executor.ts       - Class: SqlQueryExecutor
│   ├── middleware/query.middleware.ts   - Class: DatabaseMiddlewarePipeline
│   ├── migrations/migration.runner.ts   - Class: DatabaseMigrationRunner
│   ├── tracing/db.tracer.ts             - Class: DatabaseOpenTelemetryTracer
│   └── adapters/{vendor}.adapter.ts     - Class: PostgresDriverAdapter, RedisDriverAdapter
│
├── messaging/
│   ├── broker/kafka.broker.ts           - Class: KafkaBrokerClient
│   ├── factory/connection.factory.ts    - Class: KafkaConnectionFactory
│   ├── producers/event.producer.ts      - Class: TypedKafkaEventProducer
│   ├── consumers/event.consumer.ts      - Class: TypedKafkaEventConsumer
│   ├── middleware/messaging.middleware.ts - Class: MessagingMiddlewarePipeline
│   ├── topics/topic.provisioner.ts      - Class: KafkaTopicProvisioner
│   ├── migrations/topic.migrator.ts     - Class: KafkaTopicMigrationRunner
│   ├── tracing/trace.propagator.ts      - Class: KafkaTraceContextPropagator
│   └── cqrs/
│       ├── command.handler.ts           - Class: CqrsCommandDispatcher
│       ├── projection.store.ts          - Class: MaterializedProjectionStore
│       └── query.selector.ts            - Class: CqrsQuerySelector
│
└── clients/
    └── {upstream-service}/v1/
        └── {service}.client.ts          - Class: GeneratedUpstreamServiceClient
```

---

### 3.9 `src/infra/observability/` — Failure Diagnosis & Profiling Engines

The unified runtime observability engine housing all 20 complex and 17 distributed failure diagnosis mechanics:

| Sub-Module | File Name | Primary Engine Class | Responsibility |
|---|---|---|---|
| `tracing/` | `trace.provider.ts` | `OpenTelemetryTraceProvider` | Tracer setup, W3C context, HTTP/gRPC/Kafka middlewares |
| `tracing/` | `deepest_leaf_walker.ts` | `DeepestLeafErrorWalker` | Traverses span trees to locate exact root-cause failure span |
| `tracing/` | `tail_based_sampler.ts` | `TailBasedTraceSampler` | 100% trace retention on errors via post-completion buffering |
| `tracing/` | `trace_differ.ts` | `DifferentialTraceDiffer` | Aligns and diffs spans between good and bad trace runs |
| `clocks/` | `logical_clock.engine.ts` | `LogicalClockEngine` | Lamport counters, Vector Clocks, and Hybrid Logical Clocks |
| `profiling/` | `continuous_profiler.ts`| `ContinuousProfilerEngine` | Parca/Pyroscope stack sampling (< 2% CPU overhead) |
| `profiling/` | `flame_graph_differ.ts` | `FlameGraphDifferEngine` | Differential flame graph comparison between baseline and degraded periods |
| `race_detection/`| `race_detector.ts` | `HappensBeforeRaceDetector` | Vector clock runtime memory access race detection (ThreadSanitizer-style) |
| `deadlock/` | `wait_for_graph.ts` | `WaitForGraphDeadlockEngine` | Directed graph cycle detection over local lock wait queues |
| `deadlock/` | `chandy_misra_haas.ts` | `ChandyMisraHaasProbeEngine`| Distributed deadlock probe initiation and propagation |
| `heap_analysis/`| `heap_differ.ts` | `HeapSnapshotDifferEngine` | Live object diffing and retaining-reference chain isolation |
| `heap_analysis/`| `core_dump_inspector.ts`| `CoreDumpInspectorEngine` | Post-mortem stack and memory reconstruction from crash dumps |
| `heap_analysis/`| `gc_pause_correlator.ts`| `GcPauseLatencyCorrelator` | Correlates stop-the-world GC pauses directly with latency spikes |
| `ebpf/` | `syscall_tracer.ts` | `EbpfSyscallTracerEngine` | Attaches kernel kprobes to trace syscall latency histograms |
| `wire_analysis/`| `packet_capture.ts` | `WirePacketCaptureAnalyzer` | Promiscuous interface packet capture and TCP retransmission tracking |
| `vector_inspection/`| `version_vector.ts` | `VersionVectorInspectorEngine`| Direct replica version-vector causality inspection for sibling conflicts |
| `divergence_audit/`| `divergence_auditor.ts`| `AntiEntropyDivergenceAuditor`| Direct multi-replica read comparison and auto-repair trigger |
| `idempotency_audit/`| `idempotency_auditor.ts`| `IdempotencyKeyAuditorEngine` | Dedupe store inspection: TTL expiry vs duplicate delivery bug classifier |
| `transition_log/`| `transition_logger.ts` | `StateMachineTransitionLogger`| Durable transition logging for asynchronous workflows |
| `snapshots/` | `chandy_lamport.ts` | `ChandyLamportSnapshotCoordinator`| Non-blocking consistent global cut marker propagation |
| `replay/` | `event_replayer.ts` | `EventSourcedReplayEngine` | Reconstructs historical state by folding event streams to point-in-time |
| `wal_miner/` | `wal_log_miner.ts` | `DatabaseWalLogMiner` | Direct WAL/binlog tailing to verify storage ground truth vs app logs |
| `shadow_traffic/`| `shadow_comparator.ts` | `ShadowTrafficComparatorEngine`| Mirrors live requests to candidate versions and computes output diffs |
| `circuit_breaker_history/`| `cascade_analyzer.ts`| `CircuitBreakerCascadeAnalyzer`| Orders trip timestamps to distinguish root cause breaker from protective trips |
| `saturation_analysis/`| `littles_law.ts` | `LittlesLawSaturationEstimator`| $L = \lambda \times W$ non-linear queue saturation threshold calculator |
| `analytics/` | `bubbleup_differ.ts` | `BubbleUpDistributionalDiffer` | Statistical attribute divergence scoring across good and bad event sets |
| `topology/` | `dependency_overlay.ts` | `ServiceDependencyRedOverlay` | Call graph construction with Rate/Error/Duration metric overlays |

---

### 3.10 `src/shared/` — Reusable Utilities & Cross-Cutting Helpers

Pure utilities with zero domain business logic.

```
src/shared/
├── utils/
│   ├── date.utils.ts                    - Pure date formatting & timezone helpers
│   ├── string.utils.ts                  - String manipulation, slugification, regex
│   └── crypto.utils.ts                  - SHA256 hashing, HMAC signatures, UUID generation
│
├── constants/
│   ├── system.constants.ts              - System-wide constants, default page limits
│   └── header.constants.ts              - Standard HTTP/gRPC/Kafka header names
│
├── errors/
│   ├── base.error.ts                    - Abstract ApplicationError base class
│   ├── not_found.error.ts               - Standard NotFoundError envelope
│   ├── validation.error.ts              - InputValidationError envelope
│   └── envelope.wrapper.ts              - Standard API JSON envelope { data, error, meta }
│
├── ports/
│   └── database.interface.ts            - Generic CrudPort, QueryPort, CachePort
│
└── types/
    ├── common.types.ts                  - Common IDs, Timestamps, DeepPartial
    ├── pagination.types.ts              - PageRequest, PageResponse, CursorPagination
    └── result.envelope.ts               - Result<T, E> functional wrapper
```

---

### 3.11 `tests/` — Global Package Test Suites & Diagnostics Harnesses

```
tests/
├── unit/                                - Sub-package unit test suites
├── integration/                         - Testcontainers integration test suites
├── contract/                            - OpenAPI / AsyncAPI contract compliance tests
├── performance/
│   ├── scenarios/                       - K6 load, stress, and spike test scripts
│   └── thresholds.json                  - Strict SLA thresholds (p95 < 100ms, error < 0.01%)
├── e2e/                                 - Multi-feature user journey workflows
└── diagnostics/
    ├── jepsen/
    │   └── linearizability.verifier.ts  - Jepsen fault injection & Knossos linearizability checker
    ├── tla_plus/
    │   └── model_checker.runner.ts      - TLA+ state specs and TLC model checker runner
    ├── byzantine/
    │   └── byzantine_fault.injector.ts  - Intercepts and corrupts responses for BFT validation
    ├── bisection/
    │   └── regression.bisector.ts       - Automated git bisect reproducer runner
    ├── chaos/
    │   └── chaos_fault.injector.ts      - Chaos experiment harness (latency, packet drop, node kill)
    └── vcr_proxy/
        └── boundary_vcr.proxy.ts        - Network boundary record/replay VCR test proxy
```

---

### 3.12 `scripts/` — Build & Operational Scripts

| Script Name | Responsibility |
|---|---|
| `scripts/run.sh` | Starts the service locally with hot-reload and debugger attached. |
| `scripts/migrate.sh` | Verifies `schema.lock` checksums and executes pending SQL migrations. |
| `scripts/test.sh` | Executes unit, integration, and contract test runners with coverage thresholds. |
| `scripts/generate.sh` | Compiles API contracts into server stubs and client SDKs in `src/infra/clients/`. |
| `scripts/prod-check/{flow}.sh`| Deterministic shell scripts executing production smoke verification flows. |

---

## 4. Multi-Feature Comparative Implementation Matrix

To prove this architecture applies universally to **ANY** feature, here is how three completely distinct domains implement the exact same logic-driven names:

| Architectural Component | Feature A: `organizations` (Relational Multi-Tenant CRUD) | Feature B: `api-keys` (Security & Token Lifecycle) | Feature C: `evaluations` (Async LLM Pipeline & Workflows) |
|---|---|---|---|
| **Directory** | `src/features/organizations/` | `src/features/api-keys/` | `src/features/evaluations/` |
| **Contract** | `contracts/openapi/v1.yaml` (`/orgs`) | `contracts/openapi/v1.yaml` (`/keys`) | `contracts/asyncapi/v1.yaml` (`eval-events`) |
| **Schema** | `organizations.schema.ts` | `api-keys.schema.ts` | `evaluations.schema.ts` |
| **SQL Queries** | `organizations.queries.sql` | `api-keys.queries.sql` | `evaluations.queries.sql` |
| **Named Query Example**| `FLOW_GET_ORGANIZATION_BY_ID` | `FLOW_GET_API_KEY_BY_HASH` | `FLOW_INSERT_EVALUATION_RUN` |
| **Repository Port** | `OrganizationRepositoryPort` | `ApiKeyRepositoryPort` | `EvaluationRepositoryPort` |
| **Repository Impl** | `PostgresOrganizationRepository`| `PostgresApiKeyRepository` | `PostgresEvaluationRepository` |
| **Domain Service** | `OrganizationDomainService` | `ApiKeyDomainService` | `EvaluationDomainService` |
| **Primary Method** | `createOrganization(input)` | `generateScopedKey(input)` | `scheduleEvaluationPipeline(input)` |
| **Business Rules** | `OrganizationRuleSet` | `ApiKeyRuleSet` | `EvaluationRuleSet` |
| **Rule Example** | `canCreateSubOrganization` | `canAccessSecretScope` | `canExceedTokenBudget` |
| **State Machine** | `OrganizationLifecycleMachine` | `ApiKeyLifecycleMachine` | `EvaluationExecutionMachine` |
| **State Cycle** | `trial -> active -> suspended` | `active -> revoked -> expired` | `queued -> running -> completed -> failed`|
| **Workflow** | `OrganizationOnboardingWorkflow`| `ApiKeyRotationWorkflow` | `EvaluationPipelineWorkflow` |
| **Workflow Steps** | `[stepValidate, stepCreateDb]` | `[stepVerifyOld, stepIssueNew]`| `[stepFetchData, stepRunLLM, stepScore]` |
| **REST Handler** | `OrganizationRestHandler` | `ApiKeyRestHandler` | `EvaluationRestHandler` |
| **Kafka Event** | `OrganizationCreatedEventV1` | `ApiKeyRevokedEventV1` | `EvaluationCompletedEventV1` |
| **Kafka Topic** | `prod.identity.org.created.v1` | `prod.auth.api-key.revoked.v1` | `prod.llm.eval.completed.v1` |
| **Unit Test** | `organizations.service.spec.ts`| `api-keys.service.spec.ts` | `evaluations.service.spec.ts` |

---

## 5. End-to-End Request & Data Flow Anatomy

Here is the exact trace of how classes and methods interact during a write request across the architecture:

```
[Client HTTP Request]
        │
        ▼
[src/api/rest/v1/router/organizations.router.ts]
        │  Dispatches to handler
        ▼
[src/api/rest/v1/handlers/organizations.handler.ts] -> OrganizationRestHandler.handleCreate()
        │  1. Parses input with organizationsSchema.fromApi()
        │  2. Calls service
        ▼
[src/features/organizations/service/organizations.service.ts] -> OrganizationDomainService.createOrganization()
        │  1. Evaluates rules: OrganizationRuleSet.evaluate()
        │  2. Initializes state: OrganizationLifecycleMachine.transitionTo("trial")
        │  3. Delegates storage to repository port: OrganizationRepositoryPort.create()
        ▼
[src/features/organizations/repository/organizations.repository.ts] -> PostgresOrganizationRepository.create()
        │  1. Loads named query string from queries/organizations.queries.sql: FLOW_INSERT_ORGANIZATION
        │  2. Delegates to generic infra executor
        ▼
[src/infra/database/executor/query.executor.ts] -> SqlQueryExecutor.execute()
        │  1. Opens OTEL span: identity.organization.create
        │  2. Applies resilience decorators: withTracing(withCircuitBreaker(withRetry(query)))
        │  3. Executes binary wire protocol via PostgresDriverAdapter
        ▼
[Database Cluster (PostgreSQL / AlloyDB)]
        │  Data persisted -> row returned
        ▼
[src/features/organizations/schema/organizations.schema.ts]
        │  Maps DB row to internal domain model via schema.toDomain()
        ▼
[src/infra/messaging/producers/event.producer.ts] -> TypedKafkaEventProducer.publish()
        │  1. Emits OrganizationCreatedEventV1 to Kafka topic: prod.identity.organization.created.v1
        │  2. Injects W3C traceparent headers
        ▼
[src/api/rest/v1/handlers/organizations.handler.ts]
        │  Wraps domain model in standard JSON envelope: { data: result, error: null }
        ▼
[Client Receives 201 Created Response]
```

---

## 6. Configuration, Execution Wiring & Logical Interconnections

Understanding how static configuration translates into running processes, how dependencies are injected, and how features integrate without monolithic coupling is the cornerstone of extreme-scale stability.

### The Config-to-Execution Wiring Pipeline

Configuration is strictly unidirectional. Runtime components never query ambient environment variables directly. The pipeline flows deterministically from raw environment to runtime execution:

```
[System Environment / Kubernetes ConfigMap]
                   │
                   ▼
  [config/env.schema.ts]
                   │  - Strictly validates all process.env variables via Zod at boot
                   ▼
  [config/environments/{env}.yaml]
                   │  - Injects environment-specific constants (timeouts, pool sizes, hosts)
                   ▼
  [src/infra/config/config.loader.ts]
                   │  - Combines ENV + YAML into frozen, deeply-immutable configuration singleton
                   ▼
 ┌─────────────────┴───────────────────────────────┐
 │                                                 │
 ▼                                                 ▼
[src/infra/database/pool/connection.pool.ts]      [src/infra/messaging/broker/kafka.broker.ts]
 - Initializes read/write connection pools         - Initializes Producer & Consumer groups
 │                                                 │
 └─────────────────┬───────────────────────────────┘
                   │
                   ▼
[src/infra/observability/tracer/tracer.ts]
 - Bootstraps OpenTelemetry SDK, OTLP exporter & trace provider
                   │
                   ▼
[src/shared/ports/*.port.ts]
 - Declares abstract contracts (e.g. IOrganizationRepositoryPort)
                   │
                   ▼
[src/features/*/repository/*.repository.ts]
 - Instantiates repositories bound to connection pool and queries.sql
                   │
                   ▼
[src/features/*/service/*.service.ts]
 - Instantiates domain services with injected repositories, rules & machines
                   │
                   ▼
[src/api/rest/v1/router/*.router.ts]
 - Binds HTTP routes to handlers, injecting domain service instances
                   │
                   ▼
[src/infra/http/server.ts]
 - Mounts middleware pipeline (tracing -> security -> auth -> rate-limit -> routes)
 - Binds to POSIX port; starts listening for requests
```

### The "Zero `process.env` in Domain Logic" Law

1. **Pure Isolation**: Neither [`src/features/`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md) nor [`src/api/`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md) is permitted to call `process.env` or access raw runtime environment flags.
2. **Deterministic Inversion**: All configuration needed by domain features (e.g., token expiration limits, rate limit thresholds, feature flags) MUST be passed via typed parameters from [`src/infra/config/config.loader.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md).
3. **Auditability**: When an environment variable changes, the blast radius is immediately verifiable by inspecting [`config/env.schema.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md) and [`src/infra/config/config.loader.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md), rather than searching across hundreds of application files.

### Feature Integration Pathways: How Features Connect Without Coupling

At scale, features MUST NOT cross-import each other's internal files (`repository/`, `queries/`, `service/`). Integration occurs through exactly three authorized pathways:

```
                  ┌─────────────────────────────────────────┐
                  │          Feature Integration            │
                  └─────────────────────────────────────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         ▼                             ▼                             ▼
   [Pathway 1]                   [Pathway 2]                   [Pathway 3]
 [Synchronous Facade]        [Asynchronous Event Bus]      [Remote Inter-Service SDK]
   (In-Process Domain)         (Decoupled Temporal)         (Separate Microservices)
         │                             │                             │
         ▼                             ▼                             ▼
[src/features/A/index.ts]     [src/infra/messaging/]        [src/infra/clients/]
  Feature B calls public        Feature A emits to Kafka;     Generated client talks
  facade methods only.          Feature B consumes topic.     over HTTP/gRPC.
```

1. **Pathway 1: Synchronous In-Process Facade (`index.ts`)**:
   - Used when Feature B needs immediate, in-transaction domain data from Feature A.
   - Feature A exports a single entrypoint [`src/features/featureA/index.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md) exposing ONLY its public Facade/Service interface.
   - **Forbidden**: Deep importing `src/features/featureA/repository/featureA.repository.ts` or `src/features/featureA/queries/featureA.queries.sql`.
2. **Pathway 2: Asynchronous Event Bus via Kafka (`producers/` & `consumers/`)**:
   - Used for all non-blocking side effects (notifications, audit logging, analytics, eventual consistency).
   - Feature A publishes domain events via [`src/infra/messaging/producers/event.producer.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md) adhering to schemas in [`messaging/schemas/`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md).
   - Feature B listens via [`src/infra/messaging/consumers/event.consumer.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md) and delegates to its own service.
   - **Blast Radius**: Zero. Feature A does not know Feature B exists.
3. **Pathway 3: Remote Inter-Service SDK (`src/infra/clients/`)**:
   - Used when communicating with external microservices or external third-party APIs.
   - All calls go through strongly-typed clients generated from OpenAPI contracts in [`contracts/openapi/`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md).
   - Every client is automatically wrapped with resilience decorators (`withRetry`, `withCircuitBreaker`, `withTracing`, `withCache`).

### Complete Layer Dependency Matrix (Allowed vs Banned Imports)

| Layer | Can Import From | CANNOT Import From |
|---|---|---|
| **`contracts/`** | Standard schema formats | Any application code (`src/*`, `config/*`) |
| **`config/`** | Zod, YAML parsers | `src/*`, database drivers, HTTP servers |
| **`src/shared/ports/`** | `src/shared/types/` | `src/features/*`, `src/infra/*`, `src/api/*` |
| **`src/features/<feat>/service/`** | `src/shared/ports/`, `src/features/<feat>/{schema,rules,machines,types}` | `src/api/*`, `src/infra/database/pool/*`, direct SQL strings |
| **`src/features/<feat>/repository/`** | `src/infra/database/pool/`, `src/features/<feat>/queries/`, `src/features/<feat>/schema/` | `src/api/*`, `src/features/<other_feat>/*` |
| **`src/api/rest/v1/handlers/`** | `src/features/<feat>/index.ts`, `contracts/`, `src/shared/types/` | `src/features/<feat>/repository/*`, `database/*`, SQL queries |
| **`src/infra/`** | Node.js drivers, external SDKs, `src/shared/types/` | `src/api/*`, `src/features/*` |

---

## 7. Blast Radius Analysis & The Change Impact Matrix

At scale, changing code without knowing what it affects causes catastrophic regressions. This matrix defines the precise blast radius for every type of engineering modification and proves which layers are guaranteed safe.

### The Exhaustive Change Impact & Blast Radius Matrix

| Change Target | Direct Files Modified | Downstream Files Impacted | Guaranteed Unaffected Layers | Blast Radius Level | Safety Verification Command |
|---|---|---|---|---|---|
| **1. Request Payload Modification** (Rename/add parameter in incoming REST request) | 1. `contracts/openapi/v1.yaml`<br>2. `src/features/<feat>/schema/<feat>.schema.ts` (`fromApi`) | Generated API contract types (`contracts/generated/`) | **Guaranteed Unaffected:**<br>• Domain Service (`service/`)<br>• Repository (`repository/`)<br>• SQL Queries (`queries/*.sql`)<br>• Database Tables (`migrations/`) | **Level 1: Local Contract**<br>(Completely absorbed by Schema ACL) | `npm run test:contract && npm run test:unit` |
| **2. Internal Business Rule / Validation Policy** (e.g. tier limits, quota, discount rule) | 1. `src/features/<feat>/rules/<feat>.rules.ts` | None outside the rule test | **Guaranteed Unaffected:**<br>• HTTP Handlers (`handlers/`)<br>• API Routers (`router/`)<br>• Database Queries (`queries/*.sql`)<br>• Public API Contracts (`contracts/`) | **Level 0: Isolated**<br>(Pure data-driven rule update) | `npm test -- tests/unit/<feat>.rules.test.ts` |
| **3. State Machine Transition Policy** (e.g. new lifecycle state or guard condition) | 1. `src/features/<feat>/machines/<feat>.machine.ts`<br>2. `src/features/<feat>/types/<feat>.types.ts` | Handlers calling transition endpoints | **Guaranteed Unaffected:**<br>• SQL Schema (if state stored as string)<br>• External Service Clients<br>• Messaging Infrastructure | **Level 1: Local Feature**<br>(State logic localized to machine) | `npm test -- tests/unit/<feat>.machine.test.ts` |
| **4. Database Column Addition** (Adding new persisted field to entity) | 1. `database/migrations/{NNNN}_add_*.sql`<br>2. `database/schema.lock`<br>3. `src/features/<feat>/queries/*.sql`<br>4. `src/features/<feat>/schema/<feat>.schema.ts` (`toDomain`) | Repository mapper | **Guaranteed Unaffected:**<br>• External REST API Consumers<br>• Public OpenAPI Contracts<br>• Other feature services | **Level 1: Storage Tier**<br>(Decoupled from public contract) | `npm run migrate:up && npm run test:integration` |
| **5. Domain Event Schema Modification** (Adding field to outgoing Kafka message) | 1. `messaging/schemas/{topic}.avsc`<br>2. `src/infra/messaging/producers/event.producer.ts` | Downstream consumers (if breaking) | **Guaranteed Unaffected:**<br>• Synchronous REST API handlers<br>• Database write transactions<br>• Internal state machines | **Level 2: Cross-Service Async**<br>(Requires Avro/Protobuf compatibility check) | `npm run schema:check-compatibility` |
| **6. Database Connection Pool / Timeout Config** | 1. `config/environments/{env}.yaml`<br>2. `config/env.schema.ts` (if new key) | `src/infra/database/pool/connection.pool.ts` | **Guaranteed Unaffected:**<br>• All feature domain logic<br>• All business rules<br>• All API handlers | **Level 3: Infrastructure System-Wide**<br>(Runtime operational tune) | `scripts/prod-check/system-health/*.sh` |
| **7. Breaking API Change (v2 Required)** | 1. `contracts/openapi/v2.yaml`<br>2. `src/api/rest/v2/`<br>3. `src/features/<feat>/schema/<feat>.v2.schema.ts` | External API clients | **Guaranteed Unaffected:**<br>• `v1` REST API Handlers & Routers<br>• Existing database tables (uses schema adapter) | **Level 3: Public Contract Boundary**<br>(Isolated via URL versioning) | `npm run test:e2e:v1 && npm run test:e2e:v2` |

### The 4-Question Blast Radius Audit Protocol

Before writing or approving any PR, run through these 4 verification questions:
1. **"Does this change alter the public contract?"**
   - If YES: Did you update `fromApi` / `toApi` mapping in `schema/{feature}.schema.ts` to prevent domain ripple?
2. **"Does this change alter domain business logic?"**
   - If YES: Is the logic expressed as a declarative rule in `rules/{feature}.rules.ts` or is it leaking into handlers and SQL queries?
3. **"Does this change require database schema modification?"**
   - If YES: Is there an atomic migration and matching rollback script? Did you verify `database/schema.lock`?
4. **"What is the blast radius level?"**
   - *Level 0 (Isolated)*: Rule or machine change. Verify with unit tests.
   - *Level 1 (Local Feature)*: Internal schema or query change. Verify with integration tests.
   - *Level 2 (Cross-Service Async)*: Event producer change. Verify with schema registry compatibility check.
   - *Level 3 (System-Wide)*: Config or pool change. Verify with synthetic health check scripts.

---

## 8. Daily Single-Point-of-Change Recipes (How to Modify Code Without Cascade)

The primary reason software systems rot over time is the "cascade effect": a simple requirement change forces the developer to modify 10 files across 6 architectural layers. The following recipes demonstrate how our architecture confines everyday changes to a **single point of change**.

### Recipe 1: Modifying an Incoming Request Payload

**Scenario**: A third-party client or mobile app modifies the payload for creating an organization, renaming `name` to `organization_title` and adding an optional `referral_code`.

**Traditional Flawed Approach**:
- Developer changes API controller $\rightarrow$ changes DTO $\rightarrow$ changes domain entity $\rightarrow$ changes service interface $\rightarrow$ changes repository $\rightarrow$ changes SQL query $\rightarrow$ breaks 15 unit tests across the repo.

**Our Single-Point-of-Change Recipe**:
1. **File 1**: Update public contract in [`contracts/openapi/v1.yaml`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md).
2. **File 2**: Update the Anti-Corruption Layer in [`src/features/organizations/schema/organizations.schema.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md):
   ```typescript
   export const organizationSchema: EntitySchema<OrganizationEntity> = {
     name: "organization",
     endpoint: "/api/v1/organizations",
     fromApi: [
       { op: "rename", from: "organization_title", to: "name" },
       { op: "default", field: "referral_code", value: null },
     ],
     validate: organizationZodSchema,
     // ...
   };
   ```
3. **Guaranteed Unchanged Files**:
   - `src/features/organizations/service/organizations.service.ts` $\rightarrow$ **Zero Changes**
   - `src/features/organizations/repository/organizations.repository.ts` $\rightarrow$ **Zero Changes**
   - `src/features/organizations/queries/organizations.queries.sql` $\rightarrow$ **Zero Changes**
   - Database tables and migrations $\rightarrow$ **Zero Changes**

---

### Recipe 2: Modifying an Internal Business Rule or Validation Policy

**Scenario**: Product leadership changes the policy: Enterprise organizations can now invite up to 500 members instead of 100, and non-profit tiers receive an automatic 50% discount on evaluation credits.

**Single-Point-of-Change Recipe**:
1. **File 1**: Edit ONLY [`src/features/organizations/rules/organizations.rules.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md):
   ```typescript
   export const organizationRules: Rule[] = [
     {
       id: "rule-org-enterprise-member-limit",
       name: "Enterprise Tier Member Capacity",
       priority: 100,
       category: "quota",
       conditions: [
         { field: "tier", operator: "equals", value: "enterprise" }
       ],
       effects: [
         { effect: "set_member_capacity", value: 500 }
       ]
     },
     {
       id: "rule-org-nonprofit-discount",
       name: "Non-Profit Evaluation Credit Discount",
       priority: 90,
       category: "pricing",
       conditions: [
         { field: "tier", operator: "equals", value: "non_profit" }
       ],
       effects: [
         { effect: "apply_credit_discount", value: 0.50 }
       ]
     }
   ];
   ```
2. **Guaranteed Unchanged Files**:
   - API Handler & Router $\rightarrow$ **Zero Changes**
   - Repository & SQL Queries $\rightarrow$ **Zero Changes**
   - OpenAPI Contract $\rightarrow$ **Zero Changes**
   - Domain Service Logic $\rightarrow$ **Zero Changes** (it simply executes `resolveRules(organizationRules, ctx)`)

---

### Recipe 3: Modifying a State Machine / Multi-Step Lifecycle Transition

**Scenario**: Organizations in `suspended` state cannot transition directly to `active` without undergoing a mandatory audit clearance step.

**Single-Point-of-Change Recipe**:
1. **File 1**: Edit ONLY [`src/features/organizations/machines/organizations.machine.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md):
   ```typescript
   // In the suspended state definition:
   suspended: {
     on: {
       AUDIT_CLEARED: { target: "pending_review" },
       PERMANENTLY_TERMINATE: { target: "terminated" },
       // DIRECT "ACTIVATE" TRANSITION REMOVED HERE
     }
   }
   ```
2. **Guaranteed Unchanged Files**:
   - Database schemas, repositories, external API router, and HTTP handlers require **Zero Changes**. Any attempt to call `/activate` while in `suspended` will be rejected deterministically by the machine guard.

---

### Recipe 4: Adding a Persisted Database Field Without Breaking the API

**Scenario**: The database requires a new column `billing_tax_id` for compliance, but this must NOT be exposed to public REST consumers.

**Single-Point-of-Change Recipe**:
1. **File 1**: Add migration in [`database/migrations/0004_add_billing_tax_id_to_organizations.sql`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md).
2. **File 2**: Update query in [`src/features/organizations/queries/organizations.queries.sql`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md).
3. **File 3**: Update entity schema mapping in [`src/features/organizations/schema/organizations.schema.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md):
   ```typescript
   toApi: [
     { op: "omit", fields: ["billing_tax_id"] } // Strip internal tax ID from public responses
   ]
   ```
4. **Guaranteed Unchanged Files**:
   - Public OpenAPI contract [`contracts/openapi/v1.yaml`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md) $\rightarrow$ **Zero Changes**
   - External consumers experience zero breakage or leaking of internal schema details.

---

### Recipe 5: Adding Downstream Resilience (Retry, Circuit Breaker, Caching)

**Scenario**: An external KYC/Verification API called by the organizations feature is experiencing transient 503 errors during traffic spikes.

**Single-Point-of-Change Recipe**:
1. **File 1**: In the repository or adapter wiring, compose resilience decorators without touching domain logic:
   ```typescript
   // In src/features/organizations/repository/organizations.repository.ts
   export const organizationKycAdapter = withCircuitBreaker(
     withRetry(rawKycClient, { maxRetries: 3, backoffMs: 200 }),
     { failureThreshold: 5, resetTimeoutMs: 30000 }
   );
   ```
2. **Guaranteed Unchanged Files**:
   - Domain Service [`src/features/organizations/service/organizations.service.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md) $\rightarrow$ **Zero Changes**
   - Business Rules $\rightarrow$ **Zero Changes**
   - API Handlers $\rightarrow$ **Zero Changes**

---

## 9. Handling Extreme Complexity: Asynchronous Rules, Conflicting Policies, Sagas & Distributed Workflows

A common misconception is that data-driven architectures only work for simple CRUD. In reality, **simple CRUD architectures collapse under complex logic**, devolving into 2,000-line service files full of nested `if/else`, uncoordinated database writes, and untraceable race conditions.

This architecture is purpose-built to decompose extreme complexity into five deterministic engines.

### 9.1 Complex Scenario 1: Multi-Branch Conflicting Rules with Live Asynchronous Data

**The Challenge**:
A customer requests an API Key generation. The logic requires:
1. Validating organization membership.
2. Checking an external live risk score from a fraud vendor (async I/O).
3. Checking real-time burst rate limits in Redis (async I/O).
4. Evaluating conflicting rules: VIP enterprise accounts get unlimited keys, but a global regulatory compliance freeze or security lock trumps all VIP privileges (**deny-override**).

**How the Architecture Handles It**:
Instead of a 15-branch `if/else` block inside the controller or service:
1. **Async Checkers Registry** ([`src/features/api-keys/rules/api-keys.async-checkers.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md)):
   ```typescript
   export const apiKeyAsyncCheckers = {
     async isSecurityFreezeActive(orgId: string): Promise<boolean> {
       return complianceClient.checkOrgFreezeStatus(orgId);
     },
     async getLiveFraudScore(userId: string): Promise<number> {
       return fraudDetectionService.fetchScore(userId);
     },
   };
   ```
2. **Rules-As-Data with Priority & Deny-Override** ([`src/features/api-keys/rules/api-keys.rules.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md)):
   ```typescript
   export const apiKeyIssuanceRules: Rule[] = [
     {
       id: "rule-sec-01",
       name: "Global Compliance Security Freeze",
       priority: 1000, // Maximum Priority
       category: "security",
       asyncCheck: { checker: "isSecurityFreezeActive", param: "orgId" },
       effects: [{ effect: "deny", reason: "Organization is under regulatory freeze" }]
     },
     {
       id: "rule-fraud-02",
       name: "High Fraud Score Rejection",
       priority: 900,
       category: "risk",
       asyncCheck: { checker: "getLiveFraudScore", param: "userId", operator: "gt", threshold: 85 },
       effects: [{ effect: "deny", reason: "Risk score threshold exceeded" }]
     },
     {
       id: "rule-ent-03",
       name: "Enterprise Unlimited Keys",
       priority: 100, // Lower priority than security/fraud
       category: "quota",
       conditions: [{ field: "tier", operator: "equals", value: "enterprise" }],
       effects: [{ effect: "allow_unlimited_keys" }]
     }
   ];
   ```
3. **Execution in Domain Service**:
   ```typescript
   // In ApiKeysDomainService.issueKey()
   const evaluation = await resolveRules(apiKeyIssuanceRules, ctx);
   if (evaluation.hasEffect("deny")) {
     throw new PolicyViolationError(evaluation.getReason("deny"));
   }
   ```
**Blast Radius**: When fraud thresholds or enterprise rules change, **only `api-keys.rules.ts` is edited**. Handlers, database queries, and serializers remain completely untouched.

---

### 9.2 Complex Scenario 2: Multi-Step Distributed Sagas with Compensating Transactions

**The Challenge**:
Creating an Organization involves a distributed 4-step workflow:
1. Persist draft organization record in PostgreSQL.
2. Charge setup fee on Stripe via external payment gateway.
3. Provision dedicated Kubernetes namespace & cloud resources.
4. Activate organization in PostgreSQL and emit Kafka welcome event.

**Failure Case**: Step 3 (Kubernetes provisioning) fails due to cluster capacity.
In naive code, Stripe has charged the user's card, PostgreSQL has a draft record, and the system is left in a broken, half-provisioned state.

**How the Architecture Handles It via Sagas ([`src/features/organizations/workflows/organizations.workflow.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md))**:
```typescript
export const provisionOrganizationWorkflow: WorkflowDefinition = {
  name: "provision-organization-saga",
  steps: [
    {
      id: "step-db-draft",
      action: "callEntity",
      handler: "organizationRepository.createDraft",
      compensate: "organizationRepository.removeDraft",
    },
    {
      id: "step-payment-charge",
      action: "callClient",
      handler: "stripeClient.chargeSetupFee",
      compensate: "stripeClient.refundCharge", // Automatically refunds if later step fails
    },
    {
      id: "step-cloud-provision",
      action: "callClient",
      handler: "k8sProvisioningClient.createNamespace",
      compensate: "k8sProvisioningClient.deleteNamespace",
    },
    {
      id: "step-db-activate",
      action: "callEntity",
      handler: "organizationRepository.markActive",
    }
  ]
};
```
**Execution Engine ([`src/features/organizations/service/organizations.service.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md))**:
- The generic `runWorkflow(provisionOrganizationWorkflow, payload)` tracks execution spans.
- If Step 3 fails, the runner traverses backwards and executes compensating actions:
  1. Calls `stripeClient.refundCharge(chargeId)` (Customer refunded).
  2. Calls `organizationRepository.removeDraft(orgId)` (Database cleaned).
- Returns a deterministic error with full compensating execution trace.
- Zero orphaned state. Zero financial discrepancies.

---

### 9.3 Complex Scenario 3: Guaranteed Dual-Write via Transactional Outbox Pattern

**The Challenge**:
Updating an organization must update the database table AND publish an `OrganizationUpdatedEventV1` to Kafka.
If the database write succeeds but the Kafka broker is temporarily unreachable or the network partition drops the connection, the event is lost forever (inconsistent state). If Kafka publish happens before DB commit, and DB rollback occurs, downstream services process a ghost event.

**How the Architecture Solves It ([`src/infra/messaging/outbox/`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md))**:

```
[REST Handler / Service]
          │
          ▼
[PostgreSQL ACID Transaction]
 ┌────────────────────────────────────────────────────────┐
 │ 1. UPDATE organizations SET name = $1, tier = $2       │
 │ 2. INSERT INTO outbox_events (topic, payload, trace_id)│
 └────────────────────────────────────────────────────────┘
          │ (Single atomic commit - 100% ACID guarantee)
          ▼
 [PostgreSQL WAL / Storage]
          │
          ▼
[src/infra/messaging/outbox/outbox.poller.ts]
 (Or Debezium CDC Engine)
          │  Reads uncommitted outbox rows with SELECT FOR UPDATE SKIP LOCKED
          ▼
[src/infra/messaging/broker/kafka.broker.ts]
          │  Publishes to Kafka topic with injected W3C traceparent
          ▼
[Kafka Cluster: prod.identity.organization.updated.v1]
```

1. The service never calls the Kafka producer directly during write transactions.
2. The event is written to `database/migrations/0002_create_outbox_table.sql` in the **exact same transaction** as the entity update.
3. The background outbox relayer delivers events with at-least-once guarantee.
4. Downstream consumers employ idempotency deduplication (`idempotency_auditor.ts`).

---

### 9.4 Complex Scenario 4: Polymorphic Data Transformations & Nested ACL

**The Challenge**:
A legacy enterprise client sends webhook payloads with unpredictable nesting:
`{ org_info: { details: { company_nm: "Acme" } }, auth_configs: [ { type: "oidc", idp_url: "..." } ] }`.
The internal domain requires flat, normalized entities: `{ name: "Acme", authProvider: "oidc", ssoUrl: "..." }`.

**How the Architecture Handles It ([`src/features/organizations/schema/organizations.schema.ts`](file:///home/btpl-lap-22/live/llm-obs-node-packages/llm-obs-policies/rules/folderStructure/api.structure.working.rule.md))**:
Instead of writing 100 lines of brittle parsing logic across controllers:
```typescript
export const organizationSchema: EntitySchema<OrganizationEntity> = {
  name: "organization",
  endpoint: "/api/v1/organizations",
  fromApi: [
    { op: "pickDeep", sourcePath: "org_info.details.company_nm", targetField: "name" },
    { op: "transformUnion", discriminator: "auth_configs.0.type", mapping: {
        oidc: [
          { op: "rename", from: "auth_configs.0.idp_url", to: "ssoUrl" },
          { op: "default", field: "authProvider", value: "oidc" }
        ],
        saml: [
          { op: "rename", from: "auth_configs.0.metadata_xml_url", to: "ssoUrl" },
          { op: "default", field: "authProvider", value: "saml" }
        ]
      }
    }
  ],
  validate: organizationZodSchema
};
```
The Anti-Corruption Layer completely absorbs schema irregularities before data ever enters domain services.

---

## 10. Failure Diagnosis & Observability Operational Blueprint

When an operational incident occurs, engineers and AI assistants execute targeted failure diagnosis engines directly from `src/infra/observability/`:

```
                                  [Incident Alarmed / Error Spike]
                                                 │
                                                 ▼
                             [Step 1: Check Dependency RED Overlay]
                             src/infra/observability/topology/dependency_overlay.ts
                             -> ServiceDependencyRedOverlay.rankCandidateRootCauses()
                                                 │
                             ┌───────────────────┴───────────────────┐
                             ▼                                       ▼
                   [Single Request Failure]                 [System Resource Degraded]
                             │                                       │
        ┌────────────────────┴────────────────────┐      ┌───────────┴───────────┬───────────┐
        ▼                                         ▼      ▼                       ▼           ▼
[Deepest-Leaf Walk]                       [Diff Spans]   [Memory Leak]       [CPU Spike]   [Process Hang]
deepest_leaf_walker.ts                    trace_differ.ts heap_differ.ts     flame_differ.ts wait_for_graph.ts
-> findRootCauseSpan()                    -> diffSpans()  -> diffSnapshots() -> diffFlames() -> detectCycle()
        │                                         │
        ▼                                         ▼
[Inspect Storage Commit Ground Truth]     [Audit Idempotency & Causality]
wal_log_miner.ts                          idempotency_auditor.ts & version_vector.ts
-> tailWalForGroundTruth()                -> auditIdempotencyKey()
```

### Operational Incident Cheatsheet:
1. **Root Cause Isolation**: Run `DeepestLeafErrorWalker.findRootCauseSpan(trace)` to find the bottommost failing span, ignoring parent spans that merely re-threw errors.
2. **Behavioral Regressions**: Run `DifferentialTraceDiffer.diffAlignedSpans(goodTrace, badTrace)` to isolate which span duration or attribute drifted.
3. **Double Processing / Missing Events**: Run `IdempotencyKeyAuditorEngine.diagnoseDoubleProcessingCause()` to determine if failure was duplicate delivery or expired TTL.
4. **App Log vs DB Mismatch**: Run `DatabaseWalLogMiner.crossCheckAppLogAgainstWal()` to verify exact disk commits independent of application loggers.
5. **Slow Latency Spikes**: Run `GcPauseLatencyCorrelator.correlatePausesWithLatency()` to prove or rule out JVM/Go/V8 stop-the-world garbage collection pauses.
6. **Thread / Lock Hangs**: Run `WaitForGraphDeadlockEngine.detectCycle(waitForEdges)` to pinpoint lock cycle deadlocks.
7. **Multi-Node Deadlocks**: Trigger `ChandyMisraHaasProbeEngine.initiateProbe()` across transaction managers.

---

## 11. Developer & AI Daily Workflow Protocols

### Protocol 1: Creating a New Feature from Scratch (The 7-Step Sequence)
Never create service or handler files first. Follow this exact sequence:
1. **Contract**: Write `contracts/openapi/v1.yaml`. Run `scripts/generate.sh`.
2. **Migration**: Create `database/migrations/{NNNN}_create_{feature}_table.sql` and `.rollback.sql`. Update `database/schema.lock`.
3. **Port Interface**: Declare `src/shared/ports/{feature}.repository.port.ts`.
4. **Data Pillars**: Create `src/features/{feature}/`:
   - `schema/{feature}.schema.ts`
   - `queries/{feature}.queries.sql`
   - `rules/{feature}.rules.ts`
   - `machines/{feature}.machine.ts`
   - `workflows/{feature}.workflow.ts`
   - `types/{feature}.types.ts`
5. **Domain Service**: Write `src/features/{feature}/service/{feature}.service.ts`.
6. **Repository Implementation**: Write `src/features/{feature}/repository/{feature}.repository.ts`.
7. **Delivery Router & Handler**: Mount routes in `src/api/rest/v1/router/{feature}.router.ts` and handlers in `src/api/rest/v1/handlers/{feature}.handler.ts`.
8. **Test Suite**: Add unit (`tests/unit/`), integration (`tests/integration/`), and contract (`tests/contract/`) tests.

### Protocol 2: Modifying Existing Code Without Structural Drift
- **Adding a Column / Field**:
  1. Add migration: `database/migrations/{NNNN}_add_{field}_to_{entity}.sql`.
  2. Update schema contract: `src/features/{feature}/schema/{feature}.schema.ts` (`fromApi`, `toApi`).
  3. Update queries: `src/features/{feature}/queries/{feature}.queries.sql`.
  4. Update types: `src/features/{feature}/types/{feature}.types.ts`.
- **Banned Practices**:
  - Never embed inline SQL strings in services or handlers.
  - Never write manual object-mapping loops (e.g. `obj.a = raw.b`); use declarative schema operations.
  - Never wrap individual database calls in ad-hoc `try/catch` retries; use decorator composition.
  - Never place inline comments, mid-function notes, or scattered annotations inside functions, handlers, or loops; all algorithms must be documented exclusively in a single comprehensive header block at the top of the file.
  - Never use proprietary, ad-hoc, or non-standard messaging envelopes or tracing formats; all communications must adhere strictly to open standards (OpenTelemetry, W3C Trace Context, Kafka CloudEvents).

---

## 12. Non-Negotiable Architecture Guardrails (The 12 Invariants)

All PRs and automated code generation MUST pass these 12 invariants:

1. **Mandatory `.gitkeep`**: Every empty or scaffolded directory MUST include `.gitkeep` to preserve Git hierarchy.
2. **Sub-Line Tree Comment Syntax**: All directory comments in documentation MUST be placed on dedicated lines below each item using the `- description` syntax.
3. **No Inline Parenthetical Numbers**: Never write numbers in parentheses like `(8.1)` in directory tree comments.
4. **Strict Logic-Driven Naming**: File and class names must strictly conform to the formulas in §2. No random names allowed.
5. **Zero Inline SQL**: All database queries MUST be declared in `queries/{feature}.queries.sql`.
6. **Zero Direct DB/IO in Services**: Feature services import only abstract repository ports, never concrete DB drivers.
7. **No Speculative `v2` Contracts**: Never create a `v2` contract unless a breaking change is explicitly required.
8. **No Cross-Package Direct Imports**: Sub-packages communicate strictly via API contracts or generated client SDKs in `src/infra/clients/`.
9. **Centralized Infrastructure Re-use**: All database pooling, messaging pipelines, and tracing must use `src/infra/`. Never re-instantiate drivers inside features.
10. **100% Trace Context Propagation**: Every outgoing HTTP, gRPC, and Kafka message MUST inject W3C `traceparent` headers.
11. **Zero Inline Comments & Single Top-Side Algorithm Blueprint**: Implementation code bodies must never contain inline comments, mid-function notes, or scattered code explanations. The code itself must remain 100% clean and self-documenting. All end-to-end algorithmic blueprints, step-by-step logic, state transitions, prerequisites, and edge cases must be documented strictly in a single comprehensive header block at the very top of the file.
12. **Universal Open-Standard Interoperability (OpenTelemetry & Kafka)**: All services, handlers, adapters, and background workers must guarantee seamless interoperability with broader enterprise ecosystems by strictly conforming to established open standards:
    - OpenTelemetry tracing, metrics, and logs strictly adhering to OTel semantic conventions and W3C Trace Context propagation (`traceparent`, `tracestate`).
    - Kafka event streaming adhering to open event specifications (e.g., CloudEvents 1.0 standard) with schema registries and open messaging semantics.


