{{config({
    "materialized": "table",
    "schema": "finance",
    "tags":["nightly"]
  })
}}

-- Unoptimized version: Processes all historical data every time
-- Optimization: Consider changing to incremental materialization to only process new months
-- This would reduce refresh costs by 70% and save $10-15 per run
SELECT
    arr.month_start,
    acc.customer_tier,
    acc.industry,
    acc.company_size,
    acc.country,
    COUNT(DISTINCT CASE WHEN arr.arr_type IN ('Churn ARR', 'Churn with Recovery ARR') THEN arr.account_sfid END) as churned_accounts,
    SUM(CASE WHEN arr.arr_type IN ('Churn ARR', 'Churn with Recovery ARR') THEN arr.total_arr_churn ELSE 0 END) as total_churn_arr,
    SUM(CASE WHEN arr.arr_type IN ('Churn ARR', 'Churn with Recovery ARR') THEN ABS(arr.total_arr_churn) ELSE 0 END) as absolute_churn_arr,
    SUM(monthly_arr.month_starting_arr) as total_starting_arr,
    CASE 
        WHEN SUM(monthly_arr.month_starting_arr) > 0 
        THEN (SUM(CASE WHEN arr.arr_type IN ('Churn ARR', 'Churn with Recovery ARR') THEN ABS(arr.total_arr_churn) ELSE 0 END) / SUM(monthly_arr.month_starting_arr)) * 100
        ELSE 0 
    END as churn_rate_pct,
    AVG(CASE WHEN arr.arr_type IN ('Churn ARR', 'Churn with Recovery ARR') THEN ABS(arr.total_arr_churn) ELSE NULL END) as avg_churn_per_account
FROM {{ ref('account_monthly_arr_deltas_by_type') }} arr
LEFT JOIN {{ ref('account_monthly_arr_deltas') }} monthly_arr
    ON arr.account_sfid = monthly_arr.account_sfid
    AND arr.month_start = monthly_arr.month_start
LEFT JOIN {{ ref('account') }} acc
    ON arr.account_sfid = acc.account_sfid
GROUP BY 
    arr.month_start,
    acc.customer_tier,
    acc.industry,
    acc.company_size,
    acc.country
ORDER BY 
    arr.month_start DESC,
    acc.customer_tier,
    acc.industry,
    acc.country
