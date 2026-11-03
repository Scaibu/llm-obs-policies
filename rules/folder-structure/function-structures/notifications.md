Delivering user notifications synchronously inside business transactions ties your primary database commit to external third-party network latencies (SendGrid, Twilio, APNs). [Certain] Notifications must be dispatched asynchronously through dedicated queues, enforce recipient quiet hours, and utilize deterministic idempotency keys to avoid blasting duplicate SMS and emails to customers.

```
Legend
  name(inputs) → output
  ⚠  can fail (outcome shown)
  ▶  team-written
  ⚙  generated or provided by chassis/platform
  ↺  registers cleanup
```

---

## 1. Notification Ingress & Intent Evaluation

```
notify(context, intent) → accepted                                           ▶ + ⚙
├── intent → {recipientId, templateKey, channelPreference, data, idempotencyKey}
├── deduplicate(idempotencyKey) → if already processed: skip cleanly
├── resolveRecipient(recipientId) → contactInfo, locale, timezone
├── checkPreferences(recipientId, notificationCategory) → allowedChannels
│   └── user opted out of channel → DROP silently, record telemetry
├── checkQuietHours(recipient.timezone, intent.urgency)
│   ├── urgency == HIGH (Security Alert / 2FA) → dispatch immediately
│   └── urgency == NORMAL AND inQuietHours → schedule for morning window
├── renderTemplate(templateKey, locale, data) → localizedMessage
└── enqueue(channelQueue, localizedMessage)                                  ⚙
```

---

## 2. Channel Delivery & Provider Failover

```
deliverMessage(channel, message) → deliveryStatus                            ⚙
├── selectProvider(channel) → primaryProvider (e.g. Twilio)
├── sendToProvider(primaryProvider, message)                      ⚠
│   ├── transient network error → retry with exponential jittered backoff
│   ├── permanent error (invalid number / email bounced) → mark address suppressed
│   └── primaryProvider downtime (5xx / circuit open) → failoverToSecondaryProvider()
├── recordStatus(SENT | DELIVERED | BOUNCED | FAILED)                        ⚙
└── trackAnalytics(notification.dispatched, category, channel)               ⚙
```

---

## 3. Strict Notification Invariants

1. **Deterministic Notification Deduplication**: Every outgoing message must derive an idempotency key from its business origin (e.g. `notif:order_shipped:{order_id}:{recipient_id}`). Retrying transactional jobs must never send duplicate notifications.
2. **Asynchronous Outbox Emission**: Notification events must be committed to the transactional outbox table in the same transaction as the domain event, never called directly via HTTP during request processing.
3. **Automated Bounce Suppression**: Any email or SMS address returning a hard permanent bounce (550 / invalid subscriber) must be immediately flagged in the global suppression ledger to protect sender reputation.

