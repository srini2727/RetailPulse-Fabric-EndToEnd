# RetailPulse — Monitoring Metrics (OPS tables)

This document defines the OPS monitoring tables that provide pipeline observability and data health checks inside the Lakehouse. These are used for the “OPS” story in the demo.

---

## 1) Table: ops_run_log

**Purpose**
Tracks start/end status per pipeline stage. Great for demo because it shows orchestration history and failures clearly.

**Storage**
Delta table in Lakehouse.

**Schema**
| Column | Type | Description |
|---|---|---|
| run_id | string | Unique run identifier (UUID). |
| pipeline_name | string | Pipeline name (e.g., `rp_orchestrator_dev`). |
| stage | string | Stage label (e.g., `BRONZE_FULL`, `SILVER_BUILD`, `WAREHOUSE_LOAD`, `OPS_MONITORING`). |
| run_date | string | Pipeline business date (YYYY-MM-DD). |
| run_ts | timestamp | UTC timestamp for this log event. |
| status | string | `STARTED`, `COMPLETED`, `FAILED`. |
| message | string | Short message / error text. |

**How it’s written**
- Write one row at stage start: status = STARTED
- Write one row at stage end: status = COMPLETED or FAILED

---

## 2) Table: ops_table_metrics

**Purpose**
Captures table-level health metrics at run time. Used to quickly validate that tables are populated, keys are unique, and timestamps are moving forward.

**Storage**
Delta table in Lakehouse.

**Schema**
| Column | Type | Description |
|---|---|---|
| run_id | string | Same run_id as ops_run_log. |
| pipeline_name | string | Pipeline name. |
| run_date | string | Pipeline business date. |
| run_ts | timestamp | UTC timestamp for the snapshot. |
| table_name | string | Table being measured (Lakehouse or Warehouse view if exposed). |
| row_count | long | Total number of rows. |
| distinct_key_count | long | Distinct count of the configured key(s). |
| duplicate_key_count | long | row_count - distinct_key_count. |
| null_key_count | long | Count of rows where any key column is null. |
| min_ts | timestamp | Minimum timestamp from the configured timestamp column. |
| max_ts | timestamp | Maximum timestamp from the configured timestamp column. |
| notes | string | Any warnings (e.g., keys missing, table missing). |

---

## 3) Key metrics tracked (what they prove)

### Volume
- `row_count` proves “data arrived and is not empty”

### Uniqueness
- `distinct_key_count` and `duplicate_key_count` prove “no duplication in clean tables”

### Key validity
- `null_key_count` proves “primary keys are present”

### Freshness
- `min_ts` and `max_ts` show the date range and confirms new loads are happening

---

## 4) Recommended monitored tables (current project)

**Silver tables (Lakehouse)**
- `silver_orders_clean` (key: order_id, ts: order_ts or silver_ingest_ts)
- `silver_order_items_clean` (key: order_item_id, ts: silver_ingest_ts)
- `silver_products_clean` or `silver_inventory_clean` (key: product_id, ts: silver_ingest_ts)
- `silver_customers_scd2` (key: customer_id + effective_start_ts)
- `silver_payments_clean` (key: payment_id, ts: payment_ts)
- `silver_returns_clean` (key: return_id, ts: return_ts)



