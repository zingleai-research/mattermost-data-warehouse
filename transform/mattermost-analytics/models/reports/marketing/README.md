# Growth Dashboard - 30-Day Revenue by Customer Segment

## Overview

This report provides optimized 30-day revenue metrics by customer segment for the Growth dashboard. It replaces direct queries against raw tables with a curated mart approach for better performance and reliability.

## Models

### `mart_orders_enriched`
Curated mart table that combines orders and customer data, pre-filtering to completed/fulfilled orders and excluding test users. This replaces the need to join `raw_orders` and `raw_customers` in downstream queries.

**Location:** `transform/mattermost-analytics/models/marts/marketing/mart_orders_enriched.sql`

### `rpt_30day_revenue_by_segment`
Optimized report query that:
- Uses `mart_orders_enriched` instead of raw tables
- Filters to last 30 days using `order_date` (aligned with realised revenue)
- Excludes test users
- Aggregates revenue by customer segment

**Location:** `transform/mattermost-analytics/models/reports/marketing/rpt_30day_revenue_by_segment.sql`

## Data Quality Tests

The following tests are configured:

1. **Non-negative revenue** - Ensures revenue values are never negative
2. **No test users** - Validates that test users are excluded from results
3. **At least one active segment** - Warns if no segments have data
4. **Data freshness** - Ensures data is updated within the last 24 hours

## Scheduling

The models are tagged with `nightly` and `marketing`, which means they will be included in the nightly dbt run scheduled at 7:00 AM via the `dbt_nightly` Airflow DAG.

### Airflow DAG
- **DAG Name:** `dbt_nightly`
- **Schedule:** `0 7 * * *` (7:00 AM daily)
- **Location:** `airflow/dags/mattermost_dags/transformation/dbt_nightly.py`

The models will run as part of the nightly dbt cloud job (Job ID: 254981) after upstream data has landed.

## Setup Instructions

1. **Update Source References:**
   - Update `mart_orders_enriched.sql` to reference the correct source tables
   - Create source definitions in `models/staging/orders/_orders__sources.yml` and `models/staging/customers/_customers__sources.yml` if needed

2. **Verify Column Names:**
   - Ensure column names in `mart_orders_enriched.sql` match your actual source tables
   - Update `customer_segment` field mapping if your segmentation logic differs

3. **Test Execution:**
   ```bash
   dbt run --select mart_orders_enriched rpt_30day_revenue_by_segment
   dbt test --select mart_orders_enriched rpt_30day_revenue_by_segment
   ```

## Expected Impact

- **Lower warehouse cost** - Date filter and reduced column set reduce query costs
- **Faster runs** - Curated mart eliminates repeated joins
- **More reliable revenue numbers** - Test users excluded automatically
- **Better long-term reliability** - Automated tests catch data quality issues early

## Dependencies

- Upstream data must be available in `raw_orders` and `raw_customers` tables
- Models run as part of nightly dbt job after upstream data extraction completes

