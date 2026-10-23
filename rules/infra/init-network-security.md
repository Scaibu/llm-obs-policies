**Rules you can't verify will weaken this design, not strengthen it.** [Certain] An unenforced rule gives you a false belief that something is blocked. So every rule below has three parts: the requirement, where it is enforced per runtime (Docker → K8s → GCP), and a test that fails when it is violated. Rules without a test belong in a style guide, not in security policy.

**Conventions:** MUST means CI blocks the change. SHOULD means a time-boxed exception with a named owner is allowed. Confidence tags apply to factual claims, and the requirements themselves are decisions. This is design only, and I haven't touched any repo.

---

## A. Foundation

**FND-01 Default deny at every layer, both directions.**
- Docker: `DOCKER-USER` ends in DROP, and only explicit ACCEPTs precede it.
- K8s: a default-deny ingress+egress NetworkPolicy exists in every namespace, created by the namespace template, not by hand.
- GCP: a priority-65534 deny-all egress and ingress rule exists in every VPC.
- Test: a new namespace or network with no policy can't reach anything.
- [Certain] GCP's implied egress rule is allow-all, so the explicit deny is required.

**FND-02 IPv6 is a first-class citizen.** Either disable it everywhere or write every rule for both families.
- [Certain] GCP firewall rules are per IP version, so an IPv4-only deny leaves IPv6 open.
- Test: scan the same flow matrix over v4 and v6.

**FND-03 One CIDR plan for all three runtimes, in `policy/cidr-plan.yaml`.**
- Docker `default-address-pools`, GKE pod and service ranges, and VPC subnets must never overlap each other or any on-prem or peered range.
- [Certain] Overlap breaks peering and migration, and you can't renumber a live GKE cluster.
- Test: CI runs an overlap check over every range.

**FND-04 Policy is machine-readable and compiled.** Adapter output is generated from `flows.yaml`, never hand-edited.
- Test: regenerate in CI and diff against the committed output. Any diff fails.

## B. Segmentation

**SEG-01 Segments are fixed and named.** public, app, data, observability, admin, egress-proxy. A new segment needs a design review.

**SEG-02 One network per trust edge, not per tier.**
- Docker: app↔data gets its own network, app↔cache gets another.
- [Certain] Containers on one user-defined network reach each other on every port.
- Where per-container isolation is needed, use `com.docker.network.bridge.enable_icc=false`. [Likely]
- K8s: namespace per segment, plus pod-level policy inside it.
- GCP: subnet per segment, with firewall rules targeting service accounts or secure tags.

**SEG-03 Membership is by identity, not IP.**
- Never write rules against pod IPs or container IPs, because they change.
- GCP: match on service account or secure tag. [Certain] Network tags can be edited by anyone with instance-edit rights, so don't use them for security.
- K8s: label selectors plus mesh identity.

**SEG-04 The data segment is a sink.** No outbound connection initiated from data to any other segment, and no external route.
- Docker: `internal: true`.
- K8s: egress is limited to DNS, plus replication peers inside the segment.
- GCP: no NAT attached to the data subnets.
- Test: from a data container, `curl` to the internet and to the app segment both fail.

**SEG-05 No transitive trust.** A→B and B→C never implies A→C. Each edge is declared separately. Test: compile the flow graph and fail on any path not backed by a direct edge.

**SEG-06 Dependency graph is a DAG.** [Certain] Cycles hide undeclared bidirectional trust. Test: cycle detection on `flows.yaml`.

## C. Flow declaration

**FLW-01 Every flow row has these fields:** src, dst, proto, port (single), direction, reason, owner, ticket, created, review-by.
- No ranges, no `any`, no `0.0.0.0/0` as a source except the public LB listener.

**FLW-02 Flows are service-level, ports are workload-level.** A flow to "the data segment" is rejected. It must name the destination service.

**FLW-03 Contracts and flows must agree.** `CONTRACT.yaml` declares listens, calls, external needs, and explicit exclusions.
- The exclusions list is the valuable part, because it is what negative tests are generated from.
- Test: CI fails if a service calls something not in its contract, or the contract lists a call with no flow.

