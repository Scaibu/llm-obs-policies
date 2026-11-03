The most frequent cause of database death under traffic spikes is cache stampedes caused by un-jittered TTLs and un-coalesced concurrent cache misses. [Certain] Single-flight request deduplication and randomized TTL jitter are mandatory; without them, a single expired popular key will dump thousands of concurrent database queries at the same millisecond.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Cache Specification Contract

```
defineCache(name) → cacheSpec                                               ▶
├── key() → "tenant:{t}:entity:{id}:v{schemaVersion}"
├── ttl() → baseDuration + randomizedJitter (±15%)
├── staleness() → max acceptable staleness for background refreshes
├── invalidation() → ttl-only | on-write | on-event
└── negativeCaching() → yes (short ttl, e.g. 5s) | no
```

---

## 2. Read-Through & Single-Flight Coalescing

```
readThrough(context, key, loader) → value                                   ⚙
├── get(cache, key) → hit | miss                  ⚠ cache down → fallback to loader
├── hit and fresh → return value
├── hit and stale-but-allowed → return value + refreshAsync(key, loader)
├── miss → singleFlight(key, loader)              (exactly one load per key across concurrent calls)
│   ├── loader(context) → value                                 ⚠
│   └── set(cache, key, value, ttl + jitter)
└── recordMetrics(hit | miss | stale)                                       ⚙
```

---

## 3. Invalidation Strategy

```
invalidate(event) → keysDeleted                                             ⚙
├── deriveKeys(event) → keys
├── delete(keys)            (delete from cache, NEVER update: avoids write-race overwrites)
└── on failure → log error, rely on base TTL expiration, record metric
```

---

## 4. Strict Caching Invariants

1. **Mandatory Single-Flight on Misses**: Concurrent requests for the same missing key must wait on a shared promise/future rather than simultaneously hitting the database.
2. **Invalidate by Deletion Only**: Never update a cache key directly upon mutation (`set(k, v)`). Always issue a delete (`del(k)`) so subsequent reads repopulate atomically from the source of truth, eliminating write-ordering races.
3. **Mandatory Tenant Prefixing**: All cache keys must be scoped with the tenant identifier (`tenant:{tenantId}:...`) to make cache poisoning and cross-tenant leakage impossible.

