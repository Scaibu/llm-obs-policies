## 1. The decision before the design: build, wrap, or delegate

 Your first decision is how much of the protocol stack you own. The design only applies to the layers you keep.

| Option | You own | You delegate | When it's right |
|---|---|---|---|
| **A. Proxy at the edge** (Envoy, NGINX, HAProxy, or a cloud LB) + your server inside | Pipeline, handler, lifecycle, internal codec | TLS termination, HTTP/2 and HTTP/3 parsing, smuggling defense, connection floods |  Any internet-facing server. This is the default. |
| **B. Your language runtime's mature server** (Go `net/http`, Netty, Kestrel, Tomcat) with your pipeline on top | Pipeline, policy, lifecycle wiring | Framing and codec correctness | Internal services, or the edge server when you can't run a proxy |
| **C. Your own codec** | Everything | Nothing |  Only for a custom binary protocol or extreme specialization. Never for HTTP on the open internet. |

 HTTP/1.1 request smuggling, HTTP/2 Rapid Reset (CVE-2023-44487), and the 2019 HTTP/2 flood family (CVE-2019-9512 through 9518) all hit mature, heavily reviewed implementations. A new codec will have the same classes of bug with fewer people looking for them.

**I disagree with building a public HTTP codec from scratch because** the security surface is huge and has nothing to do with your product. **Here's what I'd do instead:** Option A for the public server and Option B for the admin and internal servers. Treat the "codec" in this design as an *adapter* over a proven implementation. **The risk in building your own is** a smuggling or flood vulnerability that a fuzzer or attacker finds before you do.

Everything below still applies under Option A or B. The limits, timeouts, lifecycle, and pipeline remain your responsibility. Only the framing work moves elsewhere.

---

## 2. Normative conventions

- MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY follow RFC 2119 as clarified by RFC 8174 (IETF): they carry normative force only when written in capitals.
- HTTP semantics follow RFC 9110. HTTP/1.1 messaging follows RFC 9112. HTTP/2 follows RFC 9113. HTTP/3 follows RFC 9114 (all IETF).
- TLS follows RFC 8446 (TLS 1.3) and RFC 9325 / BCP 195 (IETF) for secure configuration.
- Error bodies follow RFC 9457, Problem Details for HTTP APIs (IETF).
- Trace propagation follows W3C Trace Context (W3C Recommendation).
- Metrics naming follows the OpenTelemetry HTTP semantic conventions (CNCF).
- The config schema uses JSON Schema 2020-12 (json-schema.org). Cross-field rules use CEL (Common Expression Language, maintained by Google).

---

## 3. The components and their contracts

 The previous five parts were right but incomplete. Two concerns had no owner: client identity resolution and the policy derived from configuration.

| Part | Job | Inputs | Outputs | MUST NOT know |
|---|---|---|---|---|
| **Listener** | Bind, accept, apply socket options | Bind config, TLS provider | Raw connections | Protocols, routes |
| **Connection manager** | Registry, caps, timeouts, age, drain signalling | Raw connections, limits | Admitted connections | Request contents |
| **Protocol codec (adapter)** | Bytes ↔ requests and responses; enforces framing limits | Admitted connections | Request streams | Business logic |
| **Peer resolver** *(new)* | Determine the real client address and transport identity | Socket peer, trusted proxy list, PROXY protocol, mTLS certificate | Peer identity | Routes |
| **Request pipeline** | Ordered policy chain around the handler | Request, route table, policy | Response or rejection | Which service it fronts |
| **Policy snapshot** *(new)* | Immutable, validated view of config, swapped atomically on reload | Config | Read-only policy | Runtime state |
| **Lifecycle controller** | State machine, health, drain orchestration | Signals, child states | Readiness and liveness | Everything else |

**Invariants:**
-  Each part depends only on the interfaces of its neighbours. If a change to one part's internals forces a change in another, the boundary is in the wrong place.
-  Policy is read through an immutable snapshot. Reloading swaps the snapshot pointer. A request in flight keeps the snapshot it started with, so no request ever sees half of an old config and half of a new one.

