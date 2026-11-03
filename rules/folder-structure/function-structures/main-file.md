```
Legend
  name(inputs) → output
  ⚠  can fail      ↺  registers cleanup      ▶  service-owned code
  ✚  required at 100+ services, missing from the single-service tree
```

**Tree 1: each service's main file (the only part teams write)**

```
main(args, env)
└── exit( chassis.run(describeService(), args, env) )

describeService() → serviceSpec
├── identity() → {name, team, tier}
├── needs() → {db, cache, producer, consumer, flags}
├── dependsOn() → [downstream services + criticality: hard | soft]        ✚
├── contracts() → {apiSchemas, producedTopics, consumedTopics}            ✚
├── buildServices(deps) → services                                        ▶
├── registerApiRoutes(router, services)                                   ▶
├── registerConsumers(group, services)                                    ▶
├── jobs() → [jobSpec]                                                    ▶
└── migrations() → migrationSet                                           ▶
```

**Tree 2: the chassis (owned by the platform team, versioned, one copy)**

```
chassis.run(spec, args, env) → exitCode
├── preflight(args) → bootContext
│   ├── readBuildInfo() → {version, commit, chassisVersion}               ✚
│   ├── createBootstrapLogger() → bootLogger
│   ├── installCrashHandler(bootLogger)
│   ├── createRootContext() → rootContext
│   ├── createLifecycle() → lifecycle
│   ├── resolveCommand(args) → command                                ⚠ EXIT_USAGE
│   └── resolveWorkloadIdentity() → identity                          ✚ ⚠ EXIT_CONFIG
│       └── (workload certificate / platform identity, basis for mTLS)
│
├── configure(bootContext, spec) → config
│   ├── loadLocalConfig(args, env) → baseConfig
│   ├── fetchRemoteConfig(configService, identity) → remoteConfig     ✚ ⚠
│   │   └── unreachable → use last-known-good cache, else fail
│   ├── loadSecrets(identity) → secrets                               ⚠ EXIT_CONFIG
│   ├── validateConfig(config, spec, command) → errors                ⚠ EXIT_CONFIG
│   └── watchDynamicConfig(configService) → configStream              ✚ ↺
│       └── (only keys marked reloadable: limits, timeouts, log level)
│
├── compose(rootContext, config, spec, lifecycle) → app               ⚠ EXIT_DEPENDENCY
│   ├── applyStartupJitter(config.jitterWindow)                       ✚
│   │   └── (fleet restart must not hit DB/broker with 5,000 connects at once)
│   ├── initTelemetry(config, identity, buildInfo) → telemetry              ↺
│   │   └── applyStandardConventions(serviceName, tier, team, version)    ✚
│   ├── initFeatureFlags(config, identity) → flags                          ↺
│   │   └── registerKillSwitches(spec.dependsOn)                      ✚
│   ├── initSecurity(identity) → security                                   ↺
│   │   ├── createMtlsConfig(identity) → tlsConfig                    ✚
│   │   ├── createPeerAuthorizer(config) → peerPolicy                 ✚
│   │   └── createTokenVerifier(config) → verifier
│   ├── connectInfrastructure(spec.needs, config) → infra
│   │   ├── connectDatabase(viaPooler, computedPoolSize) → db               ↺ ⚠
│   │   │   └── (pool size from fleet budget, not per-team guess)     ✚
│   │   ├── connectCache(config) → cache                            ↺ (soft)
│   │   ├── connectProducer(config, schemaRegistry) → producer              ↺ ⚠
│   │   └── createIdempotencyStore(db | cache) → idempotencyStore
│   ├── createDownstreamClients(spec.dependsOn, security) → clients   ✚
│   │   └── for each downstream:
│   │       ├── resolveViaDiscovery(serviceName) → endpoints
│   │       ├── withMtls(tlsConfig)
│   │       ├── withDeadlinePropagation()                      (budget shrinks per hop)
│   │       ├── withRetryBudget(maxRatio)                      (not a fixed retry count)
│   │       ├── withCircuitBreaker(config)
│   │       ├── withBulkhead(maxConcurrent)
│   │       └── never block startup on a peer service — soft at boot, always
│   ├── checkSchemaVersion(infra.db)                                        ⚠
│   ├── checkContractCompatibility(spec.contracts, schemaRegistry)    ✚ ⚠
│   ├── spec.buildServices(infra, clients, flags, telemetry) → services      ▶
│   ├── buildJobs(spec.jobs) → jobs
│   └── buildHealth(infra, clients) → health
│       └── readiness ignores soft downstreams                         ✚
│
├── wireCommand(command, app, lifecycle) → mode
│   ├── wireServe(app, lifecycle) → LONG_RUNNING
│   │   ├── wireAdmin(app, lifecycle)
│   │   ├── buildApiServer(app) → apiServer
│   │   │   ├── buildStandardMiddleware(app) → middleware
│   │   │   │   ├── recover → requestId → trace → metrics/log
│   │   │   │   ├── adaptiveLoadShedding(concurrencyLimit)            ✚
│   │   │   │   ├── extractDeadline(incoming)                         ✚
│   │   │   │   ├── authenticatePeer(mtls) + authenticateUser(token)  ✚
│   │   │   │   ├── authorize(policy)
│   │   │   │   └── attachTenantAndFlagContext(flags)                 ✚
│   │   │   └── spec.registerApiRoutes(router, app.services)                 ▶
│   │   ├── lifecycle.addComponent("api", apiServer.start, apiServer.drain)
│   │   └── wireJobs(app, lifecycle)
│   │
│   ├── wireWorker(app, lifecycle) → LONG_RUNNING
│   │   ├── wireAdmin(app, lifecycle)
│   │   ├── buildConsumerGroup(app, schemaRegistry) → group
│   │   │   ├── standardConsumerWrapping()   (retry, DLQ, idempotency, tracing)
│   │   │   ├── exportLagMetric() → autoscalerSignal                  ✚
│   │   │   └── spec.registerConsumers(group, app.services)                  ▶
│   │   ├── lifecycle.addComponent("consumers", group.start, group.drainAndCommit)
│   │   └── wireJobs(app, lifecycle)
│   │
│   ├── wireMigrate(app) → RUN_ONCE
│   │   └── runMigrations(spec.migrations(), app.infra.db)   ▶ ⚠ EXIT_DEPENDENCY
│   │
│   ├── wireJob(app, jobName) → RUN_ONCE
│   │   └── runJob(jobName, app.services)                     ▶ ⚠ EXIT_RUNTIME
│   │
│   ├── wireAdmin(app, lifecycle)
│   │   └── standard endpoints: /healthz /readyz /metrics /debug /buildinfo  ✚
│   │
│   └── wireJobs(app, lifecycle)
│       └── each job: addComponent(job, withLeaderElection(job), job.stop)
│
├── runLongLived(rootContext, app, lifecycle) → stopReason
│   ├── lifecycle.startAll(rootContext)                              ⚠ EXIT_RUNTIME
│   ├── warmUp(app)
│   ├── app.health.setReady(true)
│   ├── registerWithDiscovery(identity, endpoints)                    ✚ ↺
│   │   └── (skip if platform/mesh does this from readiness)
│   ├── reportFleetMetadata(version, chassisVersion, configVersion)   ✚
│   └── lifecycle.waitForStop() → stopReason
│
└── shutdown(app, lifecycle, stopReason) → exitCode
    ├── deregisterFromDiscovery()                                     ✚
    ├── app.health.setReady(false)
    ├── waitForDrain(config.drainDelay)
    │   └── (sidecar/mesh proxy must outlive the app; drain app first)  ✚
    ├── lifecycle.stopAll(config.shutdownTimeout) → errors           ⚠ EXIT_TIMEOUT
    └── decideExitCode(stopReason, errors) → exitCode
```

Three things that break specifically at 100+ services:

- **Connection math.** [Certain] Pool sizes multiply: 100 services × 20 replicas × a pool of 20 is 40,000 connections, and databases fall over long before that. Pool sizes have to come from a fleet budget behind a connection pooler, not from each team's config.
- **Retry storms.** [Certain] A fixed "retry 3 times" at each of 4 hops turns one failed request into up to 256 attempts (4⁴) on the deepest service. `withRetryBudget` caps retries as a fraction of total traffic, which is what stops a cascade.
- **Startup coupling.** [Likely] If service A refuses to boot until service B is healthy, a full-fleet restart can deadlock or take hours. That's why peers are soft at boot, and only your own database and broker can be hard dependencies.

The chassis itself needs a versioning and rollout policy, which is why `chassisVersion` is reported per instance. Do you already have a platform team, or a shared library that every service imports? If not, building that is the real first task, not the main file.