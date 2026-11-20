---
agent_role: "Kubernetes Platform Architecture, Shell Automation, Tracing, Storage & Debugging Enforcer"
trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_K8S_MANIFEST_CREATION | ON_SCRIPT_CREATION | ON_DB_CONFIG | ON_DEBUG"
scope: "Production Kubernetes Manifests, Kustomize Overlays, ArgoCD GitOps, Shell Script Architecture, Distributed Tracing & Tempo Lifecycle, Database & Cache Topologies, Messaging Pipelines, Multi-Service Debugging & Flow Tracing"
mode: "Strict"
contract_version: "2.2"
enforcement: "Absolute & Non-Negotiable"
---

# Production Kubernetes, Shell Automation, Tracing, Storage & Debugging Specification Contract

> **Architectural Separation Principle:**  
> Infrastructure specifications operate across distinct engineering layers. They must **NEVER** be mixed or configured arbitrarily:
> - **Workloads & Services (`apps/`):** Stateless deployments, services, probes, and port bindings.
> - **Routing & Gateways (`ingress/`):** Ingress controllers, TLS termination, routing rules, and path rewrites.
> - **Environment Configurations (`config/`):** ConfigMaps, non-sensitive runtime config, feature flags, and endpoint configurations.
> - **Stateful Infrastructure (`storage/`):** StatefulSets, volumes, persistent claims, databases (`postgres/`), and distributed caches (`redis/`).
> - **Telemetry & Operations (`observability/`):** Metrics, logs, traces, dashboards, and collectors separated by sub-stack (`collector/`, `prometheus/`, `loki/`, `tempo/`, `grafana/`).
> - **Autoscaling & High Availability (`scaling-resilience/`):** HorizontalPodAutoscalers (HPA) and PodDisruptionBudgets (PDB).
> - **Identity & Secrets (`security-secrets/`):** ExternalSecrets, SecretStores, and environment secret templates.
> - **GitOps Delivery (`deploy/argocd/`):** Enterprise App-of-Apps pattern segregating Projects, Application Definitions, and Root App-of-Apps.
> - **Automation Scripts (`scripts/`):** Deduplicated, modular shell orchestrators with centralized logging, error trapping, dependency validation, and diagnostics.
> - **Distributed Tracing Engine (`tempo/` & `collector/`):** OpenTelemetry Collector pipelines, Tempo ingester, compactor, storage retention, and metrics generators.
> - **Database Topology & Secrets (`storage/postgres/` & `security-secrets/`):** StatefulSet volume claims, cluster-internal DNS, environment secret templates, credential rotation, and migration gates.
> - **Interactive Diagnostics & Correlation (`scripts/run/debug.sh`):** Instant container exec, direct query invocation (`psql`, `redis-cli`), dual-log aggregation, and trace correlation across stateful stores and workloads.

---

# PART I: STRICT NEGATIVE INVARIANTS (WHAT NOT TO DO AT ALL)

0. **STRICT LAYER INTEGRITY & TRACING/STORAGE TOPOLOGY INVARIANT**:
   - Strictly never dump heterogeneous Kubernetes manifests into a single root directory.
   - Every manifest must belong to its explicit architectural domain under `deploy/k8s/base/`.
   - Never run distributed tracing without aligning OTLP gRPC (`4317`) and OTLP HTTP (`4318`) ports across both Collector and Tempo Services.
   - Never run database workloads on ephemeral Deployments without persistent `volumeClaimTemplates`.
   - Never expose internal caching or database engines directly to external Ingress routes or NodePorts.

1. **NEVER Hardcode Database Passwords or Expose Stores Publicly:**
   - Database credentials must NEVER be placed plaintext in application source or committed to public repositories.
   - Databases must NEVER expose host ports (`NodePort`, `HostPort`, or `Ingress`); only internal `ClusterIP` (`postgres:5432`) is permitted.
   - Application Deployments must inject database credentials via `secretKeyRef` or ExternalSecrets, never hardcoded in non-sensitive ConfigMaps.
2. **NEVER Duplicate Common Logic Across Shell Scripts:**
   - Redefining ANSI color loggers (`log_info`, `log_error`), prerequisite binary checks, container diagnostics, or image cleanup across individual scripts is strictly prohibited.
   - All shared functions must reside in `scripts/lib/common.sh` and be sourced with `set -euo pipefail`.
3. **NEVER Hardcode Environment Overrides into Base Manifests:**
   - Base manifests (`deploy/k8s/base/`) must declare invariant structural topologies only.
   - Environment-specific replicas, resource limits, hostnames, ingress domains, and secrets must be injected strictly through overlays (`deploy/k8s/overlays/<env>/`).
4. **NEVER Use Floating or Undigested Image Tags in Production Overlays:**
   - `latest` tags are strictly banned in production overlays.
   - Production overlays must pin images via immutable release tags or cryptographic digest hashes (`@sha256:...`).
