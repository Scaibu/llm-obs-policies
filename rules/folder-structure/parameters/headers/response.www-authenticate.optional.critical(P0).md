# Parameter Specification: `WWW-Authenticate`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `WWW-Authenticate` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional (Conditionally Mandatory on HTTP 401)** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 9110 §11.6.1 / RFC 6750 §3 Bearer Token Challenge |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Returns a structured Bearer authentication challenge to the client when access is denied due to missing, expired, or invalid credentials. Conforming clients parse the `error` and `error_description` parameters to determine whether to re-authenticate, refresh an expired token, or escalate to the user.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: WWW-Authenticate
in: header
required: false
schema:
  type: string
  pattern: "^Bearer(\\s+[a-zA-Z0-9_]+=\\S*(,\\s*[a-zA-Z0-9_]+=\\S*)*)?$"
  examples:
    - 'Bearer error="invalid_token", error_description="The access token expired."'
    - 'Bearer error="insufficient_scope", error_description="Required scope: read:events"'
    - 'Bearer realm="api.example.com"'
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
WWW-Authenticate  = "Bearer" [ RWS 1#auth-param ]
auth-param        = token "=" ( token / quoted-string )
token             = 1*tchar
tchar             = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+"
                  / "-" / "." / "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
quoted-string     = DQUOTE *( qdtext / quoted-pair ) DQUOTE
```

> Per RFC 6750 §3, the `error` attribute MUST be one of: `invalid_request`, `invalid_token`, `insufficient_scope`.

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. On any HTTP 401 response, the server MUST include the `WWW-Authenticate` response header.
2. The challenge MUST begin with the `Bearer` authentication scheme token per RFC 6750 §3.
3. The server MUST include the `error` auth-param with a value from the RFC 6750 §3.1 error registry: `invalid_request`, `invalid_token`, or `insufficient_scope`.
4. The server SHOULD include an `error_description` auth-param containing a human-readable explanation suitable for logging (MUST NOT expose internal system details).
5. The server MAY include an `error_uri` auth-param pointing to a public documentation URL for the error code.
6. The server MUST omit this header entirely on all non-401 responses (including 403 Forbidden).
7. The header value MUST NOT include the raw token that caused the failure.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| HTTP 401 — header absent or non-Bearer prefix | `status == 401 && missing_or_invalid_prefix` | `Bearer error="invalid_request"` | Direct client to re-authenticate |
| HTTP 401 — token expired | `status == 401 && token_expired` | `Bearer error="invalid_token", error_description="..."` | Direct client to refresh token |
| HTTP 401 — token signature invalid | `status == 401 && sig_invalid` | `Bearer error="invalid_token", error_description="..."` | Direct client to re-authenticate |
| HTTP 401 — insufficient scope | `status == 401 && insufficient_scope` | `Bearer error="insufficient_scope", error_description="..."` | Direct client to request elevated scope |
| HTTP 403 (Forbidden, not 401) | `status == 403` | `OMITTED` | Header MUST NOT be present |
| HTTP 2xx / 4xx (non-401) | `status != 401` | `OMITTED` | Header MUST NOT be present |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
status_code == 401
  ? "Bearer error=\"" + error_code + "\", error_description=\"" + error_description + "\""
  : null
```

> `error_code` MUST resolve to one of `invalid_request`, `invalid_token`, `insufficient_scope` per RFC 6750 §3.1.

---

### 7. Failure & Security Enforcement
- MUST be present on every HTTP 401 response — absence is a protocol violation per RFC 9110 §11.6.1.
- MUST be absent on HTTP 403 (Forbidden is an authorisation, not an authentication, failure).
- The raw bearer token that triggered the 401 MUST NOT appear in any part of the header value.
- `error_description` MUST be sanitised — MUST NOT include SQL, stack traces, or internal service names.
- Intermediate proxies MUST forward this header unchanged to the client.
- Directs client whether to re-authenticate (invalid credentials) or refresh (expired token).

---

### 8. Protocol Wire Example

```http
WWW-Authenticate: Bearer error="invalid_token", error_description="The access token has expired."
```