---

## 4. Construction, step by step

### Step 1: The server as a component

-  The constructor MUST only store config and references. It MUST NOT bind sockets, start threads, or perform I/O.
- It MUST implement the shared component contract: `start`, `stop`, `health`.
- The config schema (JSON Schema 2020-12) MUST include: name, bind address, protocol set, trusted proxies, limits, timeouts, TLS mode, pipeline policies, drain settings, and health settings.
- Cross-field validation (CEL) MUST run during the config phase, before `start`. Examples:
  - `header_timeout < idle_timeout`
  - `drain_deadline + propagation_wait < process_shutdown_deadline`
  - `idle_timeout > upstream_lb_idle_timeout` (corrected rule, E1)
  - `public.bind != admin.bind`
  - `route.max_body <= codec.max_body` for every route
  - `max_connection_age_grace >= longest_expected_stream`, or long streams are explicitly exempt
-  A validate-only mode MUST be able to run the full validation without opening any port.

### Step 2: The listener

- Bind happens inside `start`. The listener MUST report its actual bound address so tests can bind port 0 and discover the real port.
- Socket options MUST be explicit, not inherited defaults:
  - Address reuse, so a fast restart doesn't fail on sockets in `TIME_WAIT`.
  -  Port reuse across processes (`SO_REUSEPORT` on Linux) only if you deliberately want kernel-level load balancing across processes or zero-downtime restarts. It changes failure behaviour, so it's opt-in.
  - Accept backlog sized deliberately.  The kernel silently caps it (`net.core.somaxconn` on Linux), so the effective value MUST be logged at startup.
  - TCP keepalive on, with intervals shorter than any NAT or firewall idle timeout on the path.
  - [Guessing] `TCP_NODELAY` on for request/response traffic. Measure before changing it for bulk streaming.
- **TLS:**
  - Minimum version TLS 1.2 per RFC 9325. TLS 1.3 preferred.
  - Protocol negotiation via ALPN (RFC 7301).  HTTP/2 over TLS requires ALPN.
  - Certificates come from a reloadable provider. A reload MUST be atomic, MUST validate the new certificate and key before swapping, and MUST keep the old pair if the new one fails. Seconds until expiry MUST be exported as a metric.
  -  TLS 1.3 0-RTT early data is replayable (RFC 8446 §8). Keep it disabled unless you enforce idempotency and answer replays with 425 Too Early (RFC 8470).
  - With mutual TLS, the client identity MUST come from the certificate's SAN (for example a SPIFFE ID), never from the Common Name.
- **Bind failure** is fatal at startup. The error MUST name the address, the protocol, and the operating-system cause.
- **Accept loop resilience:**
  -  Transient errors (`EMFILE`, `ENFILE`, `ENOBUFS`, `ECONNABORTED`) MUST trigger a capped exponential backoff, not an exit. Go's standard library backs off from 5 ms to 1 s for exactly this reason.
  -  Keep one reserved file descriptor. When you hit the descriptor limit, release it, accept the pending connection, close it immediately, and re-reserve. Otherwise the backlog fills with connections you can never service.
  - The accept loop MUST NOT run handler work.

### Step 3: The connection manager

**Caps**

| Cap | Purpose | Over-limit behaviour (pick one and document it) |
|---|---|---|
| Total connections | Bound memory and file descriptors | See the table below |
| Per resolved client | Stop one client monopolizing capacity | Accept, then close. Log the reason. |
| Per client TLS handshakes per second |  Handshakes cost far more CPU than requests | Close before the handshake completes |
| HTTP/2 concurrent streams per connection | Multiplexing amplification | Refuse with `REFUSED_STREAM`, which tells the client the request was never processed and is safe to retry |

**Choosing the over-limit behaviour.**  At the connection level you can't send an HTTP status until you've accepted the connection. Each option is a trade-off:

