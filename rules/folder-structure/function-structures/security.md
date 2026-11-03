The primary vulnerability in microservice fleets is accepting user tokens blindly across internal hops without audience restrictions or relying exclusively on perimeter security. [Certain] Every internal RPC must verify cryptographic peer identity via mTLS, validate scoped authorization claims, and prevent token re-use across disparate service boundaries.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Authentication Pipeline

```
authenticateRequest(context, request) → principal                           ⚙
├── peer identity (mTLS)
│   └── verifyMtls(request.peerCert) → callingService           ⚠ 401
├── end-user identity (JWT / OIDC)
│   ├── extractToken(request.headers.Authorization) → token     ⚠ 401
│   ├── verifySignature(token, cachedKeys) → claims             ⚠ 401
│   │   └── unknown key id → refresh keys once, then fail
│   ├── checkExpiry(claims) + checkAudience(claims)             ⚠ 401
│   └── toPrincipal(claims) → {userId, tenantId, scopes, roles}
└── combine → principal {callingService, user, tenantId, scopes}
```

[Certain] User tokens propagated across service hops must retain strict audience constraints or be exchanged via token exchange (RFC 8693) per hop. A naked token valid for service A must never be accepted by service B.

---

## 2. Multi-Tier Authorization Enforcement

```
authorize(principal, action, resource) → allowed                             ⚙ + ▶
├── coarse: scopeCheck(principal.scopes, operation)       ⚙     ⚠ 403
├── service: peerPolicy(callingService, operation)        ⚙     ⚠ 403
├── tenant: sameTenant(principal.tenantId, resource.tenantId) ⚙ ⚠ 404
└── fine: resourcePolicy(principal, action, resource)     ▶     ⚠ 404
```

---

## 3. Secret Lifecycle & Key Rotation

```
manageSecrets()                                                             ⚙
├── fetch(reference, identity) → secretValue
├── cacheWithTTL(secretValue)
├── rotate(secret) → dual-valid window → retire old key
└── auditAccess(identity, reference)                                        ⚙
```

---

## 4. Strict Security Invariants

1. **Zero Raw Token Trust**: Internal services must never trust raw forwarded header IDs (`x-user-id`, `x-tenant-id`) unless cryptographically signed or verified against the authenticated mTLS identity of the trusted API gateway.
2. **Dual-Valid Rotation Windows**: All cryptographic signing keys (JWT, API keys) must support overlapping rotation windows where both key $N$ and key $N-1$ are valid during verification.
3. **Information Disclosure Prevention**: Unauthorized access to tenant-scoped resources must return HTTP 404 (Not Found) rather than HTTP 403 (Forbidden) to prevent resource existence enumeration.

