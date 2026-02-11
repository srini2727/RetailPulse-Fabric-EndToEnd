/* =========================================================
   RetailPulse OLTP schema (6 tables)
   - dbo.customers
   - dbo.inventory        (product catalog + stock)
   - dbo.orders
   - dbo.order_items
   - dbo.payments
   - dbo.returns
   Includes:
   - created_ts / modified_ts for incremental loads
   - FKs + helpful indexes
   ========================================================= */

-- Safety: create schema if needed (dbo exists by default)
-- CREATE SCHEMA dbo;
-- GO

/* -----------------------------
   1) CUSTOMERS
------------------------------*/
IF OBJECT_ID('dbo.customers', 'U') IS NOT NULL DROP TABLE dbo.customers;
GO

CREATE TABLE dbo.customers (
    customer_id      INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_key     VARCHAR(50) NULL,          -- optional business key from source system
    first_name       NVARCHAR(100) NULL,
    last_name        NVARCHAR(100) NULL,
    email            NVARCHAR(255) NULL,
    phone            NVARCHAR(50) NULL,

    country          NVARCHAR(100) NULL,
    state            NVARCHAR(100) NULL,
    city             NVARCHAR(100) NULL,
    postal_code      NVARCHAR(20) NULL,

    segment          NVARCHAR(50) NULL,         -- e.g., Retail/Wholesale/VIP
    status           NVARCHAR(20) NOT NULL DEFAULT 'Active',  -- Active/Inactive

    created_ts       DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    modified_ts      DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_customers_modified_ts ON dbo.customers(modified_ts);
GO

/* -----------------------------
   2) INVENTORY  (product catalog + stock)
------------------------------*/
IF OBJECT_ID('dbo.inventory', 'U') IS NOT NULL DROP TABLE dbo.inventory;
GO

CREATE TABLE dbo.inventory (
    product_id       INT NOT NULL PRIMARY KEY,   -- keep stable product_id (not identity) for easy joins
    sku              NVARCHAR(64) NULL,
    product_name     NVARCHAR(255) NOT NULL,
    brand            NVARCHAR(100) NULL,
    category         NVARCHAR(100) NULL,

    unit_price       DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    currency         CHAR(3) NOT NULL DEFAULT 'USD',

    current_qty      INT NOT NULL DEFAULT 0,
    reorder_level    INT NOT NULL DEFAULT 10,     -- threshold for InventoryLow alerts
    status           NVARCHAR(20) NOT NULL DEFAULT 'Active', -- Active/Discontinued

    created_ts       DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    modified_ts      DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_inventory_modified_ts ON dbo.inventory(modified_ts);
CREATE INDEX IX_inventory_qty ON dbo.inventory(current_qty, reorder_level);
GO

/* -----------------------------
   3) ORDERS
------------------------------*/
IF OBJECT_ID('dbo.orders', 'U') IS NOT NULL DROP TABLE dbo.orders;
GO

CREATE TABLE dbo.orders (
    order_id         BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    order_number     NVARCHAR(50) NULL,           -- optional external ref
    customer_id      INT NOT NULL,

    order_ts         DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    order_status     NVARCHAR(30) NOT NULL DEFAULT 'Created', -- Created/Paid/Shipped/Cancelled/Returned

    channel          NVARCHAR(30) NULL,            -- Web/Mobile/Store
    country          NVARCHAR(100) NULL,

    subtotal_amount  DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    tax_amount       DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    shipping_amount  DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    total_amount     DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    currency         CHAR(3) NOT NULL DEFAULT 'USD',

    correlation_id   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(), -- for tracing
    created_ts       DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    modified_ts      DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_orders_customers
        FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id)
);
GO

CREATE INDEX IX_orders_modified_ts ON dbo.orders(modified_ts);
CREATE INDEX IX_orders_customer_ts ON dbo.orders(customer_id, order_ts);
GO

/* -----------------------------
   4) ORDER_ITEMS
------------------------------*/
IF OBJECT_ID('dbo.order_items', 'U') IS NOT NULL DROP TABLE dbo.order_items;
GO

CREATE TABLE dbo.order_items (
    order_item_id    BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    order_id         BIGINT NOT NULL,
    product_id       INT NOT NULL,

    quantity         INT NOT NULL DEFAULT 1,
    unit_price       DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    discount_amount  DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    line_total       DECIMAL(18,2) NOT NULL DEFAULT 0.00,

    created_ts       DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    modified_ts      DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_order_items_orders
        FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),

    CONSTRAINT FK_order_items_inventory
        FOREIGN KEY (product_id) REFERENCES dbo.inventory(product_id)
);
GO

CREATE INDEX IX_order_items_modified_ts ON dbo.order_items(modified_ts);
CREATE INDEX IX_order_items_order ON dbo.order_items(order_id);
CREATE INDEX IX_order_items_product ON dbo.order_items(product_id);
GO

/* -----------------------------
   5) PAYMENTS
------------------------------*/
IF OBJECT_ID('dbo.payments', 'U') IS NOT NULL DROP TABLE dbo.payments;
GO

CREATE TABLE dbo.payments (
    payment_id       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    order_id         BIGINT NOT NULL,

    payment_ts       DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    payment_method   NVARCHAR(30) NULL, -- Card/PayLater/UPI/etc.
    provider         NVARCHAR(50) NULL, -- Stripe/PayPal/etc. optional

    payment_status   NVARCHAR(20) NOT NULL, -- Success/Failed/Pending
    amount           DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    currency         CHAR(3) NOT NULL DEFAULT 'USD',

    failure_reason   NVARCHAR(255) NULL, -- only when Failed

    created_ts       DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    modified_ts      DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_payments_orders
        FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),

    CONSTRAINT CK_payments_status
        CHECK (payment_status IN ('Success','Failed','Pending'))
);
GO

CREATE INDEX IX_payments_modified_ts ON dbo.payments(modified_ts);
CREATE INDEX IX_payments_status_ts ON dbo.payments(payment_status, payment_ts);
CREATE INDEX IX_payments_order ON dbo.payments(order_id);
GO

/* -----------------------------
   6) RETURNS
------------------------------*/
IF OBJECT_ID('dbo.returns', 'U') IS NOT NULL DROP TABLE dbo.returns;
GO

CREATE TABLE dbo.returns (
    return_id        BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    order_id         BIGINT NOT NULL,
    order_item_id    BIGINT NULL, -- optional (return can be full order or item-level)

    return_ts        DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    return_reason    NVARCHAR(100) NULL, -- Damaged/NotNeeded/WrongItem/etc.
    return_status    NVARCHAR(30) NOT NULL DEFAULT 'Requested', -- Requested/Approved/Received/Rejected/Refunded

    refund_amount    DECIMAL(18,2) NULL,
    refund_status    NVARCHAR(30) NULL, -- Initiated/Completed/Failed

    created_ts       DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    modified_ts      DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_returns_orders
        FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id),

    CONSTRAINT FK_returns_order_items
        FOREIGN KEY (order_item_id) REFERENCES dbo.order_items(order_item_id)
);
GO

CREATE INDEX IX_returns_modified_ts ON dbo.returns(modified_ts);
CREATE INDEX IX_returns_status_ts ON dbo.returns(return_status, return_ts);
GO