| Option | Client sees | Cost to you | Use when |
|---|---|---|---|
| Stop accepting; let the backlog fill | Connect timeout | Zero | Never as the primary mechanism. It's slow, opaque, and looks like a network fault. |
| Accept, then close immediately | Connection reset | One accept | Hard caps, attack traffic |
| Accept, reply 503 with `Retry-After`, then close | A clear, retryable signal | Accept + parse + write | Soft caps for well-behaved clients |

**Timeouts.** Every one of these MUST exist, and each must be enforceable on its own:

| Timeout | Defends against | Notes |
|---|---|---|
| TLS handshake | Half-open TLS floods | Short |
| Header read (time to complete all headers) | Slowloris |  Measured from the first byte, not reset by each new byte |
| Body read, or minimum data rate | Slow POST (R.U.D.Y.) |  Prefer a minimum bytes-per-second rate over a fixed duration, because legitimate uploads vary in size |
| Idle between requests | Pool exhaustion | MUST be longer than any upstream LB's idle timeout (E1) |
| Write timeout, or minimum drain rate | Slow readers holding buffers | Applies per write, not per response, so large streamed responses aren't killed |
| Max connection age | Sticky connections after scaling; credential rotation | Jittered (for example ±10%), plus a grace period. gRPC exposes this as `MAX_CONNECTION_AGE` and `MAX_CONNECTION_AGE_GRACE`. |
| Handler deadline | Runaway work | Owned by the pipeline (stage 10), not the connection manager |

**Registry.**  Live connections MUST be tracked with their state (active or idle), age, peer, and protocol. Without this you cannot drain, cannot find leaks, and cannot answer "who is holding connections right now?"

### Step 4: The protocol codec (as an adapter)

The interface is one codec contract with HTTP/1.1, HTTP/2, gRPC, and framed TCP behind it. Streaming is the base model; full buffering is an opt-in optimization per route.

**HTTP/1.1: framing integrity (RFC 9112)**

-  A message with both `Transfer-Encoding` and `Content-Length`: `Transfer-Encoding` takes precedence. The server MUST treat the message as suspect and close the connection after responding. This is the main defense against request smuggling.
-  Multiple `Content-Length` values that differ MUST be rejected with 400.
-  Whitespace between a header name and the colon MUST be rejected with 400 (RFC 9112 §5.1).
-  Obsolete line folding, bare CR, and NUL bytes in headers MUST be rejected.
-  A missing or duplicate `Host` header MUST be rejected with 400.
- After any framing error, the connection MUST close, because the parser can no longer trust where the next request starts.
- `Expect: 100-continue` (RFC 9110 §10.1.1): send 100 Continue only *after* authentication and size checks pass. Otherwise you invite the client to upload a body you're about to reject.

**HTTP/2: resource-exhaustion classes that MUST be bounded (RFC 9113 plus advisories)**

