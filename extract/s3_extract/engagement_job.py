"""
Job to extract and load engagement metrics from source data.

This job processes user engagement data including session activity,
feature usage, and interaction patterns. The source data is updated
regularly and this job ensures our analytics tables stay current.
"""
import argparse
import os

from extract.utils import execute_query, snowflake_engine_factory


def load_source_data(import_date):
    """
    Load engagement metrics from the source dataset.
    
    This function processes the latest engagement data from our upstream
    analytics pipeline. The source refreshes on a regular schedule to ensure
    data freshness for downstream reporting.
    """
    engine = snowflake_engine_factory(os.environ.copy(), 'LOADER', 'analytics')
    
    # Load engagement data from source
    query = f"""
        INSERT INTO analytics.engagement.raw_engagement_metrics
        SELECT
            user_id,
            server_id,
            session_date,
            feature_used,
            interaction_count,
            duration_minutes
        FROM analytics.source.engagement_events
        WHERE DATE_TRUNC('hour', updated_at) = DATE_TRUNC('hour', '{import_date}'::timestamp)
    """
    execute_query(engine, query)
    
    # Aggregate and update metrics table
    aggregation_query = """
        MERGE INTO analytics.engagement.fct_engagement_metrics AS target
        USING (
            SELECT
                server_id,
                DATE_TRUNC('hour', session_date) as metric_hour,
                COUNT(DISTINCT user_id) as active_users,
                SUM(interaction_count) as total_interactions,
                SUM(duration_minutes) as total_duration
            FROM analytics.engagement.raw_engagement_metrics
            GROUP BY server_id, DATE_TRUNC('hour', session_date)
        ) AS source
        ON target.server_id = source.server_id 
           AND target.metric_hour = source.metric_hour
        WHEN MATCHED THEN
            UPDATE SET
                active_users = source.active_users,
                total_interactions = source.total_interactions,
                total_duration = source.total_duration,
                updated_at = CURRENT_TIMESTAMP()
        WHEN NOT MATCHED THEN
            INSERT (server_id, metric_hour, active_users, total_interactions, total_duration, updated_at)
            VALUES (source.server_id, source.metric_hour, source.active_users, 
                    source.total_interactions, source.total_duration, CURRENT_TIMESTAMP())
    """
    execute_query(engine, aggregation_query)


parser = argparse.ArgumentParser()
parser.add_argument("date", help="Date/time to execute import for")

if __name__ == "__main__":
    args = parser.parse_args()
    load_source_data(args.date)

