[Certain] A complete design can't be finished without your peak events/sec, average event size, retention and region count. Every load-dependent value below (node counts, DB tier, Kafka capacity, BigQuery slots) is therefore a formula with a placeholder, not a sizing. What I can complete without those numbers is the structure, the request path I left as ✘ last time, and the scaling mechanics.

[Likely] None of this has been through `terraform validate` or `kubectl apply --dry-run`. Treat the newest resources (Managed Kafka, Redis Cluster, Gateway policies) as needing a version check. Nothing here touches your repo.

---

## 1. Master diagram: build plane, run plane, stores, Google services

```
╔═══════════════════════════════════ ORGANIZATION ═══════════════════════════════════════╗
║ org policies · org firewall policy · aggregated log sink · SCC · billing export · VPC-SC ║
╚═════════════════════════════════════════════════════════════════════════════════════════╝

BUILD PLANE
 GitHub ─OIDC─► WIF pool (prj-b-cicd) ─► sa-tf-{org,net,proj,app} ─► Terraform 0→5
 GitHub ─build─► Artifact Registry ─► sign (KMS asym key) ─► Cloud Deploy ─► GKE
                                                       BinAuthz admits only attested images

RUN PLANE
 Client
   │ 1 Cloud DNS (public) ─► anycast IP
   ▼
 ┌──────────────────────────── EDGE (global) ─────────────────────────────┐
 │ Global external Application LB (Gateway-managed) · Certificate Manager │
 │ Cloud Armor (WAF, rate limit) · Cloud CDN                              │
 └──────────────────────────────┬─────────────────────────────────────────┘
                                │ 2 from GFE 130.211.0.0/22, 35.191.0.0/16
 ┌──────────────────────────────▼──── prj-p-net-host · Shared VPC vpc-prod (global) ───────────────┐
 │ FW policy fwp-prod (secure tags)   Org FW policy (IAP allow, mgmt-port deny)                    │
 │                                                                                                 │
 │ snet-gke-prod-a  10.30.0.0/22  pods 100.80.0.0/14  svc 100.88.0.0/20                            │
 │ snet-data-a      10.30.16.0/22 ◄── PSC endpoints: Cloud SQL, Kafka attachment                   │
 │ snet-psc-a       10.30.34.0/24 ◄── Redis Cluster PSC (service connection policy)                │
 │ snet-proxy-a     10.30.32.0/23     (only for internal ALB)                                      │
 │ PSC Google APIs  10.30.255.250 ◄── DNS zones: googleapis.com, gcr.io, pkg.dev                   │
 │ Cloud Router + Cloud NAT (static IPs, DPA)     HA VPN + BGP ◄──► on-prem / NCC hub              │
 └───────┬─────────────────────────────┬───────────────────────────────┬───────────────────────────┘
         │ service project              │ service project                │
 ┌───────▼───────────────────┐  ┌──────▼─────────────────────────┐  ┌───▼────────────────────────┐
 │ prj-p-app-svc             │  │ prj-p-data (VPC-SC perimeter)  │  │ prj-c-* (shared services)  │
 │ GKE regional, private     │  │ BigQuery raw/curated/marts     │  │ logging (locked bucket)    │
 │  pools: system · general  │  │ GCS buckets (CMEK)             │  │ kms · secrets · dns-hub    │
 │  · highmem · spot-batch   │  │ Pub/Sub topics + DLQs          │  │ scc · billing-export       │
 │ HPA→CA→nodes              │  │ Dataflow (✘)                   │  └────────────────────────────┘
 │ Cloud SQL PG (HA)+replica │  │ Spanner (optional)             │
 │ Redis Cluster · Kafka     │  └────────────────────────────────┘
 └───────────────────────────┘
 Egress: pods ─► NAT ─► internet · pods ─► PSC ─► Google APIs (never NAT)
 Telemetry: logs ─► org sink ─► prj-c-logging · metrics ─► Managed Prometheus ─► alerts
```

---

