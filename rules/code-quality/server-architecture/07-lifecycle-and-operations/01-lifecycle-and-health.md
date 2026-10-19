Lifecycle Controller
├── States
│   ├── Created ... inert         ready: no   live: yes
│   ├── Starting .. bind, certs   ready: no   live: yes
│   ├── Serving ... handling      ready: yes  live: yes
│   ├── Draining .. finishing     ready: no   live: yes
│   └── Stopped ... closed        ready: no   live: —
│
├── Transitions
│   ├── Created → Starting ......... start() called
│   ├── Starting → Serving ......... listener bound AND accepting
│   ├── Starting → Stopped ......... bind / cert failure (fatal channel)
│   ├── Serving → Draining ......... SIGTERM or stop()
│   ├── Draining → Stopped ......... in-flight = 0 OR force-close done
│   └── Created → Stopped .......... stop() before start (must succeed)
│
├── Guarantees
│   ├── [M] stop() idempotent; safe before / during start
│   ├── [M] serve-loop failures ⇒ main's single fatal channel
│   └── emit: server_state (gauge), state transition logs
│
└── Health (served on admin listener; gRPC: grpc.health.v1)
    ├── Liveness: "can this process make progress?"
    │   ├── checks: event loop responsive, no wedged workers
    │   └── [M] MUST NOT check downstream dependencies
    ├── Readiness: "send traffic here now?"
    │   ├── checks: state = Serving, local critical prerequisites
    │   └── [S] shared dependency down ⇒ stay ready, serve degraded
    └── Startup (optional): gates liveness during slow warm-up