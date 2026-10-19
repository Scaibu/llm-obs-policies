Outbound Client
├── why: inbound limits don't protect downstream; the router can still flood it
│
├── Per-upstream connection pool
│   ├── [M] one pool per upstream service, never shared globally
│   ├── caps
│   │   ├── [M] max connections per upstream
│   │   ├── [M] max pending requests waiting for a connection
│   │   └── [M] max concurrent requests (HTTP/2 streams) per upstream
│   ├── timeouts
│   │   ├── [M] connect timeout (short; separate from request timeout)
│   │   ├── [M] request timeout = min(route budget, remaining inbound deadline)
│   │   ├── [M] client idle timeout < upstream server's idle timeout
│   │   └── [M] max connection lifetime (picks up DNS / endpoint changes)
│   ├── fail: pool exhausted ⇒ fail fast with local 503, never queue unbounded
│   └── emit: pool_connections{upstream,state}, pool_pending, pool_exhausted_total
│
├── Deadline propagation
│   ├── [M] send remaining deadline downstream (grpc-timeout or custom header)
│   ├── [M] subtract a safety margin per hop
│   └── [M] remaining < upstream minimum ⇒ don't call; fail fast
│
├── Cancellation propagation
│   ├── [M] inbound cancel ⇒ cancel outbound call immediately
│   └── why: paid / expensive downstream work (LLM calls) for nobody
│
├── Endpoint discovery
│   ├── DECIDE: DNS / service registry / service mesh / static list
│   ├── [M] refresh interval + behaviour when discovery is unreachable
│   ├── [S] keep last-known-good endpoints rather than empty set
│   └── emit: endpoints{upstream}, discovery_errors_total
│
├── Load balancing across instances
│   ├── DECIDE: round robin / least-request / power-of-two-choices
│   ├── [S] power-of-two least-request for uneven latency
│   └── [M] avoid instances in outlier ejection (tree 3)
│
├── Resource budget on the host
│   ├── [M] ephemeral port range sized for outbound volume
│   ├── [M] fd budget shared with inbound — count both
│   └── emit: outbound_fds, ephemeral_ports_in_use
│
└── emit: client request duration histogram per upstream + route
          (OpenTelemetry http.client.request.duration)