**FLW-04 Health checks and metrics scraping are separate flows.** Separate ports, separate source (checker, Prometheus), and read-only.
- Nothing on a health port may accept application traffic.
- GCP: allow Google's health-check ranges (130.211.0.0/22, 35.191.0.0/16) only to the health port. [Certain]

**FLW-05 Flows expire.** Review-by is at most 90 days. An expired flow is removed automatically by the compiler unless renewed.

## D. Egress

**EGR-01 No direct internet route from any workload.**
- Docker: only the egress-proxy container touches the outside network.
- K8s: egress via Cilium FQDN policy or a mesh egress gateway.
- GCP: Cloud NAT is scoped to the proxy subnet only, and Secure Web Proxy or NGFW does the FQDN filtering.
- [Certain] Cloud NAT does no filtering, and K8s NetworkPolicy can't match FQDNs.

**EGR-02 Allowlist by FQDN and port, with expiry and owner.** Wildcards only with written justification.

**EGR-03 Know the limits of FQDN allowlisting.**
- [Likely] Allowing a shared platform (github.com, S3, a CDN) lets an attacker exfiltrate to their own account on that platform.
- Where you can, allow specific paths via an inspecting proxy, or use private mirrors for package registries.
- [Likely] SNI-based filtering can also be bypassed by domain fronting on some CDNs.
- List these residual risks in `limits/`.

**EGR-04 Block SSRF targets by default.**
- App-segment egress denies 169.254.169.254, link-local ranges, and RFC1918 ranges it has no flow to.
- Test: a fetch of the metadata IP from an app container fails.

**EGR-05 DNS is only to the sanctioned resolver.**
- Block outbound 53/853 and known DoH endpoints to anywhere else.
- The data segment resolves internal names only. [Likely] DNS is the usual exfiltration channel once everything else is closed.

**EGR-06 Google APIs go via Private Google Access.** With VPC Service Controls, use the `restricted.googleapis.com` VIP (199.36.153.4/30). [Certain]

## E. Ingress and edge

**ING-01 One front door.** Public traffic enters only through the global LB with Cloud Armor (GCP), an ingress controller (K8s), or a single reverse-proxy container (Docker).
- Nothing else has a public IP.
- Enforce with org policy `compute.vmExternalIpAccess`. [Certain]

**ING-02 Published ports are explicit and bound.**
- Docker: `127.0.0.1:port:port` or a specific interface, never bare `port:port`.
- [Certain] Published ports bypass ufw and firewalld.
- Test: `ss -tlnp` and an external scan must match the published-port list exactly.

**ING-03 TLS 1.2 minimum at the edge, 1.3 preferred.** Modern cipher suites only, HSTS on public hostnames, and certificate renewal at least 30 days before expiry with an alert at 14 days.

**ING-04 Rate limits and request size limits at the edge.** Cloud Armor rate-based rules, ingress annotations, and proxy limits. Also set connection-table sizing, because [Likely] conntrack exhaustion is a common self-inflicted outage.

**ING-05 No management ports from the public segment.** SSH, RDP, kubelet 10250, etcd 2379/2380, the Docker API 2375/2376, and Swarm 2377/7946/4789 are never reachable from public.
- [Certain] The Docker TCP API on 2375 is unauthenticated root. Use 2376 with mTLS or the socket only.

## F. Identity and encryption

**IDN-01 mTLS for all service-to-service traffic.** Certificates live 24 hours or less, and revocation is by expiry.
- Docker: Envoy sidecars with SPIFFE/SPIRE.
- K8s: mesh STRICT mode.
- GCP: Cloud Service Mesh or a Certificate Authority Service-backed CA.
- Test: a plaintext connection to a service port is refused.

**IDN-02 Authorization is separate from authentication.** mTLS proves who is calling. An explicit AuthorizationPolicy says who may call what.
- [Certain] mTLS alone permits every authenticated caller.

**IDN-03 CA hierarchy.** An offline root, an online intermediate per environment, and no shared CA between prod and non-prod. Keys live in KMS or HSM, never in repo or image.

