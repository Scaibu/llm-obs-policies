---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_FUNCTION_OR_CLASS_CREATION"
agent_role: "Functions & Classes Standards Enforcer"
target_scope: "All classes, abstract classes, interfaces, ports, adapters, services, controllers, state containers, and functions across backend and frontend"
execution_mode: "Strict"
contract_version: "2.4"
---

# Functions & Classes Contract

Backend: Hexagonal Architecture. Frontend: State-Controller-Model triad.
Every class, interface, method, and function follows the naming formulas, trace propagation, explicit try/catch/finally, immutable parameters, purity-first design, private-by-default visibility, multi-level and multiple inheritance, constructor dependency injection, and zero comments defined below.

---

# PART I: STRICT GUARDRAILS

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

1. **NEVER write comments of any kind.** No inline, block, docblock, header, or trailing comments in any source file. Code is self-documenting through names and types.

2. **NEVER mutate or reassign a parameter. All parameters are constant/final, deeply immutable, and explicitly typed.**
   - Every parameter and return value has an explicit type annotation.
   - Object and collection parameters are read-only typed: `Readonly<T>` / `ReadonlyArray<T>` for flat shapes, `DeepReadonly<T>` (kernel export) for nested shapes.
   - Primitive parameters are never reassigned. Mutating calls on a parameter (`push`, `sort`, `splice`, `Object.assign`, property assignment) are forbidden. Copy first (`[...x]`, `{ ...x }`), then change the copy.
   - Return types are read-only for objects and collections.
   - Constructor parameters are consumed once into `private readonly` or `protected readonly` fields.
   - Module-level constants are `const`, frozen, and `as const` where applicable.
   - Python: immutable parameter types (`Sequence`, `Mapping`, frozen dataclasses), never reassigned. Dart/Java: `final` on every parameter.
   - No type casts (`as`, `<T>x`, `cast()`). Unknown values are narrowed with type guards. No `any`. No non-null assertion (`!`).

3. **NEVER exceed the parameter limit.** 3 preferred, 5 hard. More than 3 means an Input DTO / Command Object. More than 5 fails the build. Constructors take exactly one `Deps` parameter (Part VIII).

4. **NEVER return naked primitives on mutation or throw uncaught errors.** Mutating operations and async I/O return a typed `Result<T, E>`. Errors are typed instances of `ApplicationError` or `DomainError`.

5. **NEVER execute async I/O or domain orchestration without an explicit try/catch/finally in that same function.** Every function or method containing `await`, an external call, or a state mutation has its own structured `try / catch / finally`, written in the function and not delegated.
   - `try`: the full logic.
   - `catch (err: unknown)`: record the exception on the active span, set status `StatusCode.ERROR`, return `Result.err(<typed error>)`. Never leak database drivers, socket buffers, or raw stack traces.
   - `finally`: `span.end()` and any state reset. A function that owns a span ends it. A function that receives a span as a parameter never ends it.
   - Abstract hooks that perform I/O follow this rule in every implementation.
   - A function doing I/O without this block fails the build.

6. **NEVER drop the W3C trace context.** Every function executing orchestration, mutation, or async I/O takes `ctx: Readonly<TraceContext>` as its first parameter. Handlers create root spans. Services and controllers create child spans. Adapters inject `traceparent` into outbound network calls. Pure functions (`can`, `is`, `evaluate`, `transitionTo`, `map`) take no `ctx`.

7. **NEVER declare mutable state properties in backend services.** Backend services and every abstract base above them are stateless and hold only `readonly` constructor-injected ports and the tracer. Fields are `private readonly` by default, `protected readonly` only when a subclass must read them.

8. **NEVER merge frontend State, Controller, and Model.** Exactly one state file (`{f}.state`) with one `State` class holding all feature variables. One controller class (`{f}.controller`) executing mutations and async actions inside try/catch/finally. Separate model files (`{f}.model`) holding pure immutable data shapes with no state logic.

9. **NEVER import concrete drivers into domain classes, and NEVER instantiate collaborators inside a class.** Domain services and controllers import abstract `*Port` interfaces only. Database drivers, HTTP clients, brokers, and third-party SDKs are imported only inside `*Adapter` classes and the composition root. Only the composition root calls `new` on services, adapters, and controllers.

