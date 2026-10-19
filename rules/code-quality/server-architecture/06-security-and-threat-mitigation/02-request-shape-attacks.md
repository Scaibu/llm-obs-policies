Request-Shape Defenses
├── Path canonicalization (before stage 4)
│   ├── why: auth policy and route matcher must see the same path
│   ├── steps
│   │   ├── [M] decode percent-encoding exactly once
│   │   ├── [M] reject encoded slash / backslash / NUL in path segments
│   │   ├── [M] resolve or reject dot segments (RFC 3986 §5.2.4)
│   │   ├── [M] reject double-encoding
│   │   └── DECIDE: case sensitivity, trailing slash policy
│   ├── [M] reject ambiguity — never "fix" it silently
│   └── emit: reason="path_noncanonical"
│
├── Decompression limits
│   ├── why: tiny gzip body → gigabytes in memory
│   ├── [M] allowlist Content-Encoding per route
│   ├── [M] cap decompressed bytes (not just compressed)
│   ├── [M] cap compression ratio
│   └── emit: reason="decompression_limit"
│
├── Route-matcher complexity
│   ├── why: backtracking regex = ReDoS
│   ├── [M] linear-time matching (RE2-class) or no regex in routes
│   └── [M] same rule for header and body validators
│
├── Method override headers
│   └── [M] ignore X-HTTP-Method-Override unless explicitly enabled per route
│
└── Host header
    ├── [M] allowlist of served hosts
    └── [M] never build absolute URLs from an unvalidated Host