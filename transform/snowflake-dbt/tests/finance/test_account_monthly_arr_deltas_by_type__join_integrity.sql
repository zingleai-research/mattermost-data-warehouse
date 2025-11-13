-- Join Integrity - Verifies relationships with upstream account_monthly_arr_deltas model are valid
{{ config(severity = 'error') }}

select
    by_type.account_sfid,
    by_type.month_start
from
    {{ ref('account_monthly_arr_deltas_by_type') }} as by_type
left join
    {{ ref('account_monthly_arr_deltas') }} as base
    on by_type.account_sfid = base.account_sfid
    and by_type.month_start = base.month_start
where
    base.account_sfid is null

