# Volume 4: Security and Adversarial Edge Cases

Volumes 1 to 3 stay as they are. This volume continues from Part 29 and looks at edge cases where someone is actively trying to exploit the gap. The usual structure applies: root cause first, then how it hides, then the structural fix.

As before, details that vary by library, protocol version, or product are flagged as things to **verify for your stack**.

---

## Part 29: Why Security Edge Cases Exist (Root Causes)

A security flaw is an edge case with an adversary attached. The adversary changes one thing: **triggers stop being random**. An accidental edge case waits for bad luck. A security edge case is found on purpose, tested thousands of times, and automated. "One in a million" becomes "guaranteed within a day."

Most security failures come from a few structural causes.

### 29.1 Trust boundary confusion

A trust boundary is any place where data or control passes between parties with different levels of trust. Failures occur when the boundary is **unmarked, in the wrong place, or crossed silently**.

- **Implicit trust of internal callers:** "It came from our own service, so it is safe." Internal services get compromised, misconfigured, or fed user input further upstream.
- **Trust inherited through data:** a value that was user-supplied three hops ago is treated as trusted because it is now in a database column or an internal message.
- **Boundaries drawn around machines, not data:** "inside the VPC is safe" assumes the attacker is never inside.
- **Client-side trust:** anything in the browser, mobile app, or device (hidden fields, prices, role flags, validation, feature gates) is attacker-controlled.

**Question:** for every piece of data, where did it originate, who could have influenced it, and where is it first validated?

**Structural fix:** mark boundaries explicitly. Parse and validate at each crossing. Carry a "trusted vs. untrusted" distinction in types where the language allows.

### 29.2 Ambient authority and the confused deputy

A component with broad privileges acts on behalf of a caller with narrow privileges without checking what the *caller* may do. Examples: a background service that can read every file, asked by a user to "export my document" using a path the user supplied; an internal API that trusts any request reaching it; a cloud function with an administrator role that performs whatever its input says.

**Root cause:** authority is attached to the *actor* (the service) instead of being derived from the *request* (what this caller is allowed).

**Fix:** pass and check the caller's identity and rights at the point of action. Give services the minimum role they need. Prefer capability-style designs, where the request carries a narrowly scoped token for exactly one thing.

### 29.3 Check and use separated (security TOCTOU)

The same time-of-check to time-of-use gap from Part 3 and 18 has security forms:
- A permission checked at request start, then acted on later by a queued job after access was revoked.
- A file path validated, then opened after a symbolic link was swapped in.
- A URL validated as external, then resolved again at fetch time to an internal address (DNS rebinding).
- A coupon, balance, or quota checked and then consumed without atomicity (race exploitation).
- A uploaded file scanned, then replaced before use.

**Fix:** make check and use one atomic step, re-check at use time, or bind the check's result to the exact object used (for example, open the file first, then verify the open handle rather than the path).

### 29.4 Fail-open defaults and missing deny paths

- A dependency (auth service, policy engine, feature flag, WAF, rate limiter) is unreachable, and the code allows the request.
- A new endpoint, field, role, or resource type is open until someone adds a rule.
- An exception in the permission check is caught and treated as "no restriction."
- A missing configuration value defaults to "disabled" for a security control.

**Rule:** for security decisions, the default on uncertainty is *deny*, with a deliberate, documented exception where availability must win.

### 29.5 Parser and interpreter differentials

Two components interpret the same bytes differently. The gap between them is the vulnerability (Part 20.4). This also covers *interpreters* that execute data: SQL engines, shells, template engines, regex engines, expression evaluators, deserializers, XML parsers, and PDF or image renderers.

**Root cause:** data and instructions are mixed in one channel (a string), so crafted data can become instructions.

**Fix:** keep data and code in separate channels (parameterized queries, argument arrays instead of shell strings, auto-escaping templates), and use one strict parser at the boundary.

### 29.6 Asymmetry of effort

Defenders must close every gap; attackers need one. Defenders test the intended use; attackers test the unintended combinations. This is why **defense in depth** matters: each layer assumes the previous layer has already failed.

### 29.7 Security debt is invisible

Unlike a slow query, a missing authorization check causes no symptom until exploited. There is no error, no latency, no alert. Security flaws are **silent and permanent** by default (Part 13, Axis 3), so they deserve the multipliers in Part 25.3.

---

## Part 30: Authentication and Session Lifecycle

### 30.1 Identity is not the same as a credential

