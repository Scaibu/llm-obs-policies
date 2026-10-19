---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_LOGGING_OR_ERROR_CREATION"
agent_role: "Principal Privacy Officer & Data Leakage Prevention Auditor"
target_scope: "PII Sanitization, Credential Masking, Problem Details Errors, Traces & Core Dumps"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Data Leakage Prevention Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Whitelist-Based Structured Logging (Zero Secrets Logged)
Application logging MUST operate on an explicit allowlist of loggable fields.
The following fields MUST NEVER appear in application logs, audit logs, or error metadata under any circumstances:
- Headers: `Authorization`, `Cookie`, `Set-Cookie`, `x-api-key`, `Proxy-Authorization`.
- Bodies: Passwords, credit card numbers, private cryptographic keys, raw secrets.
- PII fields (email, SSN, phone numbers) MUST be hashed (SHA-256 with salt) or masked (`j***@example.com`).

Guardrail 2: Sanitized RFC 9457 Problem Details (Zero Internal Leaks)
Error envelopes returned to clients MUST NEVER include:
- Raw database SQL errors or table/column names.
- Internal microservice hostnames, IP addresses, or ports.
- Language stack traces or runtime memory addresses.
Detailed technical stack traces MUST remain strictly in server-side logs, keyed by `requestId`.

Guardrail 3: Distributed Trace Scrubbing
OpenTelemetry spans, tags, and baggage MUST be sanitized before export to collector backends. Inbound headers matching secret tokens MUST be redacted before populating span attributes.

Guardrail 4: Core & Heap Dump Encryption
Memory core dumps and heap snapshots MUST be disabled in production containers, or configured to write encrypted files to restricted storage buckets accessible only by authorized security personnel.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside sanitization filters. Document the scrubbing allowlist and masking algorithms in the file header docblock.

---

## 2. Leakage Prevention Contract

```yaml
leakage_prevention_contract:
  forbidden_log_keys:
    - "authorization"
    - "cookie"
    - "set-cookie"
    - "password"
    - "api_key"
    - "token"
    - "secret"
  error_envelope:
    allow_stack_traces_to_client: false
    allow_sql_in_messages: false
    schema: "RFC_9457_PROBLEM_DETAILS"
  tracing:
    header_scrub_regex: "(?i)(auth|token|key|secret|cookie)"
  core_dumps:
    enabled: false
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Database Constraint Violation Leak Fix**: When a SQL unique constraint fails (`duplicate key value violates unique constraint "users_email_key"`), do not return the raw driver message. Catch the exception, extract the domain violation, and return: `{type: "CONFLICT", detail: "The provided email is already registered"}`.
2. **Unhandled 500 Crash Traceback Fix**: In the root exception handler, log `logger.error("Unhandled error", exc_info=True, extra={"request_id": req_id})`, and return an opaque envelope: `{status: 500, title: "Internal Server Error", instance: req_id}`.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Scrub Sensitive Headers in Middleware
Apply regex redaction (`[REDACTED]`) over header dictionaries before logging incoming request metadata.

### Instruction 2: Never Echo Raw Unvalidated Request Body in Error
If JSON parsing fails, return `{status: 400, detail: "Malformed JSON payload"}`; do not echo the raw unparsed string back to the user.
