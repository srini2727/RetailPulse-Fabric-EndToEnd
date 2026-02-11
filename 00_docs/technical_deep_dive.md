# Technical Deep Dive: RetailPulse Fabric Solution

## Executive Summary
This document provides a comprehensive technical overview of the RetailPulse end-to-end data solution built on Microsoft Fabric, covering architecture, data flows, transformation logic, and implementation details.

## Architecture Overview

### Medallion Architecture (Bronze → Silver → Gold)

#### **Bronze Layer: Raw Data Ingestion**
- **Source:** Microsoft SQL Database
- **Tables:** Raw copies of operational tables (Products, Customers, Orders, Payments, Returns)
- **Approach:** Full and incremental load patterns using watermark-based change tracking
- **Notebook:** `00_ops_watermark_init.ipynb`, `01_load_bronze_from_sql_db.ipynb`

#### **Silver Layer: Cleaned & Deduplicated**
- **Purpose:** Apply business logic, handle duplicates, enforce data quality
- **Key Transformations:**
  - Data type conversions and cleaning
  - Duplicate record removal
  - Null value handling
  - Historical tracking for slowly changing dimensions
- **Notebook:** `02_build_silver.ipynb`, `02a_customers_current.ipynb`

#### **Gold Layer: Business-Ready Analytics**
- **Purpose:** Fact tables and dimensions optimized for analytics
- **Components:**
  - Fact tables: `fact_sales`, `fact_returns`, `fact_payments`
  - Dimension tables: `dim_customer`, `dim_product`, `dim_date`
  - Aggregated views for reporting
- **Notebooks:** `03_fact_sales_staging.ipynb`, `03b_fact_returns_staging.ipynb`, `03c_fact_payments_staging.ipynb`

## Data Flow Pipelines

### Notebook-Based ETL
```
SQL DB → Bronze Layer (Lakehouse)
    ↓
Cleansing & Deduplication (Silver)
    ↓
Dimensional Modeling (Gold)
    ↓
Warehouse Star Schema
```

### Components

#### **Operational Monitoring** (`04a_ops_monitoring.ipynb`)
- Tracks pipeline execution metrics
- Logs data quality violations
- Monitors row counts and processing times
- Maintains operational state and watermarks

#### **Data Quality Framework**
- Rule definitions: [dq_rules.md](../02_lakehouse/dq_rules.md)
- Quality metrics logging to designated schema
- Automated quality checks during transformations
- Exception handling and alerting

## Semantic Model & Analytics

### Star Schema Design

**Fact Tables:**
- `fact_sales`: Transaction-level sales data
  - Keys: customer_id, product_id, date_id
  - Measures: amount, quantity, discount
  
- `fact_returns`: Return transaction details
  - Keys: customer_id, product_id, date_id
  - Measures: return_amount, return_quantity, reason

- `fact_payments`: Payment processing data
  - Keys: customer_id, date_id
  - Measures: payment_amount, transaction_fee

**Dimension Tables:**
- `dim_customer`: Customer attributes with RLS capability
- `dim_product`: Product hierarchy and categories
- `dim_date`: Time dimension with fiscal calendars

### DAX Measures
Key measures for business analytics:
- Total Sales Revenue
- Return Rate & Amount
- Customer Lifetime Value
- Product Performance Metrics
- Period-over-Period Growth

Reference: [measures_dax.md](../04_powerbi_&_semantic_model/mesures_dax.md)

## Real-Time Streaming Architecture

### Event-Driven Components
- **Event Source:** Real-time transaction events
- **Eventhouse:** Microsoft Fabric's real-time data warehouse
- **KQL Queries:** Complex event aggregation and filtering

### Real-Time Dashboard
- Live sales metrics dashboard
- Real-time customer activity stream
- Automated activator rules for business alerts
- Event processing rules: [activator_rules.md](../07_realtime_streaming/activator_rules.md)

## Security & Governance

### Row-Level Security (RLS)
- Role-based access control for sensitive regions/departments
- Dynamic RLS expressions in semantic model
- Plan: [rls_plan.md](../06_ops_governance/rls_plan.md)

### Data Quality Governance
- Schema: [data_quality_log_schema.md](../06_ops_governance/data_quality_log_schema.md)
- Metrics tracking: [monitoring_metrics.md](../06_ops_governance/monitoring_metrics.md)
- Automated quality checks in medallion layers

## Implementation Details

### Key Technologies
- **Microsoft Fabric:** Lakehouse, Warehouse, Semantic Model, Real-time Analytics
- **Languages:** Python (PySpark), SQL, DAX, KQL (Kusto Query Language)
- **Version Control:** Git-based source control
- **CI/CD:** Automated pipeline deployment

### Performance Optimization
- Partitioning strategy for large fact tables
- Aggregation tables for common queries
- Index optimization on warehouse tables
- Incremental refresh patterns

### Development Workflow
See [rp_orchestrator_dev_steps.md](../05_pipelines/rp_orchestrator_dev_steps.md) for deployment orchestration details.

## Database Schema

### SQL Database Setup
- DDL Scripts: [ddl_create_tables.sql](../01_sqldb/ddl_create_tables.sql)
- Seed Data: [seed_v2_100k.sql](../01_sqldb/seed_v2_100k.sql)
- Cleanup Scripts: [cleanup_truncate.sql](../01_sqldb/cleanup_truncate.sql)

### Warehouse Schema
- Star schema DDL: [ddl_star_schema.sql](../03_warehouse/ddl_star_schema.sql)
- Analytical views for reporting: [view_sales_daily.sql](../03_warehouse/view_sales_daily.sql), etc.
- Date dimension setup: [date_table.sql](../03_warehouse/date_table.sql)

## Configuration & Deployment

### Configuration Management
- Template: [config.template.json](../config.template.json)
- Environment-specific overrides for dev/test/prod
- Connection strings and secret management

### Deployment Steps
1. Configure source SQL database connection
2. Initialize lakehouse and warehouse
3. Deploy notebooks with proper parameterization
4. Set up semantic model and RLS roles
5. Configure real-time streaming components
6. Deploy Power BI reports

## Testing & Quality Assurance

### Data Validation
- Row count comparisons between layers
- Aggregate validation (sum checks, distinct counts)
- Referential integrity checks
- Data freshness monitoring

### Performance Testing
- Pipeline execution time baselines
- Memory and compute utilization analysis
- Query performance in semantic model
- Real-time ingest rate validation

## Support & Maintenance

### Monitoring & Alerting
- Operational metrics dashboard
- Data quality exception reports
- Pipeline failure notifications
- Real-time anomaly detection

### Troubleshooting Guide
Key areas to check:
- Watermark status and incremental load failures
- Data quality rule violations
- Semantic model refresh issues
- Real-time event stream lag
- RLS permission configuration

## References
- [Demo Walkthrough](./demo_walkthrough.md)
- [Project README](../README.md)
- Complete documentation structure in 00_docs/
