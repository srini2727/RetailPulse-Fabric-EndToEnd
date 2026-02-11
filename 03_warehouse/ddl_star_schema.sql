/* =========================================================
   RETAILPULSE – GOLD WAREHOUSE RESET & CREATE
   Target : rp_warehouse_dev
   Purpose: Clean rebuild aligned with FINAL Silver schema
   ========================================================= */

------------------------------------------------------------
------------------------------------------------------------
------------------------------------------------------------
-- DIMENSION: DATE
------------------------------------------------------------
CREATE TABLE dbo.dim_date (
    date_key        INT          NOT NULL,   -- yyyymmdd
    full_date       DATE         NOT NULL,
    [year]          INT          NOT NULL,
    [quarter]       INT          NOT NULL,
    [month]         INT          NOT NULL,
    month_name      VARCHAR(20)  NOT NULL,
    day_of_month    INT          NOT NULL,
    day_name        VARCHAR(20)  NOT NULL,
    week_of_year    INT          NOT NULL
);

------------------------------------------------------------
-- DIMENSION: CUSTOMER (SCD2)
------------------------------------------------------------
CREATE TABLE dbo.dim_customer (
    customer_id         INT           NOT NULL,
    country             VARCHAR(50)    NULL,
    segment             VARCHAR(50)    NULL,
    effective_start_ts  DATETIME2(6)   NULL,
    effective_end_ts    DATETIME2(6)   NULL,
    is_current          BIT            NULL
);

------------------------------------------------------------
-- DIMENSION: PRODUCT (FROM SILVER INVENTORY)
------------------------------------------------------------
CREATE TABLE dbo.dim_product (
    product_id      INT           NOT NULL,
    sku             VARCHAR(50)    NULL,
    product_name    VARCHAR(100)   NULL,
    brand           VARCHAR(80)    NULL,
    category        VARCHAR(50)    NULL,
    unit_price      FLOAT          NULL,
    current_qty     INT            NULL,
    reorder_level   INT            NULL,
    status          VARCHAR(30)    NULL
);

------------------------------------------------------------
-- FACT: SALES (GRAIN = ORDER ITEM)
------------------------------------------------------------
CREATE TABLE dbo.fact_sales (
    order_id        INT           NOT NULL,
    order_item_id   INT           NOT NULL,
    customer_id     INT           NOT NULL,
    product_id      INT           NOT NULL,
    date_key        INT           NOT NULL,
    quantity        INT           NULL,
    unit_price      FLOAT         NULL,
    sales_amount    FLOAT         NULL,
    channel         VARCHAR(20)   NULL
);

------------------------------------------------------------
-- FACT: PAYMENTS
------------------------------------------------------------
CREATE TABLE dbo.fact_payments (
    payment_id      INT           NOT NULL,
    order_id        INT           NOT NULL,
    date_key        INT           NOT NULL,
    amount          FLOAT         NULL,
    payment_method  VARCHAR(30)   NULL,
    payment_status  VARCHAR(30)   NULL
);

------------------------------------------------------------
-- FACT: RETURNS
------------------------------------------------------------
CREATE TABLE dbo.fact_returns (
    return_id       INT           NOT NULL,
    order_id        INT           NOT NULL,
    order_item_id   INT           NOT NULL,
    product_id      INT           NOT NULL,
    date_key        INT           NOT NULL,
    refund_amount   FLOAT         NULL,
    return_reason   VARCHAR(100)  NULL,
    return_status   VARCHAR(30)   NULL
);

------------------------------------------------------------
-- END
------------------------------------------------------------
