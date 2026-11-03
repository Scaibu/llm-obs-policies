The most common operational failure with configuration is requiring full process restarts for benign threshold tweaks while allowing unvalidated dynamic reloads to crash production instances. [Certain] Configuration changes must be layered deterministically, validated against a schema before swapping, and reject any non-reloadable field change without a clean process restart.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Configuration Schema Definition

```
defineConfig() → configSchema                                               ▶
├── field(name) → {type, default, required, secret, reloadable, range}
├── crossFieldRules() → [rule]      (e.g., tls.enabled=true → tls.certPath required)
└── perCommandNeeds() → which fields each command or CLI tool requires
```

---

## 2. Layered Resolution & Secret Hydration

```
resolveConfig(identity, command) → config                                   ⚙
├── layer 1: schema defaults
├── layer 2: fleet defaults (platform-owned centralized repository)
├── layer 3: environment overrides (production, staging, test)
├── layer 4: service overrides (remote config service stream)
├── layer 5: instance overrides (environment variables, CLI flags)
├── resolveSecrets(references) → values                         ⚠ EXIT_CONFIG
├── validate(config, schema, command) → errors                  ⚠ EXIT_CONFIG
└── fingerprint(config) → configVersion   (reported per instance via telemetry)
```

---

## 3. Dynamic Hot-Reloading Engine

```
onConfigChange(newConfig) → applied | rejected                               ⚙ ↺
├── validate(newConfig)                                         ⚠ → keep old config, alert
├── diff(oldConfig, newConfig) → changedFields
├── rejectIf(any changed field not marked reloadable) → reject, require restart ⚠
├── apply(changedFields) → atomic memory pointer swap
└── record(configVersion, changedFields)                        ⚙
```

---

## 4. Strict Configuration Invariants

1. **Deterministic Layer Precedence**: Configuration resolution must strictly follow: `Instance CLI > Env Vars > Remote Config > Environment File > Fleet Defaults > Schema Defaults`.
2. **Atomic In-Memory Swaps**: Reloadable configuration updates must swap an immutable configuration pointer atomically. Thread-unsafe partial field updates are strictly prohibited.
3. **Secret Separation**: Secrets must never be committed to source control or embedded in container image layers. All secret fields must be references resolved at boot via platform vault providers.