10. **NEVER exceed 30 lines or cyclomatic complexity 10 per function.** Multi-branch decision logic goes to `RuleTable` or a state machine.

11. **NEVER create helper or util classes.** Every class and function lives in a canonical architectural role defined in the feature folder contract.

12. **NEVER assume.** If a type, API, method signature, file, path, command, or behavior is not visible in the codebase or this contract, the agent does not guess it. It reads the real definition first, and if none exists, stops and asks.

13. **NEVER expose a method that is not private, except where Part VI allows it.** Instance methods are `private` by default. `protected` only for abstract hooks and for concrete template-step methods of abstract bases and capability parents. `public` only for methods declared by an implemented interface. No `static` methods, except factory methods on kernel value types (`Result`, the `AppError` family). Module-level pure functions replace statics.

14. **ALWAYS write a pure function when the logic can be pure.** Logic with no I/O, no injected dependency, and no state is a pure function in a role file, never a method (Part V).

15. **NEVER use inheritance outside the rules of Part VII.** Multi-level and multiple inheritance are permitted with no depth limit and no limit on parents. Every level and every parent adds exactly one concern. Inheritance is abstract-first and hook-based. Reuse of behavior without a shared lifecycle uses composition by injection.

16. **NEVER wire dependencies any way except constructor injection through a `Deps` interface.** No service locator, no singleton access, no global or static mutable state (Part VIII).

---

# PART II: CLASS & INTERFACE ARCHITECTURE

## 1. Naming Formula

`{PascalFeatureOrSubsystem}{PascalSpecialization}{PascalRole}`

| Role | Suffix | Example | Responsibility |
|------|--------|---------|----------------|
| Domain Service | `Service` | `OrganizationService`, `PaymentService` | Stateless orchestrator of ports and rules |
| Driven Port | `Port` | `OrganizationRepositoryPort`, `PaymentGatewayPort` | Abstract contract to external systems |
| Driving Port | `Port` | `OrganizationServicePort`, `OrganizationControllerPort` | Contract a service or controller exposes to callers. The only source of public methods |
| Driven Adapter | `Adapter` | `PostgresOrganizationAdapter`, `StripePaymentAdapter` | Concrete technology implementation, non-blocking I/O |
| Frontend State | `State` | `OrganizationState`, `UserProfileState` | Single state container for the feature |
| Frontend Controller | `Controller` | `OrganizationController`, `UserProfileController` | Handles gestures and async actions, mutates State |
| Domain Model | `Model` | `OrganizationModel`, `InvoiceModel` | Pure immutable data structures |
| Rules | `Rules` | `OrganizationRules`, `DiscountRules` | Decision tables evaluated as data. Frozen object of pure functions, not a class |
| State Machine | `Machine` | `OrderLifecycleMachine`, `SyncMachine` | Lifecycle transitions and guards. Frozen object of pure functions, not a class |
| Abstract Base | `Abstract` prefix + role | `AbstractTracedComponent`, `AbstractDomainService`, `AbstractOrganizationService` | One level of an inheritance chain. Never instantiated |
| Capability Parent | `Capability` suffix | `AbstractRetryableCapability`, `AbstractCacheableCapability` | Single-concern abstract parent combined with others by multiple inheritance or mixin. Never instantiated |
| Dependency Bag | `Deps` | `OrganizationServiceDeps`, `PostgresAdapterDeps` | Typed constructor input of one class level, extending the `Deps` of every parent |

## 2. Reference Structures

