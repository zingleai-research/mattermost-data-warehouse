{{config({
    "materialized": "table",
    "schema": "finance",
    "tags":["nightly"]
  })
}}

WITH churn_analysis_base AS (
    SELECT
        arr.month_start,
        arr.month_end,
        arr.account_sfid,
        arr.master_account_sfid,
        arr.arr_type,
        arr.total_arr_churn,
        arr.total_arr_churn_with_recovery,
        arr.month_starting_arr,
        arr.month_ending_arr,
        arr.total_arr_delta,
        acc.customer_tier,
        acc.industry,
        acc.company_size,
        acc.country
    FROM {{ ref('account_monthly_arr_deltas_by_type') }} arr
    LEFT JOIN {{ ref('account') }} acc
        ON arr.account_sfid = acc.sfid
    WHERE arr.arr_type IN ('Churn ARR', 'Churn with Recovery ARR')
       OR arr.total_arr_churn < 0
       OR arr.total_arr_churn_with_recovery < 0
)
SELECT
    month_start,
    month_end,
    account_sfid,
    master_account_sfid,
    customer_tier,
    industry,
    company_size,
    country,
    arr_type,
    total_arr_churn,
    total_arr_churn_with_recovery,
    month_starting_arr,
    month_ending_arr,
    total_arr_delta,
    CASE 
        WHEN total_arr_churn_with_recovery < 0 
        THEN ABS(total_arr_churn_with_recovery) / NULLIF(ABS(total_arr_churn), 0) * 100
        ELSE 0 
    END as recovery_rate_pct,
    CASE 
        WHEN arr_type = 'Churn with Recovery ARR' THEN TRUE
        ELSE FALSE
    END as is_recovered_churn,
    ABS(total_arr_churn) + ABS(COALESCE(total_arr_churn_with_recovery, 0)) as total_churn_amount
FROM churn_analysis_base
ORDER BY month_start DESC, account_sfid

