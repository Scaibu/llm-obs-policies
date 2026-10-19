---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_PROTOCOL_CODEC_CREATION"
agent_role: "Principal Security Systems Architect & Protocol Parser Auditor"
target_scope: "HTTP/1.1 Framing, HTTP/2 Rapid Reset, CONTINUATION Floods, HPACK & Smuggling Defense"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Protocol Codec Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: HTTP/1.1 Request Smuggling Invariants (RFC 9112)
- **CL + TE Conflict**: If a request contains both `Content-Length` and `Transfer-Encoding`, `Transfer-Encoding` MUST take precedence, and the connection MUST be closed after responding.
- **Multiple Disagreeing Content-Lengths**: Reject with HTTP 400 Bad Request immediately and close the socket.
- **Illegal Whitespace & Framing Anomalies**: Reject any request with whitespace before header colons, obsolete line folding (obs-fold), bare CR characters, or null bytes with HTTP 400 and immediate socket closure.
- **Host Header Enforcement**: Exactly one `Host` header is mandatory for HTTP/1.1. Missing or duplicated Host headers MUST return HTTP 400.
- **Immediate Socket Closure Rule**: After any HTTP/1.1 framing error, the socket MUST be closed; the boundary of the subsequent request on the socket is untrusted.

Guardrail 2: HTTP/2 & gRPC Rapid Reset Mitigation (CVE-2023-44487)
The server MUST track the rate of client-initiated `RST_STREAM` frames per connection. If a connection exceeds the `max_rst_stream_rate` threshold (default: 100 resets within 1 second), the server MUST immediately issue an HTTP/2 `GOAWAY` frame with error code `ENHANCE_YOUR_CALM (0xB)` and terminate the TCP connection.

Guardrail 3: HTTP/2 CONTINUATION Flood Defense
The server MUST enforce a strict cap on total accumulated unparsed header bytes across consecutive `HEADERS` and `CONTINUATION` frames (maximum: 64 KiB). Exceeding this ceiling without completing the header block MUST trigger immediate connection termination with `PROTOCOL_ERROR (0x1)`.

Guardrail 4: HPACK Bomb Protection (RFC 7541)
The HPACK dynamic table size MUST be capped (default: 4096 bytes). Decompressed header size MUST be limited strictly before buffering to prevent memory exhaustion bombs.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside function bodies. Document the entire codec framing and defense mechanisms in the file header docblock.

---

## 2. Protocol Codec Ceilings Contract

```yaml
codec_limits:
  max_header_size_bytes: 65536
  max_header_count: 100
  max_chunk_size_bytes: 1048576
  max_body_stream_bytes: 52428800 # 50 MiB
  http2:
    max_frame_size: 16384
    initial_stream_window_size: 65535
    initial_connection_window_size: 1048576
    max_concurrent_streams: 100
    hpack_dynamic_table_size: 4096
    rapid_reset_budget:
      max_resets_per_window: 100
      window_seconds: 1
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **HTTP/1.1 Desync Smuggling Attack Fix**: Whenever an invalid header syntax (e.g. `Transfer-Encoding: chunked\r\nContent-Length: 4`) arrives, write `HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n` and close the transport socket immediately.
2. **HTTP/2 CONTINUATION DoS Fix**: If a `CONTINUATION` frame arrives without an active prior `HEADERS` frame or if accumulated payload exceeds 64KB, trigger immediate connection teardown.
3. **Chunked Stream Early Abort Fix**: If the client closes the connection mid-chunk, immediately signal cancellation down the active request context; do not continue executing downstream workers.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Never Build Custom Raw Codecs
Rely strictly on mature runtime protocol engines (Envoy, Netty, Go `net/http`, Uvicorn/Hypercorn, Kestrel) wrapped with explicit parameter ceilings. Never write raw byte-level TCP HTTP parsers from scratch.

### Instruction 2: Trace and Instrument Codec Rejections
Emit `codec_rejections_total{protocol="h1|h2", reason="rapid_reset|header_overflow|smuggling"}` for every rejected framing anomaly.
