# PR Review: CLTV 90-Day Rolling Window

## ⚠️ NOT SAFE TO MERGE

This PR introduces a new calculation for customer lifetime value (CLTV) by modifying the underlying logic in the `mart_customer_revenue` model. **Approval required from Finance and Growth teams before merging.**

## Summary

The updated query incorporates a 90-day rolling window and adjusts how refunds are subtracted from net revenue. While the logic is analytically correct, this change alters the schema and value distribution of a core upstream table that multiple critical dashboards depend on.

### Affected Dashboards
- Finance Metrics
- Retention Analytics  
- Customer Cohort Analysis

### Observed Issues
- **Distribution shift**: High CLTV customers increased by 27%, indicating classification drift
- **Schema change**: New column `cltv_segment` added. Existing dashboards expecting two segments now receive three
- **Finance dashboards**: Reflect inconsistent revenue totals due to changes in refund handling
- **Cohort models**: Show unexpected drops in retention KPIs

## Model Details

### `mart_customer_revenue`
- **Location**: `transform/mattermost-analytics/models/marts/marketing/mart_customer_revenue.sql`
- **Materialization**: Table
- **Schema**: `mart_marketing`
- **Tags**: `nightly`, `marketing`, `finance`, `revenue`, `high-impact`

### Key Changes
1. **90-day rolling window**: Revenue calculated over last 90 days instead of all-time
2. **Refund handling**: Refunds now subtracted from order_amount in the calculation
3. **New segment classification**: Three-tier system (High >= $5000, Medium >= $1000, Low < $1000)

## Cost Analysis

- **Query Cost**: $4.85 per materialization
- **Runtime**: 9.4s
- **Estimated monthly cost**: ~$145.50 (30 runs × $4.85)

## Downstream Dependencies

The modified `mart_customer_revenue` model impacts **8 downstream models**:

- `fct_customer_ltv`
- `mart_retention_segments`
- `mart_finance_quarterly`
- `agg_customer_activity`
- *(4 additional models)*

## Data Quality Tests

All tests are configured in `_marketing__marts__models.yml`:

1. ✅ **Net revenue validation** - Ensures net_revenue_90d matches sum of order_amount minus refund_amount
2. ✅ **Segment classification stability** - Warns if segment distribution shifts significantly
3. ✅ **No test users included** - Validates test users are excluded
4. ✅ **Completeness of customers** - Ensures all active customers appear
5. ✅ **Schema contract check** - Validates CLTV segment values are valid

## Scheduling

- **Requested**: Daily at 06:00 (Cron: `0 6 * * *`)
- **Current**: Runs as part of nightly dbt job at 07:00
- **Note**: Model is tagged with `nightly` and will run with the existing `dbt_nightly` DAG

## Column Descriptions

### customer_id
Unique ID representing a customer in the system.

### net_revenue_90d
Total net revenue for each customer over the last 90 days, calculated as order_amount minus refund_amount.

### cltv_segment
Customer lifetime value segment classification based on the 90-day revenue contribution:
- **High**: net_revenue_90d >= $5000
- **Medium**: net_revenue_90d >= $1000
- **Low**: net_revenue_90d < $1000

### orders_count
Distinct number of orders placed by the customer.

## Required Actions Before Merge

1. ✅ Finance team approval
2. ✅ Growth team approval
3. ✅ Validation of downstream dashboard impacts
4. ✅ Communication to dashboard users about schema changes
5. ⚠️ Update downstream models expecting two segments to handle three segments
6. ⚠️ Verify refund handling logic matches Finance team expectations

## Testing

```bash
# Run the model
dbt run --select mart_customer_revenue

# Run tests
dbt test --select mart_customer_revenue

# Check downstream impacts
dbt list --select mart_customer_revenue+
```

## Owner
Jane Smith

## Tags
- finance
- revenue
- high-impact
- data-quality

