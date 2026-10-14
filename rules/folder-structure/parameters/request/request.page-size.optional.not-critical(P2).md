# Parameter Specification: `pageSize`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `pageSize` |
| **Category** | `request` |
| **Surface** | Inbound HTTP URL Query Parameter |
| **Requirement Level** | **Optional (Default: 50, Maximum: 250)** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 5988 Web Linking (rel=next) / JSON:API v1.1 Pagination / IETF draft-ietf-httpapi-rfc5988bis |
| **Schema Type** | `integer` |

---

### 1. Architectural Purpose & Scope
Specifies the maximum number of entity records returned in a single paginated collection page.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: pageSize
in: query
required: false
schema:
  type: integer
  minimum: 0
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
pageSize = 1*3DIGIT
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL parse `pageSize` query parameter.
2. IF missing or invalid, the server MUST default to 50.
3. The server MUST clamp requested values to the maximum boundary of 250.
4. The server MUST declare the resolved value in `meta.pagination.pageSize`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Parameter absent or non-numeric | `raw == null || !is_int(raw)` | `50` | Use server default |
| Value between 1 and 250 | `int(raw) >= 1 && int(raw) <= 250` | `int(raw)` | Use requested value |
| Value exceeds 250 | `int(raw) > 250` | `250` | Clamp to maximum ceiling |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!has(request.query.pageSize) ? 50 : (int(request.query.pageSize) <= 0 ? 50 : min(int(request.query.pageSize), 250))
```

---

### 7. Failure & Security Enforcement
- Values exceeding 250 must be clamped to 250, never crashing the database.
- Must be reflected in meta.pagination.pageSize in response envelope.

---

### 8. Protocol Wire Example

```http
GET /api/v2/orders?pageSize=100 HTTP/1.1
```
