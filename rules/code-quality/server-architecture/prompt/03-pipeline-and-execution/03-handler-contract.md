---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_HANDLER_CREATION"
agent_role: "Principal Software Engineer & API Interface Auditor"
target_scope: "Delivery Handlers, Context Propagation, Cancellation Cascade, Non-Blocking Invariants"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Handler Contract Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Uniform Handler Signature & Context Isolation
Every handler function MUST accept exactly two inputs:
1. **Request Context**: Cancellation signal, deadline timestamp, authenticated principal, W3C trace context, and route policy snapshot.
2. **Request Envelope**: HTTP method, typed route params, parsed query params, headers, and streaming body reader.
And return exactly one output: a typed buffered response or a typed chunked stream with explicit completion.

Guardrail 2: Downstream Cancellation Cascade Invariant
Handlers MUST propagate their context cancellation token to all downstream calls (database queries, external API clients, LLM completion calls). If a client disconnects, stream resets, deadline expires, or server drain occurs, all in-flight downstream paid API/LLM calls MUST abort immediately to prevent resource waste.

Guardrail 3: Socket Isolation Prohibition (Zero Direct I/O)
Handlers MUST NOT write directly to raw transport sockets, set low-level connection headers (`Connection: keep-alive`, `Transfer-Encoding`), or make socket reuse decisions. Protocol framing belongs strictly to the transport adapter.

Guardrail 4: Non-Blocking Event Loop Invariant
Handlers running on async event loops MUST NEVER execute synchronous blocking I/O (raw disk file reads, `time.sleep()`, synchronous network sockets) or long-running CPU calculations on the reactor thread. Heavy compute or blocking calls MUST be offloaded to a bounded worker thread pool.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside handler functions. Document the entire handler workflow and error mappings in the file header docblock.

---

## 2. Handler Execution Contract

```yaml
handler_interface_spec:
  inputs:
    context:
      cancellation_token: "Context | CancellationToken"
      deadline_utc: "datetime"
      principal: "PrincipalEntity"
      trace_context: "W3CTrace"
    request:
      method: "GET | POST | PUT | PATCH | DELETE"
      route_params: "Mapping[str, str]"
      query_params: "Mapping[str, list[str]]"
      headers: "Mapping[str, str]"
      body_stream: "AsyncIterator[bytes]"
  outputs:
    response:
      status_code: "integer"
      headers: "Mapping[str, str]"
      payload: "BufferedBytes | AsyncIterator[bytes]"
  forbidden_actions:
    - "Direct socket writes"
    - "Connection header manipulation"
    - "Blocking event loop threads"
    - "Ignoring context cancellation in child tasks"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Orphaned Expensive LLM Call Fix**: Pass the request cancellation context into the LLM SDK client. When `ctx.is_cancelled` triggers (e.g. user navigates away), immediately cancel the HTTP request stream to the LLM provider, saving token compute cost.
2. **Blocking Thread Pool Starvation Fix**: In Python/Node.js, wrap any mandatory legacy synchronous database calls with `asyncio.to_thread(func, *args)` or worker pools with a hard concurrency ceiling.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Check Context Cancellation in Loops
If a handler streams tokens or iterates over database cursors, check `ctx.is_cancelled` on every iteration and break immediately if canceled.

### Instruction 2: Route Exceptions to Domain Errors
Never allow unmapped driver exceptions (e.g. `psycopg2.OperationalError`) to escape from handlers; map them to standard domain errors caught by the outer pipeline wrapper.
