---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_FUNCTION_OR_CLASS_CREATION"
agent_role: "Lead Software Architect & Functional/Class Engineering Standards Enforcer"
target_scope: "All Classes, Interfaces, Ports, Adapters, Services, Controllers, State Containers, and Functions across Backend and Frontend"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
contract_version: "1.0"
---

# 4. Functions & Classes Writing Rules & Implementation Standards

> **Universal Engineering Axiom:**  
> Software in this ecosystem is built on strict Hexagonal Architecture (Backend) and the State-Controller-Model Triad (Frontend). Every class, interface, method, and function MUST follow deterministic naming formulas, explicit trace propagation, structured try/catch error boundaries, and zero inline comments.

---

# PART I: STRICT GUARDRAILS (WHAT NOT TO DO AT ALL)

These are non-negotiable negative constraints and architectural invariants. Systems, AI agents, and engineers MUST review these first:

1. **NEVER Write Mid-Function Inline Comments:**  
   Inline comments (`//`, `#`) inside function or method bodies are strictly prohibited. The entire algorithmic execution blueprint, complexity ($O(n)$ time/space), and failure invariants MUST be declared in the file or class top-level header docblock. Function bodies must be 100% comment-free, self-documenting code.

2. **NEVER Exceed Parameter Limits (≤ 3 Preferred, Max 5 Hard Limit):**  
   A function or method must not take more than 3 parameters. If more than 3 parameters are required, you MUST refactor them into a strongly-typed Input DTO / Command Object. Any function exceeding 5 parameters is an automatic build failure.

3. **NEVER Return Naked Primitives on Mutation or Throw Uncaught Errors:**  
   Mutating operations and async I/O MUST never return naked booleans or throw raw uncaught exceptions. All operations must return a strongly-typed `Result<T, E>` (or standard RFC Envelope). Errors must be typed instances of `ApplicationError` or `DomainError`.

4. **NEVER Drop or Omit the Shared W3C Trace Context (`traceId`):**  
   Every function and method executing domain orchestration, state mutation, or async I/O MUST participate in the active trace space. Handlers create Root Spans; services and controllers create Child Spans; adapters inject `traceparent` headers into outbound network calls. Untraced execution is strictly forbidden.

5. **NEVER Execute Async I/O Without Structured Try/Catch:**  
   Every asynchronous boundary (`async/await`) and external call MUST be wrapped in a structured `try / catch` block. When an exception is caught:
   - Record the exception on the active span (`span.record_exception(err)`).
   - Set the span status to `StatusCode.ERROR`.
   - Map the raw exception to a typed `Result.err(DomainError)`. Never leak database drivers, socket buffers, or raw stack traces.

6. **NEVER Declare Mutable State Properties in Backend Services:**  
   Backend feature services MUST be strictly stateless. Backend classes only hold constructor-injected port dependencies. Storing user state, request counters, or mutable in-memory state inside backend service classes is strictly prohibited.

7. **NEVER Merge Frontend State, Controller, and Model Logic:**  
   The Frontend **State-Controller-Model Triad** is strictly segregated:
   - Exactly **one state file** (`{f}.state`) declaring the `State` class holding all feature variables.
   - Dedicated **controller class** (`{f}.controller`) executing mutations and async actions within try/catch.
   - Separate **model files** (`{f}.model`) holding pure immutable data shapes with zero state logic.

8. **NEVER Import Concrete Drivers into Domain Classes (Ports Inversion):**  
   Domain services and controllers must NEVER import concrete database drivers, HTTP fetch clients, Kafka brokers, or third-party SDKs. They interact exclusively with abstract Driven Ports (`*Port`), implemented by outbound adapters (`*Adapter`).

9. **NEVER Exceed Cyclomatic Complexity Limits (Max ≤ 10, Lines ≤ 30):**  
   Keep functions focused and declarative. A single function or method MUST NOT exceed 30 lines of code or a cyclomatic complexity of 10. Split multi-branch decision logic into structured rules tables (`RuleTable`) or deterministic state machines.

10. **NEVER Create Arbitrary Auxiliary Classes (Closed File Set Invariant):**  
    No ad-hoc "helper" or "util" classes may be created. Every class and function must strictly reside within the canonical architectural roles defined in [1-feature-folder-writing-rule.md](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/folderStructure/1-feature-folder-writing-rule.md).

---

# PART II: UNIVERSAL CLASS & INTERFACE ARCHITECTURE

### 1. Universal Class & Interface Naming Formula
`{PascalFeatureOrSubsystem}{PascalSpecialization}{PascalRole}`

