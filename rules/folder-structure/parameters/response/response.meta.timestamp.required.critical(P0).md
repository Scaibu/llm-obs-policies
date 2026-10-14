# Parameter Specification: `meta.timestamp`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.timestamp` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **MANDATORY** |
| **Criticality Tier** | **CRITICAL (P0)** |
| **Standard / Reference** | RFC 3339 §5.6 / ISO 8601:2004 UTC / POSIX.1-2017 Clock (CLOCK_REALTIME) |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Authoritative server-side UTC clock timestamp recorded at the moment the response payload is fully serialised and queued for transmission. Allows clients to calculate local clock skew relative to the authoritative server clock, measure end-to-end network transit latency (`client_received_at - meta.timestamp`), and order events correctly in distributed audit trails.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
schema:
  type: object
  properties:
    meta:
      type: object
      required:
        - timestamp
      properties:
        timestamp:
          type: string
          format: date-time
          pattern: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$"
          description: "RFC 3339 / ISO 8601 UTC timestamp with millisecond precision and literal Z suffix."
          examples:
            - "2026-08-23T13:12:00.012Z"
```

> The `pattern` enforces exactly 3 decimal digits (millisecond precision) and a literal `Z` UTC designator. Offset notation (`+05:30`) is forbidden.

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
meta-timestamp = date "T" time-of-day "." 3DIGIT "Z"
date           = 4DIGIT "-" 2DIGIT "-" 2DIGIT
time-of-day    = 2DIGIT ":" 2DIGIT ":" 2DIGIT
```

> Conforms to RFC 3339 §5.6 `date-time` production, restricted to UTC-only with millisecond sub-second component.

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MUST record the clock value from a monotonic UTC source (POSIX `CLOCK_REALTIME`) at response serialisation completion.
2. The server MUST format the value as RFC 3339 `date-time` with exactly 3 sub-second decimal digits (millisecond precision).
3. The literal character `Z` MUST be used as the UTC designator — numeric timezone offsets (`+00:00`) MUST NOT be used.
4. The server MUST inject the formatted timestamp into `meta.timestamp` before transmitting the response.
5. IF the server clock is unsynchronised (NTP drift > 1 second), the server SHOULD emit a log warning; it MUST NOT omit the field.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Clock source available, NTP synchronised | `clock_available && ntp_synced` | `UTC_NOW_MS` in RFC 3339 | Inject into `meta.timestamp` |
| Clock source available, NTP drift detected | `clock_available && !ntp_synced` | `UTC_NOW_MS` in RFC 3339 | Inject; emit NTP drift warning log |
| Clock source unavailable (edge failure) | `!clock_available` | `null` | Omit field; log critical clock failure |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
clock_available
  ? format_rfc3339_ms(utc_now())
  : null
```

---

### 7. Failure & Security Enforcement
- MUST use literal `Z` UTC suffix — timezone offset variants (`+00:00`, `+05:30`) are forbidden.
- MUST include millisecond precision (`.NNNz`) — second-only timestamps are non-conformant.
- Server clocks MUST be synchronised via NTP/PTP to a stratum-2 or better source to maintain accurate distributed timestamps.
- Clients MUST NOT use this field as a security nonce or replay-prevention mechanism — use `x-nonce` for that purpose.
- Clock skew greater than 5 minutes from client time SHOULD trigger a client-side warning.

---

### 8. Protocol Wire Example

```json
{
  "meta": {
    "timestamp": "2026-08-23T13:12:00.012Z"
  }
}
```
