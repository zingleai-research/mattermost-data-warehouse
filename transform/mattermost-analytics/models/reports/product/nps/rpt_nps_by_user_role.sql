{{
    config({
        "materialized": "table",
        "tags": ["reports", "nps", "user-role"]
    })
}}

-- NPS Report by User Role
-- Provides NPS distribution by user role (system_admin, team_admin, user)
-- Used by product team for user segmentation analysis

select
    activity_date,
    server_id,
    daily_server_id,
    version_id,
    -- User role specific metrics
    count_user_promoters_daily,
    count_user_detractors_daily,
    count_user_passives_daily,
    count_user_nps_users_daily,
    count_team_admin_promoters_daily,
    count_team_admin_detractors_daily,
    count_team_admin_passives_daily,
    count_team_admin_nps_users_daily,
    count_system_admin_promoters_daily,
    count_system_admin_detractors_daily,
    count_system_admin_passives_daily,
    count_system_admin_nps_users_daily,
    -- Total metrics
    count_promoters_daily,
    count_detractors_daily,
    count_passives_daily,
    count_nps_users_daily
from
    {{ ref('fct_nps_score') }}
where
    activity_date >= dateadd('day', -90, current_date)

