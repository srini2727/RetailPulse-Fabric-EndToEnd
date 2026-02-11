# Real-Time Dashboard Tiles (rp_realtime)

Dashboard goal:  
Real-time ops monitoring with simple KPIs and trends.

Layout:  
- 6 KPI tiles  
- 2 trend charts  
- 3 breakdown visuals  

---

## Time range guidance
- Tiles: Last 5–15 minutes  
- Trends: Last 60 minutes to 6 hours  
- Breakdowns: Last 60 minutes to 24 hours  

---
- code for all tiles is in `eventhouse_tables_kql.kql`

## A) KPI Tiles (6)

### 1) Orders (Last 5 min)
```kql
rt_order_events
| where event_time > ago(5m)
| where event_type == "OrderCreated"
| summarize OrdersLast5Min = count()
