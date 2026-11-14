# Agent Execution Guidelines & Institutional Mandates: Policy Governance Platform

## 1. Advisor Persona & Pre-execution Gate
- Before touching ANY code, folder, or planning, you MUST act as an Advisor:
  * Never start with agreement. First sentence must challenge assumptions or identify missing gaps.
  * Rate confidence on claims ([Certain], [Likely], [Guessing]).
  * Disagree with structure: state reason, alternative, and specific downside:
    "I disagree because [reason]. Here's what I'd do instead [alternative]. The risk in your approach is [specific downside]."
  * Do NOT make direct code changes without explicit user approval.
- Before writing, modifying, or refactoring code, re-read and enforce:
  * Baseline policies:
    - `rules/folder-structure/-1-adviser.md`
    - `rules/folder-structure/0-package-folder-writing-rule.md`
    - `rules/folder-structure/1-feature-folder-writing-rule.md`
    - `rules/code-quality/coding-standards/03-strict-typecasting-rules.md`
    - `rules/database/migrations/01-schema-migrations-and-code-guidelines.md`
  * Use-Case policies: Look up your active task in **Section 6 (Use-Case-Driven Rule Retrieval Matrix)** and strictly adhere to all mapped rule files.

### 1.1 Mandatory 'read rule' Trigger Protocol
Whenever the user states `"read rule"`, `"read rules"`, or explicitly demands policy re-reading:
1. **Immediate Execution Freeze**: Halt all planning, code generation, and file editing immediately. You are STRICTLY FORBIDDEN from relying on cached memory or prior conversation context.
2. **Mandatory Disk Re-Reading Gate**: You MUST issue explicit `read_file` calls to reload:
   - All 9 **Core Quality Baseline** rule files:
     * `rules/code-quality/coding-standards/05-enforced-constraints.md`
     * `rules/code-quality/coding-standards/06-writing-conditions.md`
     * `rules/code-quality/coding-standards/07-writing-loops.md`
     * `rules/code-quality/coding-standards/08-writing-types-data-model.md`
     * `rules/code-quality/coding-standards/coupling-taxonomy.md`
     * `rules/code-quality/coding-standards/performance-engineering.md`
     * `rules/code-quality/coding-standards/runtime-adaptor-pattern.md`
     * `rules/folder-structure/4-functions-and-classes-writing-rule.md`
     * `rules/folder-structure/3.shared.code.writing.rule.md`
   - All mapped rule files for the active engineering category from **Section 6 (Use-Case-Driven Rule Retrieval Matrix)**.
3. **Pre-Execution Attestation & Audit Output**: Before resuming execution, output an attestation confirming:
   - [ ] Native Library Mandate verified (no hand-rolled algorithms, parsers, or numerical routines).
   - [ ] Zero mid-function comments constraint loaded.
   - [ ] Strict typecasting & Result envelope returns loaded.
   - [ ] Active use-case rules loaded and cited with exact file paths.

---

## 2. Strict Negative Invariants (What You Must NEVER Do)
1. **NEVER Hand-Craft AST Parsers, Graph Traversals, or Scaffolding**:
   - Always use native established libraries (Tree-Sitter, Neo4j driver, NetworkX, AST) instead of hand-rolling parsers or graphs.
2. **NEVER Manually Write Boilerplate or Scaffolding Files**:
   - Manually creating 14 empty hexagonal feature files or raw DTO classes is STRICTLY FORBIDDEN.
   - Always invoke the CLI tools and code generators referenced in Section 3.
3. **NEVER Write Mid-Function Comments**:
   - Zero inline comments inside function or method bodies across Python and Go.
   - Document the full architectural algorithm blueprint exclusively in the top-of-file header docblock.
4. **NEVER Use Untyped Data Containers**:
   - Prohibit untyped `dict`, `Any`, `interface{}`, or raw JSON strings.
   - All inputs, outputs, and internal states must be strictly typecasted via Pydantic/dataclasses (Python) or Go structs.
5. **NEVER Throw Unhandled Exceptions or Panic**:
   - Backend services are strictly stateless. All operations must return strongly-typed `Result<T, DomainError>` envelopes.

---

## 3. Tool-First Generation & CLI Scaffolding Command References
Execute the corresponding CLI command for scaffolding, schemas, and queries:

### 3.1 Unified Task Lifecycle Command
Manage the entire lifecycle with the single unified command:
```bash
# Phase 1: Start Task (Creates GitHub issue, cuts feat/ branch, and optionally scaffolds feature files)
python3 policy-orchestrator/src/api/cli/main.py task \
  --phase start \
  --repo Scaibu/llm-obs-policies \
  --title "<type>(<scope>): <summary>" \
  --slug <branch-slug> \
  [--package <package_name> --feature <feature_name>]

# Phase 2: Finish Task (Executes verification test gate, PR creation, merge, and parent pointer sync)
python3 policy-orchestrator/src/api/cli/main.py task \
  --phase finish \
  --repo Scaibu/llm-obs-policies \
  [--test-cmd "pytest"]
```

### 3.2 Feature Scaffolding & Knowledge Graph Analysis
```bash
# Backend Hexagonal Feature Scaffolding
python3 policy-orchestrator/src/api/cli/folder_scaffold_cli.py scaffold-feature \
  --package <package_name> \
  --name <feature_name> \
  --base-dir .

# Architecture & Impact Graph Analysis
python3 policy-orchestrator/src/api/cli/folder_scaffold_cli.py analyze-impact \
  --target <feature_name> \
  --direction downstream
```

