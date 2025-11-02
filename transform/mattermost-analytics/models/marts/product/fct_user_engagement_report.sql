{{
    config({
        "materialized": "table",
        "description": "Daily user engagement report aggregating all user activity events for dashboard reporting"
    })
}}

-- User Engagement Report
-- This model provides comprehensive user engagement metrics by analyzing
-- all user interaction events across the platform. Used for daily dashboard reporting.
with all_events as (
    -- Get all user events to calculate engagement metrics
    select
        event_id,
        event_name,
        user_id,
        server_id,
        received_at,
        timestamp,
        category,
        event_type,
        channel_id,
        team_id
    from {{ ref('stg_mm_telemetry_prod__event') }}
),

user_activity as (
    -- Calculate per-user engagement metrics
    select
        user_id,
        server_id,
        -- Count total events per user
        COUNT(*) as total_events,
        COUNT(DISTINCT event_name) as unique_event_types,
        COUNT(DISTINCT channel_id) as channels_engaged,
        COUNT(DISTINCT team_id) as teams_engaged,
        -- Calculate session duration and activity spans
        MIN(timestamp) as first_event_time,
        MAX(timestamp) as last_event_time,
        DATEDIFF('hour', MIN(timestamp), MAX(timestamp)) as activity_span_hours,
        -- Window function to rank users by activity
        ROW_NUMBER() OVER (
            PARTITION BY server_id 
            ORDER BY COUNT(*) DESC
        ) as user_activity_rank
    from all_events
    group by user_id, server_id
),

server_summary as (
    -- Aggregate metrics at server level
    select
        server_id,
        COUNT(DISTINCT user_id) as total_active_users,
        SUM(total_events) as total_server_events,
        SUM(unique_event_types) as server_event_types,
        AVG(activity_span_hours) as avg_user_activity_span,
        -- Calculate engagement score (weighted by activity)
        SUM(total_events * activity_span_hours) as engagement_score
    from user_activity
    group by server_id
),

event_category_summary as (
    -- Summarize events by category across all time
    select
        server_id,
        category,
        COUNT(*) as category_event_count,
        COUNT(DISTINCT user_id) as category_active_users,
        ROW_NUMBER() OVER (
            PARTITION BY server_id 
            ORDER BY COUNT(*) DESC
        ) as category_rank
    from all_events
    group by server_id, category
)

select
    s.server_id,
    s.total_active_users,
    s.total_server_events,
    s.server_event_types,
    s.avg_user_activity_span,
    s.engagement_score,
    -- Top engaged users
    u.user_id as top_user_id,
    u.total_events as top_user_events,
    u.user_activity_rank,
    -- Top event category
    e.category as top_event_category,
    e.category_event_count as top_category_events,
    e.category_rank
from server_summary s
left join user_activity u 
    on s.server_id = u.server_id 
    and u.user_activity_rank = 1
left join event_category_summary e
    on s.server_id = e.server_id
    and e.category_rank = 1

