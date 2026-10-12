---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_PACKAGE_CREATION"
agent_role: "Lead Systems Architect & Package Structure Compliance Enforcer"
target_scope: "All Polyglot Sub-Packages, Services & Workspace Directory Scaffolding"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Package Folder Structure and Sequential Scaffolding Order

(Universal Language-Agnostic Operational Rule for Polyglot Sub-Packages in Go, Python, Rust, Dart, Java, C#, C++, Node.js/TypeScript)

---

## 2. Strict Package Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Sub-Package Isolation Boundary
No sub-package may import source code directly from another sub-package. All inter-package communication must route through published versioned contracts and generated client SDKs under src/infra/clients/.

Guardrail 2: Contract-First Inviolability
No implementation source code inside src/ may be created or modified until the corresponding API contract specification (contracts/openapi/, contracts/graphql/, contracts/proto/, contracts/asyncapi/) is merged in a contract-only PR.

Guardrail 3: Single Contract Selection
Each feature endpoint selects exactly one contract format (REST OpenAPI, GraphQL SDL, gRPC Proto, or AsyncAPI + JSON Schema). Speculative generation of unused contract types is strictly prohibited.

Guardrail 4: Centralized Infrastructure Invariant
All database connection pools, Kafka client factories, and driver adapters must reside in src/infra/. Domain features and HTTP handlers must never open raw connections or import driver adapters directly.

Guardrail 5: Pure Shared Libraries
src/shared/ must contain zero business logic, zero state mutations, and zero network/disk IO.

Guardrail 6: Mandatory Hierarchy Preservation
Every directory in the package structure must include a .gitkeep file to guarantee directory hierarchy persistence across Git operations.

Guardrail 7: Declarative Configuration Safety
Raw process.env or unvalidated environment lookups inside domain features or handlers are strictly prohibited. All environment variables must be validated against config/env.schema via src/infra/config/ before service boot.

Guardrail 8: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies across any layer. Document the full architectural execution blueprint at the top of the file in the header docblock.

Guardrail 9: Pure CLI Scaffolding Invariant (Zero REST API for Scaffolding)
Never invoke, expose, or rely on HTTP/REST APIs for creating directories, scaffolding sub-packages, or synchronizing workspace knowledge graphs. All package creation, file scaffolding, and workspace scanning must be executed strictly via local CLI subcommands (`scaffold-package`, `graph-scan`) or direct domain services.

---

## 1. Mandatory Sequential Package Scaffolding Order

When creating or refactoring any sub-package or service, create directories and files in this exact sequential order:

1. contracts/
Authoritative contract specifications (contracts/openapi/, contracts/graphql/, contracts/proto/, contracts/asyncapi/, contracts/json-schema/). Merged in a dedicated contract step before any implementation source code is written.

2. config/
Environment variable validation schema (config/env.schema) and runtime environment manifests (config/default.yaml, config/development.yaml, config/production.yaml, config/test.yaml, config/feature-flags.yaml).

3. database/
Declarative database persistence specifications:
- database/migrations/ (NNNN_description.sql and NNNN_description.rollback.sql)
- database/rls/ (Row Level Security tenant isolation policies)
- database/indexes/ (Performance and foreign key index specs)
- database/partitioning/ (Range, hash, and directory partitioning specs)
- database/storage_engine/ (LSM, tiered, hot/cold archiving, polyglot specs)
- database/replication/ (Topology specs and chain replication)
- database/consensus/ (Raft consensus and WAL shipping specs)
- database/quorums/ (Quorum rules and ACK policies)
- database/cdc/ (Change Data Capture publisher and sink specs)
- database/sharding/ (Shard hash ring maps)
- database/crdts/ (CRDT definitions and hybrid logical clock specs)
- database/anti_entropy/ (Merkle tree sync and repair jobs)
- database/fencing/ (Epoch fencing failover scripts)
- database/retention/ (Compliance retention and soft-delete purge jobs)
- database/seeds/ (Development and test seed fixtures)
- database/schema.lock (Cryptographic checksum lockfile of applied migrations)

4. messaging/
Declarative streaming and event management specifications:
- messaging/topics/ (Topic provisioning JSON specs and rollback pairs)
- messaging/schema-registry/ (Avro, Protobuf, or JSON Schema event contracts)
- messaging/dlq/ (Dead Letter Queue retry policies)
- messaging/subscriptions/ (Consumer group declarations and topic mappings)
- messaging/topics.lock (Cryptographic checksum lockfile of provisioned topics)

5. deploy/
Infrastructure deployment specifications:
- deploy/k8s/ (Kubernetes manifests: Deployment, Service, HPA, ConfigMap)
- deploy/helm/ (Helm packaging chart and values manifests)

6. src/shared/
Package-internal repeating utilities with zero business logic and zero IO:
- src/shared/utils/ (Pure date, string, crypto formatting helpers)
- src/shared/constants/ (System constants and HTTP header constants)
- src/shared/errors/ (Standard ApplicationError classes and envelope wrappers)
- src/shared/types/ (Pagination, result envelopes, common utility types)

7. src/infra/
Centralized infrastructure runtime engines:
- src/infra/config/ (Strongly-typed configuration loader and secrets resolver)
- src/infra/database/ (Connection pools, factories, transaction manager, query executor, middleware, driver adapters)
- src/infra/messaging/ (Kafka broker client, factories, typed event producers, consumers, middleware, CQRS dispatcher)
- src/infra/clients/ (Generated upstream service client SDKs - never hand-written)
- src/infra/observability/ (OpenTelemetry tracer, logical clocks, profiler, race detector, deadlock engine, heap differ, eBPF probes, transition logger, failure diagnosticians)

8. src/features/{feature-name}/
Isolated business domain feature modules scaffolding all 10 mandatory roles according to feature-folder-structure.md (context.yml, index, schema/, queries/, rules/, machines/, workflows/, repository/, service/, types/).

9. src/api/
Delivery ingress adapters mapping external protocols to domain services:
- src/api/rest/v1/ (REST handlers, routers, and route rules)
- src/api/graphql/v1/ (GraphQL schemas, resolvers, dataloaders)
- src/api/grpc/v1/ (gRPC server stubs and handlers)
- src/api/events/ (Event consumers and event publishers)

10. Root Package Manifests and Scripts
- scripts/ (run.sh, migrate.sh, test.sh, generate.sh)
- Dockerfile and Dockerfile.dev (Multi-stage container builds)
- docker-compose.yml (Isolated test and runtime infrastructure)
- .env.example, .package-meta.yaml, .port-registry

---

## 2. Strict Package Guardrails

Guardrail 1: Sub-Package Isolation Boundary
No sub-package may import source code directly from another sub-package. All inter-package communication must route through published versioned contracts and generated client SDKs under src/infra/clients/.

Guardrail 2: Contract-First Inviolability
No implementation source code inside src/ may be created or modified until the corresponding API contract specification (contracts/openapi/, contracts/graphql/, contracts/proto/, contracts/asyncapi/) is merged in a contract-only PR.

Guardrail 3: Single Contract Selection
Each feature endpoint selects exactly one contract format (REST OpenAPI, GraphQL SDL, gRPC Proto, or AsyncAPI + JSON Schema). Speculative generation of unused contract types is strictly prohibited.

Guardrail 4: Centralized Infrastructure Invariant
All database connection pools, Kafka client factories, and driver adapters must reside in src/infra/. Domain features and HTTP handlers must never open raw connections or import driver adapters directly.

Guardrail 5: Pure Shared Libraries
src/shared/ must contain zero business logic, zero state mutations, and zero network/disk IO.

Guardrail 6: Mandatory Hierarchy Preservation
Every directory in the package structure must include a .gitkeep file to guarantee directory hierarchy persistence across Git operations.

Guardrail 7: Declarative Configuration Safety
Raw process.env or unvalidated environment lookups inside domain features or handlers are strictly prohibited. All environment variables must be validated against config/env.schema via src/infra/config/ before service boot.

Guardrail 8: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies across any layer. Document the full architectural execution blueprint at the top of the file in the header docblock.

Guardrail 9: Pure CLI Scaffolding Invariant (Zero REST API for Scaffolding)
Never invoke, expose, or rely on HTTP/REST APIs for creating directories, scaffolding sub-packages, or synchronizing workspace knowledge graphs. All package creation, file scaffolding, and workspace scanning must be executed strictly via local CLI subcommands (`scaffold-package`, `graph-scan`) or direct domain services.

---

## 3. AI Agent Execution Instructions: Package Scaffolding & Workspace Protocol

### Instruction 1: Mandatory Package Scaffolding via CLI
When requested to create or initialize a new polyglot sub-package or service root, NEVER create directories or `.gitkeep` files manually.
You MUST execute the package scaffolder via the CLI:
```bash
python3 -m src.api.cli.main scaffold-package <package_name> --base-dir <target_dir>
```
**Rationale:** This automatically creates the exact 10-subsystem package structure (`contracts/`, `config/`, `database/`, `messaging/`, `deploy/`, `src/shared/`, `src/infra/`, `src/api/`, `scripts/`) with `.gitkeep` files and registers the `PackageRoot` node in the Knowledge Graph.

### Instruction 2: Workspace Discovery & DAG Synchronization
When exploring, onboarding, or indexing an existing repository or workspace, execute:
```bash
python3 -m src.api.cli.main graph-scan .
```
**Rationale:** Automatically streams repository files, infers architectural roles, auto-discovers all feature packages, and establishes spatial (`PackageRoot -> Feature`) and hexagonal DAG relationships.



