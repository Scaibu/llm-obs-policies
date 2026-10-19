---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_SECURITY_RULE_CREATION"
agent_role: "Principal Application Security Architect & Path Canonicalization Auditor"
target_scope: "Path Traversal, Decompression Bombs, ReDoS Protection & Method Override"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Request-Shape Attack Defense Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Strict Path Canonicalization Invariant (RFC 3986 §5.2.4)
Before route matching or authorization execution, incoming request paths MUST be strictly canonicalized:
- Decode percent-encoding exactly once.
- Reject requests containing encoded slashes (`%2F`, `%5C`), null bytes (`%00`), or double-encoding (`%252F`) with HTTP 400 Bad Request.
- Resolve relative dot segments (`/../`, `/./`) or reject with HTTP 400.
- Never "auto-fix" or silently rewrite ambiguous paths; ambiguous paths MUST be rejected.

Guardrail 2: Decompression Bomb & Zip-Bomb Limits
When request body decompression (gzip, deflate, zstd) is enabled:
- `Content-Encoding` MUST be verified against an explicit route whitelist.
- The decompression stream MUST enforce two simultaneous ceilings:
  1. Maximum decompressed byte limit (default: 10 MiB).
  2. Maximum compression ratio (maximum: 10:1).
Exceeding either threshold MUST abort decompression immediately with HTTP 413 Payload Too Large.

Guardrail 3: Linear-Time Route Matching (ReDoS Defense)
All route matchers, regex validators, and path patterns MUST execute in strictly linear time $O(N)$ (e.g. Google RE2, deterministic automata). Non-linear backtracking regular expressions vulnerable to catastrophic backtracking Denial of Service (ReDoS) are strictly prohibited.

Guardrail 4: Prohibition of Client Method Overrides
The server MUST NEVER honor client-supplied HTTP method override headers (`X-HTTP-Method`, `X-HTTP-Method-Override`, `_method` query parameter) unless explicitly declared for legacy tunnel proxies. All routing must strictly follow the native transport HTTP verb.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside security filter functions. Document the canonicalization and decompression algorithms in the file header docblock.

---

## 2. Request-Shape Defense Contract

```yaml
request_shape_contract:
  canonicalization:
    decode_percent_once: true
    reject_encoded_slash: true
    reject_null_bytes: true
    reject_double_encoding: true
    trailing_slash_policy: "STRICT_MATCH" # STRICT_MATCH | REDIRECT
  decompression:
    allowed_encodings: ["gzip", "deflate"]
    max_decompressed_bytes: 10485760 # 10 MiB
    max_compression_ratio: 10.0
  regex_engine: "LINEAR_TIME_RE2"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Path Traversal Bypass (`/v1/auth/../../admin`) Fix**: Pass raw URI through RFC 3986 §5.2.4 path normalization before checking route permissions. Normalized path `/admin` is evaluated against admin authorization rules, preventing authentication bypass.
2. **Gzip Decompression Bomb (1MB $\rightarrow$ 10GB) Fix**: Wrap the body decompression stream with a counting reader. If decompressed byte counter exceeds 10 MiB, close stream and return HTTP 413 immediately.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Use Vulnerable Backtracking Regex
Avoid nested quantifiers like `(a+)+$` in route paths or header validators; use RE2 or simple prefix/exact string matchers.

### Instruction 2: Reject Null Bytes in URL
Check for `\x00` in query strings and path segments; reject with HTTP 400 immediately.