| Structure | Chain (level 1 to leaf) | What each level adds |
|-----------|-------------------------|----------------------|
| Domain service (4 levels) | `AbstractTracedComponent` -> `AbstractDomainService` -> `AbstractOrganizationService` -> `TieredOrganizationService` | 1 kernel: tracer, abstract hook `mapFailure`. 2 kernel: clock, implements `mapFailure` as `DomainError`. 3 feature: `repoPort`, abstract hook `canCreate`. 4 concrete leaf: implements `OrganizationServicePort`, `canCreate` delegates to pure `OrganizationRules.canCreate`; its entry method owns the span with full try/catch/finally and uses `mapFailure` in `catch` |
| Driven adapter (3 levels) | `AbstractTracedComponent` -> `AbstractPostgresAdapter` -> `PostgresOrganizationAdapter` | 1 kernel as above. 2 `pool`, implements `mapFailure` as `PortError("DATABASE_QUERY_FAILED")`. 3 concrete leaf: `acl` mapper, implements `OrganizationRepositoryPort`, returns `NotFoundError` for a missing row |
| Frontend controller (2 levels) | `AbstractTracedComponent` -> `OrganizationController` | 1 kernel as above. 2 concrete leaf: `state` and `apiPort` (a port, never the adapter class), implements `OrganizationControllerPort`, `mapFailure` as `AppError` |
| Frontend state | `OrganizationState` implements `ResettableStatePort` | Public fields: `organizations`, `selectedOrg`, `isLoading`, `hasError`, `errorMessage`, `lastTraceId`. `reset()` clears all of them, including `lastTraceId` |

Frontend controllers set `isLoading`, `hasError`, and `lastTraceId` before `try`, and clear `isLoading` in `finally`.

---

# PART III: FUNCTION & METHOD VERB-NOUN MATRIX

Names are `camelCase` and start with a verb that declares intent and fixes the return type. Applies to public, protected, private methods and pure functions.

| Prefix | Meaning | Return type | Examples |
|--------|---------|-------------|----------|
| `get` | Single entity by unique key; fails if missing | `Promise<Result<T, NotFoundError>>` | `getOrganizationById(id)` |
| `find` | Single entity by criteria; null if missing | `Promise<Result<T \| null, PortError>>` | `findUserByEmail(email)` |
| `list` | Filtered, sorted, paginated collection | `Promise<Result<Page<T>, PortError>>` | `listMembersByOrgId(orgId, filter, page)` |
| `count` | Aggregate count of matching records | `Promise<Result<number, PortError>>` | `countActiveSubscriptions(orgId)` |
| `create` | Validate, persist, emit creation event | `Promise<Result<T, DomainError>>` | `createOrganization(ctx, input)` |
| `update` | Apply validated mutation to existing entity | `Promise<Result<T, DomainError>>` | `updateOrgTier(ctx, id, tier)` |
| `delete` | Purge record or mark soft-deleted | `Promise<Result<void, DomainError>>` | `deleteOrganization(ctx, id)`, `revokeApiKey(ctx, id)` |
| `can` / `is` | Pure deterministic boolean rule check | `boolean` | `canIssueApiKey(actor, org)` |
| `evaluate` | Multi-branch rules resolution | `DecisionResult` | `evaluateTierQuota(usage)` |
| `transitionTo` | State machine transition with guard check | `Result<State, StateError>` | `transitionToSuspended(entity, reason)` |
| `step` | One sequential DAG step in a workflow | `Promise<Result<StepOutput, StepError>>` | `stepValidateQuota(ctx)` |
| `map` | Pure conversion of one shape or error into another | the target type | `mapFailure(cause)`, `mapRowToModel(row)` |

---

# PART IV: ERROR BOUNDARY PATTERN

Every function with I/O or orchestration, in order:
1. Start a child span from `ctx` (`tracer.startActiveSpan`). A function receiving a span as a parameter skips this.
2. Open `try`. Run logic, check invariants, map results through the ACL.
3. Success: `span.setStatus(StatusCode.OK)`, return `Result.ok(value)`.
4. Returned `Result.err`: `span.setStatus(StatusCode.ERROR, message)`, return it as a typed error.
5. `catch (err: unknown)`: build a typed error through the inherited `mapFailure` hook, `span.recordException(failure)`, `span.setStatus(StatusCode.ERROR, failure.message)`, return `Result.err(failure)`.
6. `finally`: `span.end()` (only if this function owns the span) and any state reset.

---

# PART V: PURITY

