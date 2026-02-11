CREATE VIEW dbo.v_sales_daily AS
SELECT
    d.full_date,
    d.year,
    d.month,
    d.month_name,
    p.category,
    p.brand,
    c.country,
    c.segment,
    SUM(f.sales_amount)              AS total_sales,
    SUM(f.quantity)                  AS units_sold,
    COUNT(DISTINCT f.order_id)       AS total_orders
FROM dbo.fact_sales f
JOIN dbo.dim_date d
    ON f.date_key = d.date_key
JOIN dbo.dim_product p
    ON f.product_id = p.product_id
JOIN dbo.dim_customer c
    ON f.customer_id = c.customer_id
WHERE c.is_current = 1
GROUP BY
    d.full_date,
    d.year,
    d.month,
    d.month_name,
    p.category,
    p.brand,
    c.country,
    c.segment;