# PR #2: User Engagement Report Model

**Branch:** `pr-user-engagement-report`  
**PR Title:** Added user engagement report model for dashboard

## Overview

This PR adds a new dbt model `fct_user_engagement_report` that provides comprehensive user engagement metrics for daily dashboard reporting. The model analyzes all user interaction events to calculate engagement scores, activity ranks, and server-level summaries.

## Optimization Issues

### Issue #1: Full Table Scan Without Date Filters

**Severity:** Critical  
**Cost Impact:** Very High  
**Performance Impact:** Very High

#### Problem
The query scans the entire `stg_mm_telemetry_prod__event` table without any date filters, even though this is for daily reporting. This causes:
- **Excessive compute costs**: Processing billions of historical events for daily reports
- **Slow query execution**: Full table scans can take hours or time out
- **High warehouse credit consumption**: Scanning entire event table is extremely expensive
- **Poor scalability**: Performance degrades as historical data grows

#### Targeted Code Locations

**File:** `transform/mattermost-analytics/models/marts/product/fct_user_engagement_report.sql`

- **Line 12-24:** `all_events` CTE selects all rows from `stg_mm_telemetry_prod__event` with no date filter
  ```sql
  from {{ ref('stg_mm_telemetry_prod__event') }}
  -- Missing: WHERE clause to filter by date
  ```

- **Line 26-43:** `user_activity` CTE aggregates all events without time constraints
- **Line 45-57:** `server_summary` CTE processes all user activity across all time
- **Line 59-70:** `event_category_summary` CTE summarizes events "across all time" (as noted in comment)

#### Optimization Suggestions

1. **Add Date Filter for Daily Reports**
   ```sql
   with all_events as (
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
       where DATE(received_at) = CURRENT_DATE() - 1  -- Yesterday's data for daily report
   ),
   ```

2. **Use Incremental Materialization**
   ```sql
   {{
       config({
           "materialized": "incremental",
           "unique_key": "server_id",
           "incremental_strategy": "merge",
           "description": "Daily user engagement report"
       })
   }}
   
   -- Then filter for incremental runs
   where received_at >= (select max(report_date) from {{ this }})
   ```

3. **Add Partitioning Strategy**
   ```sql
   {{
       config({
           "materialized": "table",
           "cluster_by": ['server_id', 'report_date'],
           "description": "Daily user engagement report"
       })
   }}
   ```

4. **Limit Historical Window**
   ```sql
   where DATE(received_at) >= CURRENT_DATE() - INTERVAL '90 DAYS'  -- Last 90 days only
   ```

#### Expected Cost Savings
- **Query Cost Reduction**: 95-99% reduction by filtering to recent data (e.g., last 30-90 days vs all history)
- **Execution Time**: Reduce from hours to minutes
- **Warehouse Credits**: Significant reduction in Snowflake compute usage

---

### Issue #2: Expensive Window Functions on Full Dataset

**Severity:** High  
**Cost Impact:** High  
**Performance Impact:** High

#### Problem
Multiple `ROW_NUMBER()` window functions are executed over the entire unfiltered dataset, which is extremely expensive:
- Window functions require sorting the entire dataset
- Multiple window functions compound the cost
- No optimization for large datasets

#### Targeted Code Locations

**File:** `transform/mattermost-analytics/models/marts/product/fct_user_engagement_report.sql`

- **Line 40-43:** `ROW_NUMBER()` window function partitions by server_id over all events
  ```sql
  ROW_NUMBER() OVER (
      PARTITION BY server_id 
      ORDER BY COUNT(*) DESC
  ) as user_activity_rank
  ```

- **Line 68-71:** Another `ROW_NUMBER()` window function on full event dataset
  ```sql
  ROW_NUMBER() OVER (
      PARTITION BY server_id 
      ORDER BY COUNT(*) DESC
  ) as category_rank
  ```

#### Optimization Suggestions

1. **Filter Before Window Functions**
   ```sql
   -- Apply date filter before window functions
   where DATE(received_at) = CURRENT_DATE() - 1
   ```

2. **Use LIMIT Instead of ROW_NUMBER() for Top-N**
   ```sql
   -- Instead of ROW_NUMBER and filtering to rank = 1, use QUALIFY
   select *
   from (
       select ...,
              ROW_NUMBER() OVER (PARTITION BY server_id ORDER BY COUNT(*) DESC) as rank
       from all_events
       where DATE(received_at) = CURRENT_DATE() - 1
       group by ...
   )
   qualify rank = 1
   ```

3. **Pre-aggregate Before Window Functions**
   ```sql
   -- Aggregate first, then apply window functions on smaller dataset
   with aggregated as (
       select server_id, user_id, count(*) as event_count
       from all_events
       where DATE(received_at) = CURRENT_DATE() - 1
       group by server_id, user_id
   )
   select *,
          ROW_NUMBER() OVER (PARTITION BY server_id ORDER BY event_count DESC) as rank
   from aggregated
   ```

