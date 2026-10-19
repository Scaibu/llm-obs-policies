---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_AUTH_ROTATION_CREATION"
agent_role: "Principal Security Operations Architect & Identity Lifecycle Auditor"
target_scope: "JWKS Key Rotation, Stream Re-Authentication, Token Revocation & Clock Skew Tolerance"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Credentials Lifecycle Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Long-Lived Stream Re-Authentication Invariant
Long-lived persistent streams (WebSockets, Server-Sent Events, gRPC bi-directional streaming) MUST track credential expiration. When the token that authorized the stream expires or is revoked, the stream MUST NOT continue running indefinitely:
- The stream MUST be terminated with a protocol-defined policy error (WebSocket code `1008 Policy Violation`, gRPC `UNAUTHENTICATED`).
- Clients must re-authenticate and establish a fresh connection.

Guardrail 2: Dynamic JWKS Key Rotation & Overlap Window
JSON Web Key Sets (JWKS) MUST be fetched and cached with periodic background refresh.
- When a request presents an unknown Key ID (`kid`), the server MAY execute at most one rate-limited on-demand JWKS refresh before rejecting with HTTP 401.
- Both old and new public signing keys MUST be valid simultaneously during an explicit key rotation overlap window (minimum: 24h).
- If the JWKS endpoint is unreachable, cached keys MUST be retained up to a maximum stale grace period (default: 1 hour).

Guardrail 3: Token Time Validation with Bounded Clock Skew
Token validation (`exp`, `nbf`, `iat` claims) MUST enforce an explicit clock skew window (default: $\pm 3000\text{ms}$). Clock drift beyond this window MUST result in immediate token rejection.

Guardrail 4: Zero Inline Comments Doctrine
Never write mid-function inline comments inside credential validators. Document the JWKS rotation and stream termination algorithms in the file header docblock.

---

## 2. Credentials Lifecycle Contract

```yaml
credentials_contract:
  jwks:
    endpoint_url: "https://auth.llmobs.internal/.well-known/jwks.json"
    cache_ttl_seconds: 3600
    unknown_kid_rate_limit: "1/minute"
    overlap_window_hours: 24
    stale_on_error_grace_seconds: 3600
  stream_reauth:
    check_interval_seconds: 60
    websocket_close_code: 1008
    grpc_error_code: "UNAUTHENTICATED"
  clock_skew_tolerance_ms: 3000
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **JWKS Key Rotation Outage Fix**: During signing key rollover in Keycloak/Auth0, a token signed with the new `kid` arrives. The server detects the missing `kid`, triggers a single rate-limited fetch from `/.well-known/jwks.json`, caches the new public key, and verifies the token without restart.
2. **Infinite WebSocket Token Revocation Leak Fix**: Associate an async timer with active WebSocket connections: `sleep(token.exp - now())`. When timer triggers, send close frame `1008 Policy Violation: Token Expired` and close the socket.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Hardcode Public Keys
Load public verification keys dynamically via the JWKS client adapter; never paste raw PEM strings into source code.

### Instruction 2: Attach Clock Skew to Verification Library
Pass `leeway=3` or `clock_skew=timedelta(seconds=3)` into PyJWT or Nimbus JOSE token decoders.
