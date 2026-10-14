# Checklist 04: Security & Adversarial Defense (Exhaustive Verification)

**Source Reference**: [Security and Adversarial Edge Cases (Parts 29–43)](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/security-and-adversarial-edge-cases.md)  
**Scope**: Complete operational checklist across Trust Boundaries, Authn/Authz Lifecycle, BOLA/IDOR, Cryptography, Envelope Encryption, Injection/SSRF/Deserialization, Logic Abuse, Supply Chain, ReDoS, Privacy/GDPR, SIEM Detection, and Principles 45–60.

---

## 1. Trust Boundaries & Core Security Architecture (Part 29)

- [ ] **Trust Boundary Verification**:
  - [ ] Are trust boundaries explicitly mapped for every network interface and microservice hop?
  - [ ] Are internal networks treated as hostile (Zero Trust architecture with mTLS and authenticated service tokens)?
- [ ] **Confused Deputy & Ambient Privilege Elimination**:
  - [ ] When a service acts on behalf of a user, does it pass both client identity and explicit scoped permissions (delegated authorization)?
  - [ ] Are internal administrative endpoints protected by explicit authorization middleware, never trusting perimeter IP whitelists alone?
- [ ] **Fail-Closed Security Defaults**:
  - [ ] Do authorization and authentication interceptors deny access by default when errors, timeouts, or policy evaluation exceptions occur?

---

## 2. Authentication, MFA & Token Lifecycle (Part 30)

- [ ] **Password & Credential Hashing**:
  - [ ] Are user passwords hashed using Argon2id, bcrypt (work factor $\ge 12$), or scrypt, never MD5 or plain SHA-256?
  - [ ] Are login endpoints protected against timing attacks using constant-time comparison on credentials?
- [ ] **Brute-Force & Credential Stuffing Defenses**:
  - [ ] Are login, password reset, and registration endpoints protected by IP and account-level rate limits with CAPTCHA step-up?
  - [ ] Are generic error messages returned on login failures ("Invalid email or password") to prevent user enumeration?
- [ ] **MFA & Step-Up Security**:
  - [ ] Are recovery codes single-use, cryptographically hashed at rest, and rate-limited against brute-force guessing?
  - [ ] Is step-up authentication (re-entering MFA/password) required prior to modifying security settings (email, password, MFA devices)?
- [ ] **Stateless Token & Session Revocation**:
  - [ ] Are refresh tokens issued as single-use tokens with automatic **Token Family Revocation** (if a used refresh token is reused, all tokens in the family are instantly revoked)?
  - [ ] Are stateless JWTs given short expiration times ($\le 15\text{ mins}$) or backed by a Redis-based revocation denylist for emergency session termination?
  - [ ] Does password reset or account compromise immediately invalidate all active sessions, JWTs, and refresh tokens across all devices?
- [ ] **OAuth2 / OIDC Integration Hardening**:
  - [ ] Are OAuth authorization flows protected by cryptographically random `state` parameters and PKCE (`code_challenge` / `code_verifier`)?
  - [ ] Are redirect URIs validated against strict exact-match whitelists (no regex or wildcard matching)?

---

## 3. Authorization Depth & Tenant Isolation (Part 31)

- [ ] **Elimination of Broken Object-Level Authorization (BOLA / IDOR)**:
  - [ ] Does every query fetching, modifying, or deleting tenant resources enforce a composite tenant check:
    ```sql
    -- Compliant Tenant Scoped Query
    SELECT * FROM invoices 
    WHERE id = :invoice_id AND tenant_id = :authenticated_tenant_id;
    ```
  - [ ] Are database-level protections (PostgreSQL Row-Level Security `USING (tenant_id = current_setting('app.current_tenant_id'))`) enabled on all multi-tenant tables?
- [ ] **State-Based & Function-Level Authorization**:
  - [ ] Does authorization verify the entity's *current state* before permitting mutations (e.g. users cannot edit an invoice that is already `PAID` or `SUBMITTED`)?
  - [ ] Are administrative actions verified against explicit role permissions at the handler level, not merely obscured in frontend navigation?

---

## 4. Cryptography, Keys & Secrets Management (Part 32)

- [ ] **Zero Hardcoded Secrets**:
  - [ ] Are all database passwords, API keys, and signing secrets fetched from a secret manager (Vault, AWS Secrets Manager, GCP Secret Manager) at runtime?
  - [ ] Are automated pre-commit scanners (TruffleHog, Gitleaks) integrated into CI pipelines to block credential leakage?
- [ ] **Envelope Encryption & Key Rotation**:
  - [ ] Is sensitive at-rest data (PII, bank accounts, API keys) encrypted via envelope encryption (KMS Key Encryption Keys wrapping local Data Encryption Keys)?
  - [ ] Are KMS keys configured for automated annual rotation without invalidating existing ciphertexts?
- [ ] **Constant-Time Comparison**:
  - [ ] Are cryptographic signatures, HMAC tokens, and authentication hashes compared using constant-time comparison utilities (`crypto.timingSafeEqual`) to prevent timing side-channel attacks?
- [ ] **Cryptographic Primitives**:
  - [ ] Are symmetric encryptions using authenticated AEAD ciphers (AES-256-GCM or ChaCha20-Poly1305) with unique, non-repeating initialization vectors (IVs)?

---

## 5. Injection, SSRF & Parser Discrepancies (Part 33)