#### Expected Performance Improvement
- **50-80% faster** window function execution on filtered data
- **Lower memory usage** for sorting operations
- **Better query plan** from optimizer on smaller datasets

---

### Issue #3: No Incremental Strategy

**Severity:** High  
**Cost Impact:** High  
**Performance Impact:** High

#### Problem
The model uses `materialized: table` which rebuilds the entire table on each run, even though daily reports only need incremental updates.

#### Targeted Code Locations

**File:** `transform/mattermost-analytics/models/marts/product/fct_user_engagement_report.sql`

- **Line 1-4:** Model config uses `materialized: "table"` instead of incremental
  ```sql
  {{
      config({
          "materialized": "table",  -- Should be "incremental"
          "description": "..."
      })
  }}
  ```

#### Optimization Suggestions

1. **Switch to Incremental Materialization**
   ```sql
   {{
       config({
           "materialized": "incremental",
           "unique_key": ["server_id", "report_date"],
           "incremental_strategy": "merge",
           "description": "Daily user engagement report"
       })
   }}
   ```

2. **Add Incremental Filter**
   ```sql
   where received_at >= (
       select coalesce(max(report_date), '1900-01-01'::date)
       from {{ this }}
   )
   ```

#### Expected Cost Savings
- **Daily runs**: Process only new data instead of full history
- **Rebuild time**: Reduce from hours to minutes
- **Storage**: More efficient table maintenance

---

### Issue #4: Multiple Expensive Aggregations on Large Dataset

**Severity:** Medium  
**Cost Impact:** Medium  
**Performance Impact:** Medium

#### Problem
Multiple CTEs perform heavy aggregations (COUNT, SUM, AVG, DISTINCT) on the entire unfiltered event table sequentially.

#### Targeted Code Locations

**File:** `transform/mattermost-analytics/models/marts/product/fct_user_engagement_report.sql`

- **Line 26-43:** `user_activity` performs COUNT(*), COUNT(DISTINCT ...), MIN, MAX, DATEDIFF on all events
- **Line 45-57:** `server_summary` performs COUNT(DISTINCT ...), SUM, AVG on all user_activity
- **Line 59-70:** `event_category_summary` performs COUNT, COUNT(DISTINCT ...) on all events again

#### Optimization Suggestions

1. **Combine Aggregations**
   ```sql
   -- Single pass aggregation instead of multiple CTEs
   with aggregated_metrics as (
       select
           server_id,
           user_id,
           category,
           count(*) as event_count,
           count(distinct event_name) as unique_events,
           min(timestamp) as first_event,
           max(timestamp) as last_event
       from {{ ref('stg_mm_telemetry_prod__event') }}
       where DATE(received_at) = CURRENT_DATE() - 1
       group by server_id, user_id, category
   )
   ```

2. **Use Approximate Functions for Large Datasets**
   ```sql
   -- If exact counts not critical
   APPROX_COUNT_DISTINCT(user_id) as active_users
   ```

---

## Test Cases

### Test Case 1: Date Filter Validation
**Objective:** Verify query includes appropriate date filters

**Test Steps:**
1. Review SQL query for WHERE clauses filtering by date
2. Check if model filters to recent data (e.g., last 30-90 days)
3. Verify date filters are applied at earliest CTE stage

**Expected Result:** Query should filter by date in `all_events` CTE

**Location:** `transform/mattermost-analytics/models/marts/product/fct_user_engagement_report.sql:12-24`

**Query:**
```sql
-- Should have date filter like:
where DATE(received_at) >= CURRENT_DATE() - INTERVAL '90 DAYS'
```

---

### Test Case 2: Full Table Scan Detection
**Objective:** Identify if query scans entire table without filters

**Test Steps:**
1. Run EXPLAIN PLAN on the query
2. Check for "Full Scan" or "Table Scan" in execution plan
3. Verify predicate pushdown is occurring

**Expected Result:** Query should use filtered scan, not full table scan

**Location:** `transform/mattermost-analytics/models/marts/product/fct_user_engagement_report.sql:12-24`

---

### Test Case 3: Window Function Performance
**Objective:** Measure performance of window functions on dataset size

**Test Steps:**
1. Measure query execution time with current full table scan
2. Run query with date filter limiting to last 30 days
3. Compare execution times and costs

**Expected Result:** Filtered query should be 10-100x faster

**Location:** 
- Line 40-43: `user_activity` CTE with ROW_NUMBER()
- Line 68-71: `event_category_summary` CTE with ROW_NUMBER()

---

### Test Case 4: Incremental Materialization Test
**Objective:** Verify incremental strategy is implemented

