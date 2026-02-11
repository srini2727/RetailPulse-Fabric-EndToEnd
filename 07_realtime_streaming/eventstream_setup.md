
# Eventstream Setup (rp_eventstream_dev)

Goal: Build real-time monitoring using Fabric Eventstream → Eventhouse (KQL DB) and Activator.


## Naming 
- Eventstream: `rp_eventstream_dev`
- Eventhouse/KQL Database: `rp_eventhouse_dev`
- Main table: `rt_order_events`
- Dashboard: `rp_realtime` (Real-Time Dashboard)
- Activator: `Order_spike_alert`

---

## Step-by-step

### 1) Create Eventhouse (KQL Database)
In Fabric workspace:
- New → Eventhouse (KQL Database)
- Name: `rp_eventhouse_dev`

### 2) Create Eventstream
- New → Eventstream
- Name: `rp_eventstream_dev`

### 3) Add Source
Choose one:

- Add source → Embedded event hub
- Use sample events or custom publisher later

### 4) Transform events
If your payload is already clean JSON, keep transformations minimal.
Recommended: keep only the important fields, do not over-transform.

### 5) Add Destination → Eventhouse
- Add destination → Eventhouse
- Choose: `rp_eventhouse_dev`
- Target table: `rt_order_events`
- Ingestion: direct ingestion is fine

### 6) Add Destination → Real-Time Dashboard
- Add destination → Real-Time Dashboard
- Name: `rp_realtime`
- This is used for real-time tiles and charts

### 7) Add Destination → Activator
- Add destination → Activator
- Use it for alerts (payment failures / inventory low / order spike)

---

## Common troubleshooting (what we faced)
If events get dropped with an error like:
"CloudEvent property type is missing"

That means schema registry/CloudEvents is expecting CloudEvent attributes.
Fix options:
1) Disable schema association (fastest)
2) Send full CloudEvents fields (type, source, id, specversion, time, datacontenttype)
3) Keep this project on simple JSON (recommended for stability)
