Peer Resolver
├── in: socket peer, TLS identity, headers, trusted proxy list
├── out: resolved client address, transport identity, hop chain
│
├── socket peer NOT in trusted list
│   └── [M] use the socket peer; ignore every forwarding header
│
├── socket peer IS trusted
│   ├── sources (one configured, not all at once)
│   │   ├── PROXY protocol v2 .... preferred for TCP / L4 balancers
│   │   ├── Forwarded (RFC 7239)
│   │   └── X-Forwarded-For
│   ├── [M] walk the chain right-to-left
│   ├── [M] skip trusted hops; first untrusted address = client
│   └── fail: malformed header from a trusted hop ⇒ 400 + log
│
└── emit: peer_resolution_total{source, result}