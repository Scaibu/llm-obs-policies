Promoting a secondary disaster recovery region without first fencing the compromised primary region guarantees split-brain corruption. [Certain] If two regions accept writes for the same tenant concurrently during a network partition, merging conflicting state across divergent databases requires weeks of painful manual reconciliation.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Multi-Region Strategy Definition

```
defineRegionStrategy(service) → drStrategy                                  ▶
├── recoveryTimeObjective() → acceptable downtime (e.g. RTO < 15m)
├── recoveryPointObjective() → acceptable data loss (e.g. RPO < 5s)
├── multiRegionMode()
│   ├── ActivePassive: Standby DR region, automated or human failover
│   ├── ActiveActivePartitioned: Each tenant homed in exactly one primary region
│   └── ActiveActiveGlobal: Multi-master writes (requires CRDTs or strict epoch fencing)
└── dataResidency() → jurisdictional regions tenant data may legally occupy
```

---

## 2. Automated Failover & Split-Brain Fencing Protocol

```
executeFailover(compromisedRegion, targetRegion) → status                   ⚙
├── detectFailure(unhealthyRegion, sustainedDuration > 3m) → trigger
├── STEP 1 (FENCE): Revoke write permissions in compromised region           ⚠ MANDATORY
│   └── Revoke database credentials or update DNS/BGP to isolate old primary
│   └── If fencing fails, HALT failover (prevent split-brain writes)
├── STEP 2 (PROMOTE): Promote read-replica in targetRegion to primary
├── STEP 3 (SWITCH): Update global Anycast DNS / CDN to route tenants to targetRegion
├── STEP 4 (RECONCILE): Replay un-replicated Kafka outbox streams via idempotent keys
└── STEP 5 (RECORD): Compute actual RTO and RPO metrics for compliance audit
```

---

## 3. Mandatory Disaster Recovery Testing

Disaster recovery cannot be trusted if it is only tested on paper:

```
disasterRecoveryDrill(schedule) → auditReport                               ⚙
├── Scheduled production Chaos GameDay (quarterly schedule)
├── Terminate primary database or simulate cloud region network blackhole
├── Verify automated fencing and failover within target RTO / RPO
└── Failure to meet RTO/RPO → blocks new feature deployments until resolved
```

---

## 4. Strict Disaster Recovery Invariants

1. **Fence Before Promotion**: A standby database in Region B must NEVER be promoted to writable primary until Region A is definitively fenced and prevented from accepting further mutations.
2. **Deterministic Idempotent Recovery**: All replay operations post-failover must utilize deterministic idempotency keys to ensure late-arriving messages do not double-process.
3. **Partitioned Active-Active Primary Homed**: When operating active-active, a given tenant must be homed in exactly one primary region for write operations, with cross-region replication for read fallbacks.