## 2. Scaling infra: the chain and its weakest links

[Certain] Compute is rarely what breaks first. The failure order I'd expect is: **DB connections → pod IP space → quota → NAT ports → Kafka partitions → compute**.

```
Traffic ↑
  │
  ├─► LB / Armor / CDN ............ automatic, no config; watch Armor rate rules
  ├─► HPA (pods) .................. 15s loop, CPU/RPS/custom metric   ◄ limited by: node capacity
  │      │ pods Pending
  │      ▼
  ├─► Cluster Autoscaler (nodes) .. per pool, BALANCED across zones   ◄ limited by: CPU quota, pod /24 blocks
  │      │ nodes join
  │      ▼
  ├─► Pod ranges .................. 1 /24 per node (110 max pods)     ◄ /14 pods = 1,024 nodes, fixed at creation
  │      │
  │      ▼
  ├─► DB connections .............. pods × pool_size ≤ max_connections ◄ the usual first failure
  ├─► Cloud NAT ports ............. DPA 256→4096 per VM, more IPs
  ├─► Kafka ....................... partitions cap consumer parallelism; vCPU is the throughput lever
  └─► BigQuery .................... autoscale slots up to max_slots
```

| Layer | Scale mechanism | Trigger | Hard limit to know | Downtime on scale-up |
|---|---|---|---|---|
| Global ALB | Managed | n/a | Backend service / URL map quotas | None |
| Pods | HPA v2 (`k8s/apps/api/hpa.yaml`) | CPU 65%, or RPS / Kafka lag via custom metric | Node + IP capacity | None |
| Nodes | Node pool autoscaler, `OPTIMIZE_UTILIZATION` profile | Pending pods | Regional CPU quota, pod range | None |
| Cloud SQL | Vertical: tier change. Reads: replicas. Disk: autoresize | Manual or scripted | One writer; tier change restarts the instance [Likely: brief outage, plan a window] | Yes for tier |
| Spanner | Autoscaler, processing units | CPU 65% high-priority | Hotspotting on monotonic keys | None |
| Redis Cluster | Add shards online | Memory / CPU | Cluster-aware clients only | None [Likely] |
| Managed Kafka | Raise vCPU/memory, rebalance | CPU, bytes in/out | Partitions can only increase, never decrease | None [Likely] |
| Pub/Sub | Managed | n/a | Per-region quota; ordering keys cap per-key throughput | None |
| BigQuery | Reservation autoscale | Slot demand | `max_slots` ceiling you set | None |
| Cloud NAT | DPA + more static IPs | `nat_allocation_failed` | 64,512 ports per NAT IP | None |

**Capacity formulas (fill in your numbers):**
```
pods_peak        = peak_rps / rps_per_pod_at_65%_cpu × 1.3 headroom
nodes_peak       = ceil(pods_peak / pods_per_node_by_resources)   # usually CPU/mem bound, not the 110 cap
pod_ip_blocks    = nodes_peak × 1.5 (surge + upgrade)   → needs ≥ that many /24s in the pods range
db_connections   = pods_peak × pool_size_per_pod        → must be < max_connections − 20 reserved
                   if not: PgBouncer / Managed Connection Pooling, or lower pool_size
kafka_partitions = max(peak_MBps / ~10 MBps_per_partition, max_consumer_instances)
nat_ports_needed = concurrent_egress_conns_per_node ≤ max_ports_per_vm (4096)
```
Example with placeholders: 400 pods × pool 10 = 4,000 connections, far above a typical Postgres limit, so you'd need a pooler or `pool_size=2`.

### `modules/gke/node_pools.tf`

