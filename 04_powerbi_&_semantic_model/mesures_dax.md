# RetailPulse — Measures (DAX)

This file contains the **DAX measures** used in the RetailPulse semantic model (Warehouse / Direct Lake).
All measures align to your current model tables/columns:

- **fact_sales**: `sales_amount`, `quantity`, `order_id`, `order_item_id`, `customer_id`, `product_id`, `date_key`, `channel`, `unit_price`
- **fact_payments**: `amount`, `payment_status`, `payment_method`, `order_id`, `payment_id`, `date_key`
- **fact_returns**: `refund_amount`, `return_id`, `order_id`, `order_item_id`, `product_id`, `date_key`, `return_reason`, `return_status`
- **dim_product**: `current_qty`, `reorder_level`, `product_name`, `brand`, `category`, `unit_price`, `status`, `product_id`
- **dim_customer**: `customer_id`, `country`, `segment`, `is_current`, `effective_start_ts`, `effective_end_ts`
- **dim_date**: `date_key`, `full_date`, `year`, `quarter`, `month`, `month_name`, `day_of_month`, `day_name`, `week_of_year`

---

## 0) Relationships (required)

Create these relationships (single direction, 1:*):
- `dim_date[date_key]` → `fact_sales[date_key]`
- `dim_date[date_key]` → `fact_payments[date_key]`
- `dim_date[date_key]` → `fact_returns[date_key]`
- `dim_customer[customer_id]` → `fact_sales[customer_id]`
- `dim_product[product_id]` → `fact_sales[product_id]`

Avoid many-to-many links (`fact_sales` ↔ `fact_payments`, `fact_sales` ↔ `fact_returns`) unless you truly need them.

---

## 1) Create a Measures table

Create a table named **Measures** and store all measures below in it.

```DAX
Measures = DATATABLE("x", INTEGER, {{1}})
```

---

# PAGE 1 — Executive Overview (CEO / GM)

## Sales KPIs
```DAX
Total Sales = SUM ( fact_sales[sales_amount] )
```

```DAX
Total Orders = DISTINCTCOUNT ( fact_sales[order_id] )
```

```DAX
Total Units = SUM ( fact_sales[quantity] )
```

```DAX
AOV = DIVIDE ( [Total Sales], [Total Orders] )
```

## Trend / Growth
```DAX
Sales MTD = TOTALMTD ( [Total Sales], dim_date[full_date] )
```

```DAX
Sales YTD = TOTALYTD ( [Total Sales], dim_date[full_date] )
```

```DAX
Sales YoY =
CALCULATE ( [Total Sales], SAMEPERIODLASTYEAR ( dim_date[full_date] ) )
```

```DAX
Sales YoY % =
VAR PY = [Sales YoY]
RETURN DIVIDE ( [Total Sales] - PY, PY )
```

```DAX
Orders MTD = TOTALMTD ( [Total Orders], dim_date[full_date] )
```

```DAX
Orders YoY =
CALCULATE ( [Total Orders], SAMEPERIODLASTYEAR ( dim_date[full_date] ) )
```

```DAX
Orders YoY % =
VAR PY = [Orders YoY]
RETURN DIVIDE ( [Total Orders] - PY, PY )
```

## Payments / Returns (Executive Risk)
```DAX
Total Payments Amount = SUM ( fact_payments[amount] )
```

```DAX
Payment Success Count =
CALCULATE ( COUNTROWS ( fact_payments ), fact_payments[payment_status] = "Success" )
```

```DAX
Payment Failed Count =
CALCULATE ( COUNTROWS ( fact_payments ), fact_payments[payment_status] = "Failed" )
```

```DAX
Payment Success Rate =
DIVIDE ( [Payment Success Count], COUNTROWS ( fact_payments ) )
```

```DAX
Failed Amount =
CALCULATE ( SUM ( fact_payments[amount] ), fact_payments[payment_status] = "Failed" )
```

```DAX
Return Count = COUNTROWS ( fact_returns )
```

```DAX
Refund Amount = SUM ( fact_returns[refund_amount] )
```

```DAX
Refund % of Sales = DIVIDE ( [Refund Amount], [Total Sales] )
```

## Executive Health Score (optional demo KPI)
```DAX
Exec Health Score =
VAR pay = [Payment Success Rate]
VAR refund = 1 - [Refund % of Sales]
RETURN IF ( ISBLANK(pay) || ISBLANK(refund), BLANK(), ROUND( (pay*0.6 + refund*0.4) * 100, 1 ) )
```

---

# PAGE 2 — Operations & Inventory Risk (Ops Manager)

## Inventory
```DAX
Inventory Current Qty = SUM ( dim_product[current_qty] )
```

```DAX
Products Below Reorder =
COUNTROWS (
    FILTER ( dim_product, dim_product[current_qty] <= dim_product[reorder_level] )
)
```

```DAX
Products At Risk % =
DIVIDE ( [Products Below Reorder], COUNTROWS ( dim_product ) )
```

