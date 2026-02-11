# RetailPulse — Data Quality Log Schema (Lakehouse)

This document defines the schema and rules used to log data quality issues during Bronze → Silver processing in the Lakehouse. The goal is to keep DQ tracking simple, demo-ready, and easy to explain.

---

## 1) Table: silver_dq_issues

**Purpose**
Stores one row per (run_date, layer, table, rule) with counts and a small JSON sample of bad rows. This makes it easy to show DQ trends and drill into examples.

**Storage**
Delta table in Lakehouse.

**Write pattern**
For now (demo), we overwrite each run. In production, this can be append.

**Schema**
| Column | Type | Description |
|---|---|---|
| run_date | string | Pipeline business date (YYYY-MM-DD). |
| layer | string | Data layer name (e.g., `silver`). |
| table_name | string | Target table name where rule was applied (e.g., `silver_orders_clean`). |
| rule_name | string | Human-readable rule identifier (e.g., `invalid_orders`). |
| issue_count | int | Count of records that violated the rule. |
| sample_json | string | JSON array of a few sample bad records (5 rows max). |
| logged_utc_ts | timestamp | UTC timestamp when the log entry was created. |

**Example row**
- run_date: `2026-01-14`
- layer: `silver`
- table_name: `silver_payments_clean`
- rule_name: `invalid_payment_status`
- issue_count: `84`
- sample_json: `[{...},{...}]`

---

## 2) Standard DQ Rules (Demo set)

These are the DQ rules applied when building Silver “clean” tables. Any rows failing rules go into the matching `*_quarantine` table.

### A) Inventory / Products (`silver_inventory_clean` or `silver_products_clean`)
- `product_id` must not be null
- `unit_price` must be > 0
- `current_qty` must be >= 0
- optional: `status` must be one of (Active, Inactive, Discontinued) if you have those values

### B) Orders (`silver_orders_clean`)
- `order_id` not null
- `customer_id` not null
- `order_ts` not null
- `channel` must be one of (Web, Mobile, Store)
- `total_amount` >= 0 (or `subtotal_amount` >= 0)

### C) Order Items (`silver_order_items_clean`)
- `order_item_id` not null
- `order_id` not null
- `product_id` not null
- `quantity` > 0
- `unit_price` > 0
- `line_total` > 0 (or recompute if needed)

### D) Payments (`silver_payments_clean`)
- `payment_id` not null
- `order_id` not null
- `payment_ts` not null
- `amount` > 0
- `payment_status` must be one of (Success, Failed, Pending)
- optional: `payment_method` must be one of (Card, Wallet, PayLater)

### E) Returns (`silver_returns_clean`)
- `return_id` not null
- `order_id` not null
- `order_item_id` not null
- `return_ts` not null
- `refund_amount` >= 0
- `return_status` must be one of (Requested, Approved, Rejected, Completed)

---

## 3) Quarantine tables

For each major Silver table, we keep a quarantine table containing rejected rows:

- `silver_orders_quarantine`
- `silver_order_items_quarantine`
- `silver_products_quarantine` (or `silver_inventory_quarantine`)
- `silver_payments_quarantine`
- `silver_returns_quarantine`

**Why**
- We don’t drop bad data. We isolate it for remediation.

---

## 4) Reporting / Demo angles

- Show `silver_dq_issues` filtered by run_date to prove DQ monitoring exists.
- Show counts by table_name to highlight where issues happen.
- Show sample_json for 1 rule to demonstrate debugging.

---

## 5) Future enhancement (optional)
- Append logs daily instead of overwrite.
- Add rule severity (Low/Medium/High).
- Add `pipeline_run_id` to link DQ logs to orchestration runs.
