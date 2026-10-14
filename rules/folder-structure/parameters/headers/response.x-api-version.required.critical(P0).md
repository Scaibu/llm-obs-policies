# Parameter Specification: `x-api-version` (Response Header)

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-api-version` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 §10.1 Custom Headers / CalVer (Calendar Versioning) / API Versioning Best Practice (Microsoft REST API Guidelines) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Declares the active API contract version used by the server to construct this specific response payload. Allows clients to detect silent version shifts when requests traverse multiple API versions (e.g., canary deployments, gradual rollouts). The value echoed here MUST exactly match `meta.apiVersion` in the JSON envelope to provide redundant contract signalling at both transport and payload layers.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-api-version
in: header
required: true
schema:
  type: string
  pattern: "^(\\d{4}-\\d{2}-\\d{2}|v\\d+(\\.\\d+)?)$"
  examples:
    - "2024-11-01"
    - "v2"
    - "v2.1"
```

> Two supported versioning strategies: CalVer (`YYYY-MM-DD`) for date-based API lifecycle management, or Major/Minor (`vN` / `vN.M`) for semantic versioning. Both MUST be stable identifiers — patch increments MUST NOT change the version string.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-api-version = calver-date / semver-major
calver-date   = 4DIGIT "-" 2DIGIT "-" 2DIGIT
semver-major  = "v" 1*DIGIT [ "." 1*DIGIT ]
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST inject `x-api-version` into every HTTP response, regardless of status code (2xx, 4xx, 5xx).
2. The version value MUST be resolved by the API gateway from the request's `x-api-version` request header and the server's deployed contract registry.
3. IF the client requested a specific version via `x-api-version` request header and that version is supported, the server MUST echo that requested version.
4. IF the client requested a version that is deprecated but still supported, the server MUST echo the requested version AND set a `Deprecation` response header with the sunset date.
5. IF the client requested a version that is unsupported or unknown, the server MUST return HTTP 400 with `UNSUPPORTED_API_VERSION` and echo the default active version in `x-api-version`.
6. The value MUST exactly match `meta.apiVersion` in the response JSON envelope.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Client requests supported active version | `requested_version in active_versions` | `requested_version` | Serve response under that contract |
| Client requests deprecated but supported version | `requested_version in deprecated_versions` | `requested_version` | Set `Deprecation` header with sunset date |
| Client omits version header (use default) | `requested_version == null` | `default_active_version` | Serve response under default contract |
| Client requests unsupported/unknown version | `requested_version not in all_versions` | `default_active_version` | Return HTTP 400 UNSUPPORTED_API_VERSION |
| Server generates any response | `true` | `resolved_version` | Mirror into `meta.apiVersion` |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
requested_version == null
  ? default_active_version
  : requested_version in active_versions
    ? requested_version
    : requested_version in deprecated_versions
      ? requested_version
      : "ERROR_UNSUPPORTED_API_VERSION"
```

---

### 7. Failure & Security Enforcement
- MUST be present on every response including error responses (4xx/5xx).
- MUST match `meta.apiVersion` exactly — a mismatch between header and body is a critical contract integrity defect.
- Clients MUST verify this header to detect silent version shifts during canary deployments or blue-green rollouts.
- Deprecated version support expiry MUST be communicated via `Sunset` response header with a minimum 90-day advance notice.
- Version identifiers MUST be immutable — once a version string is published, its contract MUST NOT be retroactively mutated.

---

### 8. Protocol Wire Example

```http
x-api-version: 2024-11-01
```
