# Checklist 06: Domain-Specific Systems (Exhaustive Verification)

**Source Reference**: [Domain-Specific Edge Cases (Parts 59–68)](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/domain-specific-edge-cases.md)  
**Scope**: Complete operational checklist across Double-Entry Ledgers, Payment Gateways, Multi-Tenant SaaS Metering, Offline Mobile Sync/CRDTs, ML/Data Pipelines, Messaging Delivery, and Principles 75–90.

---

## 1. Payments & Double-Entry Financial Ledgers (Part 60)

- [ ] **Immutable Double-Entry Accounting**:
  - [ ] Are all financial transactions recorded as immutable, append-only journal entries (never modifying existing rows with `UPDATE balance = ...`)?
  - [ ] Does every transaction enforce the zero-sum ledger balance constraint across debit and credit legs:
    $$\sum \text{Debits} - \sum \text{Credits} = 0$$
  - [ ] Are account balances computed as derived materialized projections from immutable ledger lines, and verified via periodic balance reconcilers?
  - [ ] Are financial corrections executed as distinct reversal/adjustment entries preserving audit history, never overwriting historical entries?
- [ ] **Currency Representation & Rounding Precision**:
  - [ ] Are currency amounts stored as integers in lowest minor units (cents, satoshis) or exact-precision numeric types (`NUMERIC(28, 8)`), with IEEE floating-point strictly forbidden?
  - [ ] Is rounding calculated using **Half-Even (Banker's Rounding)** to prevent statistical accumulation drift across high-volume transaction aggregations?
  - [ ] In multi-currency transactions, is the exchange rate (FX rate) and source timestamp frozen on the ledger entry at transaction time?
- [ ] **Payment Gateway Webhooks & Lifecycles**:
  - [ ] Are incoming webhook payloads cryptographically validated against gateway HMAC signatures before parsing?
  - [ ] Does webhook processing check and write an `idempotency_key` or gateway event ID in a transactional table before executing fulfillment?
  - [ ] Are out-of-order gateway webhooks (e.g. `charge.refunded` arriving before `charge.succeeded`) handled safely by transitioning through an explicit state machine?
- [ ] **Refund, Partial Capture & Dispute Races**:
  - [ ] Are concurrent refund requests locked using database-level constraints or pessimistic locks to prevent total refunds exceeding the original captured amount:
    $$\sum \text{Refunds} \le \text{Captured Amount}$$
  - [ ] Are pre-authorization hold expirations (e.g. 7-day card auth hold timeout) tracked and automatically released if settlement fails?

---

## 2. Multi-Tenant SaaS, Subscriptions & Metering (Part 61)

- [ ] **Hard Multi-Tenant Isolation**:
  - [ ] Is `tenant_id` verified from authenticated JWT claims and injected into query execution context, preventing client-supplied tenant ID spoofing?
  - [ ] Are shared computing resources (worker pools, rate limiters, DB connection pools) partitioned per tenant to prevent noisy neighbor degradation?
- [ ] **Usage Metering & Event Ingestion**:
  - [ ] Are usage events (API calls, storage GBs, tokens consumed) ingested with unique `event_id` keys to ensure idempotent deduplication?
  - [ ] Do usage aggregation pipelines account for late-arriving logs using tumbling or sliding time windows with watermark buffers?
- [ ] **Proration, Timezones & Billing Cycles**:
  - [ ] Are subscription upgrades, downgrades, and cancellations calculated based on normalized UTC timestamps?
  - [ ] Are monthly billing cycle resets resilient to 28/29/30/31-day month length variations and Daylight Saving Time shifts?
  - [ ] Are failed renewal payment retries (dunning schedules) managed via state machines with defined grace period expirations?
- [ ] **Credit Balances & Quota Enforcement**:
  - [ ] Are prepaid credit decrements executed atomically in the database (`UPDATE credits SET balance = balance - :cost WHERE id = :id AND balance >= :cost;`) to prevent concurrent credit overdraft exploits?

---

## 3. Mobile, Offline-First & Sync Engines (Part 62)

- [ ] **Deterministic Conflict Resolution & CRDTs**:
  - [ ] Are offline concurrent mutations resolved using Conflict-Free Replicated Data Types (CRDTs) or explicit deterministic merge policies, never relying on naive client-timestamp Last-Write-Wins (LWW)?
- [ ] **Tombstone Lifecycle & Deletion Propagation**:
  - [ ] When an entity is deleted offline, is it recorded as a soft-deleted tombstone with a sync timestamp so that all authorized client devices receive the deletion instruction during sync?
  - [ ] Are tombstones garbage-collected only after an upper-bound retention window (e.g. 90 days), with dormant devices required to perform a full re-sync?
- [ ] **Zero Trust for Client Clocks**:
  - [ ] Does the server reject or overwrite client-generated timestamps for data ordering, issuing authoritative server sequence numbers and sync cursors?
- [ ] **Multi-Version Backward Compatibility**:
  - [ ] Does the sync backend support payload schemas from older client app versions ($V-3$) that have not yet updated?
  - [ ] Is a remote kill switch and forced-upgrade mechanism implemented in mobile clients for emergency protocol deprecation?

---

## 4. Data Pipelines, Analytics & Machine Learning (Part 63)

- [ ] **Late-Arriving Data & Streaming Watermarks**:
  - [ ] Do stream processing engines (Flink, Spark Streaming) configure bounded watermarking to accept and process late-arriving out-of-order events without silently discarding data?
- [ ] **Idempotent Pipeline Backfills**:
  - [ ] Are analytical backfill and batch replay pipelines designed to execute partition overwrites (`INSERT OVERWRITE`) rather than naive appends, preventing duplicate historical rows?
- [ ] **Schema Drift in Data Lakes**:
  - [ ] Are Parquet/Delta/Iceberg tables configured with schema evolution controls that reject unvalidated type conversions or incompatible column drops?
- [ ] **ML Training-Serving Feature Parity**:
  - [ ] Is feature engineering logic shared or identically verified between real-time serving pipelines and offline batch training pipelines?
  - [ ] Are automated monitors tracking feature distribution drift (Kolmogorov-Smirnov test, Population Stability Index / PSI) and prediction drift in production?
- [ ] **Model Feedback Loop Poisoning**:
  - [ ] Are model predictions segregated from ground-truth training labels to prevent automated models from training on their own synthetic outputs?

---

## 5. Notifications & Messaging Delivery (Part 64)

- [ ] **Cross-Channel Deduplication**:
  - [ ] Are multi-channel notifications (email, SMS, push) coordinated through a central notification coordinator to prevent flooding users across multiple channels during retries?
- [ ] **Timezone-Aware Quiet Hours**:
  - [ ] Are non-critical transactional or marketing notifications deferred when the recipient's local civil time falls within overnight quiet hours ($10\text{ PM} – 8\text{ AM}$)?
- [ ] **Unsubscribe & Opt-Out Enforcement at Final Delivery Hop**:
  - [ ] Is recipient opt-out / unsubscribe status checked immediately before handing off to third-party delivery providers (SendGrid, Twilio, APNs), preventing queued messages from bypassing recent unsubscribes?
- [ ] **Bounce & Reputation Webhook Ingestion**:
  - [ ] Are hard bounces and spam complaints ingested via provider webhooks and written to a suppression table to protect sender domain reputation?

---

## 6. Principles 75–90 Operationalized (Part 68)

- [ ] Write domain invariants in plain language and enforce them at the lowest authoritative layer.
- [ ] Store immutable events and entries; derive balances and states as rebuildable views.
- [ ] Treat corrections as new audit facts, never mutating historical truth.
- [ ] Combine third-party webhook receivers with periodic out-of-band reconciliation pulls.
- [ ] Reconcile domain state against independent sources on a schedule in both directions.
- [ ] Model every domain lifecycle as an explicit state machine with timeouts on intermediate states.
- [ ] Gate irreversible operations with preview windows, sanity limits, and approval workflows.
- [ ] Design for the oldest supported client version and longest expected offline sync duration.
- [ ] Select explicit conflict merge strategies per data type, avoiding accidental data loss.
- [ ] Never trust device or partner clocks for business ordering—use server-issued cursors.
- [ ] Maintain feature extraction parity between ML training and real-time inference.
- [ ] Monitor domain behavior, feature distributions, and business outcomes alongside system health.
- [ ] Ensure system rollbacks restore matching data schemas, prompts, and configurations.
- [ ] Maintain human accountability, explanation, and appeal pathways for automated decisions.
- [ ] Separate transactional and promotional message streams to isolate delivery reputation.
- [ ] Assign clear organizational ownership to every seam between teams, services, and external APIs.
