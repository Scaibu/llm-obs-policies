Alerting
├── SLO burn-rate alerts (multi-window, multi-burn-rate)
│   ├── page:   fast burn  (short + long window both burning)
│   ├── page:   medium burn
│   ├── ticket: slow burn
│   └── [Likely] Google SRE Workbook: 14.4× (1 h / 5 min), 6× (6 h / 30 min),
│                1× (3 d / 6 h)
├── Direct-cause alerts
│   ├── rejection spike by reason
│   ├── certificate expiry < N days
│   ├── breaker open on a critical upstream
│   ├── OOM kills / restarts
│   └── config reload failures
└── Runbooks
    └── one entry per rejection reason
        ├── what it means
        ├── most likely cause
        ├── first diagnostic query
        └── first mitigation (kill switch, scale, rollback)