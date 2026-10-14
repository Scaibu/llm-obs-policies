# Parameter Specification: `X-RateLimit-Reset`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `X-RateLimit-Reset` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **MANDATORY on All Responses** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | IETF draft-polli-ratelimit-headers-02 / POSIX.1-2017 Unix Epoch Seconds / RFC 6585 §4 |
| **Schema Type** | `integer` |

---

### 1. Architectural Purpose & Scope
Unix epoch timestamp in seconds at which the current rate limit quota window resets and full budget is restored.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: X-RateLimit-Reset
in: header
required: true
schema:
  type: integer
  minimum: 0
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
X-RateLimit-Reset = 10*DIGIT
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST inject `X-RateLimit-Reset` on every HTTP response with the Unix epoch timestamp (seconds) at which the current window expires.
2. The reset timestamp MUST be computed from the window start time plus the window duration — it MUST NOT be a relative delta.
3. The server clock used for this value MUST be NTP-synchronised to avoid client mis-timing on back-off.
4. On 429 responses, `X-RateLimit-Reset` MUST be consistent with the `Retry-After` header value.


---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Normal response, window active | `quota.remaining > 0` | `quota.reset_epoch_seconds` | Inject reset timestamp |
| 429 response, quota exhausted | `quota.remaining <= 0` | `quota.reset_epoch_seconds` | Inject; pair with Retry-After |
| Server clock not NTP-synced | `!ntp_synced` | Best-effort estimate | Log NTP warning; do not omit header |


---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
rate_quota.remaining <= 0
  ? string(rate_quota.reset_epoch_seconds)
  : string(rate_quota.reset_epoch_seconds)
```

> Both branches emit the same value — the conditional makes the dependency on `remaining` explicit for downstream rule engines and test harnesses.

---

### 7. Failure & Security Enforcement
- Provides exact timestamp when quota refreshes.
- Paired with Retry-After on 429 errors.
- The reset timestamp MUST use Unix epoch seconds (not milliseconds and not HTTP-date format) for machine-parseable client back-off calculations.
- On 429 responses, `Retry-After` header seconds value MUST align with `X-RateLimit-Reset - current_epoch` — inconsistency causes client retry storms.
---

### 8. Protocol Wire Example

```http
X-RateLimit-Reset: 1700000060
```