**Test Steps:**
1. Check model config for `materialized: incremental`
2. Verify `unique_key` is defined
3. Check for incremental filter logic
4. Test full refresh vs incremental run times

**Expected Result:** Model should use incremental materialization

**Location:** `transform/mattermost-analytics/models/marts/product/fct_user_engagement_report.sql:1-4`

---

### Test Case 5: Query Cost Estimation
**Objective:** Estimate cost difference between current and optimized query

**Test Steps:**
1. Run query with current implementation and note:
   - Execution time
   - Rows scanned
   - Warehouse credits used
2. Run optimized query with date filters and compare metrics
3. Calculate cost savings percentage

**Expected Result:** Should show 90%+ cost reduction with proper filters

---

### Test Case 6: Data Freshness Validation
**Objective:** Ensure report reflects appropriate time window

**Test Steps:**
1. Verify model documents what time period it covers
2. Check if "daily report" actually uses daily data or all-time data
3. Validate report date logic

**Expected Result:** Daily report should only include recent daily data

---

### Test Case 7: Partition/Cluster Key Optimization
**Objective:** Verify table uses appropriate clustering

**Test Steps:**
1. Check if model config includes `cluster_by` for common filter columns
2. Verify clustering columns match query filters (e.g., server_id, date)

**Expected Result:** Table should be clustered by commonly filtered columns

**Location:** Model config section

---

### Test Case 8: Cardinality Validation
**Objective:** Check if aggregations are optimized for dataset size

**Test Steps:**
1. Measure distinct values in grouped columns
2. Check if COUNT(DISTINCT) is necessary vs COUNT
3. Verify aggregations don't cause memory issues

**Expected Result:** Aggregations should be optimized for actual data patterns

---

## Code Review Checklist

- [ ] Verify date filters exist in query (especially first CTE)
- [ ] Check if model uses incremental materialization
- [ ] Review window function usage on filtered vs unfiltered data
- [ ] Validate query execution plan for table scans
- [ ] Check for proper clustering/partitioning configuration
- [ ] Review aggregation strategy for performance
- [ ] Verify model description matches actual time window
- [ ] Check for opportunities to combine CTEs
- [ ] Review DISTINCT operations for optimization opportunities
- [ ] Validate cost implications of current approach

---

## Recommended Actions

1. **Critical:** Add date filter to `all_events` CTE (e.g., last 90 days)
2. **Critical:** Switch to incremental materialization strategy
3. **High Priority:** Apply filters before window functions
4. **High Priority:** Add clustering by server_id and date
5. **Medium Priority:** Optimize aggregation CTEs
6. **Medium Priority:** Consider approximate functions for large counts

---

## Performance Benchmarks

### Current Implementation (Full Table Scan)
- **Rows Scanned**: ~10+ billion events (all history)
- **Execution Time**: 2-4 hours (may timeout)
- **Cost**: Very High (~$50-200 per run depending on warehouse size)

### Optimized Implementation (With Filters)
- **Rows Scanned**: ~100 million events (last 90 days)
- **Execution Time**: 5-15 minutes
- **Cost**: Low (~$2-5 per run)
- **Cost Savings**: 90-95% reduction

---

## References

- [dbt Incremental Models Documentation](https://docs.getdbt.com/docs/build/incremental-models)
- [Snowflake Query Performance Best Practices](https://docs.snowflake.com/en/user-guide/query-performance.html)
- [Window Functions Performance Optimization](https://docs.snowflake.com/en/sql-reference/functions-analytical.html)
- Cost optimization strategies for data warehouse queries

---

## Complete Source Code

### File 1: `transform/mattermost-analytics/models/marts/product/fct_user_engagement_report.sql`

```sql
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
```

### File 2: `transform/mattermost-analytics/models/marts/product/_product__models.yml` (Relevant Section)

```yaml
  - name: fct_user_engagement_report
    description: |
      Daily user engagement report aggregating all user activity events for dashboard reporting.
      Provides comprehensive engagement metrics including user activity ranks, event categories,
      and server-level engagement scores.
    columns:
      - name: server_id
        description: The server's unique id.
        tests:
          - not_null
      - name: total_active_users
        description: Total number of active users on the server.
      - name: total_server_events
        description: Total number of events across all users on the server.
      - name: server_event_types
        description: Total number of unique event types on the server.
      - name: avg_user_activity_span
        description: Average activity span in hours across users.
      - name: engagement_score
        description: Weighted engagement score calculated from events and activity span.
      - name: top_user_id
        description: User ID with the highest engagement rank.
      - name: top_user_events
        description: Total events for the top engaged user.
      - name: user_activity_rank
        description: Activity rank of the top user (1 = most active).
      - name: top_event_category
        description: Most popular event category on the server.
      - name: top_category_events
        description: Event count for the top category.
      - name: category_rank
        description: Rank of the top event category (1 = most popular).
```

