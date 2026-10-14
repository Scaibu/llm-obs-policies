# Parameter Specification: `page`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `page` |
| **Category** | `request` |
| **Surface** | Inbound HTTP URL Query Parameter |
| **Requirement Level** | **Optional (Default: 1)** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 5988 Web Linking (rel=next) / JSON:API v1.1 Offset Pagination / IETF draft-ietf-httpapi-rfc5988bis |
| **Schema Type** | `integer` |

---

### 1. Architectural Purpose & Scope
Designates the 1-indexed page number to retrieve when using offset-based pagination.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: page
in: query
required: false
schema:
  type: integer
  minimum: 0
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
page = 1*DIGIT
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL parse `page` query parameter as 1-indexed positive integer.
2. IF missing or less than 1, the server MUST default to 1.
3. The server MUST reflect the active page in `meta.pagination.page`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Parameter absent or < 1 | `raw == null || int(raw) < 1` | `1` | Default to page 1 |
| Positive integer >= 1 | `int(raw) >= 1` | `int(raw)` | Fetch specified page |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!has(request.query.page) ? 1 : max(1, int(request.query.page))
```

---

### 7. Failure & Security Enforcement
- Offset pagination must be disabled on deep collections (> 10,000 items) in favor of cursor pagination.
- Must be reflected in meta.pagination.page.

---

### 8. Protocol Wire Example

```http
GET /api/v2/orders?page=3&pageSize=50 HTTP/1.1
```
