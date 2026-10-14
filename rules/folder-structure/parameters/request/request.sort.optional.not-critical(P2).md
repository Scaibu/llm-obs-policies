# Parameter Specification: `sort`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `sort` |
| **Category** | `request` |
| **Surface** | Inbound HTTP URL Query Parameter |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | JSON:API v1.1 §7.2 Sorting / OData v4 $orderby / IETF RFC 5988 (link relation ordering) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Directs the sort order of collection results. Ascending by default; prefix with hyphen '-' for descending sort.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: sort
in: query
required: false
schema:
  type: string
  pattern: "^(-?[a-zA-Z0-9_.]+(,-?[a-zA-Z0-9_.]+)*)$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
sort = sort-field *( "," sort-field )
sort-field = [ "-" ] 1*( ALPHA / DIGIT / "_" / "." )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL extract `sort` query string.
2. The server MUST validate requested sort fields against permitted indexed fields whitelist.
3. Unindexed or unpermitted sort fields MUST be ignored or rejected.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Sort field in whitelist without prefix | `field in allowed_sort_fields` | `ASCENDING on field` | Apply ORDER BY field ASC |
| Sort field in whitelist with '-' prefix | `field in allowed_sort_fields` | `DESCENDING on field` | Apply ORDER BY field DESC |
| Field not in whitelist | `!(field in allowed_sort_fields)` | `IGNORED` | Discard unpermitted field |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
request.query.sort.split(",").filter(s, (s.startsWith("-") ? s.substring(1) : s) in allowed_sort_fields)
```

---

### 7. Failure & Security Enforcement
- Sorting on unindexed or unpermitted columns must be rejected or omitted.
- Protects against database full-table-scan DOS vulnerabilities.

---

### 8. Protocol Wire Example

```http
GET /api/v2/orders?sort=-createdAt,totalAmount HTTP/1.1
```
