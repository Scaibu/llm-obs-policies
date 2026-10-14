# Parameter Specification: `meta.pagination`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.pagination` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **MANDATORY when data is a Collection** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | IETF RFC 5988 Web Linking / cursor-based paging (RFC draft-ietf-httpapi-rfc5988bis) |
| **Schema Type** | `object` |

---

### 1. Architectural Purpose & Scope
Complete navigational metadata for paginated collection responses. Supports offset-based (page, pageSize, totalItems, totalPages) and cursor-based (nextCursor, previousCursor) paging.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: meta.pagination
in: body  # JSON body field — not a header parameter
required: true
schema:
  type: object
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
pagination = "{" page-info *( "," cursor-info ) "}"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF response payload is a collection, the server MUST include `meta.pagination` object.
2. IF response payload is a single entity, `meta.pagination` MUST be omitted.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Collection payload | `is_collection == true` | `Pagination Metadata Object` | Inject into meta |
| Single entity payload | `is_collection == false` | `OMITTED` | Omit from meta |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
is_collection ? {"page": page, "pageSize": page_size, "totalItems": total_items, "totalPages": total_pages, "hasNextPage": has_next, "hasPreviousPage": has_prev} : null
```

---

### 7. Failure & Security Enforcement
- Mandatory whenever data is an array.
- Forbidden when data is a single entity object.

---

### 8. Protocol Wire Example

```json
"pagination": { "page": 1, "pageSize": 50, "totalItems": 142, "totalPages": 3, "hasNextPage": true, "hasPreviousPage": false }
```