```hcl
variable "node_pools" {
  type = map(object({
    machine_type = string
    min_total    = number          # across all zones
    max_total    = number
    spot         = optional(bool, false)
    disk_gb      = optional(number, 100)
    labels       = optional(map(string), {})
    taints       = optional(list(object({ key = string, value = string, effect = string })), [])
  }))
}

variable "node_resource_tags" {
  type        = map(string)   # { "tagKeys/<id>" = "tagValues/<id>" } for tier=gke-node
  description = "Secure tag binding so firewall.tf rules actually match the nodes"
}

resource "google_service_account" "node" {
  project      = var.project_id
  account_id   = "sa-gke-node-${var.env}"
  display_name = "GKE nodes ${var.env}"
}

resource "google_project_iam_member" "node" {
  for_each = toset([
    "roles/logging.logWriter", "roles/monitoring.metricWriter",
    "roles/monitoring.viewer", "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node.email}"
}

resource "google_container_node_pool" "pool" {
  for_each = var.node_pools

  project  = var.project_id
  name     = each.key
  cluster  = google_container_cluster.c.name
  location = var.region

  autoscaling {
    total_min_node_count = each.value.min_total
    total_max_node_count = each.value.max_total
    location_policy      = each.value.spot ? "ANY" : "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 2
    max_unavailable = 0
  }

  node_config {
    machine_type    = each.value.machine_type
    spot            = each.value.spot
    disk_size_gb    = each.value.disk_gb
    disk_type       = "pd-balanced"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.node.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = merge({ pool = each.key }, each.value.labels)

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config { mode = "GKE_METADATA" }
    resource_manager_tags = var.node_resource_tags

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect   # NO_SCHEDULE | PREFER_NO_SCHEDULE | NO_EXECUTE
      }
    }
  }

  lifecycle { ignore_changes = [node_count] }
}
```

`terraform.tfvars` example (placeholders):
```hcl
node_pools = {
  system   = { machine_type = "e2-standard-4",  min_total = 3,  max_total = 6,  taints = [{ key = "pool", value = "system", effect = "NO_SCHEDULE" }] }
  general  = { machine_type = "n2-standard-8",  min_total = 3,  max_total = 60 }
  highmem  = { machine_type = "n2-highmem-16",  min_total = 0,  max_total = 12, taints = [{ key = "pool", value = "highmem", effect = "NO_SCHEDULE" }] }
  batch    = { machine_type = "n2-standard-16", min_total = 0,  max_total = 40, spot = true, taints = [{ key = "pool", value = "batch", effect = "NO_SCHEDULE" }] }
}
```

Additions to `gke/main.tf` (cluster-level scaling and upgrade control):
```hcl
  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"   # [Likely] verify it's accepted without enabled=true on your provider version
  }

  maintenance_policy {
    recurring_window {
      start_time = "2026-01-04T21:00:00Z"
      end_time   = "2026-01-05T03:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }
```
[Certain] The `lifecycle { ignore_changes = [node_count] }` matters. Without it, Terraform fights the autoscaler on every apply.

### `k8s/` manifests: the request path

`k8s/base/namespace-and-policy.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata: { name: app, labels: { pod-security.kubernetes.io/enforce: restricted } }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: app }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-lb-and-dns, namespace: app }
spec:
  podSelector: { matchLabels: { app: api } }
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    - ipBlock: { cidr: 130.211.0.0/22 }
    - ipBlock: { cidr: 35.191.0.0/16 }
    ports: [{ port: 8080 }]
  egress:
  - to: [{ namespaceSelector: {} , podSelector: { matchLabels: { k8s-app: kube-dns } } }]
    ports: [{ port: 53, protocol: UDP }, { port: 53, protocol: TCP }]
  - to: [{ ipBlock: { cidr: 10.30.0.0/16 } }]     # PSC endpoints: SQL, Redis, Kafka, Google APIs
  - to: [{ ipBlock: { cidr: 0.0.0.0/0 } }]        # tighten to FQDN rules once egress is observed
    ports: [{ port: 443 }]
```

`k8s/apps/api/deployment.yaml`
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api
  namespace: app
  annotations: { iam.gke.io/gcp-service-account: sa-api@<PROJECT>.iam.gserviceaccount.com }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: api, namespace: app }
