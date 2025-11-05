{{config({
    "materialized": "table",
    "schema": "reports_finance",
    "tags":["nightly"]
  })
}}

WITH monthly_churn_base AS (
    SELECT
        arr.month_start,
        arr.account_sfid,
        arr.total_arr_churn,
        arr.arr_type,
        arr.month_starting_arr,
        arr.month_ending_arr,
        acc.customer_tier,
        acc.industry,
        acc.company_size,
        acc.country
    FROM {{ ref('account_monthly_arr_deltas_by_type') }} arr
    LEFT JOIN {{ ref('account') }} acc
        ON arr.account_sfid = acc.sfid
    WHERE arr.arr_type = 'Churn ARR'
       OR arr.total_arr_churn < 0
)
SELECT
    month_start,
    customer_tier,
    industry,
    company_size,
    country,
    COUNT(DISTINCT account_sfid) as churned_accounts,
    SUM(total_arr_churn) as total_churn_arr,
    SUM(ABS(total_arr_churn)) as absolute_churn_arr,
    SUM(month_starting_arr) as total_starting_arr,
    CASE 
        WHEN SUM(month_starting_arr) > 0 
        THEN (SUM(ABS(total_arr_churn)) / SUM(month_starting_arr)) * 100
        ELSE 0 
    END as churn_rate_pct,
    AVG(ABS(total_arr_churn)) as avg_churn_per_account
FROM monthly_churn_base
GROUP BY 1, 2, 3, 4, 5
ORDER BY month_start DESC, total_churn_arr ASC

