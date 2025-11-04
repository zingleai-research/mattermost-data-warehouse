# PR #1: Engagement Metrics Refresh Job

**Branch:** `pr-engagement-metrics-15min`  
**PR Title:** Added job to refresh engagement metrics every 15 minutes

## Overview

This PR introduces a new Airflow DAG and extract job to refresh engagement metrics from the source analytics pipeline. The job is scheduled to run every 15 minutes to keep dashboard data current.

## Optimization Issues

### Issue #1: Job Frequency Mismatch with Upstream Data Refresh Rate

**Severity:** High  
**Cost Impact:** High  
**Performance Impact:** Medium

#### Problem
The DAG runs every 15 minutes, but the upstream source data (`analytics.source.engagement_events`) only updates once per hour. This causes:
- **Unnecessary compute costs**: 3x more job executions than needed (4 runs/hour vs 1 update/hour)
- **Wasted resources**: Jobs process the same data multiple times per hour
- **No incremental benefit**: Running more frequently doesn't improve data freshness

#### Targeted Code Locations

**File:** `airflow/dags/mattermost_dags/extract/engagement.py`
- **Line 36:** `schedule="*/15 * * * *"` - Cron expression runs every 15 minutes
- **Line 31-37:** DAG configuration lacks upstream dependency checks

**File:** `extract/s3_extract/engagement_job.py`
- **Line 26-34:** SQL query filters by hour, implying hourly granularity is sufficient
- **Line 16-18:** Comments mention "source refreshes on a regular schedule" but don't specify frequency or add checks

#### Optimization Suggestions

1. **Reduce Schedule Frequency**
   ```python
   # Change from every 15 minutes to hourly
   schedule="0 * * * *",  # Every hour at minute 0
   ```

2. **Add Upstream Dependency Check**
   ```python
   # In engagement_job.py, add a check before processing:
   def check_upstream_refresh():
       engine = snowflake_engine_factory(os.environ.copy(), 'LOADER', 'analytics')
       query = """
           SELECT MAX(updated_at) as latest_update
           FROM analytics.source.engagement_events
       """
       result = execute_query(engine, query)
       latest_update = result[0][0] if result else None
       
       # Only proceed if data updated in last hour
       if latest_update and (datetime.now() - latest_update).total_seconds() < 3600:
           return True
       return False
   ```

3. **Add Skip Logic**
   ```python
   # In load_source_data function
   if not check_upstream_refresh():
       logging.info("Skipping run - upstream data not updated since last run")
       return
   ```

4. **Consider Incremental Processing**
   - Track last processed timestamp
   - Only process new data since last run
   - Reduces query costs on large tables

#### Expected Cost Savings
- **Compute Reduction**: ~75% reduction in job executions (from 96/day to 24/day)
- **Query Costs**: Eliminate redundant queries when source hasn't updated
- **Resource Usage**: Lower Kubernetes pod usage and Snowflake warehouse credits

---

### Issue #2: Missing Data Freshness Validation

**Severity:** Medium  
**Cost Impact:** Low  
**Performance Impact:** Low

#### Problem
No validation to ensure upstream data is actually fresh before processing. Jobs may run even when source hasn't updated.

#### Targeted Code Locations

**File:** `extract/s3_extract/engagement_job.py`
- **Line 14-19:** `load_source_data()` function has no upstream freshness check
- **Line 26-34:** Query filters by hour but doesn't verify data actually exists for that hour

#### Optimization Suggestions

Add validation logic:
```python
def validate_source_data_freshness(import_date):
    """Check if source data is available and fresh"""
    engine = snowflake_engine_factory(os.environ.copy(), 'LOADER', 'analytics')
    
    check_query = f"""
        SELECT COUNT(*) as record_count,
               MAX(updated_at) as latest_update
        FROM analytics.source.engagement_events
        WHERE DATE_TRUNC('hour', updated_at) = DATE_TRUNC('hour', '{import_date}'::timestamp)
    """
    
    result = execute_query(engine, check_query)
    record_count = result[0][0] if result else 0
    
    if record_count == 0:
        logging.warning(f"No source data found for {import_date}")
        return False
    
    return True
```

---

## Test Cases

### Test Case 1: Schedule Frequency Validation
**Objective:** Verify job frequency matches upstream refresh rate

**Test Steps:**
1. Identify upstream data refresh frequency (should be hourly)
2. Verify DAG schedule matches or exceeds upstream frequency appropriately
3. Check for any documentation stating upstream refresh schedule

**Expected Result:** DAG should run hourly (not every 15 minutes) to match upstream refresh

**Location:** `airflow/dags/mattermost_dags/extract/engagement.py:36`

---

### Test Case 2: Upstream Dependency Check
**Objective:** Verify job checks for upstream data availability

**Test Steps:**
1. Review `engagement_job.py` for upstream dependency checks
2. Check if job validates source data freshness before processing
3. Verify skip logic exists when upstream hasn't updated

**Expected Result:** Job should check and skip if upstream data hasn't refreshed

**Location:** `extract/s3_extract/engagement_job.py:14-73`

---

### Test Case 3: Cost Impact Analysis
**Objective:** Calculate potential cost savings from optimization

**Test Steps:**
1. Measure current job execution frequency (96/day with 15-min schedule)
2. Calculate compute costs per execution
3. Estimate costs with hourly schedule (24/day)
4. Calculate percentage savings

**Expected Result:** ~75% reduction in execution costs

---

### Test Case 4: Data Freshness Validation
**Objective:** Ensure jobs handle missing upstream data gracefully

**Test Steps:**
1. Simulate scenario where upstream source hasn't updated
2. Run job and verify it skips processing or handles gracefully
3. Check logs for appropriate warnings/messages

**Expected Result:** Job should skip or log warning when source data unavailable

---

### Test Case 5: Integration with Source System
**Objective:** Verify schedule alignment with source refresh schedule

**Test Steps:**
1. Check source system documentation for refresh schedule
2. Verify DAG schedule aligns with source schedule
3. Test with actual source system to confirm data availability timing

**Expected Result:** Job schedule should align with source refresh cycle

---

## Code Review Checklist

- [ ] Verify upstream data refresh frequency (should be documented)
- [ ] Check if schedule frequency matches upstream refresh rate
- [ ] Ensure upstream dependency validation exists
- [ ] Verify skip logic for unchanged upstream data
- [ ] Check for proper logging when skipping runs
- [ ] Validate cost implications of current schedule
- [ ] Review error handling for missing upstream data
- [ ] Check if incremental processing is feasible

---

## Recommended Actions

1. **Immediate:** Change schedule from `*/15 * * * *` to `0 * * * *` (hourly)
2. **Short-term:** Add upstream freshness check before processing
3. **Medium-term:** Implement incremental processing with last-run tracking
4. **Long-term:** Add monitoring/alerting for schedule mismatches

---

## References

- Airflow Schedule Interval Documentation
- Cost optimization best practices for scheduled jobs
- Upstream dependency management patterns

---

## Complete Source Code

### File 1: `airflow/dags/mattermost_dags/extract/engagement.py`

```python
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
```

### File 2: `extract/s3_extract/engagement_job.py`

```python
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
```

