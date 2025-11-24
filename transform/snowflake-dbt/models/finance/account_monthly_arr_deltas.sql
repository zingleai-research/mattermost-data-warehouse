{{config({
    "materialized": "table",
    "schema": "finance",
    "tags":["nightly"]
  })
}}

WITH monthly_base AS (
    SELECT
        date_trunc('month',new_day) AS month_start,
        date_trunc('month',new_day) + interval '1 month' - interval '1 day' AS month_end,
        master_account_sfid,
        account_sfid,
        max(account_new_arr) as account_new_arr,
        max(coalesce(CASE WHEN month_start THEN previous_day_total_arr ELSE 0 END, 0)) as month_starting_arr,
        max(coalesce(CASE WHEN month_end THEN new_day_total_arr ELSE 0 END, 0)) as month_ending_arr,
        sum(total_arr_delta) AS total_arr_delta
    FROM {{ ref('account_daily_arr_deltas') }}
    GROUP BY 1, 2, 3, 4
),
account_monthly_arr_deltas AS (
    SELECT
        monthly_base.*,
        LEAD(total_arr_delta, 1) OVER (
            PARTITION BY account_sfid 
            ORDER BY month_start
        ) as next_month_arr_delta,
        LEAD(month_start, 1) OVER (
            PARTITION BY account_sfid 
            ORDER BY month_start
        ) as next_month_start,
        -- Recovery within 30 days flag - moved upstream for reuse across downstream models
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
    FROM monthly_base
    WHERE abs(total_arr_delta) > 0
)

SELECT * FROM account_monthly_arr_deltas