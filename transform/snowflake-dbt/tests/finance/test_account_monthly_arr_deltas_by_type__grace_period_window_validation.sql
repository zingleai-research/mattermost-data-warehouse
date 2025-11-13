-- Grace Period Window Validation - Ensures data is fresh enough to accurately classify accounts within the 30-day grace period
-- Validates that recent churn events have sufficient future data available
{{ config(severity = 'warn') }}

select
    account_sfid,
    month_start,
    month_end,
    arr_type
from
    {{ ref('account_monthly_arr_deltas_by_type') }}
where
    month_end > CURRENT_DATE()

