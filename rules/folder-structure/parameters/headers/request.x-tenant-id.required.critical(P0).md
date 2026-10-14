# Parameter Specification: `x-tenant-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-tenant-id` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY in Multi-Tenant Environments** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 4122 UUID / IETF RFC 2616 Custom Extension Headers / Multi-Tenancy SaaS Architecture (ISO/IEC 17788) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Enforces strict logical tenant boundary isolation. Ingested at edge gateway, verified against JWT claims, and bound to database connection pool and cache namespaces.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-tenant-id
in: header
required: true
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{3,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-tenant-id = 3*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST extract `x-tenant-id` on multi-tenant service routes.
2. IF missing, the server MUST reject with HTTP 400 MISSING_TENANT_ID.
3. The server MUST cross-validate `x-tenant-id` against the tenant claim in the authenticated JWT token.
4. IF mismatch is detected, the server MUST reject with HTTP 403 FORBIDDEN.
5. The server SHALL bind the validated tenant ID to database and cache execution namespaces.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header absent in multi-tenant environment | `header == null` | `ERROR 400` | Reject with MISSING_TENANT_ID |
| Header present and matches JWT claim | `header == token.tenant_id` | `VALIDATED` | Bind to tenant partition |
| Header present but mismatches JWT claim | `header != token.tenant_id` | `ERROR 403` | Reject with FORBIDDEN cross-tenant violation |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
!has(request.headers["x-tenant-id"])
  ? "ERROR_MISSING"
  : has(token.tenant_id) && request.headers["x-tenant-id"] != token.tenant_id
    ? "ERROR_MISMATCH"
    : "VALIDATED"
```

---

### 7. Failure & Security Enforcement
- Cross-tenant data access is a P0 security incident.
- Header value must strictly match JWT claims when token is present.
- Cross-tenant data access caused by header mismatch with JWT claim is a P0 security incident — must trigger immediate security alert and audit entry.
- Tenant ID MUST be used as the primary namespace key for all database queries, cache lookups, and event bus topics — unscoped queries are forbidden.
---

### 8. Protocol Wire Example

```http
x-tenant-id: tenant-us-enterprise-01
```
