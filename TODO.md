# TODO — LLM Obs Policies (Senior/Staff System Architect prep)

Contents: `rules/` (engineering standards + agent rules), `gcd/` (GCP/Kubernetes reference), `policy-orchestrator/` (Python FastAPI; zero-clone git features; AlloyDB + Neo4j lineage; ADRs 0001-0006).
Primary company fit: **Anthropic** (agent safety, governance, LLM observability, secure code-mutating agents), **Google** (cloud architecture, engineering standards, readability culture), Stripe (API/design rigor, engineering conventions), Neo4j (lineage-in-graph).

Current state: no root README; duplicate `ADR-0001`, no `ADR-0002`; `.pytest_cache` and `__pycache__` present in the tree; folder-name typos (`algorithems`, `requirment-clarifications`).

Every WP has an **AC**. Not done until demonstrated.

---

## 0. Definition of done for "interview-ready"
- [ ] You can present this repo as "how I make architecture enforceable at scale" in 10 minutes
- [ ] You can show at least 3 rules that are machine-enforced (not just prose) with measured violations before/after
- [ ] You can discuss the safety model of an agent that mutates remote repos, including its failure modes
- [ ] GCP landing-zone design doc exists and you can defend each boundary

## 1. Repo hygiene and structure (quick wins first)
- [ ] Add root `README.md`: purpose, map, how the four platform repos consume it, how to contribute a rule
- [ ] Add `.gitignore` for `__pycache__/`, `.pytest_cache/`, `.venv`; remove tracked artifacts (`git rm -r --cached`)
- [ ] Resolve ADR numbering: rename duplicate `ADR-0001-*`, add `ADR-0002` or document the gap; add `docs/adr/README.md` index with status (proposed/accepted/superseded)
- [ ] Rename misspelled folders (`algorithems` -> `algorithms`, `requirment-clarifications` -> `requirement-clarifications`) AFTER grepping all repos for references; one commit, update links
- [ ] Add CODEOWNERS and a rule-change PR template (rationale, enforcement, rollout, rollback)
- **AC:** link checker passes across all markdown; `git status` clean after running tests

## 2. Rules as an enforceable system (`rules/`)
- [ ] Inventory table (`rules/INDEX.md`): rule id, text, severity, audience (human/agent), enforcement (linter / CI check / review / agent prompt), owner, last reviewed
- [ ] Rule IDs stable and referenced in code review comments and agent output
- [ ] Machine-checkable conversion — pick the top 10 rules and implement checks:
  - [ ] folder-structure checks (feature folder contains expected files; `context.yml` has matching code) — start with `distributed-transaction-engine`, many features only have `context.yml`
  - [ ] commit-message and branch-name lint (`rules/git`) via commit-msg hook + CI
  - [ ] no raw SQL string concatenation, no floats for money, no secrets in repo (gitleaks)
  - [ ] import-boundary checks for hexagonal architecture (domain must not import infra) via `import-linter` (Python) / `depguard` or `go-arch-lint` (Go)
  - [ ] API structure/contract lint (OpenAPI via Spectral)
  - [ ] migration safety checks (no blocking `ALTER` without expand/contract)
  - [ ] test-presence rule (each feature has tests; coverage threshold on changed lines)
  - [ ] docs presence (architecture/performance/security doc templates exist for each service)
- [ ] Measure: violations per rule before/after across the four repos; chart in `docs/rule-adoption.md`
- [ ] `rules/edge-cases`: for each distributed-systems edge case, link the drill/test in the corresponding platform repo (traceability matrix)
- [ ] `rules/doc-template`: produce one real architecture, performance and security doc using the templates for a platform repo; revise templates from the friction
- [ ] `rules/algorithems` (-> algorithms) and `rules/database`: add a worked example with measurements (query-optimization before/after EXPLAIN; algorithm choice with complexity and benchmark)
- [ ] Rule lifecycle doc: propose -> RFC -> trial (warn) -> enforce -> review -> deprecate; sunset policy so rules don't rot
- **AC:** CI on each platform repo fails on a deliberately introduced violation of each of the 10 rules

## 3. Agent rules and evaluation (`rules/agents`)
- [ ] For `code-generator`, `code-reviewer`, `policy-guardian`: define purpose, tools, permissions, inputs/outputs, failure behavior
- [ ] Build an eval harness: 50 real diffs (good, bad, subtle) with labeled expected findings; measure precision/recall of reviewer and guardian; track cost and latency per diff
- [ ] Prompt versioning: prompts in repo, semver, changelog, eval gate on change (no prompt change merges without eval run)
- [ ] Prompt-injection tests for agents that read untrusted content (PR descriptions, code comments, README files containing instructions)
- [ ] Define human-approval points: anything irreversible or outward-facing (push, merge, deploy, delete) requires explicit approval; default dry-run
- [ ] Agent observability: trace each run (inputs, tool calls, outputs, tokens, latency, cost, decision), searchable; redact secrets/PII
- **AC:** eval report committed; regression gate in CI; injection test suite passes

