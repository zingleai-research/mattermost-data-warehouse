{{
    config({
        "materialized": "table",
        "schema": "mart_marketing",
        "tags": ["nightly", "marketing"]
    })
}}

-- Customer dimension table
-- NOTE: Update this to reference your actual customer dimension source
-- This is a placeholder that may need to be updated based on your actual customer data structure
SELECT DISTINCT
    customer_id,
    customer_name,
    customer_segment,
    customer_tier,
    is_test_user,
    country,
    industry,
    created_at,
    updated_at
FROM {{ ref('mart_orders_enriched') }}
WHERE is_test_user = FALSE

