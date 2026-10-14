# Parameter Specification: `x-nonce`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-nonce` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional (Conditionally Mandatory on Cryptographically Signed API Verifications)** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | NIST SP 800-90A Cryptographic Nonce / IETF RFC 5849 OAuth 1.0 Nonce / OWASP Cryptographic Storage |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Prevents replay attacks on signed REST endpoints. Paired with timestamp validation to guarantee single-use message validity.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-nonce
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{16,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-nonce = 16*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. On cryptographically signed routes, the server MUST require `x-nonce`.
2. The server MUST verify that the nonce has not been recorded in the active nonce replay cache within the 5-minute validity window.
3. IF reused, the server MUST reject with HTTP 409 NONCE_REPLAYED.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Fresh nonce unused in cache | `!is_cached(raw)` | `VALID` | Store nonce in cache with 5m TTL |
| Nonce previously recorded in cache | `is_cached(raw)` | `ERROR 409` | Reject with NONCE_REPLAYED |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!is_nonce_used(request.headers["x-nonce"]) ? "VALID" : "ERROR_NONCE_REPLAYED"
```

---

### 7. Failure & Security Enforcement
- Nonce values must expire after 5 minutes.
- Reused nonces must be rejected with 409 Conflict.

---

### 8. Protocol Wire Example

```http
x-nonce: nnc-1700000000000-8812ab
```
