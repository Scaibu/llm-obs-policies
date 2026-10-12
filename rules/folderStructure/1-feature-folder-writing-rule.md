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
| 2 | types | `types/{f}.types` | C | Domain models, input/output DTOs |
| 3 | schema | `schema/{f}.schema` | C | Validation + `Mapper` (fromApi, toApi) |
| 4 | queries | `queries/{f}.queries` | C | Named `FLOW_{VERB}_{ENTITY}_{CRITERIA}` queries |
| 5 | port | `repository/{f}.repository.port` | C | `Repository` interface instance |
| 6 | repository | `repository/{f}.repository` | C | Adapter executing queries |
| 7 | rules | `rules/{f}.rules` | X | Any business branching (see rule test below) |
| 8 | machine | `machines/{f}.machine` | X | Entity has a lifecycle (>= 3 states) |
| 9 | workflow | `workflows/{f}.workflow` | X | Multi-step automation |
| 10 | service | `service/{f}.service` | C | Orchestrates port + rules + machine, owns transactions |
| 11 | index | `index` | C | Public facade: service + public types only |
| 12 | handler | `src/api/rest/v1/handlers/{f}.handler` | C | Parse, call service, return envelope |
| 13 | router | `src/api/rest/v1/routers/{f}.router` | C | Mount endpoints |
| 14 | tests | `tests/{f}.rules.test`, `tests/{f}.machine.test` | X | Required whenever rules / machine exist |

Agent scratch notes go in a git-ignored `.agent-notes.md`, never in `context.yml`.

**Rule test:** "Would a non-engineer change this condition?" Yes -> it belongs in `rules`.
Guard clauses, null checks, and loop conditions stay in code.

## 2. Shared Generic Kernel (written once, reused by every feature)

Location: `src/shared/kernel`. Features instantiate these types and never redefine them.

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

A feature file is a typed instantiation, e.g. `RuleTable<OrderCtx, Discount>`, not custom plumbing.

## 3. Guardrails

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

## 4. Agent Protocol (CLI only, never REST for file operations)

```bash
python3 -m src.api.cli.main scaffold-feature <name> [--tier core|full]
python3 -m src.api.cli.main create-file --path <p> --role <R> --rel <Rel> --target <t> --direction incoming
python3 -m src.api.cli.main link-file --source <s> --rel <Rel> --target <t>
python3 -m src.api.cli.main verify-feature <name>
```

Sub-package scaffolding: add `--base-dir packages/<pkg>/src/features --package-root packages/<pkg>`.
Never hand-create directories or orphan files. Populate files in table order.

### Mechanical enforcement (tooling, not prose)

`verify-feature` and CI must check, so the agent does not self-certify:
- Required files exist for the declared tier, and naming matches the formula.
- Import boundaries: service -> port only; cross-feature imports via `index` only; no SQL outside `queries`.
- Banned patterns: `any`, inline comments (except `WHY:`), string-built SQL.

### Definition of Done

A feature task is complete only when all hold:
1. `verify-feature <name>` passes.
2. Type check compiles with no errors.
3. Tests pass, including rules and machine tests where those roles exist.
4. Knowledge graph is synced (every new file created via `create-file` or `scaffold-feature`).