**IDN-04 Overlay networks are encrypted.** [Certain] Docker overlay VXLAN traffic is unencrypted unless you set the encrypted option. For Swarm, set `--opt encrypted`. On K8s, use CNI-level encryption (Cilium WireGuard) if nodes cross untrusted links.

**IDN-05 Database and broker wire protocols.**
- Postgres: `hostssl` only, SCRAM-SHA-256, and no `trust` entries.
- Kafka: separate listeners for client and inter-broker traffic, mTLS plus ACLs.
- Redis: TLS and ACL users, with the default user disabled.
- A listener without TLS is a violation, even on a private segment.

## G. DNS

**DNS-01 Split-horizon is enforced, not assumed.** Internal zones live in private zones (Cloud DNS private zones, CoreDNS, or an internal resolver) and are never served externally. Test: query internal names from outside and expect NXDOMAIN.

**DNS-02 TTL policy is lowered 48 hours or more before any migration** and restored after. Record the planned cutover time in the change ticket. CI fails if the change is scheduled before the TTL window has elapsed.

**DNS-03 Public zones use DNSSEC where the registrar supports it,** plus CAA records limiting issuing CAs. [Certain] CAA is checked by CAs at issuance.

**DNS-04 Guard against dangling records.** Delete DNS records in the same change that decommissions the service. [Likely] Dangling CNAMEs are a standard subdomain takeover path.

**DNS-05 DNS query logging is on** and alerts on high-entropy or unusually long names, which indicates tunneling.

## H. Host and container hardening that affects the network

**HST-01 No `network_mode: host`, no `hostNetwork: true`.**
- [Certain] The NetworkPolicy spec leaves hostNetwork pods undefined, and in many CNIs they bypass policy.

**HST-02 Drop capabilities.** `cap_drop: [ALL]` and add back only what is justified. [Certain] NET_RAW is granted by default in Docker and enables ARP spoofing and raw sockets. `NET_ADMIN` is never granted to workloads.

**HST-03 No privileged containers, no `docker.sock` mount,** and `allowPrivilegeEscalation: false`. K8s uses Pod Security Admission at `restricted`. Exceptions need signed-off, time-boxed approval.

**HST-04 Service account tokens are not mounted by default.** Only pods that call the API server get one, and they get a short-lived projected token. Their egress to the API server is the only allowed control-plane flow.

**HST-05 Nodes are private.** GKE private nodes, authorized networks on the control plane, and no SSH from the internet. Use OS Login with IAP TCP forwarding for the rare break-glass.

## I. Admin and access

**ADM-01 Admin access is a separate segment with its own path.** IAP, a bastion with short-lived credentials, or Teleport. Admin tools never run in the app segment.

**ADM-02 Admin and observability flows are one-way.** Observability scrapes in. Nothing in app or data initiates to admin. Alerts go out through a push gateway or an agent in the observability segment, never from data.

**ADM-03 Human access to data goes through audited sessions,** not direct network paths. No developer laptops in any flow, and no VPN that places users inside the data segment.

## J. Secrets and metadata

**SEC-01 No secrets, tokens, IPs, or certificates in policy files.** Reference them by name. A secret scanner runs in CI and fails the build.

**SEC-02 Metadata server access is denied by default and granted per workload identity.**
- GKE: Workload Identity, with the GKE metadata server enabled.
- Docker: block 169.254.169.254 with a `DOCKER-USER` rule.
- Service account keys are never created (`iam.disableServiceAccountKeyCreation`). [Certain]

## K. Observability and detection

**OBS-01 Log denies as well as allows.**
- Docker: iptables LOG rules on the DROP rule, rate-limited.
- K8s: Cilium Hubble or Calico flow logs, because [Certain] standard NetworkPolicy has no logging.
- GCP: VPC Flow Logs and firewall rule logging on the deny rules.

**OBS-02 Alert on deny spikes, new destinations, and flow-log silence.** The last one matters: logging that stops is itself an incident.

**OBS-03 Logs are tamper-resistant.** Ship them to a separate project or account with a locked retention bucket. The workload's service account cannot write to or delete from it, except for append-only writes.