5. **NEVER Run Pods Without Resource Limits & Probes:**
   - Every container specification in `apps/` and `storage/` must declare explicit `resources.requests` and `resources.limits`.
   - Every long-running service must configure `livenessProbe` and `readinessProbe` with appropriate initial delays.
6. **NEVER Bind Admin / Probe Endpoints to Localhost Inside Containers:**
   - Probes bind addresses must listen on `0.0.0.0` (all interfaces), not `127.0.0.1`. In Kubernetes, kubelet probe traffic arrives across the pod virtual network interface (`eth0`); binding to `127.0.0.1` causes immediate `connection refused` probe failures and crash loops.
7. **NEVER Run Tempo Without Metrics Generator or Compactor Block Retention:**
   - Disabling `metrics_generator` in Tempo while using Grafana Traces Drilldown causes TraceQL rate aggregations to fail (`500 Internal Server Error: empty ring`).
   - Tempo must always configure explicit block retention and compaction windows.
8. **NEVER Perform Blind In-Cluster Debugging Without Structured Scripts:**
   - Guessing pod names or manually writing ad-hoc kubectl exec strings with hardcoded pod hashes is prohibited in standard operating procedures.
   - Always invoke `./scripts/run/debug.sh <service> <command>` to dynamically resolve pod selectors and environment namespaces.

---

# PART II: DIRECTORY STRUCTURE & CANONICAL LAYOUT

## 1. Directory Tree & Canonical Domain Responsibilities

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
scripts/
├── lib/
│   └── common.sh                              # Centralized logging, checks, diagnostics & cleanup
└── run/
    ├── debug.sh                               # Multi-service interactive query, shell & log debugger
    ├── k8s-local.sh                           # Single-entrypoint Kind, ArgoCD, deploy & port-forward
    ├── infra.sh                               # Infrastructure provisioning & compose orchestrator
    └── run.sh                                 # Native application runner & local lifecycle
```

---

# PART III: SHELL SCRIPT ARCHITECTURE CONTRACT (`scripts/`)

All scripts in the repository must adhere to the single-source standard:

1. **Mandatory Header & Options**:
   Every script must begin with:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "${SCRIPT_DIR}/../lib/common.sh"
   ```
2. **Standard Functions in `scripts/lib/common.sh`**:
   - `log_info "<msg>"`: Formatted cyan/blue operational logging.
   - `log_success "<msg>"`: Formatted green success verification.
   - `log_error "<msg>"`: Formatted red error stream logging to `stderr`.
   - `require_binaries "<bin1>" "<bin2>"`: Validates that all prerequisites (e.g. `docker`, `kubectl`, `kind`, `helm`) exist before starting execution; aborts on missing binary.
   - `diagnose_compose_failures "<compose_file>"`: Dumps recent tail logs of restarting or unhealthy containers automatically.
   - `prune_container_images "<img1>" "<img2>"`: Safely prunes stale or intermediate container images.

3. **Single Script Lifecycle (`scripts/run/k8s-local.sh`)**:
   Local Kubernetes development must be orchestratable via a single command supporting four distinct phases:
   - `up`: Provisions Kind cluster with host ports (30080, 30443), patches CoreDNS upstream resolvers, installs CRDs and ArgoCD, builds/loads the native Go binary and Docker image into Kind, applies the Kustomize overlay, runs database migrations, and initializes port forwards.
   - `down`: Tears down the Kind cluster and kills background forwarders cleanly.
   - `status`: Queries pod readiness, ArgoCD sync status, and active forwarders.
   - `port-forward`: Establishes background supervisors for Grafana (3000), Platform API (8080), OTel Collector (4318), PostgreSQL (5432), and Redis (6379).

---

# PART IV: DISTRIBUTED TRACING & TEMPO ARCHITECTURAL SPECIFICATION

## 1. Trace Ingestion & Processing Pipeline

Distributed tracing flows through a three-stage decoupled architecture:

```
+------------------------------------------+
| Native Applications / Microservices      |
| (OTel SDK: HTTP / gRPC spans)            |
+--------------------+---------------------+
                     | OTLP HTTP (4318) / gRPC (4317)
                     v
+--------------------+---------------------+
| OpenTelemetry Collector                  |
| - Receiver: OTLP (0.0.0.0:4317, :4318)   |
| - Processor: batch (timeout: 1s)         |
| - Exporters: otlp/tempo, prometheus, loki|
+--------------------+---------------------+
                     | OTLP gRPC (tempo:4317)
                     v
+--------------------+---------------------+
| Grafana Tempo (Distributed Tracing Engine)|
| - Distributor (receivers: 4317, 4318)    |
| - Ingester (memory WAL buffer)           |
| - Metrics Generator (TraceQL rate engine)|
| - Compactor (block compaction & retention)|
| - Query HTTP API (port 3200)             |
+--------------------+---------------------+
                     ^
                     | Query / TraceQL / Drilldown
+--------------------+---------------------+
| Grafana (exploretraces-app, drilldown)   |
+------------------------------------------+
```

