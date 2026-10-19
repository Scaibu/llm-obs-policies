---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_BROWSER_CONTROLS_CREATION"
agent_role: "Principal Web Application Security Architect & Browser Security Officer"
target_scope: "CORS Policies, CSRF Defense, Security Headers (HSTS, CSP, Sniff), Cookie Security"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Browser-Facing Controls Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Explicit CORS Origin Whitelist (Zero Blind Reflection)
- CORS `Access-Control-Allow-Origin` MUST NEVER blindly reflect the incoming `Origin` header. Allowed origins MUST be matched against an explicit, immutable allowlist.
- When `Access-Control-Allow-Credentials: true` is configured, wildcards (`*`) are strictly prohibited by browser standards and MUST trigger startup configuration failure.
- CORS preflight (`OPTIONS`) requests MUST be answered early in the pipeline (before authentication) with a strict `Access-Control-Max-Age` (e.g. 86400s) and explicit allowed headers/methods.

Guardrail 2: Defense-in-Depth CSRF Protection
All state-changing routes (`POST`, `PUT`, `PATCH`, `DELETE`) relying on cookie-based authentication MUST enforce CSRF protection:
- Validate `Sec-Fetch-Site: same-origin` or verify `Origin` / `Referer` match the server host.
- For public APIs consuming cookies, enforce Double Submit Cookie tokens or cryptographic anti-CSRF tokens.

Guardrail 3: Mandatory Ingress Security Headers
Every HTTP response serving public clients MUST include:
- `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload` (on TLS connections).
- `X-Content-Type-Options: nosniff` (prevents MIME-sniffing execution).
- `Referrer-Policy: strict-origin-when-cross-origin`.
- `Content-Security-Policy: default-src 'self'` (mandatory whenever serving HTML or interactive assets).

Guardrail 4: Secure Cookie Flags Invariant
All cookies set via `Set-Cookie` MUST explicitly specify:
- `Secure = true` (transmitted only over HTTPS).
- `HttpOnly = true` (inaccessible to JavaScript `document.cookie` unless explicitly declared as a client token).
- `SameSite = Lax` or `SameSite = Strict`.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside security middleware functions. Document header and CORS rules in the file header docblock.

---

## 2. Browser Controls Contract

```yaml
browser_security_contract:
  cors:
    allowed_origins:
      - "https://app.llmobs.internal"
      - "https://dashboard.llmobs.internal"
    allow_credentials: true
    allowed_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allowed_headers: ["Authorization", "Content-Type", "x-request-id", "traceparent", "x-idempotency-key"]
    max_age_seconds: 86400
  headers:
    hsts: "max-age=63072000; includeSubDomains; preload"
    nosniff: "nosniff"
    referrer_policy: "strict-origin-when-cross-origin"
    frame_options: "DENY"
  cookies:
    secure: true
    http_only: true
    same_site: "Lax"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Preflight Auth Failure (CORS 401 Bug) Fix**: In the pipeline router, handle `OPTIONS` requests before the Authentication stage. Returning a 401 on an unauthenticated preflight breaks valid browser cross-origin requests.
2. **Wildcard Origin with Credentials Vulnerability Fix**: In configuration validation, if `allow_credentials == true` and `allowed_origins` contains `*`, fail fast at Phase 1 startup with exit code `3`.
3. **MIME Confusion XSS Fix**: Ensure `X-Content-Type-Options: nosniff` is attached to all static and JSON endpoints so browsers do not execute malicious user uploads as HTML.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Check Preflight Order in Middleware Chain
Ensure CORS middleware sits ahead of JWT/Auth middleware in the pipeline stack.

### Instruction 2: Immutable Security Headers Map
Construct the security headers map once during server initialization; inject it as a zero-copy reference on every response envelope.
