# Parameter Specification: `Authorization`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Authorization` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **MANDATORY on Protected Endpoints** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 6750 OAuth 2.0 Bearer Token / RFC 7519 JSON Web Token |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Transmits OAuth 2.0 / JWT bearer credentials for caller authentication. Cryptographically validated against public JWKS. Token claims establish subject identity and roles.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Authorization
in: header
required: true
schema:
  type: string
  pattern: "^Bearer\s+[a-zA-Z0-9_\-\.]+$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Authorization = "Bearer" RWS 1*( ALPHA / DIGIT / "-" / "_" / "." )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST require `Authorization` header on all non-public endpoints.
2. The server SHALL verify the presence of the `Bearer ` credential prefix.
3. The server MUST validate the cryptographic signature against trusted public keys (JWKS).
4. The server MUST verify that the token is not expired (`exp` > current_time).
5. IF validation fails, the server MUST return HTTP 401 with `WWW-Authenticate` header challenge.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Header absent or non-Bearer prefix | `!raw.startsWith('Bearer ')` | `ERROR 401` | Emit WWW-Authenticate challenge |
| Token expired or signature invalid | `!verify(token)` | `ERROR 401` | Emit WWW-Authenticate invalid_token |
| Token cryptographically verified | `verify(token) == true` | `AUTHENTICATED` | Bind principal subject and claims |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
has(request.headers.authorization) && request.headers.authorization.startsWith("Bearer ")
  ? (verify_jwt(request.headers.authorization.substring(7)) ? "AUTHENTICATED" : "ERROR_INVALID_TOKEN")
  : "ERROR_UNAUTHENTICATED"
```

---

### 7. Failure & Security Enforcement
- Missing or invalid credentials must yield HTTP 401 UNAUTHENTICATED with WWW-Authenticate challenge.
- Expired tokens must return HTTP 401 with explicit error_description.
- Tokens must never be logged or echoed in response bodies or headers.

---

### 8. Protocol Wire Example

```http
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```
