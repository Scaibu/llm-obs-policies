---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_DRAIN_SEQUENCE_CREATION"
agent_role: "Principal Systems Reliability Engineer & Graceful Shutdown Auditor"
target_scope: "SIGTERM Handling, Propagation Wait, Connection Draining, HTTP/2 GOAWAY & LIFO Unwind"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Drain Sequence Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Strict Six-Step Sequential Drain
Upon receiving `SIGTERM` or shutdown signal ($t_0$), shutdown MUST execute in exact linear order:
1. **$t_0$**: Flip readiness to `false` (informs Kubernetes endpoint slice controller).
2. **$t_0 \rightarrow t_0 + P$**: **Propagation Wait** ($P$, default: 2000ms). Keep serving incoming traffic normally to allow upstream load balancers to asynchronously remove the node from rotation.
3. **$t_0 + P$**: Stop accepting new TCP connections (close listening socket).
4. **$t_0 + P$**: Signal existing connections:
   - HTTP/1.1: Attach `Connection: close` to all in-flight responses; close idle sockets immediately.
   - HTTP/2: Issue initial `GOAWAY` with $\text{last\_stream\_id} = 2^{31}-1$, wait 1 RTT, then issue second `GOAWAY` with actual last stream ID (RFC 9113 §6.8).
   - WebSockets: Send close frame `1001 Going Away`.
5. **$t_0 + P \rightarrow t_0 + P + D$**: **Drain In-Flight Requests** ($D$, default: 15s) until all active handlers complete.
6. **$t_0 + P + D$**: Cancel remaining contexts; pop started components stack in reverse LIFO order.

Guardrail 2: Mathematical Shutdown Window Invariant
The sum of all shutdown phases MUST be strictly less than the orchestrator kill deadline:
$P \text{ (Propagation)} + D \text{ (Drain)} + F \text{ (Force Cleanup Margin)} < \text{Orchestrator SIGKILL Timeout}$.

Guardrail 3: Zero Inline Comments Doctrine
Never write mid-function inline comments inside drain handlers. Document the shutdown timelines and protocol teardown mechanics in the file header docblock.

---

## 2. Drain Sequence Contract

```yaml
drain_contract:
  propagation_wait_ms: 2000
  drain_deadline_ms: 15000
  force_cleanup_margin_ms: 3000
  orchestrator_sigkill_ms: 30000
  http2_drain:
    initial_goaway_id: 2147483647 # 2^31 - 1
    rtt_pause_ms: 100
  websocket_drain_code: 1001
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **502 Bad Gateway During Kubernetes Rolling Deploy Fix**: Introduce the 2000ms `propagation_wait`. When Kubernetes sends `SIGTERM`, kube-proxy and Ingress take up to 2 seconds to update iptables. Serving during this gap eliminates dropped requests.
2. **HTTP/2 Graceful Teardown Race Fix**: Implement the two-step `GOAWAY` sequence. The first frame alerts the client to stop creating streams; the second frame defines the final processed stream boundary without resetting in-flight streams.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Close Listening Socket at $t_0$
Do not close public listeners immediately upon receiving `SIGTERM`; execute `propagation_wait` first.

### Instruction 2: Unwind in Strict LIFO Order
Pop components off the `started_stack` in reverse order so storage and databases remain open until all workers complete.