1. A pure function returns the same output for the same input, performs no I/O, mutates nothing, never throws, has no `await`, and reads no clock, random source, environment, or global.
2. Time and randomness enter as values. The effectful edge reads `ClockPort` or `IdGeneratorPort` and passes the value in.
3. Pure functions live only in role files (`{f}.rules`, `{f}.machine`, `{f}.schema` mappers, `{f}.types` builders) and the kernel, as frozen `const` objects (`Rules`, `Machine`) or exported `const` functions. Never classes, never static methods.
4. Pure modules import only types and other pure modules. Importing a driver, port, tracer, clock, `Date`, `Math.random`, or `process` fails the build.
5. Pure functions return a value or a `Result`, never `void`.
6. Effects stay outward: classes load, call a pure decision, then persist. A method with no `await` and no injected dependency must become a pure function.
7. Pure functions take no `ctx` and create no span.
8. Every pure function has a unit test with no mocks.

---

# PART VI: VISIBILITY

| Member | Allowed modifier | Condition |
|--------|------------------|-----------|
| Instance method | `private` | Default for every method |
| Abstract hook and its implementations | `protected` | `private` members are invisible to subclasses and cannot be abstract |
| Concrete template step in an abstract base or capability parent | `protected` | Only when a child must call it. Children call it, never override it |
| Method declared by an implemented `*Port` interface | `public` | The only way a class exposes behavior. Nothing else is public |
| Constructor | `public` on concrete leaf, `protected` on abstract classes | Assignment only (Part VIII) |
| Field | `private readonly` | Default |
| Field read by a subclass | `protected readonly` | Only dependencies |
| Frontend State fields | `public` | Mutated only by the matching Controller |
| Static member | not allowed | Exception: factory methods on kernel value types (`Result`, `AppError` family) |

Public, hook, and private methods are all named by the verb matrix.

---

# PART VII: INHERITANCE (MULTI-LEVEL AND MULTIPLE)

Purpose: abstraction. A shared lifecycle is written once in abstract parents. Concrete leaves differ only by hooks and dependencies. Behavior reuse without a shared lifecycle uses composition by injection.

## A. Multi-level

1. **No depth limit.** Each level adds exactly one concern: a hook, a dependency, or a concrete template step. A level adding none is deleted.
2. **Abstract-first.** Every level except the leaf is `abstract` with a `protected` constructor. Only leaves are concrete and instantiated.
3. **Hooks only.** A child implements abstract hooks and never overrides a concrete ancestor method. Template steps are `protected`, called by children, not replaced.
4. **Template contract.** Hooks and template steps are `protected`. Outside callers never reach them.
5. **Substitutability.** A child never strengthens preconditions, weakens postconditions, throws, or returns a different error type than its ancestor declares.
6. **No downward knowledge.** An ancestor never references a descendant, never uses `instanceof` on its descendants, never switches on descendant type.
7. **Stateless chain.** Backend bases hold no mutable state, only `readonly` dependencies.
8. **Constructors.** Each level takes one `Readonly<...Deps>` whose interface extends the `Deps` of every parent, and calls `super(deps)` first. Constructors only assign and never call hooks or virtual methods.
9. **Consumers depend on ports.** Signatures and fields use `*Port` interfaces, never abstract bases or concrete classes.

## B. Multiple

10. **Allowed.** A class may inherit from several parents. Each parent is a single-concern abstract class or mixin named `Abstract{Concern}Capability` (retry, cache, audit, idempotency).
11. **Realization follows the language** (the contract does not assume one):

| Language | Form |
|----------|------|
| Python | Several base classes, C3 linearization, cooperative `super()` |
| Dart | Mixins with `with` |
| TypeScript | No multiple class inheritance. Class mixins plus several `implements`. The mixin constructor needs `any[]`, so the single exception to the no-`any` rule is the kernel's `AbstractConstructor` type alias |
| Java, C# | Several interfaces with stateless default members |

12. **No silent resolution.** Two parents contributing a member with the same name fails the build unless both inherit it from one common ancestor. Parent order is never relied on to resolve it.
13. **Diamonds.** Allowed only when the shared ancestor is a stateless abstract class with constructor-injected dependencies. Constructors are cooperative: each level calls the parent constructor once with its `Deps`.
14. **Independent capabilities.** A capability parent never depends on a sibling capability. It depends on the shared ancestor's members, its own abstract hooks, and ports in its own `Deps`.
15. **Explicit order and linearization.** Parents are listed in priority order. The resulting linearization is declared and must equal the real one.
16. **Visibility unchanged.** Capability parents follow Part VI.

