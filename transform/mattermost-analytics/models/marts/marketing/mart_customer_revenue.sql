{{
    config({
        "materialized": "table",
        "schema": "mart_marketing",
        "tags": ["nightly", "marketing", "finance", "revenue", "high-impact"]
    })
}}

-- Customer Lifetime Value (CLTV) calculation with 90-day rolling window
-- This model calculates net revenue and CLTV segments for each customer
-- WARNING: This model modifies core revenue calculations that impact multiple downstream dashboards
-- Approval required from Finance and Growth teams before merging
WITH base AS (
  SELECT
    c.customer_id,
    SUM(CASE 
      WHEN r.order_date >= DATEADD(day, -90, CURRENT_DATE) 
      THEN r.order_amount - r.refund_amount 
      ELSE 0 
    END) AS net_revenue_90d,
    COUNT(DISTINCT r.order_id) AS orders_count
  FROM {{ ref('mart_orders_enriched') }} r
  JOIN {{ ref('dim_customers') }} c ON r.customer_id = c.customer_id
  WHERE r.is_test_user = FALSE
  GROUP BY c.customer_id
)
SELECT
  customer_id,
  net_revenue_90d,
  CASE
    WHEN net_revenue_90d >= 5000 THEN 'High'
    WHEN net_revenue_90d >= 1000 THEN 'Medium'
    ELSE 'Low'
  END AS cltv_segment,
  orders_count
FROM base