## 2. Tempo Configuration Parameters & Retention Rules

All Tempo settings must be codified in `deploy/k8s/base/observability/tempo/configmap.yaml` with the following parameters:

| Component | Setting Key | Configured Value | Architectural Purpose |
|---|---|---|---|
| **Server** | `http_listen_port` | `3200` | Port for TraceQL queries and health probes from Grafana. |
| **Distributor** | `receivers.otlp.protocols.grpc.endpoint` | `0.0.0.0:4317` | gRPC receiver for OpenTelemetry Collector exports. |
| **Distributor** | `receivers.otlp.protocols.http.endpoint` | `0.0.0.0:4318` | HTTP receiver for direct REST OTLP span payloads. |
| **Ingester** | `trace_idle_period` | `10s` | Time to wait after last span received before cutting a trace in memory. |
| **Ingester** | `max_block_bytes` | `1,000,000` (1 MB) | In-memory block size threshold before flushing to the WAL. |
| **Ingester** | `max_block_duration` | `5m` | Maximum time an in-memory block remains uncompacted before flush. |
| **Storage WAL** | `storage.trace.wal.path` | `/tmp/tempo/wal` | Write-Ahead Log for crash resilience during active ingestion. |
| **Storage Traces**| `storage.trace.local.path` | `/tmp/tempo/traces` | Local persistent/ephemeral block storage directory. |
| **Compactor** | `compaction.compaction_window` | `1h` | Time window across which small trace blocks are compacted into large blocks. |
| **Compactor** | `compaction.max_block_bytes` | `100,000,000` (100 MB)| Target size for compacted trace blocks. |
| **Compactor** | `compaction.block_retention` | `1h` | **Trace Retention**: How long blocks remain searchable before automatic deletion. |
| **Compactor** | `compacted_block_retention` | `10m` | Retention grace period for superseded blocks after compaction. |
| **Metrics Generator**| `registry.collection_interval` | `15s` | Scrape frequency for calculating span metrics and service graphs. |
| **Metrics Generator**| `processor.local_blocks.flush_to_storage` | `true` | Allows recent blocks to be queried immediately without waiting for disk flush. |
| **Metrics Generator**| `overrides.defaults.metrics_generator.processors`| `[local-blocks, service-graphs, span-metrics]` | **Mandatory for Queryless Drilldown**: Enables TraceQL rate queries (`rate() by(...)`). |

## 3. Kubernetes Service Exposure Rule for Tempo

The Kubernetes `Service` for Tempo (`deploy/k8s/base/observability/tempo/service.yaml`) **MUST** expose all three active communication ports:
- `http` (Port `3200`): Consumed by Grafana for TraceQL exploration.
- `otlp-grpc` (Port `4317`): Consumed by OpenTelemetry Collector (`endpoint: tempo:4317`).
- `otlp-http` (Port `4318`): Consumed for HTTP OTLP payloads.

Omitting port 4317 breaks the OpenTelemetry pipeline and results in silent span drop or dialing timeouts.

---

# PART V: STORAGE, CACHING & MESSAGING PIPELINES

