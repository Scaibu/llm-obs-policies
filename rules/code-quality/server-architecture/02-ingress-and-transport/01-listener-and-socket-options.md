Listener
├── in:  bind config, TLS provider        out: raw connections
│
├── Bind (inside start only)
│   ├── [M] report the actual bound address (supports port 0 in tests)
│   ├── fail: fatal at startup — address + protocol + OS errno in message
│   └── emit: listener_bound{addr, protocol}
│
├── Socket options (explicit, never inherited)
│   ├── [M] address reuse ......... fast restart past TIME_WAIT
│   ├── [O] port reuse ............ multi-process accept / zero-downtime restart
│   ├── [M] accept backlog ........ log the effective value (kernel caps it)
│   ├── [M] TCP keepalive ......... interval < any NAT/firewall idle on the path
│   └── [S] TCP_NODELAY ........... on for request/response; measure for bulk
│
├── TLS provider
│   ├── versions
│   │   ├── [M] minimum TLS 1.2 (RFC 9325 / BCP 195)
│   │   └── [S] prefer TLS 1.3 (RFC 8446)
│   ├── negotiation
│   │   └── [M] ALPN (RFC 7301): h2, http/1.1 — determines the codec
│   ├── 0-RTT early data
│   │   ├── [M] off by default (replayable, RFC 8446 §8)
│   │   └── [O] on only with idempotency enforcement + 425 Too Early (RFC 8470)
│   ├── certificate reload
│   │   ├── [M] load → validate key pair, chain, expiry → atomic swap
│   │   ├── fail: keep old pair, alert
│   │   └── emit: tls_cert_expiry_seconds, tls_reload_total{result}
│   ├── mTLS (optional)
│   │   ├── [M] identity from SAN (e.g. SPIFFE ID), never Common Name
│   │   └── fail: handshake rejected, emit reason
│   └── emit: tls_handshake_failures_total{reason}, handshake duration
│
└── Accept loop
    ├── [M] never runs handler work
    ├── transient errors (EMFILE, ENFILE, ENOBUFS, ECONNABORTED)
    │   ├── [M] capped exponential backoff (e.g. 5 ms → 1 s), never exit
    │   └── [S] reserved-fd trick: release, accept, close, re-reserve
    ├── fatal errors (listener closed outside drain)
    │   └── [M] report to main's single fatal channel
    └── emit: accept_errors_total{errno}, accept_backoff_active