**OBS-04 Telemetry carries no payloads, credentials, or full URLs with tokens.** Connection metadata only: duration, bytes, handshake latency, and trace context.

**OBS-05 Review flows against traffic quarterly.** A flow with no traffic in 90 days is flagged for removal.

## L. Change control and testing

**CHG-01 Every change is a PR, with CODEOWNERS from the security team on `policy/`.** No console or `kubectl` edits to firewall or policy resources. Drift detection compares live state to the compiled output nightly and pages on any difference.

**CHG-02 Negative tests are mandatory and generated from the contracts.** For each service, test every flow not in `flows.yaml` and require failure. Run them in CI against an ephemeral environment, and again nightly against staging.

**CHG-03 Migration order follows the dependency graph, leaf services first.** DNS TTLs are lowered first, flows are added before cutover, and old flows are removed only after traffic has drained.

**CHG-04 Append-only history.** Retired rules are marked retired with date and reason, never deleted from history.

**CHG-05 Org-level invariants live above the project.** GCP hierarchical firewall policy and org policies cannot be overridden by project admins. Include `compute.skipDefaultNetworkCreation`, `compute.restrictVpcPeering`, and `sql.restrictPublicIp`.

## M. Exceptions and limits

**EXC-01 Every adapter has a `limits/` file** listing what it cannot enforce and the compensating control.
- A flow that depends on an unenforceable property is not allowed until the limit is listed.
- Examples: Docker has no FQDN egress policy (a proxy compensates), and K8s NetworkPolicy has no L7 (a mesh policy compensates).

**EXC-02 Exceptions expire in 30 days or less,** with a named owner and a compensating control. Renewal requires re-approval.

**EXC-03 Break-glass is logged, time-boxed, and reviewed within 24 hours.** It never leaves a permanent rule behind. The compiler removes it on expiry.

---

[Likely] The first rules that will hurt are EGR-03 and CHG-01. FQDN allowlisting is weaker than people assume, and nightly drift detection will find manual edits you've forgotten about. Expect that in your first week.

Should I put this in a file, or draft the CI checks (FLW-03, SEG-06, CHG-02) first, since those make everything else enforceable? Once you approve one, I'll start on it.

**The most likely cause of your first serious outage is your own security policy, not an attacker, and two of my earlier rules make it worse.** [Likely]

1. **IDN-01 (24-hour mTLS certs).** [Certain] Short certs only work if the CA and issuance path are more available than the services depending on them. If the CA is down for 24 hours, every service loses identity at once.
2. **The single egress proxy I suggested for Docker.** [Certain] It's a single point of failure and the highest-value target in the design.

The rules below add what the first two passes lacked: failure modes, rollout, incident response, capacity, and the pipeline that applies the policy. I haven't touched any repo, and this is design only.

---

## N. Availability and failure modes

**AVL-01 Every security control declares fail-open or fail-closed, with a reason.** This covers the CA, the mesh control plane, the egress proxy, the policy engine, the DNS resolver, and the admission webhook.
- [Certain] A fail-closed admission webhook with no replicas blocks all deployments, including the fix. A fail-open one silently disables the control.
- Rule of thumb: the data path fails closed, and the control plane degrades to last-known-good policy.
- Test: kill each component in staging and record what happens.

**AVL-02 The CA and issuance path is HA and has a runbook.**
- Cert lifetime must be at least 10x the longest tolerable CA outage. If you can't keep the CA up for hours, use 7-day certs, not 24-hour.
- Alert at 50% of cert lifetime remaining on any workload that hasn't renewed.
- Test: stop the CA for a duration equal to half the lifetime. Services must keep working.

**AVL-03 The egress proxy, DNS resolver, and ingress are N+1 across zones,** with health checks and connection draining. A deploy of the proxy itself must not drop traffic.

**AVL-04 Control-plane loss does not break the data plane.**
- [Likely] The Cilium, Calico, and Envoy data planes keep enforcing the last programmed policy when their control plane is down.
- Test: take down the mesh control plane and confirm existing traffic and new connections still work.

