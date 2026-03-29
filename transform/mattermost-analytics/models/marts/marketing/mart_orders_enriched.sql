{{
    config({
        "materialized": "table",
        "schema": "mart_marketing",
        "tags": ["nightly", "marketing"]
    })
}}

-- Curated mart table for orders with enriched customer data
-- This replaces raw_orders and raw_customers joins for better performance
-- NOTE: Update source references below to match your actual source configuration
SELECT
    o.order_id,
    o.order_date,
    o.customer_id,
    o.revenue,
    o.order_status,
    c.customer_segment,
    c.customer_tier,
    c.is_test_user,
    c.customer_name,
    c.country,
    c.industry,
    o.created_at,
    o.updated_at
FROM {{ source('orders', 'raw_orders') }} o
LEFT JOIN {{ source('customers', 'raw_customers') }} c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN ('completed', 'fulfilled')
    AND (c.is_test_user = FALSE OR c.is_test_user IS NULL)

