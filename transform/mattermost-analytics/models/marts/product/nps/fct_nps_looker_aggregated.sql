{{
    config({
        "materialized": "table",
        "tags": ["nps", "looker", "dashboard"]
    })
}}

-- NPS Looker Dashboard Aggregation
-- Pre-aggregated NPS data for Looker dashboard consumption
-- Optimized for dashboard queries with common filters

select
    activity_date,
    server_id,
    daily_server_id,
    version_id,
    -- Daily metrics
    count_promoters_daily,
    count_detractors_daily,
    count_passives_daily,
    count_nps_users_daily,
    -- User role breakdown (for End Users filter)
    count_user_promoters_daily as end_user_promoters_daily,
    count_user_detractors_daily as end_user_detractors_daily,
    count_user_passives_daily as end_user_passives_daily,
    count_user_nps_users_daily as end_user_nps_users_daily,
    -- Last 90 days metrics
    count_promoters_last90d,
    count_detractors_last90d,
    count_passives_last90d,
    count_nps_users_last90d,
    -- New: NPS Score calculations
    nps_score_daily,
    nps_score_last90d,
    end_user_nps_score_daily,
    end_user_nps_score_last90d,
    -- New: MME customer flag
    is_mme_customer
from
    {{ ref('fct_nps_score') }}
where
    activity_date >= dateadd('day', -90, current_date)

