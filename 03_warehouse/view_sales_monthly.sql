CREATE VIEW dbo.v_sales_monthly AS
SELECT
    d.year,
    d.month,
    d.month_name,
    SUM(f.sales_amount)        AS total_sales,
    SUM(f.quantity)            AS units_sold,
    COUNT(DISTINCT f.order_id) AS total_orders
FROM dbo.fact_sales f
JOIN dbo.dim_date d
    ON f.date_key = d.date_key
GROUP BY
    d.year,
    d.month,
    d.month_name;