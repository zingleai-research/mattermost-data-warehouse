-- Churn Value Range - Verifies total_arr_churn and total_arr_churn_with_recovery values are always <= 0
-- Churn represents ARR loss
{{ config(severity = 'error') }}

select
    account_sfid,
    month_start,
    total_arr_churn,
    total_arr_churn_with_recovery
from
    {{ ref('account_monthly_arr_deltas_by_type') }}
where
    total_arr_churn > 0
    or total_arr_churn_with_recovery > 0