spec:
  replicas: 3                                  # HPA owns this after first apply
  strategy: { rollingUpdate: { maxSurge: 25%, maxUnavailable: 0 } }
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      serviceAccountName: api
      terminationGracePeriodSeconds: 60
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector: { matchLabels: { app: api } }
      containers:
      - name: api
        image: <REGION>-docker.pkg.dev/<PROJECT>/docker-prod/api:<DIGEST>   # pin by digest for BinAuthz
        ports: [{ containerPort: 8080 }]
        resources:
          requests: { cpu: "500m", memory: 512Mi }
          limits:   { memory: 512Mi }          # no CPU limit: avoids throttling, HPA still works off requests
        readinessProbe: { httpGet: { path: /healthz, port: 8080 }, periodSeconds: 5 }
        livenessProbe:  { httpGet: { path: /livez,   port: 8080 }, periodSeconds: 10, failureThreshold: 3 }
        lifecycle: { preStop: { exec: { command: ["sleep", "20"] } } }   # lets NEG drain before SIGTERM
        securityContext: { runAsNonRoot: true, readOnlyRootFilesystem: true, allowPrivilegeEscalation: false }
---
apiVersion: v1
kind: Service
metadata: { name: api, namespace: app }
spec:
  selector: { app: api }
  ports: [{ port: 80, targetPort: 8080 }]
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: api, namespace: app }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: api }
  minReplicas: 3
  maxReplicas: 60
  metrics:
  - type: Resource
    resource: { name: cpu, target: { type: Utilization, averageUtilization: 65 } }
  behavior:
    scaleUp:   { stabilizationWindowSeconds: 0,   policies: [{ type: Percent, value: 100, periodSeconds: 30 }] }
    scaleDown: { stabilizationWindowSeconds: 300, policies: [{ type: Percent, value: 20,  periodSeconds: 60 }] }
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: api, namespace: app }
spec:
  minAvailable: 2
  selector: { matchLabels: { app: api } }
```

`k8s/gateway/gateway.yaml`
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: external
  namespace: infra-gw
  annotations: { networking.gke.io/certmap: cm-prod }     # created in lb_global/certs.tf
spec:
  gatewayClassName: gke-l7-global-external-managed
  addresses: [{ type: NamedAddress, value: lb-ip-prod }]   # created in lb_global/main.tf
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    allowedRoutes: { namespaces: { from: All } }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: api, namespace: app }
spec:
  parentRefs: [{ name: external, namespace: infra-gw }]
  hostnames: ["api.example.com"]
  rules:
  - matches: [{ path: { type: PathPrefix, value: / } }]
    backendRefs: [{ name: api, port: 80 }]
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata: { name: api, namespace: app }
spec:
  default:
    config: { type: HTTP, httpHealthCheck: { requestPath: /healthz, port: 8080 } }
  targetRef: { group: "", kind: Service, name: api }
---
apiVersion: networking.gke.io/v1
kind: GCPBackendPolicy
metadata: { name: api, namespace: app }
spec:
  default:
    securityPolicy: armor-prod                              # created in lb_global/armor.tf
    timeoutSec: 30
    connectionDraining: { drainingTimeoutSec: 60 }
  targetRef: { group: "", kind: Service, name: api }
```

[Certain] This corrects a contradiction in my first answer. If you use the Gateway API, **the controller creates the URL map, backend services and NEGs**. Terraform should only own what the Gateway references: the static IP, the certificate map and the Armor policy. If Terraform also built a `backends.tf` you'd have two owners fighting over one load balancer. That is why `lb_global` below has no backend services.

---

## 3. Edge: `5-app-infra/modules/lb_global/`