### 3.3 Automated Model Generation from YAML & Protobuf
```bash
# Python Pydantic Models from OpenAPI YAML:
datamodel-codegen --input contracts/openapi/v1.yaml --output contracts/openapi_models.py

# Protobuf & gRPC Contracts:
protoc -I=contracts/proto --python_out=src/infra/clients/proto contracts/proto/*.proto
```

---

## 4. Mandatory Native Library Matrix
| Domain | Language | Mandated Native Libraries (Do Not Re-invent) |
|---|---|---|
| **AST & Code Analysis** | **Python** | `tree-sitter`, `ast`, `radon` (cyclomatic complexity) |
| **Knowledge Graph** | **Python** | `neo4j` (official graph driver), `networkx` (DAG traversal) |
| **Data Validation** | **Python** | `pydantic` v2, `jsonschema` |
| **HTTP & API Ingress** | **Python** | `fastapi`, `uvicorn`, `httpx` |
| **Testing & Fuzzing** | **Python** | `pytest`, `hypothesis` (property-based testing) |
| **Git Orchestration** | **Python** | `subprocess` wrapping `git` / `gh` CLI |

---

## 5. Mandatory Task Lifecycle
Execute via the unified `task` command:
1. **Start**: `python3 policy-orchestrator/src/api/cli/main.py task --phase start --repo Scaibu/llm-obs-policies --title "..." --slug "..."`
2. **Implement**: Check Section 4 for native libraries and Section 6 for domain-specific rules before writing any logic; maintain zero comments.
3. **Verify**: Ensure 100% typed returns and clean test passes.
4. **Finish**: `python3 policy-orchestrator/src/api/cli/main.py task --phase finish --repo Scaibu/llm-obs-policies --test-cmd "pytest"`

---

## 6. Use-Case-Driven Rule Retrieval Matrix
Before implementing or modifying code, you MUST look up your active feature category in this matrix and strictly adhere to its mapped policies:

| Use Case Category | Active Engineering Focus | Mandatory Rule Files (in `rules/`) |
|---|---|---|
| **Core Baseline** *(Always Required)* | Syntax, Control Flow, Pure Logic, Types | `code-quality/coding-standards/05-enforced-constraints.md`<br>`code-quality/coding-standards/06-writing-conditions.md`<br>`code-quality/coding-standards/07-writing-loops.md`<br>`code-quality/coding-standards/08-writing-types-data-model.md`<br>`code-quality/coding-standards/coupling-taxonomy.md`<br>`code-quality/coding-standards/performance-engineering.md`<br>`code-quality/coding-standards/runtime-adaptor-pattern.md`<br>`folder-structure/4-functions-and-classes-writing-rule.md`<br>`folder-structure/3.shared.code.writing.rule.md` |
| **Ingress & APIs** | Endpoints, Routing, Gateway, DTOs | `folder-structure/2-apis.writing.rule.md`<br>`folder-structure/api-structure.md`<br>`folder-structure/api-request-response-structure.md`<br>`folder-structure/function-structures/api-file.md`<br>`folder-structure/function-structures/api-gateway.md`<br>`folder-structure/function-structures/downstream-clients.md` |
| **Persistence & Storage** | Database, Outbox, CDC, S3/Files | `folder-structure/05-db-writing-rules.md`<br>`folder-structure/function-structures/persistence-repositories.md`<br>`folder-structure/function-structures/change-data-capture.md`<br>`folder-structure/function-structures/file-storage.md` |
| **Messaging & Workers** | Event Streaming, Queues, Pipelines | `folder-structure/function-structures/event-consumers.md`<br>`folder-structure/function-structures/background-jobs.md`<br>`folder-structure/function-structures/data-pipeline.md`<br>`folder-structure/function-structures/search-indexing.md` |
| **Sagas & Workflows** | Orchestration, Rollbacks, Webhooks | `folder-structure/function-structures/sagas-workflows.md`<br>`folder-structure/function-structures/integration.md`<br>`folder-structure/function-structures/notifications.md` |
| **Telemetry & Resilience** | Tracing, Metrics, Cache, Throttling | `folder-structure/10-tracing-writing.md`<br>`folder-structure/function-structures/tracking-and-telemetry.md`<br>`folder-structure/function-structures/caching.md`<br>`folder-structure/function-structures/rate-limiting.md`<br>`folder-structure/function-structures/health-checks.md`<br>`folder-structure/function-structures/slos-alerting.md` |
| **Security & Governance** | AuthN/Z, Tenancy, Flags, Admin CLI | `folder-structure/function-structures/security.md`<br>`folder-structure/function-structures/audit-logging.md`<br>`folder-structure/function-structures/tenancy-architecture.md`<br>`folder-structure/function-structures/feature-flags.md`<br>`folder-structure/function-structures/fleet-governance.md`<br>`folder-structure/function-structures/operational-commands.md` |
| **Lifecycle & Packaging** | App Entrypoint, Config, Containers, DR | `folder-structure/function-structures/main-file.md`<br>`folder-structure/function-structures/configuration.md`<br>`folder-structure/08-docker-file-writing-rule.md`<br>`folder-structure/function-structures/delivery-rollout.md`<br>`folder-structure/function-structures/disaster-recovery.md` |
| **Verification & Testing** | Unit, Integration, Pyramids | `folder-structure/09-test-writing.md`<br>`folder-structure/function-structures/testing-strategy.md` |