## 4. policy-orchestrator service
### 4.1 Architecture and docs
- [ ] C4 diagrams + sequence diagrams for each feature (`git_remote_inspector`, `git_remote_mutator`, `git_branch_lifecycle`, `git_verifier`, `git_submodule_manager`, `folder_scaffold`, `module_resolver`, `code_search`, `file_search`)
- [ ] Review ADR-0001 (x2), 0003, 0004, 0005, 0006: for each add "alternatives rejected", "risks", "revisit when"; promote `NEURON_ARCHITECTURE_AND_SWOT.md` items into tracked issues with owners
- [ ] Write ADR on dual-store design (AlloyDB + Neo4j): source of truth, write ordering, failure semantics, reconciliation
### 4.2 Security (treat the mutator as high-risk)
- [ ] Threat model: stolen token, malicious repo URL (SSRF), path traversal in file ops, force-push to protected branches, supply-chain via submodule changes, injection through commit messages/branch names, confused deputy (agent acts with orchestrator's broader permissions than requester)
- [ ] Controls: per-request scoped credentials (GitHub App installation tokens, minimal permissions, short-lived), allowlist of orgs/repos, protected branches enforced, dry-run default, signed commits, full audit log (who/what/why/before/after SHA), rate limiting
- [ ] SSRF defenses for `git_remote_inspector`: URL allowlist, block private IP ranges and metadata endpoints, DNS rebinding protection, size/time limits
- [ ] Secrets: no tokens in logs/traces; secret scanning in CI
- **AC:** red-team checklist executed; findings tracked and fixed; test per control
### 4.3 Reliability and performance
- [ ] GitHub API: conditional requests (ETag), rate-limit awareness (`X-RateLimit-*`), backoff with jitter, secondary rate limits, GraphQL batching
- [ ] Merkle cache in Neo4j: prove invalidation correctness (tree SHA change invalidates exactly affected subtrees); add property tests
- [ ] Idempotent mutation: same request id -> same outcome; optimistic concurrency on branch ref (expected SHA / compare-and-swap)
- [ ] Concurrency model: per-repo locks or CAS; timeouts; cancellation propagation
- [ ] Load test with k6/locust; record p50/p95/p99 per endpoint; find bottleneck; document
- **AC:** SLOs defined and dashboards exist (latency, error rate, GitHub quota burn)
### 4.4 Quality
- [ ] Coverage report; mutation testing (mutmut) on core engines; contract tests against `contracts/openapi` (schemathesis)
- [ ] Type-check strict (`pyright` config exists); ruff + format in CI
- [ ] End-to-end propagation test of `traceparent`, `x-request-id`, `x-correlation-id` through logs and downstream calls
- [ ] Health, readiness, graceful shutdown; Dockerfile hardening (non-root, minimal image, pinned digests); `docker-compose.yml` smoke test in CI

## 5. gcd/ — Google Cloud architecture (Google-interview leverage)
- [ ] Verify each documented command against the current `gcloud` CLI; add "verified on <date>/<version>" header; fix drift
- [ ] Per service (Compute Engine, GKE, Cloud Run/Functions, Cloud SQL, Firestore, BigQuery, Pub/Sub, Cloud Storage, VPC, Docker/Artifact Registry): add **limits/quotas, pricing model, SLA, consistency/durability model, DR options, security defaults**
- [ ] Decision guides with criteria and anti-patterns:
  - [ ] Cloud Run vs GKE vs Compute Engine vs Functions
  - [ ] Firestore vs Cloud SQL vs AlloyDB vs Spanner vs Bigtable vs BigQuery
  - [ ] Pub/Sub vs Kafka (Managed Service) vs Cloud Tasks vs Eventarc
  - [ ] GCS storage classes and lifecycle policies
- [ ] Landing zone doc: org -> folders -> projects, org policies, IAM (groups not users, conditions, workload identity federation), Shared VPC, VPC Service Controls, Private Service Connect, logging sinks, billing export to BigQuery, budgets/alerts
- [ ] Reference architectures with diagrams: 3-tier web app, event-driven pipeline, data platform, ML serving (Vertex AI / GKE with GPUs), multi-region active-passive
- [ ] Terraform for the landing zone skeleton (even minimal) that passes `terraform validate`
- [ ] Google-specific knowledge to be able to speak to: Spanner (TrueTime, external consistency), Bigtable/Colossus/Borg at overview, Anycast/Global load balancing/Premium tier network, Cloud Armor/IAP/BeyondCorp, Cloud Monitoring SLO tooling
- **AC:** each decision guide has a worked example scenario with the chosen option and why

## 6. LLM observability (Anthropic relevance; repo name suggests this theme)
- [ ] Define what to observe for LLM systems: traces of prompt/response, tool calls, token counts, cost, latency (TTFT and inter-token), cache hit rate (prompt caching), refusal rate, eval scores, guardrail triggers, user feedback
- [ ] OpenTelemetry GenAI semantic conventions: implement in policy-orchestrator's agent calls
- [ ] Privacy: PII redaction, retention limits, access controls on prompt logs, sampling policy
- [ ] Drift/quality monitoring: scheduled evals against a frozen set; alert on regression; model-version pinning and canary of model upgrades
- [ ] Cost governance: per-feature/per-tenant budgets, anomaly alerts
- [ ] Incident playbook for LLM-specific failures: model regression, provider outage (fallback model/degraded mode), prompt-injection incident, runaway agent loop (max steps/budget, kill switch)
- **AC:** one dashboard + three alerts + one game-day for an LLM failure

## 7. Company-specific mapping

### Anthropic
- [ ] Read: Responsible Scaling Policy, Constitutional AI paper (overview), "Building effective agents", "Writing tools for agents", MCP spec, Claude Code security/sandboxing docs, alignment/interpretability blog headlines
- [ ] Prepare your position on: how to give agents autonomy safely (least privilege, reversibility, approvals, monitoring), evals as the main engineering feedback loop, defense in depth against injection
- [ ] Prepare 2 stories where you made a reliability/safety trade-off against speed
- [ ] "Why Anthropic" — specific, honest, tied to your work here (policy-guardian, approvals, evals)
- [ ] Practice designs: "design a sandbox for agent code execution", "design an eval platform", "design the metering and rate-limiting layer for an LLM API", "design prompt/version management with safe rollouts"

### Google
- [ ] Engineering practices: readability, design docs, code review norms, monorepo + trunk-based dev, release engineering; show how `rules/` embodies these
- [ ] Behavioral: 6 STAR stories (conflict, failure, ambiguity, influence w/o authority, mentoring, ownership); rehearse aloud with timer
- [ ] Practice 45-min system design 1x/week; get feedback from a peer; record yourself

### Stripe
- [ ] Engineering conventions: written culture (RFCs/design docs), API design rigor, backward compatibility, operational excellence; map rule-system ideas to these
- [ ] Practice the collaborative, pragmatic communication style — think aloud, clarify, test as you go

### Neo4j
- [ ] Lineage graph: model repos/modules/rules/violations in Neo4j (policy-orchestrator already tracks lineage); write 5 useful Cypher queries (impact of a rule change, owners of violating code, dependency cycles) and show PROFILE
- [ ] Link with `knowledge-graph-platform` as the data source for "architecture knowledge graph"

## 8. Mock interview bank
1. Design a policy-as-code platform that enforces standards across 2,000 repos. *Strong: rule registry, checks as CI, gradual rollout (warn->enforce), exemptions with expiry, metrics, ownership, developer experience.*
2. Design an agent that opens PRs across many repos safely. *Strong: scoped credentials, dry-run, CAS on refs, approvals, audit, rollback plan, injection defense, rate limits.*
3. How do you test an LLM-based code reviewer? *Strong: labeled corpus, precision/recall, severity calibration, regression gates, cost, human sampling.*
4. Design a landing zone for a regulated company on GCP. *Strong: org policy, IAM, network segmentation, VPC-SC, logging, key management, break-glass.*
5. How do you keep documentation and rules from rotting? *Strong: ownership, review dates, enforcement tied to CI, deletion policy, measure usage.*
6. Design observability for an LLM application. *Strong: traces, token/cost, quality evals, privacy, drift, alerts.*
7. An agent deleted a branch it shouldn't have — postmortem. *Strong: timeline, root cause (permissions, missing approval), blast radius, fix (guardrails not blame), detection, prevention.*
8. Trade-off: strict rules vs team autonomy. *Strong: paved road with escape hatches, risk-based enforcement, data on cost of violations.*
9. Design a distributed rate limiter for an LLM API with token-based quotas. *Strong: token bucket on tokens not requests, estimate-then-reconcile on output length, per-key + global, fairness, headers.*
10. How would you roll out a new model version safely? *Strong: shadow, canary by traffic %, eval parity, rollback, comms.*

## 9. Reading list
1. Google SRE book (postmortem culture, release engineering); Google Cloud Architecture Framework
2. Building Evolutionary Architectures (fitness functions = machine-enforced rules!)
3. Fundamentals of Software Architecture (Richards & Ford); Michael Nygard ADR article; "Documenting Software Architectures"
4. Anthropic engineering posts + RSP; OWASP Top 10 for LLM Applications; MITRE ATLAS
5. GitHub REST/GraphQL rate-limit docs; GitHub Apps permissions model
6. OpenTelemetry GenAI semantic conventions

## 10. Weekly cadence
- 1 enforceable-rule conversion or eval improvement; 1 doc/ADR; 1 timed mock; 1 reading; weekend: behavioral story rehearsal
