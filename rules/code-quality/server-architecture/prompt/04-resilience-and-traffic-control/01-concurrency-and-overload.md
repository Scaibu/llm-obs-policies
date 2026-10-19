---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_CONCURRENCY_TUNING"
agent_role: "Principal Performance Architect & Overload Protection Officer"
target_scope: "Admission Limits, Little's Law, Priority Shedding, Queue Bounds & Thread Isolation"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Concurrency and Overload Protection Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Universal Bounded Queues & Pools Invariant
Every worker pool, event loop queue, and buffer MUST have an explicit, hard ceiling. Unbounded in-memory queues (`asyncio.Queue()`, channel without capacity) are strictly prohibited.

Guardrail 2: Little's Law Admission Limit ($L = \lambda \times W$)
Admission concurrency MUST be bounded based on throughput and latency goals:
$\text{Static Ceiling} = (\text{Target Req/s} \times \text{P99 Latency Seconds}) \times 1.5 \text{ (Headroom)}$.
Requests exceeding this ceiling MUST be shed immediately with HTTP 503 + `Retry-After: 1`.

Guardrail 3: Priority-Class Shedding Hierarchy
When total concurrency exceeds 80% of capacity, shedding MUST execute in strict priority order:
`Best-Effort / Analytics` $\rightarrow$ `Normal User Traffic` $\rightarrow$ `Critical / Financial Mutations`.
Critical health checks and admin probes MUST NEVER be shed.

Guardrail 4: Queue Expiry Drop (Never Execute Stale Work)
Queued requests MUST check remaining deadline upon dequeuing: if `time_in_queue \ge remaining_request_deadline`, the request MUST be dropped immediately with HTTP 504 `DEADLINE_EXCEEDED` without executing domain logic. Under sustained overload, the queue MUST switch to LIFO to process fresh requests and drop expired tail traffic.

Guardrail 5: Admin & Diagnostics Thread Isolation
Admin listeners (`/healthz`, `/metrics`, `/ready`) MUST run on a dedicated thread pool or distinct event loop isolated from the public request processing pool. Public traffic saturation MUST NEVER starve admin probes.

Guardrail 6: Zero Inline Comments Doctrine
Never write mid-function inline comments inside concurrency controllers. Document the queue discipline and shedding math in the file header docblock.

---

## 2. Concurrency & Overload Contract

```yaml
concurrency_contract:
  admission:
    static_limit: 500
    algorithm: "AIMD_GRADIENT" # STATIC | AIMD_GRADIENT
    shed_status_code: 503
    retry_after_seconds: 1
  queue:
    max_depth: 200
    max_queue_wait_ms: 1000
    discipline_normal: "FIFO"
    discipline_overload: "LIFO_CODEL"
  priority_classes:
    critical: { concurrency_share: 0.50, min_guaranteed: 50 }
    normal: { concurrency_share: 0.35, min_guaranteed: 20 }
    best_effort: { concurrency_share: 0.15, min_guaranteed: 0 }
  thread_isolation:
    admin_thread_pool_size: 4
    blocking_io_pool_size: 64
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Queue Tail Drop Latency Spike Fix**: Check `deadline` immediately upon taking a request off the queue. If expired, return HTTP 504 without calling downstream DB or LLM services.
2. **Cascading Load Collapse Fix**: When server utilization hits 95%, immediately shed `best_effort` routes by returning HTTP 503 with header `Retry-After: 5`. This stabilizes CPU and memory for `critical` routes.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Use Unbounded Channels
Always pass an explicit integer buffer size when initializing channels or queues.

### Instruction 2: Isolate Public and Admin Runtime Schedulers
Ensure the Uvicorn/Netty admin server is configured on a separate listening thread group.
