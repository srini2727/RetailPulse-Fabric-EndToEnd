CREATE VIEW dbo.v_customer_performance AS
SELECT
    c.customer_id,
    c.country,
    c.segment,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.sales_amount)        AS total_sales,
    SUM(f.quantity)            AS total_units
FROM dbo.fact_sales f
JOIN dbo.dim_customer c
    ON f.customer_id = c.customer_id
WHERE c.is_current = 1
GROUP BY
    c.customer_id,
    c.country,
    c.segment;