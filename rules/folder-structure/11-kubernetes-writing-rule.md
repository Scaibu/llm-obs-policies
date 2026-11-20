---
agent_role: "Kubernetes Platform Architecture & Manifest Structure Enforcer"
trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_K8S_MANIFEST_CREATION"
scope: "Production Kubernetes Manifests, Kustomize Bases & Overlays, ArgoCD GitOps Hierarchy, Workload Layering"
mode: "Strict"
contract_version: "1.0"
enforcement: "Absolute & Non-Negotiable"
---

# Production Kubernetes & GitOps Architecture Specification Contract (`deploy/k8s/` & `deploy/argocd/`)

> **Architectural Separation Principle:**  
> Kubernetes manifests and GitOps configurations operate across distinct infrastructure domains. They must **NEVER** be mixed into a monolithic, unlayered directory:
> - **Workloads & Services (`apps/`):** Stateless deployments, services, probes, and port bindings.
> - **Routing & Gateways (`ingress/`):** Ingress controllers, TLS termination, routing rules, and path rewrites.
> - **Environment Configurations (`config/`):** ConfigMaps, non-sensitive runtime config, feature flags, and endpoint configurations.
> - **Stateful Infrastructure (`storage/`):** StatefulSets, volumes, persistent claims, databases, and caches (isolated per stateful technology).
> - **Telemetry & Operations (`observability/`):** Metrics, logs, traces, dashboards, and collectors separated by sub-stack (`collector/`, `prometheus/`, `loki/`, `tempo/`, `grafana/`).
> - **Autoscaling & High Availability (`scaling-resilience/`):** HorizontalPodAutoscalers (HPA) and PodDisruptionBudgets (PDB).
> - **Identity & Secrets (`security-secrets/`):** ExternalSecrets, SecretStores, and environment secret templates.
> - **GitOps Delivery (`deploy/argocd/`):** Enterprise App-of-Apps pattern segregating Projects, Application Definitions, and Root App-of-Apps.

---

# PART I: STRICT NEGATIVE INVARIANTS (WHAT NOT TO DO AT ALL)

0. **STRICT NON-ASSUMPTION & LAYER INTEGRITY INVARIANT**:
   - Strictly never dump heterogeneous Kubernetes manifests into a single root directory.
   - Every manifest must belong to its explicit architectural domain under `deploy/k8s/base/`.
   - Strictly never create ad-hoc resources without integrating them into the domain's local `kustomization.yaml` and the base aggregator `kustomization.yaml`.

1. **NEVER Hardcode Environment Overrides into Base Manifests:**
   - Base manifests (`deploy/k8s/base/`) must declare invariant structural topologies only.
   - Environment-specific replicas, resource limits, hostnames, ingress domains, and secrets must be injected strictly through overlays (`deploy/k8s/overlays/<env>/`).
2. **NEVER Use Floating or Undigested Image Tags in Production Overlays:**
   - `latest` tags are strictly banned in production overlays.
   - Production overlays must pin images via immutable release tags or cryptographic digest hashes (`@sha256:...`).
3. **NEVER Expose Internal Databases to Ingress or Host Ports:**
   - PostgreSQL, Redis, and internal state stores must only expose cluster-internal `ClusterIP` services.
   - HostPort, NodePort, or Ingress exposure for stateful stores is strictly forbidden.
4. **NEVER Place Raw Secrets in Git Repositories:**
   - Plaintext credentials, unencrypted private keys, and API tokens must never be committed to Git.
   - Secrets must reference ExternalSecret operators, Vault, KMS, or sealed secret specifications.
5. **NEVER Run Pods Without Resource Limits & Probes:**
   - Every container specification in `apps/` and `storage/` must declare explicit `resources.requests` and `resources.limits`.
   - Every long-running service must configure `livenessProbe` and `readinessProbe` with appropriate initial delays.
6. **NEVER Use Monolithic ArgoCD Applications for Heterogeneous Stacks:**
   - Bypassing the Root App-of-Apps hierarchy to deploy monolithic applications that mix core apps and third-party observability charts is strictly forbidden.
   - Use dedicated ArgoCD Projects with RBAC separation (`platform.project.yaml`).

---

# PART II: DIRECTORY STRUCTURE & CANONICAL LAYOUT

## 1. Directory Tree & Canonical Domain Responsibilities

All Kubernetes resources follow the canonical directory structure:

```
deploy/
├── argocd/
│   ├── projects/
│   │   └── platform.project.yaml              # ArgoCD AppProject with RBAC & cluster boundaries
│   ├── applications/
│   │   └── core/
│   │       └── app.dev.yaml                   # Core application definition targeting environment
│   └── root-app-of-apps/
│       └── root.dev.yaml                      # Root App-of-Apps bootstrapping all sub-applications
└── k8s/
    ├── base/
    │   ├── kustomization.yaml                 # Master base aggregator referencing sub-layers
    │   ├── apps/
    │   │   ├── deployment.yaml                # Application Deployment (stateless workload)
    │   │   ├── service.yaml                   # Service definition exposing application ports
    │   │   └── kustomization.yaml             # Apps local kustomization
    │   ├── ingress/
    │   │   ├── ingress.yaml                   # Ingress resource with TLS and routing rules
    │   │   └── kustomization.yaml             # Ingress local kustomization
    │   ├── config/
    │   │   ├── configmap.yaml                 # Non-sensitive runtime configs & feature flags
    │   │   └── kustomization.yaml             # Config local kustomization
    │   ├── storage/
    │   │   ├── kustomization.yaml             # Storage layer aggregator
    │   │   ├── postgres/
    │   │   │   ├── statefulset.yaml           # Database StatefulSet with volume claim templates
    │   │   │   ├── service.yaml               # ClusterIP headless/cluster service
    │   │   │   └── kustomization.yaml
    │   │   └── redis/
    │   │       ├── deployment.yaml            # Cache workload deployment
    │   │       ├── service.yaml               # Cache service
    │   │       └── kustomization.yaml
    │   ├── observability/
    │   │   ├── kustomization.yaml             # Observability suite aggregator
    │   │   ├── collector/                     # OpenTelemetry Collector (receivers, pipelines)
    │   │   ├── prometheus/                    # Prometheus metrics engine & scrape configs
    │   │   ├── loki/                          # Loki log aggregation engine
    │   │   ├── tempo/                         # Tempo distributed tracing engine & OTLP receivers
    │   │   └── grafana/                       # Grafana dashboards, plugins & datasources
    │   ├── scaling-resilience/
    │   │   ├── hpa.yaml                       # HorizontalPodAutoscaler specifications
    │   │   ├── pdb.yaml                       # PodDisruptionBudget specifications
    │   │   └── kustomization.yaml             # Scaling local kustomization
    │   └── security-secrets/
    │       ├── external-secrets.yaml          # ExternalSecret bindings
    │       ├── postgres-credentials.dev.yaml  # Environment secret template
    │       └── kustomization.yaml             # Secrets local kustomization
    └── overlays/
        ├── dev/
        │   └── kustomization.yaml             # Dev environment overlay with patches & config
        ├── staging/
        │   └── kustomization.yaml             # Staging environment overlay
        └── prod/
            └── kustomization.yaml             # Production environment overlay
```

---

# PART III: DOMAIN SPECIFICATION & INTEGRATION RULES

## 1. Workloads (`base/apps/`)
- Declares stateless application logic.
- Must bind admin/probe endpoints to `0.0.0.0` inside containers so kubelet probes can reach them across pod network boundaries.
- Must consume configuration files via ConfigMap volume mounts located at `/app/config/`.

## 2. Stateful Storage (`base/storage/`)
- Separated by service name (`storage/postgres/`, `storage/redis/`).
- Databases requiring data persistence must use `StatefulSet` with `volumeClaimTemplates`, not raw ephemeral `Deployment` volumes.
- Must declare explicit internal DNS services (`postgres:5432`, `redis:6379`).

## 3. Observability Suite (`base/observability/`)
- Must maintain independent sub-directories per observability pillar:
  * `collector/`: OpenTelemetry Collector routing traces, metrics, and logs.
  * `tempo/`: Must expose HTTP query (`3200`), OTLP gRPC (`4317`), and OTLP HTTP (`4318`) services to allow collector and query engines to function.
  * `prometheus/`: Configured for scrape targets and remote write receivers.
  * `loki/`: Structured logging with file-storage backends.
  * `grafana/`: Automated datasource provisioning (`datasources-configmap.yaml`) linking Prometheus, Tempo, and Loki.

## 4. GitOps ArgoCD Layout (`deploy/argocd/`)
- **Projects (`projects/platform.project.yaml`):** Restricts destination clusters, namespaces, and source repositories.
- **Applications (`applications/core/app.dev.yaml`):** References the Kustomize overlay (`deploy/k8s/overlays/dev`) with automated prune and self-heal sync policies.
- **Root App-of-Apps (`root-app-of-apps/root.dev.yaml`):** Watches the GitOps application manifest directory and orchestrates child application rollouts.

---

# PART IV: VERIFICATION & AUDIT CHECKLIST

Before committing or deploying Kubernetes infrastructure, execute the following audit gates:

1. [ ] **Kustomize Build Verification**:
   ```bash
   kubectl kustomize deploy/k8s/overlays/dev > /dev/null
   ```
2. [ ] **ArgoCD Root Reconciliation Verification**:
   Verify that all child apps in `deploy/argocd/applications/` are tracked by `deploy/argocd/root-app-of-apps/`.
3. [ ] **Zero Inline Secrets Check**:
   Confirm no plaintext passwords exist in `base/` or `overlays/`.
4. [ ] **Networking & Port Alignment Gate**:
   Confirm that all internal service ports (e.g., Tempo `4317`/`4318`, Postgres `5432`) match the ports configured in clients and collectors.
