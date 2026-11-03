"Data pipeline" can mean four different systems: real-time ingestion, stream processing, a batch warehouse, or a lake feeding ML. [Likely] The design that breaks at scale is the one that tries to be all four at once with the same semantics. Below I cover the full path, but the most important decision is in tree 1: **which guarantees each stage gives** (at-least-once vs effectively-once, event time vs processing time, how late data is handled). Most pipeline incidents are a mismatch between what one stage guarantees and what the next one assumes.

The flow being designed:

```
producers → ingest → raw log → stream processing → sinks (serving / analytics / lake)
                        └→ archive → batch reprocessing ─────┘
                 quality checks + lineage across every arrow
```

Same notation.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by platform
  ↺  registers cleanup
```

---

## 1. Pipeline contract (decided before any code)

```
defineDataset(name) → datasetContract                                       ▶
├── owner() → team
├── schema() → fields + types + version
├── compatibility() → backward | full          (enforced by schema registry)
├── eventIdentity() → eventId generation rule  (set by producer, never by pipeline)
├── eventTime() → which field is "when it happened"
├── partitionKey() → field                     (decides ordering + parallelism)
├── orderingGuarantee() → per key | none
├── deliveryGuarantee() → at-least-once | effectively-once (per stage, stated)
├── latenessPolicy() → allowedLateness + what happens after
├── freshnessSLO() → max age at each sink
├── piiClassification() → per field
├── retention() → raw log | archive | each sink
└── consumers() → who depends on this (from lineage, not self-reported)
```

[Certain] **Exactly-once is never a property of one component.** A stream processor with transactions still double-writes if the sink isn't idempotent. Write the guarantee per stage, and make every sink idempotent regardless.

---

## 2. Ingestion

```
ingest(request) → ack                                                       ⚙ + ▶
├── authenticate(producer) → producerIdentity                   ⚠ 401
├── enforceLimits(batchSize, payloadSize, producerQuota)        ⚠ 413 | 429
├── parseEnvelope(payload) → envelope
│   └── extract only routing fields (eventId, type, tenant, eventTime)
│       full payload deserialization belongs in processing, not here
├── validateEnvelope(envelope) → ok                             ⚠ → rejected list
│   └── per-event: one bad event never fails the whole batch
├── stampIngest(envelope) → ingestTime, producerId, schemaVersion
├── routeTopic(envelope.type) → topic
├── produce(topic, key=partitionKey, value=payload) → offsets   ⚠ 503 retryable
│   ├── batching + compression
│   ├── acks = all, idempotent producer on
│   └── buffer full → backpressure (503 + Retry-After), never silent drop
└── respond(accepted, rejected[reasons])
    └── ack only after durable write to the log
```

[Likely] At high volume, ingestion CPU cost is dominated by parsing. Extracting only the routing fields with a targeted parser, and deferring full decode to processing, is often the difference between scaling ingestion horizontally and hitting CPU saturation at the edge.

---

## 3. Raw log and archive

```
rawLog(topic) → durable, replayable stream                                  ⚙
├── partitions → sized for peak throughput + headroom (hard to change later)
├── replication → ≥ 3, minimum in-sync replicas ≥ 2
├── retention → days (hot replay window)
└── immutability → never edited, never compacted for raw topics

archiveRaw(rawLog) → objectStorage                                          ⚙ ↺
├── consume(raw topics)
├── batchByTimeAndSize(window, maxBytes) → files
├── writeColumnarOrCompressed(files, path=dataset/date/hour/)
├── commitOffsets (only after files durable)
└── catalog(files, offsets range)   (enables replay of exact ranges)
```

[Certain] The archive is your real source of truth for reprocessing. Topic retention will eventually expire, and any bug found after that window can only be fixed by replaying from the archive.

---

## 4. Stream processing

```
processStream(rawTopic) → outputTopics | sinks                              ▶ + ⚙
├── consume(rawTopic, consumerGroup)
│
├── perEvent
│   ├── deserialize(payload, schemaRegistry) → event            ⚠ → quarantine
│   ├── upcast(event, toLatestVersion) → event
│   ├── validateSemantics(event) → ok                           ⚠ → quarantine
│   ├── dedupe(eventId, windowState) → new | duplicate          (duplicate → drop + count)
│   ├── enrich(event, lookupTables) → enrichedEvent
│   │   └── lookups from local state (changelog-backed), never per-event remote calls
│   └── scrubPII(event, classification) → event
│
├── timeHandling
│   ├── assignEventTime(event.eventTime)
│   ├── generateWatermark(maxEventTime - allowedLateness)
│   └── lateEvent(event.eventTime < watermark)
│       ├── within grace → update window, emit correction
│       └── beyond grace → sideOutput(lateTopic)                 (never silently dropped)
│
├── statefulOperations                                                      ▶
│   ├── aggregate(window: tumbling | sliding | session, key) → results
│   ├── join(stream, table) → enriched           (table = compacted topic → local state)
│   ├── join(stream, stream, window) → matched   (bounded window, bounded state)
│   └── stateTTL(key) → expire idle keys       (unbounded state = eventual OOM)
│
├── stateManagement                                                         ⚙
│   ├── localStore + changelog topic          (rebuildable after crash/rebalance)
│   ├── standbyReplicas → faster failover
│   └── checkpoint(state, offsets) atomically
│
├── emit(results)
│   └── transactional produce(output, offsets)   (effectively-once inside the log)
│
└── operational
    ├── hotKeyDetection(key share > threshold) → alert
    │   └── mitigation: salt key + two-stage aggregation
    ├── lagMetric(consumerGroup) → autoscaling signal
    └── rebalance → cooperative (avoid stop-the-world pauses)
