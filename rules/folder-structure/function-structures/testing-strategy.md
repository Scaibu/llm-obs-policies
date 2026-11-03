The most pervasive testing mistake in distributed systems is building tests on synthetic database mocks that always return success. [Certain] Mocking PostgreSQL or Kafka verifies only your imagination of how the infrastructure behaves, hiding real-world syntax errors, lock contention, constraint violations, and transaction rollbacks until production deployment.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Multi-Tier Verification Strategy

```
testStrategy(service)                                                       ▶ + ⚙
├── Tier 0: Pure Unit Tests → Domain rules, state machines, math (ZERO I/O, <1ms)
├── Tier 1: Repository Tests → Real database container (testcontainers), zero mocks
├── Tier 2: Contract Tests
│   ├── Provider Verification → Ensure implementation satisfies OpenAPI / Protobuf
│   └── Consumer Verification → Validate client expectations against provider contracts
├── Tier 3: Component Tests → Whole service booted locally, real DB/Kafka, downstream HTTP mocked
├── Tier 4: Idempotency Tests → Submit every write endpoint twice; assert exactly one state effect
├── Tier 5: Chaos / Fault-Injection → Kill network / DB mid-transaction, assert recovery & fencing
├── Tier 6: Migration Verification → Apply DDL against production-scale data clone, assert lock < 2s
└── Tier 7: Load & Concurrency Tests → Execute peak TPS against local runner, assert p99 SLOs
```

---

## 2. Idempotency & Concurrency Verification Test Pattern

Every mutating API endpoint must execute an automated concurrency and double-click test:

```
testIdempotency(endpoint, payload, idempotencyKey)                           ▶
├── Worker A: POST endpoint with idempotencyKey
├── Worker B: POST endpoint with SAME idempotencyKey (simultaneous concurrent request)
├── Worker C: POST endpoint with SAME idempotencyKey (delayed sequential retry)
└── Assertions:
    ├── Worker A succeeds with HTTP 200/201
    ├── Worker B either receives HTTP 409 (Retry-After) or identical HTTP 200 response
    ├── Worker C receives identical cached HTTP 200 response
    └── Database direct assertion: exactly ONE entity created, zero duplicate rows
```

---

## 3. Strict Testing Invariants

1. **Zero Database Mocks**: Testing repository adapters with `sqlmock` or in-memory SQLite pretending to be PostgreSQL is strictly prohibited. All persistence tests must run against real PostgreSQL instances via Docker or local engines.
2. **Deterministic Test Isolation**: Every integration test must create its own isolated tenant (`tenantId = uuid.New()`) or execute inside an auto-rollback transaction to prevent cross-test state leakage.
3. **Contract Enforcement in CI**: Any pull request that introduces an OpenAPI schema breaking change without version bumping must automatically fail CI.

