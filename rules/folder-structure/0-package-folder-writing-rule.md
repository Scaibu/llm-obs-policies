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

1. database/
Consolidated declarative database migrations, seeds, runtime engine, and topology configuration:
- database/schema.lock (Cryptographic checksum lockfile of applied migrations)
- database/migrations/sql/ (.gitkeep - SQL schema migrations & rollbacks)
- database/migrations/cypher/ (.gitkeep - Cypher graph migrations)
- database/seeds/ (dev_seeds.sql, test_seeds.sql - development and integration fixtures)
- database/engine/ (connection.py, transaction.py, executor.py, runner.py - database runtime engine)
- database/config/ (rls.sql - Row Level Security policies, topology.yaml - replication & quorums)

2. messaging/
Declarative streaming, topic management, schemas, policies, and messaging runtime engine:
- messaging/topics.lock (Cryptographic checksum lockfile of provisioned topics)
- messaging/topics/ (Declarative topic provisioning manifests - topics.yaml)
- messaging/schemas/ (Event schema registry contracts - Avro, Protobuf, JSON Schema)
- messaging/policies/ (Dead Letter Queue & retry policies - dlq_policy.yaml)
- messaging/engine/ (Centralized runtime engine: client/, producers/, consumers/, pipeline/)

3. deploy/
Multi-target polyglot infrastructure deployment and release specifications:
- deploy/docker/ (base/Dockerfile.base, base/registry.yaml, service/Dockerfile, service/Dockerfile.dev, compose/docker-compose.single.yml, compose/docker-compose.polyglot.yml, compose/docker-compose.infra.yml)
- deploy/k8s/ (base/deployment.yaml, service.yaml, hpa.yaml, configmap.yaml, ingress.yaml, pdb.yaml, overlays/local-polyglot, dev, staging, prod)
- deploy/helm/ (Chart.yaml, Chart.lock, values.yaml, env-values/values.{dev,staging,prod}.yaml, templates/_helpers.tpl, templates/deployment.yaml, service.yaml, ingress.yaml, hpa.yaml, pdb.yaml, packaging/package.sh, packaging/publish.sh)
- deploy/argocd/ (project.yaml, applicationset.yaml, applications/app.{dev,staging,prod}.yaml)
- deploy/terraform/ (backend.tf, versions.tf, main.tf, variables.tf, outputs.tf, environments/{dev,staging,prod}.tfvars, modules/stateful/{database,storage,cache,secrets}.tf, modules/stateless/{compute,ingress,autoscaling}.tf, modules/security/{iam,security_groups,kms}.tf)
- deploy/topology/ (network_map.yaml - declares hostnames, ports & protocols for sibling services)
- deploy/release/ (deploy.sh, rollback.sh)

4. src/
Application core source code:
- src/main.[ext] (Root application bootstrap, DI wiring, and server runner adhering strictly to 07-main-file.md 9-phase lifecycle)
- src/api/ (Delivery ingress and contract specifications: contracts/, rest/v1/, graphql/v1/, grpc/v1/, events/)
- src/features/{feature-name}/ (Hexagonal domain feature modules: contracts/, domain/, infrastructure/, service/, tests/)
- src/infra/ (Centralized infrastructure adapters: config/, clients/, observability/)
- src/shared/ (Pure reusable utilities with zero IO and zero business logic: constants/, utils/, errors/, types/)

5. scripts/
Operational and lifecycle runner automation:
- scripts/run/ (run.sh, run.prod.sh)
- scripts/migrate/ (migrate.sh, rollback.sh)
- scripts/test/ (test.unit.sh, test.integration.sh, test.e2e.sh)
- scripts/generate/ (generate.contracts.sh, generate.clients.sh)

6. Root Package Manifests and Ignore Files
- .gitignore, .dockerignore, .helmignore
- .env.example, .package-meta.yaml, .port-registry
- pyproject.toml / package.json / Cargo.toml / go.mod

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



