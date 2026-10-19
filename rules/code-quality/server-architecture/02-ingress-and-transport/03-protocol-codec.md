Protocol Codec
├── in: admitted connections        out: request streams
├── [M] one interface for every protocol; streaming is the base model
├── [M] codec-wide ceilings: header bytes, header count, body bytes, frame size
│
├── HTTP/1.1 (RFC 9112)
│   ├── framing integrity (smuggling defense)
│   │   ├── CL + TE together ........... TE wins, close after response
│   │   ├── multiple differing CL ...... 400, close
│   │   ├── whitespace before colon .... 400, close
│   │   ├── obs-fold, bare CR, NUL ..... 400, close
│   │   └── missing / duplicate Host ... 400
│   ├── [M] after any framing error, close — next request boundary is unknown
│   ├── 100-continue
│   │   └── [M] send only after route limits + auth pass (pipeline 5–8)
│   └── emit: codec_rejections_total{protocol="h1", reason}
│
├── HTTP/2 + gRPC (RFC 9113)
│   ├── Rapid Reset (CVE-2023-44487)
│   │   ├── [M] count resets against a per-connection budget
│   │   └── fail: GOAWAY(ENHANCE_YOUR_CALM) + close
│   ├── CONTINUATION flood
│   │   ├── [M] cap total header bytes across HEADERS + CONTINUATION
│   │   └── fail: connection error, close
│   ├── HPACK bomb
│   │   ├── [M] enforce SETTINGS_MAX_HEADER_LIST_SIZE on decoded size
│   │   └── [M] bound dynamic table size
│   ├── control-frame floods (PING, SETTINGS, empty frames)
│   │   └── [M] per-connection rate limit → close on breach
│   ├── buffering abuse (zero / tiny windows)
│   │   └── [M] bounded per-stream + per-connection output buffers, write timeout
│   ├── stream concurrency
│   │   └── [M] SETTINGS_MAX_CONCURRENT_STREAMS (start near 100)
│   └── emit: codec_rejections_total{protocol="h2", reason}, h2_resets_total
│
├── Framed TCP
│   ├── [M] length-prefix ceiling checked before allocation
│   ├── [M] per-frame read timeout
│   └── fail: close (no in-band error channel assumed)
│
└── Error mapping
    ├── request-level problem ⇒ protocol error response, connection kept
    └── framing-level problem ⇒ connection closed