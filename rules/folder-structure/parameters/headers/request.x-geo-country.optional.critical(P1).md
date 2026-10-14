# Parameter Specification: `x-geo-country`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-geo-country` |
| **Category** | `headers` |
| **Surface** | Inbound HTTP Transport Request Header |
| **Requirement Level** | **Optional / Injected by Edge CDN** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | ISO 3166-1 alpha-2 Country Codes / MaxMind GeoIP2 / RFC 5646 Language Tags |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Injected by edge CDN / reverse proxy to convey client physical jurisdiction. Enforces data residency, compliance geofencing, and localized content delivery.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-geo-country
in: header
required: false
schema:
  type: string
  pattern: "^[A-Z]{2}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-geo-country = 2UPPER
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The edge proxy MUST overwrite any client-submitted `x-geo-country` with verified GeoIP lookup.
2. The application server SHALL compare country code against compliance embargo lists.
3. IF blocked, the server MUST reject with HTTP 403 GEO_BLOCKED.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Country permitted under policy | `!(country in blocked_countries)` | `PERMITTED` | Route to region |
| Country on embargo blacklist | `country in blocked_countries` | `ERROR 403` | Reject with GEO_BLOCKED |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
country in blocked_countries ? "ERROR_GEO_BLOCKED" : "PERMITTED"
```

---

### 7. Failure & Security Enforcement
- Edge gateway must overwrite client-submitted values to prevent geo spoofing.
- Used to route traffic to region-specific database partitions.

---

### 8. Protocol Wire Example

```http
x-geo-country: US
```
