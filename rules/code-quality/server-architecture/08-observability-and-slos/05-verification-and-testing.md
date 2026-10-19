Verification
├── Lifecycle
│   ├── port-0 start → discover → stop; no leaks (ports, fds, tasks)
│   └── stop twice / stop before start both succeed
├── Config
│   ├── every documented invalid combination rejected in validate-only
│   └── property-generated configs: no invalid one accepted
├── Limits
│   ├── oversized headers / body, trickled headers, slow body, conn flood
│   └── each refused in bounded time with expected status + reason
├── Conformance
│   ├── HTTP/2: h2spec passes
│   └── HTTP/1.1: CL+TE, duplicate CL, whitespace-before-colon rejected
├── Fuzzing
│   └── coverage-guided parser fuzzing: no crash, hang, unbounded allocation
├── HTTP/2 abuse
│   └── Rapid Reset, CONTINUATION, PING flood: CPU + memory bounded
├── Isolation
│   └── one handler hangs; other routes stay within SLO
├── Overload
│   └── early rejection; goodput holds near capacity; bounded recovery
├── Drain
│   └── deploy under load behind a real LB: zero 5xx
├── Cancellation
│   └── client disconnect stops downstream work (verified downstream)
├── Peer resolution
│   └── untrusted forwarded headers ignored; limits keyed correctly
├── TLS reload
│   └── valid cert served without drops; invalid cert rejected, old kept
├── Soak
│   └── hours at moderate load: flat memory, fds, threads
└── Timeouts
    └── injectable clock, no real sleeps