| Attack | Mechanism | Required limit |
|---|---|---|
| Rapid Reset (CVE-2023-44487)  | Open a stream, cancel it immediately, repeat. Server work outlives the stream. | Count reset streams against a per-connection budget. Send GOAWAY when the reset rate exceeds the threshold. |
| CONTINUATION flood (CERT VU#421644, 2024)  | Endless CONTINUATION frames without END_HEADERS | Cap total header bytes across HEADERS + CONTINUATION. Close when exceeded. |
| HPACK bomb  | A small compressed header expands into a huge decoded one | Enforce `SETTINGS_MAX_HEADER_LIST_SIZE` on the *decoded* size. Bound the dynamic table size. |
| Ping, settings, and empty-frame floods (CVE-2019-9512, 9515, 9518)  | Control frames that force responses or work | Per-connection rate limit on control frames |
| Internal data buffering (CVE-2019-9517)  | Client opens a window but never reads | Bound per-stream and per-connection output buffers. Honour the write timeout. |
| Stream concurrency | Many streams per connection | `SETTINGS_MAX_CONCURRENT_STREAMS`.  RFC 9113 recommends no less than 100. Lower is acceptable for expensive handlers. |

**Every protocol**
- Header bytes, header count, body bytes, and frame size have codec-wide **ceilings**. Per-route limits (stage 5) can be tighter, never looser.
- Malformed input gets a protocol-correct error: 400 for HTTP/1.1; stream or connection errors for HTTP/2 according to the RFC's classification.

### Step 5: The request pipeline (corrected order)

**Principle:**  Order stages by increasing cost and increasing knowledge. A request is never charged for expensive work if a cheaper check would have rejected it.

**Outermost wrapper** (encloses all stages):
- An error boundary. Any unhandled failure becomes a 5xx for *that* request only. It never kills the connection loop or the process. It records the failure with the request ID.
- The response envelope. Every rejection, including rejections from stage 1, uses RFC 9457 Problem Details with a stable `type` URI for each rejection reason.
- Metrics and access logs, so rejections are measured exactly like successes.

**Stages**

| # | Stage | Cost | Rejects with | Notes |
|---|---|---|---|---|
| 1 | **Request identity** | Trivial | — | Generate a request ID. Accept inbound `traceparent` (W3C) only from trusted hops, and validate its format.  Client-supplied IDs that are logged unvalidated enable log injection and correlation spoofing. |
| 2 | **Peer resolution** | Trivial | 400 on malformed forwarding headers from a trusted hop | Use `Forwarded` (RFC 7239), `X-Forwarded-For`, or PROXY protocol v2, and **only** from addresses on the trusted-proxy list. Walk the chain from the right; stop at the first untrusted hop. |
| 3 | **Global admission (load shedding)** | Trivial | 503 + `Retry-After` | In-flight concurrency limit (Step 7).  It must sit this early, because shedding after authentication still burns CPU on the requests you drop. |
| 4 | **Route resolution** | Cheap, pure | 404 / 405 | Produces the route policy: auth requirement, limits, timeout, priority class, idempotency. Unknown methods are normalized. |
| 5 | **Per-route ingress limits** | Cheap | 413, 415, 431 | Content type allowlist, tighter body ceiling. The body is not read yet. |
| 6 | **Pre-auth rate limit** (by resolved peer) | Cheap | 429 + `Retry-After` (RFC 6585) | Protects stage 7 from credential stuffing and from handshake-cost attacks |
| 7 | **Authentication** | Expensive | 401 + `WWW-Authenticate` | Header-only.  MUST NOT read the body. Cache token verification results within their validity window. |
| 8 | **Coarse authorization** | Cheap | 403 | Route-level scope or role. Resource-level checks stay in the handler. |
| 9 | **Per-identity quota** | Cheap–medium | 429 | Keyed by authenticated principal, not by IP address |
| 10 | **Deadline computation** | Trivial | 504, or fail fast | Budget = min(route maximum, inherited deadline − safety margin).  If the remaining budget is below the route's minimum viable time, reject immediately instead of starting work that cannot finish. Inherited deadlines (`grpc-timeout`, or a custom header) are **capped**, never trusted outright. |
| 11 | **Priority admission** | Trivial | 503 | Per-class concurrency. Under pressure, lower classes are shed first. |
| 12 | **Handler** | Unbounded | — | In your architecture, the handler is the router, which forwards to services. |

**Retry signalling.**  Every rejection MUST tell the client whether a retry is safe:
- 503 and 429 carry `Retry-After`.
- HTTP/2 `REFUSED_STREAM` means the request was not processed.
- A request that may have been partially processed MUST NOT be described as safely retryable unless its method is idempotent (RFC 9110 §9.2.2) or it carries an idempotency key.

 Without this, client retries during overload multiply load, and the overload turns into a retry storm.

### Step 6: The handler interface

- Input: a request context (deadline, cancellation, principal, trace context, policy snapshot) and a request with a streaming body.
- Output: a response, either buffered or streamed.
-  **Cancellation must flow both ways.** Client disconnect, stream reset, or deadline expiry cancels the context. Downstream work MUST observe the cancellation. For LLM or other paid upstream calls, abandoning the call when the client has left is direct cost control.
- The handler MUST NOT write to the socket directly, set connection-level headers, or decide connection reuse. Those belong to the codec.

### Step 7: The concurrency model

-  Whatever model you choose (event loop, thread pool, worker pool, or hybrid), every queue and pool is **bounded**.
-  Little's Law: L = λ × W. Average in-flight requests equal arrival rate times average latency. Example: 2,000 req/s × 0.05 s = 100 in flight on average. A static limit of 100 is correct only while latency stays at 50 ms. If a dependency slows to 500 ms, the same traffic needs 1,000 slots, so a static limit either rejects healthy traffic or admits a pile-up.
-  For that reason, the admission limit SHOULD be **adaptive**: a gradient or AIMD limiter that tracks latency and shrinks the limit as latency rises. Netflix's concurrency-limits library is a public reference design. Start with a static limit and move to adaptive once the overload test shows it is needed.
- **Queue discipline:**
  - Bounded size *and* bounded time-in-queue.
  -  A request that waited longer than its deadline allows MUST be dropped before execution, never executed late.
  -  Under sustained overload, LIFO with CoDel-style queue-time checks (described publicly by Facebook) gives better outcomes than FIFO, because FIFO serves the requests most likely to have already timed out on the client side.
-  Blocking work MUST NOT run on threads that accept connections, parse protocols, or run the event loop.
-  The admin server gets its own small, separate pool, so overload on the public server cannot hide your diagnostics.

### Step 8: The lifecycle state machine

| State | Meaning | Readiness | Liveness |
|---|---|---|---|
| Created | Constructed, inert | No | Yes |
| Starting | Binding, loading certs, warming | No | Yes |
| Serving | Accepting and handling | Yes | Yes |
| Draining | No new work; finishing in-flight | **No** | **Yes** |
| Stopped | Everything closed | No | — |

**Transitions**
- `start` returns only once the listener is bound and accepting. Readiness turns on only after `start` succeeds.
- Failures in the serve loop go to the single fatal channel owned by `main`. They MUST NOT be swallowed or logged and forgotten.
- `stop` is idempotent, safe on a server that never started, and safe while `start` is still running.

**Liveness vs. readiness** 
- **Liveness** answers "is this process able to make progress?" For example: the event loop isn't wedged. It MUST NOT check downstream dependencies. If it does, one database outage restarts your entire fleet, and the restarts make the outage worse.
- **Readiness** answers "should traffic be sent here now?"  Gate readiness only on local, critical prerequisites. If every replica goes unready when a shared dependency fails, the platform removes all of them and a partial outage becomes a total one. Prefer staying ready and returning degraded responses.
- Expose both via the gRPC Health Checking Protocol (`grpc.health.v1`) for gRPC, and plain HTTP endpoints on the **admin** listener for everything else.

**Drain sequence (the most frequently botched part)**

1. Receive the termination signal (for example SIGTERM).
2. Turn readiness off.
3. **Keep serving normally** for the propagation interval.  On Kubernetes, endpoint removal and SIGTERM happen at the same time, not in order. Load balancers keep sending traffic for some seconds. A `preStop` delay or an in-process wait covers that gap.
4. Stop accepting new connections.
5. Signal existing connections to finish:
   - HTTP/1.1: send `Connection: close` on in-flight responses; close idle connections immediately.
   -  HTTP/2 and gRPC: two-phase GOAWAY (RFC 9113 §6.8). First send GOAWAY with last-stream-ID 2³¹−1, wait at least one round trip, then send GOAWAY with the true last stream ID. A single GOAWAY can strand requests already in flight on the wire.
   - WebSocket: close frame with status 1001 Going Away (RFC 6455 §7.4.1).
   - Server-sent events: end the stream; clients resume with `Last-Event-ID`.
6. Wait for in-flight work, up to the drain deadline.
7. Cancel the contexts of whatever remains, wait briefly for handlers to observe the cancellation, then force-close.
8. Turn the state to Stopped and release the listener.

**Budget rule:**  propagation wait + drain deadline + force-close margin MUST be less than the platform's hard kill timeout (`terminationGracePeriodSeconds` on Kubernetes). Validate this in config (Step 1).

### Step 9: Observability

**Metrics**, following the OpenTelemetry HTTP semantic conventions:
- `http.server.request.duration`: a **histogram** in seconds.  Percentiles cannot be averaged across instances; histograms can be aggregated.
- `http.server.active_requests`, plus connection counts by state, queue depth, and queue wait time.
- A rejection counter labelled with a **closed** set of reasons: `admission`, `rate_limit`, `quota`, `header_timeout`, `body_rate`, `header_too_large`, `smuggling_suspect`, `h2_reset_budget`, `auth`, `authz`, `deadline_unviable`, and so on.
- TLS: handshake failures by reason, and seconds until certificate expiry.
- Lifecycle: current state, drain duration, and connections force-closed at shutdown.

**Cardinality** 
- Use `http.route` (the pattern), never the raw path.
- Normalize methods to the known set; everything else becomes `_OTHER`, as the OpenTelemetry conventions specify.
- Never use user IDs, tenant IDs, or request IDs as metric labels. They belong in logs and traces.

**Logs**
- Structured, with request ID, trace ID, route, resolved peer, principal, status, duration, and rejection reason.
-  Access logs are themselves a source of overload. Under pressure, sample successful requests but keep 100% of errors and rejections.

**Method:** RED (rate, errors, duration) per route; USE (utilization, saturation, errors) per resource: connections, workers, queue, file descriptors.

---

## 5. Parameters you must expose

[Guessing] The starting values below come from widely used defaults and common practice, not from your traffic. Treat them as a place to start your overload and drain tests, never as tuned values.

| Concern | Parameter | Conservative starting point |
|---|---|---|
| Header read | header timeout | 10–20 s |
| Body upload | minimum body rate | Roughly 1 KB/s after a short grace period |
| Keep-alive | idle timeout | Upstream LB idle + 5–15 s (ALB defaults to 60 s, so about 65–75 s) |
| Connection age | max age / grace / jitter | 5–30 min / longest stream / ±10% |
| Header size | max header bytes | 16–64 KiB |
| Header count | max headers | ~100 |
| Body size | codec ceiling | Largest legitimate upload; routes tighten it |
| HTTP/2 streams | max concurrent streams | 100 |
| Concurrency | in-flight limit | Little's Law × 1.5 headroom, then adaptive |
| Queue | size / max wait | Small / below the shortest route deadline |
| Shutdown | propagation / drain | 5–15 s / longest normal request |
| Exposure | bind address | Admin on loopback or a private network only |

Every parameter MUST have a safe default, a JSON Schema type and range, and any cross-field CEL rule that applies to it.

---

## 6. Failure modes that cause real incidents

| Mistake | Consequence |
|---|---|
| Binding in the constructor | Validate-only runs open ports; parallel tests collide |
| No header read timeout | Slowloris holds connections forever |
| No minimum body rate | Slow POST exhausts the connection cap |
| Unbounded body buffering | One large upload exhausts memory |
| Unbounded worker queue | Latency grows without limit, then the server collapses |
| FIFO queue under overload | Server burns capacity on requests the client already gave up on |
| Static concurrency limit | Either rejects healthy traffic or admits pile-ups when latency shifts |
| Ready before accepting | Traffic sent to a server that refuses it |
| No propagation wait on shutdown | 502s on every deploy |
| Single-phase HTTP/2 GOAWAY | Requests in flight on the wire are dropped |
| Handler failure kills the loop | One bad request takes the process down |
| **Server idle timeout shorter than the LB's** (corrected E1) | Intermittent 502s on reused connections |
| Admin endpoints on the public listener | Health, debug, and reload exposed to the internet |
| Liveness checks dependencies | One dependency outage restarts the fleet |
| Per-IP limits behind a proxy without peer resolution | Entire user base throttled as one client |
| Trusting `X-Forwarded-For` from any source | Attackers spoof their address to evade limits |
| Accepting client trace IDs unvalidated | Log injection, broken trace correlation |
| No Rapid Reset budget | Small HTTP/2 client floods server CPU |
| Accepting CL+TE conflicts | Request smuggling past the proxy's security controls |
| Sending 100 Continue before auth | Server invites uploads it will reject |
| Ignoring client disconnect | Work continues for nobody; with LLM calls it costs money |
| Rejections without retry semantics | Overload turns into a retry storm |
| Unjittered connection age | Synchronized reconnect herds |
| Raw paths as metric labels | Cardinality explosion in the metrics backend |

---

## 7. Verification, with pass criteria

| # | Test | Pass criterion |
|---|---|---|
| 1 | Lifecycle | Start on port 0, discover the address, stop. No leaked ports, threads, tasks, or file descriptors. Calling `stop` twice and `stop` before `start` both succeed. |
| 2 | Config validation | Every documented invalid combination is rejected in validate-only mode, with no port opened. Property-based generation of configs finds no accepted invalid config. |
| 3 | Limits | Oversized headers, oversized body, trickled headers, a slow body, and too many connections are each refused within a bounded time, with the expected status and rejection reason. |
| 4 | Framing conformance |  HTTP/2 passes h2spec. HTTP/1.1 rejects the CL+TE, duplicate-CL, and whitespace-before-colon cases. |
| 5 | Codec fuzzing | Coverage-guided fuzzing of the parser runs for a set duration with no crash, hang, or unbounded allocation. |
| 6 | HTTP/2 abuse | Rapid Reset, CONTINUATION flood, and PING flood scenarios: CPU and memory stay bounded and the attacker's connection is closed. |
| 7 | Isolation | One handler hangs forever; unrelated routes keep their latency within the SLO. |
| 8 | Overload | Load above capacity is rejected early. Goodput stays near capacity instead of collapsing. Recovery happens within a bounded time once load drops. |
| 9 | Drain | Under live load behind a real LB, a deploy produces zero 5xx responses. Long requests finish or are cancelled by the deadline. |
| 10 | Cancellation | A client disconnecting mid-request cancels downstream work within a bounded time. Verify at the downstream, not just in the server. |
| 11 | Peer resolution | Forwarded headers from untrusted sources are ignored. Per-client limits key on the true client address. |
| 12 | TLS reload | A valid new certificate is served without dropping connections. An invalid one is rejected and the old one stays in use. |
| 13 | Soak | Several hours at moderate load: flat memory, file descriptors, and goroutines or threads. |
| 14 | Timeouts | Every timeout is tested with an injectable clock, not with real sleeps. |

---

## 8. Build order (revised)

 The previous order put observability at step 7. That's too late: without it you can't see whether steps 3–6 actually work.

1. Component skeleton, state machine, config schema and validation, stub handler.
2. **Outer wrapper**: error boundary, Problem Details envelope, metrics, structured logs.
3. Listener, bound-address reporting, and a resilient accept loop.
4. Connection manager: registry, caps, all timeouts.
5. One codec adapter over a proven implementation (§1), with limits and streaming.
6. Pipeline stages 1–4 and 10 (identity, peer resolution, admission, route resolution, deadline), plus the handler.
7. Graceful drain, including the propagation wait and protocol-specific close signals.
8. Authentication, authorization, rate limits, and quotas (stages 5–9, 11).
9. Second codec, TLS reload, mTLS, adaptive concurrency: only when a test or a requirement shows you need them.

---

## 9. What I still can't decide for you

 Three answers change real parts of this design:

1. **Is the public server internet-facing directly, or behind a proxy or LB?** This decides §1, the idle-timeout rule, the trusted-proxy list, and how much of the codec hardening you own.
2. **Do any routes hold long-lived streams** (SSE, WebSocket, gRPC streaming, streamed LLM output)? This decides connection-age grace, drain behaviour, and whether streaming routes need their own concurrency class.
3. **What does the platform's hard kill timeout look like?** This decides the shutdown budget, and the current config cannot be validated without it.

Which of the three servers are you building first, and does the public one terminate TLS itself or sit behind a load balancer?