---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_FLOOD_PROTECTION_CREATION"
agent_role: "Principal Infrastructure Security Architect & DDoS Defense Officer"
target_scope: "Volumetric Attack Mitigation, SYN Floods, Connection Starvation, L4/L7 Defense & TCP Syncookies"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Volumetric Attack Defense Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Layered Ingress Protection Invariant
Volumetric Layer 3/4 network floods (SYN floods, UDP amplification, ICMP floods) MUST be absorbed and filtered at the edge network layer (Anycast BGP, Cloudflare, AWS Shield, kernel TCP syncookies). Application servers MUST NOT attempt to absorb raw gigabit volumetric packet floods at the application layer.

Guardrail 2: Kernel SYN Flood & Backlog Tuning
The server environment MUST enable kernel-level SYN flood protection:
- `net.ipv4.tcp_syncookies = 1`.
- `net.ipv4.tcp_max_syn_backlog \ge 4096`.
- `net.core.somaxconn \ge 4096`.
Application listeners MUST log any truncation of the accept backlog by the kernel.

Guardrail 3: Pre-Handshake Connection Rate Limiting
To defend against TCP connection exhaustion attacks, the ingress connection manager MUST enforce an IP-based connection rate limit (e.g. maximum 50 new TCP connections/second per IP subnet) before initiating expensive TLS cryptographic handshakes.

Guardrail 4: Fast Fail & RST on Volumetric Saturation
When total connections hit 100% capacity due to a volumetric surge, the server MUST NOT queue sockets into an unbounded accept backlog. It MUST immediately accept-and-close or emit TCP RST to release kernel memory buffers.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside security filter functions. Document the flood defense thresholds in the file header docblock.

---

## 2. Volumetric Defense Contract

```yaml
volumetric_defense_contract:
  kernel_parameters:
    tcp_syncookies: 1
    tcp_max_syn_backlog: 4096
    somaxconn: 4096
  application_limits:
    max_handshake_concurrency: 500
    max_connection_rate_per_ip: 50
    handshake_timeout_ms: 3000
  saturation_action: "TCP_RST"
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **SYN Flood Queue Exhaustion Fix**: Verify `cat /proc/sys/net/ipv4/tcp_syncookies` returns `1`. If syn backlog fills up, kernel generates cryptographically verified SYN-ACKs without allocating socket control blocks.
2. **TLS Handshake CPU Starvation Fix**: Clamp `handshake_timeout: 3000ms`. Connections holding open sockets during TLS negotiation without completing the key exchange within 3s are forcefully terminated.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Check Kernel Socket Backlog
Ensure `listen(backlog)` parameter requests at least `2048` and logs a warning if capped by the operating system.

### Instruction 2: Instrument Handshake Aborts
Emit `handshake_failures_total{reason="timeout|flood"}` on every stalled connection drop.
