SET NOCOUNT ON;

------------------------------------------------------------
-- PARAMETERS
------------------------------------------------------------
DECLARE @CustomerCount  INT = 20000;
DECLARE @ProductCount   INT = 5000;
DECLARE @OrderCount     INT = 100000;   -- 100k+
DECLARE @MaxItemsPerOrder INT = 5;

------------------------------------------------------------
-- Tally table
------------------------------------------------------------
IF OBJECT_ID('tempdb..#N') IS NOT NULL DROP TABLE #N;
SELECT TOP (400000)
       ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
INTO #N
FROM sys.all_objects a
CROSS JOIN sys.all_objects b;

------------------------------------------------------------
-- 1) CUSTOMERS
------------------------------------------------------------
PRINT 'Seeding customers...';

INSERT INTO dbo.customers
(
  customer_key, first_name, last_name, email, phone,
  country, state, city, postal_code, segment, status,
  created_ts, modified_ts
)
SELECT TOP (@CustomerCount)
  CONCAT('CUST-', FORMAT(n, '0000000')) AS customer_key,

  CASE (ABS(CHECKSUM(NEWID())) % 8)
    WHEN 0 THEN 'Ava' WHEN 1 THEN 'Mia' WHEN 2 THEN 'Noah' WHEN 3 THEN 'Liam'
    WHEN 4 THEN 'Emma' WHEN 5 THEN 'Olivia' WHEN 6 THEN 'Ethan' ELSE 'Sophia'
  END AS first_name,

  CASE (ABS(CHECKSUM(NEWID())) % 8)
    WHEN 0 THEN 'Patel' WHEN 1 THEN 'Smith' WHEN 2 THEN 'Brown' WHEN 3 THEN 'Garcia'
    WHEN 4 THEN 'Khan' WHEN 5 THEN 'Reddy' WHEN 6 THEN 'Chen' ELSE 'Singh'
  END AS last_name,

  CONCAT('user', n, '@retailpulse.demo') AS email,
  CONCAT('+1-', RIGHT('0000000000' + CAST(ABS(CHECKSUM(NEWID())) % 10000000000 AS varchar(20)), 10)) AS phone,

  CASE (ABS(CHECKSUM(NEWID())) % 6)
    WHEN 0 THEN 'US' WHEN 1 THEN 'UK' WHEN 2 THEN 'CA' WHEN 3 THEN 'IN' WHEN 4 THEN 'AU' ELSE 'Unknown'
  END AS country,

  CASE (ABS(CHECKSUM(NEWID())) % 6)
    WHEN 0 THEN 'CA' WHEN 1 THEN 'TX' WHEN 2 THEN 'NY' WHEN 3 THEN 'TN' WHEN 4 THEN 'WA' ELSE 'NA'
  END AS state,

  CASE (ABS(CHECKSUM(NEWID())) % 6)
    WHEN 0 THEN 'LA' WHEN 1 THEN 'Dallas' WHEN 2 THEN 'NYC' WHEN 3 THEN 'Memphis' WHEN 4 THEN 'Seattle' ELSE 'London'
  END AS city,

  RIGHT('00000' + CAST(ABS(CHECKSUM(NEWID())) % 99999 AS varchar(10)), 5) AS postal_code,

  CASE (ABS(CHECKSUM(NEWID())) % 4)
    WHEN 0 THEN 'Consumer' WHEN 1 THEN 'SMB' WHEN 2 THEN 'Enterprise' ELSE 'VIP'
  END AS segment,

  'Active' AS status,
  DATEADD(day, -(ABS(CHECKSUM(NEWID())) % 365), SYSUTCDATETIME()) AS created_ts,
  SYSUTCDATETIME() AS modified_ts
FROM #N;

------------------------------------------------------------
-- Customer map
------------------------------------------------------------
IF OBJECT_ID('tempdb..#CustMap') IS NOT NULL DROP TABLE #CustMap;
SELECT ROW_NUMBER() OVER (ORDER BY customer_id) AS rn, customer_id, country
INTO #CustMap
FROM dbo.customers;

DECLARE @CustActual INT = (SELECT COUNT(*) FROM #CustMap);

------------------------------------------------------------
-- 2) INVENTORY (product_id in your table is PK int NOT NULL)
-- We'll always provide product_id safely.
------------------------------------------------------------
PRINT 'Seeding inventory...';

