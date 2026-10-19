OUTER WRAPPER  (encloses every stage)
├── error boundary ... unhandled failure ⇒ 5xx for this request only
├── envelope ......... RFC 9457 Problem Details, stable `type` URI per reason
├── metrics .......... duration histogram, active requests, rejections{reason}
└── access log ....... id, trace, route, peer, principal, status, reason, duration
│
├── 1 Request identity                         cost: trivial
│   ├── [M] generate request ID always
│   ├── [M] accept traceparent only from trusted hops; validate format
│   ├── fail: invalid inbound trace ⇒ drop it, start a new trace (no reject)
│   └── out: request_id, trace context
│
├── 2 Peer resolution                          cost: trivial
│   └── out: resolved client (tree E)
│
├── 3 Global admission                         cost: trivial
│   ├── check: in-flight < admission limit (tree H)
│   ├── fail: 503 + Retry-After
│   └── emit: reason="admission"
│
├── 4 Route resolution                         cost: cheap, pure
│   ├── check: method + path pattern match
│   ├── fail: 404 (no route) / 405 + Allow header (wrong method)
│   └── out: route policy
│       ├── auth requirement + required scopes
│       ├── body / header / content-type limits
│       ├── timeout min + max
│       ├── priority class
│       └── idempotency flag
│
├── 5 Per-route ingress limits                 cost: cheap (headers only)
│   ├── 413 body too large (declared length)
│   ├── 415 unsupported content type
│   └── 431 headers too large for this route
│
├── 6 Pre-auth rate limit (by resolved peer)   cost: cheap
│   ├── protects stage 7 from credential stuffing
│   └── fail: 429 + Retry-After (RFC 6585)
│
├── 7 Authentication                           cost: expensive
│   ├── [M] headers only — body unread
│   ├── [S] cache verification results within token validity
│   ├── fail: 401 + WWW-Authenticate
│   └── out: principal
│
├── 8 Coarse authorization                     cost: cheap
│   ├── check: principal scopes ⊇ route scopes
│   └── fail: 403
│
├── 9 Per-identity quota                       cost: cheap–medium
│   ├── keyed by principal (not IP)
│   └── fail: 429 + Retry-After
│
├── 10 Deadline computation                    cost: trivial
│   ├── budget = min(route.max, inherited − safety margin)
│   ├── [M] inherited deadlines capped, never trusted outright
│   ├── fail: budget < route.min ⇒ fail fast (504 / DEADLINE_EXCEEDED)
│   └── out: deadline in request context
│
├── 11 Priority admission                      cost: trivial
│   ├── per-class concurrency; lowest class shed first
│   └── fail: 503 + Retry-After
│
└── 12 Handler (router → services)             cost: unbounded
    ├── 100-continue sent now (if requested)
    ├── body streamed now, under body-rate timeout
    └── retry semantics on every non-2xx
        ├── 503 / 429 ............ Retry-After set
        ├── REFUSED_STREAM ....... never processed, safe
        └── partial processing ... retry-safe only if idempotent or keyed