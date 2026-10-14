# Parameter Specification: `x-api-version`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-api-version` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | CalVer ISO-8601 Date Format (YYYY-MM-DD) or Major Version (v2) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Designates the requested API contract version. Evaluated against active, deprecated, and retired versions in the registry.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-api-version
in: header
required: true
schema:
  type: string
  pattern: "^(\d{4}-\d{2}-\d{2}|v\d+)$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-api-version = 4DIGIT "-" 2DIGIT "-" 2DIGIT / "v" 1*DIGIT
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST resolve the requested version from `x-api-version` (or URL path fallback).
2. The server SHALL check the resolved version against the active versions registry.
3. IF the version is retired, the server MUST reject with HTTP 410 GONE or 400 UNSUPPORTED_API_VERSION.
4. IF deprecated, the server SHALL process the request and inject `Deprecation` and `Sunset` headers.
5. The server MUST echo the resolved version in response header `x-api-version` and `meta.apiVersion`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Version in active supported list | `version in active_versions` | `ACTIVE` | Process normally |
| Version in deprecated list | `version in deprecated_versions` | `DEPRECATED` | Inject Deprecation and Sunset headers |
| Version retired or undeclared | `!(version in supported_versions)` | `ERROR 400` | Reject with UNSUPPORTED_API_VERSION and meta.supportedVersions |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
version in active_versions
  ? "ACTIVE"
  : version in deprecated_versions
    ? "DEPRECATED"
    : "UNSUPPORTED"
```

---

### 7. Failure & Security Enforcement
- Unsupported or retired versions must immediately trigger HTTP 400 UNSUPPORTED_API_VERSION.
- Deprecated versions must inject Deprecation and Sunset headers into response.
- Version strings MUST be immutable once published — a deployed version identifier must not be silently mapped to a different contract.
- Clients sending an unsupported version MUST receive HTTP 400 with error code `UNSUPPORTED_API_VERSION` and the list of supported versions.
---

### 8. Protocol Wire Example

```http
x-api-version: 2024-11-01
```
