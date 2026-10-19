---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_DIAGNOSTICS_SETUP"
agent_role: "Principal Systems Infrastructure Engineer & Host Observability Auditor"
target_scope: "Kernel Checklist, Socket Buffers, Ephemeral Ports, Conntrack & Profiling Endpoints"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Host and Diagnostics Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Host Kernel Parameter Logging at Startup
During Phase 0 bootstrap, the server MUST inspect and log the effective values of critical host kernel settings:
- `somaxconn` (effective socket accept backlog).
- `net.netfilter.nf_conntrack_max` (connection tracking table limit).
- `ip_local_port_range` (ephemeral port budget).
- Process and system-wide file descriptor ceilings (`ulimit -n`, `fs.file-max`).

Guardrail 2: Diagnostic & Profiling Isolation
Runtime profiling endpoints (pprof, heap dumps, CPU flamegraphs, thread dumps) MUST ONLY listen on the private admin listener (`127.0.0.1` or internal mesh). Exposing pprof or heap dumps to public ingress ports is strictly prohibited.

Guardrail 3: Low-Overhead Continuous Profiling
If continuous profiling is enabled, sampling overhead MUST NOT exceed 2% of total CPU utilization. Continuous allocation profiling must sample on byte thresholds rather than hooking every object allocation.

Guardrail 4: Zero Inline Comments Doctrine
Never write mid-function inline comments inside diagnostics controllers. Document the host parameter checklists in the file header docblock.

---

## 2. Host Diagnostics Contract

```yaml
host_diagnostics_contract:
  kernel_requirements:
    min_somaxconn: 2048
    min_file_descriptors: 65536
    min_conntrack_max: 131072
  admin_profiling:
    enabled: true
    bind_interface: "127.0.0.1"
    auth_required: true
    allowed_endpoints:
      - "/debug/pprof/profile"
      - "/debug/pprof/heap"
      - "/debug/pprof/goroutine"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **NAT Gateway Ephemeral Port Exhaustion (EADDRNOTAVAIL) Fix**: When running high-throughput outbound clients, verify host ephemeral port range (`cat /proc/sys/net/ipv4/ip_local_port_range`). Ensure range is expanded (e.g. `10240 65535`) and enable TCP socket reuse (`tcp_tw_reuse = 1`).
2. **Conntrack Table Dropping Packets Fix**: Check `/proc/sys/net/netfilter/nf_conntrack_count` against `nf_conntrack_max`. If usage exceeds 80%, log a critical alert before the kernel begins silently dropping inbound TCP packets.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Expose Pprof on Public Router
Ensure profiling handlers are registered strictly on `admin_router` and never included in `public_router`.

### Instruction 2: Log Effective Limits on Boot
Print a startup summary table of detected host parameters in Phase 0.
