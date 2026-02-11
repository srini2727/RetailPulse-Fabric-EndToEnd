
---------------------------------------------------------------
-- FABRIC SQL DB (rp_sqldb_dev)
-- Truncate source OLTP tables (child -> parent order)
---------------------------------------------------------------

/*
  Run this section in rp_sqldb_dev (Fabric SQL Database).
  Truncate in dependency order:
    order_items / returns / payments -> orders -> inventory -> customers
*/

-- Drop constraints if your schema has FK constraints (only if TRUNCATE fails).
-- (Fabric SQL DB may or may not have FK constraints depending on how you created tables)
-- If truncate fails, use DELETE instead (provided below).

/* TRUNCATE OLTP (preferred) */
IF OBJECT_ID('dbo.returns', 'U') IS NOT NULL TRUNCATE TABLE dbo.returns;
IF OBJECT_ID('dbo.order_items', 'U') IS NOT NULL TRUNCATE TABLE dbo.order_items;
IF OBJECT_ID('dbo.payments', 'U') IS NOT NULL TRUNCATE TABLE dbo.payments;
IF OBJECT_ID('dbo.orders', 'U') IS NOT NULL TRUNCATE TABLE dbo.orders;
IF OBJECT_ID('dbo.inventory', 'U') IS NOT NULL TRUNCATE TABLE dbo.inventory;
IF OBJECT_ID('dbo.customers', 'U') IS NOT NULL TRUNCATE TABLE dbo.customers;

PRINT '✅ SQL DB cleanup complete (OLTP tables truncated).';

-- If TRUNCATE fails due to constraints, use DELETE (slower but works):
-- DELETE FROM dbo.returns;
-- DELETE FROM dbo.order_items;
-- DELETE FROM dbo.payments;
-- DELETE FROM dbo.orders;
-- DELETE FROM dbo.inventory;
-- DELETE FROM dbo.customers;


---------------------------------------------------------------
-- SECTION C: LAKEHOUSE (Spark SQ