;WITH ProdBase AS
(
  SELECT TOP (@ProductCount)
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS pid,
    n
  FROM #N
)
INSERT INTO dbo.inventory
(
  product_id, sku, product_name, brand, category,
  unit_price, currency,
  current_qty, reorder_level,
  status, created_ts, modified_ts
)
SELECT
  pb.pid AS product_id,
  CONCAT('SKU-', FORMAT(pb.pid, '0000000')) AS sku,
  CONCAT('Product ', pb.pid) AS product_name,

  CASE (ABS(CHECKSUM(NEWID())) % 6)
    WHEN 0 THEN 'Contoso' WHEN 1 THEN 'Fabrikam' WHEN 2 THEN 'Northwind'
    WHEN 3 THEN 'Adventure' WHEN 4 THEN 'Tailspin' ELSE 'WideWorld'
  END AS brand,

  CASE (ABS(CHECKSUM(NEWID())) % 6)
    WHEN 0 THEN 'Electronics' WHEN 1 THEN 'Apparel' WHEN 2 THEN 'Home'
    WHEN 3 THEN 'Beauty' WHEN 4 THEN 'Sports' ELSE 'Grocery'
  END AS category,

  CAST((5 + (ABS(CHECKSUM(NEWID())) % 500)) + ((ABS(CHECKSUM(NEWID())) % 99) / 100.0) AS decimal(18,2)) AS unit_price,
  'USD' AS currency,
  50 + (ABS(CHECKSUM(NEWID())) % 500) AS current_qty,
  10 + (ABS(CHECKSUM(NEWID())) % 50) AS reorder_level,
  'Active' AS status,
  DATEADD(day, -(ABS(CHECKSUM(NEWID())) % 365), SYSUTCDATETIME()) AS created_ts,
  SYSUTCDATETIME() AS modified_ts
FROM ProdBase pb;

------------------------------------------------------------
-- Product map
------------------------------------------------------------
IF OBJECT_ID('tempdb..#ProdMap') IS NOT NULL DROP TABLE #ProdMap;
SELECT ROW_NUMBER() OVER (ORDER BY product_id) AS rn, product_id, unit_price
INTO #ProdMap
FROM dbo.inventory;

DECLARE @ProdActual INT = (SELECT COUNT(*) FROM #ProdMap);

------------------------------------------------------------
-- 3) ORDERS (fixed: order_status never NULL)
------------------------------------------------------------
PRINT 'Seeding orders...';

IF OBJECT_ID('tempdb..#OrdersOut') IS NOT NULL DROP TABLE #OrdersOut;
CREATE TABLE #OrdersOut
(
  order_number nvarchar(50) NOT NULL,
  order_id BIGINT NOT NULL,
  customer_id INT NOT NULL,
  order_ts datetime2(3) NOT NULL,
  country nvarchar(100) NULL,
  channel nvarchar(30) NULL,
  currency char(3) NOT NULL
);

WITH OrderBase AS
(
  SELECT TOP (@OrderCount)
    n.n AS seq,
    cm.customer_id,
    cm.country,
    DATEADD(second, ABS(CHECKSUM(NEWID())) % 86400,
      DATEADD(day, -(ABS(CHECKSUM(NEWID())) % 365), CAST(SYSUTCDATETIME() AS datetime2(3)))
    ) AS order_ts,
    (ABS(CHECKSUM(NEWID())) % 4) AS status_bucket,
    (ABS(CHECKSUM(NEWID())) % 3) AS channel_bucket
  FROM #N n
  JOIN #CustMap cm
    ON cm.rn = ((n.n - 1) % @CustActual) + 1
)
INSERT INTO dbo.orders
(
  order_number, customer_id, order_ts, order_status,
  channel, country,
  subtotal_amount, tax_amount, shipping_amount, total_amount,
  currency, correlation_id,
  created_ts, modified_ts
)
OUTPUT
  inserted.order_number,
  inserted.order_id,
  inserted.customer_id,
  inserted.order_ts,
  inserted.country,
  inserted.channel,
  inserted.currency
