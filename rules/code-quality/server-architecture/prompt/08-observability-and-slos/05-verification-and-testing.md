---
agent_activation_trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_TEST_SUITE_CREATION"
agent_role: "Principal Quality Assurance Architect & Chaos Verification Auditor"
target_scope: "Automated Verification, Conformance Suites, Fuzzing, Overload Tests & Port-0 Testing"
execution_mode: "Strict & Non-Negotiable Enforcement Gate"
enforcement: "Absolute (Zero-Omission Policy)"
---

# Verification and Testing Standards

(Universal Language-Agnostic Operational Rule for Polyglot Microservices in Go, Python, Rust, Java, C#, Node.js/TypeScript)

---

## 1. Strict Guardrails

0. **STRICT NON-ASSUMPTION & SCOPE ISOLATION INVARIANT**: Strictly never assume anything and do not create anything extra unless explicitly requested by the user.

Guardrail 1: Ephemeral Port-0 Lifecycle Leak Test
Integration suites MUST test the full server lifecycle on ephemeral port `0` (`start(port=0)` $\rightarrow$ query dynamic port $\rightarrow$ run assertions $\rightarrow$ `stop()`). After `stop()`, test suites MUST assert:
- Zero listening sockets remain open.
- Zero orphaned background tasks or goroutines exist.
- Calling `stop()` a second time succeeds idempotently without error.

Guardrail 2: Protocol Conformance & Ingress Flood Assertions
Automated tests MUST verify defense mechanisms against protocol anomalies:
- **HTTP/1.1**: Reject `CL+TE`, duplicate `Content-Length`, and whitespace before colons with HTTP 400.
- **HTTP/2**: Enforce Rapid Reset limits (`RST_STREAM` rate) and assert connection termination with `GOAWAY(ENHANCE_YOUR_CALM)`.
- **Limits**: Verify oversized headers, slowloris byte trickles, and bodies exceeding limits return HTTP 413, 408, or 431 within bounded timeouts.

Guardrail 3: Zero-5xx Rolling Deploy Drain Verification
End-to-end chaos tests MUST run continuous traffic (e.g. 500 RPS) against a multi-replica service behind an edge proxy while triggering a rolling deployment. The test MUST assert **zero dropped requests (zero HTTP 5xx responses)** throughout the entire rolling drain sequence.

Guardrail 4: Downstream Cancellation Propagation Test
Tests MUST assert that client disconnection triggers context cancellation in mock downstream services within $< 100\text{ms}$, halting downstream work.

Guardrail 5: Zero Inline Comments Doctrine
Never write mid-function inline comments inside test functions. Document test invariants in file header docblocks.

---

## 2. Verification Contract

```yaml
verification_contract:
  suites:
    lifecycle:
      test_port_zero: true
      test_double_stop_idempotent: true
      test_stop_before_start: true
    conformance:
      http1_smuggling_vectors: ["CL_TE", "DUPLICATE_CL", "OBS_FOLD"]
      http2_abuse_vectors: ["RAPID_RESET", "CONTINUATION_FLOOD"]
    limits:
      test_body_overflow_413: true
      test_header_overflow_431: true
      test_idle_timeout_disconnect: true
    drain:
      target_error_rate: 0.00 # Zero 5xx during deploy
```

---

## 3. Edge-Case Implementation Fix Instructions

1. **Flaky Port Collision in Parallel Tests Fix**: Never hardcode ports (e.g. `8080`) in unit/integration test suites. Always bind to port `0`, let the OS allocate a free socket, and query the dynamically assigned port via `server.socket.getsockname()`.
2. **Hanging Test Task Leak Fix**: In test teardown fixtures, inspect running tasks (`asyncio.all_tasks()`). If background tasks from the test server remain uncancelled, fail the test and print the task stack trace.

---

## 4. AI Agent Implementation Instructions

### Instruction 1: Always Implement Test Fixture with Port 0
Use port 0 in all integration tests to enable parallel test execution across CPU cores.

### Instruction 2: Verify Strict Status Codes
Assert the exact status code (`400`, `413`, `429`, `503`, `504`) and RFC 9457 JSON structure in every limit rejection test.