## 1. PostgreSQL Database Architecture (`deploy/k8s/base/storage/postgres/`)
- **StatefulSet & Volume Claim Templates**: Mounts persistent data directories to `/var/lib/postgresql/data`.
- **Dedicated `PGDATA` Subdirectory**: PostgreSQL requires `/var/lib/postgresql/data/pgdata` to avoid root filesystem collisions with `lost+found`.
- **ClusterIP Internal Service**: Accessible within the cluster namespace exclusively as `postgres.dev.svc:5432`.
- **Credentials & Secrets**: Stored in `postgres-credentials` Secret (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`) and injected into workloads via `secretKeyRef`.

## 2. Distributed Caching Pipeline (`deploy/k8s/base/storage/redis/`)
- **Workload Role**: High-speed ephemeral cache, rate-limiting store, and session token state for `platform-api`.
- **Deployment & Service**: Deployed under `storage/redis/` exposing ClusterIP port `6379` (`redis.dev.svc:6379`).
- **Health Probes**: Liveness and readiness via `redis-cli ping` returning `PONG`.

## 3. Declarative Messaging & Event Streaming Pipelines (`messaging/`)
- **Topics Specification (`messaging/topics/topics.yaml`)**:
  Declarative event bus manifests specifying partitions, replication factor, and retention:
  ```yaml
  topics:
    - name: internal-developer-platform.events
      partitions: 3
      replication_factor: 1
      retention_ms: 604800000  # 7-day retention
  ```
- **Outbox & Database-Message Correlation**:
  When domain entities transition state, events are committed transactionally to the database outbox table before propagation to avoid distributed state corruption.

---

# PART VI: MULTI-SERVICE DEBUGGING, FLOW EXECUTION & TRACING (`scripts/run/debug.sh`)

To troubleshoot tightly coupled microservices, database transactions, and messaging pipelines without tedious manual kubectl lookups, use the unified debugger:

### 1. Interactive Container Shell Access
Access container shells directly using symbolic names:
```bash
./scripts/run/debug.sh postgres shell   # Opens interactive bash inside postgres-0
./scripts/run/debug.sh redis shell      # Opens sh inside redis pod
./scripts/run/debug.sh app shell        # Opens sh inside platform-api
```

### 2. Direct Query Invocation (Zero Port-Forward Needed)
Run ad-hoc database or cache queries through the in-cluster network:
```bash
# Query PostgreSQL tables directly:
./scripts/run/debug.sh postgres query "SELECT tablename FROM pg_tables WHERE schemaname='public';"
./scripts/run/debug.sh postgres query "SELECT id, name, environment FROM service_descriptors LIMIT 5;"

# Query Redis cache:
./scripts/run/debug.sh redis query PING
./scripts/run/debug.sh redis query KEYS "*"
./scripts/run/debug.sh redis query GET "<cache_key>"
```

### 3. Multi-Component Log Correlation & Flow Tracing
When debugging issues where database queries, API requests, and trace emissions interact:
```bash
# Stream correlated logs simultaneously from Platform API, PostgreSQL, and OTel Collector:
./scripts/run/debug.sh all follow-flow
```
This enables real-time observation of API request arrival $\rightarrow$ SQL statement execution $\rightarrow$ OpenTelemetry span export in a single unified terminal view.

---

# PART VII: ROOT CAUSE ANALYSIS OF INITIAL FAILURES

| Failure Mode | Root Cause | Mandatory Architectural Fix |
|---|---|---|
| **Liveness Probe `Connection Refused`** | Application server admin/probe port was bound to `127.0.0.1` inside container. Kubelet health probe arrives on `eth0` pod IP, not loopback. | In application config (`src/infra/config/config.go`), always bind admin/probe endpoints to `0.0.0.0:%d`. |
| **Missing Config Files at Runtime** | Go binary expects `config/default.yaml` on disk, but container image has a minimal filesystem without baked configs. | Mount `internal-developer-platform-config` ConfigMap into `/app/config/` via `volumeMounts` in `deployment.yaml`. |
| **Local Port Conflicts (`address already in use: 5432 / 6379`)** | Existing Docker Compose containers or host services hold ports 5432 or 6379, blocking `kubectl port-forward`. | Diagnostic checks in `scripts/run/k8s-local.sh` verify port vacancy and stop conflicting background containers before binding. |
| **Tempo gRPC Timeout / Missing Spans** | Tempo Kubernetes `Service` only exposed port 3200; Collector tried to reach gRPC 4317 which had no endpoints. | Expose all required ports (`3200`, `4317`, `4318`) on `svc/tempo`. |
| **Tempo TraceQL Query Failure (`empty ring`)** | Traces Drilldown issued rate aggregations, but Tempo did not have `metrics_generator` or `local_blocks` processor configured. | Configure `metrics_generator` with `local_blocks` and overrides in `tempo.yaml`. |

---

# PART VIII: VERIFICATION & AUDIT CHECKLIST

Before committing or deploying, execute the following validation gates:

1. [ ] **Kustomize Build Gate**:
   ```bash
   kubectl kustomize deploy/k8s/overlays/dev > /dev/null
   ```
2. [ ] **Script Dependency & Dry-Run Gate**:
   ```bash
   bash -n scripts/lib/common.sh
   bash -n scripts/run/k8s-local.sh
   bash -n scripts/run/debug.sh
   ```
3. [ ] **Storage & Cache Readiness Gate**:
   ```bash
   ./scripts/run/debug.sh postgres query "SELECT 1;"
   ./scripts/run/debug.sh redis query PING
   ```
4. [ ] **Tracing Pipeline Port Verification**:
   Verify that `kubectl get svc tempo -n dev` exposes ports 3200, 4317, and 4318.
5. [ ] **TraceQL Rate Aggregation Gate**:
   Verify that Tempo responds with HTTP 200 OK to the queryless TraceQL rate query:
   ```bash
   curl -s -u admin:admin -H "Host: localhost:3000" \
     --data-urlencode 'q={nestedSetParent<0 && true && resource.service.name != nil} | rate() by(resource.service.name)' \
     "http://localhost:3000/api/datasources/proxy/uid/tempo/api/search" | jq '.metrics'
   ```
