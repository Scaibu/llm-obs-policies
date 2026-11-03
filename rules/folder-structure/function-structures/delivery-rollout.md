The primary flaw in modern deployment pipelines is gating production rollouts solely on whether "all Kubernetes pods started without crashing." [Certain] A deployment where all pods are healthy but 50% of user requests fail due to missing database columns or bad configuration will pass standard readiness probes and crash production unless explicitly gated on automated canary analysis and real-time SLO burn rates.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Continuous Delivery & Rollout Lifecycle

```
deliver(change) → released | rolledBack                                     ⚙
├── CI Pipeline Gate
│   ├── buildArtifacts()
│   ├── runUnitAndRepoTests()                                   ⚠ block on failure
│   ├── lintOpenApiContracts() + checkBreakingChanges()          ⚠ block on failure
│   ├── securityVulnerabilityScan(dependencies, image)          ⚠ block on failure
│   └── checkExpiredFeatureFlags()                              ⚠ block on failure
├── Progressive Deployment Gate
│   ├── deployCanary(1% of live traffic)
│   │   ├── compareTelemetry(canaryInstances, baselineInstances)
│   │   │   ├── error rate spike > 0.1% → AUTOMATIC ROLLBACK    ⚠
│   │   │   ├── p99 latency regression > 25% → AUTOMATIC ROLLBACK ⚠
│   │   │   └── error budget burn detected → AUTOMATIC ROLLBACK ⚠
│   │   └── promoteCanary(10% → 50% → 100%)
│   └── each stage gated on 15-minute soak and SLO health verification
└── Feature Release
    └── decoupled from deployment via dynamic feature flags
```

---

## 2. Decoupling Deployment from Release

```
Deployment vs. Release Principle                                            ▶
├── Deployment (Infrastructure Event):
│   └── Rolling out new binary and container images to Kubernetes pods.
│       Dark deployment: new code paths are disabled behind feature flags.
└── Release (Business Event):
    └── Dynamically enabling feature flags for targeted cohorts (1% → 10% → 100%).
        Instant rollback via flag toggle without waiting for pod re-deployment.
```

---

## 3. Strict Delivery Invariants

1. **Automated Canary Rollback**: The deployment orchestrator (Argo Rollouts, Flagger) must have automated authority to terminate canaries and rollback immediately upon detecting anomalous 5xx error spikes or latency regressions.
2. **Zero In-Process DDL Migrations**: Deploying application containers must never execute database migrations during rolling updates. Migrations must run as isolated pre-deployment jobs using the zero-downtime expand-contract protocol.
3. **Immutable Tagged Artifacts**: Container images and Helm charts must be tagged with unique git commit SHAs. Deploying mutable tags (e.g. `latest`, `staging`) is strictly prohibited.

