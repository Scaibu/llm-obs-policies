Browser Controls
├── CORS
│   ├── [M] explicit origin allowlist; never reflect Origin blindly
│   ├── [M] credentials allowed only with explicit origins (no wildcard)
│   └── [M] preflight answered in pipeline before auth
├── CSRF
│   ├── [M] required for cookie-authenticated state-changing routes
│   └── options: SameSite cookies + token, or Origin / Fetch-Metadata check
├── Response headers
│   ├── HSTS ........................... [M] on public TLS
│   ├── X-Content-Type-Options: nosniff  [M]
│   ├── Content-Security-Policy ........ [S] for HTML responses
│   └── Referrer-Policy ................ [S]
└── Cookies
    └── [M] Secure, HttpOnly, SameSite set deliberately