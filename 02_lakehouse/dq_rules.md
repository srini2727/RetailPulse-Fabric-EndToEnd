# RetailPulse — Data Quality Rules (DQ) for Silver Layer

This document defines the **Data Quality (DQ) rules** applied when transforming **Bronze → Silver** in the RetailPulse Lakehouse. The goal is to keep Silver tables **clean, reliable, and analytics-ready**, while moving bad records into **quarantine** tables for review.

DQ is implemented in the notebook: **02_build_silver**.

---

## 1) DQ Design (how it works)

RetailPulse follows a simple pattern for each dataset:

1. Read Bronze table
2. Apply type casting + standardization
3. Identify bad rows using clear rules
4. Write:
   - `silver_<table>_clean` (good rows)
   - `silver_<table>_quarantine` (bad rows)
5. Record an issue summary into `silver_dq_issues`


---

## 2) DQ Output Tables

### Clean tables (Lakehouse)
- `silver_customers_scd2`
- `silver_customers_current`
- `silver_products_clean` (inventory/products)
- `silver_orders_clean`
- `silver_order_items_clean`
- `silver_payments_clean`
- `silver_returns_clean`

### Quarantine tables (Lakehouse)
- `silver_products_quarantine`
- `silver_orders_quarantine`
- `silver_order_items_quarantine`
- `silver_payments_quarantine`
- `silver_returns_quarantine`

### DQ issue log
- `silver_dq_issues`

---

## 3) Standard Columns (added in Silver)

Each clean/quarantine dataset includes:
- `silver_ingest_ts` (timestamp when Silver was built)

Bronze metadata carried forward when available:
- `bronze_ingest_ts`
- `bronze_run_id`
- `bronze_source`

---

## 4) DQ Rules by Dataset

### A) Products / Inventory (`bronze_inventory` → `silver_products_clean`)
**Key column:** `product_id`

Rules:
- product_id must not be null
- unit_price must be not null and > 0
- current_qty must be not null and >= 0
- reorder_level must be not null and >= 0

Quarantine examples:
- product_id is null
- unit_price <= 0 or null
- negative inventory quantities

Output:
- Clean: `silver_products_clean`
- Quarantine: `silver_products_quarantine`

---

### B) Orders (`bronze_orders` → `silver_orders_clean`)
**Key column:** `order_id`

Rules:
- order_id must not be null
- customer_id must not be null
- order_ts must be a valid timestamp
- channel must be one of: `Web`, `Mobile`, `Store` (if your data uses this list)
- order_status must not be null (optional rule)
- total_amount should be >= 0 (optional rule)

Quarantine examples:
- missing order_id / customer_id
- invalid order_ts
- unknown channel value

Output:
- Clean: `silver_orders_clean`
- Quarantine: `silver_orders_quarantine`

---

### C) Order Items (`bronze_order_items` → `silver_order_items_clean`)
**Key column:** `order_item_id`  
(If you want a composite key: `order_id + order_item_id`, that is also valid.)

Rules:
- order_item_id must not be null
- order_id must not be null
- product_id must not be null
- quantity must be not null and > 0
- unit_price must be not null and > 0
- line_total should be >= 0 (optional)
- discount_amount should be >= 0 (optional)

Quarantine examples:
- quantity <= 0
- unit_price <= 0
- missing order_id or product_id

Output:
- Clean: `silver_order_items_clean`
- Quarantine: `silver_order_items_quarantine`

---

### D) Payments (`bronze_payments` → `silver_payments_clean`)
**Key column:** `payment_id`

Rules:
- payment_id must not be null
- order_id must not be null
- payment_ts must be a valid timestamp
- amount must be not null and > 0
- payment_status must be one of: `Success`, `Failed`, `Pending` (adjust based on your data)
- payment_method must not be null (optional rule)
- failure_reason must be present when payment_status = Failed (optional, “quality” rule)

Quarantine examples:
- amount <= 0
- missing payment_ts
- missing order_id
- invalid payment_status

Output:
- Clean: `silver_payments_clean`
- Quarantine: `silver_payments_quarantine`

---

### E) Returns (`bronze_returns` → `silver_returns_clean`)
**Key column:** `return_id`

Rules:
- return_id must not be null
- order_id must not be null
- order_item_id must not be null
- return_ts must be a valid timestamp
- refund_amount must be >= 0 (or > 0 if your data requires)
- return_status must not be null (optional rule)

Quarantine examples:
- missing keys (return_id/order_id/order_item_id)
- invalid return_ts
- negative refund_amount

Output:
- Clean: `silver_returns_clean`
- Quarantine: `silver_returns_quarantine`

---

### F) Customers SCD2 (`bronze_customers` → `silver_customers_scd2`)
**Key column:** `customer_id`

Rules:
- customer_id must not be null
- country and segment are standardized:
  - blank/null → `Unknown`
- SCD2 logic:
  - only one row per customer should be current (`is_current = true`)
  - if duplicates exist, it is flagged by OPS monitoring

Outputs:
- `silver_customers_scd2` (historical + current)
- `silver_customers_current` is derived later from SCD2:
  - `WHERE is_current = true`

---

## 5) DQ Issue Logging (`silver_dq_issues`)

A single table stores summaries of detected issues during a run.

Recommended columns:
- run_date
- layer (silver)
- table_name
- rule_name
- issue_count
- sample_json (small sample rows)
- logged_utc_ts

This table supports:
- auditability
- quick troubleshooting
- demo governance story


---

## 6) Acceptance Criteria (what “good” looks like)

A Silver run is considered successful when:
- Clean tables exist and have expected row counts
- Quarantine tables exist and contain only bad rows
- `silver_dq_issues` is generated with clear rule counts
- No critical key columns are missing in clean tables
- OPS monitoring tables show stable row counts and low duplicate/null key counts

---
