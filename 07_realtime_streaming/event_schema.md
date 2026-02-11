# RetailPulse Event Schema (rp_event_schema_v1)

This project has 2 data paths:

1) Batch / near real-time analytics (SQL DB → Lakehouse → Warehouse → Power BI)
2) Real-time ops monitoring (App/Event Hub → Eventstream → Eventhouse/KQL → Real-Time Dashboard + Activator)

This document defines the **real-time event payload** used by Eventstream/Eventhouse.

---

## Event envelope (simple JSON)
To keep things stable and avoid schema registry/CloudEvents issues, we use a **simple JSON event** with these common fields:

- event_time (datetime)
- event_type (string)
- correlation_id (guid)

All other fields depend on event_type.

---

## Event Types

### 1) OrderCreated
Used for order volume, revenue, channel and country monitoring.

**Fields**
- event_time
- event_type = "OrderCreated"
- order_id (long)
- channel (string: Web/Mobile/Store)
- amount (decimal/real)
- country (string)
- correlation_id (guid)

**Example**
```json
{
  "event_time": "2026-01-10T00:02:58.174Z",
  "event_type": "OrderCreated",
  "order_id": 437577,
  "channel": "Store",
  "amount": 22.83,
  "country": "AU",
  "correlation_id": "32315a39-7245-4a3d-bd6a-f77c963d876f"
}

### 2) PaymentFailed
Used to monitor payment failures and trigger alerts.

**Fields**
- event_time
- event_type = "PaymentFailed"
- order_id (long)
- payment_type (string: Card/PayLater/Wallet)
- amount (decimal/real)
- country (string)
- reason (string)
- correlation_id (guid)

**Example**
{
  "event_time": "2026-01-10T00:03:11.532Z",
  "event_type": "PaymentFailed",
  "order_id": 230056,
  "payment_type": "Card",
  "amount": 160.42,
  "country": "UK",
  "reason": "Timeout",
  "correlation_id": "9e662fb6-93bb-4345-b8e7-8d74b77da313"
}

### 3) InventoryLow
Used for inventory risk alerts.

**Fields**
- event_time
- event_type = "InventoryLow"
- product_id (int/long)
- inventory_level (int)
- threshold (int)
- channel (optional string)
- country (optional string)
- correlation_id (guid)

**Example**
{
  "event_time": "2026-01-10T00:04:05.101Z",
  "event_type": "InventoryLow",
  "product_id": 688,
  "inventory_level": 7,
  "threshold": 20,
  "reason": "OutOfStockRisk",
  "correlation_id": "4826e11e-3862-45d1-8a7a-4fbecb5b0c51"
}
