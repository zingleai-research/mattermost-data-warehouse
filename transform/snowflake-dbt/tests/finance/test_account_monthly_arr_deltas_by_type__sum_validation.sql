-- Sum Validation - Verifies ARR type columns sum equals total_arr_delta
{{ config(severity = 'error') }}

select
    account_sfid,
    month_start,
    total_arr_delta,
    total_arr_new,
    total_arr_expansion,
    total_arr_resurrection,
    total_arr_contraction,
    total_arr_churn,
    total_arr_churn_with_recovery,
    (COALESCE(total_arr_new, 0) + 
     COALESCE(total_arr_expansion, 0) + 
     COALESCE(total_arr_resurrection, 0) + 
     COALESCE(total_arr_contraction, 0) + 
     COALESCE(total_arr_churn, 0) + 
     COALESCE(total_arr_churn_with_recovery, 0)) as calculated_sum,
    ABS(total_arr_delta - (COALESCE(total_arr_new, 0) + 
                           COALESCE(total_arr_expansion, 0) + 
                           COALESCE(total_arr_resurrection, 0) + 
                           COALESCE(total_arr_contraction, 0) + 
                           COALESCE(total_arr_churn, 0) + 
                           COALESCE(total_arr_churn_with_recovery, 0))) as difference
from
    {{ ref('account_monthly_arr_deltas_by_type') }}
where
    ABS(total_arr_delta - (COALESCE(total_arr_new, 0) + 
                           COALESCE(total_arr_expansion, 0) + 
                           COALESCE(total_arr_resurrection, 0) + 
                           COALESCE(total_arr_contraction, 0) + 
                           COALESCE(total_arr_churn, 0) + 
                           COALESCE(total_arr_churn_with_recovery, 0))) >= 0.01

