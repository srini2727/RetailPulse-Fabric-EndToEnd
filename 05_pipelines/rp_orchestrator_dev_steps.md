# RetailPulse — rp_orchestrator_dev (Orchestration Pipeline Steps)

This document describes the exact flow of the **RetailPulse DEV orchestration pipeline** in Microsoft Fabric Data Factory.

Pipeline name: **rp_orchestrator_dev**  
Goal: **Fabric SQL DB → Lakehouse (Bronze/Silver + OPS) → Warehouse (Gold) → Monitoring**

---

## 0) Prerequisites (items used)

### Source (OLTP)
- Fabric SQL DB: **rp_sqldb_dev**
- Tables (dbo): `customers`, `inventory`, `orders`, `order_items`, `payments`, `returns`

### Lakehouse (Bronze/Silver + OPS)
- Lakehouse: **rp_lakehouse_dev**
- Bronze tables created by load notebook:
  - `bronze_customers`
  - `bronze_inventory`
  - `bronze_orders`
  - `bronze_order_items`
  - `bronze_payments`
  - `bronze_returns`
- Silver tables created by silver notebook:
  - `silver_customers_scd2`
  - `silver_customers_current`
  - `silver_products_clean` (or inventory clean based on your naming)
  - `silver_orders_clean`
  - `silver_order_items_clean`
  - `silver_payments_clean`
  - `silver_returns_clean`
  - `silver_*_quarantine`
  - `silver_dq_issues`
- OPS tables:
  - `ops_watermark`
  - `ops_run_log`
  - `ops_table_metrics`

### Warehouse (Gold star schema)
- Warehouse: **rp_warehouse_dev**
- Tables (dbo):
  - Dims: `dim_customer`, `dim_product`
  - Facts: `fact_sales`, `fact_payments`, `fact_returns`

---

## 1) Pipeline overview (high level)

The pipeline runs in this order:

1. **01_load_bronze_from_sql_db** (Notebook)  
2. **02_build_silver** (Notebook)  
3. **02a_customers_current** (Notebook)  
4. **cp_silver_products_clean_to_dim_product_dev** (Copy job)  
5. **cp_silver_customers_current_to_dim_customer_dev** (Copy job)  
6. **03_fact_sales_staging** (Notebook)  
7. **cp_fact_sales_staging_to_fact_sales_dev** (Copy job)  
8. **03b_fact_returns_staging** (Notebook)  
9. **cp_silver_returns_clean_to_fact_returns** (Copy job)  
10. **03c_fact_payments_staging** (Notebook)  
11. **cp_gold_fact_payments_staging_to_fact_payments** (Copy job)  
12. **04a_ops_monitoring** (Notebook)

This matches your orchestration diagram (notebook + copy jobs chained).

---

## 2) Step-by-step details (what each activity does)

### Step 1 — Notebook: `01_load_bronze_from_sql_db`
**Purpose:** Full load from Fabric SQL DB → Lakehouse Bronze Delta tables  
**Output tables (Lakehouse):**
- `bronze_customers`
- `bronze_inventory`
- `bronze_orders`
- `bronze_order_items`
- `bronze_payments`
- `bronze_returns`

**Notes**
- Uses Microsoft Entra ID token authentication (no passwords)

---

### Step 2 — Notebook: `02_build_silver`
**Purpose:** Clean and standardize Bronze → Silver  
**Outputs (Lakehouse):**
- Silver clean tables:
  - `silver_orders_clean`
  - `silver_order_items_clean`
  - `silver_payments_clean`
  - `silver_returns_clean`
  - `silver_products_clean` (or `silver_inventory_clean`)
  - `silver_customers_scd2`
- Quarantine tables:
  - `silver_orders_quarantine`
  - `silver_order_items_quarantine`
  - `silver_payments_quarantine`
  - `silver_returns_quarantine`
  - `silver_products_quarantine` (or inventory)
- DQ log table:
  - `silver_dq_issues`

**Notes**
- For this demo run, `silver_dq_issues` is overwritten (not append).

---

