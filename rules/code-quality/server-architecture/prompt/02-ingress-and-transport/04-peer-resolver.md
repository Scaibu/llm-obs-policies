---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_PEER_RESOLVER_CREATION"
agent_role: "Principal Network Security Architect & Identity Assurance Officer"
target_scope: "Client IP Resolution, Trusted Proxies, PROXY Protocol v2, Forwarded & X-Forwarded-For"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Peer Resolver Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Trusted Proxy Validation Invariant
The server MUST NEVER trust forwarding headers (`X-Forwarded-For`, `Forwarded`, `X-Real-IP`) from an untrusted socket peer. If the raw TCP socket peer IP is not present in the explicitly configured `trusted_proxies` CIDR whitelist:
- The raw TCP socket peer IP MUST be resolved as the true client IP.
- All inbound forwarding headers MUST be discarded/ignored for rate-limiting, geo-routing, and security identity.

Guardrail 2: Right-to-Left Chain Traversal
When the socket peer is in the trusted proxy list, the server MUST parse `X-Forwarded-For` or `Forwarded` (RFC 7239) strictly **right-to-left**. The resolved client IP MUST be the first untrusted IP encountered when scanning backwards from the closest trusted proxy. Leftmost IP parsing (naive `split(',')[0]`) is strictly prohibited due to client header spoofing.

Guardrail 3: PROXY Protocol v2 Support for Layer 4 Balancers
When deployed behind Layer 4 TCP load balancers (AWS NLB, HAProxy, Envoy in TCP mode), the peer resolver MUST ingest PROXY Protocol v2 binary headers before parsing application protocols, extracting the authentic remote client IP and port.

Guardrail 4: Malformed Header Handling
If an incoming forwarding header from a trusted proxy contains invalid IP syntax or unparseable values, the request MUST be rejected with HTTP 400 Bad Request and an audit alert logged (`event: "peer_resolution_malformed_header"`).

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies. Document the entire peer resolution algorithm in the file header docblock.

---

## 2. Peer Resolver Configuration Contract

```yaml
peer_resolver_contract:
  trusted_proxies:
    - "10.0.0.0/8"
    - "172.16.0.0/12"
    - "192.168.0.0/16"
    - "127.0.0.1/32"
  protocol_source: "X_FORWARDED_FOR" # PROXY_PROTOCOL_V2 | FORWARDED_RFC7239 | X_FORWARDED_FOR
  traversal_direction: "RIGHT_TO_LEFT"
  output_schema:
    client_ip: "string (IPv4 or IPv6)"
    client_port: "integer | null"
    is_trusted_hop: "boolean"
    hop_chain: "list[string]"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Spoofed X-Forwarded-For Attack Fix**: A client sends `X-Forwarded-For: 1.1.1.1, 8.8.8.8`. The intermediate trusted proxy appends the client IP `203.0.113.195`. The header becomes `1.1.1.1, 8.8.8.8, 203.0.113.195`. By traversing right-to-left, the resolver correctly extracts `203.0.113.195`, completely ignoring the spoofed `1.1.1.1`.
2. **Missing Forwarding Header from Trusted Proxy Fix**: If a trusted proxy fails to inject `X-Forwarded-For`, fallback to the immediate socket peer and flag the anomaly in telemetry metrics (`peer_resolution_anomaly_total`).

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Trust Leftmost IP
Always write right-to-left parsing logic when extracting client identities from `X-Forwarded-For`.

### Instruction 2: Immutable Client Context
Attach the resolved `client_ip` and `hop_chain` to the request context early so rate limiters and loggers read a unified immutable value.
