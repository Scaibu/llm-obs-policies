Conflating application diagnostic logs with compliance audit logs is a critical regulatory violation. [Certain] Application logs are sampled, un-indexed, and routinely dropped during high-load backpressure; compliance audit logs must be immutable, non-repudiable, append-only, and strictly zero-loss.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Compliance Audit Record Schema

```
audit(context, action, target, outcome)                                     ⚙
├── who → principal {userId, callingService, tenantId, impersonatorId}
├── what → actionName + targetResourceType + targetResourceId
├── when → UTC ISO 8601 server timestamp (microsecond precision)
├── where → serviceName, podHostname, traceId, requestId, sourceIpAddress
├── outcome → ALLOWED | DENIED | ERRORED
├── changes → before/after state diff for sensitive attributes (hashed / masked)
├── write → append-only immutable audit store (isolated WORM storage)
└── on write failure
    ├── securityCriticalAction == true → fail the business transaction      ⚠
    └── nonCriticalAction == true → buffer locally in WAL, retry, alert
```

---

## 2. Ingress & Delivery Guarantee

```
Audit Delivery Pipeline                                                     ⚙
├── Synchronous In-Transaction Writes (Critical Financial / Auth Mutations):
│   └── INSERT INTO audit_events in the SAME PostgreSQL transaction as the state mutation
└── Asynchronous Stream Delivery (Read Auditing / Access Log):
    ├── Enqueue to durable, bounded local memory buffer
    ├── Flush batch to Kafka / Kinesis audit topic
    └── Buffer full → halt execution if compliance-enforced; never drop silently
```

---

## 3. Strict Audit Logging Invariants

1. **Fail-Closed on High-Security Mutations**: If the audit pipeline is unreachable during high-privilege actions (e.g. role escalation, credential revocation, data export), the primary action must abort and return HTTP 500.
2. **Immutable Append-Only Storage**: Audit logs must be stored in Write-Once-Read-Many (WORM) storage with cryptographic hashing (e.g. SHA-256 hash chains). Updates (`UPDATE`) and deletions (`DELETE`) on audit tables are forbidden.
3. **PII Masking at Origin**: Passwords, API tokens, and payment card numbers must never enter audit diff records under any circumstances. Masking must occur in memory before serialization.

