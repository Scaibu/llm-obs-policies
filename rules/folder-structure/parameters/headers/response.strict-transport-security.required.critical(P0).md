# Parameter Specification: `Strict-Transport-Security`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `Strict-Transport-Security` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on All Responses** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 6797 HSTS Directive |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Instructs user agents and clients to enforce encrypted TLS connections for all future interactions, preventing SSL-stripping and man-in-the-middle attacks.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: Strict-Transport-Security
in: header
required: true
schema:
  type: string
  pattern: "^max-age=[0-9]+; includeSubDomains; preload$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
Strict-Transport-Security = directive *( OWS ";" OWS directive )
directive                 = "max-age=" 1*DIGIT / "includeSubDomains" / "preload"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST set `Strict-Transport-Security` on ALL HTTPS responses with a minimum `max-age` of 31536000 seconds (1 year).
2. The server SHOULD include the `includeSubDomains` directive to extend HSTS policy to all subdomains of the origin.
3. The server SHOULD include the `preload` directive only when the domain is enrolled in the HSTS preload list (https://hstspreload.org/).
4. The gateway MUST strip `Strict-Transport-Security` headers from any inbound HTTP request — clients must not be able to inject HSTS policy.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Any HTTPS response | `is_https == true` | `max-age=31536000; includeSubDomains` | Enforce browser HTTPS pinning for 1 year |
| HTTP response (not HTTPS) | `is_https == false` | `OMITTED` | Header MUST NOT be set on plain HTTP |
| HSTS preload-enrolled domain | `is_preload_enrolled == true` | `max-age=31536000; includeSubDomains; preload` | Register with browser HSTS preload list |


---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
"max-age=63072000; includeSubDomains; preload"
```

---

### 7. Failure & Security Enforcement
- Must be present on all responses over HTTPS.
- Essential for banking, enterprise, and SOC2 compliance.
- HSTS without `includeSubDomains` creates subdomain downgrade attack vectors — all production origins MUST use `includeSubDomains`.
- Removing or shortening `max-age` after deployment can create a downgrade window — changes require a minimum 90-day transition period.
---

### 8. Protocol Wire Example

```http
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```
