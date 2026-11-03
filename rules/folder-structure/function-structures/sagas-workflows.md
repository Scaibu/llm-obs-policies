The fundamental misconception with distributed sagas is treating compensations as database rollbacks. [Certain] Once a side effect leaves a service (credit card charged, email sent, warehouse inventory allocated), you cannot undo physical reality; you can only execute an explicit semantic compensating business transaction (issue refund, send cancellation email, release allocation).

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Saga Specification Contract

```
defineSaga(name) → sagaSpec                                                 ▶
├── steps() → [step]
│   └── step(name) → {action, compensation, timeout, retryPolicy, isPivot}
├── idempotencyKey() → derived deterministically from business identifier
└── ordering() → sequential | DAG parallel groups
```

---

## 2. Distributed Saga Orchestration Engine

```
runSaga(sagaSpec, input) → outcome                                          ⚙
├── startOrResume(sagaId) → state             (durable state machine in PostgreSQL)
├── for each step in executionPlan:
│   ├── execute(step.action, idempotencyKey + ":" + step.name)  ⚠
│   │   ├── transient error → retry per backoff policy
│   │   └── permanent error → beginCompensation(sagaId)
│   └── persistStepJournal(sagaId, step, result)
├── compensate() → reverse topological order over SUCCEEDED steps
│   ├── execute(step.compensation, idempotencyKey + ":comp:" + step.name) ⚠
│   └── compensation fails repeatedly → mark COMPENSATION_STUCK + page operator
└── emit(saga.completed | saga.failed_compensated | saga.paused_poison)     ⚙
```

---

## 3. The Pivot Step & Idempotency Guarantee

```
Step Execution Classification                                               ▶
├── Pre-Pivot Steps: Reversible actions (e.g. reserving inventory, validating credit)
│   └── Failure triggers automatic reverse compensation
├── The Pivot Step: The point of no return (e.g. charging credit card)
│   └── Once committed, saga MUST complete forward; compensation is strictly impossible
└── Post-Pivot Steps: Non-failable follow-ups (e.g. creating invoice, sending confirmation)
    └── Failure triggers durable retries until eventual success, never compensation
```

---

## 4. Strict Saga Invariants

1. **Deterministic Step Idempotency**: Every forward and compensating network dispatch must carry a deterministic idempotency key formatted as `sga_{saga_id}:{step_name}:{attempt}`.
2. **Postgres-Fenced State Machine**: Saga state transitions must be enforced in PostgreSQL via atomic Compare-And-Swap statements with fencing tokens (`WHERE id = :id AND version = :version`). In-memory-only saga states are strictly forbidden.
3. **Quarantine on Poison Loops**: A saga that fails takeover or step reconciliation repeatedly ($\ge 5$ attempts) must transition directly to `PAUSED_POISON` and quarantine to prevent cluster-wide restart storms.