- **Account identity vs. credential:** if identity is an email address and emails can change, be recycled by providers, or be unverified, then "same email" is not "same person."
- **Email and phone recycling:** an old number or address reassigned to a stranger. Account recovery through it hands over the account.
- **Unverified identity attributes from third-party login:** trusting an email claim from an identity provider without checking that it is verified, or linking accounts automatically by email across providers, enables account takeover (an attacker creates an account at a weak provider with the victim's email).
- **Pre-hijacking:** an attacker registers an account with the victim's email before the victim does (using a password or a weak provider). When the victim later signs up through another method, the accounts merge and the attacker retains access.
- **Case, whitespace, and Unicode variants** of usernames and emails create duplicate or confusable identities (Part 2.3 and 20.2).
- **Identifier enumeration:** login, signup, and reset flows that reveal whether an account exists (different messages, status codes, or response times).

### 30.2 Login edge cases

- **Brute force and credential stuffing:** rate limits per account only (an attacker tries one password across thousands of accounts) or per IP only (an attacker uses thousands of IPs against one account). Both dimensions are needed, plus detection of known-breached passwords.
- **Lockout as a weapon:** locking an account after N failures lets an attacker deliberately lock out victims (a denial of service against a specific person). Use progressive delays and challenge mechanisms rather than hard locks where possible.
- **Timing differences:** a code path that returns faster when the user does not exist leaks existence. Hash a dummy value to equalize time, and compare secrets in constant time.
- **Password handling:** storing with a fast hash, no per-user salt, or a hash algorithm choice that cannot be upgraded. Plan for re-hashing on next login as cost parameters change.
- **Very long passwords or inputs:** some hash functions truncate input at a fixed length (verify for your library), or an endpoint accepting megabyte-long passwords burns CPU on hashing (a cost attack).
- **Unicode in passwords:** different normalization forms on different devices make the "same" password fail. Normalize consistently.
- **Password reset:** predictable or long-lived tokens, tokens not invalidated after use or after a password change, tokens reusable, reset links leaked through the `Referer` header or logs, host header injection generating links to an attacker's domain, and reset flows that bypass multi-factor authentication.
- **Default and shared credentials,** bootstrap accounts, and test accounts left in production.

### 30.3 Multi-factor authentication edge cases

- **Fallback weaker than the primary:** MFA is enforced at login, but "forgot device" recovery, support-desk overrides, or backup codes bypass it. The weakest recovery path defines the real security level.
- **Enrollment gaps:** an attacker who gains a session before MFA enrollment enrolls their own device. Adding a factor should require re-authentication.
- **Code reuse and brute force:** one-time codes with a small space (6 digits) and no attempt limit; codes accepted for several time windows; the same code accepted twice.
- **MFA fatigue:** repeated push prompts until the user approves. Use number matching and rate limits.
- **Step-up inconsistencies:** sensitive actions (change email, add payout account, export data) not requiring recent authentication.
- **SMS and voice weaknesses:** SIM swap and number recycling; treat as lower assurance.
- **Clock skew** making time-based codes fail for legitimate users (Part 21.4).
- **Partial authentication state:** a session that has passed step one (password) but not step two (MFA) being treated as fully authenticated by some endpoints.
- **Remember-this-device tokens** that never expire, are not bound to the device, or survive password changes.

### 30.4 Session and token lifecycle

A session or token has a life: **issue, use, refresh, revoke, expire.** Each stage has edge cases.

**Issue**
- **Session fixation:** accepting a session ID supplied before login and keeping it afterward. Always issue a new identifier on authentication and on privilege change.
- Predictable or low-entropy identifiers (Part 20.9).

**Use**
- **Token in URLs** leaks via logs, browser history, and the `Referer` header.
- **Missing cookie protections** (HTTP-only, secure, same-site settings) and overly broad cookie scope (a parent domain cookie shared with less-trusted subdomains).
- **Cross-site request forgery:** state-changing requests authenticated only by ambient cookies. Also check "safe" methods (GET) that change state.
- **Token audience and issuer confusion:** a token issued for service A accepted by service B. Verify issuer, audience, expiry, and intended use.
- **Algorithm and key confusion in signed tokens:** accepting the algorithm named *in the token itself* (including "none"), or verifying with the wrong key type. Fix the expected algorithm server-side (verify against your library's behavior).
- **Unsigned or unverified claims trusted** because the token "looks" valid after decoding but the signature was never checked.
- **Key identifier handling:** a header that points the verifier at an attacker-controlled key location.

**Refresh**
- **Refresh token theft and reuse:** without rotation and reuse detection, a stolen refresh token gives indefinite access. With rotation, handle the race where a legitimate client retries after a lost response and gets flagged as theft (an idempotency edge case).
- **Refresh tokens outliving password changes or account disablement.**

**Revoke**
- **Stateless tokens cannot be revoked** until expiry unless you add a denylist or short lifetimes. Logout, password change, role change, account deletion, and "sign out everywhere" must all have a defined effect on existing tokens.
- **Cached authorization** in the token (roles, permissions) stays stale until refresh (Part 20.12).
- **Revocation propagation delay** across services and caches.

**Expire**
- Expiry enforced only in the client.
- Expiry based on a client-supplied clock.
- Long-lived API keys with no rotation or expiry.
- Idle vs. absolute timeouts: sessions that extend forever with activity.

### 30.5 OAuth, OpenID Connect, and delegated access

These are complex protocols with many well-known edge cases:
- **Redirect URI validation:** loose matching (prefix match, wildcard subdomains, open redirects on allowed hosts) lets an attacker capture authorization codes. Require exact matches.
- **Missing or unchecked state parameter:** cross-site request forgery on the login flow (an attacker logs the victim into the attacker's account).
- **Authorization code interception:** use proof key mechanisms for public clients.
- **Scope creep and over-broad scopes,** and consent granted once that silently covers later additions.
- **Token exchange confusion:** accepting an access token as proof of *identity* for your app when it was issued to a different app (audience not checked).
- **Open redirect chaining** that turns a minor bug into token theft.
- **Mix-up attacks** when one client talks to several identity providers.
- **Device and embedded flows** that train users to enter credentials in untrusted windows.
- **Third-party app permissions** that outlive the user's intent, or that allow an app to act after the user leaves the organization.

### 30.6 Service-to-service authentication

- **Shared static secrets** across many services: any compromise compromises all; rotation requires coordinated change.
- **Network location as identity** ("only reachable from this subnet").
- **Tokens forwarded across hops** without narrowing, so a low-value service can replay a token against a high-value one.
- **Authentication present but authorization absent:** any authenticated service can call any endpoint.
- **Certificate-based identity edge cases:** hostname or identity checks skipped "for internal traffic," expired internal CAs (Part 12.4), and clients that accept any certificate when verification fails.
- **Metadata service credentials** reachable from application code or through SSRF (Part 12.8).

---

## Part 31: Authorization Depth (Beyond Part 20.12)

### 31.1 Where object-level checks disappear

Every code path that reaches an object needs the check. Less obvious paths:
- **Indirect references:** object A contains an ID of object B, and the API returns or modifies B without checking the caller's rights to B.
- **Nested resources:** `/projects/5/tasks/9` checks access to project 5 but not that task 9 belongs to project 5.
- **Bulk and batch endpoints:** the check runs for the first item or for the collection but not each item; a mixed list containing one unauthorized ID is processed.
- **Search, autocomplete, and "suggest" features** that index everything and filter afterward (or not at all).
- **Counts and aggregates:** totals that include items the user cannot see leak existence and volume.
- **Sort and filter parameters** that let a user infer hidden values (sorting by a field they cannot read reveals its ordering).
- **Error differences:** "forbidden" vs. "not found" reveals existence.
- **Export, report, PDF, email digest, and notification** generators, which often run in a background context with elevated access (Part 20.12).
- **GraphQL and flexible query APIs:** field-level access rules missing, deeply nested queries reaching data through a relation, introspection exposing the whole schema, and batched aliases multiplying one request into thousands.
- **File and object storage:** predictable URLs, signed URLs that never expire or are reusable for other objects, directory listings, and thumbnails or previews stored under different access rules.
- **Webhooks and integrations** delivering data to a destination the user should not control (or that remains after access is removed).

### 31.2 Function-level and state-based authorization

- **Hidden or admin endpoints** protected only by obscurity or by the UI not showing the button.
- **HTTP method switching:** GET is checked, POST or DELETE is not.
- **State-dependent rights** ("owner can edit while open"): state changes between check and action, or background jobs act after state changed.
- **Workflow step skipping:** multi-step processes (checkout, verification, approval) where later steps do not verify earlier steps were completed. A user calls step 3 directly.
- **Role hierarchy gaps:** a lower role able to assign or create a higher role, invite users with more privilege than themselves, or modify their own permissions.
- **Mass assignment** (Part 20.12): request body fields bound to internal fields (role, owner, tenant, price, verified flag, balance). Use explicit allowlists of writable fields per operation.
- **Ownership transfer and deletion:** what happens to shared objects when their owner is deleted, leaves an organization, or is demoted? Orphaned data with no owner is often left publicly accessible or permanently undeletable.
- **Sharing links:** "anyone with the link" objects that are indexed, guessable, never expire, or cannot be revoked; links that keep working after the user's access was removed from the parent.
- **Invitation flows:** invitations to an email that a different person later controls; invitations that grant access before acceptance; invitation links reusable by anyone.

### 31.3 Authorization models and their failure modes

| Model | Typical failure |
|---|---|
| Role-based | Role explosion, roles that accumulate permissions over time, "admin" used for convenience, users holding stale roles after job changes |
| Attribute or policy-based | Policies that interact unpredictably, untested policy combinations, attributes that are user-editable, missing default-deny |
| Relationship-based (sharing graphs) | Transitive grants nobody intended, cycles, revocation not propagating through the graph, expensive checks that get cached wrongly |
| Ownership-only | Fails at teams, transfers, and organizational changes |
| Row-level database policies | Bypassed by privileged roles, forgotten on new tables, views executing with owner rights (verify for your engine) |

**Cross-cutting questions:**
- Where is the decision made (one policy point or scattered)? Can it be tested independently?
- Is there a list of "who can do what to what" that can be *audited*, not only inferred from code?
- How are permissions reviewed and removed (access recertification)? Permission accumulation over years is an edge case of organizational time.

### 31.4 Tenant isolation as a security boundary

Extends Part 19.11. Additional points:
- **Tenant identity taken from the wrong place:** from a request parameter or header the client controls, instead of from the authenticated session.
- **Shared resources leaking identity:** a cache key without tenant, a search index without tenant filter, a message topic shared between tenants, log lines exposed to support staff across tenants.
- **Background jobs and scheduled tasks** that iterate over all tenants and lose context on an error midway (continuing with the previous tenant's context).
- **Connection-level context leakage:** a tenant identifier set on a pooled connection not reset (Part 19.10).
- **Cross-tenant references:** a foreign key accepted from user input that points into another tenant.
- **Support and admin impersonation** without audit and time limits.
- **Data export, backup restore, and migration tools** that mix tenants.
- **Tenant deletion and offboarding:** data remains in caches, backups, analytics, and logs.

---

## Part 32: Secrets, Keys, and Cryptography

### 32.1 Secret lifecycle edge cases

Secrets have **creation, distribution, storage, use, rotation, revocation, and destruction**.

- **Secrets in places nobody considers secret stores:** source history (deleted files remain in version control history), container image layers, build logs, CI variables printed on error, crash dumps, core files, shell history, backups, ticket attachments, chat messages, configuration examples, browser developer tools, and mobile app binaries (anything shipped in a client is public).
- **Leaked secret response:** removing it from the repository does not revoke it. The response must be *rotate first*, then clean up. Teams often skip rotation because it is hard, which reveals that rotation was never designed.
- **Rotation that breaks production:** consumers cache old secrets, rotation is not atomic across consumers, or there is no overlap window during which both old and new are valid (Part 12.4 and 12.8).
- **One secret, many uses:** the same key used for several purposes or environments, so a low-value leak (staging) becomes a high-value compromise (production).
- **Secrets passed on command lines or environment variables,** visible to other processes, process listings, and diagnostic endpoints that dump environment.
- **Secrets in logs and error messages,** including HTTP request logging with authorization headers and URLs with tokens.
- **No inventory:** nobody knows how many secrets exist, who owns them, or where they are used. A leak then cannot be scoped.
- **Long-lived credentials where short-lived would work,** and credentials with broader permissions than needed.
- **Break-glass credentials** that are never tested, are not audited, or are stored where the failed system is needed to reach them (Part 12.7).

### 32.2 Cryptography edge cases (design-level, not algorithm-level)

- **Rolling your own or misusing primitives:** correct algorithm, incorrect mode or parameters.
- **Encryption without authentication:** data can be modified undetected. Use authenticated encryption.
- **Nonce or initialization vector reuse:** for many modes, reusing a value with the same key catastrophically breaks confidentiality or authenticity. Causes include counters reset after a restart, random generators seeded identically on cloned machines (Part 20.9), and multiple writers sharing a key without coordinated nonces.
- **Key and data stored together:** encryption adds little if the key sits beside the ciphertext with the same access.
- **Encryption scope mistakes:** encrypted at rest on disk while readable to any application credential; "encrypted database" that protects only against stolen physical disks.
- **Key hierarchy and rotation:** rotating a master key without re-encrypting data (or without a way to know which key version encrypted which record). Store a key version with each ciphertext. Also plan for what happens when an old key is compromised and old data needs re-protecting.
- **Key deletion equals data deletion:** crypto-shredding is powerful, but if a key is lost accidentally, data is permanently gone. Key backup and recovery must be as carefully designed as data backup, and key material needs its own restore drills (Case 13 in Part 15).
- **Regional or single-account key storage:** replicated data unreadable in another region because the key lives only in the failed one (Part 21.9).
- **Certificate validation disabled** "temporarily" for testing and left on; verification that checks the chain but not the hostname.
- **Downgrade and fallback:** systems supporting old protocol versions or weak algorithms for compatibility, allowing an attacker to force the weak path.
- **Comparison and randomness:** non-constant-time secret comparison (Part 20.2); non-cryptographic random generators for security values (Part 20.9).
- **Hash usage:** using a fast general-purpose hash for passwords; using a hash as a "signature" without a secret key (length-extension and forgery issues for some constructions; verify the primitive you use); truncated hashes colliding under attack.
- **Deterministic encryption or hashing of low-entropy data** (phone numbers, national IDs, email addresses) can be reversed by brute force over the small input space, even if the algorithm is strong. Hashing a phone number is not anonymization.
- **Signature verification on parsed rather than raw data** (webhooks, Part 20.11): re-serialization changes bytes.
- **Replay:** validly signed messages accepted repeatedly or long after creation. Include timestamps, nonces, or sequence numbers, and enforce them.
- **Key confusion between purposes:** using the same key for signing and encryption, or for different token types.
- **Post-quantum and algorithm agility:** data that must stay confidential for decades may be recorded now and decrypted later. Systems with hard-coded algorithms cannot migrate. This is a time-horizon edge case (Family E/I).

### 32.3 Randomness and identifiers as security controls

- IDs used as capabilities ("unguessable URL" sharing) must be long and generated with cryptographic randomness; sequential or timestamp-based IDs are enumerable.
- **Password reset and invitation tokens stored in plain text** in the database (a database read leak then equals account takeover). Store only a hash of tokens, compare on use.
- Tokens with no expiry or no single-use enforcement.

---

## Part 33: Injection, Deserialization, and Dangerous Interpreters

### 33.1 The common root

**Any place that builds an instruction for another system out of strings that include external data.** Each target has its own grammar and escaping rules.

| Target | Mechanism | Root fix |
|---|---|---|
| SQL/NoSQL queries | Data concatenated into query text; operators supplied as objects in NoSQL query documents | Parameters; strict type validation; never pass raw request objects into queries |
| Shell/OS commands | String concatenation into a command line; filenames beginning with a dash interpreted as options | Avoid shells; pass argument arrays; use option terminators; allowlist |
| Templates (server-side) | User input compiled as template source | Never compile user input as a template; sandbox if unavoidable |
| HTML/JavaScript output | Unescaped data in the wrong context (HTML body, attribute, script, URL, CSS each need different escaping) | Context-aware auto-escaping; content security policy as a backstop |
| Headers/log lines | Newlines in input forge headers or log entries | Reject or encode control characters |
| LDAP/XPath/expression languages | Same pattern | Parameterized APIs or strict escaping |
| Regex construction | User text interpreted as a pattern | Escape literals; bound complexity |
| File paths | `..` segments, absolute paths, symlinks, encoded separators, reserved names on some platforms | Resolve to a canonical path then verify it is inside the allowed directory; use generated storage names |
| URLs | Redirect targets, fetch targets, embedded credentials, unusual schemes | Parse with one library; allowlist scheme and host |
| Email | Header injection through newlines in recipient or subject fields | Use libraries that reject control characters |
| Serialization formats | Type-carrying formats instantiate arbitrary classes | Use data-only formats; allowlist types |
| Spreadsheet exports | Cells beginning with `=`, `+`, `-`, `@` executed as formulas when opened | Prefix or escape leading characters in exported fields |
| Prompts to language models | Untrusted text treated as instructions | Separate instructions from data; limit tool privileges; treat model output as untrusted input to downstream systems |

**Second-order injection:** data stored safely, later read by a different component and used unsafely (a username containing a query fragment stored correctly, then concatenated by an admin report). Trust labels must not be dropped at storage.

**Context-switch mistakes:** escaping for one context, using in another (HTML-escaped text placed into JavaScript, or URL-encoded text placed into a shell command).

### 33.2 Deserialization

- Deserializing untrusted data with a format that can instantiate arbitrary types or run code during construction is a direct path to remote code execution in many languages (verify for each runtime and library).
- **Gadget chains:** harmless classes on the classpath combine into an exploit, so the risk grows with every added dependency.
- Even "safe" formats can have **resource attacks:** deeply nested structures, huge numbers, duplicate keys with different interpretation, or large allocations from small inputs.
- **Type confusion:** a field expected to be a string arrives as an object or an array, taking a different code path (especially in dynamically typed languages and query builders).
- **Prototype or property pollution** (in languages with mutable object prototypes): merging untrusted objects into internal ones alters behavior globally.
- **Schema-less acceptance:** unknown fields preserved and forwarded to downstream systems, carrying unexpected commands or flags.

### 33.3 Server-side request forgery and outbound fetches

Any feature where the server fetches a URL chosen or influenced by a user (webhooks, image proxy, link preview, import-from-URL, PDF renderer, avatar fetch, federation) is a door into your internal network.

- **Targets:** internal services, cloud metadata endpoints, loopback, link-local ranges, private address ranges, admin panels, and cluster control APIs.
- **Validation bypasses:** alternative IP notations (decimal, octal, hexadecimal, IPv6-mapped), DNS names that resolve to internal addresses, DNS rebinding (resolves externally at check time, internally at use time), redirects from an allowed host to an internal one, URL parser differences, and alternate schemes (file, gopher, and others).
- **Blind SSRF:** no response visible, but the request itself triggers an action or exfiltrates timing and existence information.
- **Fix layers:** allowlist destinations where possible; resolve the name yourself, verify the *resolved* address is public, and connect to that exact address; disable or re-validate redirects; restrict the fetcher's network egress at the infrastructure level (so the code-level check is not the only barrier); require metadata-service protections; run fetchers in an isolated network segment with no credentials; apply size, time, and type limits.

### 33.4 File handling and content processing

- **Content sniffing:** the browser or downstream program guesses a type different from the declared one; an uploaded "image" served from your own domain executes as HTML or script in a viewer's browser. Serve user content from a separate origin, with explicit content type and download disposition.
- **Polyglot files** valid as two formats.
- **Archive extraction:** path traversal through entry names, symlinks inside archives, decompression bombs, too many entries.
- **Image and document processors:** memory and CPU bombs (small file, enormous dimensions), vulnerable parser libraries, metadata containing location data (privacy) or scripts. Process in a sandbox with limits.
- **Filename issues:** reserved device names, trailing dots or spaces, case-insensitive collisions, right-to-left override characters that disguise extensions, extremely long names, null bytes.
- **Antivirus and scanning races:** files served before scanning completes.
- **Temporary files:** predictable names, world-readable permissions, not deleted on error.
- **Storage ACLs:** public-read defaults, bucket policies that allow listing, pre-signed URLs with excessive lifetime or scope.

### 33.5 Web-specific edge cases

- **Cross-origin behavior:** overly permissive cross-origin resource sharing (reflecting any origin, allowing credentials with wildcard-like matching, trusting `null` origins); missing clickjacking protection on sensitive actions.
- **Open redirects** used for phishing and protocol attacks.
- **Host header trust:** building absolute links (password reset, email) from a request header.
- **Cache poisoning and deception:** shared caches storing responses that depend on headers not in the cache key, or caching authenticated pages under public-looking URLs (a path suffix trick making a private page look like a static asset).
- **Request smuggling and desynchronization** when a proxy and backend disagree on where a request ends (parser differential).
- **Client-side storage:** tokens in places accessible to scripts; sensitive data persisting after logout; shared computers.
- **Third-party scripts** with full page access (payment pages, admin consoles): a compromised vendor is a compromise of you.
- **Subdomain takeover:** dangling DNS records pointing to decommissioned services (Part 12.4).
- **Mixed content, downgrade, and insecure redirect chains.**
- **Unicode domain lookalikes** in links and brands.

---

## Part 34: Business Logic Abuse

Business logic flaws have no signature and no scanner. Each one is a *correct implementation of a flawed rule.* They are rooted in Family B (model) and Family C (invariants), seen through an adversary.

### 34.1 Money and value

- **Race conditions on balances, limits, and single-use items:** many parallel requests executed together spend a coupon, gift card, or withdrawal limit multiple times (Part 3.4 and 10.1). The test is to send N identical requests simultaneously and check the outcome.
- **Negative and boundary values:** negative quantity yielding a credit, zero price, discounts over 100%, integer overflow on totals, extremely large quantities, fractional units.
- **Currency and rounding exploitation:** repeated conversion or splitting that gains a fraction per transaction at scale; differences in rounding between two systems.
- **Refund and chargeback logic:** refunding more than paid, refund after a discount, double refund through concurrent requests, refund to a different instrument than the original, keeping the goods and the credit.
- **Promotion stacking:** combinations of coupons, credits, trials, and referral rewards that the designers never tested together.
- **Referral and reward loops:** self-referral, fake accounts, circular referral chains.
- **Free trial abuse:** repeated trials via email variations (plus-addressing, dots), disposable domains, device resets.
- **Price and plan changes mid-cycle:** proration rounding, downgrade credit timing, changing plan right before renewal to exploit the order of charge and entitlement updates.
- **Entitlement lag:** access granted on payment start, not payment confirmation, or retained after failure or refund.
- **Trusting client-supplied totals, prices, or currencies.**
- **Ledger asymmetries:** operations that create value in one place without a matching debit (Part 14.1 reconciliation).

### 34.2 Workflow and state abuse

- **Skipping steps, replaying steps, reordering steps** (Part 31.2).
- **Invalid transitions:** cancel after ship, edit after approval, reopen after closure, approve your own request.
- **Approval separation of duties:** the requester can also approve (via a second account, role overlap, or a direct API call).
- **Time-of-check gaps in approvals:** approved content modified after approval.
- **Deadline and window abuse:** acting just before a cutoff to exploit stale snapshots; manipulating the client clock where it governs eligibility.
- **Resource hoarding:** reserving inventory, seats, usernames, or rate-limited slots without completing (and with no expiry on the reservation), denying others.
- **Scarcity abuse:** automated purchasing of limited goods; ticket or appointment hoarding.
- **Account lifecycle abuse:** deleting and recreating accounts to reset limits, reputations, bans, or trial status; merging accounts to combine entitlements; transferring accounts.

### 34.3 Information leakage as logic abuse

- **Enumeration oracles:** any endpoint that answers "does X exist / is X valid" (usernames, emails, invite codes, coupon codes, order numbers, gift card numbers).
- **Differences in responses, timing, sizes, or ordering** reveal hidden state.
- **Side channels in aggregates:** a statistic over a tiny group reveals an individual; repeated filtered counts reconstruct hidden data.
- **Verbose errors, stack traces, debug endpoints, source maps, API documentation of internal endpoints, and leftover test endpoints.**
- **Metadata leakage:** file metadata, email headers, timestamps revealing activity patterns.
- **Predictable resource names** and sequential IDs revealing business volume (Part 10.5).

### 34.4 Abuse of legitimate features

Every feature has a hostile use:
- **Notifications and messaging features** used for spam, harassment, phishing, or as an amplification vector (send an email to any address with your content; your domain reputation pays).
- **Import, export, and sync** used to exfiltrate or to overload.
- **Webhooks and callbacks** used to attack third parties (your system becomes the source of a flood).
- **Search and autocomplete** used as data scrapers.
- **Invitations and sharing** used to reach users with attacker content.
- **Free storage and hosting features** used to serve malware or illegal content from your domain.
- **Programmatic access** (API keys) abused for scraping, cost inflation, or competitive extraction.
- **Support channels** used for social engineering (Part 34.5).

**Question to ask of each feature:** "If someone wanted to use this to harm a user, to harm a third party, to harm us financially, or to extract data, how would they do it?" (This is the *abuse case*, the counterpart to a use case.)

### 34.5 Social engineering and human-process edge cases

Technical controls are often bypassed through people and processes:
- **Support staff able to reset access or change contact details** with weak identity verification; call-center procedures that can be guessed or pressured.
- **Account recovery through customer support** becoming the real authentication mechanism.
- **Internal tooling with broad powers and weak audit.**
- **Urgency and authority pressure** ("the CEO needs this now") bypassing approval steps for payments or access.
- **Change of bank details or vendor payment instructions** accepted by email without out-of-band verification.
- **Onboarding and offboarding gaps:** access granted quickly and removed slowly; accounts of departed staff and contractors remaining active; shared accounts and shared credentials nobody can attribute.
- **Insider threat and mistakes:** excessive standing access, no separation of duties, no alert on unusual bulk access.
- **Phishing of your own staff** yielding session tokens (which bypass passwords and some forms of MFA); device trust and session binding reduce this.
- **Recruiting and vendor risk:** a new employee or contractor with production access on day one.

---

## Part 35: Supply Chain, Build, and Deployment Security

### 35.1 Dependency and package edge cases

- **Typosquatting and dependency confusion:** a public package with the same name as an internal one, with a higher version number, preferred by the resolver; or a near-miss name installed by mistake. Configure resolvers to prefer or restrict to internal sources for internal names.
- **Abandoned and transferred packages:** ownership changes hands, and a malicious update follows.
- **Install-time code execution:** build and install scripts run with the developer's or CI's privileges.
- **Transitive dependencies** that nobody reviewed (your risk includes their entire tree).
- **Version range drift:** a floating range silently pulls a new (possibly malicious or breaking) version into a build.
- **Lockfile bypass:** builds that ignore or regenerate lockfiles.
- **Vulnerability disclosure lag:** the time between a flaw existing, being disclosed, your noticing, and your deploying. Inventory (what is actually running where) is the prerequisite for response.
- **Vulnerable-but-unreachable vs. reachable:** not all reports matter, but without knowing your usage you cannot tell.
- **End-of-life components** with no fixes available.

### 35.2 Build and pipeline trust

- **CI with write access to production and read access to all secrets:** anything that can modify the pipeline definition (a pull request from a fork, a dependency's script) can reach them. Separate untrusted build steps from privileged deploy steps; do not expose secrets to builds triggered by untrusted code.
- **Pipeline configuration as code changed by the same people it constrains,** with no independent review.
- **Self-hosted runners** shared across projects, persisting state and credentials between jobs.
- **Artifact integrity:** unsigned artifacts; no link between deployed binary and source commit; mutable tags; build caches poisoned by an earlier job.
- **Third-party build actions or plugins** referenced by mutable version (a moved tag now runs different code). Pin by immutable identifier.
- **Reproducibility:** if you cannot rebuild the same artifact, you cannot verify it or trust a rollback.
- **Emergency bypass paths** that become the normal path.
- **Secrets printed by debug modes** in logs that are visible to a wider audience than the secret.

### 35.3 Cloud identity and configuration security

- **Over-permissioned roles** (wildcard actions and resources) turning any single bug (SSRF, injection, stolen token) into full account access.
- **Privilege escalation through permission combinations:** permission to create or modify roles, pass roles to services, or alter policies is effectively administrator access.
- **Trust relationships** between accounts and roles that are broader than intended (any principal in another account, or any caller of a service).
- **Long-lived access keys** in code or on laptops.
- **Public exposure by configuration:** storage buckets, snapshots, databases, dashboards, message brokers, container registries, admin consoles, debug ports. Often introduced by a default, a template, or a temporary change.
- **Network rules:** `0.0.0.0/0` on administrative ports; security groups edited during an incident and never reverted.
- **Logging disabled or not retained** for audit-relevant services, discovered only after an incident.
- **Single account holding everything** (production, backups, logs, security tooling): compromise of one role deletes the evidence and the recovery copies (Part 10.9).
- **Resource deletion by attackers** as an extortion step: deletion protection, backup immutability, and separate recovery accounts.
- **Shadow infrastructure:** resources created manually, outside infrastructure-as-code and inventory, never patched or monitored.
- **Abandoned resources** (old test environments, forgotten servers, dormant accounts) that still hold data and credentials.

### 35.4 Containers and orchestration security edge cases

- Containers running as root, with host mounts, privileged mode, or the container runtime socket mounted: a compromise of the container is a compromise of the host and potentially the cluster.
- Broad cluster roles assigned to workloads; service account tokens auto-mounted into pods that do not need them.
- Secrets stored unencrypted or readable by all workloads in a namespace.
- Network policies absent: any pod can reach any other, including the control plane and metadata service.
- Image provenance: pulling from public registries, unpinned bases, unscanned images, images that embed credentials.
- Admission controls missing: anyone with deploy rights can run arbitrary privileged workloads.
- Shared clusters across trust levels (tenants or environments) with shared kernel and network.
- Debug and management interfaces exposed (dashboards, kubelet APIs, metrics).

---

## Part 36: Abuse, Denial of Service, and Cost Attacks

### 36.1 Resource exhaustion shapes

Denial of service does not require a flood. Cheap requests that trigger expensive work are more effective (Family F seen adversarially):
- **Algorithmic complexity:** regex backtracking, hash collisions in collections (verify for your runtime), pathological sort inputs, nested structure processing (Part 20.3 and 20.4).
- **Amplification through the application:** one request triggers many database queries, many outbound calls, many emails, many background jobs (fan-out; Part 9.4).
- **Expensive endpoints:** search with wildcards, report generation, export, image transformation, PDF rendering, graph queries with deep nesting, pagination with large offsets (Part 10.6).
- **Large and slow inputs:** slow uploads holding connections open (slowloris-style), huge headers, huge bodies, many small requests.
- **Stateful exhaustion:** session table filling, unverified signups creating rows, unfinished multi-part uploads consuming storage, reservations never released (Part 34.2).
- **Cache bypass:** unique query strings or nonexistent keys forcing every request to the origin (Part 20.7).
- **Lockout and quota exhaustion against a victim:** consuming a shared third-party quota (your email provider, SMS provider, or API limits) so legitimate users are blocked.

### 36.2 Cost as an attack surface

- **Pay-per-use services** (functions, SMS, email, AI inference, data transfer, storage requests, log ingestion): an attacker or a bug can produce a large bill. SMS and phone-verification endpoints are classic targets, where attackers trigger messages to premium-rate numbers they profit from.
- **Unbounded autoscaling** converting an attack into a bill.
- **Log and telemetry volume** inflated by error generation.
- **Egress charges** from data exfiltration or scraping.
- **Budget controls:** hard limits where the provider supports them, alerts on rate of spend (not only total), per-key and per-tenant caps, and kill switches for costly features that do not depend on the affected system.

### 36.3 Rate limiting edge cases

- **Identity keyed wrongly:** by IP only (shared NAT users blocked together, attackers rotate addresses), by account only (no protection for pre-login endpoints), by API key only (an attacker creates many keys or accounts).
- **Trusting forwarded headers** for client IP (spoofable unless your own proxy sets and overwrites them).
- **Limit per instance vs. global:** N instances each allowing M requests gives N x M; a shared counter store becomes a dependency (what happens when it is down: fail open or fail closed?).
- **Window edge behavior:** fixed windows allow a burst of twice the limit across a boundary; token or leaky bucket designs behave better.
- **Counting the wrong thing:** requests vs. cost. A cheap request and an expensive request should not consume the same quota.
- **Retry interactions** (Part 22.1): limiter penalizes retries of failed requests and locks out legitimate traffic.
- **Limits on authenticated users only,** leaving signup, login, reset, and public endpoints open.
- **No limit on concurrency,** only on rate (ten slow requests at once can exhaust resources even under the rate limit).
- **Distributed attackers** staying under each individual limit; detection needs aggregate behavior analysis.
- **Response semantics:** limiter responses that reveal information, or that clients misinterpret and retry harder.

### 36.4 Bots, scraping, and automation

- Scraping for data extraction, price monitoring, inventory hoarding, content theft.
- Credential stuffing infrastructure using residential proxy networks, which look like normal users.
- Fake account creation at scale for promotions, reviews, spam, and referral fraud.
- **Business decision edge:** blocking aggressively harms accessibility and legitimate automation (assistive technologies, partners); blocking weakly invites abuse. Decide with data.
- **Challenges (captcha-like mechanisms) as dependencies:** if the provider fails, does registration stop or open?

---

## Part 37: Privacy and Data Lifecycle Edge Cases (Extending Part 19.12)

### 37.1 Data collection and minimization

- **Collecting "just in case":** every stored field is a liability in a breach and an obligation in deletion requests.
- **Derived and inferred data:** embeddings, profiles, segments, scores, and model features derived from personal data are personal data, and often not included in deletion and export processes.
- **Free-text fields** accumulate personal and sensitive data that you never intended to collect (support tickets, notes, chat, comments, search queries, file names).
- **Identifiers in URLs, query strings, and analytics events** flow to third parties and logs.
- **Metadata** (IP addresses, device identifiers, precise timestamps, location) enabling re-identification.
- **Combining datasets** can re-identify individuals in data that looked anonymous; removing names is not anonymization. Small groups and unique combinations (postal code, birth date, gender) identify people.
- **Test and staging environments using production data copies,** with weaker controls, broader access, and no deletion process.

### 37.2 Data flow edge cases

- **Third-party SDKs and tags** sending data to their own servers, including data you did not intend to share; updates changing what they collect.
- **Logs, traces, error reports, and session replay tools** capturing form inputs, tokens, and personal data.
- **Email and notification content** containing sensitive data, delivered through systems and inboxes you do not control; links in emails that work without authentication.
- **Cross-border transfers** and data residency: backups, replicas, analytics pipelines, support tooling, and subprocessors located elsewhere than the primary store.
- **Shared links and embeds** that expose data after sharing intent has changed.
- **Copy and export:** data downloaded to laptops, spreadsheets, and chat, outside the controls of the source system.
- **Internal access without need:** employees browsing records (curiosity access) when there is no technical control or audit.

### 37.3 Subject rights and lifecycle

- **Access and export requests:** completeness across all systems (Part 19.12's inventory of where data lives), identity verification of the requester (an attacker can file a request to obtain someone else's data), and redaction of other people's data within the export.
- **Deletion and retention conflicts:** legal holds, financial record obligations, fraud prevention needs, backups (Part 19.12), and downstream copies in partner systems.
- **Consent and purpose:** data collected for one purpose repurposed; consent withdrawal not propagating to downstream processing and caches; consent state stored in one place and ignored by pipelines that read from another.
- **Children and special categories:** age handling, parental consent flows, and sensitive categories needing stricter treatment, with mistakes having higher legal and ethical consequences.
- **Account merges and splits** mixing data across individuals.
- **Deceased users, inactive accounts,** and data kept indefinitely with no retention policy.
- **Re-identification through deletion:** a deleted user's ID reused or their data remaining in aggregated or anonymized sets that can be linked back.

### 37.4 Breach readiness edge cases

- You cannot scope a breach without an inventory of data, access logs with enough retention, and knowledge of which records a compromised credential could reach.
- **Notification deadlines** are short; the decision process, contact lists, and draft communications need to exist beforehand.
- **Evidence preservation vs. recovery:** restoring service can destroy forensic evidence; decide and practice the trade-off.
- **Attackers disabling logging or deleting logs:** ship logs to a separate, append-only store with separate credentials.
- **Credentials exposed in the breach** need revocation at scale, and mass forced resets are themselves a load, support, and phishing event (Part 22.4).
- **Communication channel compromise:** the incident is being discussed in a channel the attacker can read; plan an out-of-band channel.

---

## Part 38: Detection and Response Edge Cases

### 38.1 Security logging pitfalls

- **Not logging security-relevant events:** failed and successful logins, permission changes, privilege use, data exports, configuration changes, API key creation, admin actions, and access to sensitive records.
- **Logging too much of the wrong thing** (secrets, personal data; Part 11.10).
- **Logs an attacker can alter or delete** with the same credentials that compromised the system.
- **Log injection:** attacker-controlled text forging entries (Part 33.1).
- **Timestamps and identity:** missing user or request identity, unsynchronized clocks across systems (Part 21.4), or shared accounts that make attribution impossible.
- **Retention shorter than dwell time:** attackers often stay for weeks or months; logs from the initial intrusion are gone by discovery.
- **Sampling and aggregation** that drop the rare event that matters.
- **No baseline:** without normal patterns, nothing looks abnormal.

### 38.2 Detection logic edge cases

- **Signature-based detection** defeated by trivial variation; **anomaly-based detection** drowned in false positives and eventually ignored (alert fatigue, Part 4.7).
- **Slow and low attacks** that stay under thresholds (a few requests per hour per account across thousands of accounts).
- **Legitimate-looking attacks:** valid credentials, normal tools, normal hours. The attacker uses your own administrative features.
- **Detectors that share fate** with the thing detected: an agent on a compromised host, which the attacker can disable.
- **Coverage gaps:** unmanaged assets, forgotten accounts, new cloud services, SaaS applications outside central logging.
- **Alert without context:** an alert that cannot answer "what else did this identity do?"
- **Untested detections:** never verified that a known-bad action actually triggers the alert (Part 14.3).

### 38.3 Incident response edge cases

- **Containment vs. business continuity:** isolating a system may halt revenue; the decision criteria and authority should be agreed in advance.
- **Credential rotation order and completeness:** rotating some secrets but missing one that remains valid gives the attacker persistence. Persistence mechanisms (new accounts, added keys, scheduled tasks, modified code, added trust relationships, inbox forwarding rules, OAuth app grants) must be hunted, not only the initial entry point.
- **Rotation causing outage,** especially for secrets with undocumented consumers (Part 32.1).
- **Scope uncertainty:** treating the first-found compromised system as the whole incident.
- **Access needs during an incident:** the responders' accounts, tooling, and communication depend on the compromised identity provider or cloud account.
- **Backups potentially containing the compromise** (restored malware, restored vulnerable configuration, restored attacker accounts) and the question of which restore point is clean.
- **Legal, regulatory, insurance, and customer obligations** with deadlines that start at awareness, not at confirmation.
- **Human factors:** long incidents, fatigue, unclear roles, and decisions made without a record.
- **Post-incident drift:** fixes applied in a hurry are not made permanent, or hotfix access remains.

---

## Part 39: Worked Cases (Security Root-Cause Chains)

### Case 24: The account takeover through "verified by email"

- **Symptom:** users find their accounts accessed; no password was guessed.
- **Trigger:** attacker signs up at a third-party provider with the victim's email (unverified there), then uses "sign in with that provider."
- **Proximate cause:** the application linked accounts by email without checking that the identity provider had verified it.
- **Root causes:** **B** (identity modeled as an email string; the meaning of "verified" not modeled), **D** (the claim's semantics mismatched between provider and application), **A** (assumed all providers check email ownership).
- **Class-level fix:** link identities by stable provider subject identifiers; require explicit, authenticated linking by the existing account holder; accept only verified attributes; review each provider's guarantees.

### Case 25: The refund that paid twice

- **Symptom:** finance finds refunds exceeding payments for certain orders.
- **Trigger:** two refund requests submitted at the same instant.
- **Proximate cause:** each request read "refundable balance: 50," each issued 50.
- **Root causes:** **E** (check separated from act), **C** (the invariant "total refunds never exceed payment" not enforced at the ledger), **H** (no reconciliation of refunds vs. payments).
- **Class-level fix:** an atomic conditional update on the refundable balance or a constraint; idempotency keys on refund requests; ledger reconciliation with alerts; load-test the financial endpoints with concurrent identical requests.

### Case 26: The internal URL fetcher that read cloud credentials

- **Symptom:** unexpected cloud resource creation in an unknown region; leaked instance credentials.
- **Trigger:** a "preview this link" feature fetched an address that resolved to the cloud metadata service.
- **Proximate cause:** validation checked the hostname string, not the resolved address; redirects were followed.
- **Root causes:** **A** (assumed users provide only public URLs), **E** (validation and fetch resolved names separately), **G** (the application's role carried wide permissions; the metadata endpoint was reachable from the application network), **C** (nothing at the infrastructure level enforced "this service cannot reach internal addresses").
- **Class-level fix:** Part 33.3 layers: resolve-then-connect to verified public addresses, egress restrictions at the network, hardened metadata access, least-privilege role for the fetcher, isolated fetch service.

### Case 27: The leaked secret that was "removed"

- **Symptom:** months after a developer deleted a committed key, it was used by an outsider.
- **Trigger:** automated scanning found the key in repository history.
- **Proximate cause:** removal did not revoke; the key remained valid and broad.
- **Root causes:** **F/H** (credential with no expiry and no inventory), **K** (rotation was hard so nobody did it), **C** (credential permissions not bounded).
- **Class-level fix:** treat any exposed secret as compromised and rotate first; short-lived credentials; secret scanning in pre-commit and CI; inventory with owners; rotation as a routine, rehearsed operation.

### Case 28: The tenant filter that one query forgot

- **Symptom:** a customer sees another customer's invoice in an export.
- **Trigger:** a new export query written by a different team.
- **Proximate cause:** the query lacked the tenant condition.
- **Root causes:** **C** (isolation enforced by developer discipline in each query, not structurally), **K** (new team unaware of the convention), **J** (no cross-tenant test).
- **Class-level fix:** structural isolation (row-level policies, tenant-scoped data-access layer that cannot omit the filter); automated tests that create two tenants and assert no cross-visibility on every endpoint; export and background jobs included in the test matrix.

### Case 29: The SMS endpoint that became a revenue stream for someone else

- **Symptom:** a messaging bill increases about 200x in a weekend.
- **Trigger:** an unauthenticated phone-verification endpoint.
- **Proximate cause:** an attacker triggered verification messages to numbers they profit from.
- **Root causes:** **F** (unbounded cost resource), **K** (cost not treated as a risk), **H** (spend alerts at monthly totals only).
- **Class-level fix:** per-number, per-IP, per-account, and global limits; geographic and number-type restrictions; challenges before sending; spend-rate alerts and hard caps; alternative verification methods.

### Case 30: The reset link pointing to the attacker

- **Symptom:** victims receive genuine reset emails and complete a reset on an attacker's page.
- **Trigger:** a forged host header on the reset request.
- **Proximate cause:** the application built the link from the request's host header.
- **Root causes:** **A** (assumed headers reflect your domain), **D** (proxy and application disagree about which header is authoritative), **A**/**K** (configuration lacked a fixed canonical base URL).
- **Class-level fix:** a configured canonical origin for link generation; validate allowed hosts; short-lived single-use tokens bound to the account; notify the user of reset attempts.

### Case 31: The CI job that ran untrusted code with production secrets

- **Symptom:** production credentials are used from an unfamiliar network.
- **Trigger:** an external contributor's pull request modified a build script.
- **Proximate cause:** the pipeline ran the changed script with secrets available.
- **Root causes:** **G** (build and deploy trust levels shared), **C** (secrets not scoped to trusted refs), **K** (pipeline config reviewed less than application code).
- **Class-level fix:** no secrets for untrusted builds, separate privileged deployment stages requiring approval, short-lived credentials from an identity federation with scoped trust, pipeline changes reviewed as production code.

### Case 32: The JWT that named its own algorithm

- **Symptom:** an attacker accesses administrative APIs without credentials.
- **Trigger:** a forged token declaring a weaker verification algorithm.
- **Proximate cause:** the verifier used the token header to choose the algorithm and key handling.
- **Root causes:** **D** (contract: untrusted data controlling the trust decision), **B** (verification treated as a property of the token rather than of the expected configuration), **J** (no negative tests with malformed tokens).
- **Class-level fix:** server-side fixed algorithm and key per issuer, strict claim validation (issuer, audience, expiry), library versions reviewed, and negative test vectors in CI.

### Case 33: The password reset that survived the password change

- **Symptom:** an attacker who had briefly accessed an email inbox returns days later after the user secured their account.
- **Trigger:** an old reset link was still valid, and active sessions persisted.
- **Root causes:** **E** (lifecycle of tokens not tied to account state), **C** (no invariant that credential change invalidates sessions and pending tokens).
- **Class-level fix:** on password change, invalidate reset tokens, revoke sessions and refresh tokens, notify the user; expire tokens quickly; single-use enforcement.

---

## Part 40: Categorizing Security Issues

These extend Part 13. Use them together with the existing axes.

### 40.1 By attacker capability required
- **Unauthenticated remote** (internet anonymous).
- **Authenticated low-privilege user** (any customer).
- **Malicious tenant admin.**
- **Insider with production access.**
- **Compromised dependency or vendor.**
- **Network-adjacent or man-in-the-middle.**
- **Physical or device-level access.**
Priority rises sharply as the capability needed falls.

### 40.2 By security property violated
- **Confidentiality** (data exposure).
- **Integrity** (unauthorized modification, forged actions).
- **Availability** (denial of service, lockout, cost exhaustion).
- **Authenticity and non-repudiation** (cannot prove who did what; forged identity).
- **Accountability** (missing or altered audit).
- **Privacy** (exposure or use of personal data beyond purpose).
- **Safety** (physical or financial harm).

### 40.3 By STRIDE-style threat type
**S**poofing, **T**ampering, **R**epudiation, **I**nformation disclosure, **D**enial of service, **E**levation of privilege. Walk each trust boundary and data flow with these six prompts.

### 40.4 By where the control failed
- **Missing control** (nothing existed).
- **Misplaced control** (client-side, wrong layer, bypassable path).
- **Incomplete control** (covers some endpoints, methods, tenants).
- **Flawed control** (present but wrong logic).
- **Misconfigured control** (correct design, wrong setting or default).
- **Bypassed control** (alternative path, fallback, admin tool).
- **Decayed control** (worked once; expired, drifted, disabled).
- **Unmonitored control** (working or not, nobody knows).

### 40.5 By exploit chain role
- **Initial access**, **privilege escalation**, **lateral movement**, **persistence**, **data access/exfiltration**, **impact**, **evidence destruction.**
A finding that looks minor alone (an open redirect, verbose error, weak role) may be the **link** that completes a chain. Rate findings also by the chain they enable.

### 40.6 Security-specific severity multipliers (add to Part 25.3)
- Exploitable without authentication: x3.
- Exploitable at scale with automation (no per-victim effort): x2.
- Gives access to credentials or keys (enabling further compromise): x3.
- Undetectable with current logging: x2.
- Cross-tenant or cross-customer reach: x3.
- Regulated or highly sensitive data: x2.
- Persistence possible (survives password change or patch): x2.

### 40.7 Security finding record (extends the Part 13 record)

```
finding:              <one line>
attacker capability:  <40.1>
property violated:    <40.2 / STRIDE letter>
control failure type: <40.4>
chain role:           <40.5> and what it enables in combination
preconditions:        what must be true for exploitation
evidence of exploitation: would we see it? (logs, alerts, retention)
blast radius:         one user / tenant / all / infrastructure
data or value at risk:
immediate mitigation: (limit now)
class-level fix:      (remove the whole class)
sibling search:       (where else is the same pattern)
verification:         (test, scanner rule, guard in CI)
owner + date
```

---

## Part 41: Methods for Finding Security Unknown Unknowns

### 41.1 Threat modeling that finds real problems

A workable four-question structure:
1. **What are we building?** Draw the data flow diagram: actors, processes, data stores, and **trust boundaries**.
2. **What can go wrong?** Apply STRIDE (40.3) at each boundary crossing and each data store. Add abuse cases (34.4).
3. **What are we going to do about it?** Prevent, detect, limit, recover, or accept (Part 13, Axis 7).
4. **Did we do a good job?** Verify with tests, reviews, and exercises.

Common failure modes of threat modeling: done once and never updated; drawn at too high a level (one box called "backend"); performed only by the builders (curse of knowledge, Part 9.9); ignoring the deployment and operations layer; producing a document but no tracked actions.

### 41.2 Attack trees and kill chains

Start from an attacker goal ("read another tenant's data", "obtain production credentials", "make money from our payment flow") and decompose it into alternative ways (OR) and required combinations (AND). Annotate each leaf with cost, skill, detectability. Focus on the *cheapest path*, which is usually neither the most technical nor the one defenders are watching.

### 41.3 Abuse and misuse cases

For each use case, write its hostile twin. Systematically ask, for each field and each feature: *what is the most damaging valid-looking input? What does a hostile competitor, a fraudster, a stalker, an angry ex-employee, or an automated scraper do here?* Include **safety** cases for products involving personal safety (stalking through location sharing, contact discovery, or shared accounts).

### 41.4 Differential authorization testing

The most effective practical technique for access control edge cases:
- Create at least two users per role and two tenants.
- Record every request of user A (all endpoints, all methods, all object IDs).
- **Replay them as user B, as a lower role, as unauthenticated, and as another tenant's user**, and compare results.
- Include background outputs: exports, emails, notifications, webhooks, search, and cached responses.
- Automate this in CI against all routes (generated from your route list) so a new endpoint without a policy fails the build.

### 41.5 Race-condition testing

For any rule of the form "only once / at most N / if enough balance": fire many identical requests simultaneously (aligned to start together) and verify the invariant afterward. Include single-use tokens, coupon redemption, withdrawals, invitation acceptance, vote casting, inventory purchase, and account creation with the same email.

### 41.6 Fuzzing and negative testing at boundaries

Parsers, file processors, protocol handlers, and deserializers benefit from fuzzing (coverage-guided where possible). For APIs: type confusion (array instead of string, object instead of number), oversize and undersize values, unusual encodings, duplicate parameters, unexpected content types, and missing required fields. Keep every crash as a permanent test.

### 41.7 Secret and exposure scanning

Regularly scan repositories (including history), images, CI logs, configuration, and storage for credentials; scan your external attack surface (domains, subdomains, open ports, exposed services) as an outsider would; monitor for your credentials and data appearing in public leaks. Combine with an *asset inventory*, since you cannot defend what you do not know you run.

### 41.8 Red team, purple team, and tabletop exercises

- **Red team:** authorized adversarial simulation with a specific goal, testing people and detection as well as systems.
- **Purple team:** attackers and defenders working together, running each technique and checking whether it was detected; the output is detection coverage.
- **Tabletop exercises:** walk through a scenario with decision makers ("the database is encrypted by ransomware; backups are deleted; it is Friday night") to find the gaps in authority, communication, and dependencies.
- **Assume breach:** design reviews starting with "an attacker has already obtained one credential or one host; how far can they get, and how would we know?"

### 41.9 Metrics that reveal security posture

- Time to patch critical vulnerabilities, by asset class.
- Percentage of secrets with a known owner, rotation date, and scope.
- Percentage of endpoints covered by automated authorization tests.
- Privileged accounts count and age; stale accounts count.
- Mean time to detect and to contain in exercises.
- Number of public-facing assets not in inventory.
- Coverage of logging for sensitive actions.
- Backup restore test recency (Part 10.9), including from the recovery account.

---

## Part 42: Security Question Bank

**Trust and boundaries**
- Where does each input originate, and who could influence it?
- What do we trust because of *where it came from* rather than *what it is*?
- What would happen if this internal caller were compromised or this internal data contained hostile input?

**Identity and sessions**
- What exactly is "the same user"? What could make two identities collide or a stranger inherit one?
- Which recovery path is the weakest, and does it bypass our strongest control?
- When privileges, passwords, devices, or employment change, what happens to every existing session, token, key, and link?

**Authorization**
- For every endpoint, method, background job, export, and notification: who is allowed, and where is that enforced?
- What if the object ID in this request belongs to someone else? What if it belongs to another tenant? What if it is nested under a parent that does not match?
- If our authorization dependency fails or errors, what do we do?

**Secrets and keys**
- If this secret leaked today, could we rotate it without outage, and how quickly?
- Who can read it, where is it copied, and what does it unlock?
- If we lost this key, what data is unrecoverable? Have we tested restoring with it?

**Interpreters**
- What other system interprets strings we build, and what does its grammar allow?
- Is there any place where untrusted data becomes code, a command, a path, a template, a query, or a URL fetch?

**Business logic**
- What is the most profitable or most damaging valid-looking sequence of actions here?
- What if the same request is sent 100 times at once? What if steps are skipped or reordered?
- Where can value be created without a matching debit?

**Abuse and cost**
- What can an anonymous person make our system do that costs us money or harms someone else?
- Which endpoint has the highest cost per request, and what limits it?

**Supply chain and operations**
- What runs with our credentials that we did not write?
- Who or what can change our pipeline, our infrastructure, or our dependencies, and who reviews it?

**Detection and response**
- If an attacker used a valid credential to access data quietly for 30 days, what would show it?
- Do our logs survive a compromise of the thing they describe?
- If our identity provider, cloud account, or chat were compromised, how would we coordinate and recover?

**The hardest security questions**
1. What is the cheapest route for an attacker to our most valuable data or money, and do we watch it?
2. What single credential, role, or account, if compromised, ends us?
3. What would we do if we learned today that an attacker has had access for six months?
4. Which of our security controls have never been tested by an actual attempt to bypass them?
5. What do we assume about our users, partners, employees, and tools that an adversary is free to ignore?

---

## Part 43: Security Principles (Extending Parts 8, 17, 28)

45. **Deny by default,** including on errors, timeouts, and unknown states. Permit deliberately.
46. **Authorize at the object, at the action, at the time of use,** not only at the route or the login.
47. **Keep data and instructions in separate channels.** Parameterize, escape by context, and never build code from strings containing external input.
48. **Validate at the boundary, normalize before validating, and use one parser.**
49. **Attach authority to the request, not the actor.** Avoid ambient privilege; carry narrowly scoped, short-lived credentials.
50. **Assume each layer fails.** Put independent controls at the network, application, data, and account levels so one bug is not total.
51. **Least privilege for people, services, pipelines, and automation,** and review it on a schedule, since permissions accumulate.
52. **Every secret has an owner, a scope, an expiry, a rotation procedure that has been exercised, and a leak response.**
53. **Treat exposure as compromise.** Rotate first, clean up after.
54. **Design for revocation.** Anything that can be granted (session, token, link, key, role, invitation, consent) must be revocable, with defined propagation time.
55. **Make abuse expensive and visible:** limits on rate, concurrency, cost, and volume at every unauthenticated or costly path, with alerts on spend and anomalies.
56. **Protect recovery and evidence:** immutable backups in a separate account, logs shipped to a separate store, and out-of-band communication paths.
57. **Model the adversary as patient, automated, and creative,** with access to your client code, your documentation, your dependencies, and your employees' inboxes.
58. **Test security with hostile methods:** differential authorization tests, concurrency tests, fuzzing, exercises, and assume-breach reviews, not only with scanners and checklists.
59. **Minimize data:** what you do not collect or keep cannot leak, be subpoenaed, or need deleting.
60. **Security is an ongoing property, not a launch gate.** Code, dependencies, people, and attackers all change; controls decay without maintenance and testing.

---

## Operational Verification Checklist

For the actionable security, tenant isolation, and cryptographic defense review checklist derived from Volume 4, see:
👉 **[Checklist 04: Security & Adversarial Defense](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/04-security-and-adversarial-checklist.md)**  
👉 **[Master Engineering Checklist Index](file:///home/btpl-lap-22/live/llm-obs-infra/policies/rules/edgeCases/check-list/00-master-engineering-checklist.md)**

