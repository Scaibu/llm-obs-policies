Host + Diagnostics
├── Kernel / host checklist
│   ├── somaxconn (effective backlog)
│   ├── conntrack table size (NAT / firewall hosts)
│   ├── ephemeral port range
│   ├── fd limits (process + system)
│   └── [M] all logged at startup with effective values
└── Continuous profiling [O]
    ├── low-overhead CPU + allocation profiles
    └── [M] admin listener only, authenticated