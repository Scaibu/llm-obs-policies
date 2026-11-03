The most common mistake here is treating consumers as "APIs without HTTP." [Certain] They fail completely differently: messages get redelivered on network disconnects, brokers rebalance partitions, and poisoned payloads crash consumer loops. Copying the HTTP delivery pattern into message consumers causes silent data corruption, out-of-order execution, and poison pill crash loops.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis
  ↺  registers cleanup
```

---

## 1. Event Contract Definition

```
defineEventContract(topic) → eventContract                                  ▶
├── eventName() → "order.created"           (past tense fact, never an imperative command)
├── partitionKey() → orderId                (determines partition and strict ordering)
├── schema() → fields + semanticVersion
├── compatibility() → backward | full       (enforced by Schema Registry in CI)
├── orderingGuarantee() → per key | none
├── piiFields() → [fields to encrypt or scrub]
└── retention() → duration
```

---

## 2. Consumer Registration & Chassis Options

```
spec.registerConsumers(group, services)                                     ▶
└── consume(topic, handler, options)
    └── options
        ├── orderingScope → per key | per partition | none
        ├── concurrency → per partition | per key worker pool
        ├── maxAttempts, backoff (initial, max, jitterFactor)
        ├── retryMode → in place (preserves ordering) | retry topic (preserves throughput)
        ├── deadLetterTopic → "orders.dlq"
        └── processingTimeout → max duration before lease expires
```

[Certain] `retryMode` is a non-negotiable trade-off. Retrying in place halts the entire partition behind one failing message. Shunting to a retry topic preserves throughput but permanently breaks per-key ordering. This must be decided per consumer contract, never fleet-wide.

---

## 3. Event Processing Lifecycle

```
handleEvent(context, envelope) → outcome
├── deserialize(envelope, schemaRegistry) → event                 ⚙ ⚠ → DLQ, no retry
├── upcast(event, fromVersion, toVersion) → event                 ⚙
├── restoreContext(envelope.headers) → context                    ⚙
│   └── traceparent, requestId, correlationId, tenant, flagContext
├── checkProcessed(event.id, consumerName) → seen | new           ⚙
│   └── seen → ack and skip immediately
├── toCommand(event) → command                                    ▶
├── services.billing.onOrderCreated(context, command) → result    ▶
│   └── inTransaction(db)
│       ├── apply(command)
│       ├── markProcessed(event.id, consumerName)  (same database transaction)
│       └── writeOutbox(InvoiceCreated)            (same database transaction)
├── classifyFailure(error) → transient | permanent                ⚙
│   ├── transient → retry with exponential jittered backoff       ⚠
│   └── permanent or attempts exhausted → publishToDLQ(envelope, reason)
├── commitOffset()            (only after business commit or DLQ) ⚙
└── recordMetrics(lag, latency, outcome)                          ⚙
```

---

## 4. Dead Letter Queue (DLQ) & Operator Replay

```
operateDLQ()                                                                 ⚙
├── inspect(dlqTopic, filter) → messages
├── replay(dlqTopic, filter, targetTopic) → count   (audited CLI command)
└── alertOn(dlqRate > threshold)
```

---

## 5. Strict Consumer Invariants

1. **Storage-Level Deduplication**: Never rely on in-memory deduplication. Message processed checks must be persisted in the exact same database transaction as the business state change (`UNIQUE (consumer_group, event_id)`).
2. **Post-Commit Offset Acknowledgment**: Offsets must never be committed before the business transaction is finalized in the database or the envelope is successfully routed to the DLQ. Committing early causes message loss on pod termination.
3. **Trace Propagation**: Handlers must restore W3C trace context from message headers and create a child span covering both processing and outbox emission.

