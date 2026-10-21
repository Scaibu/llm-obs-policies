[Certain] The gap in my earlier answers wasn't missing code, it was missing decision logic. The hard parts of this build are about 10 irreversible decisions (org shape, project boundaries, CIDR plan, regions, key locations, identity model), and Terraform can't make them for you. So each layer below gives its purpose, the decisions with a rule for each, the algorithm to follow, the Terraform structure, and an exit gate you must pass before the next layer. No code.

[Likely] The details are standard for Google Cloud foundations, but I haven't verified product limits against current docs, so check quotas and newer products (Managed Kafka, Redis Cluster) before committing.

---

## The dependency spine

```
L0 Manual prerequisites
L1 Identity              who exists
L2 Permissions           what they may do, and what nobody may do
L3 APIs                  what services are switched on, where
L4 Storage (API-only)    state, keys, logs, buckets, datasets, secrets
L5 Network               VPC, subnets, egress, firewall, DNS, private access
L6 Storage (in-VPC)      SQL, Redis, Kafka, Spanner
L7 Compute + scaling     GKE, pools, autoscaling
L8 Edge                  LB, certs, WAF
L9 Security overlay      perimeter, image admission, threat detection
L10 Observability        logs, alerts, SLOs, budgets
L11 Delivery             infra CI, app CI/CD
```