- [ ] **100% Parameterized Queries**:
  - [ ] Are SQL/NoSQL/CQL queries strictly parameterized via ORMs or prepared statements, with zero string concatenation of user input?
- [ ] **Server-Side Request Forgery (SSRF) Defense**:
  - [ ] Are outgoing HTTP requests triggered by user URLs validated against private IP ranges:
    - `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.0/8`, `169.254.169.254` (cloud metadata endpoint), and IPv6 equivalents.
  - [ ] Are DNS rebinding attacks mitigated by resolving domain IPs and validating IP ranges immediately before establishing network connections?
- [ ] **Safe Payload Deserialization**:
  - [ ] Are untrusted payloads strictly banned from using unsafe polymorphic deserialization (Python `pickle`, Java `ObjectInputStream`, YAML `unsafe_load`)?
- [ ] **Parser Discrepancy & Smuggling Defenses**:
  - [ ] Are reverse proxy path normalizers (Nginx/Traefik) and backend application routers configured identically regarding URL-encoded slashes (`%2F`), dot segments (`/../`), and header whitespace?

---

## 6. Business Logic Abuse & Anti-Fraud (Part 34)

- [ ] **Concurrency Race Condition Protections**:
  - [ ] Are coupon redemptions, bonus credits, and wallet withdrawals locked using database-level atomic conditional updates or advisory locks to prevent concurrent double-spend attacks:
    ```sql
    UPDATE promo_codes 
    SET redeemed_count = redeemed_count + 1 
    WHERE code = :code AND redeemed_count < max_limit;
    ```
- [ ] **Inventory & Booking Reservation Expiry**:
  - [ ] Do temporary shopping cart reservations or ticket holds enforce an automatic TTL expiration that returns held stock to public inventory?
- [ ] **Scraping & Enumeration Throttles**:
  - [ ] Are bulk data endpoints (user search, catalog export) rate-limited and capped to prevent automated data harvesting?

---

## 7. Supply Chain & CI/CD Pipeline Integrity (Part 35)

- [ ] **Immutable Dependency Pinning**:
  - [ ] Are all package dependencies locked with exact versions and cryptographic hashes in lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `go.sum`, `poetry.lock`)?
  - [ ] Are container base images pinned by immutable SHA-256 digests (`image@sha256:...`) rather than mutable tags (`alpine:latest`)?
- [ ] **CI/CD Pipeline Isolation**:
  - [ ] Are GitHub Actions / CI workflows restricted from exposing repository secrets on pull requests from untrusted forks?

---

## 8. Denial of Service & Asymmetric Cost Mitigation (Part 36)

- [ ] **Regular Expression Denial of Service (ReDoS)**:
  - [ ] Are regex patterns evaluated using non-backtracking engines (e.g. Google `RE2`) or audited for catastrophic polynomial backtracking?
- [ ] **Payload Size & Complexity Limits**:
  - [ ] Is incoming JSON/XML request body size limited (e.g. max 2MB–10MB)?
  - [ ] Are GraphQL queries restricted by maximum query depth ($< 8$) and execution complexity analysis?
  - [ ] Are zip/archive upload endpoints protected against compression bombs (zip bombs) by checking decompressed size ratios before expansion?
- [ ] **Financial & External API Cost Throttles**:
  - [ ] Are endpoints that invoke expensive external APIs (SMS sending, credit card validation, AI LLM token generation) guarded by strict per-user/per-tenant budget quotas?

---

## 9. Privacy, GDPR & Audit Logging (Parts 37, 38)

- [ ] **PII Scrubbing & Log Sanitization**:
  - [ ] Are logging frameworks configured with automatic regex filters to redact passwords, credit card numbers, authorization tokens, and personal identifiers from application logs and traces?
- [ ] **Immutable Security Audit Log**:
  - [ ] Are all administrative actions, permission changes, login events, and tenant exports written to an immutable, append-only audit trail?
- [ ] **GDPR Right-to-be-Forgotten Implementation**:
  - [ ] Is there an automated, transactional deletion/anonymization pipeline that purges user personal data across primary databases, search indexes, and cache clusters?

---

## 10. Threat Modeling & Principles 45–60 Operationalized (Parts 41, 43)

- [ ] Deny by default on all endpoints, filters, and firewall rules.
- [ ] Authorize at the object, at the action, and at the time of use.
- [ ] Keep data and code strictly separated (parameterization everywhere).
- [ ] Validate and normalize all input at the boundary using a single parser.
- [ ] Attach authority to the request via short-lived scoped tokens, not ambient credentials.
- [ ] Implement defense in depth across network, application, DB, and cloud IAM layers.
- [ ] Enforce least privilege for developers, services, CI/CD runners, and background workers.
- [ ] Every secret has an owner, an expiry, and an automated rotation runbook.
- [ ] Treat any credential exposure as an active compromise—rotate immediately.
- [ ] Design for immediate revocation across sessions, tokens, and access keys.
- [ ] Make abuse computationally and financially expensive via rate limits and proof-of-work.
- [ ] Store audit logs and disaster backups in an isolated, immutable security account.
- [ ] Model adversaries as patient, automated, and possessing complete documentation.
- [ ] Test security with adversarial tooling (DAST, SAST, fuzzing, and red team exercises).
- [ ] Minimize collected data to limit breach liability.
- [ ] Treat security as an ongoing operational invariant, continuously verified against drift.
