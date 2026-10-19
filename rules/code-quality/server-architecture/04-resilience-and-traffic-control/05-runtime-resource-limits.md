Runtime vs Container
├── why: a runtime unaware of cgroup limits gets OOM-killed or over-schedules
│
├── CPU
│   ├── Go
│   │   ├── [M] GOMAXPROCS matches container CPU limit
│   │   └── note: container-aware by default only from Go 1.25
│   ├── JVM (Kotlin)
│   │   └── [M] container support on; verify active processor count at startup
│   └── emit: effective CPU count in startup log
│
├── Memory
│   ├── Go ..... [M] GOMEMLIMIT below the cgroup limit (leave headroom)
│   ├── JVM .... [M] heap as % of container (MaxRAMPercentage) + off-heap budget
│   ├── [M] limit = heap + stacks + buffers + off-heap + TLS state
│   └── fail: OOM kill ⇒ no drain, no logs; must be alerted on separately
│
├── File descriptors
│   ├── [M] read ulimit at startup
│   ├── [M] fail startup if ulimit < connection cap + outbound budget + margin
│   └── emit: fds_open, fds_limit
│
└── GC behaviour
    ├── [M] observe GC pause and CPU in the overload test
    └── DECIDE: tune only after measurement