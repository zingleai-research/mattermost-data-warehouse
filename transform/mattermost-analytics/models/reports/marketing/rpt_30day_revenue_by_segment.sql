{{
    config({
        "materialized": "table",
        "schema": "reports_marketing",
        "tags": ["nightly", "marketing", "growth_dashboard"]
    })
}}

-- Optimized 30-day revenue by customer segment query for Growth dashboard
-- Uses curated mart_orders_enriched instead of raw tables for better performance
-- Filters to last 30 days and excludes test users
WITH revenue_by_segment AS (
    SELECT
        customer_segment,
        COUNT(DISTINCT customer_id) as active_customers,
        COUNT(DISTINCT order_id) as total_orders,
        SUM(revenue) as total_revenue,
        AVG(revenue) as avg_order_value,
        MIN(order_date) as first_order_date,
        MAX(order_date) as last_order_date
    FROM {{ ref('mart_orders_enriched') }}
    WHERE order_date >= DATEADD(day, -30, CURRENT_DATE())
        AND order_date < CURRENT_DATE()
        AND is_test_user = FALSE
        AND revenue >= 0
    GROUP BY customer_segment
)
SELECT
    customer_segment,
    active_customers,
    total_orders,
    total_revenue,
    avg_order_value,
    first_order_date,
    last_order_date,
    CURRENT_TIMESTAMP() as report_generated_at
FROM revenue_by_segment
ORDER BY total_revenue DESC

