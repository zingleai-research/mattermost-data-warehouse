-- Unique Key Validation - Verifies unique combination of account_sfid and month_start
{{ config(severity = 'error') }}

select
    account_sfid,
    month_start,
    count(*) as duplicate_count
from
    {{ ref('account_monthly_arr_deltas_by_type') }}
group by
    account_sfid,
    month_start
having
    count(*) > 1