## C. Declaration (no comments)

Each concrete class declares in `context.yml`, under `inheritance_chain`: `class`, `parents` (priority order), `linearization` (full resolved order), `shared_ancestors`, and `ports` (implemented driving and driven ports).

---

# PART VIII: DEPENDENCY INJECTION

1. **Constructor injection only.** One `Readonly<{Name}Deps>` parameter holds all collaborators. Each level's `Deps` extends the `Deps` of every parent.
2. **Depend on abstractions.** Fields and signatures use `*Port` interfaces, never a concrete adapter or abstract base class.
3. **Never `new` a collaborator inside a class.** Value objects, errors, and events are allowed. Only the composition root instantiates services, adapters, and controllers.
4. **No service locator, container lookup inside a class, singleton access, or static or module-level mutable state.**
5. **Inject non-determinism.** Time via `ClockPort`, identifiers and randomness via `IdGeneratorPort`, tracing via `Tracer`.
6. **Segregated ports.** One capability per port. A class depends on the narrowest port it uses.
7. **Acyclic graph.** Direction is handler or controller -> service -> port <- adapter. Import cycles between classes or features fail the build.
8. **Size signal.** A `Deps` adding more than 5 members of its own means the class does too much and must be split.
9. **Composition root.** One per deployable wires every `Deps` bag. Retry, circuit breaker, caching, and tracing decorators wrap adapters there, never inside methods.
10. **Testability.** Every dependency can be replaced by an in-memory implementation of its port without mocking libraries.

---

# PART IX: VERIFICATION

Existing commands:

```bash
pnpm typecheck
python3 -m mypy src/
rg -n "(^|\\s)(//|/\\*|\\*/|#)" src/features/ -g "!*.yml" -g "!*.yaml" -g "!*.md"
pnpm lint:params
pnpm test
```

Run each stack's own type check. Never chain stacks with `||`, because a passing second command hides a failing first one.

Checks that must exist and fail the build (this contract does not assume they already do):
1. No comments of any kind in any source file. A text search is only a first filter (it can miss trailing comments or flag string contents), so the real check must parse the source.
2. Every parameter is explicitly typed, never reassigned, never mutated, and read-only typed.
3. No type casts, no `any`, no non-null assertions.
4. Every function containing `await` or an external call has `try / catch / finally` in its own body.
5. Every I/O function takes `ctx` as its first parameter.
6. Parameter count, line count, and complexity limits from Guardrails 3 and 10.
7. Drivers and SDKs are imported only in adapters and the composition root.
8. Visibility: every `public` method is declared by an implemented interface. No `static` members outside kernel value types.
9. Purity: pure modules import no driver, port, tracer, clock, `Date`, `Math.random`, or `process`. A method with no `await` and no use of injected dependencies is reported.
10. Inheritance: only leaves concrete, no override of a concrete ancestor method, no `instanceof` on own descendants, no pass-through level, no member-name collision between parents unless inherited from a common ancestor, shared ancestors stateless, constructors cooperative.
11. Dependency injection: constructors take one `Deps` parameter and contain only assignments. No class calls `new` on a service, adapter, or controller outside the composition root. The import graph has no cycles.
12. Every concrete class's `inheritance_chain` in `context.yml` (parents, linearization, shared ancestors) matches the real inheritance graph.

### Definition of Done
1. All commands and checks above pass.
2. Classes follow the naming formula. Methods follow the verb matrix.
3. Zero comments of any kind in any source file.
4. Every parameter is typed, immutable, and cast-free.
5. Every function with I/O has its own `try / catch / finally` that records the exception on the span and returns a typed `Result.err`.
6. Every method that can be a pure function is a pure function in a role file.
7. Every class method is private, except hooks and template steps (protected) and interface-declared entry points (public).
8. Inheritance chains (any depth, any number of capability parents) are abstract down to the leaf, hook-based, collision-free, and declared in `context.yml`.
9. Every class receives collaborators through a `Deps` bag and depends only on ports.
10. Frontend features have separate `State`, `Controller`, and `Model` files.