# Parameter Specification: `x-forwarded-for`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-forwarded-for` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY at Ingress Edge** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 7239 Forwarded / Comma-separated IPv4 / IPv6 addresses |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Carries client IP address across intermediate proxies, load balancers, and CDNs. Ingress gateway must validate proxy trust chain to identify the true client IP.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-forwarded-for
in: header
required: true
schema:
  type: string
  pattern: "^([0-9a-fA-F:.]+(,\s*)?)+$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-forwarded-for = ( ip-address ) *( OWS "," OWS ip-address )
ip-address      = ipv4-address / ipv6-address
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The edge gateway MUST inspect the `x-forwarded-for` header list.
2. The gateway SHALL traverse the IP chain from right to left, filtering trusted proxies.
3. The first untrusted IP in the chain MUST be selected as the authentic client origin IP.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header present with proxy chain | `raw != null && size(raw) > 0` | `First untrusted IP from right` | Bind for rate limiting and audit |
| Header absent | `raw == null` | `peer_ip` | Use direct socket peer IP |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-forwarded-for"])
  ? resolve_client_ip(request.headers["x-forwarded-for"], peer_ip, trusted_proxies)
  : peer_ip
```

---

### 7. Failure & Security Enforcement
- Spoofable if edge proxies do not sanitize inbound headers.
- Used for geofencing, IP rate limiting, and security forensic logging.
- All inbound `X-Forwarded-For` values MUST be treated as untrusted by default — only IPs appended by the trusted edge gateway are authoritative.
- The resolved client IP MUST be used for rate limiting, geofencing, and audit trail logging — using a spoofed XFF IP is a P0 security incident.
---

### 8. Protocol Wire Example

```http
x-forwarded-for: 203.0.113.195, 70.41.3.18, 150.172.238.178
```
