-- ============================================
-- Generate dim_date from fact_sales.date_key
-- ============================================

DECLARE @min_date DATE;
DECLARE @max_date DATE;

-- Convert date_key (yyyyMMdd) → DATE and add buffer
SELECT
    @min_date = DATEADD(
        DAY, -30,
        CAST(CONVERT(char(8), MIN(date_key)) AS DATE)
    ),
    @max_date = DATEADD(
        DAY,  30,
        CAST(CONVERT(char(8), MAX(date_key)) AS DATE)
    )
FROM dbo.fact_sales;

-- Safety fallback (should not trigger in your case)
IF @min_date IS NULL
BEGIN
    SET @min_date = DATEADD(YEAR, -1, CAST(GETDATE() AS DATE));
    SET @max_date = DATEADD(DAY,  30, CAST(GETDATE() AS DATE));
END;

-- Rebuild dim_date
TRUNCATE TABLE dbo.dim_date;

;WITH d AS (
    SELECT
        DATEADD(DAY, value, @min_date) AS dt
    FROM GENERATE_SERIES(
        0,
        DATEDIFF(DAY, @min_date, @max_date),
        1
    )
)
INSERT INTO dbo.dim_date
SELECT
    CAST(FORMAT(dt, 'yyyyMMdd') AS INT) AS date_key,
    dt AS full_date,
    YEAR(dt) AS [year],
    DATEPART(QUARTER, dt) AS [quarter],
    MONTH(dt) AS [month],
    DATENAME(MONTH, dt) AS month_name,
    DAY(dt) AS day_of_month,
    DATENAME(WEEKDAY, dt) AS day_name,
    DATEPART(WEEK, dt) AS week_of_year
FROM d;
