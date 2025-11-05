{{
    config({
        "materialized": "table",
        "tags": ["reports", "nps", "scorecard"]
    })
}}

-- Company Scorecard NPS Report
-- Aggregates NPS scores for company scorecard reporting
-- Used by executive dashboards and quarterly business reviews

select
    activity_date,
    server_id,
    daily_server_id,
    version_id,
    -- Current NPS metrics from fct_nps_score
    count_promoters_daily,
    count_detractors_daily,
    count_passives_daily,
    count_nps_users_daily,
    -- Roll up to weekly
    date_trunc('week', activity_date) as nps_week,
    -- Roll up to monthly
    date_trunc('month', activity_date) as nps_month,
    -- Aggregate metrics for reporting
    sum(count_promoters_daily) over (
        partition by server_id, date_trunc('week', activity_date)
    ) as weekly_promoters,
    sum(count_detractors_daily) over (
        partition by server_id, date_trunc('week', activity_date)
    ) as weekly_detractors,
    sum(count_nps_users_daily) over (
        partition by server_id, date_trunc('week', activity_date)
    ) as weekly_nps_users
from
    {{ ref('fct_nps_score') }}
where
    activity_date >= dateadd('day', -90, current_date)

