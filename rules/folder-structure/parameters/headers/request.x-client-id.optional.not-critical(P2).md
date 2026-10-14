# Parameter Specification: `x-client-id`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-client-id` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | RFC 6749 §2.2 OAuth 2.0 Client Identifier / OpenID Connect Client Metadata |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Identifies the client software application or integration partner making the call. Used for rate limit tiering and metric slicing.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-client-id
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{3,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-client-id = 3*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server SHALL extract `x-client-id` from inbound request headers.
2. The server SHALL sanitize characters to prevent log injection.
3. IF absent, the server SHALL assign default value `unknown-client`.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Valid identifier present | `raw.matches('^[a-zA-Z0-9_-]{3,64}$') == true` | `Trim(raw)` | Group metrics by client |
| Absent or malformed | `raw == null || match fails` | `unknown-client` | Group under unknown tier |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers["x-client-id"]) && request.headers["x-client-id"].matches("^[a-zA-Z0-9_-]{3,64}$")
  ? request.headers["x-client-id"].trim()
  : "unknown-client"
```

---

### 7. Failure & Security Enforcement
- Cannot replace Authorization bearer authentication.
- Used exclusively for telemetry and quota grouping.

---

### 8. Protocol Wire Example

```http
x-client-id: ios-mobile-app-v3.4
```
