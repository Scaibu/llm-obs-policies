# Parameter Specification: `Link`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Link` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 8288 Web Linking Standard |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Provides typed navigational links in HTTP transport headers (e.g. successor-version documentation, next/prev pagination links).

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Link
in: header
required: false
schema:
  type: string
  pattern: "^<https?://[^>]+>;\s*rel="[a-zA-Z0-9_-]+"(,\s*<https?://[^>]+>;\s*rel="[a-zA-Z0-9_-]+")*$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Link = #link-value
link-value = "<" URI-reference ">" *( OWS ";" OWS link-param )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MAY format hypermedia links into RFC 8288 `Link` transport headers.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Links list provided | `links.size() > 0` | `Formatted RFC 8288 Link header` | Inject header |
| No links list | `links.size() == 0` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
links.size() > 0 ? links.map(l, "<" + l.uri + ">; rel="" + l.rel + """).join(", ") : null
```

---

### 7. Failure & Security Enforcement
- Enables clients to discover successor versions on deprecated routes.
- Provides standards-based pagination traversal.

---

### 8. Protocol Wire Example

```http
Link: <https://api.example.com/v3/orders>; rel="successor-version"
```