INTO #OrdersOut (order_number, order_id, customer_id, order_ts, country, channel, currency)
SELECT
  CONCAT('ORD-', FORMAT(ob.seq, '000000000')) AS order_number,
  ob.customer_id,
  ob.order_ts,

  CASE ob.status_bucket
    WHEN 0 THEN 'Completed'
    WHEN 1 THEN 'Shipped'
    WHEN 2 THEN 'Pending'
    ELSE 'Cancelled'
  END AS order_status,

  CASE ob.channel_bucket
    WHEN 0 THEN 'Web'
    WHEN 1 THEN 'Mobile'
    ELSE 'Store'
  END AS channel,

  ob.country,
  CAST(0.00 AS decimal(18,2)),
  CAST(0.00 AS decimal(18,2)),
  CAST(0.00 AS decimal(18,2)),
  CAST(0.00 AS decimal(18,2)),

  CASE ob.country
    WHEN 'UK' THEN 'GBP' WHEN 'IN' THEN 'INR' WHEN 'AU' THEN 'AUD' WHEN 'CA' THEN 'CAD' ELSE 'USD'
  END AS currency,

  NEWID() AS correlation_id,
  ob.order_ts AS created_ts,
  SYSUTCDATETIME() AS modified_ts
FROM OrderBase ob;

------------------------------------------------------------
-- 4) ORDER_ITEMS
------------------------------------------------------------
PRINT 'Seeding order_items...';

WITH ItemNums AS
(
  SELECT TOP (@MaxItemsPerOrder) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
  FROM sys.all_objects
),
OrderWithItemCount AS
(
  SELECT
    o.order_id,
    o.order_ts,
    1 + (ABS(CHECKSUM(NEWID())) % @MaxItemsPerOrder) AS item_cnt
  FROM #OrdersOut o
),
OrderItemsGen AS
(
  SELECT
    ow.order_id,
    ow.order_ts,
    i.n AS item_pos
  FROM OrderWithItemCount ow
  JOIN ItemNums i ON i.n <= ow.item_cnt
)
INSERT INTO dbo.order_items
(
  order_id, product_id,
  quantity, unit_price, discount_amount, line_total,
  created_ts, modified_ts
)
SELECT
  g.order_id,
  pm.product_id,
  1 + (ABS(CHECKSUM(NEWID())) % 4) AS quantity,
  CAST(pm.unit_price AS decimal(18,2)) AS unit_price,
  CAST(pm.unit_price * (ABS(CHECKSUM(NEWID())) % 15) / 100.0 AS decimal(18,2)) AS discount_amount,
  CAST(
    (pm.unit_price * (1 + (ABS(CHECKSUM(NEWID())) % 4))) -
    (pm.unit_price * (ABS(CHECKSUM(NEWID())) % 15) / 100.0)
    AS decimal(18,2)
  ) AS line_total,
  g.order_ts AS created_ts,
  SYSUTCDATETIME() AS modified_ts
FROM OrderItemsGen g
JOIN #ProdMap pm
  ON pm.rn = ((ABS(CHECKSUM(NEWID())) % @ProdActual) + 1);

------------------------------------------------------------
-- 5) Update order totals
------------------------------------------------------------
PRINT 'Updating order totals...';

;WITH agg AS
(
  SELECT order_id, CAST(SUM(line_total) AS decimal(18,2)) AS subtotal
  FROM dbo.order_items
  GROUP BY order_id
)
UPDATE o
SET
  o.subtotal_amount = a.subtotal,
  o.tax_amount = CAST(a.subtotal * 0.08 AS decimal(18,2)),
  o.shipping_amount = CAST(CASE WHEN o.channel = 'Store' THEN 0 ELSE 5 + (ABS(CHECKSUM(NEWID())) % 10) END AS decimal(18,2)),
  o.total_amount = CAST(a.subtotal + (a.subtotal * 0.08) + (CASE WHEN o.channel = 'Store' THEN 0 ELSE 5 + (ABS(CHECKSUM(NEWID())) % 10) END) AS decimal(18,2)),
  o.modified_ts = SYSUTCDATETIME()
FROM dbo.orders o
JOIN agg a ON a.order_id = o.order_id;

------------------------------------------------------------
-- 6) PAYMENTS (1 per order)
------------------------------------------------------------
PRINT 'Seeding payments...';

