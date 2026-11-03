The most common failure in feature flag architectures is performing synchronous network calls on the request hot path or misconfiguring default values. [Certain] When the flag provider experiences an outage, a synchronous client crashes the host service, and a poorly chosen default value can turn unreleased, experimental features on in production.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis
  ↺  registers cleanup
```

---

## 1. Feature Flag Specification Contract

```
defineFlag(key) → flagSpec                                                  ▶
├── kind() → release | experiment | operational kill switch | permission
├── owner() → owningEngineeringTeam
├── defaultValue() → safe fallback value when evaluation fails or rule is absent
├── expiresOn() → date (mandatory for release and experiment flags to prevent dead code)
└── contextFields() → [tenantId, userId, region, clientVersion]
```

[Likely] Kill switches must default to the *safe* operational state (e.g. disabling a degraded downstream dependency), whereas release flags must default to *off* (false). Blurring these semantics causes platform outages to enable unstable beta code.

---

## 2. In-Memory Snapshot Evaluation Engine

```
isEnabled(context, key) → boolean / getVariant(context, key) → variant      ⚙
├── buildEvaluationContext(context) → subject
│   └── tenantId, userId, ipAddress, userTier
├── readLocalSnapshot(key) → rules          (ZERO network I/O on hot path; local memory cache)
├── evaluate(rules, subject) → variant
│   ├── explicit targeting (tenant / user allowlists)
│   └── percentage rollout → stableHash(key + subject.id) mod 100 < rolloutPercentage
├── onAnyError → defaultValue               (safe degradation guarantee)
└── recordExposure(key, variant, subject)   (async buffered queue, sampled, deduplicated)
```

---

## 3. Flag Lifecycle & CI Hygiene Reaping

```
flagLifecycle(key)                                                          ⚙
├── create → rollout 1% → 10% → 50% → 100%
├── verify telemetry stability & business KPIs
├── cleanup: remove fallback conditional code paths in source code
├── delete flag definition in config repository
└── ciCheck(expiredFlagsStillInCode) → fail pull request build              ⚠
```

---

## 4. Strict Feature Flag Invariants

1. **Zero Network I/O on Hot Path**: Flag evaluations must always execute against locally cached in-memory rule sets updated via background streams or SSE. Synchronous HTTP calls to flag providers during request handling are strictly prohibited.
2. **Deterministic Percentage Hashing**: Percentage rollouts must compute `hash(flag_key + subject_id) % 100`. The evaluation must remain consistent across multiple pods and requests for the same user.
3. **Mandatory Expiration Enforcement**: Release flags are technical debt. Any release flag that lives past its `expiresOn` date must fail CI pipelines until the conditional code and flag are deleted.

