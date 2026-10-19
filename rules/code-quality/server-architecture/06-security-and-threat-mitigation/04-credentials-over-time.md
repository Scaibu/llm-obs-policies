Credential Lifecycle
├── Long-lived stream re-authentication
│   ├── why: token expires or is revoked; stream keeps running for hours
│   ├── [M] track credential expiry per stream
│   ├── DECIDE: re-validate periodically / on revocation event / both
│   ├── [M] expiry ⇒ close with defined code
│   │   ├── WebSocket: close code (e.g. 1008 Policy Violation)
│   │   └── gRPC: UNAUTHENTICATED
│   └── emit: streams_closed_total{reason="credential_expired"}
│
├── Signing key rotation (JWKS)
│   ├── [M] fetch + cache key set; refresh on interval
│   ├── [M] unknown key ID ⇒ one rate-limited refresh, then reject
│   ├── [M] overlap window: old and new keys valid together
│   ├── DECIDE: behaviour when key endpoint is down (keep cached keys, bounded)
│   └── emit: jwks_refresh_total{result}, jwks_age_seconds
│
├── Clock skew
│   ├── [M] tolerance for exp / nbf / iat checks
│   └── DECIDE: tolerance value  [Guessing: seconds, not minutes]
│
└── Revocation
    └── DECIDE: short token TTL only, or a revocation list / introspection