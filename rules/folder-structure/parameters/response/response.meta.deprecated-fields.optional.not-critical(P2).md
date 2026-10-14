# Parameter Specification: `meta.deprecatedFields`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.deprecatedFields` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **MANDATORY when Response Contains Deprecated Attributes** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 8594 Sunset Header / IETF Deprecation Header draft-ietf-httpapi-deprecation-header / OpenAPI Deprecated Flag |
| **Schema Type** | `array` |

---

### 1. Architectural Purpose & Scope
Notifies caller that one or more attributes returned in the data payload are deprecated and will be removed in a future contract release.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: meta.deprecatedFields
in: body  # JSON body field — not a header parameter
required: true
schema:
  type: array
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
deprecatedFields = "[" DQUOTE field-name DQUOTE *( "," DQUOTE field-name DQUOTE ) "]"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL compare returned payload keys against schema deprecation registry.
2. IF deprecated keys are present, the server MUST return their names in `meta.deprecatedFields`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Deprecated attributes present in payload | `deprecated_keys.size() > 0` | `Array of deprecated field names` | Inject into meta |
| No deprecated attributes present | `deprecated_keys.size() == 0` | `null` | Omit from meta |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
payload_keys.filter(k, k in deprecated_keys_registry).size() > 0 ? payload_keys.filter(k, k in deprecated_keys_registry) : null
```

---

### 7. Failure & Security Enforcement
- Provides in-band schema migration signals without breaking runtime.
- SDKs log warnings when deprecated fields are accessed.

---

### 8. Protocol Wire Example

```json
"deprecatedFields": [ "legacyCustomerId", "oldNotes" ]
```