### Step 3 — Notebook: `02a_customers_current`
**Purpose:** Create a simple “current customer snapshot” from SCD2 for reporting and warehouse load  
**Logic:**
- `silver_customers_current` = rows from `silver_customers_scd2` where `is_current = true`

**Output (Lakehouse):**
- `silver_customers_current`

---

### Step 4 — Copy job: `cp_silver_products_clean_to_dim_product_dev`
**Purpose:** Load Warehouse dim_product  
**Source:** Lakehouse `silver_products_clean`  
**Destination:** Warehouse `dbo.dim_product`

**Mapping note**
- Product attributes come from inventory/products clean table.

---

### Step 5 — Copy job: `cp_silver_customers_current_to_dim_customer_dev`
**Purpose:** Load Warehouse dim_customer  
**Source:** Lakehouse `silver_customers_current`  
**Destination:** Warehouse `dbo.dim_customer`

**Mapping note**
- This keeps warehouse reporting clean and avoids needing SCD2 logic inside the warehouse.

---

### Step 6 — Notebook: `03_fact_sales_staging`
**Purpose:** Build a staging fact table at order-item grain inside Lakehouse  
**Logic:**
- Join `silver_orders_clean` + `silver_order_items_clean`
- Create `date_key` (yyyyMMdd) from order date
- Select columns aligned to warehouse `dbo.fact_sales`

**Output (Lakehouse):**
- `gold_fact_sales_staging`

---

### Step 7 — Copy job: `cp_fact_sales_staging_to_fact_sales_dev`
**Purpose:** Load Warehouse fact_sales  
**Source:** Lakehouse `gold_fact_sales_staging`  
**Destination:** Warehouse `dbo.fact_sales`

---

### Step 8 — Notebook: `03b_fact_returns_staging`
**Purpose:** Prepare returns data aligned to warehouse fact_returns schema  
**Logic:**
- Start from `silver_returns_clean`
- Add:
  - `product_id` (join to order_items to get product_id if needed)
  - `date_key` from return_ts (yyyyMMdd)

**Output (Lakehouse):**
- `gold_fact_returns_staging` (if you created it; if not, you can copy directly with mapping)

---

### Step 9 — Copy job: `cp_silver_returns_clean_to_fact_returns`
**Purpose:** Load Warehouse fact_returns  
**Source:** Lakehouse staging/clean returns table  
**Destination:** Warehouse `dbo.fact_returns`


---

### Step 10 — Notebook: `03c_fact_payments_staging`
**Purpose:** Prepare payments data aligned to warehouse fact_payments schema  
**Logic:**
- Start from `silver_payments_clean`
- Add `date_key` from payment_ts (yyyyMMdd)
- Select columns aligned to warehouse

**Output (Lakehouse):**
- `gold_fact_payments_staging`

---

### Step 11 — Copy job: `cp_gold_fact_payments_staging_to_fact_payments`
**Purpose:** Load Warehouse fact_payments  
**Source:** Lakehouse `gold_fact_payments_staging`  
**Destination:** Warehouse `dbo.fact_payments`

---

### Step 12 — Notebook: `04a_ops_monitoring`
**Purpose:** Record pipeline run + table health metrics for demo governance/observability  
**Writes to (Lakehouse):**
- `ops_run_log` (STARTED / COMPLETED)
- `ops_table_metrics` (row counts, key uniqueness, min/max timestamps)

**Notes**
- This gives you an “OPS” story: “I built monitoring so stakeholders can trust the data.”

---

## 3) Where `00_ops_watermark_init` should go (for incremental pipeline)

For incremental mode, add this at the very start (or run once separately):

### Notebook: `00_ops_watermark_init`
**Purpose:** Create and initialize watermark tracking  
**Creates (Lakehouse):**
- `ops_watermark` with default `1900-01-01`


---


## 5) Success criteria (what you validate after run)

- Lakehouse Bronze: 6 tables loaded with correct row counts
- Lakehouse Silver: clean tables + quarantine + dq_issues created
- Warehouse Gold: dim_* and fact_* tables populated
- Ops tables updated (ops_run_log, ops_table_metrics)
- Power BI semantic model refresh works (Direct Lake)

---
