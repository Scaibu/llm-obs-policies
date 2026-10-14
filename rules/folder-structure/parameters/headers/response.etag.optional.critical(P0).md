# Parameter Specification: `ETag`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `ETag` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional (Conditionally Mandatory for Versioned Entities)** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 Strong Entity Tag |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Entity tag representing the specific version of the resource representation. Used by clients in subsequent If-Match headers for optimistic concurrency control.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: ETag
in: header
required: false
schema:
  type: string
  pattern: "^"[a-zA-Z0-9_-]+"$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
ETag = entity-tag
entity-tag = DQUOTE 1*( VCHAR ) DQUOTE
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST generate an ETag for all GET and HEAD responses on mutable resources.
2. The ETag MUST be computed from a deterministic hash of the resource version, content body, or a monotonic revision counter.
3. IF a conditional request includes `If-Match`, the server MUST compare the provided ETag to the stored resource ETag before permitting mutation.
4. IF ETags mismatch, the server MUST respond with HTTP 412 PRECONDITION_FAILED — the client must re-fetch before retrying.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Versioned resource response | `resource.is_versioned && resource.etag != null` | `"resource.etag"` | Inject ETag header |
| Non-versioned resource | `!resource.is_versioned` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
resource.etag != null ? '"' + resource.etag + '"' : null
```

---

### 7. Failure & Security Enforcement
- Must be returned on successful POST, PUT, PATCH, and GET for versioned entities.
- Must be updated atomically upon every state change.
- ETags MUST NOT expose internal implementation details (e.g., database row versions, memory addresses) — use opaque hashes.
- Weak ETags (`W/"..."`) MUST NOT be used on resources requiring strong byte-for-byte identity (e.g., content downloads, version-controlled assets).
---

### 8. Protocol Wire Example

```http
ETag: "018f6e2c-9999-7d4e-b3f2-1a2b3c4d5e6f"
```