```hcl
# main.tf
resource "google_compute_global_address" "lb" {
  project      = var.project_id
  name         = "lb-ip-${var.env}"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# armor.tf
resource "google_compute_security_policy" "armor" {
  project = var.project_id
  name    = "armor-${var.env}"
  type    = "CLOUD_ARMOR"

  adaptive_protection_config {
    layer_7_ddos_defense_config { enable = true }
  }

  rule {
    priority    = 1000
    action      = "throttle"
    description = "per-IP rate limit"
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_per_min
        interval_sec = 60
      }
    }
  }

  dynamic "rule" {
    for_each = { sqli = "sqli-v33-stable", xss = "xss-v33-stable", rce = "rce-v33-stable", lfi = "lfi-v33-stable" }
    content {
      priority    = 2000 + index(keys({ sqli = 1, xss = 1, rce = 1, lfi = 1 }), rule.key)
      action      = "deny(403)"
      preview     = var.armor_preview          # true first, flip after reading logs
      description = "OWASP ${rule.key}"
      match {
        expr { expression = "evaluatePreconfiguredWaf('${rule.value}', {'sensitivity': 1})" }
      }
    }
  }

  rule {
    priority    = 2147483647
    action      = "allow"
    description = "default"
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
  }
}

# certs.tf
resource "google_certificate_manager_dns_authorization" "d" {
  for_each = toset(var.domains)
  project  = var.project_id
  name     = "dnsauth-${replace(each.value, ".", "-")}"
  domain   = each.value
}

resource "google_dns_record_set" "auth" {
  for_each     = google_certificate_manager_dns_authorization.d
  project      = var.dns_project_id
  managed_zone = var.public_zone_name
  name         = each.value.dns_resource_record[0].name
  type         = each.value.dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [each.value.dns_resource_record[0].data]
}

resource "google_certificate_manager_certificate" "c" {
  project = var.project_id
  name    = "cert-${var.env}"
  managed {
    domains            = var.domains
    dns_authorizations = [for d in google_certificate_manager_dns_authorization.d : d.id]
  }
}

resource "google_certificate_manager_certificate_map" "m" {
  project = var.project_id
  name    = "cm-${var.env}"
}

resource "google_certificate_manager_certificate_map_entry" "e" {
  for_each     = toset(var.domains)
  project      = var.project_id
  name         = "cme-${replace(each.value, ".", "-")}"
  map          = google_certificate_manager_certificate_map.m.name
  certificates = [google_certificate_manager_certificate.c.id]
  hostname     = each.value
}

# DNS A record for the app hostname
resource "google_dns_record_set" "app" {
  for_each     = toset(var.domains)
  project      = var.dns_project_id
  managed_zone = var.public_zone_name
  name         = "${each.value}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.lb.address]
}
```
[Certain] Deploy Armor with `armor_preview = true` first and read the `securityPolicy` fields in LB logs for a week before blocking. Provision the certificate and wait for `ACTIVE` before moving DNS, or you get a TLS outage at cutover.

---

## 4. Store instances: the full inventory

| Store | Shape | HA | Backup / RPO | Scale path | DR | Reached via |
|---|---|---|---|---|---|---|
| Cloud SQL Postgres 16 | `db-custom-N`, SSD, autoresize | `REGIONAL` (synchronous standby) | PITR 7d, 14 daily, RPO ≈ seconds | Tier up (restart), read replicas | Cross-region replica, promote manually | PSC IP + private DNS `pg.<internal>` |
| Spanner (optional) | Autoscaled PUs, regional config | Built in | Daily backup schedule, 7d | Autoscaler | Multi-region config instead of replica | Spanner API via PSC Google APIs |
| Redis Cluster | N shards × 1 replica, multi-zone | Per-shard replica | Treat as cache; no RPO promise | Add shards | Rebuild from source | PSC endpoints in `snet-psc-a` |
| Managed Kafka | vCPU/GiB per cluster, RF=3 | 3 zones | Topic retention only, no backup [Certain] | Raise capacity, add partitions | Second cluster + mirroring (✘ not written) | Subnet attachment in `snet-data-a` |
| Pub/Sub | Managed | Regional | Retention 7d + DLQ | Automatic | Multi-region topics (not enabled) | Google APIs via PSC |
| BigQuery | Reservation + autoscale | Regional | Time travel 7d, snapshots (✘) | Slot autoscale | Cross-region dataset copy (✘) | Google APIs via PSC |
| GCS | Per bucket, CMEK | Regional (or dual-region) | Versioning + soft delete | Automatic | Dual-region for critical buckets | Google APIs via PSC |
| Secret Manager | User-managed replica, CMEK | Regional | Versions | n/a | Add replicas | Google APIs via PSC |
| Artifact Registry | Regional repo | Regional | Immutable tags | Automatic | Mirror to second region | `pkg.dev` via PSC DNS |

