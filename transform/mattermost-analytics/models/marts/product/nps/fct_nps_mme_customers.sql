{{
    config({
        "materialized": "table",
        "tags": ["nps", "mme", "customers"]
    })
}}

-- MME Customer NPS Fact Table
-- Aggregates NPS scores specifically for MME (Mid-Market/Enterprise) customers
-- Used for company scorecard and executive reporting

select
    nps.activity_date,
    nps.server_id,
    nps.daily_server_id,
    nps.version_id,
    customer.customer_tier,
    customer.account_name,
    -- NPS metrics from fct_nps_score
    nps.count_promoters_daily,
    nps.count_detractors_daily,
    nps.count_passives_daily,
    nps.count_nps_users_daily,
    nps.count_user_promoters_daily,
    nps.count_user_detractors_daily,
    nps.count_user_passives_daily,
    nps.count_user_nps_users_daily,
    -- MME specific flag (now available in fct_nps_score)
    nps.is_mme_customer,
    -- Use NPS score from fct_nps_score
    nps.nps_score_daily,
    nps.end_user_nps_score_daily
from
    {{ ref('fct_nps_score') }} nps
    left join {{ ref('dim_latest_server_customer_info') }} customer
        on nps.server_id = customer.server_id
where
    -- Filter to MME customers only (using flag from fct_nps_score)
    nps.is_mme_customer = true
    and nps.activity_date >= dateadd('day', -90, current_date)

