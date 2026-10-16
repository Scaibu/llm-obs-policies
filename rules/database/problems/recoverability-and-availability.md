# Category 4: Recoverability and availability

**Problem statement:** Hardware, software, humans, and whole regions fail. The system must restore correct state within a data-loss bound (RPO) and a time bound (RTO). The dangerous failures are the ones nobody tested: a mechanism exists on paper, but its guarantee was never proven.

**Subproblems:** 4A data safety and restore. 4B failover correctness. 4C slow-burn failure.

## 4A. Data safety and restore

#### 4.1 "We have replication and failover, so we're safe" (was #24) [Certain]
- **Why wrong:** Replication copies damage instantly, and a bad DELETE, corruption, or ransomware replicates to every replica.
- **What is correct:** High availability keeps service up through component failure, and recoverability restores correct state after data is damaged. They are different mechanisms.
- **Problem it creates:** Fast, consistent loss of data with no way back.
- **First-principles fix:** Define RPO and RTO per dataset. Add point-in-time recovery (base backups plus continuous log archive), isolate backups from production credentials, and rehearse restoring to a chosen moment.
- **Meta:** Which failure does each mechanism cover, and which does it not? What is the oldest damage I could still recover from?
- **Second-order:** What does PITR retention cost? A restore to a past point loses later legitimate writes, so how would I reapply them?

#### 4.2 "Backups are fine if the job exits successfully" (was #62) [Certain]
- **Why wrong:** A job can succeed while producing unusable backups, and logical corruption flows into them unnoticed.
- **What is correct:** A backup is proven only by a restore.
- **Problem it creates:** Discovering during an incident that backups are empty, incomplete, corrupt, or too slow to restore.
- **First-principles fix:** Automate restores into a scratch environment, run integrity and business checks (row counts, checksums, sentinel records), and measure restore time against RTO. Keep retention longer than your time-to-detect, and keep immutable off-account copies.
- **Meta:** When did I last restore, and how long did it take? How long until I'd notice silent corruption?
- **Second-order:** Does restore testing expose production data to a less-protected environment? Will restore time outgrow the RTO as data grows?

#### 4.3 "Multi-AZ is disaster recovery" (was #63) [Certain]
- **Why wrong:** Multi-AZ covers instance and zone failure only.
- **What is correct:** Failure domains nest (instance, zone, region, account, provider, human, software), and each needs a recovery path.
- **Problem it creates:** Region outages, account compromise, and accidental deletion have no answer.
- **First-principles fix:** List failure classes with likelihood and cost, choose a mechanism and target for each (cross-region replica or backup, separate-account copy, delete protection), and drill the ones you can't afford to get wrong.
- **Meta:** Which failure classes have no mechanism? Who can delete everything with one credential?
- **Second-order:** Does cross-region replication add lag and cost? Does account separation complicate restores during an incident?

#### 4.4 "If the database recovers, the system recovers" (was #67) [Likely]
- **Why wrong:** State lives in queues, caches, object storage, secrets, and configs, and a restored database may disagree with them.
- **What is correct:** Recovery must produce a mutually consistent set of stores.
- **Problem it creates:** A restored database referencing missing objects, queues replaying already-applied events, stale caches.
- **First-principles fix:** Inventory every stateful component and mark each as source of truth or derived. Define a recovery order and a consistency anchor (a restore timestamp or LSN), make consumers idempotent for replay, and rebuild derived stores from the source.
- **Meta:** Which stores are sources of truth? What happens to messages in flight at the restore point?
- **Second-order:** Can derived stores really be rebuilt within RTO? What do clients holding state from the "future" do?

## 4B. Failover correctness

#### 4.5 "Automatic failover is safer than manual" (was #61) [Likely]
- **Why wrong:** Failover is a distributed decision under uncertainty, and its safety depends on never having two writers.
- **What is correct:** Promotion is safe only after the old primary is provably unable to write.
- **Problem it creates:** Split-brain, flapping, and promotion of a lagging replica, all of which cause data loss or corruption.
- **First-principles fix:** Use a consensus-backed orchestrator with quorum agreement. Fence the old primary (revoke network or storage access, or power it off) before promoting, promote the most caught-up replica, and set detection timeouts above transient blip duration.
- **Meta:** How do I know the old primary is really down? What is the worst data loss at promotion, and is it acceptable?
- **Second-order:** What if the fencing action itself fails? What does the application do during the failover window?

#### 4.6 "Synchronous replication means zero data loss" (was #60) [Likely]
- **Why wrong:** The loss bound equals the acknowledged durability point plus the failure combinations tolerated.
- **What is correct:** "Synchronous" is a family of settings (received, flushed, applied), and behavior when the standby disappears is a separate decision.
- **Problem it creates:** Writes block when the standby is down, or silently degrade to async, and acknowledgment can precede durable flush.
- **First-principles fix:** Define the RPO, choose the sync level and quorum to meet it, decide explicitly what happens when no standby is available (block or degrade) and alert on degraded mode, and test by killing nodes mid-write.
- **Meta:** What exactly is acknowledged to the client? What happens when the sync standby is unreachable?
- **Second-order:** How much write latency does cross-zone sync add? Does blocking on standby loss create an availability problem?

#### 4.7 "The failover target is as capable as the primary" (was #65) [Likely]
- **Why wrong:** Standbys are often smaller, run different configuration, and have cold caches.
- **What is correct:** A standby is a production system that hasn't been given traffic yet.
- **Problem it creates:** Promotion meets RTO on paper and then collapses under full load.
- **First-principles fix:** Match instance size and configuration, warm the cache (read traffic or periodic warm-up), load-test promotion, and check capacity against peak.
- **Meta:** Could the standby carry today's peak? How long until its cache is warm?
- **Second-order:** Does equal sizing double cost? If I use the standby for reads, how does that change failover behavior?

#### 4.8 "Active-active multi-region is free availability" (was #64) [Likely]
- **Why wrong:** Concurrent writers need a conflict rule, and the speed of light bounds synchronous agreement across regions.
- **What is correct:** Multi-region writes trade availability against consistency and latency, and the conflict rule is a business decision.
- **Problem it creates:** Lost updates under last-write-wins, anomalies, high commit latency under consensus.
- **First-principles fix:** Partition ownership so each entity has a home region (others read or forward writes), or use a consensus database and accept cross-region commit latency. Define merge semantics (CRDT or domain rules) for any multi-writer data.
- **Meta:** Which entities truly need writes in multiple regions? What is my conflict rule, and is data loss acceptable under it?
- **Second-order:** How do I move an entity's home region? What does a user traveling between regions experience?

## 4C. Slow-burn failure

#### 4.9 "Storage grows linearly and visibly" (was #66) [Likely]
- **Why wrong:** Disk consumption includes retained logs, stalled replication slots, temp space, bloat, and in-flight backups, each growing independently.
- **What is correct:** The dangerous consumers are the ones nobody is watching.
- **Problem it creates:** Disk-full halts the database, often with a complicated recovery.
- **First-principles fix:** Alert on free space and on each hidden consumer (slot lag, WAL/binlog volume, temp usage, bloat). Cap retention for slots where supported, keep growth-based headroom, and drill the disk-full runbook.
- **Meta:** Which process holds data that blocks cleanup? What is time-to-full at the current worst-case rate?
- **Second-order:** Does capping slot retention break a downstream CDC consumer and force a resync? How would I resync without disrupting production?

---