[Certain] Kafka and Redis are the two stores where "HA" does not mean "recoverable". Kafka has no backup, and Redis is a cache. If either holds the only copy of something, that is a design bug.

[Likely] Pick one backbone for events. Kafka and Pub/Sub in parallel means two sources of truth and double cost.

---

## 5. Which Google service lives in which project

```
prj-b-seed       storage (tf state) · iam · cloudkms (state key) · cloudresourcemanager
prj-b-cicd       iam (WIF, sts) · artifactregistry (TF runner image)
prj-c-logging    logging · bigquery (log analytics)
prj-c-kms        cloudkms
prj-c-secrets    secretmanager
prj-c-dns-hub    dns
prj-c-scc        securitycenter · pubsub (findings)
prj-p-net-host   compute · dns · servicenetworking · networkconnectivity · servicedirectory
prj-p-app-svc    container · sqladmin · redis · managedkafka · artifactregistry · binaryauthorization
                 containeranalysis · clouddeploy · monitoring · logging · pubsub · certificatemanager
prj-p-data       bigquery(+storage,+reservation) · datacatalog · storage · pubsub · dataflow · spanner
```
[Certain] Enable `compute`, `dns` and `servicenetworking` in the **host** project. Service projects that consume PSC endpoints need `networkconnectivity` as well. `apis.tf` currently lists one flat set per project. Split it per project from this table.

---

## 6. Shared network: ownership and IAM matrix

```
HOST (prj-p-net-host)                          SERVICE (prj-p-app-svc, prj-p-data)
 owns: VPC, subnets, NAT, FW policy,            owns: GKE, SQL, Kafka, Redis, buckets, datasets
       DNS zones, PSC endpoint for APIs,         consumes: subnets (networkUser, per subnet)
       VPN/NCC, flow logs                        creates: PSC consumer endpoints in host subnets
 team: network (small, privileged)               team: app/platform
```

| Principal | Where | Role | Why |
|---|---|---|---|
| `sa-tf-net` | host project | `compute.networkAdmin`, `dns.admin` | Owns network stage only |
| `sa-tf-app` | service projects | Resource-specific admin roles | Cannot touch the host |
| `<proj-num>@cloudservices` | each used subnet | `compute.networkUser` | MIGs and Google-managed provisioning |
| GKE service agent | each GKE subnet | `compute.networkUser` | Create nodes and NEGs |
| GKE service agent | host project | `container.hostServiceAgentUser` | Shared VPC GKE |
| App group | host project | **None** | Must never edit firewalls or routes |

[Certain] The most common Shared VPC mistake is granting `networkUser` at the host project level, which lets any service-project admin attach to any subnet, including prod from dev. `shared_vpc_iam.tf` grants it per subnet; keep it that way.

---

## 7. Platform glue: logging, budgets, registry, supply chain, CI

`1-org/logging.tf`
```hcl
resource "google_logging_project_bucket_config" "org" {
  project        = var.logging_project_id
  location       = var.log_location
  bucket_id      = "org-all"
  retention_days = 400
  locked         = var.lock_log_bucket   # [Certain] irreversible once true
}

resource "google_logging_organization_sink" "all" {
  name             = "sink-org-all"
  org_id           = var.org_id
  include_children = true
  destination      = "logging.googleapis.com/projects/${var.logging_project_id}/locations/${var.log_location}/buckets/${google_logging_project_bucket_config.org.bucket_id}"
  filter           = "severity >= WARNING OR logName:\"cloudaudit.googleapis.com\" OR resource.type=\"gce_subnetwork\""

  exclusions {
    name   = "lb-200-sampled"
    filter = "resource.type=\"http_load_balancer\" AND httpRequest.status=200 AND sample(insertId, 0.9)"
  }
}

resource "google_project_iam_member" "sink_writer" {
  project = var.logging_project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.all.writer_identity
}
```

