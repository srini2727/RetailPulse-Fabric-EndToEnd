
---

## 5) `activator_rules.md` (copy/paste)

```md
# Activator Rules (3 alerts)

Goal:
Add simple but strong alerts that show operational maturity.

Rule engine:
Activator listens to streaming events coming from Eventstream.

---

## Rule 1 — Payment failure spike (last 15 min)
**Why**
A spike in payment failures usually means a payment provider outage, fraud spike, or bad deployment.

**Trigger logic**
- event_type = "PaymentFailed"
- count over last 15 minutes >= 25 (adjust to your data volume)

**Action**
- Send Email (or Teams)
Subject: RetailPulse Alert — Payment failures spike
Body: Include count and sample reason values.

---

## Rule 2 — Inventory low (threshold breach)
**Why**
Prevent stockouts and lost revenue.

**Trigger logic**
- event_type = "InventoryLow"
- inventory_level <= threshold
- fire on every matching event (or only once per product per X minutes)

**Action**
- Send Email (or Teams)
Include product_id, inventory_level, threshold.

---

## Rule 3 — Order spike (possible marketing surge or fraud)
**Why**
Order spikes can mean a promo event (good) or bot/fraud (bad). Either way ops should know.

**Trigger logic**
- event_type = "OrderCreated"
- orders in last 5 minutes >= 500 (tune based on your volume)

**Action**
- Send Email (or Teams)
Include current count, top channel, top country.

---

## Implementation notes
- If you don't see “query editor”, that’s okay — Activator works mainly as:
  Event selection → filters → condition thresholds → action.
- Start simple with Email. Later you can connect Power Automate for richer workflows.