| Architectural Role | Suffix / Role Name | Example Class / Interface Name | Primary Responsibility |
|---|---|---|---|
| **Domain Service** | `Service` | `OrganizationService`, `PaymentService` | Pure domain orchestrator; stateless; coordinates ports & rules |
| **Driven Port** | `Port` | `OrganizationRepositoryPort`, `PaymentGatewayPort` | Abstract interface contract decoupling domain from external systems |
| **Driven Adapter** | `Adapter` | `PostgresOrganizationAdapter`, `StripePaymentAdapter` | Concrete technology implementation; executes non-blocking async I/O |
| **Frontend State** | `State` | `OrganizationState`, `UserProfileState` | Single state container holding all feature variables and flags |
| **Frontend Controller**| `Controller` | `OrganizationController`, `UserProfileController`| Dispatches user gestures, executes async operations, mutates State |
| **Domain Model** | `Model` | `OrganizationModel`, `InvoiceModel` | Pure, immutable data structures and entity DTOs |
| **Rules Engine** | `Rules` | `OrganizationRules`, `DiscountRules` | Business decision tables evaluated as structured data |
| **State Machine** | `Machine` | `OrderLifecycleMachine`, `SyncMachine` | Deterministic entity lifecycle transitions and state guards |

---

### 2. Backend Class Architecture (Stateless Hexagonal Core)

#### 2.1 Domain Service Class Structure:
```typescript
/**
 * ALGORITHM BLUEPRINT: Organization Domain Service
 * 1. Validates organization creation invariants against business rules table.
 * 2. Starts child trace span under active W3C trace context.
 * 3. Coordinates UnitOfWork transaction across persistence and event ports.
 * Complexity: Time O(1) | Space O(1)
 */
export class OrganizationService {
  constructor(
    private readonly repoPort: OrganizationRepositoryPort,
    private readonly eventPort: EventPublisherPort,
    private readonly tracer: Tracer
  ) {}

  public async createOrganization(
    ctx: TraceContext,
    dto: CreateOrganizationInput
  ): Promise<Result<OrganizationModel, DomainError>> {
    return this.tracer.startActiveSpan("organization.create", async (span) => {
      try {
        const canCreate = OrganizationRules.canCreate(dto);
        if (!canCreate) {
          span.set_status(StatusCode.ERROR, "Tier limit exceeded");
          return Result.err(new DomainError("TIER_QUOTA_EXCEEDED"));
        }

        const org = await this.repoPort.save(ctx, dto);
        await this.eventPort.publish(ctx, new OrganizationCreatedEvent(org));

        span.set_status(StatusCode.OK);
        return Result.ok(org);
      } catch (err: unknown) {
        span.record_exception(err as Error);
        span.set_status(StatusCode.ERROR);
        return Result.err(DomainError.fromException(err));
      } finally {
        span.end();
      }
    });
  }
}
```

#### 2.2 Driven Outbound Adapter Structure:
```typescript
/**
 * ALGORITHM BLUEPRINT: Postgres Organization Adapter
 * Implements OrganizationRepositoryPort via connection pool and FLOW_* queries.
 * Wrapped in withTracing, withCircuitBreaker, withRetry, and withCache.
 * Complexity: Time O(1) network I/O | Space O(1)
 */
export class PostgresOrganizationAdapter implements OrganizationRepositoryPort {
  constructor(
    private readonly pool: DbConnectionPool,
    private readonly acl: OrganizationSchemaMapper
  ) {}

  public async getOrganizationById(
    ctx: TraceContext,
    id: string
  ): Promise<Result<OrganizationModel, PortError>> {
    try {
      const row = await this.pool.query(FLOW_GET_ORGANIZATION_BY_ID, [id]);
      if (!row) {
        return Result.err(new NotFoundError("Organization", id));
      }
      return Result.ok(this.acl.fromDatabase(row));
    } catch (err: unknown) {
      return Result.err(new PortError("DATABASE_QUERY_FAILED", err));
    }
  }
}
```

---

### 3. Frontend Class Architecture (State-Controller-Model Triad)

#### 3.1 Dedicated State Class (`{f}.state.ts`):
```typescript
/**
 * ALGORITHM BLUEPRINT: Organization State Container
 * Exactly one state class per feature centralizing all variables, loading,
 * error flags, and reactive view models. Mutated solely by Controller.
 */
export class OrganizationState {
  public organizations: OrganizationModel[] = [];
  public selectedOrg: OrganizationModel | null = null;
  public isLoading: boolean = false;
  public hasError: boolean = false;
  public errorMessage: string = "";
  public lastTraceId: string = "";

  public reset(): void {
    this.organizations = [];
    this.selectedOrg = null;
    this.isLoading = false;
    this.hasError = false;
    this.errorMessage = "";
  }
}
```

