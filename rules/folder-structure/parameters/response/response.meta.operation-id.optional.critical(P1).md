# Parameter Specification: `meta.operationId`

| Attribute | Specification |
| :--- | :--- |
| **Identifier** | `meta.operationId` |
| **Category** | `response` |
| **Surface** | Response JSON Metadata Field |
| **Requirement Level** | **MANDATORY on Async 202 Accepted Operations** |
| **Criticality Tier** | **CRITICAL (P1)** |
| **Standard / Reference** | RFC 9110 §15.3.3 (202 Accepted) / OpenAPI 3.1 `operationId` / Async Job Pattern |
| **Schema Type** | `string` |

---

### 1. Architectural Purpose & Scope
Identifies an asynchronous background job triggered by a 202 Accepted response. Used to poll job status and query final execution outcome.

---

### 2. Open Standard Contract Schema (OpenAPI 3.1 & JSON Schema 2020-12)

```yaml
name: meta.operationId
in: body  # JSON body field — not a header parameter
required: true
schema:
  type: string
  pattern: "^[a-zA-Z0-9_-]{16,64}$"
```

---

### 3. Wire Grammar (ABNF — RFC 5234)

```abnf
operationId = 16*64( ALPHA / DIGIT / "-" / "_" )
```

---

### 4. Normative Lifecycle Protocol (IETF RFC 2119)

1. On asynchronous 202 Accepted responses, the server MUST inject `meta.operationId` tracking the job.
2. The server MUST pair this with `Location` header pointing to polling endpoint.

---

### 5. Deterministic Decision Table (DMN / Invariant Truth Table)

| Input Condition | Predicate Evaluation | Output Value | Secondary Effect |
| :--- | :--- | :--- | :--- |
| Async 202 Accepted response | `status_code == 202 && operation_id != null` | `operation_id` | Inject into meta |
| Synchronous response | `status_code != 202` | `null` | Omit from meta |

---

### 6. Declarative Logic Expression (CEL — Common Expression Language)

```cel
status_code == 202 && operation_id != null ? operation_id : null
```

---

### 7. Failure & Security Enforcement
- Mandatory on all 202 Accepted responses.
- Paired with Location header pointing to operation status URI.

---

### 8. Protocol Wire Example

```json
"operationId": "op-99281a7b-3c4d"
```
