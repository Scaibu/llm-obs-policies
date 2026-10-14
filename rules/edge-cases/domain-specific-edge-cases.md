# Volume 6: Domain-Specific Edge Cases

Volumes 1 to 5 stay as they are. This volume continues from Part 59 and moves from technologies to **domains**. Every domain has its own invariants, and most of its disasters come from engineers who know the technology well but have not modeled the domain's rules. In the taxonomy of Part 25.1, this is the **domain gap**.

Legal, tax, and regulatory details differ by country and change over time. Treat those points as **questions for your finance, legal, and compliance people**, not as settled facts.

---

## Part 59: Why Domains Create Their Own Edge Cases

### 59.1 Domain invariants are not in the framework

A database enforces "not null." It does not know that "a refund cannot exceed the amount captured," that "a subscription cannot be both canceled and renewing," or that "a model must not be trained on data from after the prediction date." These rules live in domain experts' heads, regulations, and contracts. If nobody writes them down, nothing enforces them (Family C), and they get violated under concurrency, retries, and bulk operations.

### 59.2 The domain has time and money built in

Most serious domains carry three properties that generic code handles badly:
- **Irreversibility:** money moved, notifications sent, data published, predictions acted upon.
- **Delayed truth:** the real outcome arrives later (settlement, chargeback, delivery, label, sync), so the system must hold and correct provisional states.
- **Third parties with their own clocks and rules:** banks, card networks, app stores, carriers, mail providers, identity providers.

### 59.3 A method for any new domain

