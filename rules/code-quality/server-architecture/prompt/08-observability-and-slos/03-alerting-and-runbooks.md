---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_ALERT_RULE_CREATION"
agent_role: "Principal SRE & Incident Response Officer"
target_scope: "Multi-Window Multi-Burn-Rate Alerts, Runbook Links & Triage Procedures"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Alerting and Runbooks Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Multi-Window Multi-Burn-Rate SLO Alerts
Alerting on user-facing symptoms MUST follow the Google SRE Workbook multi-window multi-burn-rate methodology:
- **Critical Page (Fast Burn)**: $14.4\times$ burn rate consuming 2% of 30-day budget within 1 hour (checked over 1h and 5m windows).
- **Urgent Page (Medium Burn)**: $6\times$ burn rate consuming 5% of 30-day budget within 6 hours (checked over 6h and 30m windows).
- **Ticket / Work-Hours (Slow Burn)**: $1\times$ burn rate consuming 10% of budget over 3 days (checked over 3d and 6h windows).

Guardrail 2: Direct-Cause Hardware & Boundary Alerts
Complementary direct-cause alerts MUST be configured strictly for clear actionable infrastructure failures:
- Circuit breaker stuck `OPEN` on a critical upstream dependency.
- Ingress rejection spike by reason exceeding threshold.
- Pod OOM kills and restart loops.
- TLS certificate expiration within $< 14$ days.

Guardrail 3: Mandatory Runbook Linkage Invariant
Every alert rule MUST include an explicit, verified `runbook_url`. Alerts without actionable triage steps (what it means, most likely cause, diagnostic query, immediate mitigation killswitch) are strictly forbidden from paging on-call engineers.

Guardrail 4: Zero Inline Comments Doctrine
Never write mid-function inline comments inside alert generator manifests. Document the burn-rate formulas in the file header docblock.

---

## 2. Alerting & Runbook Contract

```yaml
alerting_contract:
  slo_burn_rates:
    fast_burn: { factor: 14.4, long_window: "1h", short_window: "5m", severity: "PAGE" }
    medium_burn: { factor: 6.0, long_window: "6h", short_window: "30m", severity: "PAGE" }
    slow_burn: { factor: 1.0, long_window: "3d", short_window: "6h", severity: "TICKET" }
  direct_cause_thresholds:
    tls_cert_expiry_days: 14
    breaker_open_duration_minutes: 2
    oom_restart_count: 1
  runbook_base_url: "https://runbooks.llmobs.internal/services"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Flapping Alert Fatigue Fix**: Use multi-window verification. Both the short window (5m) and long window (1h) must simultaneously show an elevated burn rate before firing the page, preventing false alarms from brief 30-second network blips.
2. **Missing Actionable Runbook Fix**: In Prometheus alert definitions, declare:
   `runbook_url: "https://runbooks.llmobs.internal/services/ewma-worker/alerts/{{ $labels.alertname }}"`.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Trigger Pages on Single Instantaneous Spikes
Always configure `for: 5m` or multi-window burn rate queries in Alertmanager rules.

### Instruction 2: Attach Diagnostic PromQL Queries
Embed immediate triage queries directly into alert annotations for fast incident triage.
