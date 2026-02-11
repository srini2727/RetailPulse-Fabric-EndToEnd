# RetailPulse — Row Level Security (RLS) Plan (Power BI Semantic Model)

This document explains how Row Level Security (RLS) is implemented in the RetailPulse semantic model using the Warehouse star schema. The goal is to keep it simple, demo-ready, and realistic for a portfolio project.

---

## 1) What RLS protects

RetailPulse uses RLS to control who can see data in the report based on:
- Country (regional access)
- Segment (business segment access)
- Executive access (see everything)

RLS is applied in the Power BI semantic model (dataset), because it is the cleanest and most common way to manage access in BI reporting. It is also easy to demonstrate using “View as role”.

---

## 2) RLS roles used in this project

### Role: Executive_AllAccess
- Full access to all data
- No filters

### Role: Ops_ByCountry
- Operations users only see data for the countries assigned to them

### Role: Finance_ByCountry
- Finance users only see data for the countries assigned to them
- Same logic as Ops, different role name for demo clarity

### Role: Segment_Analyst
- Analysts see only data for the segments assigned to them

This set of roles is enough to show realistic, enterprise-style access control.

---

## 3) Security approach (recommended)

### Mapping table approach (scalable)
RetailPulse uses a mapping table in the Warehouse so access can be managed without editing the semantic model roles each time.

Table: `dbo.rls_user_access`

| Column | Example | Meaning |
|---|---|---|
| user_email | user@company.com | The user login email |
| access_type | COUNTRY / SEGMENT / ALL | Type of access |
| access_value | US / CA / Consumer / * | Allowed value |

Example rows:
- john@retailpulse.com, COUNTRY, US
- john@retailpulse.com, COUNTRY, CA
- maria@retailpulse.com, SEGMENT, Consumer
- ceo@retailpulse.com, ALL, *

---

## 4) Model relationships used by RLS

RetailPulse uses a star schema. These relationships are required:

- dim_customer[customer_id] → fact_sales[customer_id]
- dim_product[product_id] → fact_sales[product_id]
- dim_date[date_key] → fact_sales[date_key]
- dim_date[date_key] → fact_payments[date_key]
- dim_date[date_key] → fact_returns[date_key]

For RLS, the safest and simplest approach is:
Apply the RLS filter on dim_customer and let it automatically filter fact_sales through the relationship.

Note: fact_payments and fact_returns may not filter through dim_customer unless they also contain customer_id and have relationships. For this portfolio demo, RLS is focused on Sales and Customer-level views, which is a common real-world pattern.

---

## 5) Implementation steps (what I did)

### Step 1 — Create the mapping table in the Warehouse
Create and populate `dbo.rls_user_access` with demo users and access rows.

### Step 2 — Add the mapping table to the semantic model
In the Power BI semantic model, load `dbo.rls_user_access` from the Warehouse along with dimensions and facts.

### Step 3 — Create roles in the semantic model
Power BI → Modeling → Manage roles

#### Role: Executive_AllAccess
No filter applied.

#### Role: Ops_ByCountry
Apply this filter on `dim_customer`:

```DAX
dim_customer[country] IN
CALCULATETABLE(
    VALUES('dbo.rls_user_access'[access_value]),
    'dbo.rls_user_access'[user_email] = USERPRINCIPALNAME(),
    'dbo.rls_user_access'[access_type] = "COUNTRY"
)
