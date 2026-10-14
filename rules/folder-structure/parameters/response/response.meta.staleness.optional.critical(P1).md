# Parameter Specification: `meta.staleness`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.staleness` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **MANDATORY on Eventual Consistency Reads** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | RFC 9111 §5.2 Cache-Control (stale-while-revalidate) / IETF RFC 7234 Age Header / Eventual Consistency (CAP Theorem) |
| **Schema Type** | `object` |

---

### 1. Architectural Purpose & Scope
Discloses data staleness guarantees when reads are served from read-replicas, search indexes, or materialized caches under eventual consistency.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: meta.staleness
in: body  # JSON body field — not a header parameter
required: true
schema:
  type: object
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
staleness = "{" "maxLagMs:" 1*DIGIT "}"
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. IF read was served under eventual consistency, the server MUST include `meta.staleness` declaring `maxLagMs`.
2. Strong consistency reads SHALL omit this block.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Eventual consistency read | `consistency_level == 'eventual'` | `{"maxLagMs": max_lag_ms}` | Inject staleness object |
| Strong consistency read | `consistency_level == 'strong'` | `null` | Omit block |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
consistency_level == "eventual" ? {"maxLagMs": max_lag_ms} : null
```

---

### 7. Failure & Security Enforcement
- Crucial for banking and transactional UIs to render 'Data may be delayed' indicators.
- Omitted on strong consistency reads.

---

### 8. Protocol Wire Example

```json
"staleness": { "maxLagMs": 150 }
```
