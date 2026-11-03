---
agent_role: "Distributed Systems Quality & Test Engineering Compliance Enforcer"
trigger: "ON_REFERENCE | ON_CONTEXT_LOAD | ON_TEST_CREATION | ON_VERIFICATION"
scope: "Unit Tests, Integration Tests, End-to-End Tests, Scenario Tests, Performance/Benchmark Tests, Load Tests, Production & Real Infrastructure Verification"
mode: "Strict"
contract_version: "2.1"
enforcement: "Absolute & Non-Negotiable"
---

# Production Testing & Infrastructure Verification Specification (`rules/folder-structure/09-test-writing.md`)

> **Architectural Separation Principle:**  
> Synthetic in-memory mocks give developers a false sense of security while hiding the real failure modes of distributed systems (network partitions, connection pool exhaustion, transaction deadlocks, SSRF guards, and CAS race conditions).
> 
> Testing MUST be performed like a seasoned human engineer operating on real infrastructure, NOT an AI generating superficial mock unit tests:
> - **Unit Tests (`*.unit_test.go`):** Pure deterministic domain rules, state machine transitions, input schemas, and cryptographic hash computations. Offline, zero network, zero I/O, sub-millisecond execution.
> - **Integration Tests (`*.integration_test.go`):** Verified interactions across database adapters, schema migrations, and real repository layers using transactional isolation.
> - **End-to-End Tests (`*.e2e_test.go`):** In-process lifecycle verification connecting controllers, services, database engines, and dispatchers across full execution graphs.
> - **Scenario & Edge Case Tests (`*.scenario_test.go`, `*.edgecases_test.go`):** Deliberate adversarial injections: poisoned payloads, malformed JSON, network timeouts, duplicate event replays, and split-brain lease acquisitions.
> - **Performance & Benchmark Tests (`*.performance_test.go`):** High-throughput micro-benchmarks enforcing allocation quotas (`-benchmem`), zero GC thrashing in hot loops, and nanosecond latency budgets.
> - **Real Infrastructure Verification (`scripts/test/test.real.sh`):** Fully automated, self-contained shell verification launching production binaries against live PostgreSQL clusters and mock downstream services via HTTP/cURL, asserting wire-level semantics and physical database states with strict process trap teardown.
> - **Load & Concurrency Tests (`scripts/test/test.load.sh`):** High-concurrency stress testing pushing connection pools, lease pollers, and fencing tokens to saturation to verify stability, dead-letter capture, and absence of data corruption.

---

# PART I: STRICT GUARDRAILS (WHAT NOT TO DO AT ALL)

0. **STRICT NON-ASSUMPTION & REAL INFRASTRUCTURE INVARIANT**:
   - Strictly never assume that code that passes unit tests will function in production.
   - Always verify that real database check constraints, unique indexes, foreign keys, regex patterns, and network SSRF filters allow the test payloads.
   - Strictly never create synthetic mocks that bypass production validation rules.

These are non-negotiable negative constraints and architectural invariants. Systems, AI agents, and engineers MUST review these first before writing or running tests:

1. **NEVER Rely Exclusively on In-Memory Mocks:** Mocking everything obscures SQL syntax errors, type mismatches (e.g., UUID vs string), unique constraint violations, and transaction isolation anomalies. Every feature MUST have tests running against real PostgreSQL storage.
2. **NEVER Use Bare `sleep` for Asynchronous State Verification:** Distributed sagas and background pollers execute asynchronously. Using `sleep 2` or `sleep 5` creates flaky pipelines under CPU pressure and wastes CI runtime. All asynchronous assertions MUST poll using bounded retry loops with exponential backoff against the database or status API.
3. **NEVER Leave Orphaned Background Processes:** Test scripts that launch servers, proxies, or background daemons MUST trap all exit signals (`trap cleanup EXIT INT TERM ERR`) to kill child processes and delete temporary directories. Never leave ports locked after a test run fails.
4. **NEVER Hardcode Hostnames, Ports, or Credentials:** Test scripts and suites must read configuration from 12-factor environment variables (`PORT`, `ADMIN_PORT`, `MOCK_PORT`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`) with non-conflicting default values. Never assume port 8080 or 5432 is free.
5. **NEVER Bypass Production Security Controls in Tests:** Do not disable loopback/SSRF validators, authentication middleware, or fencing checks just to make a test pass. Tests must conform to real security policies (e.g., resolving a real hostname like `$(hostname)` rather than using blocked `127.0.0.1` when SSRF guards are active).
6. **NEVER Test Only the Happy Path:** Human engineers test what breaks. Tests must deliberately verify pre-pivot failure compensation, post-pivot retry policies, stale CAS version conflicts (HTTP 409), invalid input payloads (HTTP 400), cancellation mid-flight, and database failover.
7. **NEVER Share Unisolated State Across Test Runs:** Tests running concurrently must never mutate the same entity without isolation. Workflows and sagas must generate dynamic, unique IDs, timestamps, or tenant boundaries (`default_${RANDOM}`) to prevent foreign key and unique index collisions.
8. **NEVER Ship Unbenchmarked Critical Paths:** State machine transition loops, DAG topological sorters, and idempotency key derivations must have automated benchmarks verifying memory allocations (`0 allocs/op` or strictly bounded byte quotas).
9. **NEVER Ignore Clean Database Rollbacks and Cleanup:** Integration tests that populate database tables must either run within rolled-back transactions or cleanly truncate/partition test tables to ensure idempotency when executed repeatedly on developer machines.
10. **NEVER Conflate Unit Tests with Integration Tests:** Unit tests must run without external dependencies and complete in under 5 seconds for the entire repository. Slow network/database tests must be partitioned behind build tags (`//go:build integration`) or dedicated test scripts.

---

# PART II: THE TEST TAXONOMY & DIRECTORY HIERARCHY

Every feature within `src/features/<feature-name>/` and the project root MUST implement tests adhering to this exact directory structure:

```
distributed-transaction-engine/
├── scripts/
│   └── test/
│       ├── test.unit.sh          # Executes pure unit test suite across all features
│       ├── test.integration.sh   # Executes integration tests against database
│       ├── test.e2e.sh           # Executes E2E regression and benchmark suite
│       ├── test.real.sh          # Full automated live host verification with mock services
│       └── test.load.sh          # High-concurrency load and stress test harness
└── src/
    └── features/
        └── <feature-name>/
            └── tests/
                ├── <feature>.rules_test.go        # Pure unit tests (business invariants)
                ├── <feature>.schema_test.go       # Input validation & regex checks
                ├── <feature>.integration_test.go  # Database adapter & persistence tests
                ├── <feature>.e2e_test.go          # Feature-level end-to-end flows
                ├── <feature>.scenario_test.go     # Multi-step business scenarios
                ├── <feature>.edgecases_test.go    # Boundary conditions & adversarial inputs
                └── <feature>.performance_test.go  # Benchmark tests & allocation budgets
```

### Test Classification Matrix

| Test Type | Target Scope | External Dependencies | Execution Speed | Execution Frequency | Primary Command |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Unit** | Functions, domain rules, schemas | None (Pure offline) | < 1 ms / test | Pre-commit / every save | `go test -v ./src/features/... -run "Rules\|Schema"` |
| **Performance** | Hot execution loops, DAG sorting | None | 1-5 s / suite | Daily / Pre-release | `go test -bench=. -benchmem ./src/...` |
| **Integration** | DB adapters, queries, migrations | PostgreSQL instance | 50-200 ms / test | Pre-push / CI build | `./scripts/test/test.integration.sh` |
| **E2E (Code)** | Controllers -> Services -> Repos | In-memory / Mock DB | 100-500 ms / test | CI PR verification | `./scripts/test/test.e2e.sh` |
| **Scenario** | Multi-step saga compensation flows | Real / Mock Repos | 100-500 ms / test | CI PR verification | `go test -v -run "Scenario"` |
| **Edge Cases** | Timeouts, poisoned input, CAS race | In-memory / Real DB | 50-200 ms / test | CI PR verification | `go test -v -run "Edgecases"` |
| **Real Infra** | Compiled binary, HTTP API, DB, Mocks | Real Postgres, Network, Curl | 5-15 s total | CI Pipeline & Release Gate | `./scripts/test/test.real.sh` |
| **Load Test** | Concurrent worker pools, API stress | Live Service Cluster | 30-120 s total | Nightly / Pre-production | `./scripts/test/test.load.sh` |

---

# PART III: DETAILED SPECIFICATIONS BY TEST TYPE

## 1. Unit Tests (`*.rules_test.go`, `*.schema_test.go`)

### Purpose & Requirements
- Enforce business logic correctness, state machine mathematical properties, and input contract adherence.
- **Zero I/O:** Must never open files, network sockets, or database handles.
- **Table-Driven Design:** All test cases must use table-driven slices with explicit names, input payloads, expected outcomes, and expected error codes.

### Canonical Pattern
```go
package tests

import (
	"testing"
	"distributed-transaction-engine/src/features/workflow-definitions/contracts"
)

func TestWorkflowSchemaValidation(t *testing.T) {
	testCases := []struct {
		name          string
		input         contracts.CreateWorkflowDefinitionInput
		expectValid   bool
		expectedError string
	}{
		{
			name: "valid workflow definition",
			input: contracts.CreateWorkflowDefinitionInput{
				TenantID:      "default",
				Name:          "payment_flow",
				Version:       1,
				Source:        "web_console",
				ExternalID:    "ext_123",
				CorrelationID: "11111111-2222-3333-4444-555555555555",
				Steps: []contracts.StepDefinition{
					{
						StepID:             "charge_card",
						StepName:           "Charge Credit Card",
						IsPivot:            true,
						ActionType:         "HTTP",
						ActionEndpoint:     "https://api.payments.internal/charge",
						TimeoutSeconds:     10,
						MaxRetries:         3,
						Dependencies:       []string{},
					},
				},
			},
			expectValid: true,
		},
		{
			name: "reject empty externalId",
			input: contracts.CreateWorkflowDefinitionInput{
				TenantID:      "default",
				Name:          "payment_flow",
				Version:       1,
				Source:        "web_console",
				ExternalID:    "",
				CorrelationID: "11111111-2222-3333-4444-555555555555",
				Steps:         []contracts.StepDefinition{},
			},
			expectValid:   false,
			expectedError: "externalId cannot be empty",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			err := contracts.ValidateCreateWorkflowDefinitionInput(tc.input)
			if tc.expectValid && err != nil {
				t.Fatalf("expected valid input but got error: %v", err)
			}
			if !tc.expectValid {
				if err == nil {
					t.Fatalf("expected validation error but got nil")
				}
				if err.Error() != tc.expectedError {
					t.Fatalf("expected error '%s', got '%s'", tc.expectedError, err.Error())
				}
			}
		})
	}
}
```

---

## 2. Performance & Benchmark Tests (`*.performance_test.go`)

### Purpose & Requirements
- Verify that performance-critical operations (DAG sorting, CAS transitions, hash computations) do not create garbage collection pressure or latency regressions.
- Must run using `go test -bench=. -benchmem`.
- Must verify allocations per operation (`b.ReportAllocs()`).

### Canonical Pattern
```go
package tests

import (
	"testing"
	"distributed-transaction-engine/src/features/workflow-definitions/contracts"
)

func BenchmarkDAGTopologyValidation(b *testing.B) {
	steps := make([]contracts.StepDefinition, 20)
	for i := 0; i < 20; i++ {
		var deps []string
		if i > 0 {
			deps = []string{steps[i-1].StepID}
		}
		steps[i] = contracts.StepDefinition{
			StepID:         string(rune('a' + i)),
			StepName:       "Benchmark Step",
			IsPivot:        i == 19,
			ActionType:     "HTTP",
			ActionEndpoint: "https://api.internal/step",
			Dependencies:   deps,
		}
	}

	b.ResetTimer()
	b.ReportAllocs()

	for i := 0; i < b.N; i++ {
		_ = contracts.ValidateCreateWorkflowDefinitionInput(contracts.CreateWorkflowDefinitionInput{
			TenantID:      "default",
			Name:          "bench_workflow",
			Version:       1,
			Source:        "benchmark",
			ExternalID:    "ext_bench",
			CorrelationID: "11111111-2222-3333-4444-555555555555",
			Steps:         steps,
		})
	}
}
```

---

## 3. Integration Tests (`*.integration_test.go`)

### Purpose & Requirements
- Test direct interaction with real PostgreSQL adapters and repository implementations.
- Must verify real schema constraints:
  - Check constraints (e.g. `public_id ~ '^sga_[0-9a-zA-Z]{26}$'`).
  - Foreign key constraints (e.g. `fk_saga_instances_workflow`).
  - Unique keys (e.g. `(tenant_id, name, version)`).
  - Version fencing and optimistic concurrency locking (`fencing_token`, `expected_version`).

### Canonical Pattern
```go
package tests

import (
	"context"
	"database/sql"
	"testing"
	"time"

	"distributed-transaction-engine/src/features/saga-orchestration/contracts"
	"distributed-transaction-engine/src/features/saga-orchestration/infrastructure/adapters"
	_ "github.com/lib/pq"
)

func TestPostgresOptimisticLocking(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test in short mode")
	}

	db, err := sql.Open("postgres", "postgres://postgres:supersecretpgpassword@127.0.0.1:5432/dist_tx_engine?sslmode=disable")
	if err != nil {
		t.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	repo := adapters.NewPostgresSagaRepositoryAdapter(db)
	ctx := context.Background()

	instance := &contracts.SagaInstance{
		ID:                   "11111111-2222-3333-4444-555555555555",
		PublicID:             "sga_0123456789abcdef0123456789",
		TenantID:             "default",
		WorkflowDefinitionID: "22222222-3333-4444-5555-666666666666",
		WorkflowVersion:      1,
		SpecHash:             "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
		Source:               "integration_test",
		ExternalID:           "ext_test_opt_lock",
		InputHash:            "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
		CorrelationID:        "33333333-4444-5555-6666-777777777777",
		CurrentState:         contracts.SagaStateCreated,
		Version:              1,
		FencingToken:         0,
		DeadlineAt:           time.Now().Add(10 * time.Minute),
	}

	_ = repo.CreateSaga(ctx, instance)

	err = repo.UpdateSagaState(ctx, instance.TenantID, instance.ID, 1, contracts.SagaStateRunning)
	if err != nil {
		t.Fatalf("expected version 1 update to succeed, got: %v", err)
	}

	err = repo.UpdateSagaState(ctx, instance.TenantID, instance.ID, 1, contracts.SagaStateCompleted)
	if err == nil {
		t.Fatalf("expected stale version update to fail with CAS conflict, got nil")
	}
}
```

---

## 4. Scenario & Edge Case Tests (`*.scenario_test.go`, `*.edgecases_test.go`)

### Purpose & Requirements
- Model complete multi-step transaction journeys:
  - **Happy Path:** Steps execute in topological order -> pivot executes -> status `COMPLETED`.
  - **Pre-Pivot Failure:** Step 2 fails -> step 1 reverse compensated -> unstarted steps drained -> status `FAILED_COMPENSATED`.
  - **Post-Pivot Failure:** Step 2 (pivot) succeeded, step 3 fails -> retry forward indefinitely -> status `STUCK_FORWARD` or operator intervention.
  - **Saga Cancellation:** Cancel request arrives while step 1 in-flight -> drain unstarted -> compensate executed -> status `CANCELLED`.
  - **Split-Brain Lease Conflict:** Two workers claim the same saga -> second worker fence rejected via fencing token check.

---

## 5. Real Infrastructure Live Verification (`scripts/test/test.real.sh`)

### Purpose & Requirements
- **Human Engineer Standard:** A real human test script runs outside the Go test runner to verify actual system behavior over standard HTTP networking, using real processes, real curl calls, real database queries, and deterministic process lifecycle management.
- **Zero Leaks:** Must implement a mandatory `trap cleanup EXIT INT TERM ERR` routine that guarantees all child PIDs (engine binary, mock HTTP downstream servers, temp folders) are terminated and removed.
- **Readiness Polling:** Must actively probe `http://127.0.0.1:${ADMIN_PORT}/health/ready` until HTTP 200 is confirmed before sending traffic.
- **Asynchronous DB Convergence:** Must query the actual PostgreSQL database or status API with bounded retries to verify terminal state convergence.

### Architecture Blueprint (`scripts/test/test.real.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Environment & Dynamic Config (12-Factor Compliant)
PORT="${PORT:-8088}"
ADMIN_PORT="${ADMIN_PORT:-8089}"
MOCK_PORT="${MOCK_PORT:-9095}"
DOWNSTREAM_HOST="${DOWNSTREAM_HOST:-$(hostname)}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-supersecretpgpassword}"
DB_NAME="${DB_NAME:-dist_tx_engine}"
DB_SSLMODE="${DB_SSLMODE:-disable}"

TMP_DIR="$(mktemp -d)"
MOCK_PID=""
ENGINE_PID=""

# 2. Strict Process Cleanup Trap
cleanup() {
    local exit_code=$?
    if [[ -n "${ENGINE_PID}" ]] && kill -0 "${ENGINE_PID}" 2>/dev/null; then
        kill -TERM "${ENGINE_PID}" 2>/dev/null || true
        wait "${ENGINE_PID}" 2>/dev/null || true
    fi
    if [[ -n "${MOCK_PID}" ]] && kill -0 "${MOCK_PID}" 2>/dev/null; then
        kill -TERM "${MOCK_PID}" 2>/dev/null || true
        wait "${MOCK_PID}" 2>/dev/null || true
    fi
    rm -rf "${TMP_DIR}"
    exit ${exit_code}
}
trap cleanup EXIT INT TERM ERR

# 3. Inline Mock Downstream Engine (Python HTTP)
# Implements endpoints: /reserve, /charge, /compensate, /fail-step, /slow-step

# 4. Build Engine Binary
go build -o "${TMP_DIR}/engine-bin" ./src/main.go

# 5. Launch Daemon & Poll Deep Readiness
# Polls http://127.0.0.1:${ADMIN_PORT}/health/ready until HTTP 200

# 6. Execute Scenario Suite via curl:
# - Scenario 1: Admin probes & Prometheus /metrics verification
# - Scenario 2: Workflow registration & retrieval
# - Scenario 3: State machine initialization & CAS version enforcement (HTTP 409)
# - Scenario 4: Happy path end-to-end saga execution & DB assertion
# - Scenario 5: Pre-pivot failure & automatic reverse compensation (FAILED_COMPENSATED)
# - Scenario 6: In-flight saga cancellation (CANCELLED)
```

---

## 6. Load & Concurrency Tests (`scripts/test/test.load.sh`)

### Purpose & Requirements
- Verify system performance under sustained concurrent load:
  - Connection pool stability (ensuring PostgreSQL pool does not exhaust).
  - Background saga poller throughput under contention.
  - Zero deadlocks under concurrent lease acquisition (`FOR UPDATE SKIP LOCKED`).
  - Fencing token monotonicity under rapid worker failover.
- Must measure p50, p95, and p99 latency percentiles and error rates.

### Canonical Pattern (`scripts/test/test.load.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONCURRENCY="${CONCURRENCY:-20}"
TOTAL_REQUESTS="${TOTAL_REQUESTS:-500}"
TARGET_URL="http://127.0.0.1:8088/api/v1/sagas/execute"

echo "=== LAUNCHING LOAD TEST (${CONCURRENCY} workers, ${TOTAL_REQUESTS} requests) ==="

# Execute load runner (using hey, k6, or concurrent Go worker script)
python3 - << EOF
import concurrent.futures, requests, time, uuid

def submit_saga(i):
    url = "${TARGET_URL}"
    payload = {
        "tenantId": "default",
        "workflowName": "load_workflow",
        "workflowVersion": 1,
        "source": "load_test",
        "externalId": f"load_ext_{i}_{uuid.uuid4()}",
        "correlationId": str(uuid.uuid4()),
        "initialPayload": {"index": i}
    }
    start = time.time()
    resp = requests.post(url, json=payload, headers={"Content-Type": "application/json"})
    return resp.status_code, (time.time() - start) * 1000

with concurrent.futures.ThreadPoolExecutor(max_workers=${CONCURRENCY}) as executor:
    results = list(executor.map(submit_saga, range(${TOTAL_REQUESTS})))

statuses = [r[0] for r in results]
latencies = sorted([r[1] for r in results])

p50 = latencies[int(len(latencies) * 0.50)]
p95 = latencies[int(len(latencies) * 0.95)]
p99 = latencies[int(len(latencies) * 0.99)]

print(f"Results: Total={len(statuses)}, Success={statuses.count(202)}, Errors={len(statuses)-statuses.count(202)}")
print(f"Latency: p50={p50:.2f}ms, p95={p95:.2f}ms, p99={p99:.2f}ms")
EOF
```

---

# PART IV: HUMAN TESTING CHECKLIST VS AI MOCK CHECKLIST

Every pull request and architectural verification must be audited against this checklist to eliminate synthetic AI testing illusions:

| Testing Vector | Synthetic AI Approach (BANNED) | Real Human Engineer Approach (MANDATORY) |
| :--- | :--- | :--- |
| **Database** | Pure mock struct in memory returning pre-baked structs | Real PostgreSQL container verifying real SQL constraints, types, and indexes |
| **Async Operations** | Arbitrary `time.Sleep(3 * time.Second)` | Bounded exponential backoff loop polling terminal database state |
| **Downstream APIs** | Hardcoded function stubs | Real HTTP mock server verifying network requests, headers, and timeouts |
| **Error Handling** | Only happy path `err == nil` assertions | Chaos injection: HTTP 500 downstream, connection drops, stale CAS versions |
| **Process Lifecycles** | Leaves background daemons dangling on host | `trap cleanup EXIT INT TERM` killing all child PIDs and removing temp files |
| **Configuration** | Hardcoded `localhost:8080` and `postgres` password | 12-factor environment variables (`PORT`, `DB_HOST`, `DB_PASSWORD`) with overrides |
| **Security Validation** | Disables SSRF / loopback guards in test mode | Resolves local machine DNS hostname to satisfy production security checks |
| **Performance** | Assumes code is fast without measurement | Runs `-benchmem` micro-benchmarks verifying zero heap allocation in hot paths |
| **Concurrency** | Tests with a single sequential call | Runs concurrent worker pools pushing fencing tokens and lease locks to contention |

---

# PART V: CI/CD PIPELINE INTEGRATION STANDARD

Automated CI pipelines (GitHub Actions, GitLab CI) must execute the test suite in strict order of increasing resource cost:

```mermaid
flowchart LR
    A["Stage 1: Unit Tests<br/>(scripts/test/test.unit.sh)"] --> B["Stage 2: Benchmarks<br/>(go test -bench=.)"]
    B --> C["Stage 3: Integration Tests<br/>(scripts/test/test.integration.sh)"]
    C --> D["Stage 4: Real E2E Harness<br/>(scripts/test/test.real.sh)"]
    D --> E["Stage 5: Concurrency / Load<br/>(scripts/test/test.load.sh)"]
```

### Pipeline Failure Action Plan
1. If Stage 1 fails: Reject build immediately. Business rules or input schemas have broken.
2. If Stage 2 fails: Reject build if allocation budgets exceed thresholds. Memory leak introduced.
3. If Stage 3 fails: PostgreSQL migration or adapter query syntax error. Inspect SQL schema.
4. If Stage 4 fails: Runtime lifecycle, wiring, networking, or async poller defect. Inspect `engine.log`.
5. If Stage 5 fails: Concurrency deadlock, connection pool starvation, or lease lock collision.
