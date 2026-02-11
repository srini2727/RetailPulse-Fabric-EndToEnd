------------------------------------------------------------
-- VIEW 5: RETURNS SUMMARY (OPERATIONS / QUALITY VIEW)
------------------------------------------------------------
CREATE VIEW dbo.v_returns_summary AS
SELECT
    d.full_date,
    r.return_status,
    r.return_reason,
    COUNT(DISTINCT r.return_id) AS total_returns,
    SUM(r.refund_amount)        AS total_refund_amount
FROM dbo.fact_returns r
JOIN dbo.dim_date d
    ON r.date_key = d.date_key
GROUP BY
    d.full_date,
    r.return_status,
    r.return_reason;