```

[Certain] Any per-event remote call inside a stream processor (database lookup, HTTP enrichment) caps your throughput at that dependency's capacity and couples your lag to its latency. Load reference data as a compacted topic into local state instead.

---

## 5. Sinks

```
writeSink(results, sinkSpec) → committed                                    ⚙ + ▶
├── sinkType
│   ├── servingStore (low-latency reads)
│   │   └── idempotent upsert(key, value, version) → ignore if older version
│   ├── analyticsStore (columnar OLAP)
│   │   ├── batchInserts(size, interval)       (many tiny inserts kill columnar stores)
│   │   ├── dedupe on read or via replacing-merge engine keyed on eventId
│   │   └── partition by time, order by query access pattern
│   └── lake (object storage tables)
│       ├── write files → commit via table format transaction
│       ├── compact small files periodically
│       └── partition by date (+ tenant if needed), never high-cardinality columns
├── commitOffsets(after sink acknowledges)
├── onSinkUnavailable
│   ├── pause consumption (lag grows, data safe in log)
│   └── never buffer unboundedly in memory
└── recordFreshness(sink, maxEventTime landed) → freshness SLO metric
```

---

## 6. Batch reprocessing and backfill

```
reprocess(dataset, range, reason) → newVersion                              ⚙
├── plan(range) → source (raw log if retained, else archive)
├── writeTo(outputVersion = v+1)              (never overwrite current in place)
├── run(sameCodeAsStreaming | batch equivalent)
│   ├── chunked, checkpointed, throttled
│   └── isolated resources (backfill must not starve live pipeline)
├── validate(v+1 vs v) → counts, totals, sample diffs           ⚠ abort
├── swap(readers → v+1)                       (atomic pointer / view switch)
├── retain(v) for rollback window
└── record(lineage: range, code version, reason)
```

[Likely] Running the same transformation code for streaming and backfill (one codebase, two execution modes) prevents the slow drift where historical numbers and live numbers disagree and nobody can say which is right.

---

## 7. Data quality

```
qualityChecks(dataset, stage) → pass | warn | fail                          ⚙ + ▶
├── schema → matches contract
├── freshness → max eventTime within SLO
├── volume → within expected band (vs same hour last week)
├── completeness → null rate per field within threshold
├── uniqueness → duplicate eventId rate
├── validity → value ranges, enums, referential integrity
└── reconciliation → source count ≈ sink count (per window)

onFail(check, severity)                                                     ⚙
├── quarantine(records) → quarantine table with reason
├── circuitBreaker(publish downstream) → hold the batch, don't propagate bad data
├── alert(owner) with lineage → which consumers are affected
└── replayQuarantine(fixed) → reinject after fix
```

---

## 8. Orchestration and lineage

```
orchestrate(batchJobs) → runs                                               ⚙
├── declareDependencies(job → upstream datasets, not upstream jobs)
├── trigger on data availability (partition landed), not on wall-clock alone
├── retries with backoff, idempotent tasks
└── SLA miss → alert with blocking upstream identified

lineage() → graph                                                           ⚙
├── capture automatically from job reads/writes (never hand-documented)
├── column-level where possible
└── impactAnalysis(change) → affected datasets, dashboards, models, owners
```

---

## 9. Privacy and deletion

```
privacyControls()                                                           ⚙
├── classifyAtIngest(fields) → drop | hash | encrypt | keep
├── encryptSensitive(field, subjectKey)    (per-user or per-tenant key)
├── deletionRequest(subjectId)
│   ├── live stores → delete / tombstone
│   ├── compacted topics → produce tombstone for key
│   ├── lake tables → row-level delete via table format + compaction
│   └── archive + backups → destroy subjectKey (crypto-shredding)
└── accessAudit(dataset, reader, purpose)
```

[Certain] Deleting one person's data from an immutable raw log and years of archive files is effectively impossible without per-subject encryption keys. This has to be designed in at ingestion; it can't be added later.

---

## 10. Capacity planning

```
capacityPlan(dataset) → sizing                                              ▶
├── peakEventsPerSecond × avgEventSize → bytes/sec in
├── × replication factor × retention → log storage
├── partitions ≥ peak throughput ÷ per-partition safe throughput
│   └── also ≥ max consumer parallelism you'll ever need
├── state size per processor → memory + local disk + restore time
├── restoreTime(state from changelog) → must be < acceptable recovery window
└── loadTest at 2× projected peak, with replay of real traffic shape
```

[Certain] Partition count is the one number you can't easily change later on a keyed topic. Increasing it reshuffles keys across partitions and breaks per-key ordering for anything in flight, so size it for the 3-year projection, not today's load.

What end-to-end freshness do the consumers of this pipeline actually need: seconds, minutes, or hours? That one answer decides whether trees 4 and 5 should be true streaming or micro-batch. Micro-batch is much cheaper to operate if minutes are acceptable.