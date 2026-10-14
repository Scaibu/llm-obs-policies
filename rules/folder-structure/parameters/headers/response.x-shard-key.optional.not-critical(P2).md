# Parameter Specification: `x-shard-key`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `x-shard-key` |
| **Category** | `headers` |
| **Surface** | Outbound HTTP Transport Response Header |
| **Requirement Level** | **Optional** |
| **Criticality Tier** | **NOT-CRITICAL (P2)** |
| **Standard / Reference** | Consistent Hashing (Karger et al. 1997) / RFC 9110 §10.1 Custom Headers / Database Sharding Architecture |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Discloses the database shard or partition key that executed the read or write operation for diagnostics and routing transparency.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: x-shard-key
in: header
required: false
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{3,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
x-shard-key = 3*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. The server MAY return `x-shard-key` disclosing partition diagnostics.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Shard identifier available | `shard_key != null` | `shard_key` | Inject header |
| Non-sharded or hidden | `shard_key == null` | `null` | Omit header |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
shard_key != null ? shard_key : null
```

---

### 7. Failure & Security Enforcement
- Aids backend infrastructure debugging during shard rebalancing.
- Must not leak internal database credentials or cluster topologies.

---

### 8. Protocol Wire Example

```http
x-shard-key: shard-us-east-04
```
