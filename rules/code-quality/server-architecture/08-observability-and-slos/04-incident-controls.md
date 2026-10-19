Incident Controls
├── Kill switches (in policy snapshot, hot-reloadable)
│   ├── [M] disable one route ⇒ 503 + Problem Details
│   ├── [M] disable one upstream ⇒ fallback path
│   └── [M] change takes effect without deploy
├── Brownout / degraded mode
│   ├── [S] switch off optional expensive work (enrichment, recommendations)
│   └── DECIDE: automatic trigger (queue wait) or manual only
└── Maintenance mode
    └── [O] whole server returns 503 + Retry-After, health stays live