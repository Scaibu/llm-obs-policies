Scope Decisions
├── HTTP/3 / QUIC
│   ├── in scope ⇒ UDP listener, QUIC flood classes, own drain semantics
│   └── out of scope ⇒ terminate at edge, document it
├── Idempotency key store
│   ├── storage + TTL
│   ├── concurrent duplicate behaviour (wait / 409 / replay)
│   └── stored response replay rules
├── Response compression
│   ├── which routes / content types
│   └── never compress secrets alongside attacker input (BREACH)
├── Multi-tenant fairness
│   ├── per-tenant quotas (stage 9) are not enough
│   └── fair queuing across tenants in admission (tree H)
├── Body schema validation
│   ├── pipeline stage (uniform, early) vs handler (flexible, late)
│   └── which contract artifact is the source of truth
├── Audit logging
│   ├── which actions need tamper-evident records
│   └── separate from access logs; separate retention
└── Clock skew
    └── tolerance for tokens and cross-host deadlines