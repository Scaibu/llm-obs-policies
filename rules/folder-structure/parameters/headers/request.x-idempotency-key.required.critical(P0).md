# Parameter Specification: `x-idempotency-key`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-idempotency-key` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY on POST / PUT / PATCH / DELETE** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | IETF Idempotency-Key HTTP Header Draft / UUIDv4 / UUIDv7 |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Prevents duplicate execution of mutating operations during network retries, timeouts, or client replays. Re-executing with identical key and payload returns cached response.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-idempotency-key
in: header
required: true
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{16,128}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-idempotency-key = 16*128( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST require `x-idempotency-key` on all mutating HTTP methods (POST, PUT, PATCH, DELETE).
2. IF a mutating request arrives without `x-idempotency-key`, the server MUST reject with HTTP 400 IDEMPOTENCY_KEY_MISSING.
3. The server SHALL calculate the canonical SHA-256 digest of the request payload, method, and URI.
4. IF a cached record exists for the key and payload hash matches, the server MUST return the cached response with `x-cache-hit: true`.
5. IF a cached record exists but payload hash differs, the server MUST reject with HTTP 409 IDEMPOTENCY_KEY_REUSE.
6. IF no record exists, the server SHALL acquire a distributed lock and proceed with execution.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Non-mutating method (GET/HEAD) | `!is_mutation` | `PROCEED` | Bypass idempotency layer |
| Mutating method with key missing | `is_mutation && raw == null` | `ERROR 400` | Reject with IDEMPOTENCY_KEY_MISSING |
| Key present, exact payload hash match | `cached != null && cached.hash == current_hash` | `RETURN_CACHED` | Echo cached response with x-cache-hit: true |
| Key present, payload hash mismatch | `cached != null && cached.hash != current_hash` | `ERROR 409` | Reject with IDEMPOTENCY_KEY_REUSE |
| Key present, no cached record | `cached == null` | `PROCEED` | Acquire lock and execute mutation |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!is_mutation
  ? "PROCEED"
  : !has(request.headers["x-idempotency-key"])
    ? "ERROR_MISSING"
    : cached_record != null
      ? (cached_record.payload_hash == incoming_payload_hash ? "RETURN_CACHED" : "ERROR_KEY_REUSE")
      : "PROCEED"
```

---

### 7. Failure & Security Enforcement
- Reusing an idempotency key with a mutated payload hash must return HTTP 409 IDEMPOTENCY_KEY_REUSE.
- Cached response replay must set x-cache-hit: true in response headers.
- Idempotency records must have a minimum 24-hour persistence window.

---

### 8. Protocol Wire Example

```http
x-idempotency-key: 018f6e2c-5b3a-7d4e-8f1a-9c2b3d4e5f60
```
