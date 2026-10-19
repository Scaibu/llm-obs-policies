Config
├── Schema layer (JSON Schema 2020-12)
│   ├── [M] every field typed, ranged, with a safe default
│   ├── [M] durations as typed values with units, never bare integers
│   ├── [M] addresses parsed and classified (loopback / private / public)
│   └── fail: process exits before start, error names field + path + reason
│
├── Cross-field layer (CEL rules)
│   ├── timeouts
│   │   ├── [M] header_timeout < idle_timeout
│   │   ├── [M] idle_timeout > upstream_lb_idle_timeout
│   │   ├── [M] handshake_timeout <= header_timeout
│   │   └── [M] every route.timeout <= server.max_request_timeout
│   ├── limits
│   │   ├── [M] every route.max_body <= codec.max_body
│   │   ├── [M] every route.max_headers <= codec.max_headers
│   │   └── [M] per_client_cap <= total_connection_cap
│   ├── lifecycle
│   │   ├── [M] propagation_wait + drain_deadline + force_margin < kill_timeout
│   │   └── [M] max_connection_age_grace >= longest_stream OR streams exempt
│   ├── exposure
│   │   ├── [M] public.bind != admin.bind
│   │   ├── [M] admin.bind not public unless auth + allowlist set
│   │   └── [M] tls.mode = off only on loopback or a declared private network
│   └── trust
│       └── [M] trusted_proxies empty ⇒ forwarded headers ignored entirely
│
├── Modes
│   ├── validate-only ... [M] full validation, zero sockets, zero threads
│   └── run ............. validate → construct → start
│
├── Reload
│   ├── [M] new config passes both layers before anything changes
│   ├── [M] produce a new immutable Policy Snapshot, swap atomically
│   ├── [M] in-flight requests keep the snapshot they started with
│   ├── [M] non-reloadable fields (bind address, protocol set) ⇒ reject reload
│   ├── fail: keep old snapshot, log diff + reason
│   └── emit: config_reload_total{result}, config_version (info metric)
│
└── emit: startup log of effective values (incl. kernel-capped backlog)