Leakage Controls
├── Logs
│   ├── [M] allowlist of loggable fields (not a denylist)
│   ├── [M] never log Authorization, Cookie, Set-Cookie, API keys, bodies
│   └── [M] PII fields hashed or dropped
├── Traces
│   ├── [M] header scrubbing before export
│   └── [M] span attributes follow the same allowlist
├── Errors
│   ├── [M] Problem Details never include stack traces or internal hosts
│   └── [M] detailed error stays in logs, keyed by request ID
├── Core dumps / heap dumps
│   └── [M] disabled, or written encrypted to restricted storage
└── Admin endpoints
    └── [M] profiling / debug endpoints authenticated + admin-listener only