```DAX
Reorder Gap Units =
SUMX (
    FILTER ( dim_product, dim_product[current_qty] < dim_product[reorder_level] ),
    dim_product[reorder_level] - dim_product[current_qty]
)
```

## Operational Spike (Today vs Yesterday)
```DAX
Orders Today =
CALCULATE ( [Total Orders], dim_date[full_date] = TODAY() )
```

```DAX
Orders Yesterday =
CALCULATE ( [Total Orders], dim_date[full_date] = TODAY() - 1 )
```

```DAX
Orders DoD % =
VAR Y = [Orders Yesterday]
RETURN DIVIDE ( [Orders Today] - Y, Y )
```

```DAX
Sales Today =
CALCULATE ( [Total Sales], dim_date[full_date] = TODAY() )
```

```DAX
Sales Yesterday =
CALCULATE ( [Total Sales], dim_date[full_date] = TODAY() - 1 )
```

```DAX
Sales DoD % =
VAR Y = [Sales Yesterday]
RETURN DIVIDE ( [Sales Today] - Y, Y )
```

## Ops: Payment/Returns Today
```DAX
Failed Payments Today =
CALCULATE ( [Payment Failed Count], dim_date[full_date] = TODAY() )
```

```DAX
Failed Amount Today =
CALCULATE ( [Failed Amount], dim_date[full_date] = TODAY() )
```

```DAX
Returns Today =
CALCULATE ( [Return Count], dim_date[full_date] = TODAY() )
```

```DAX
Refund Amount Today =
CALCULATE ( [Refund Amount], dim_date[full_date] = TODAY() )
```

## Ops Alert Flags (for conditional formatting)
```DAX
ALERT_Inventory = IF ( [Products Below Reorder] > 0, "⚠️ Inventory Risk", "OK" )
```

```DAX
ALERT_Payments = IF ( [Payment Success Rate] < 0.95, "⚠️ Payment Risk", "OK" )
```

```DAX
ALERT_Returns = IF ( [Refund % of Sales] > 0.05, "⚠️ Returns Risk", "OK" )
```

---

# PAGE 3 — Finance + Customer & Segment (Finance / Segment Analyst)

## Customers
```DAX
Total Customers =
CALCULATE ( DISTINCTCOUNT ( dim_customer[customer_id] ), dim_customer[is_current] = 1 )
```

## Share of total (works for Segment/Country/Brand breakdowns)
```DAX
Sales % of Total =
DIVIDE (
    [Total Sales],
    CALCULATE ( [Total Sales], ALLSELECTED ( dim_customer ), ALLSELECTED ( dim_product ) )
)
```

## Repeat Proxy (simple + demo-ready)
```DAX
Repeat Customers =
VAR custOrders =
    SUMMARIZE (
        fact_sales,
        fact_sales[customer_id],
        "order_cnt", DISTINCTCOUNT ( fact_sales[order_id] )
    )
RETURN
COUNTROWS ( FILTER ( custOrders, [order_cnt] >= 2 ) )
```

```DAX
Repeat Rate % = DIVIDE ( [Repeat Customers], [Total Customers] )
```

## Payments (Finance)
```DAX
Avg Payment Amount = AVERAGE ( fact_payments[amount] )
```

```DAX
Failed Amount % = DIVIDE ( [Failed Amount], [Total Payments Amount] )
```

```DAX
Payments Success % (Amount) =
VAR successAmt =
    CALCULATE ( SUM ( fact_payments[amount] ), fact_payments[payment_status] = "Success" )
RETURN
DIVIDE ( successAmt, [Total Payments Amount] )
```

## Returns (Finance impact)
```DAX
Return Rate =
DIVIDE ( [Return Count], DISTINCTCOUNT ( fact_sales[order_item_id] ) )
```

```DAX
Refund per Order = DIVIDE ( [Refund Amount], [Total Orders] )
```

```DAX
Avg Refund = DIVIDE ( [Refund Amount], [Return Count] )
```

## Net Sales (Finance)
```DAX
Net Sales = [Total Sales] - [Refund Amount]
```

```DAX
Net Sales YoY =
CALCULATE ( [Net Sales], SAMEPERIODLASTYEAR ( dim_date[full_date] ) )
```

```DAX
Net Sales YoY % =
VAR PY = [Net Sales YoY]
RETURN DIVIDE ( [Net Sales] - PY, PY )
```

---

## Helpers (Top N visuals)
```DAX
Product Rank by Sales =
RANKX ( ALL ( dim_product[product_id] ), [Total Sales], , DESC )
```

```DAX
Customer Rank by Sales =
RANKX ( ALL ( dim_customer[customer_id] ), [Total Sales], , DESC )
```

---

## Notes (demo-friendly)
- Use `dim_date[full_date]` on all trend charts.
- Keep relationships simple; avoid many-to-many.
- Use slicers: Date, Channel, Country, Segment, Category.
