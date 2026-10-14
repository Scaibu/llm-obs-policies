# Parameter Specification: `Accept-Language`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Accept-Language` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 9110 / BCP 47 Language Tag (e.g. en-US, fr-FR) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Indicates the preferred natural language for human-readable error messages and localized responses.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Accept-Language
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z]{1,8}(-[a-zA-Z0-9]{1,8})*(\s*;\s*q=\d(\.\d+)?)?$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Accept-Language = #( language-range [ weight ] )
language-range  = ( 1*8ALPHA *( "-" 1*8ALPHANUM ) ) / "*"
weight          = OWS ";" OWS "q=" qvalue
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL extract `Accept-Language` from inbound request headers.
2. IF present, the server SHALL parse language priority tags in descending order of weight.
3. The server MUST match tags against the list of application-supported locales.
4. IF a match is found, the server SHALL localize human-readable message strings.
5. IF absent or unmatched, the server MUST fallback to the default locale (`en-US`).

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header absent or empty | `raw == null || raw == ''` | `default_locale` | Use server default locale |
| Primary tag in supported_locales | `primary_tag in supported_locales` | `primary_tag` | Select localized catalog |
| No tag in supported_locales | `all tags not in supported_locales` | `default_locale` | Fallback to default |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["accept-language"]) && request.headers["accept-language"].size() > 0
  ? (request.headers["accept-language"].split(",").map(t, t.split(";")[0].trim().lowerAscii()).filter(tag, tag in supported_locales).size() > 0
      ? request.headers["accept-language"].split(",").map(t, t.split(";")[0].trim().lowerAscii()).filter(tag, tag in supported_locales)[0]
      : default_locale)
  : default_locale
```

---

### 7. Failure & Security Enforcement
- Affects only error.message and human-facing textual labels.
- Machine-readable error codes (error.code) must never be localized.

---

### 8. Protocol Wire Example

```http
Accept-Language: en-US,en;q=0.9,fr;q=0.8
```
