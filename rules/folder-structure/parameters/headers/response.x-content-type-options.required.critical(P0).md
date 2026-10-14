# Parameter Specification: `X-Content-Type-Options`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `X-Content-Type-Options` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on All Responses** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | W3C Fetch Standard nosniff Directive |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Prevents browsers and HTTP clients from MIME-sniffing a response away from the declared Content-Type, mitigating script execution and drive-by download vulnerabilities.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: X-Content-Type-Options
in: header
required: true
schema:
  type: string
  pattern: "^nosniff$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
X-Content-Type-Options = "nosniff"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST set `X-Content-Type-Options: nosniff` on ALL HTTP responses, regardless of content type.
2. The directive instructs the browser to strictly honour the declared `Content-Type` and refuse MIME-type sniffing.
3. The server MUST ensure `Content-Type` is declared correctly on every response before relying on `nosniff` for protection.
4. The value MUST always be the literal string `nosniff` — no variations or additional directives are defined by the specification.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Any HTTP response | `true` | `nosniff` | Instruct browser to disable MIME sniffing |
| Response with incorrect or missing Content-Type | `content_type == null` | `nosniff` (still set) | Log Content-Type missing warning |
| Inbound request contains X-Content-Type-Options | `has_inbound` | Stripped and replaced | Server-set value always wins |


---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
"nosniff"
```

---

### 7. Failure & Security Enforcement
- Must be present on every HTTP response.
- Protects JSON endpoints against polyglot and MIME-confusion exploits.
- Missing `X-Content-Type-Options: nosniff` enables MIME confusion attacks where browsers execute scripts disguised as images or text files.
- Must be set even on API responses that return JSON — intermediary browser fetch requests can be MIME-sniffed if this header is absent.
---

### 8. Protocol Wire Example

```http
X-Content-Type-Options: nosniff
```
