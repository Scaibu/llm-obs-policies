# Parameter Specification: `x-content-sha256`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-content-sha256` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional (Conditionally Mandatory for High-Value Mutations)** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | FIPS PUB 180-4 SHA-256 / AWS Signature Version 4 / IETF draft-cavage-http-signatures |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Guarantees message integrity across intermediate transport layers. The server computes the payload hash and compares it against this header before processing.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-content-sha256
in: header
required: false
schema:
  type: string
  pattern: "^[0-9a-fA-F]{64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-content-sha256 = 64HEXDIG
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF present, the server MUST compute the SHA-256 digest of raw inbound body bytes.
2. The server MUST perform constant-time comparison between computed hash and header value.
3. IF mismatch is detected, the server MUST reject with HTTP 400 INTEGRITY_CHECK_FAILED.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header absent on standard route | `raw == null` | `PROCEED` | Bypass digest check |
| Computed hash matches header | `raw.lowerAscii() == computed_hash.lowerAscii()` | `PROCEED` | Process body |
| Computed hash differs from header | `raw.lowerAscii() != computed_hash.lowerAscii()` | `ERROR 400` | Reject with INTEGRITY_CHECK_FAILED |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!has(request.headers["x-content-sha256"]) || request.headers["x-content-sha256"].lowerAscii() == computed_body_sha256
  ? "PROCEED"
  : "ERROR_INTEGRITY_CHECK_FAILED"
```

---

### 7. Failure & Security Enforcement
- Protects financial transactions and webhook callbacks against in-transit payload tampering.
- Evaluated prior to JSON deserialization.

---

### 8. Protocol Wire Example

```http
x-content-sha256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```
