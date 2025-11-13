-- ARR Type Classification Validation - Verifies that arr_type is correctly populated and matches business logic rules
-- Ensures all rows have valid arr_type values including the new 'Churn with Recovery ARR' category
{{ config(severity = 'error') }}

select
    account_sfid,
    month_start,
    arr_type
from
    {{ ref('account_monthly_arr_deltas_by_type') }}
where
    arr_type is not null
    and arr_type not in (
        'New ARR',
        'Expansion ARR',
        'Resurrection ARR',
        'Contraction ARR',
        'Churn ARR',
        'Churn with Recovery ARR'
    )

