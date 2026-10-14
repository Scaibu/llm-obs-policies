# Parameter Specification: `meta.supportedVersions`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.supportedVersions` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **MANDATORY on UNSUPPORTED_API_VERSION Errors** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | CalVer (Calendar Versioning) / Semantic Versioning 2.0.0 / RFC 9110 §10.1 Custom Headers / API Versioning Best Practice |
| **Schema Type** | `array` |

---

### 1. Architectural Purpose & Scope
Enumerates all currently active API contract versions when a caller requests an unsupported or retired version.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: meta.supportedVersions
in: body  # JSON body field — not a header parameter
required: true
schema:
  type: array
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
supportedVersions = "[" 1#version-string "]"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. When rejecting a request with `UNSUPPORTED_API_VERSION`, the server MUST include `meta.supportedVersions` listing available versions.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Error is UNSUPPORTED_API_VERSION | `error_code == 'UNSUPPORTED_API_VERSION'` | `Active versions array` | Inject into meta |
| Other responses | `error_code != 'UNSUPPORTED_API_VERSION'` | `null` | Omit from meta |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
error_code == "UNSUPPORTED_API_VERSION" ? active_supported_versions : null
```

---

### 7. Failure & Security Enforcement
- Allows clients to self-correct version negotiation upon failure.
- Prevents opaque 400 rejections.

---

### 8. Protocol Wire Example

```json
"supportedVersions": [ "2024-11-01", "2025-06-01" ]
```