**Placement algorithm (for any resource you're unsure about):**
1. Does it need a subnet, PSC endpoint or VPC IP to exist? Yes → after L5 (L6 or L7).
2. Does it need a key? Then the key and the grant to its service agent come first, in L4.
3. Does it need a service agent identity? Then its API must be enabled first (L3).
4. Does it need a project? Then the project and folder exist first (L2).
5. If none apply, it goes in L4 or later, and no earlier than what it references.

---

## L0. Manual prerequisites (human, once)

1. Verify a Cloud Identity or Workspace domain. This creates the organization node.
2. Create a billing account and make a small group its administrators.
3. Create admin groups: org-admins, billing-admins, security-admins, network-admins, devops, developers, data-analysts, auditors, break-glass.
4. Enforce 2-step verification, with hardware keys for admins.
5. Create two break-glass accounts. Store credentials offline, and alert on every use.
6. Decide and write down the **irreversible decisions** (table below) before touching Terraform.

| Decision | Rule | Why irreversible |
|---|---|---|
| Regions | One primary, one DR candidate, chosen by user latency, data residency, and product availability | Changing region means recreating stateful resources |
| Project boundaries | One project per environment per concern (network host, app, data, KMS, logging) | Moving resources between projects is partial and painful |
| CIDR plan | Non-overlapping across envs, on-prem and partners; reserve 2x growth | Overlap blocks VPN/peering; ranges barely resize |
| Naming | `<type>-<env>-<region>-<purpose>`, enforced in a module | Renames force recreation |
| BigQuery location | Same as sources and keys | Immutable per dataset |
| Key locations | Same as the resource each key protects | A mismatch fails or blocks replication |
| Identity model | Groups for humans, service accounts for machines, no keys | Retrofitting is a full IAM audit |

[Certain] If you skip step 6, you'll rebuild layers 2 to 5 within a year.

---

## L1. Identity

**Purpose:** create every principal that will ever act, and bind humans to groups only.

**Decisions**
- One Terraform service account per stage, not one admin account. Rule: a stage's account can only touch what that stage owns. [Certain] A single all-powerful Terraform account is the most common privilege-escalation path in these builds.
- How CI authenticates. Rule: federated tokens (Workload Identity Federation) tied to a specific repository and branch; never downloaded service account keys.
- Who may impersonate whom. Rule: only the CI identity plus a small break-glass group, and impersonation is logged.

**Algorithm**
1. Human, using your own credentials, creates the bootstrap folder, a seed project, and a CI project.
2. Create the state bucket in the seed project: versioned, no public access, retention on deleted versions.
3. Create one Terraform service account per stage: org, environments, network, projects, apps.
4. Grant each account only the roles its stage needs. At org level only the org stage gets folder and policy admin.
5. Create the federation pool and provider. The provider's condition must pin the repository (and ideally branch or environment). A provider with no condition trusts every repo on GitHub.
6. Bind: federated identity for that repo → permission to impersonate the matching stage account.
7. Switch Terraform from your human credentials to impersonation. From now on a human applies nothing.
8. Migrate local state to the bucket, with one state path per stage and environment.

**Terraform structure:** `0-bootstrap/` holds folder, projects, bucket, service accounts, federation pool, impersonation bindings. It is the only stage run by a human, once, and afterwards only rarely.

**Exit gate:** CI can impersonate `sa-tf-org` and run a no-op plan. A different repo cannot. Your personal account can no longer apply.

**Failure modes:** [Certain] the quota-project error on first org-level calls (set the billing project to the seed project after it exists); losing the state bucket (copy it somewhere outside the seed project).

---

## L2. Permissions

**Purpose:** build the hierarchy, then define what is allowed, and set hard limits nobody can override.

**Decisions**
- Hierarchy shape. Rule: common (shared services), bootstrap, then one folder per environment (dev, nonprod, prod). A small team merges dev and nonprod, never prod.
- Role strategy. Rule: predefined roles at the narrowest scope that works; custom roles only when a predefined role grants a clearly dangerous extra permission.
- Guardrail strategy. Rule: organization policies for configuration limits, deny policies for actions that must never happen, whatever the allow rules say.

**IAM assignment algorithm (use for every grant)**
1. Is the principal a human? Bind a group, never a person.
2. Is it a machine? Use a dedicated service account for that workload only.
3. Choose the lowest scope: resource, then project, then folder, then org. Move up only if the resource count makes lower scope unmanageable.
4. Choose the narrowest predefined role. If none fits, compare custom role vs. accepting a slightly broader one and document it.
5. Prefer additive membership bindings over authoritative ones, except at org/folder level where you want drift corrected.
6. Add a condition (time-bound, resource-name) for anything privileged or temporary.
7. Record the owner and the reason.

**Algorithm for this layer**
1. Create the folders.
2. Create common projects: logging, KMS, secrets, DNS hub, security, billing export (and a network hub only if hybrid or multi-VPC).
3. Apply organization policies at the org. Core set: no default network, no external IPs on VMs, no service account key creation or upload, public storage blocked, uniform bucket access, no public database IPs, OS Login, Shielded VM, allowed locations only, restricted sharing outside your domain.
4. Add deny policies for: disabling audit logs, deleting the log bucket, using the root of the org outside break-glass.
5. Bind groups to folders: security admins at org, network admins on the network host projects only, developers on app projects only, auditors read-only everywhere.
6. Create environment projects through a single reusable project module: it sets name, folder, billing, labels, deletion protection, and a budget. Never create projects by hand.
7. Add exceptions to org policies only per folder, with a written reason and an expiry date.

**Terraform structure:** `1-org/` (folders, policies, deny, group IAM, org-wide firewall policy, org log sink), `2-environments/` (per-env baseline), and `4-projects/` (project factory). Project creation runs late, but the module is designed here.

**Exit gate:** attempt, as a developer group member, to create a VM with an external IP, a public bucket, and a service account key. All three must fail.

**Failure modes:** [Certain] organization policies applied after projects exist can break running resources; apply them first. [Likely] overly tight allowed-locations breaks global services.

---

## L3. APIs

**Purpose:** switch on exactly the services each project needs, in the right project, in the right order.

**Algorithm**
1. Build a table: rows are projects, columns are services. Fill from the resources you plan, using the placement algorithm.
2. Always enable in the **host** project: compute, DNS, service networking, network connectivity. In **service projects** that consume private endpoints: compute plus networkconnectivity plus the product itself.
3. Enable APIs at the start of each project's module, and make every resource depend on its API.
4. Create service agents explicitly for every product that needs a key or cross-project access (SQL, BigQuery, Pub/Sub, Kafka, Redis, GCS, Secret Manager, GKE). Service agents don't exist until the API is enabled and sometimes until first use.
5. Set "do not disable on destroy", so tearing down one module doesn't break its neighbors.
6. Never enable APIs inside the application stage ad hoc; add them to the table, then to the module.

**Terraform structure:** one API list per project role (network-host, app, data, kms, logging), maintained in the project module, not scattered.

**Exit gate:** every project's enabled-services list matches the table, and each service agent exists.

**Failure modes:** [Certain] the most common first-apply failures are a missing API in the host project and a service agent referenced before it exists. [Certain] eventual consistency: allow time after enabling.

---

## L4. Storage that needs no VPC

Order inside this layer matters: keys → state/log/audit buckets → data stores → secrets.

**Keys (KMS)**
- Decision: one key per data class (database, analytics, messaging, objects, secrets), not one key for everything. [Certain] One key means one blast radius.
- Rule: location matches the protected resource; rotation about every 90 days; key admins are a different group from key users; destruction protection on.
- Algorithm: create key ring and keys in the KMS project → create the service agents (L3) → grant each agent encrypt/decrypt on exactly its key → only then create the resource that references it.

**Logging**
- Decision: centralize. Rule: an org-level sink with children included, writing to a dedicated log bucket in the logging project, retention set by compliance, locked once you are sure (irreversible).
- Add exclusions for noisy successes only after you know what they are. Never exclude audit logs.

**Object storage**
- Decision per bucket: region vs. dual-region (dual only where RPO must be near zero), versioning, retention lock, lifecycle to colder classes.
- Rule: uniform access, public prevention enforced, key per data class, no bucket per developer.

**Analytics (BigQuery)**
- Decision: layered datasets (raw, curated, marts). Raw is append-only; transformations write forward only.
- Rules: partition by event time, cluster on your most common filters, require a partition filter, set expiration, enforce column-level tags for personal data, grant at dataset level to groups.
- Cost strategy: reservations with a hard ceiling, or a per-day query quota. [Certain] Default on-demand billing has no cap.

**Secrets**
- Decision: Terraform creates the secret container and permissions, never the value. Values enter out-of-band or via rotation. [Certain] Values in Terraform end up in state.

**Messaging (Pub/Sub)**
- Rule: every subscription has a dead-letter topic, and every dead-letter topic has its own subscription and an alert on depth; otherwise dead letters expire silently.

**Exit gate:** write and read an object and a table row using the key; revoke the agent's grant in a test project and confirm access fails; confirm a log entry arrives in the central bucket.

---

## L5. Network

**Purpose:** a private, shared, observable network with controlled egress and private access to Google services.

**Decisions and rules**

| Decision | Rule |
|---|---|
| Model | Shared VPC: a host project per environment owns the network, service projects consume subnets |
| Environments | Separate VPC per environment. Connect them only deliberately, never by default |
| Subnets | Regional, not per-zone. One per role per region: nodes, data endpoints, private service connect, proxy-only (only if internal load balancers) |
| Private Google access | On for every subnet, plus one private endpoint for Google APIs with DNS pointing at it |
| Managed-service access | Prefer private endpoints (PSC) over peering for new builds, because peering is non-transitive |
| Egress | NAT with static IPs and dynamic port allocation. Start egress open and logged, tighten to allowlists once observed |
| Firewall | Network firewall policies with identity-based tags, default deny ingress, org-level policy for management ports |
| DNS | Private zones per environment, a central hub for forwarding to on-prem, query logging on |
| Hybrid | HA VPN to start, Interconnect for bandwidth or latency needs. Hub-and-spoke connectivity only if three or more networks must talk |

**CIDR allocation algorithm**
1. List every range that must never collide: on-prem, partners, other clouds, future regions.
2. Give each environment a primary block, large enough for 2x current plan.
3. Give Kubernetes pods and services a separate secondary range per environment, taken from non-routable space so your routable space stays free.
4. Size pods by this rule: nodes you may ever need × 1.5 (surge and upgrades) = address blocks needed, then round up. [Certain] This is the range you can't fix cheaply.
5. Reserve the Google API endpoint address outside every subnet.
6. Reserve a block for private service access if any peering-based service remains.
7. Record the plan in a table that lives in the repo and is checked in CI for overlaps.

**Algorithm**
1. In each host project, create the VPC, then subnets from the CIDR table.
2. Create routers and NAT with static addresses; give partners those addresses.
3. Create the identity tags for firewall rules, then the firewall policy with explicit rules by tier, then associate it. [Certain] Tag-based rules match nothing until the tags are bound to the instances, which is why this must be coordinated with the node pool definition in L7.
4. Create the Google API private endpoint, then the DNS zones that route Google domains to it.
5. Create DNS forwarding to and from on-prem, if hybrid.
6. Attach service projects, then grant subnet-level network user to exactly the accounts that need each subnet. Never at host-project level.
7. Add flow logs at a sampling rate you can afford (higher in prod, near zero in dev).
8. Add hybrid connectivity last, with redundant tunnels and BGP.
9. Run connectivity tests as part of the pipeline.

**Terraform structure:** `3-networks/` with a shared module and one root per environment; the CIDR table is the single source of values.

**Exit gate:** a test VM with no external IP can reach Google APIs (through the private endpoint, not NAT), reach the internet only via the NAT addresses, and cannot be reached from the internet. A service project in dev cannot attach to a prod subnet.

---

## L6. Storage that lives in the VPC

**Store selection algorithm**
1. Relational with transactions, single-writer is fine → managed Postgres. Needs horizontal write scale or global consistency → Spanner, but only if you can model keys to avoid hotspots.
2. Cache or ephemeral lookups → Redis. [Certain] Nothing irreplaceable lives there.
3. Event backbone → choose **one**: Pub/Sub (simplest) unless you need ordering within consumer groups, replay by offset, compaction or Kafka Streams; then Kafka.
4. Very high-rate key-value or time-series lookups → evaluate Bigtable.
5. Analytics → BigQuery (L4), fed from the backbone.

**Rules per store**
- Always: private connectivity only, customer-managed key (L4), deletion protection, backups tested, access via identity not passwords where supported.
- Postgres: high-availability mode on, point-in-time recovery, read replica in the DR region, connection pooling. [Certain] Connection count (pods × pool size) usually fails before CPU does; compute that budget before choosing the tier.
- Redis: cluster mode with replicas across zones; requires cluster-aware clients.
- Kafka: replication factor 3 with minimum in-sync replicas of 2; partitions can only grow, so size from peak throughput and maximum consumer instances.

**Algorithm**
1. Reserve endpoint addresses in the data subnet.
2. Create each store with its key and private connection.
3. Register DNS names so applications use names, never addresses.
4. Create workload service accounts and grant per-resource access.
5. Configure backups and a replica or standby in the DR region.
6. Run a restore into a scratch instance. [Certain] An untested backup is a guess.

**Exit gate:** from a pod, connect with workload identity, read and write, kill the primary zone's instance in a drill and confirm failover time meets your target.

---

## L7. Compute and scaling

**Decisions**
- Autopilot vs Standard. Rule: Autopilot unless you need privileged workloads, special kernels or tight cost control at steady high load.
- Private nodes, regional control plane, workload identity, managed Prometheus, dataplane with network policy built in.
- Node pools by workload class: system, general, memory-heavy, interruptible batch (tainted).

**Scaling chain (in the order it fails)**

1. Database connections.
2. Pod address space.
3. Project quotas (CPUs, addresses).
4. NAT ports.
5. Kafka partitions.
6. Compute.

**Capacity algorithm**
1. Measure per-pod throughput at 65% CPU in a load test.
2. Pods at peak = peak requests per second ÷ per-pod throughput × 1.3.
3. Nodes at peak = pods ÷ pods per node, bound by CPU and memory, not the 110 cap.
4. Pod address blocks needed = nodes × 1.5. Compare with L5; if short, stop and replan.
5. Database connections = pods × pool size; if above the limit minus reserve, add pooling or shrink pools.
6. Request quota for peak plus 50%, in the prod region, early.
7. Set autoscaler minimums to cover known events, since node boot takes minutes.

**Algorithm**
1. Create the cluster and node service account (minimal roles, never the default).
2. Create pools with autoscaling bounds from step 2 and 3, taints for isolated classes, and the firewall tag binding from L5.
3. Terraform must ignore node counts after creation, or it fights the autoscaler.
4. Apply namespace baseline: default-deny network policies, resource quotas, pod security restricted.
5. Per service: service account bound to workload identity, spread across zones, disruption budget, readiness/liveness probes, pre-stop delay for graceful drain, autoscaler on CPU or a request or lag metric, memory limits set, CPU limits omitted.

**Exit gate:** load test to 2x expected peak, record what breaks first, and confirm a zone drain loses no requests beyond your error budget.

---

## L8. Edge

**Ownership rule:** [Certain] if Kubernetes Gateway objects create the load balancer, Terraform owns only what they reference (static address, certificate map, WAF policy, DNS). Two owners of one load balancer will fight forever.

**Algorithm**
1. Reserve the global address.
2. Create certificates with DNS authorization and wait until active.
3. Create the WAF policy in **preview** mode with rate limits; read logs for a week; then enforce.
4. Apply the Gateway and routes referencing those three objects.
5. Lower DNS TTL a day ahead, then point DNS at the address.
6. Verify health checks, draining, and cache behavior.

**Exit gate:** a request from outside traverses TLS, WAF, CDN and reaches a pod, and a simulated attack pattern is logged without blocking legitimate traffic.

---

## L9. Security overlay

- **Perimeter (VPC Service Controls):** [Certain] always dry-run first. Collect violations for weeks, add explicit allow rules for legitimate flows (CI, cross-project reads, Google-managed services), then enforce. Enforcing early breaks pipelines.
- **Image admission (Binary Authorization):** require signed attestations from CI; dry-run, read audit logs, enforce.
- **Threat detection:** Security Command Center at org level, findings routed to your alerting.
- **Audit:** admin and data access logs on for sensitive services, alerts on break-glass use, key state changes, IAM policy changes and firewall changes.

---

## L10. Observability and cost

1. Service-level objectives on availability and latency at the load balancer; alert on error-budget burn, not raw CPU.
2. Alerts for each failure mode in L7's chain: connections, address space, NAT allocation failures, consumer lag, dead-letter depth, replica lag, disk, key state.
3. Budgets at 50/80/100% plus forecast. [Certain] Budgets notify, they don't stop spending; pair them with quotas or an automated response for services that can run away (analytics, NAT, egress).
4. A weekly review of top cost drivers and top log volume.

---

## L11. Delivery

**Infrastructure pipeline algorithm**
1. Pull request: format, validate, lint, policy scan, CIDR overlap check, plan posted as comment.
2. Merge: apply the **saved** plan, so reviewed equals executed.
3. Stages apply in order, never in parallel; environments in order dev → nonprod → prod, with required approval before prod.
4. Daily drift detection: plan only, alert on any diff.
5. Destruction safety: deletion protection on stateful resources, plus a rule that no plan containing a delete of a protected type can auto-apply.

**Application pipeline:** build → scan → sign → promote through environments → canary in prod → automatic rollback on SLO burn.

**State strategy:** one state per stage per environment, split further when plans exceed a few minutes or when two teams collide. Stages communicate through explicit outputs, not by reading each other's state.

---

## Final order, as a checklist

1. L0 decisions written down
2. Bootstrap: seed, CI project, state bucket, stage accounts, federation
3. Folders, org policies, deny policies, group IAM
4. Common projects, then environment projects via the factory
5. APIs per project, service agents
6. Keys → logging → buckets → datasets → secrets → messaging
7. VPC, subnets, NAT, firewall, private endpoints, DNS, Shared VPC IAM, hybrid
8. Databases, cache, backbone, with restore drills
9. Cluster, pools, workloads, scaling tests
10. Edge, in preview first
11. Perimeter, image admission, threat detection, all dry-run first
12. Alerts, SLOs, budgets
13. CI for infra and apps, drift detection

I haven't touched your repo. [Guessing] The sizing steps depend on numbers I don't have: peak requests per second, events per second and average size, retention, and region count. Which of those can you give me first? Events per second and event size decide Pub/Sub vs. Kafka, which is the one choice in L6 that changes the shape of everything after it.