# Parameter Specification: `Cache-Control`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Cache-Control` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on All Responses** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9111 HTTP Caching Directives |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Directs intermediate proxies, CDNs, and client browsers regarding response cacheability. Mutation, sensitive, and PII endpoints must enforce 'no-store'.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Cache-Control
in: header
required: true
schema:
  type: string
  pattern: "^(no-store|private|public)(,\s*[a-zA-Z0-9_=-]+)*$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Cache-Control = 1#cache-directive
cache-directive = token [ "=" ( token / quoted-string ) ]
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST determine the cacheability category of each response before transmission.
2. IF the response contains authenticated data, user-specific PII, tokens, or results from a mutating operation, the server MUST set `Cache-Control: no-store`.
3. IF the response is a public, read-only, non-personalised resource with a defined TTL, the server SHALL set `Cache-Control: public, max-age={ttl}, must-revalidate`.
4. IF the response is authoritative but may become stale (ETag-based), the server SHOULD set `Cache-Control: no-cache` to force revalidation without preventing storage.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Authenticated, PII, or mutating response | `is_sensitive || is_mutation` | `no-store` | Prevents caching across proxies and browsers |
| Public read-only cacheable response with TTL | `!is_sensitive && cache_ttl > 0` | `public, max-age={ttl}, must-revalidate` | Enable CDN and browser caching |
| Authoritative but potentially stale (ETag) | `has_etag && !is_sensitive` | `no-cache` | Force conditional revalidation |
| Rate-limited or error response | `is_error || is_rate_limited` | `no-store` | Prevent caching of error states |


---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
is_mutation || is_sensitive || cache_max_age == 0 ? "no-store" : "public, max-age=" + string(cache_max_age) + ", must-revalidate"
```

---

### 7. Failure & Security Enforcement
- Responses containing user credentials, tokens, or PII must strictly return no-store.
- Prevents stale or contaminated caches.
- Any response containing OAuth tokens, session identifiers, or JWKS material MUST declare `no-store` — leaking credentials to shared caches is a critical vulnerability.
---

### 8. Protocol Wire Example

```http
Cache-Control: no-store
```