INSERT INTO dbo.payments
(
  order_id, payment_ts,
  payment_method, provider, payment_status,
  amount, currency, failure_reason,
  created_ts, modified_ts
)
SELECT
  o.order_id,
  DATEADD(minute, 1 + (ABS(CHECKSUM(NEWID())) % 30), o.order_ts) AS payment_ts,

  CASE (ABS(CHECKSUM(NEWID())) % 3)
    WHEN 0 THEN 'Card' WHEN 1 THEN 'PayLater' ELSE 'Wallet'
  END AS payment_method,

  CASE (ABS(CHECKSUM(NEWID())) % 4)
    WHEN 0 THEN 'Visa' WHEN 1 THEN 'Mastercard' WHEN 2 THEN 'Amex' ELSE 'PayPal'
  END AS provider,

  CASE WHEN (ABS(CHECKSUM(NEWID())) % 100) < 4 THEN 'Failed' ELSE 'Success' END AS payment_status,

  CAST(o.total_amount AS decimal(18,2)) AS amount,
  o.currency,

  CASE WHEN (ABS(CHECKSUM(NEWID())) % 100) < 4
       THEN CASE (ABS(CHECKSUM(NEWID())) % 3)
              WHEN 0 THEN 'InsufficientFunds' WHEN 1 THEN 'Timeout' ELSE 'FraudSuspected'
            END
       ELSE NULL
  END AS failure_reason,

  o.created_ts AS created_ts,
  SYSUTCDATETIME() AS modified_ts
FROM dbo.orders o;

------------------------------------------------------------
-- 7) RETURNS (~3% of items)
------------------------------------------------------------
PRINT 'Seeding returns...';

INSERT INTO dbo.returns
(
  order_id, order_item_id,
  return_ts, return_reason, return_status,
  refund_amount, refund_status,
  created_ts, modified_ts
)
SELECT
  oi.order_id,
  oi.order_item_id,
  DATEADD(day, 1 + (ABS(CHECKSUM(NEWID())) % 30), oi.created_ts) AS return_ts,

  CASE (ABS(CHECKSUM(NEWID())) % 5)
    WHEN 0 THEN 'Damaged' WHEN 1 THEN 'WrongItem' WHEN 2 THEN 'LateDelivery'
    WHEN 3 THEN 'NotAsDescribed' ELSE 'ChangedMind'
  END AS return_reason,

  CASE (ABS(CHECKSUM(NEWID())) % 3)
    WHEN 0 THEN 'Requested' WHEN 1 THEN 'Approved' ELSE 'Completed'
  END AS return_status,

  CAST(oi.line_total AS decimal(18,2)) AS refund_amount,

  CASE (ABS(CHECKSUM(NEWID())) % 3)
    WHEN 0 THEN 'Pending' WHEN 1 THEN 'Completed' ELSE 'Rejected'
  END AS refund_status,

  SYSUTCDATETIME() AS created_ts,
  SYSUTCDATETIME() AS modified_ts
FROM dbo.order_items oi
WHERE (ABS(CHECKSUM(NEWID())) % 100) < 3;

------------------------------------------------------------
-- 8) Inventory decrement (optional realism)
------------------------------------------------------------
PRINT 'Updating inventory quantities...';

;WITH sold AS
(
  SELECT product_id, SUM(quantity) AS sold_qty
  FROM dbo.order_items
  GROUP BY product_id
)
UPDATE i
SET i.current_qty = CASE WHEN i.current_qty - s.sold_qty < 0 THEN 0 ELSE i.current_qty - s.sold_qty END,
    i.modified_ts = SYSUTCDATETIME()
FROM dbo.inventory i
JOIN sold s ON s.product_id = i.product_id;

------------------------------------------------------------
-- DONE
------------------------------------------------------------
PRINT 'Seed complete. Row counts:';

SELECT 
  (SELECT COUNT(*) FROM dbo.customers)   AS customers,
  (SELECT COUNT(*) FROM dbo.inventory)   AS inventory,
  (SELECT COUNT(*) FROM dbo.orders)      AS orders,
  (SELECT COUNT(*) FROM dbo.order_items) AS order_items,
  (SELECT COUNT(*) FROM dbo.payments)    AS payments,
  (SELECT COUNT(*) FROM dbo.returns)     AS returns;
