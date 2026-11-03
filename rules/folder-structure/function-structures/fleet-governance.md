At a scale of 100+ microservices, software architecture degrades rapidly without automated, continuous fleet governance. [Certain] Manually managed dependency spreadsheets and voluntary architecture guidelines always drift; governance must be continuously computed from live OpenTelemetry distributed traces and automated CI scorecard gates.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Centralized Service Catalog & Telemetry Ingestion

```
serviceCatalog(serviceName) → catalogEntry                                  ⚙
├── metadata: owningTeam, onCallPagerDutyRotation, tier (Tier 1 to 3)
├── dependencies: upstreamCallers + downstreamServices (derived from live OTel traces)
├── publishedContracts: versioned OpenAPI schemas, produced Kafka events, CDC contracts
├── chassisVersion: current chassis version vs. latest platform release
└── scorecard:
    ├── Availability SLO defined & monitored in Prometheus?
    ├── Runbooks attached to 100% of PagerDuty alerts?
    ├── Chassis within N-2 supported versions?
    ├── Zero expired feature flags in codebase?
    ├── Disaster recovery drill passed within 90 days?
    ├── Double-click idempotency integration tests present?
    └── Automated cross-tenant isolation tests present in CI?
```

---

## 2. Automated Scorecard Policy Enforcement

```
enforceScorecard(serviceName, scorecard) → action                           ⚙
├── Scorecard Grade: PASS (All Tier criteria satisfied) → normal production operations
├── Scorecard Grade: WARNING (Chassis out of date / flag expired) →
│   └── Automated platform upgrade PR opened; visible on engineering leadership dashboard
└── Scorecard Grade: CRITICAL FAIL (No runbook / Tier 1 service failing SLO) →
    ├── Blocks new downstream services from taking production dependencies on this service ⚠
    └── Blocks non-security feature pull requests until operational health is restored ⚠
```

---

## 3. Strict Fleet Governance Invariants

1. **Live-Trace Dependency Graphs**: Architectural dependency graphs must be continuously derived from OpenTelemetry distributed trace spans. Self-reported or manually documented dependency lists are strictly prohibited as authoritative sources.
2. **Automated Platform Upgrades**: Microservices must maintain platform chassis dependencies within $N-2$ minor versions of the latest platform release. Automated bots must submit weekly upgrade PRs with green CI status.
3. **Scorecard Blockers for Tier 1 Services**: Any Tier 1 service (financial transactions, authentication, order intake) failing its governance scorecard must be blocked from deploying new business features until foundational reliability criteria are satisfied.