`4-projects/modules/app_project/budget.tf`
```hcl
resource "google_billing_budget" "b" {
  billing_account = var.billing_account
  display_name    = "budget-${var.env}"

  budget_filter { projects = ["projects/${var.project_number}"] }
  amount { specified_amount { currency_code = var.currency  units = tostring(var.monthly_budget) } }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.8, 1.0]
    content { threshold_percent = threshold_rules.value }
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }
  all_updates_rule {
    pubsub_topic   = var.budget_topic_id
    schema_version = "1.0"
  }
}
```
[Certain] Budgets alert, they don't cap. A runaway BigQuery or NAT bill needs an actual automated response (a function that detaches billing or scales down), or a hard custom quota.

`5-app-infra/modules/artifact_registry/main.tf` and `binauthz/main.tf`
```hcl
resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = "docker-${var.env}"
  format        = "DOCKER"
  kms_key_name  = var.kms_key_id
  docker_config { immutable_tags = true }

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions { keep_count = 30 }
  }
  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"
    condition { tag_state = "UNTAGGED"  older_than = "604800s" }
  }
}

resource "google_container_analysis_note" "ci" {
  project = var.project_id
  name    = "attestor-ci-note"
  attestation_authority { hint { human_readable_name = "Built and scanned by CI" } }
}

resource "google_binary_authorization_attestor" "ci" {
  project = var.project_id
  name    = "attestor-ci"
  attestation_authority_note {
    note_reference = google_container_analysis_note.ci.name
    public_keys {
      id = data.google_kms_crypto_key_version.sign.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.sign.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.sign.public_key[0].algorithm
      }
    }
  }
}

resource "google_binary_authorization_policy" "p" {
  project                       = var.project_id
  global_policy_evaluation_mode = "ENABLE"

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = var.binauthz_enforce ? "ENFORCED_BLOCK_AND_AUDIT_LOG" : "DRYRUN_AUDIT_LOG_ONLY"
    require_attestations_by = [google_binary_authorization_attestor.ci.name]
  }
}
```
[Likely] The attestor wiring (asymmetric KMS signing key, `data.google_kms_crypto_key_version.sign`) needs a key with `purpose = "ASYMMETRIC_SIGN"` that I haven't included in `kms.tf`. Start in dry-run, read the audit logs, then enforce.

`.github/workflows/tf-apply.yml`
```yaml
name: tf-apply
on:
  push: { branches: [main], paths: ["infra/**"] }
permissions: { id-token: write, contents: read }

jobs:
  apply:
    runs-on: ubuntu-latest
    strategy:
      max-parallel: 1                       # stages are ordered, never parallel
      matrix:
        include:
          - { dir: infra/3-networks/envs/development, sa: "${{ vars.SA_TF_NET }}",  env: development }
          - { dir: infra/3-networks/envs/nonprod,     sa: "${{ vars.SA_TF_NET }}",  env: nonprod }
          - { dir: infra/3-networks/envs/production,  sa: "${{ vars.SA_TF_NET }}",  env: production }
    environment: ${{ matrix.env }}          # "production" environment has required reviewers
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ matrix.sa }}
      - uses: hashicorp/setup-terraform@v3
      - run: terraform -chdir=${{ matrix.dir }} init -input=false
      - run: terraform -chdir=${{ matrix.dir }} plan -input=false -out=tfplan
      - run: terraform -chdir=${{ matrix.dir }} apply -input=false tfplan
```
[Certain] The plan job on PRs should run `fmt -check`, `validate`, `tflint` and `checkov`, and post the plan as a comment. Apply from the *saved* plan, as above, so what was reviewed is what runs.

