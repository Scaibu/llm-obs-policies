The most common telemetry incident is high-cardinality label explosion that knocks over monitoring backends, coupled with leaking plain-text PII into tracking pipelines. [Certain] Emitting dynamic identifiers like user IDs, email addresses, or un-templated URLs into Prometheus metric labels triggers metric server OOMs and violates GDPR/HIPAA compliance.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis
  ↺  registers cleanup
```

---

## 1. Tracked Product Event Contract

```
defineTrackedEvent(name) → trackingSpec                                     ▶
├── name() → "object.action"   (e.g., "order.created", "checkout.started")
├── properties() → schema (strongly typed payload contract)
├── piiClassification() → per property {NONE, PSEUDONYMOUS, RESTRICTED}
├── sampling() → sampleRate (0.0 to 1.0)
└── owner() → owningTeam
```

---

## 2. Event Tracking Pipeline

```
track(context, name, properties)                                            ⚙
├── validate(name, properties, trackingPlan)
│   ├── dev / CI → fail test suite immediately                              ⚠
│   └── production → drop event + increment invalid_tracking_events_total
├── enrich(context) → requestId, traceId, tenant, pseudonymous userId,
│                     service, version, active flag variants
├── scrubPII(properties, piiClassification)                                 ⚙
│   └── hash or drop RESTRICTED fields
├── enqueue(event)           (bounded channel, non-blocking; full → drop + count)
└── exportBatch() → event pipeline → warehouse / analytics sink
```

---

## 3. Metrics, Traces & Logs Cardinality Guardrails

```
telemetryConventions()                                                      ⚙
├── spans → One root span per inbound request/consumer; child span per I/O call
├── metrics
│   ├── per route / per consumer → rate, errors, duration (histogram)
│   ├── per resource → connection pool utilization, thread saturation
│   └── labels → strictly bounded values ONLY (e.g. status_code_class: 2xx, 5xx)
└── logs → Structured JSON, mandatory traceId & spanId correlation
```

[Certain] Never put user IDs, order UUIDs, raw JSON payloads, or dynamic URLs into metric labels. Every unique label combination generates a new Prometheus time series. High-cardinality dimensions belong exclusively in OpenTelemetry trace attributes and structured Loki logs.

---

## 4. Strict Telemetry Invariants

1. **Bounded Metric Cardinality**: All metric labels must have a known, finite domain ($\le 30$ distinct values). Dynamic IDs, email addresses, and full URLs are forbidden in metric labels.
2. **Pre-Ingress PII Scrubbing**: Passwords, authorization tokens, full credit card PANs, and sensitive user data must be sanitized before being enqueued or exported to analytics streams.
3. **Non-Blocking Observability**: Failure in metrics emission, tracing exporters, or product analytics must never degrade or block core transactional request handling.

