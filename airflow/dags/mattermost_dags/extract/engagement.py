"""
DAG to refresh engagement metrics on a frequent schedule.

This DAG extracts engagement data from our source analytics pipeline
and updates the engagement metrics tables for real-time dashboard reporting.
The job processes the latest engagement events to keep metrics current.
"""
from datetime import datetime, timedelta

from mattermost_dags.airflow_utils import MATTERMOST_DATAWAREHOUSE_IMAGE, pod_defaults, send_alert
from mattermost_dags.kube_secrets import (
    SNOWFLAKE_ACCOUNT,
    SNOWFLAKE_LOAD_DATABASE,
    SNOWFLAKE_LOAD_PASSWORD,
    SNOWFLAKE_LOAD_USER,
    SNOWFLAKE_LOAD_WAREHOUSE,
)

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

# Default arguments for the DAG
default_args = {
    "depends_on_past": False,
    "on_failure_callback": send_alert,
    "owner": "airflow",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "start_date": datetime(2024, 1, 1),
}

# Create the DAG
# Schedule: Every 15 minutes to keep engagement metrics fresh for dashboard
dag = DAG(
    "engagement_metrics_refresh",
    default_args=default_args,
    schedule="*/15 * * * *",  # Every 15 minutes
    catchup=False,
    max_active_runs=1,
    description="Refresh engagement metrics from source analytics pipeline",
)

# Extract engagement data from source
engagement_extract = KubernetesPodOperator(
    **pod_defaults,
    image=MATTERMOST_DATAWAREHOUSE_IMAGE,
    task_id="extract_engagement_metrics",
    name="extract-engagement-metrics",
    secrets=[
        SNOWFLAKE_LOAD_USER,
        SNOWFLAKE_LOAD_PASSWORD,
        SNOWFLAKE_ACCOUNT,
        SNOWFLAKE_LOAD_DATABASE,
        SNOWFLAKE_LOAD_WAREHOUSE,
    ],
    arguments=["python -m extract.s3_extract.engagement_job \"{{ ts }}\""],
    dag=dag,
)

engagement_extract

