Observability
├── Metrics (OpenTelemetry HTTP semantic conventions)
│   ├── request
│   │   ├── http.server.request.duration ... histogram, seconds
│   │   └── http.server.active_requests
│   ├── connection: count by state, duration, closed by reason
│   ├── overload: admission limit, in-flight, queue depth, queue wait
│   ├── rejections: one counter, closed reason set
│   │   └── admission | rate_limit | quota | auth | authz | deadline_unviable
│   │       header_timeout | body_rate | header_too_large | body_too_large
│   │       smuggling_suspect | h2_reset_budget | h2_control_flood | client_cap
│   ├── TLS: handshake failures{reason}, cert expiry seconds
│   └── lifecycle: state, drain duration, force-closed count
│
├── Cardinality rules
│   ├── [M] http.route (pattern), never raw path
│   ├── [M] methods normalized, unknown ⇒ _OTHER
│   └── [M] no user / tenant / request IDs as labels
│
├── Logs
│   ├── structured: request_id, trace_id, route, peer, principal,
│   │               status, reason, duration, bytes in/out
│   └── [S] under overload: sample successes, keep 100% of rejections + errors
│
├── Traces
│   ├── W3C Trace Context, inbound trusted only
│   └── span per request; child spans for auth + downstream calls
│
└── Views
    ├── RED per route ...... rate, errors, duration
    └── USE per resource ... connections, workers, queue, file descriptors