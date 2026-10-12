---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_FEATURE_CREATION"
agent_role: "Lead Systems Architect & Feature Structure Compliance Enforcer"
target_scope: "All Feature Creation, Refactoring, Code Generation & Maintenance"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Feature Folder Structure and Sequential File Creation Order

(Universal Language-Agnostic Operational Rule for Polyglot Sub-Packages in Go, Python, Rust, Dart, Java, C#, C++, Node.js/TypeScript)

---

## 1. Mandatory Sequential File Creation Order

When creating or refactoring any feature, create files in this exact sequential order:

1. context.yml
which will hold agent related working memories 

2. types/{feature}.types.[ext]
Define feature-local domain models, input DTOs, output DTOs, and type definitions.

3. schema/{feature}.schema.[ext]
Define runtime validation schema and bidirectional anti-corruption layer mappings (fromApi and toApi).

4. queries/{feature}.queries.[ext|sql]
Define named parameterized SQL queries using the FLOW_{VERB}_{ENTITY}_{CRITERIA} formula.

5. repository/{feature}.repository.port.[ext]
Define the abstract hexagonal port interface for data operations.

6. repository/{feature}.repository.[ext]
Implement the concrete repository adapter that executes the named SQL queries against the database pool.

7. rules/{feature}.rules.[ext]
Define business logic decision tables as structured data with priority weights and deny-override semantics.
- all if else logic will goes here 

8. machines/{feature}.machine.[ext] 
Define the state machine lifecycle DAG with deterministic transition triggers and guard conditions.

9. workflows/{feature}.workflow.[ext]
Define the multi-step automation DAG steps array.

10. service/{feature}.service.[ext]
Implement the pure domain service injecting the repository port and executing rules and machines with zero HTTP or raw DB driver imports.

11. index.[ext]
Export the public feature facade (domain service and public types only). Never export repositories, drivers, or raw queries.

12. src/api/rest/v1/handlers/{feature}.handler.[ext]
Implement the HTTP delivery handler that validates requests, invokes the domain service, and returns the RFC standardized envelope (success, statusCode, data, meta).

13. src/api/rest/v1/routers/{feature}.router.[ext]
Mount the feature endpoints on the API gateway router.

---

## 2. The 10-Role Mandatory Feature Inventory

Every feature directory under `src/features/{feature-name}/` is automatically scaffolded via `scaffold-feature` with these 10 mandatory roles:

1. `context.yml`: Feature domain boundaries, invariants, and ports.
2. `index.[ext]`: Public facade exporting domain service and public types only.
3. `schema/{feature}.schema.[ext]`: Validation schema and declarative ACL mappers (`fromApi`, `toApi`).
4. `queries/{feature}.queries.[ext|sql]`: Named parameterized SQL queries (`FLOW_*`).
5. `rules/{feature}.rules.[ext]`: Business decision tables evaluated as data.
6. `machines/{feature}.machine.[ext]`: Deterministic state transition lifecycle graphs.
7. `workflows/{feature}.workflow.[ext]`: Multi-step automation DAG steps.
8. `repository/{feature}.repository.port.[ext]`: Hexagonal domain port interface.
9. `repository/{feature}.repository.[ext]`: Persistence adapter executing queries.
10. `service/{feature}.service.[ext]`: Pure domain orchestrator with zero DB/HTTP imports.
11. `types/{feature}.types.[ext]`: Domain models, inputs, and DTO types.

*(The complete reference directory tree is documented in [api-structure.md](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/folderStructure/api-structure.md))*


---

## 3. Universal Language-Agnostic Naming Formula

All files follow the deterministic formula:
{feature}.{role}.[ext] (or {feature}_{role}.[ext] for languages requiring snake_case identifiers)

- Domain Context: context.yml
- Public Facade: index.[ext]
- Schema and ACL: schema/{feature}.schema.[ext]
- Flow Queries: queries/{feature}.queries.[ext|sql]
- Rules as Data: rules/{feature}.rules.[ext]
- State Machine: machines/{feature}.machine.[ext]
- Workflow DAG: workflows/{feature}.workflow.[ext]
- Repository Port: repository/{feature}.repository.port.[ext]
- Repository Impl: repository/{feature}.repository.[ext]
- Domain Service: service/{feature}.service.[ext]
- Domain Types: types/{feature}.types.[ext]
- REST Handler: src/api/rest/v1/handlers/{feature}.handler.[ext]
- REST Router: src/api/rest/v1/routers/{feature}.router.[ext]

---

## 4. Strict Guardrails

Guardrail 1: 10-File Inventory Inviolability
Every feature must contain all 10 feature roles. Never omit schema, queries, rules, machines, workflows, repository port, repository impl, service, types, or context.yml.

Guardrail 2: Hexagonal Dependency Inversion
Domain service must import only repository port interface. Never import concrete database drivers, ORMs, connection pools, or HTTP frameworks into domain services.

Guardrail 3: Zero Inline SQL
Raw SQL strings are strictly prohibited inside services, repositories, and handlers. All queries must be declared inside queries.sql using named FLOW_{VERB}_{ENTITY}_{CRITERIA} constants.

Guardrail 4: Anti-Corruption Layer Isolation
External API wire contract changes must be mapped inside schema via fromApi and toApi. Never modify internal domain models or database columns to satisfy external wire changes.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments or annotations inside function bodies. Document the entire algorithm once at the top of the file in the header docblock.

Guardrail 6: Public Facade Boundary
Other features and API routers must import only from the feature index file. Never deep-import internal repositories, queries, or service internals across feature boundaries.

Guardrail 7: Strict Response Envelope
All HTTP delivery handlers must return standardized RFC response envelopes containing success, statusCode, data or error, and meta blocks with W3C trace IDs.

Guardrail 8: Zero File Duplication
Maintain exactly one file per role. Never create duplicate variations of files with mixed dot or underscore naming.

Guardrail 9: Pure CLI & Domain Execution Invariant (Zero REST API for File Operations)
Never invoke, expose, or rely on HTTP/REST APIs for creating files, scaffolding feature structures, or synchronizing the architectural knowledge graph. All file generation, scaffolding, and graph synchronization operations must be performed strictly via deterministic local CLI commands (`scaffold-feature`, `create-file`, `link-file`) or direct domain services.

---

## 5. AI Agent Execution Instructions: Scaffolding & Graph Protocol

### Instruction 1: Mandatory Automated Scaffolding
When requested to create, scaffold, or initialize a new feature, NEVER manually create individual directories or empty files using raw filesystem writes.
You MUST execute the feature scaffolder via the CLI:
```bash
python3 -m src.api.cli.main scaffold-feature <feature_name>
```
*(If scaffolding inside a sub-package, pass `--base-dir packages/<package>/src/features --package-root packages/<package>`)*

**Rationale:** This guarantees all 10 mandatory roles and ingress handlers are generated in strict sequential order and instantly registers the 25+ node hexagonal DAG in the Knowledge Graph.

### Instruction 2: Mandatory `create-file` for Single File Additions
When adding a new auxiliary file (e.g. an additional rule set, specialized repository adapter, or shared helper), NEVER create an orphan file on disk. You MUST execute:
```bash
python3 -m src.api.cli.main create-file --path <file_path> --role <Role> --rel <RelationshipType> --target <target_node_or_file> --direction incoming
```
**Rationale:** Enforces that every newly created file is bound immediately to its upstream/downstream collaborator in the Knowledge Graph.

### Instruction 3: Connecting Existing Components via `link-file`
When introducing cross-feature communication, event pub/sub delivery, or shared library dependencies between existing files, you MUST execute:
```bash
python3 -m src.api.cli.main link-file --source <source> --rel <RelationshipType> --target <target>
```

### Instruction 4: Sequential Content Population
After executing automated scaffolding, populate the business logic into the generated files in the exact order defined in Section 1 (`context.yml` -> `types` -> `schema` -> `queries` -> `repository port` -> `repository adapter` -> `rules` -> `machine` -> `workflow` -> `service` -> `index` -> `handler` -> `router`). Always preserve the Zero-Inline-Comment header docblock doctrine.



