The most dangerous operational failures occur when commands or database migrations are executed without dry-run guarantees, lock timeouts, or environment guards. [Certain] Running migrations on application pod startup guarantees race conditions during rolling deployments, while executing un-guarded destructive scripts in production causes irrecoverable data loss.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis
  ↺  registers cleanup
```

---

## 1. Operational Command Contract

```
defineCommand(name) → commandSpec                                           ▶
├── args() → typed arguments & flags
├── needs() → minimal dependency set (no full application boot)
├── destructive() → yes | no
├── supportsDryRun() → must be yes if destructive
└── resumable() → yes | no
```

---

## 2. Command Execution & Safety Gating

```
runCommand(commandSpec, args) → exitCode
├── parseArgs(args) → input                                       ⚙ ⚠ EXIT_USAGE
├── guardEnvironment(env, commandSpec) → allowed                  ⚙ ⚠ EXIT_USAGE
│   └── production + destructive → requires explicit confirmation token (--confirm=PROD_TOKEN)
├── compose(commandSpec.needs) → app                              ⚙
├── plan(input, app) → plan                                       ▶
├── dryRun? → printPlan(plan) → exit 0
├── execute(plan) with checkpoint + progress                      ▶ ⚠
├── auditLog(who, command, args, result)                          ⚙
└── decideExitCode(result) → exitCode
```

---

## 3. Database Migration Runner

```
runMigrations(db, migrationSet) → exitCode
├── acquireMigrationLock(db)                                      ⚙ ⚠ → wait or exit (timeout)
├── listPending(db, migrationSet) → pending
├── for each migration:
│   ├── setLockTimeout(2s)           (never queue live transactional locks for long)
│   ├── setStatementTimeout(30s)     (prevent runaway DDL table locks)
│   ├── apply(migration)                                          ⚠ → stop, report error
│   └── recordVersion(migration)
└── releaseMigrationLock(db)
```

[Certain] Migrations must never run during normal application container startup. With 20 replicas starting simultaneously in Kubernetes, they race for the migration lock, and any slow DDL operation stalls readiness probes across the entire fleet. Migrations must execute as dedicated pre-deploy CI/CD Kubernetes Jobs.

---

## 4. Zero-Downtime Expand-Contract Protocol

Any breaking schema mutation requires a phased deployment cycle:

```
schemaChange(expand → contract)   (one breaking change = multiple distinct deployments)
├── 1. expand:   Add new nullable column or new table in Postgres (no constraints yet)
├── 2. deploy:   Application code writes to both old and new schema
├── 3. backfill: Run chunked, rate-limited CLI command to backfill new column from old data
├── 4. deploy:   Application code switches reads exclusively to the new schema
├── 5. deploy:   Application code stops writing to the old schema
└── 6. contract: Drop old column / table in a final migration
```

---

## 5. Strict Operational Invariants

1. **Short DDL Lock Timeouts**: Every DDL migration must explicitly set `SET lock_timeout = '2s'` and `SET statement_timeout = '30s'`. Blocking transactional table locks in production cascades into connection pool exhaustion.
2. **Mandatory Dry-Run for Destructive Operations**: Any command marked `destructive: true` must support `--dry-run` to output execution plans before applying mutations.
3. **Audited Output**: All operational CLI executions must emit structured audit records with operator identity, git commit hash, arguments, and exit codes.