---

## 8. Failure walkthrough: what actually happens

| Event | What responds | What breaks or degrades | Gap |
|---|---|---|---|
| One zone lost | Regional GKE reschedules, SQL standby promotes, Kafka RF=3, LB drains the NEG | Brief connection errors, ≈1–2 min for SQL failover | Pods need zone spread (set in the manifest) |
| Region lost | Global LB stops routing to dead backends | **Everything stateful** unless a second region exists | DR region is not built; only cross-region SQL replica and backups |
| Traffic spike 5× | HPA scales pods in ~1–3 min, CA adds nodes in a few minutes | Latency during node boot | Pre-warm min replicas before known events |
| Pod IP range exhausted | Nothing | Pods stuck `Pending`, no cheap fix | Add secondary range plus new node pool (planned in `subnets.auto.tfvars`) |
| DB connections exhausted | Nothing | Errors across all pods at once | Pooler plus `pool_size` budget |
| NAT port exhaustion | DPA raises ports up to 4096 | Intermittent egress failures to a single destination | Add NAT IPs, alert on `nat_allocation_failed` |
| Bad deploy | Readiness probe, `maxUnavailable: 0`, Cloud Deploy rollback | Canary users | Needs a real SLO alert to trigger rollback |
| Armor false positive | Preview mode logs it | Blocked legit traffic after enforcement | Read preview logs first |
| KMS key disabled/destroyed | Nothing | **Data unreadable** | `prevent_destroy`, separate admins, alert on key state changes |
| Terraform state lost | Versioned bucket | Cannot manage infra | Bucket versioning and a copy outside the seed project |
| CI credential abused | WIF `attribute_condition` limits repo | Whatever that SA can do | Keep per-stage SAs minimal |

---

## 9. Quotas to request before prod, and go-live checklist

Request these early. Lead time can be days:
- Regional **CPUs** (and CPUs for N2/highmem/Spot separately), **in-use external IPs**, **static addresses** (NAT IPs plus LB IP)
- **Forwarding rules** and **backend services** per project, **Cloud NAT** IPs
- **SSD/PD capacity** per region, **Cloud SQL** instance and storage limits
- **Pub/Sub** throughput per region, **BigQuery** slot reservation maximum

Go-live checklist:
```
□ Load test to 2× expected peak, record where it breaks first
□ SQL failover drill, replica promotion drill, a real restore into a scratch instance
□ Zone-evacuation drill (cordon one zone's nodes)
□ Armor preview → block, after one week of logs
□ VPC-SC dry-run violations at zero, then enforce
□ BinAuthz dry-run clean, then enforce
□ Cert ACTIVE before DNS move, DNS TTL lowered a day earlier
□ Budgets, SLO burn-rate alerts, DLQ-depth alerts, key-state alerts routed to on-call
□ Break-glass admin path tested (and alarmed when used)
□ Quotas confirmed in the prod region
```

---

## 10. Updated status

Now written: `node_pools.tf`, `lb_global` (IP, Armor, certs, DNS), all `k8s/` manifests shown, org logging sink, budget, Artifact Registry, Binary Authorization, CI apply workflow.

Still ✘: `0-bootstrap/main.tf`+`iam.tf`, `org_policies.tf` HCL, `routes.tf`, `lb_internal.tf`, `psc_publish.tf`, `egress_fqdn.tf`, `interconnect.tf`, `access_levels.tf`+`ingress_egress.tf`, Dataflow, Kafka Connect, DR-region stack, Cloud Deploy YAML, SLO/uptime/dashboards, and the per-env `main.tf` wiring that calls every module. [Certain] That wiring is the least glamorous gap and the one that stops `terraform apply` from running at all.

I haven't touched your repo. What are your peak events/sec, average event size and required retention? With those I can turn every placeholder above into real numbers, and only then is it worth packaging this as a runnable module with the env wiring.