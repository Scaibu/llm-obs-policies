t0  SIGTERM received
│
├── 1 readiness → off                             t0
│
├── 2 keep serving normally                       t0 → t0+P   (P = propagation wait)
│   └── why: LB endpoint removal is asynchronous to SIGTERM
│
├── 3 stop accepting new connections              t0+P
│
├── 4 signal existing connections                 t0+P
│   ├── HTTP/1.1
│   │   ├── in-flight: response carries Connection: close
│   │   └── idle: close now
│   ├── HTTP/2 / gRPC (RFC 9113 §6.8)
│   │   ├── GOAWAY(last_stream_id = 2^31−1)
│   │   ├── wait ≥ 1 RTT
│   │   └── GOAWAY(last_stream_id = actual last)
│   ├── WebSocket ... close frame 1001 Going Away (RFC 6455 §7.4.1)
│   └── SSE ......... end stream; client resumes with Last-Event-ID
│
├── 5 wait for in-flight                          t0+P → t0+P+D (D = drain deadline)
│   └── emit: inflight countdown, drain_duration
│
├── 6 cancel remaining contexts                   t0+P+D
│   ├── short wait for handlers to observe cancel (F = force margin)
│   └── force-close what remains
│       └── emit: connections_force_closed_total
│
└── 7 Stopped, listener released                  ≤ t0+P+D+F

[M] P + D + F < platform hard kill timeout