The fatal anti-pattern in API gateway architecture is treating the gateway as a distributed business logic orchestrator. [Certain] Writing BFF aggregation code or business transforms inside the API gateway turns the gateway team into an organizational bottleneck and transforms the gateway into a fragile, monolithic single point of failure.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Edge Ingress & Forwarding Pipeline

```
handleAtEdge(request) → upstreamRequest | response                          ⚙
├── terminateTls(request)
├── protectPerimeter()
│   ├── blockKnownBad(ipReputation, wafRules, geoIp)            ⚠ 403
│   ├── enforcePayloadSizeLimits(headers: 16KB, body: 2MB)      ⚠ 413
│   └── coarseRateLimit(clientIp | apiKey)                      ⚠ 429
├── authenticate(request) → principal                           ⚠ 401
├── resolveTenant(principal) → tenantContext                    ⚠ 403 | 404
├── matchRoute(request.path, request.method) → routeSpec        ⚠ 404
│   └── routeSpec generated strictly from published OpenAPI contracts
├── checkApiVersion(request) → version
│   └── deprecated → inject Deprecation & Sunset headers
├── tenantQuota(tenantContext, routeSpec.rateClass)             ⚠ 429
├── stripUntrustedHeaders(request)   (CRITICAL: strip client-spoofed internal headers)
├── attachInternalHeaders(principal, tenantContext, requestId, traceparent)
├── setDeadline(routeSpec.timeoutBudget)
├── routeToCell(tenantContext.cellId) → upstreamEndpoint
└── forward(upstreamEndpoint) → response
    └── normalizeErrors(response) → standard RFC envelope format
```

---

## 2. Header Hygiene & Security Stripping

Clients routinely attempt to inject internal authentication headers. The edge gateway must sanitize transport headers before forwarding:

```
sanitizeHeaders(incomingHeaders) → sanitizedHeaders                         ⚙
├── DROP: x-user-id, x-tenant-id, x-client-id, x-audit-actor-id (incoming raw values)
├── DROP: x-fencing-token, x-internal-role, x-bypass-*
├── PRESERVE: traceparent, baggage (W3C tracing headers)
├── INJECT: x-request-id (generate UUIDv7 if absent)
└── INJECT: cryptographically signed internal token or verified mTLS context
```

---

## 3. Strict API Gateway Invariants

1. **Zero Business Logic at the Edge**: The gateway must only perform routing, TLS termination, WAF filtering, auth translation, and rate limiting. It must never perform database queries or payload transformation logic.
2. **Contract-Driven Route Tables**: Gateway routes must be automatically compiled from versioned OpenAPI specifications published by downstream teams. Hand-editing gateway YAML files is strictly prohibited.
3. **Fail-Closed Perimeter Rate Limiting**: The gateway must enforce hard IP-based and token-based connection limits to absorb volumetric DDoS attacks before they reach internal cluster networks.