1. **List the nouns and their lifecycles** (states, legal transitions, terminal states, time limits).
2. **List the invariants** in plain language ("total refunds never exceed total payments").
3. **Identify who holds the truth** for each fact (us, a provider, the user's device, a regulator).
4. **Identify the delayed and asynchronous parts** (what is provisional, when does it become final, who corrects it).
5. **Identify the irreversible actions** and put extra gates in front of them.
6. **Ask a domain expert: "what is the ugliest real case you have seen?"** That answer is worth more than any checklist.

---

## Part 60: Payments and Financial Ledgers

### 60.1 Modeling money correctly

- **Store amounts as integers in minor units** (or exact decimals), together with an explicit currency code. A number without a currency is a bug waiting to happen.
- **Currencies differ in exponent:** some have 0 decimal places, most have 2, some have 3. A hard-coded factor of 100 breaks them. Take the exponent from a table, not from habit.
- **Rounding rules are business rules:** half-up vs. banker's rounding, rounding per line vs. per invoice, and where the remainder goes when splitting (Part 11.9). Write them down; they must match what the tax authority, the provider, and the accounting system expect.
- **Allocation:** splitting 100.00 three ways must produce parts that sum to exactly 100.00. Use a largest-remainder method, and record where the odd cent went.
- **Never compute money with floating point,** and never let a JSON number pass through a language that parses it as a float (Part 53.2).
- **Multi-currency:** store the original amount and currency, the converted amount, the rate used, the rate's timestamp, and its source. Decide for refunds: original rate or current rate? Decide who bears FX risk.
- **Negative amounts** (credits, refunds, reversals) need an explicit sign convention across every table, report, and integration. Mixed conventions cause exactly-wrong-by-double errors.

### 60.2 The ledger as the source of truth

Root cause of many financial bugs: **a mutable balance column is treated as the truth.**

```
# fragile: balance is the truth
update accounts set balance = balance - 50 where id = A

# robust: entries are the truth, balance is derived
insert into ledger_entries (account, amount, currency, reason, reference, created_at)
-- balance = sum(entries); a cached balance is a rebuildable copy
```

- **Append-only entries:** corrections are new entries (reversal plus replacement), never edits or deletes. This preserves the audit trail and makes "what did we believe last Tuesday" answerable.
- **Double-entry:** every movement has equal debits and credits across accounts. A global invariant (sum of all entries is zero per currency) gives you a check that catches whole classes of bugs.
- **Each entry references its cause** (payment ID, refund ID, idempotency key) with a **unique constraint** so a retry cannot post twice.
- **Posted vs. pending:** holds and reservations are separate from final entries, with expiry.
- **Atomicity:** all entries of one business event commit in one database transaction. Entries spanning two databases or services are a saga (Part 18.7) and need reconciliation.
- **Balance checks under concurrency:** "sufficient funds" must be enforced atomically (conditional update, row lock on the account, or a constraint), never by read-then-write (Case 8, Case 25).
- **Snapshots and period closes:** periodically store a verified balance snapshot and lock closed periods. Late corrections to a closed period go into the current period with a reference, not into the past.
- **Time fields:** keep *event time* (when it happened), *posting time* (when we recorded it), and *value date* (when it counts). Conflating them breaks reporting and interest calculations.
- **Invoice and receipt numbering:** many jurisdictions require gapless, sequential numbers. Database sequences have gaps (Part 10.5). If gaplessness is a legal requirement, you need a dedicated, serialized numbering process, and a policy for voided numbers.
- **Rounding differences between ledger and reports:** decide the single place where rounding occurs so reports reconcile exactly.

### 60.3 The payment lifecycle is a state machine with an external owner

Typical stages (names vary by provider):

```
created -> requires_action (authentication) -> authorized -> captured -> settled -> paid out
              |                                   |            |
           abandoned                         voided/expired  refunded (partial/full) / disputed
```

Edge cases by stage:
- **Creation and double submit:** the user double-clicks, the client retries, two tabs submit. Use an idempotency key derived from the *intent* (cart or order), not the attempt (Part 11.6).
- **Authentication steps (strong customer authentication, redirects):** users abandon midway, close the browser, return hours later, or complete on another device. The payment can complete after your session is gone, so **your order must not depend on the browser returning.**
- **Authorization vs. capture:** an authorization is a temporary hold with an expiry window. Capturing after expiry fails or creates a new charge. Capturing more than authorized, or capturing in pieces, has provider-specific rules.
- **Amount changes after authorization:** price changes, shipping added, items out of stock. Decide how to adjust, and what happens to the hold.
- **Timeouts are unknown outcomes** (Part 9.5): the provider may have charged. Never assume failure; query by the idempotency key or reference, or wait for the webhook, then reconcile.
- **Asynchronous payment methods** (bank debits, vouchers, wallets) stay pending for minutes to days and can fail after you delivered the goods. Decide when fulfillment is allowed for each method.
- **Declines are not one thing:** soft declines (retry later, authenticate), hard declines (do not retry), and fraud blocks. Retrying a hard decline repeatedly can harm your standing with issuers and networks.
- **Stored payment methods:** cards expire, get replaced, or are closed. Card updater services help but are not universal. Off-session charges need stored consent and may require authentication.
- **Subscriptions and retries (dunning):** retry schedule, grace period, what access is retained, notifications, and what happens if a retry succeeds after cancellation.
- **Duplicate detection by cardholders:** a customer who sees two pending holds calls the bank and files a dispute, even if one will drop off. Reduce duplicate authorizations.
- **Test vs. live mode:** keys, webhooks endpoints, and customers differ. Test data leaking into production reports, and live keys used in test environments, are both recurring incidents.

### 60.4 Webhooks and events are the real state, and they misbehave

Providers notify you of outcomes asynchronously. Edge cases:
- **Duplicates:** the same event delivered several times. Dedupe by the provider's event ID in a table with a unique constraint, in the same transaction as the effect.
- **Out of order:** a "refund succeeded" event arriving before the "charge succeeded" event you have not processed yet; "updated" before "created." Handlers must tolerate missing predecessors (fetch the current object from the provider, or park the event and retry).
- **Late:** events arriving hours or days later, after you have canceled the order or closed the period.
- **Lost:** provider retries have limits. Do not rely on webhooks alone; run a **periodic reconciliation pull** that lists recent objects from the provider and compares them with your records.
- **Stale payloads:** the event body is a snapshot at emission time. For decisions, fetch the current object.
- **Signature verification** on the raw body, with timestamp tolerance (Part 20.11).
- **Slow handlers:** respond quickly and process asynchronously, or the provider times out and retries, causing duplicates and queues.
- **Endpoint migration:** deploying a new endpoint while the old one still receives events; secret rotation with overlap; multiple environments subscribing to the same account.
- **Replay by operators:** re-sending historical events (for recovery) must be safe against your dedupe table and your side effects (emails, shipments).

### 60.5 Reconciliation: the control that catches everything else

Three-way reconciliation compares:

```
1. your internal ledger / orders
2. the payment provider's records (charges, refunds, fees, payouts)
3. the bank statement (actual deposits)
```

- **Direction matters:** check both "recorded by us but missing at provider" and "at provider but missing in our records."
- **Timing differences:** settlement lags, batch cutoffs, time zones of cutoff, weekends and holidays. Reconcile by stable reference, not by date alone.
- **Fees, reserves, and adjustments:** payouts equal charges minus refunds minus fees minus disputes minus reserves. Every component needs its own ledger account, or reconciliation never closes.
- **Breaks need an owner and an aging report:** unreconciled items older than N days escalate.
- **Automate the tolerance:** allow known rounding differences, alert on anything else.
- **Reconcile refunds and disputes separately;** they are where most silent leaks live.

### 60.6 Refunds, disputes, and reversals

- **Refund limits:** total refunded must not exceed total captured. Enforce atomically (Case 25), including concurrent partial refunds.
- **Refund paths:** to the original instrument vs. store credit; expired or closed cards causing bounced refunds; refunds taking days; refunds that fail and need an alternative.
- **Refund of discounted, taxed, or multi-item orders:** how are discount and tax apportioned to returned items? Decide and document.
- **Disputes (chargebacks):** arrive weeks or months later, with short response deadlines, and often carry a dispute fee. Fulfillment evidence, logs, and communication records must be retained and retrievable. A dispute and a refund on the same payment can double-refund the customer.
- **Fraud and friendly fraud:** identify repeat abusers without violating privacy rules; velocity limits (Part 36.3).
- **Negative balances:** a merchant or seller whose account goes negative because refunds and disputes exceed incoming funds. Decide recovery: debit future payouts, charge a card, or write off.
- **Write-offs and adjustments** require approval and a reason code; they are a common fraud vector inside companies (Part 34.5).

### 60.7 Marketplace and payout edge cases

- **Split payments and commissions:** rounding, fee attribution, refunds after payout (who funds it).
- **Payout timing and holds:** new sellers, high-risk periods, reserves, compliance holds.
- **Payout failures:** closed bank accounts, name mismatches, currency not supported; funds returned days later and stuck.
- **Verification and compliance states** (identity checks, sanctions screening) that can flip after funds have moved. Design "account restricted" as a first-class state with defined effects on in-flight money.
- **Tax reporting thresholds and forms** depend on cumulative amounts over a year: a counter whose correctness is legally significant.

### 60.8 Operational and compliance hazards

- **Never store or log full card numbers, security codes, or unnecessary personal data;** use the provider's tokenization so your systems stay out of scope (the exact compliance obligations depend on your integration; confirm with your compliance owner). Check logs, error reports, analytics tags, screenshots, and support tickets for accidental capture.
- **Provider as a single point of failure:** outage, account freeze, rate limits, sudden risk review. Decide whether a second provider is worthwhile, and what "degraded mode" means (accept orders, collect later?).
- **Price and currency display vs. charge:** showing one amount and charging another (tax, FX, rounding) creates disputes and legal exposure.
- **Regulated behavior:** refund rights, cancellation windows, renewal notices, and consent requirements vary by country. Keep the rules in a reviewed, versioned place, not scattered in code.
- **Promotions and gift cards:** liability accounting, expiry rules (legally restricted in many places), fraud via enumeration and brute force of codes (Part 34.3).
- **Time-based cutoffs:** end-of-day, end-of-month, and fiscal-year boundaries across time zones; daylight saving shifts in batch schedules.
- **Migration between providers:** stored payment tokens are usually not portable without a formal transfer process; plan it before signing the contract.

---

## Part 61: Multi-Tenant SaaS, Subscriptions, and Metering

Builds on Parts 19.11 and 31.4 (tenant isolation).

### 61.1 The subscription state machine

```
trialing -> active -> past_due -> (grace) -> unpaid/suspended -> canceled
                \-> pausing/paused      \-> reactivated
active -> cancel_at_period_end -> canceled
```

- **Every state needs a defined meaning for access, billing, data retention, and notifications.** "Past due" with full access for 30 days is a business decision; if it is accidental, it is a revenue leak.
- **Illegal combinations:** canceled but still billing; renewing after cancel; two active subscriptions for one tenant; trial that restarts on reactivation.
- **Concurrency:** upgrade and cancel at the same instant; two admins changing the plan; renewal job running while the customer changes plan (Part 11.9).
- **Proration:** daily vs. per-second; what happens to credits; upgrade timing vs. invoice timing; downgrade credits; rounding. Prorations that add up to unexpected negative invoices.
- **Billing anchors:** subscriptions starting on the 29th to 31st; "monthly" on February; leap years (Part 20.8). Decide and test the month-end rules.
- **Trials:** who counts as a new customer (email variants, company domain, payment method fingerprint), what happens at trial end without a payment method, and time zone of "ends at midnight."
- **Entitlements are separate from billing:** access should derive from an entitlement record that billing events update, with a reconciler. Coupling access directly to payment webhooks means a lost webhook silently grants or removes access.
- **Plan changes and limits:** a downgrade to a plan with lower limits while the tenant already exceeds them (more seats, projects, storage). Decide: block, grace period, read-only over-limit data, or forced cleanup (Case 49). Never silently delete.
- **Seat counting:** simultaneous invitations exceeding seat limits (check-then-act); removed users still counted; users who are deactivated and later reactivated; SSO-provisioned users appearing automatically and changing your invoice.
- **Price changes and grandfathering:** existing customers on old prices; currency changes; tax rate changes; contract-specific overrides that live in a spreadsheet nobody maintains.
- **Invoicing rules:** invoices are legal documents: immutable after finalization; corrections via credit notes; consistent numbering; tax identifiers and address snapshots taken at invoice time (Part 3.3 snapshot principle).
- **Enterprise exceptions multiply states:** custom terms, manual invoicing, purchase orders, negotiated limits. Every exception should be modeled as data with an owner and an expiry, not as a code branch (Part 20.6).

### 61.2 Usage metering and usage-based billing

Usage data is an event stream feeding money, so it inherits every stream problem.

- **Duplicates:** at-least-once delivery double-counts usage. Every usage event carries a unique ID, and ingestion dedupes (Case 48).
- **Late events:** usage arriving after the invoice period closed. Decide: bill next period, reissue, or drop after a cutoff, and communicate the rule.
- **Out-of-order and clock skew:** event time from clients cannot be trusted; bound acceptable skew; use server receive time as a cross-check.
- **Aggregation windows and time zones:** the boundary of "month" in whose zone; events near the boundary attributed to the wrong period.
- **Rounding and minimums:** per-event rounding versus rounding the total; minimum charge increments; free tiers and how they reset.
- **Counter semantics:** gauges (storage used) vs. counters (API calls) vs. peaks (max seats) need different aggregation; averaging a gauge incorrectly under- or over-bills.
- **Metering pipeline outage:** missing data looks like zero usage. Detect gaps (expected-volume checks) before invoicing; hold invoice runs on anomalies.
- **Customer-visible usage must match the bill.** Two different computations (dashboard vs. invoice) will disagree; compute once and share.
- **Abuse and spikes:** a bug or attack produces enormous usage the customer is then billed for. Caps, alerts to the customer, and a documented forgiveness process.
- **Backfills and corrections:** re-running metering must be idempotent and produce credit or debit adjustments, not silent changes to issued invoices.
- **Quota enforcement vs. billing:** real-time limits use approximate counters; billing uses exact totals. Accept and document the gap, and reconcile.

### 61.3 Tenant lifecycle

- **Onboarding:** tenant creation is multi-step (record, default data, keys, domain, billing customer, identity provider). A failure midway leaves a half-tenant. Use a state machine and cleanup job, not a long synchronous request.
- **Naming and domains:** subdomain and custom-domain uniqueness, reserved words, case and Unicode confusables (Part 20.2), subdomain takeover after deletion (Part 12.4), certificate issuance for custom domains (validation failures, expiry, rate limits at the certificate authority).
- **Ownership:** the last admin leaves; the only owner is deactivated; ownership transfer; an acquired company merging tenants. Always keep a recoverable path to an owner, with identity verification by support (Part 34.5).
- **Tenant merge and split:** identifiers collide; users exist in both; settings conflict; audit history must stay attributable. Plan it as a project with dry runs, not a script.
- **Suspension and deletion:** suspension must preserve data and block access consistently across APIs, background jobs, webhooks, and integrations. Deletion must reach caches, search, analytics, backups, logs, and third parties (Part 19.12), after a grace period that is communicated and reversible until a defined point.
- **Export and portability:** complete, consistent, large (time-outs, memory), permission-respecting, and protected against being used as an exfiltration path (Part 34.4).
- **Data residency:** per-tenant region choices affect backups, search, analytics, support tooling, and sub-processors.
- **Per-tenant keys (bring-your-own-key):** key revocation by the customer makes data unreadable; define what the product does (degrade, read-only, fail) and how background jobs behave (Part 32.2).

### 61.4 Identity integration: SSO, SCIM, and directory sync

- **Deprovisioning lag:** a user removed from the corporate directory retains access until the sync runs, sessions expire, and tokens lapse. Define the maximum window and shorten it for sensitive roles (Part 30.4).
- **Identifier changes:** users whose email or username changes at the identity provider become new accounts (duplicate users, lost data) unless you key on a stable subject ID (Case 24).
- **Email reuse:** a departed employee's address assigned to a new hire, inheriting the old account.
- **Just-in-time provisioning:** auto-created users might bypass seat limits, approval, or default role assumptions; role mapping from group claims that change over time.
- **Conflicting sources:** local users plus SSO users plus directory-sync users for the same person; precedence rules.
- **Enforcement transitions:** turning on mandatory SSO for a tenant locks out admins whose SSO is misconfigured. Require a tested break-glass local admin and a staged rollout.
- **Certificate and metadata expiry** on the SAML side (Part 12.4): silent expiry breaks login for an entire enterprise customer.
- **Multiple tenants per user:** context switching; a token valid for tenant A used against tenant B (Part 31.4); notifications and sessions crossing tenants.
- **Directory sync bulk changes:** an upstream mistake (group emptied) deprovisions hundreds of users. Apply sanity limits on bulk removals, as in Part 22.3.

### 61.5 Fairness, limits, and noisy neighbors by plan

- **Limits must be enforced where the resource is consumed** (queue workers, query layer, storage) and not only at the API edge.
- **Per-tenant concurrency, not only rate,** plus per-tenant queues or weighted fair scheduling (Part 18.8).
- **Big-tenant behaviors:** the largest customer's export, reindex, or migration can degrade everyone. Run heavy operations through throttled, isolated workers.
- **Plan-based limits and abuse:** free-tier accounts used for spam, scraping, crypto mining, or hosting. Needs detection, rate limits, and verification gates (Part 36.4).
- **Tiering by isolation:** premium tenants on dedicated resources create a second, rarely tested code path and deployment topology; every migration must handle both.
- **Cost attribution:** if you cannot attribute cost per tenant, you cannot find the tenant whose usage makes you unprofitable or that is under attack.
- **Migrations across thousands of tenants** run for days, fail for a subset, and leave a mixed fleet (Part 19.11); track per-tenant migration state and make code tolerate both versions.

---

## Part 62: Mobile, Offline-First, and Sync

Mobile inverts several server-side assumptions: **you cannot control the client, you cannot force an upgrade, the network is hostile, and the clock is wrong.** Extends Parts 20.5 and 52.

### 62.1 Fleet and version realities

- **Old versions live for years.** Every API field, enum value, and error code you ever shipped must stay supported until telemetry shows the version is gone. Removing or changing behavior breaks installed apps you cannot patch (Case 42).
- **Release cannot be rolled back on the device.** Store review delays and staged rollouts limit speed. Every risky feature needs a **remote kill switch** and a server-side compatibility plan, and the kill switch must work without the broken code path.
- **Forced-upgrade mechanism:** design it on day one (minimum supported version returned by the server, with a graceful screen). Retrofitting it into an app that lacks it is impossible.
- **Version skew is permanent, not transient:** your server runs with dozens of client versions simultaneously. Contract tests should include the oldest supported client.
- **Platform and OS diversity:** behaviors differ by OS version and vendor (background limits, permission models, keyboard, locale, system font size, storage encryption, battery optimizers that kill background work).
- **Third-party SDKs** embedded in the app (analytics, ads, payments, crash reporting) change behavior with their updates and can crash or leak data.
- **App store and policy changes:** a rejected update during an incident, new privacy requirements, payment policy differences (in-app purchase vs. your own billing), and review delays around holidays.

### 62.2 Network and request edge cases

- **Connectivity is not binary:** offline, captive portal (returns HTML to API requests), very slow, high latency, packet loss, flipping between Wi-Fi and cellular mid-request, IPv6-only networks, corporate proxies, VPNs, and data-saver modes.
- **A request that timed out may have succeeded.** Mobile clients retry constantly. Every mutating endpoint needs idempotency keys generated **once per user action and persisted across app restarts** (Part 11.6). An in-memory key is lost when the OS kills the app.
- **Retries when the app is killed and relaunched:** unsent operations need a durable local queue with status (pending, sent-unknown, confirmed, failed).
- **Timeout and backoff discipline:** aggressive retry on many phones after an outage is a thundering herd against your servers (Part 22.4). Backoff with jitter, honor retry-after hints, and cap total attempts.
- **Large uploads:** resumable, chunked, verified by checksum; background upload limits; partial uploads orphaned on the server (lifecycle cleanup).
- **Clock skew:** device time can be years off. Never use device time for ordering across devices, expiry, token validity calculations, or fraud checks without server correction. Keep a server-time offset if the client needs it, and handle time-zone changes and manual clock changes (travel, daylight saving).
- **Certificate pinning** without a rotation plan bricks installed apps (Part 52.4); corporate TLS inspection breaking pinned connections.
- **Token refresh races:** several requests receive "unauthorized" at once and each triggers a refresh. With rotating refresh tokens, the second refresh uses an already-used token and the server treats it as theft, revoking the session and logging the user out (Case 46). Serialize refreshes on the client (single in-flight refresh that other requests await), and give the server a short grace window for the immediately previous token.
- **Push notifications are best-effort:** not guaranteed, not ordered, may be delayed, dropped, collapsed, or blocked by user settings and battery modes. Use them as a hint to sync, never as the only delivery of critical information. Tokens rotate and become invalid; clean them up or you waste sends and appear in provider reputation metrics.
- **Deep links and universal links:** links that open in other apps or browsers, links that arrive before login or before the app is installed (deferred deep links), and links carrying tokens (leaks, Part 30.4); open-redirect-like behavior (Part 33.5).

### 62.3 Local storage and lifecycle

- **Local database migrations can fail on users' devices,** with no chance for you to intervene: interrupted migration, low storage, schema from skipped versions (a user jumping from v3 to v9 must run all migrations in order), and old data shapes. Test upgrade paths from **every** supported old version with realistic, large, dirty data. A failed migration should degrade to "re-sync from server," not crash at launch forever.
- **Storage full or limited:** writes fail; caches grow; downloaded content never cleaned. Handle write failure as a normal outcome.
- **The OS can kill the app at any moment,** including mid-write. Local writes must be transactional, and multi-step operations resumable.
- **Backup and restore to a new device:** restored local databases, tokens, and keys may be stale, duplicated, or bound to the old device (keys in secure hardware do not move). Restored data can resurrect deleted items (Part 18.6) or carry an old device identifier. Handle "restored from backup" as a state.
- **Cloned or shared devices:** two devices with the same stored identity and refresh token (image restored, enterprise cloning) make token-reuse detection misfire. Bind sessions to device keys where possible.
- **Secure storage differences:** values lost after biometric changes, OS upgrades, or restore; apps must handle "secret missing" by re-authenticating, not crashing.
- **Logout and account switching:** what local data is cleared (cached personal data, pending operations, push tokens unregistered, analytics identifiers reset)? Leftover data from the previous user shown to the next user on a shared device is a privacy incident.
- **Permissions:** granted, denied, "only while using," revoked in settings while the app runs, reduced precision location, limited photo access. Every feature depending on a permission needs a denied state that is permanent and usable.
- **Background execution limits:** scheduled syncs are deferred, batched, or denied; your "sync every 15 minutes" is a wish. Design for being launched once a day.
- **Memory pressure and process death:** state held only in memory (a multi-step form, a half-completed purchase) is lost; restore UI state and in-flight operations.
- **Localization and accessibility:** long translations breaking layouts, right-to-left languages, large text sizes, screen readers, non-Gregorian calendars, different number formats (Part 11.1).

### 62.4 Offline-first data and synchronization

The hardest mobile problem is **multiple replicas of the truth that change independently and merge later.**

**Conflict cases**
- **Same field edited on two devices while offline.** Options: last-writer-wins (simple, silently loses data, and depends on untrusted clocks, Part 18.1); server-arrival-order (still loses data, but deterministically); field-level merge (merges independent fields); operation-based merge or CRDT types (preserve intent for counters, sets, text); prompt the user to resolve. Choose **per data type**: a counter (likes, inventory) must merge as increments, not overwrite; free text needs a merge strategy; a status needs a state-machine rule.
- **Edit vs. delete:** one device edits an item another deleted. Does the edit resurrect it, or is it lost? Decide and tell the user.
- **Ordering dependencies:** "create folder" then "move file into it" queued offline; the server receives them reordered or the first fails. Operations need dependency tracking and client-generated IDs so children can reference parents that do not yet exist on the server.
- **Uniqueness conflicts:** two devices create the same unique name or username offline; the server rejects one later, long after the user moved on. Design the rejection UX and local rollback.
- **Constraint violations found late:** an offline action violates a rule the server enforces (insufficient balance, revoked permission, deleted parent). Queued operations need a failure path that informs the user and repairs local state.
- **Permission changes while offline:** the user was removed from a shared project; queued edits are now unauthorized. Reject safely, preserve the user's work locally (export or copy), and explain.

**Sync protocol cases**
- **Cursors:** "give me changes since X." X must be a server-issued opaque cursor, not a device timestamp (clock skew) and not "max ID seen" (Part 10.5 skipped rows).
- **Deletions need tombstones** retained long enough for every device to sync; a device offline longer than the tombstone retention must do a **full resync**, or it resurrects deleted data (Part 18.6). The server needs a way to tell the client "your cursor is too old."
- **Initial sync cost:** the first sync of a large account is huge; chunk it, make it resumable, prioritize recent data, and throttle server-side.
- **Partial sync and partial failure:** half the changes applied; the cursor advanced only for the applied part. Apply changes transactionally per batch and advance the cursor with the batch.
- **Sync loops:** device A's change triggers server changes that device B echoes back, triggering more changes. Mark origin and suppress echoes.
- **Idempotent apply:** receiving the same change twice must be harmless (version numbers, change IDs).
- **Schema differences between client and server versions in the sync payload:** old clients must ignore unknown fields without dropping them on write-back (a client that deserializes and re-serializes can erase fields it does not know, a silent data-loss bug in read-modify-write sync).
- **Large data and media:** separate metadata sync from blob transfer; content-addressed storage avoids duplicates; orphan cleanup.
- **Quota and storage on device:** selective sync, eviction of local copies (never of unsynced changes).
- **Multiple accounts and multiple devices simultaneously:** the same account on a phone, tablet, and web; real-time collaboration on top of offline edits.
- **Debugging is hard:** provide a way to see sync state, pending operations, last successful sync, and conflicts, and log them with correlation IDs (respecting privacy).

### 62.5 In-app purchases and platform billing

- **Receipts and entitlements:** purchases can complete while the app is closed, be restored on another device, be refunded by the store later, be shared within a family group, or be revoked. Server-side verification and store server notifications are required; a client-side "purchased" flag is forgeable.
- **Duplicate and delayed notifications, out-of-order events** (Part 60.4), and gaps when your endpoint was down; periodic reconciliation with the store's API.
- **Price localization, currency, and tax handled by the store;** your reporting and revenue recognition must reconcile against store payouts, which arrive on the store's schedule and net of fees.
- **Subscription states specific to stores:** grace periods, billing retry, price increase consent, upgrade/downgrade timing, cross-platform subscriber (bought on mobile, using web).
- **Policy constraints:** where you may and may not offer alternative payment methods differ by platform, region, and time.

### 62.6 Mobile telemetry and analytics edge cases

- **Events are delayed, duplicated, dropped, or sent after days offline,** with device timestamps. Deduplicate by event ID; bucket by server receive time and event time with bounded skew.
- **Session and user identity:** anonymous to logged-in transitions, multiple devices per user, reinstalls creating new IDs, resets of advertising identifiers, consent states controlling what you may collect.
- **Crash reporting volume and privacy:** symbolication, PII in breadcrumbs, crash loops at launch that prevent the crash report itself from uploading (you need launch-crash detection on the next start).
- **Sampling and version skew** in metrics; adoption curves needed to decide when an old API can be removed.

---

## Part 63: Data Pipelines, Analytics, and Machine-Learning Systems

Extends Part 19.13. The defining property: **the outputs look plausible even when wrong**, so failures are silent and permanent by default (Part 13, Axis 3).

### 63.1 Pipeline root causes (beyond Part 19.13)

- **Schema drift:** upstream renames, retypes, or repurposes a field. The pipeline keeps running with NULLs, zeros, or shifted columns. Enforce schema contracts at ingestion, quarantine violating records, and alert on distribution change per column (null rate, cardinality, min/max, distinct values).
- **Unit and semantic drift:** a field switches from cents to dollars, seconds to milliseconds, UTC to local time, or "last 30 days" to "calendar month," with the same name and type. Only distribution monitoring and documented semantics catch it.
- **Silent truncation and type coercion:** strings cut at a length limit, numbers cast to integers, timestamps cast to dates, dates parsed with swapped day/month (ambiguous formats, Part 11.1).
- **Partial and empty loads treated as success:** a source returned half the files, or zero rows (Part 22.3). Gate each stage on expected volume and freshness relative to history, with anomaly thresholds.
- **Idempotency and reruns:** rerunning a job must replace, not append (Part 19.13); a retry after partial failure must not double-load. Design by partition overwrite, merge by key, or write-then-swap.
- **Dependency ordering and freshness:** a downstream job running before its upstream finishes (using yesterday's data, successfully). Use data-aware triggers (partition arrival) rather than clock times; carry "as-of" timestamps end to end and display them on dashboards.
- **Late and out-of-order data:** define watermarks (how long to wait), how late data is handled (restatement, side table, dropped with a counter), and who is told when historical numbers change.
- **Backfills at scale:** saturate the source or cluster; overwrite recent correct data with older logic; produce different results from the current logic on old data. Keep logic versioned and record which version produced each partition.
- **Non-determinism:** ordering not guaranteed without sort keys; "first" and "last" on unordered data; random sampling without seed; floating-point summation order (Part 20.1); joins on non-unique keys multiplying rows (Case 20).
- **Identity resolution:** merging records into one customer by email, phone, or device; false merges combine different people (privacy and correctness incident), missed merges split one person. Merges must be reversible and logged.
- **Slowly changing dimensions:** analysis joined against *current* attributes instead of attributes *as of the event* (Part 19.13). Keep validity ranges and join on time.
- **Grain confusion and double counting** (Case 20); `COUNT DISTINCT` across partitions; averaging averages; percentiles aggregated incorrectly (Part 21.10); ratios summed instead of recomputed from numerators and denominators.
- **Time zone and calendar definitions** for "day," "week," "month," "quarter," fiscal years, and business days.
- **Orphaned and ghost data:** deleted source records remaining in warehouses, data lakes, and derived tables; deletion and consent withdrawal not propagating (Part 37.3).
- **Metric definition sprawl:** several "active users," "revenue," and "churn" definitions. Keep a single governed definition layer with an owner and change log; version metric changes and annotate charts.
- **Dashboards and decisions:** executives act on numbers. A dashboard with no freshness indicator, no sample-size warning, and no definition link is a risk.
- **Access and privacy:** wide read access to warehouses exposing personal data (Part 37.2); test datasets copied from production; notebooks with credentials and outputs containing personal data; exports to spreadsheets.
- **Cost failure modes:** unbounded scans, cross joins, runaway queries, forgotten scheduled jobs, duplicated pipelines computing the same thing; budgets and per-query limits (Part 36.2).

### 63.2 Testing and observing data

- **Assertions on data (expectations):** uniqueness of keys, non-null of required fields, accepted values, referential integrity, row counts within a band of the prior period, sums reconciled to an independent source (Part 14.1).
- **Distribution and drift monitors:** per-column statistics over time, with alerting on abrupt change; segment-level monitoring so one tenant or region failing does not hide in the aggregate.
- **Freshness and completeness monitors:** as-of timestamps per table and partition; alerts on missing partitions; end-to-end "canary records" injected at the source and traced to the output.
- **Lineage:** know which dashboards and models depend on which tables, so a schema change notifies its consumers (Part 29, contract boundary).
- **Data contracts between producers and consumers:** versioned, tested in the producer's CI; breaking changes need migration windows (Part 20.5).
- **Golden datasets and regression diffs:** run old and new pipeline versions on the same input and diff outputs (Part 23.7).
- **Reprocessing drills:** can you rebuild yesterday, last month, and last year from raw data, and how long does it take? Raw data retention is a recovery-time figure.

### 63.3 Machine-learning systems: where the edge cases concentrate

A model is a function learned from data, so **data edge cases become behavior edge cases that no code review can see.**

**Data and labels**
- **Label leakage:** features that contain, or are computed from, the answer or from the future relative to the prediction time (a "refund issued" flag used to predict fraud; an aggregate computed over a window that includes the target period). Offline metrics look superb; production fails.
- **Time-travel bugs in features:** building training rows with data that was not yet available at prediction time (late-arriving corrections, current-state joins, backfilled values). Use point-in-time-correct joins and record each feature's availability delay.
- **Label quality and delay:** labels arrive late (chargebacks after 60 days, churn after 90), are noisy, or are produced by a process your model influences. Recent data has unmatured labels and biases training toward fast-resolving outcomes.
- **Selection bias and feedback loops:** you only observe outcomes for cases you acted on (approved loans, shown recommendations, inspected transactions). Training on those outcomes reinforces the old policy and hides errors. Retraining on your own model's outputs (or synthetic or model-generated text) degrades quality over time.
- **Sampling and class imbalance:** downsampling changes the predicted probability scale (calibration must be corrected); evaluation sets that do not reflect production mix.
- **Duplicate and near-duplicate data** across train and test (same user, same document, same session) inflating evaluation; splits must respect groups and time.
- **Distribution shift:** covariate shift (inputs change), label shift (base rates change), concept drift (relationships change), seasonality, launches, policy changes, upstream feature changes, new markets and languages.
- **Missing values:** imputation done differently in training and serving (Case 47); "missing" carrying signal in training that disappears in production (or vice versa); sentinel values like -1 treated as real.
- **Rare categories and unseen values:** new categories at serving time mapped to an "other" bucket inconsistently; high-cardinality identifiers memorized.
- **Protected attributes and proxies:** removing a sensitive attribute does not remove it if other features proxy it. Evaluate by subgroup, not only overall; define fairness and harm criteria with legal and domain input.

**Training-serving consistency**
- **Skew:** feature code in a batch training pipeline and in an online service written separately, diverging in rounding, time zones, tokenization, normalization constants, category mappings, default values, and library versions. Share one implementation, or test equivalence on real samples continuously (shadow compare).
- **Feature freshness:** online features computed from streams lag or fail; the model silently receives stale or default values. Serve a freshness indicator and alert when features fall back to defaults at unusual rates.
- **Feature store and join hazards:** point-in-time correctness, key mismatches, TTLs, backfill consistency with online values.
- **Preprocessing artifacts** (scalers, encoders, vocabularies, tokenizers) must be versioned with the model; a model deployed with a mismatched artifact produces confident garbage without errors.
- **Numerical differences across hardware and library versions:** precision, nondeterministic kernels, quantization; results differ slightly and thresholds near decision boundaries flip.
- **Input validation at serving:** out-of-range, wrong types, extreme values, adversarial input; decide reject, clip, or flag, and log counts.

**Evaluation**
- **Metrics without decision context:** accuracy on imbalanced data; AUC without looking at the operating threshold; averages hiding subgroup failures; offline metrics not tied to business outcomes.
- **Threshold and calibration:** a model's scores drift while ranking stays stable, breaking fixed thresholds; calibrate and monitor.
- **Test set reuse and overfitting to the benchmark** through repeated tuning; contamination from pretraining data when using foundation models.
- **Online experiments:** novelty effects, interference between users, sample ratio mismatch (assignment imbalance signaling a bug), peeking and stopping early, multiple comparisons, seasonality, and metrics that move at different speeds.
- **Slices and rare critical cases:** define must-not-fail cases (safety, regulatory, VIP customers) and test them explicitly, independent of aggregate metrics.

**Deployment and operations**
- **Model versioning and rollback:** rollback requires the old model, its preprocessing artifacts, its feature definitions, and compatible downstream consumers. If feature definitions or data have changed, "rollback" is not a simple switch.
- **Shadow, canary, and gradual rollout,** with automatic rollback triggers on business and safety metrics, not only latency and errors.
- **Silent degradation:** no exception is raised when accuracy falls. Monitor input distributions, output distributions, prediction confidence, downstream outcomes when labels arrive, and proxies when they do not (agreement with a rules baseline, human review rates).
- **Fallbacks:** what happens when the model or feature service is down or slow? Default prediction, rules, or human queue; each has its own risk (Part 11.2 fail-open vs. fail-closed). Test the fallback.
- **Latency and capacity:** tail latency under batching, cold starts, GPU memory limits, input-length-dependent cost (long inputs consume far more), queueing under load (Part 9.1).
- **Reproducibility:** record code version, data snapshot, hyperparameters, random seeds, environment, and hardware so a model can be audited and rebuilt.
- **Retraining automation:** automatic retraining on bad or poisoned data promotes a worse model; require validation gates, comparison against the current model on fixed holdouts, and human approval for high-stakes systems.
- **Human-in-the-loop design:** automation bias (reviewers rubber-stamping), queue overload, and review feedback that is not captured as labels.
- **Privacy:** training data containing personal data; models memorizing and regurgitating it; deletion requests that cannot be applied to a trained model without retraining; logging of inputs and outputs (Part 37). Define retention for training sets, features, logs, and embeddings.
- **Security:** data poisoning, adversarial examples, model extraction through an exposed API, membership inference, exposure of model artifacts and feature stores, and dependency vulnerabilities in model-serving stacks (Part 35).
- **Accountability:** who is responsible when a model decision harms someone, how a decision can be explained, contested, and reversed, and what human override exists.

### 63.4 Systems built on large language models

These inherit all of the above plus their own edge cases. Specifics change quickly; verify against your provider's current behavior and documentation.

- **Non-determinism:** the same input can produce different outputs; tests need tolerance and statistical evaluation, not exact match. Lowering randomness reduces but does not guarantee identical output.
- **Structured output failure:** malformed or schema-violating output, extra text around JSON, truncated output at the token limit, wrong enum values. Validate strictly, retry with bounded attempts, and have a fallback; never pass raw output into queries, shells, templates, or code execution (Part 33.1).
- **Context limits and truncation:** long inputs silently truncated or dropped; important instructions pushed out of the window; retrieved documents crowding out the task. Count tokens, prioritize content, and alert on truncation.
- **Retrieval-augmented systems:** stale or missing index entries (Part 49.1), permission-blind retrieval leaking documents the user cannot access (Part 31.1), retrieved text carrying injected instructions, chunking splitting key facts, duplicates dominating results, and the model citing sources it did not use. Enforce access control at retrieval time, using the user's identity.
- **Prompt injection and untrusted content:** any text the model reads (web pages, emails, documents, tool output, user messages) can contain instructions. Separate trusted instructions from untrusted data, limit what tools the model can invoke, require confirmation for irreversible or sensitive actions, apply least privilege to every tool credential, and treat model output as untrusted input to downstream systems (Part 33.1).
- **Tool use and agents:** repeated or looping tool calls (cost and side effects), wrong arguments, acting on stale observations, partial completion of multi-step tasks (saga concerns, Part 18.7), irreversible actions taken on misunderstanding, unbounded spend. Impose step limits, budget caps, idempotency for tool actions, dry-run modes, and audit logs of every action with the reasoning inputs.
- **Hallucination and confident errors:** fabricated citations, numbers, API names, legal or medical claims. Design for verification: require grounding, show sources, route high-stakes outputs to human review, and measure factuality on your own tasks.
- **Model deprecation and silent updates:** provider models are retired or updated; behavior changes without your deploying anything (Part 21.5 "what changed outside our team"). Pin versions where possible, keep an evaluation suite, and monitor outputs for drift.
- **Prompt and template management:** prompts are code: version them, review them, test them, and deploy them with rollback. Template variables that are missing or empty produce nonsense ("Hi null," Case 50).
- **Caching:** cache keys must include every input that affects the result (user, tenant, permissions, model version, prompt version, retrieved context); semantic caches can return another user's answer (Part 20.7, 31.4).
- **Cost and latency:** long contexts, retries, verbose reasoning, and multi-step agents multiply cost; rate limits and provider outages are dependencies (Part 21.7); set per-user and per-tenant budgets and graceful degradation.
- **Safety and policy edge cases:** harmful or disallowed requests, self-harm or crisis signals, minors, regulated advice. Decide and test behavior for these, including what the system does when the safety layer itself is unavailable.
- **Logging and privacy:** prompts and outputs contain personal and confidential data; retention, access, and vendor data-use terms; redaction before logging (Part 11.10, 37.2).
- **Evaluation:** use task-specific golden sets, adversarial sets, regression tracking by prompt and model version, human review samples, and automated graders whose own biases are checked; evaluate end-to-end behavior, not isolated prompts.
- **Human factors:** users over-trust fluent output; UI must communicate uncertainty and allow correction; feedback loops (thumbs up/down) are biased samples.

---

## Part 64: Notifications, Email, SMS, and Messaging Delivery

Every product sends messages, and every message leaves your control the moment it is sent.

### 64.1 Email

- **Irreversible and public:** a wrong recipient, wrong content, or duplicate to the whole customer base cannot be recalled. Gate bulk sends: preview, test to seed list, recipient-count sanity limit, send-rate throttle, and a kill switch.
- **Template failures:** missing variables rendering as "null," "undefined," or blank; broken links; wrong locale; unescaped user content (injection, Part 33.1); HTML rendering differences across clients; plain-text fallback missing. Fail the send when a required variable is missing rather than sending a broken message.
- **Recipient identity:** addresses recycled to new owners, typos at signup, role addresses, shared inboxes, forwarding, and plus-addressing tricks. Require verification before sending sensitive content; never send private data to an unverified address.
- **Deliverability is a shared asset:** bounces (hard and soft), complaints, spam traps, and sending to old lists damage reputation, and your transactional mail (password resets, receipts) may share that reputation. Separate transactional and marketing streams and domains, process bounce and complaint feedback automatically, and suppress bad addresses.
- **Authentication records (sender policy, signing, domain-based policy) expire, break, or get misconfigured** during DNS changes, vendor switches, or new sending tools; mail silently lands in spam. Monitor and test them (Part 12.4 inventory).
- **Link behavior:** security scanners and preview bots **open every link** in an email, triggering one-time links, unsubscribes, and "confirm" actions (Part 52.1). Make state-changing actions require a click-through confirmation (POST), and make tokens resilient to prefetching.
- **Tracking pixels and link tracking:** unreliable (image blocking, privacy proxies prefetching and inflating opens); do not base logic on open events.
- **Unsubscribe and consent:** legally required in many jurisdictions; must be honored promptly across *all* systems and vendors (propagation delays create violations); preference centers with conflicting states; transactional exemptions have limits.
- **Timing:** time zones and daylight saving for scheduled sends; quiet hours; send-time storms (Part 22.2) overloading your own app with simultaneous clicks; provider rate limits and daily caps.
- **Duplicates:** at-least-once queues and retries send twice (Part 48); use a send-idempotency key per (recipient, message) and record provider message IDs.
- **Provider outage or throttling:** queueing, failover to a second provider (with reputation warm-up consideration), and expiry of stale messages (an "OTP code" delivered an hour late is noise; a "reminder" delivered days late is harmful, Part 20.10).
- **Content and data leakage:** sensitive data in subject lines and previews, in messages to a forwarded or shared mailbox, and in links that work without authentication.
- **Reply handling:** replies to no-reply addresses, auto-responders creating mail loops (bounded by loop detection), and inbound mail as an injection vector.
- **Inbound email parsing:** encodings, attachments, HTML, forged senders; authenticate before acting on instructions sent by mail.

### 64.2 SMS, voice, and one-time codes

- **Segments and encoding:** using any non-basic character switches encoding and cuts the per-segment length, multiplying segments and cost; long messages split and may arrive out of order or truncated.
- **Delivery is not guaranteed or timely;** delays of minutes are normal in some regions; carriers filter; sender registration and regional regulations apply.
- **Number hygiene:** formatting (normalize to an international standard form, Part 2.3), recycled numbers, landlines and virtual numbers, porting, number changes; SIM-swap risk for authentication (Part 30.3).
- **Abuse and pumping:** premium-rate destinations and verification-request floods (Case 29). Use per-destination caps, geographic allowlists, and challenges.
- **Code design:** single-use, short-lived, limited attempts, invalidated on new issuance, not reusable across users; do not reveal whether the number exists (Part 30.1).
- **Opt-in and opt-out keywords** and legal consent records; per-country sender rules; quiet-hour laws.
- **Fallbacks:** voice or alternative channels when SMS fails, with the same abuse controls.

### 64.3 Push and in-app notifications

- **Best-effort, unordered, collapsible** (Part 62.2); notification content may be visible on lock screens (privacy); user-level permission and per-category settings; token lifecycle (invalid tokens, multiple tokens per user, tokens persisting after logout and going to the next user of the device).
- **Fan-out scale:** a single event notifying a million users creates a thundering herd on your backend when they all open the app; stagger sends (Part 22.2).
- **Deduplication across channels:** the same event sent by email, push, and in-app without a unified model; user preferences respected consistently.
- **Stale notifications:** a notification about a state that has since changed (order status, meeting time). Include a version or recheck state on open.
- **Notification as action path:** deep links and inline actions must re-authenticate and re-authorize (Part 31.2).
- **Rate and fatigue:** excess notifications cause opt-outs and uninstalls, permanently removing your channel. Budget notifications per user, batch digests, and measure opt-out rates as a safety metric.

### 64.4 Webhooks you send (extends Part 20.11)

- **Receivers are unreliable** and sometimes slow or hostile: timeouts, redirects to internal addresses (SSRF, Part 33.3), huge responses, TLS failures, endpoints that always return 200 while dropping data.
- **Retry policy:** exponential backoff with jitter, a maximum age, automatic disabling after sustained failure with owner notification (and a manual re-enable plus replay option).
- **Per-endpoint isolation:** one slow receiver must not consume shared delivery workers (Part 18.8); per-destination concurrency and circuit breakers.
- **Ordering and idempotency:** include event ID, type, created time, and sequence or version; document that delivery is at-least-once and unordered.
- **Replay and dead-letter:** customers need to see delivery logs, failure reasons, and replay events; replays must not bypass payload authorization.
- **Payload design:** thin events (ID and type; receiver fetches current state) reduce staleness and leaks; fat events reduce round trips but freeze a snapshot and may include data the receiver should not see.
- **Secret handling:** signing secrets per endpoint, rotation with overlap, and protection in logs and dashboards.

---

## Part 65: Worked Cases (Domain Root-Cause Chains)

### Case 43: The refund that arrived before the charge

- **Symptom:** some orders are marked refunded but never paid; finance shows negative revenue for those orders.
- **Trigger:** a provider delivered the "refund created" event before the "charge succeeded" event, under a burst of retried webhooks.
- **Proximate cause:** the refund handler looked up the payment, found none, and created a placeholder in a wrong state; the later charge handler saw the placeholder and skipped creation.
- **Root causes:** **E** (ordering assumption), **B** (state model had no "event arrived before its parent"), **C** (no invariant that every refund references an existing captured payment), **H** (no periodic reconciliation with the provider).
- **Class-level fix:** event handlers are order-tolerant (fetch current object, or park and retry with a bound); refunds require a payment reference by constraint; daily provider reconciliation; out-of-order arrival tests with shuffled event sequences (Part 23.5).

### Case 44: The balance column that drifted

- **Symptom:** customer balances differ from the sum of their transactions by small, growing amounts.
- **Trigger:** concurrent updates and a bulk correction script that edited the balance directly.
- **Proximate cause:** balance was a mutable column updated in several code paths, one of which skipped the ledger entry.
- **Root causes:** **C** (two sources of truth), **B** (derived value stored as primary), **H** (no ledger-vs-balance invariant check).
- **Class-level fix:** entries as the only truth; balance derived or cached with a verified rebuild; a scheduled invariant job that recomputes and alerts on any mismatch; ban direct edits (corrections through reversing entries with reason and approver).

### Case 45: The offline edit that overwrote a teammate

- **Symptom:** users report notes "reverting" to old text; nobody sees an error.
- **Trigger:** two people edited the same note, one of them offline for a day; on reconnect the offline edit won.
- **Proximate cause:** last-writer-wins by **device clock**, and the offline device's clock was ahead.
- **Root causes:** **A** (assumed device time is comparable), **B** (free text modeled as an atomic value), **E** (concurrent offline edits treated as sequential).
- **Class-level fix:** server-assigned versions with conflict detection; merge strategy per data type (text merge or conflict copy, never silent overwrite); keep the losing version recoverable; tests with clock skew and long offline periods.

### Case 46: The refresh-token race that logged everyone out

- **Symptom:** after a release, a wave of users is unexpectedly signed out, mostly on poor networks.
- **Trigger:** the app made several parallel requests right after the access token expired.
- **Proximate cause:** each request attempted a refresh; the second used an already-rotated token, and the server's reuse detection revoked the whole session.
- **Root causes:** **E** (concurrency and retry on the client), **D** (client behavior and server theft-detection never reconciled as a contract), **J** (tests ran single requests on a fast network).
- **Class-level fix:** a single in-flight refresh shared by all pending requests; server grace window for the immediately previous token; distinguish reuse-after-grace (real theft) from retry; concurrency tests on the auth layer; metrics on forced logouts.

### Case 47: The imputation that differed by one line

- **Symptom:** a model performing well offline underperforms in production from day one, more so for new users.
- **Trigger:** new users have missing values for several features.
- **Proximate cause:** training replaced missing values with the column median; the serving code replaced them with zero.
- **Root causes:** **D** (two implementations of one feature logic), **J** (no training-serving equivalence test), **H** (no monitoring of feature distributions at serving).
- **Class-level fix:** a single shared feature implementation; replay of production inputs through both paths with diffs; serving-time monitoring of missing-rate and distributions per feature; a model cannot be promoted without the equivalence test passing.

### Case 48: The usage event that counted twice

- **Symptom:** customers complain invoices are higher than their dashboards; support credits them individually for months.
- **Trigger:** the metering consumer retried batches after timeouts.
- **Proximate cause:** ingestion inserted usage events without a unique ID constraint, so each retry double-counted.
- **Root causes:** **E** (at-least-once delivery), **C** (no idempotency at the store), **H** (no reconciliation between dashboards, raw logs, and invoices), **K** (billing and metering owned by different teams, with nobody owning the seam).
- **Class-level fix:** unique event IDs with dedupe at ingestion; invoice computed from the same aggregation the dashboard uses; automatic reconciliation of invoice totals against raw event counts; a named owner for the metering-to-billing boundary.

### Case 49: The downgrade that orphaned a customer's data

- **Symptom:** a customer downgrades, then finds half their projects inaccessible and some deleted overnight.
- **Trigger:** the new plan allowed fewer projects than they had.
- **Proximate cause:** a cleanup job enforcing plan limits archived "excess" projects, then purged them.
- **Root causes:** **B** (no state for "over limit but valid"), **C** (enforcement implemented as destructive cleanup), **K** (product, billing, and engineering each assumed another defined the policy).
- **Class-level fix:** over-limit as an explicit state (read-only, grace period, clear notices); destructive actions gated by sanity limits, soft-delete, and approval (Part 22.3); downgrade preview showing exactly what will be affected; restoration path.

### Case 50: "Hello null," sent to 400,000 people

- **Symptom:** a marketing send goes out with broken greetings and, for some recipients, another person's data.
- **Trigger:** a template variable was missing for users without a first name; a fallback join matched on a non-unique key.
- **Proximate cause:** no validation of required variables; the personalization join multiplied rows and mismatched fields.
- **Root causes:** **B** (name treated as always present; Part 11.9), **J** (seed-list test had only complete records), **C** (no send-time invariant on recipient data integrity), **K** (no approval gate or staged send).
- **Class-level fix:** templates declare required fields and fail the send if missing; sample-based preview across data-quality edge cases (empty, long, non-Latin names); staged sends (1%, then 10%, then all) with automated stop on complaint or error anomalies; recipient-count and data-integrity checks before release.

### Case 51: The sync that could not catch up

- **Symptom:** a mobile app shows old data for some users indefinitely; "pull to refresh" does nothing.
- **Trigger:** users who had been offline longer than the server's change-log retention.
- **Proximate cause:** the client cursor referred to purged history; the server returned an empty change set instead of an error.
- **Root causes:** **E** (assumed the cursor remains valid), **D** (contract lacked a "cursor expired, resync required" outcome), **H** (no metric for sync staleness per client).
- **Class-level fix:** explicit expired-cursor response that triggers a full, resumable resync; retention longer than realistic offline periods plus an upper bound enforced in the protocol; client-side "last successful sync" surfaced to users and to telemetry.

### Case 52: The grace period nobody chose

- **Symptom:** revenue analysis shows thousands of accounts using the product for months after failed payments.
- **Trigger:** payment failure events only moved accounts to "past due," and nothing handled the transition after retries were exhausted.
- **Proximate cause:** access depended on "not canceled," and the dunning process ended without canceling.
- **Root causes:** **B** (incomplete state machine: no terminal state after dunning), **E** (assumed an event would always arrive), **H** (no report of accounts in a transitional state beyond maximum duration, Part 14.1 "stuck items").
- **Class-level fix:** an explicit, reviewed subscription state machine with time-bounded states and scheduled transitions; entitlement reconciler; a dashboard and alert on accounts past due beyond policy.

---

## Part 66: Categorizing Domain Issues

Extends Part 13 and Part 25.

### 66.1 By which domain truth was violated
- **Monetary truth** (amounts, currencies, rounding, ledger balance).
- **Temporal truth** (event vs. posting vs. value time; period boundaries; late data).
- **Entitlement truth** (who may use what, until when).
- **Identity truth** (who is this person, tenant, device, account).
- **State-machine truth** (legal transitions, terminal states, time limits).
- **Consent and legal truth** (permissions to message, collect, retain, charge).
- **Provenance truth** (where did this number or prediction come from, and as of when).
- **Delivery truth** (was this sent, received, acted upon).

### 66.2 By who owns the authoritative copy
- **We own it** (enforce invariants ourselves).
- **A provider owns it** (we mirror and reconcile).
- **The user's device owns it temporarily** (we merge).
- **A regulator or contract defines it** (we follow and evidence).
- **Nobody owns it** (the most dangerous category; assign an owner).

### 66.3 By reversibility in the domain sense
- **Reversible by compensation** (refund, reversal entry, correction email).
- **Reversible only with counterparty consent** (chargeback, recalled payout, contract change).
- **Irreversible** (sent message, published data, acted-upon prediction, deleted data without backup, regulatory filing).
Irreversible domain actions get gates: preview, limits, staged rollout, approval, delay-and-cancel windows.

### 66.4 By detection source
- **Customer reports it** (worst: trust already lost).
- **Finance or operations notices** (late; often at month-end).
- **Reconciliation detects** (good).
- **Invariant monitor detects** (better).
- **Prevented by construction** (best).

### 66.5 Domain severity multipliers (add to Parts 25.3 and 40.6)
- Affects customer money directly: x3.
- Legally regulated behavior (consent, retention, financial records): x2.
- Visible to many external parties at once (bulk messages, public data): x2.
- Discovered only at period end or by audit: x2.
- Decisions by automated models affecting people's access, money, or safety: x3.
- Unowned authoritative copy: x2.

---

## Part 67: Domain Question Bank

**Money and ledgers**
- Is every amount stored with a currency and in exact units? Where is rounding defined, and who approved it?
- What is the single source of truth for a balance, and can it be rebuilt from entries?
- What enforces "refunds never exceed payments" under concurrent requests?
- What do we do when a payment attempt times out, and how do we find out what actually happened?
- Do we reconcile against the provider **and** the bank, in both directions, and who owns breaks?
- Which numbers must be gapless or immutable by law, and how is that enforced?

**Subscriptions and metering**
- Can you draw the subscription state machine with time limits on every non-terminal state?
- What happens to data and access on downgrade, non-payment, cancellation, and reactivation?
- Is usage deduplicated at ingestion, and do invoice totals reconcile to raw events?
- Who owns the boundary between metering, billing, and entitlements?

**Tenancy and identity**
- What happens when the last admin leaves, the identity provider changes an email, or an entire directory group disappears?
- What is the maximum time between "removed at the source" and "no access here"?
- If one tenant is huge, abusive, or hostile, what bounds the damage to others?

**Mobile and sync**
- What is the oldest client we must support, and how do we know when it is gone?
- If the app is killed at any instruction, what state is the user's data in?
- Where do concurrent offline edits go, per data type, and can the loser always be recovered?
- What happens when a device returns after longer than our change-log retention?
- Can we disable a bad feature remotely without the broken code's cooperation?

**Data and machine learning**
- For every feature and label: was it knowable at prediction time, and who proved it?
- Is the feature logic identical in training and serving, and is that tested continuously?
- How would we know the model silently got worse, and how long would that take?
- Can we roll the model back **including** its data, features, and downstream consumers?
- What happens when the model, its features, or the provider is unavailable?
- Which decisions affect people's money, access, or safety, and what human review, explanation, and appeal exist?

**Messaging**
- What is the worst message we could send to everyone by mistake, and which gates stop it?
- What happens when a required variable is missing, an address was recycled, or the same message is sent twice?
- Do scanners or prefetchers trigger any action on our links?
- Does an unsubscribe reach every system and vendor, and how quickly?

**The hardest domain questions**
1. What would a forensic accountant, an auditor, or a regulator find if they reconciled our records against an independent source today?
2. Which irreversible actions can our automation take at scale, and what limits each one?
3. Where does our truth depend on a third party's event that may be late, duplicated, reordered, or missing?
4. Which of our authoritative facts has no named owner?
5. If we learned today that one of our numbers, scores, or messages had been wrong for three months, how would we find every affected person and repair it?

---

## Part 68: Additional Principles (Extending Parts 8, 17, 28, 43, 58)

75. **Write the domain invariants down in plain language,** name an owner for each, and enforce them at the lowest authoritative layer.
76. **Store events and entries, derive balances and states.** Derived values are rebuildable caches with a verifier.
77. **Corrections are new facts, not edits.** Preserve the history of what was believed and when.
78. **Treat every third-party outcome as eventually arriving, possibly twice, possibly out of order, possibly never;** combine webhook handling with periodic reconciliation pulls.
79. **Reconcile against an independent source on a schedule,** in both directions, with aging and ownership of breaks.
80. **Model every lifecycle as an explicit state machine with time limits,** including the ugly states (over-limit, past due, pending forever, restored from backup).
81. **Gate irreversible actions:** preview, sanity limits, staged rollout, delay-and-cancel windows, and approval for bulk or destructive operations.
82. **Design for the oldest client and the longest offline period,** and ship a remote kill switch and a forced-upgrade path before you need them.
83. **Choose a merge strategy per data type.** Silent last-writer-wins is a decision to lose data; make it only on purpose.
84. **Never trust device, provider, or partner clocks for ordering;** use server-issued versions and cursors.
85. **Keep training and serving logic identical, and prove it with replayed real inputs.**
86. **Monitor data and model behavior, not only system health:** distributions, freshness, fallbacks, and outcomes.
87. **Make rollback include data,** artifacts, prompts, configurations, and dependents, or do not call it a rollback.
88. **Keep humans accountable for automated decisions that affect people:** explanation, appeal, override, and audit.
89. **Separate message streams by purpose** (transactional vs. marketing), protect sender reputation, and make bulk sends pass gates that assume the template, the data, or the list is wrong.
90. **Give every seam between teams or systems an owner,** because unowned seams are where duplicate charges, double counts, and missing data live.

---

## Operational Verification Checklist

For the actionable domain-specific review checklist (Payments, SaaS, Mobile Sync, Data/ML, Messaging) derived from Volume 6, see:
👉 **[Checklist 06: Domain-Specific Systems](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/06-domain-specific-systems-checklist.md)**  
👉 **[Master Engineering Checklist Index](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/00-master-engineering-checklist.md)**

