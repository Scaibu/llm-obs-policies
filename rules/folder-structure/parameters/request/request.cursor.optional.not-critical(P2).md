# Parameter Specification: `cursor`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `cursor` |
| **Category** | `request` |
| **Surface** | Inbound HTTP URL Query Parameter |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 5988 Web Linking / IETF draft-ietf-httpapi-rfc5988bis / JSON Web Token RFC 7519 (cursor-as-JWT pattern) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Opaque cursor pointer for keyset pagination. Provides constant O(1) performance on deep dataset traversal.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: cursor
in: query
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{16,256}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
cursor = 16*256( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL extract `cursor` query parameter.
2. IF valid, the server SHALL decode keyset boundary conditions.
3. The server MUST return opaque `nextCursor` and `previousCursor` tokens in `meta.pagination`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Cursor present and valid | `raw != null && raw.matches('^[a-zA-Z0-9_-]{16,256}$')` | `Decoded keyset boundary` | Execute keyset query |
| Cursor absent | `raw == null` | `First page initial boundary` | Execute initial query |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.query.cursor) && request.query.cursor.matches("^[a-zA-Z0-9_-]{16,256}$") ? request.query.cursor : null
```

---

### 7. Failure & Security Enforcement
- Cursor tokens must be opaque to clients.
- Reflected in meta.pagination.nextCursor and meta.pagination.previousCursor.

---

### 8. Protocol Wire Example

```http
GET /api/v2/orders?cursor=eyJpZCI6IjAxOGY2ZTJjIn0 HTTP/1.1
```
