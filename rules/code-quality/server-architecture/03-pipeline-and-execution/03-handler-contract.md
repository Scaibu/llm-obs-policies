Handler
├── in
│   ├── context: deadline, cancellation, principal, trace, policy snapshot
│   └── request: method, route params, headers, streaming body
├── out
│   ├── buffered response
│   └── streamed response (with explicit end)
├── cancellation sources
│   ├── client disconnect / stream reset
│   ├── deadline expiry
│   └── server drain (after drain deadline)
├── [M] downstream calls observe cancellation (stops paid LLM calls)
├── [M] MUST NOT write to the socket, set connection headers, or decide reuse
└── [M] MUST NOT block the accept / parse / event-loop threads