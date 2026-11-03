The order is: **contract → generated layer → handler → service → persistence/events.** Three trees, same notation as before.

```
Legend
  name(inputs) → output
  ⚠  can fail (HTTP status shown)
  ▶  team-written
  ⚙  generated or provided by chassis, never hand-written
```

**Tree 1: the contract (written first, reviewed like code)**

```
defineApi() → apiContract                                                  ▶
├── metadata() → {service, majorVersion, owner, visibility: public | internal}
├── resources() → [resource]
│   └── defineResource(name) → resourceSpec
│       ├── schema() → fields {type, required, readOnly, format}
│       ├── idFormat() → opaque string (never expose DB auto-increment ids)
│       └── ownership() → tenant-scoped | caller-scoped | global
├── operations() → [operation]
│   └── defineOperation(name) → operationSpec
│       ├── route() → method + path            (POST /v1/orders)
│       ├── request() → schema
│       ├── responses() → {success schema, status}
│       ├── errors() → [declared error types + status]
│       ├── auth() → {requiredScopes, resourceLevelCheck: yes | no}
│       ├── idempotency() → required | natural | none
│       ├── consistency() → strong | eventual (stated to callers)
│       ├── pagination() → cursor | none
│       ├── rateClass() → tier
│       ├── timeoutBudget() → ms
│       └── lifecycle() → active | deprecated(sunsetDate)
└── events() → [produced event schemas]        (same contract, same review)
```

**Tree 2: generated layer (runs in CI, owned by the platform team)**

```
buildFromContract(apiContract) → artifacts                                 ⚙
├── lintContract(fleetRules) → violations                         ⚠ CI fail
│   └── naming, error envelope, pagination style, id format, versioning
├── checkBreakingChanges(apiContract, publishedVersion) → breaks  ⚠ CI fail
│   └── removed field | type change | new required input | narrowed enum
├── generateServerInterface() → interface the team implements
├── generateDecoders() → decode(request) → dto
├── generateValidators() → validate(dto) → fieldErrors
├── generateClients() → typed clients for the other 99 services
├── generateMockServer() → for consumers' tests
├── generateDocs() → reference docs
└── publishToRegistry(apiContract, artifacts)
```

**Tree 3: runtime, from route to database**