#### 3.2 Dedicated Controller Class (`{f}.controller.ts`):
```typescript
/**
 * ALGORITHM BLUEPRINT: Organization Controller
 * Orchestrates user gestures, initiates child spans, invokes API adapters,
 * safely handles errors in try/catch, and mutates OrganizationState.
 */
export class OrganizationController {
  constructor(
    private readonly state: OrganizationState,
    private readonly adapter: OrganizationApiAdapter,
    private readonly tracer: Tracer
  ) {}

  public async loadOrganizations(ctx: TraceContext): Promise<void> {
    return this.tracer.startActiveSpan("ui.organization.load", async (span) => {
      this.state.isLoading = true;
      this.state.hasError = false;
      this.state.lastTraceId = ctx.traceId;

      try {
        const result = await this.adapter.listOrganizations(ctx);
        if (result.isOk()) {
          this.state.organizations = result.value;
          span.set_status(StatusCode.OK);
        } else {
          this.state.hasError = true;
          this.state.errorMessage = result.error.message;
          span.set_status(StatusCode.ERROR, result.error.message);
        }
      } catch (err: unknown) {
        span.record_exception(err as Error);
        span.set_status(StatusCode.ERROR);
        this.state.hasError = true;
        this.state.errorMessage = "Failed to load organizations";
      } finally {
        this.state.isLoading = false;
        span.end();
      }
    });
  }
}
```

---

# PART III: FUNCTION & METHOD VERB-NOUN SEMANTIC MATRIX

All functions and methods use `camelCase` with strict semantic prefixes declaring operational intent:

| Prefix / Verb | Semantic Meaning | Expected Return Type | Example Method Names |
|---|---|---|---|
| `get` | Fetch single entity by unique key; fails if missing | `Promise<Result<T, NotFoundError>>` | `getOrganizationById(id)`, `getApiKeyByKeyHash(hash)` |
| `find` | Query single entity by criteria; returns null if missing | `Promise<Result<T \| null, PortError>>` | `findUserByEmail(email)`, `findActiveSession(token)` |
| `list` | Fetch collection filtered, sorted, and paginated | `Promise<Result<Page<T>, PortError>>` | `listMembersByOrgId(orgId, filter, page)` |
| `count` | Aggregate count of matching records | `Promise<Result<number, PortError>>` | `countActiveSubscriptions(orgId)` |
| `create` | Validate, persist, and emit creation event | `Promise<Result<T, DomainError>>` | `createOrganization(ctx, input)`, `createApiKey(ctx, input)` |
| `update` | Apply validated mutation to existing entity | `Promise<Result<T, DomainError>>` | `updateProfileInfo(ctx, id, patch)`, `updateOrgTier(ctx, id, tier)` |
| `delete` | Purge record or mark soft-deleted | `Promise<Result<void, DomainError>>` | `deleteOrganization(ctx, id)`, `revokeApiKey(ctx, id)` |
| `can` / `is` | Pure deterministic business rule boolean check | `boolean` | `canIssueApiKey(actor, org)`, `isRateLimitExceeded(key)` |
| `evaluate` | Multi-branch rules engine decision resolution | `DecisionResult` | `evaluateAccessRules(context)`, `evaluateTierQuota(usage)` |
| `transitionTo`| State machine transition with guard verification | `Result<State, StateError>` | `transitionToSuspended(entity, reason)` |
| `step` | Sequential DAG step inside workflow runner | `Promise<Result<StepOutput, StepError>>`| `stepValidateQuota(ctx)`, `stepProvisionTenantDb(ctx)` |

---

# PART IV: RESILIENCE & ERROR BOUNDARY PATTERNS

Every function or method interacting with I/O or domain orchestration MUST follow this structured pattern:

```
┌────────────────────────────────────────────────────────┐
│ Method Invocation: method(ctx: TraceContext, dto: DTO) │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
           [1. Start Child Span (tracer.start)]
           • Inherits traceId and spanId from ctx
           • Tags span with method name & client metadata
                            │
                            ▼
                 [2. Structured try / catch]
                            │
            ┌───────────────┴───────────────┐
            ▼ (Async Execution)             ▼ (Exception Caught)
   • Await non-blocking I/O        • span.record_exception(err)
   • Check business invariants     • span.set_status(StatusCode.ERROR)
   • Map to Domain Model via ACL   • Log structured error with traceId
   • span.set_status(StatusCode.OK)• Return Result.err(TypedDomainError)
            │                               │
            └───────────────┬───────────────┘
                            ▼
              [3. Finally: span.end()]
                            │
                            ▼
           Returns Result<T, DomainError>
```

---

# PART V: AGENT CLI PROTOCOL & VERIFICATION

When writing new functions or classes, AI agents MUST verify compliance against this contract:

```bash
# 1. Verify TypeScript / Polyglot type checks pass with zero errors
pnpm typecheck || python3 -m mypy src/

# 2. Verify zero inline comments in function bodies
rg -n "^\\s*(//|#)" src/features/ -g "!*.yml" -g "!*.yaml"

# 3. Verify function parameter limits (<= 5 arguments)
pnpm lint:params

# 4. Run unit tests verifying Result-based error handling
pnpm test
```

### Definition of Done:
1. Every class strictly follows `{PascalFeatureOrSubsystem}{PascalSpecialization}{PascalRole}` naming.
2. Every method uses the semantic Verb-Noun naming matrix.
3. Zero inline comments exist inside function bodies; full docblock blueprint declared at file/class head.
4. All async methods accept/propagate `traceId` and wrap operations in structured `try/catch`.
5. Frontend features cleanly separate `State`, `Controller`, and `Model` classes.
