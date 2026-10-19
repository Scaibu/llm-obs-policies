Connection Manager
├── in: raw connections        out: admitted connections
│
├── Registry
│   ├── [M] per connection: id, peer, protocol, state, opened_at, last_activity
│   ├── states: handshaking → active ⇄ idle → closing → closed
│   ├── used by: drain, leak detection, "who holds connections" queries
│   └── emit: connections{state, protocol}, connection_duration (histogram)
│
├── Caps
│   ├── total connections
│   │   ├── fail: accept-then-close (hard) or 503 + Retry-After (soft)
│   │   └── emit: connections_rejected_total{reason="total_cap"}
│   ├── per resolved client
│   │   ├── [M] keyed by peer resolver output, never raw socket peer behind LB
│   │   └── emit: connections_rejected_total{reason="client_cap"}
│   ├── TLS handshakes per client per second
│   │   └── fail: close before handshake completes
│   └── HTTP/2 concurrent streams per connection
│       └── fail: REFUSED_STREAM (safe to retry — never processed)
│
├── Over-limit strategy (choose per cap, document it)
│   ├── stop accepting ......... client sees connect timeout — avoid
│   ├── accept + close ......... client sees reset — hard caps, attacks
│   └── accept + 503 + close ... clear retry signal — soft caps
│
├── Timeouts
│   ├── handshake ........... from TCP accept to TLS done
│   ├── header read ......... from first byte to end of headers; not reset per byte
│   ├── body rate ........... minimum bytes/sec after a short grace
│   ├── idle ................ between requests; > upstream LB idle
│   ├── write ............... per write / minimum drain rate, not per response
│   ├── max age ............. jittered (±10%) + grace for in-flight streams
│   └── each fail: close + emit connection_closed_total{reason=<timeout name>}
│
└── Drain hooks
    ├── stop admitting new connections
    ├── mark all connections "closing" → codec sends protocol close signals
    └── report live count until zero or deadline