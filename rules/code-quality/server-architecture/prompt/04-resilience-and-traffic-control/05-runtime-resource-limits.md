---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_RESOURCE_TUNING"
agent_role: "Principal Systems Reliability Engineer & Container Runtime Auditor"
target_scope: "Cgroups, CPU Throttling, Memory Headroom, OOM Prevention & File Descriptor Limits"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Runtime Resource Limits Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Container-Aware CPU Concurrency Alignment
Runtime concurrency threads (e.g. Go `GOMAXPROCS`, Node.js UV thread pool, JVM `ActiveProcessorCount`) MUST explicitly align with the container CPU quota allocated by Kubernetes/cgroups (`/sys/fs/cgroup/cpu.max`). Over-scheduling across a smaller container CPU quota causes severe CFS kernel throttling and latency spikes.

Guardrail 2: Hard Memory Target & OOM Headroom Invariant
Application runtime memory targets MUST be configured strictly below the container cgroup memory limit (default: 80% of container limit) to account for off-heap buffers, thread stacks, TLS contexts, and GC spikes. An unhandled container OOM kill terminates the process instantly without executing graceful drain, flushing logs, or reporting exit codes.

Guardrail 3: File Descriptor Pre-Flight Verification
During Phase 1 boot, the process MUST inspect the OS file descriptor limit (`ulimit -n`). The limit MUST satisfy:
$\text{ulimit -n} \ge \text{Total Ingress Cap} + \text{Total Egress Cap} + \text{Internal DB Pools} + 256 \text{ (Safety Margin)}$.
If `ulimit -n` is insufficient, the service MUST fail fast at startup with exit code `5` rather than crashing during a peak traffic burst.

Guardrail 4: Zero Inline Comments Doctrine
Never write mid-function inline comments inside runtime tuning initializers. Document the cgroup and memory arithmetic in the file header docblock.

---

## 2. Resource Limits Contract

```yaml
resource_limits_contract:
  cpu:
    cgroup_detection: true
    overschedule_factor: 1.0 # 1 worker thread per cgroup quota core
  memory:
    max_runtime_memory_ratio: 0.80 # 80% allocated to heap/runtime, 20% OS/off-heap headroom
  file_descriptors:
    minimum_margin: 256
    enforce_preflight: true
  metrics:
    fds_open_gauge: "process_open_fds"
    fds_max_gauge: "process_max_fds"
    memory_usage_gauge: "process_resident_memory_bytes"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Kubernetes OOMKilled Container Exit Fix**: Configure runtime memory caps (e.g. `GOMEMLIMIT=800MiB` on a 1GiB container, or JVM `-XX:MaxRAMPercentage=75.0`). The garbage collector triggers aggressively *before* the Linux kernel cgroup OOM killer drops the pod.
2. **"Too Many Open Files" (EMFILE) Mid-Traffic Collapse Fix**: In Phase 1 startup, check `resource.getrlimit(resource.RLIMIT_NOFILE)`. If `soft_limit < required_fds`, attempt to raise it to the hard limit. If still below required capacity, abort startup with exit code `5`.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Check Cgroup v1/v2 Paths at Boot
Read `/sys/fs/cgroup/cpu.max` or `/sys/fs/cgroup/memory.max` during bootstrap to determine actual container boundaries.

### Instruction 2: Emit Startup Resource Logs
Log `{cpu_cores_detected, memory_limit_bytes, fds_limit}` in the Phase 0 bootstrap logger.
