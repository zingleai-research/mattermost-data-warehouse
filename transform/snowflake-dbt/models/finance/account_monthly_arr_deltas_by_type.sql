{{config({
    "materialized": "table",
    "schema": "finance",
    "tags":["nightly", "operations_team"]
  })
}}

WITH monthly_data_with_recovery_check AS (
    SELECT
        account_monthly_arr_deltas.*,
        LEAD(total_arr_delta, 1) OVER (
            PARTITION BY account_sfid 
            ORDER BY month_start
        ) as next_month_arr_delta,
        LEAD(month_start, 1) OVER (
            PARTITION BY account_sfid 
            ORDER BY month_start
        ) as next_month_start,
        -- Recovery within 30 days calculation - done in this model
        -- Note: This logic could be moved upstream to account_monthly_arr_deltas for better reuse
        CASE
            WHEN total_arr_delta < 0 
                AND month_ending_arr = 0 
                AND LEAD(month_start, 1) OVER (PARTITION BY account_sfid ORDER BY month_start) IS NOT NULL
                AND DATEDIFF(day, 
                    month_end, 
                    LEAD(month_start, 1) OVER (PARTITION BY account_sfid ORDER BY month_start)
                ) <= 30
                AND LEAD(total_arr_delta, 1) OVER (PARTITION BY account_sfid ORDER BY month_start) > 0
            THEN 1
            ELSE 0
        END as has_recovery_within_30d
    FROM {{ ref('account_monthly_arr_deltas') }}
    WHERE abs(total_arr_delta) > 0
),
account_monthly_arr_deltas_by_type AS (
    SELECT
        monthly_data_with_recovery_check.month_start,
        monthly_data_with_recovery_check.month_end,
        monthly_data_with_recovery_check.account_sfid,
        monthly_data_with_recovery_check.master_account_sfid,
        CASE
            WHEN account_new_arr THEN 'New ARR'
            WHEN NOT account_new_arr AND month_starting_arr != 0 AND total_arr_delta > 0 THEN 'Expansion ARR'
            WHEN NOT account_new_arr AND month_starting_arr = 0 AND total_arr_delta > 0 THEN 'Resurrection ARR'
            WHEN total_arr_delta < 0 AND month_ending_arr != 0 THEN 'Contraction ARR'
            WHEN total_arr_delta < 0 AND month_ending_arr = 0 AND has_recovery_within_30d = 1 THEN 'Churn with Recovery ARR'
            WHEN total_arr_delta < 0 AND month_ending_arr = 0 AND has_recovery_within_30d = 0 THEN 'Churn ARR'
            ELSE NULL
        END as arr_type,
        sum(CASE WHEN account_new_arr THEN total_arr_delta ELSE 0 END) AS total_arr_new,
        sum(CASE WHEN NOT account_new_arr AND month_starting_arr != 0 AND total_arr_delta > 0 THEN total_arr_delta ELSE 0 END) AS total_arr_expansion,
        sum(CASE WHEN NOT account_new_arr AND month_starting_arr = 0 AND total_arr_delta > 0 THEN total_arr_delta ELSE 0 END) AS total_arr_resurrection,
        sum(CASE WHEN total_arr_delta < 0 AND month_ending_arr != 0 THEN total_arr_delta ELSE 0 END) AS total_arr_contraction,
        sum(CASE 
            WHEN total_arr_delta < 0 AND month_ending_arr = 0 AND has_recovery_within_30d = 0 
            THEN total_arr_delta ELSE 0 
        END) AS total_arr_churn,
        sum(CASE 
            WHEN total_arr_delta < 0 AND month_ending_arr = 0 AND has_recovery_within_30d = 1 
            THEN total_arr_delta ELSE 0 
        END) AS total_arr_churn_with_recovery,
        sum(total_arr_delta) AS total_arr_delta
    FROM monthly_data_with_recovery_check
    GROUP BY 1, 2, 3, 4, 5, has_recovery_within_30d
)
select * from account_monthly_arr_deltas_by_type