**AVL-05 Clock sync is a dependency.**
- [Certain] Clock skew breaks mTLS validation, JWT validation, and log correlation.
- Use a single NTP source (Google's internal NTP on GCP) and alert on skew above 1 second.

## O. Safe rollout of policy

**RLT-01 Nothing goes straight to enforce.** Every policy goes through observe mode, then canary enforce, then full enforce.
- [Certain] Calico has staged network policies and Cilium has policy audit mode.
- [Likely] Istio supports dry-run on AuthorizationPolicy.
- GCP: enable firewall rule logging before the deny rule, and use Firewall Insights for hit counts and shadowed rules.
- Docker: put the LOG rule before the DROP and watch for a week.

**RLT-02 Brownfield: learn flows from traffic first.** Generate the draft `flows.yaml` from 2 to 4 weeks of flow logs, then have owners review it. Include month-end, quarterly, and backup jobs. [Likely] The flows you break are the ones that run once a month.

**RLT-03 Blast radius limit.** A policy change affects one segment or one environment at a time. A change that touches all segments needs two approvers and a scheduled window.

**RLT-04 Every change has a tested rollback under 5 minutes,** and automatic rollback triggers on SLO breach (error rate, p99 latency) within 10 minutes of the change.

**RLT-05 Lockout protection.** One protected admin path (IAP, serial console, break-glass VM) is excluded from the compiler's ability to remove it. Test this path monthly. [Likely] A deny-all applied without a tested way back in is a classic way to lock yourself out.

**RLT-06 Revocation is not instant.** [Likely] Established connections usually survive a rule removal, because stateful firewalls track them.
- Removing a flow requires an explicit connection kill or workload restart, plus a verification test.
- For emergencies, see IR-02.

## P. Incident response and containment

**IR-01 You can isolate one workload in under 2 minutes, without a deploy.** A pre-written quarantine policy keyed by a label:
- K8s: a high-priority deny policy applied by label.
- GCP: a secure tag or service-account-based deny at higher priority.
- Docker: disconnect the container from its networks.
- Test: a quarterly drill, timed.

**IR-02 Quarantine preserves evidence.** Block egress and ingress, but keep the workload running with a forensic capture path (memory, disk snapshot, pcap) in an isolated segment. Don't kill it first.

**IR-03 Kill switches exist per segment** (cut the egress proxy, sever a peering) and are documented as business decisions, with named people allowed to pull them.

**IR-04 Runbooks exist for:** credential leak, compromised workload, DDoS, CA compromise, DNS hijack, data exfil alert, and cloud account takeover. Each has an owner and was exercised within 6 months.

**IR-05 CA compromise plan.** Know how to rotate the intermediate and re-issue all workload certs. [Likely] Most teams discover during the incident that they can't.

**IR-06 Logs needed for forensics are retained long enough.** Flow logs and DNS logs for at least 90 days hot and a year cold, while detection of a breach often takes longer than the retention.

## Q. Capacity, performance, and network gotchas

**CAP-01 NAT port exhaustion is monitored.**
- [Certain] Cloud NAT allocates a limited number of ports per VM, and GKE pods behind one node share them.
- [Likely] The default minimum is small. Exhaustion shows up as random connection timeouts to external APIs.
- Alert on dropped-connection metrics, and size ports per VM from the busiest workload.

**CAP-02 Conntrack table is sized and monitored** on Docker hosts and K8s nodes, and per-service connection limits are set. [Certain] A full conntrack table drops new connections silently.

**CAP-03 DNS capacity.**
- [Certain] Kubernetes defaults to `ndots:5`, so one lookup turns into several queries.
- Use NodeLocal DNSCache (or equivalent), tune ndots per workload, and alert on SERVFAIL and latency.
- DNS failure presents as "the network is down."

**CAP-04 MTU is documented for every path.**
- [Likely] Overlays, WireGuard, VPN, and GCP's default MTU differ, and a mismatch causes hangs on large payloads while small requests work.
- Test: a don't-fragment ping at the MTU across every segment pair.

**CAP-05 Idle timeout alignment.** Idle timeouts differ between load balancer, NAT, firewall conntrack, proxy, and application. [Likely] The shortest one wins and kills long-lived connections (database pools, gRPC streams, websockets). Set TCP keepalives below the smallest timeout.

**CAP-06 Mesh and proxy overhead is measured,** not assumed. Record added p99 latency and CPU per sidecar or node, and set a budget.

**CAP-07 IP address capacity.** Plan pod, service, and node ranges for 3 to 5 years of growth. [Certain] You can't resize some GKE ranges easily. Alert at 70% utilization.

**CAP-08 DDoS posture is explicit.**
- L3/L4: provider protection (Cloud Armor, Cloud Load Balancing).
- L7: rate limits, bot rules, WAF, and caching.
- Know your costs under attack (autoscaling bill) and set a max replica ceiling.
- Test with a load test that exceeds your expected peak by 5x in staging.

## R. The pipeline is part of the network

**PIP-01 The compiler and CI runners are the most privileged network actors you have.** Whoever can change `policy/` or the compiler can open the whole network.
- Runners live in their own segment with no route to prod data.
- Deployment uses a pull-based GitOps agent, not push from CI.
- Branch protection, signed commits, and two reviewers on `policy/`.

**PIP-02 Terraform and state are protected.** [Certain] State files contain secrets and full topology. Use remote state in a locked bucket with versioning, restricted access, and no local state. Apply identity is a dedicated service account with least privilege per environment.

**PIP-03 Pipeline credentials are short-lived** (workload identity federation, not exported keys). No long-lived cloud keys in CI.

**PIP-04 Drift response is defined.** Detection alone isn't enough. Decide per resource type whether drift auto-reverts or pages a human. [Likely] Auto-reverting everything can undo an emergency fix mid-incident, so add a time-boxed override label.

## S. Supply chain and admission

**SUP-01 Images come from one private registry, pulled over a private path.** Artifact Registry via Private Google Access. Public registries are mirrored, not pulled live.

**SUP-02 Only signed, scanned images run.** Binary Authorization or an equivalent (Cosign verification via Kyverno or Gatekeeper). Pin by digest, not tag.

**SUP-03 Admission policy enforces the network rules.** Reject, at admission time:
- Namespaces without a default-deny policy.
- `hostNetwork`, `hostPort`, privileged, `hostPath`, `NET_ADMIN`.
- Services of type `LoadBalancer` or `NodePort` outside the ingress segment.
- Missing `CONTRACT` reference labels.

**SUP-04 Block Service `externalIPs`.** [Certain] CVE-2020-8554 allows traffic interception through it, and the mitigation is admission policy or the `DenyServiceExternalIPs` plugin.

**SUP-05 Patch SLAs for network components.** Envoy, Squid, CoreDNS, the CNI, and the kernel have a defined time-to-patch (critical within 7 days, for example). [Likely] Proxies parse hostile input all day, so they are the most attractive targets.

## T. Kubernetes bypasses that NetworkPolicy doesn't cover

**K8S-01 `kubectl exec` and `port-forward` bypass network segmentation.** [Certain] They're governed by RBAC and the API server path, not NetworkPolicy. Restrict them in prod, require break-glass with audit logging, and alert on use.

**K8S-02 RBAC is part of network security.** A pod that can create pods, or edit NetworkPolicies, can undo your segmentation. [Certain] Deny workloads the ability to modify policies, services, or ingress.

**K8S-03 Node-level policy.** Protect kubelet (10250), the node's SSH, and node-to-node traffic with host firewall policy (Cilium host policies or GCP firewall rules).

**K8S-04 Control plane access is private and authorized.** Restrict the API endpoint to authorized networks or private endpoint only. [Certain] An open API server is a top-10 cloud exposure.

**K8S-05 Kube-proxy and policy scale.** [Likely] iptables-mode kube-proxy degrades with thousands of services. Dataplane V2 (eBPF) avoids that. Decide before you pass a few thousand services.

## U. Environments, regions, DR, outside connectivity

**ENV-01 Environments are isolated at the project/account level,** with separate VPCs, separate CAs, separate DNS zones, and no shared networking between prod and non-prod. [Likely] Most "staging reached prod" incidents come from shared peering or shared credentials.

**ENV-02 Peering is a trust decision.** [Certain] GCP VPC peering is non-transitive, which is good for segmentation but means hub-and-spoke needs explicit design. Each peering is a `flows.yaml` entry. Prefer Private Service Connect for service exposure over full-network peering.

**ENV-03 Third parties get an isolated entry.** Partner VPNs and SaaS connections terminate in a dedicated segment, with flows allowed only to named services, and their IP ranges recorded with an owner and contact.

**ENV-04 DR flows are declared in advance.** Replication, failover DNS, and cross-region paths exist in `flows.yaml` before you need them. Policy is identical in both regions, tested by a failover drill at least twice a year. [Likely] The DR region is where the firewall rules are most often missing.

**ENV-05 Data residency is a network rule.** If data must stay in a region, enforce it with org policy resource locations and by blocking cross-region flows, not by convention.

## V. External dependencies that can ruin you

**EXT-01 Registrar and DNS provider accounts are tier-0.** Registrar lock, MFA with hardware keys, no shared logins, and expiry monitoring. [Certain] A hijacked registrar account bypasses every control inside your network.

**EXT-02 Certificate transparency monitoring.** Alert on any certificate issued for your domains that you didn't request.

**EXT-03 Dependency map of third-party services** (identity provider, payment, email, CDN) with a plan for each outage. Your egress allowlist should be derived from this list.

## W. Detection beyond negative tests

**DET-01 Runtime detection at the workload.** Falco or Tetragon for unexpected outbound connections, shell in container, and raw socket use. [Likely] Network policy tells you what was blocked, while runtime detection tells you what a compromised process tried.

**DET-02 Canary assets.** Honeytoken credentials and a canary service in each segment that nothing legitimate touches. Any connection pages someone.

**DET-03 Exfil detection by volume baseline.** Alert when data-segment egress bytes or app-to-external bytes exceed a per-service baseline.

**DET-04 Policy coverage metric.** Track the percentage of workloads with a contract, with default-deny, and with mTLS. Report it weekly, and treat a drop as a regression.

**DET-05 Adversarial testing.** Quarterly: an internal red-team exercise with a compromised-pod starting point, and monthly chaos tests (remove a policy, expire a cert) in staging. [Likely] You learn more from these than from audits.

## X. Cost, compliance, ownership

**GOV-01 Network costs are budgeted.** Flow logs, NAT data processing, cross-zone and egress charges, and WAF requests can become large line items. Sample flow logs (for example 50% on busy subnets) but log denies at 100%. Alert on cost anomalies.

**GOV-02 Control mapping.** Map each rule ID to the framework control it satisfies (SOC 2, ISO 27001, PCI DSS if card data exists). Auditors want evidence, so each rule's test output is the evidence. Retain it.

**GOV-03 Ownership is named.** Every segment, flow, and component has an owner and a backup, on-call included. Orphaned policies are flagged.

**GOV-04 The secure path must be the easy path.** [Likely] If getting a flow approved takes two weeks, people will use `port-forward`, shared VMs, or a personal proxy. Set an SLA for flow approval (for example 1 business day) and give developers a self-service PR template.

**GOV-05 Documentation of intentional weaknesses.** Keep a risk register of accepted risks (FQDN-allowlist limits, shared platform exfil) with owner, review date, and compensating control.

---

## What I'd do first

1. [Likely] RLT-01, RLT-05, and IR-01, because the biggest early risk is breaking production or locking yourselves out.
2. AVL-01 and AVL-02, before you commit to short cert lifetimes.
3. PIP-01 and SUP-03, since the pipeline and admission policy are where one mistake opens everything.
4. DET-02 and DET-05, because they find what the rules missed.

The risk in treating this as one big checklist is that you'll add rules faster than you can test them. Each one is only real once its test exists, so I'd build the rule set in tiers, with a coverage metric (DET-04) showing which are enforced.

I haven't touched any repo. Do you want this combined with the earlier rules into one `.md` file with consistent IDs, or should I draft the fail-open/fail-closed table (AVL-01) first, since it forces decisions that shape the rest?