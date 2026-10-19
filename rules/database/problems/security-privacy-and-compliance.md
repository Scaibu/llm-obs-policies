
# Category 11: Security, privacy, and compliance

**Problem statement:** Data must be accessible only to authorized parties, for permitted purposes, and removable on demand, even when parts of the system are compromised or misused by insiders. Failure here means a breach or violation through a legitimate-looking access path, or inability to perform or prove deletion.

**Subproblems:** 11A access control and blast radius. 11B data lifecycle and erasure.

## 11A. Access control and blast radius

#### 11.1 "Encryption at rest means our data is secure" (was #96) 
- **Why wrong:** It defends against stolen or decommissioned disks. The database decrypts transparently for any authenticated session, so injection, stolen application credentials, over-broad roles, and insiders bypass it entirely.
- **What is correct:** Security is about who can obtain plaintext through any path, and at-rest encryption covers one path.
- **Problem it creates:** False confidence and unreviewed access.
- **First-principles fix:** Threat-model by actor (external attacker, compromised service, insider, administrator). Use least-privilege roles per service (no DDL, table-level grants), row-level security for tenancy, column or application-level encryption with separate keys for the most sensitive fields, parameterized queries, access audit logging, secret rotation, and alerts on bulk reads.
- **Meta:** If one application credential leaks, what can the attacker read, and how soon would I notice?
- **Second-order:** Column encryption breaks indexing and search, key management becomes a critical dependency, and audit logs themselves contain sensitive data.

#### 11.2 "The internal network is trusted" (was #97) 
- **Why wrong:** One compromised service enables lateral movement, and shared credentials remove attribution and make revocation disruptive.
- **What is correct:** Trust attaches to identity and authorization per request, not to network location.
- **Problem it creates:** One compromise reaches every database.
- **First-principles fix:** A unique database identity per service with minimal grants, mutual TLS, short-lived credentials from a secrets manager or workload identity, deny-by-default network policies, and logs keyed by principal.
- **Meta:** If service X is compromised, which databases can it reach and with what privileges?
- **Second-order:** Credential rotation causes connection churn or outages if done badly, there are more identities to manage, and certificate expiry becomes an outage class.

## 11B. Data lifecycle and erasure

#### 11.3 "Deleting a user's row deletes their data" (was #98) 
- **Why wrong:** Copies live in replicas, backups, caches, logs, search indexes, warehouses, ML features, exports, event streams, and third parties.
- **What is correct:** Erasure is a distributed operation over a graph of copies.
- **Problem it creates:** Legal exposure, inability to demonstrate deletion, deleted data returning via a backup restore.
- **First-principles fix:** Maintain a data inventory of every store holding personal data with an owner. Key all records by a subject ID, propagate deletion events to derived stores, handle backups with a retention window plus a deletion ledger replayed after any restore (or per-subject keys for crypto-shredding), and verify with periodic scans.
- **Meta:** Can I list every place user X's data exists? How would I prove it's gone?
- **Second-order:** Per-subject key management is complex, the deletion ledger must not retain the PII itself, and aggregates built from deleted data may need recomputation.

---
