The fastest way to destroy on-call engineering effectiveness is paging engineers on static infrastructure causes like "CPU usage at 85%" or "disk IOPS high." [Certain] Infrastructure fluctuations are noise; on-call engineers must only be paged on customer-impacting symptoms derived from Service Level Objective (SLO) error budget burn rates.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Service Level Objective (SLO) Contract

```
defineSLO(service, userJourney) → sloSpec                                   ▶
├── serviceLevelIndicator() → goodEvents / totalValidEvents
│   └── e.g. (HTTP requests with status < 500 AND duration < 300ms) / (total non-4xx requests)
├── targetObjective() → 99.9% availability over a rolling 28-day window
├── errorBudget() → 1 - targetObjective (0.1% allowed failures = 40.3 minutes / month)
└── tier() → Tier 1 (Critical Financial Path) | Tier 2 (Core Business) | Tier 3 (Internal)
```

---

## 2. Multi-Window Multi-Burn-Rate Alerting

Alerting must trigger based on how quickly the service is burning through its monthly error budget:

```
alertingEngine(sloSpec) → incidentPage                                      ⚙
├── 1-Hour Window (14.4x Burn Rate → 2% budget consumed in 1 hour):
│   └── IMMEDIATE CRITICAL PAGERDUTY WAKEUP (Active Severity 1 Outage)      ⚠
├── 6-Hour Window (6x Burn Rate → 5% budget consumed in 6 hours):
│   └── HIGH PRIORITY PAGERDUTY NOTIFICATION (Working-hours on-call page)   ⚠
├── 3-Day Window (1x Burn Rate → 10% budget consumed in 3 days):
│   └── JIRA TICKET / SLACK DIGEST (Investigate during standard business hours)
└── Infrastructure Anomalies (CPU, memory, goroutines):
    └── DASHBOARD GRAPHS ONLY; NEVER TRIGGER PAGER NOTIFICATIONS
```

---

## 3. Mandatory Incident Runbook Linkage

Every alert fired by Prometheus / Alertmanager must include four automated diagnostic links in the payload:
1. Direct URL to the primary service dashboard (Grafana).
2. Direct URL to the active OpenTelemetry trace exemplar triggering the failure.
3. Direct URL to the emergency rollback runbook.
4. Git diff and deployment log of the most recent release.

---

## 4. Strict SLO & Alerting Invariants

1. **Symptom-Over-Cause Paging**: Never trigger on-call pages for server metrics (CPU, RAM, thread pool size) alone. Pages must trigger exclusively when user-facing SLO error budgets are being rapidly consumed.
2. **Exclusion of Bad Caller Requests**: Client errors (HTTP 400 Bad Request, 401 Unauthorized, 404 Not Found) must be excluded from server availability SLO denominators to prevent external script kiddies from burning the service's error budget.
3. **Mandatory Runbook URL**: Any alert configured in Prometheus/Alertmanager without a valid, maintained `runbook_url` annotation must fail the CI linter.

