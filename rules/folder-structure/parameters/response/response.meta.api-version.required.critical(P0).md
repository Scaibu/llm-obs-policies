# Parameter Specification: `meta.apiVersion`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.apiVersion` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | CalVer (Calendar Versioning) / Semantic Versioning 2.0.0 / JSON Schema 2020-12 |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Declares the active API contract version that produced this response, embedded in the JSON payload envelope. Provides contract version signalling at the payload layer as a redundant verification path alongside the `x-api-version` transport header. Survives header stripping by intermediary proxies, API gateways, or logging pipelines that drop custom headers.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
schema:
  type: object
  properties:
    meta:
      type: object
      required:
        - apiVersion
      properties:
        apiVersion:
          type: string
          pattern: "^(\\d{4}-\\d{2}-\\d{2}|v\\d+(\\.\\d+)?)$"
          description: "Resolved API contract version. Identical to x-api-version response header."
          examples:
            - "2024-11-01"
            - "v2"
```

> `meta.apiVersion` is a JSON body field, not a header parameter. It MUST be defined under the response schema's `meta` object, not as a `parameters` entry.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
meta-apiVersion = 4DIGIT "-" 2DIGIT "-" 2DIGIT / "v" 1*DIGIT [ "." 1*DIGIT ]
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST inject the resolved contract version into `meta.apiVersion` in every response, regardless of status code.
2. The value MUST be identical to the `x-api-version` response header — divergence is a critical contract integrity defect.
3. IF `x-api-version` header was stripped by an intermediary, clients MUST fall back to reading `meta.apiVersion` from the JSON envelope.
4. The value MUST be a stable, published version identifier — it MUST NOT include build metadata, commit hashes, or environment suffixes.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| All responses (success or error) | `true` | `resolved_api_version` | Inject into `meta.apiVersion` |
| Header `x-api-version` is present | `x_api_version_header != null` | Must equal `x_api_version_header` | Mismatch triggers integrity alert |
| Header was stripped by proxy | `x_api_version_header == null` | `resolved_api_version` | Client reads from body as fallback |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
x_api_version_header != null && x_api_version_header != resolved_api_version
  ? "ERROR_VERSION_MISMATCH"
  : resolved_api_version
```

---

### 7. Failure & Security Enforcement
- Ensures contract version is accessible even when transport headers are stripped by load balancers, API gateways, or logging proxies.
- MUST match `x-api-version` response header exactly — mismatches indicate a routing or deployment misconfiguration.
- Version string MUST be immutable once published; changes require a new version identifier.
- Deprecated versions MUST still populate this field until the sunset date passes.

---

### 8. Protocol Wire Example

```json
{
  "meta": {
    "apiVersion": "2024-11-01"
  }
}
```
