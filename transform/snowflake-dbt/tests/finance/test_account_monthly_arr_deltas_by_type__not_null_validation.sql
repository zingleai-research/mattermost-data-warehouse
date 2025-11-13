-- Not Null Validation - Ensures total_arr_churn and total_arr_churn_with_recovery are never NULL
{{ config(severity = 'error') }}

select
    account_sfid,
    month_start,
    total_arr_churn,
    total_arr_churn_with_recovery
from
    {{ ref('account_monthly_arr_deltas_by_type') }}
where
    total_arr_churn is null
    or total_arr_churn_with_recovery is null