```
spec.registerApiRoutes(router, services)                                   ▶
├── route(POST   /v1/orders,              handleCreateOrder)
├── route(GET    /v1/orders/{id},         handleGetOrder)
├── route(GET    /v1/orders,              handleListOrders)
├── route(PATCH  /v1/orders/{id},         handleUpdateOrder)
└── route(POST   /v1/orders/{id}:cancel,  handleCancelOrder)    (action, not DELETE)

  (before any handler, chassis middleware already ran:
   recover → requestId → trace → load shedding → deadline → mTLS/peer auth
   → user auth → coarse scope check → tenant + flag context)


handleCreateOrder(context, request) → response
├── decode(request) → dto                                         ⚙ ⚠ 400
├── validate(dto) → fieldErrors                                   ⚙ ⚠ 400 (all at once)
├── checkIdempotency(key, caller, hash(dto)) → stored | proceed   ⚙
│   ├── key seen, same hash      → return stored response
│   ├── key seen, different hash → ⚠ 422
│   └── key in flight            → ⚠ 409
├── toCommand(dto, context.caller, context.tenant) → command      ▶
├── authorizeResource(caller, "create", target) → allowed         ▶ ⚠ 403
├── isEnabled(flags, "orders.new_pricing", context) → variant     ▶
├── services.orders.create(context, command) → result             ▶
│   ├── validateBusinessRules(command) → violations               ⚠ 422
│   ├── callDownstream(clients.inventory.reserve, context.deadline) → reservation
│   │   ├── hard dependency fails → ⚠ 503 (retryable)
│   │   └── soft dependency fails → fallback, mark degraded
│   ├── inTransaction(db) → order
│   │   ├── loadAndCheckInvariants() → ok                         ⚠ 409
│   │   ├── insert(order)
│   │   └── writeOutbox(OrderCreated)       (same transaction as insert)
│   └── return result
├── storeIdempotentResponse(key, response)                        ⚙
├── track(context, "order.created", attributes)                   ⚙ (async)
├── toResponse(result) → dto                                      ▶
│   └── 201 + Location + ETag
└── onError(error) → mapError(error) → problemDetails             ⚙


handleGetOrder(context, request) → response
├── parseId(request.path) → id                                    ⚙ ⚠ 400
├── services.orders.get(context, id) → order                      ▶
│   └── readThroughCache(id) → db fallback
├── authorizeResource(caller, "read", order) → allowed            ▶ ⚠ 404
│   └── deny as 404, not 403 (don't reveal it exists)
├── checkConditional(request.ifNoneMatch, order.etag) → 304 | continue
└── toResponse(order) → 200 + ETag + Cache-Control


handleListOrders(context, request) → response
├── parseQuery(request) → query                                   ⚙ ⚠ 400
│   ├── filters → allowlisted fields only
│   ├── sort → allowlisted fields only, must match an index
│   ├── pageSize → clamp to max
│   └── cursor → opaque, signed, decoded server-side
├── scopeToCaller(query, context.tenant, context.caller) → query  ▶
│   └── scoping is server-enforced, never trusted from the client
├── services.orders.list(context, query) → page                   ▶
└── toResponse(page) → {items, nextCursor}   (no total count by default)


handleUpdateOrder(context, request) → response
├── decode + validate                                             ⚙ ⚠ 400
├── requireIfMatch(request) → expectedEtag                        ⚙ ⚠ 428
├── authorizeResource(caller, "update", id)                       ▶ ⚠ 404
├── services.orders.update(context, id, patch, expectedEtag)       ▶
│   └── inTransaction: compareVersion → apply → writeOutbox        ⚠ 412 stale
└── toResponse(order) → 200 + new ETag


handleCancelOrder(context, request) → response        (long-running action)
├── checkIdempotency(...)                                         ⚙
├── services.orders.requestCancel(context, id) → operation        ▶
└── toResponse(operation) → 202 + Location: /v1/operations/{id}


background (not in the request path)
└── outboxRelay(db, producer) → publishes OrderCreated / OrderUpdated  ⚙
    ├── poll unpublished rows → publish → mark published
    └── at-least-once: consumers must be idempotent
```

**Error mapping (one table for the whole fleet, in the chassis)**

```
domain error              → status   retryable   caller sees
─────────────────────────────────────────────────────────────────
ValidationError           → 400      no          field errors
Unauthenticated           → 401      no          —
Forbidden (scope)         → 403      no          —
NotFound / NotVisible     → 404      no          —
Conflict / InFlight       → 409      maybe       —
StaleVersion              → 412      no          refetch + retry
BusinessRuleViolation     → 422      no          rule code
RateLimited / Shed        → 429      yes         Retry-After
DependencyUnavailable     → 503      yes         Retry-After
DeadlineExceeded          → 504      yes         —
Unexpected                → 500      no          requestId only
```

The rules that matter most at this scale:

- **The outbox is written in the same transaction as the row.** [Certain] If you write to the DB and then publish to Kafka directly, a crash between the two leaves them inconsistent forever, and with 100 services consuming events that becomes silent data corruption.
- **Cursor pagination only, and no total counts by default.** [Likely] Offset pagination and `COUNT(*)` look fine in development and turn into full-table scans once tables reach hundreds of millions of rows.
- **Error bodies use one fleet-wide format.** [Certain] RFC 9457 (Problem Details) is the standard to adopt. Without it, every client SDK has to special-case 100 error formats.
- **Handlers stay thin.** [Likely] If a handler has business logic in it, the same operation can't be reused from a consumer or a job without duplicating that logic.

Are these APIs external (behind a gateway) or internal service-to-service, or both? That decides whether internal traffic should use RPC contracts instead of REST, which changes Tree 1 and the error table.