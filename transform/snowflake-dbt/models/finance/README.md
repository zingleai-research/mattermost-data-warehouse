# Churn Recovery Classification - PR Documentation

## Overview

This PR adds churn recovery classification with a 30-day grace period to `account_monthly_arr_deltas_by_type`. The recovery logic identifies accounts that churned (ARR = 0) but recovered within 30 days, classifying them as 'Churn with Recovery ARR' instead of true churn.

## Current Implementation

**Recovery logic is calculated in this downstream model** (`account_monthly_arr_deltas_by_type`) using LEAD window functions:

```sql
-- Lines 27-38 in account_monthly_arr_deltas_by_type.sql
CASE
    WHEN total_arr_delta < 0 
        AND month_ending_arr = 0 
        AND LEAD(month_start, 1) OVER (...) IS NOT NULL
        AND DATEDIFF(day, month_end, LEAD(month_start, 1) OVER (...)) <= 30
        AND LEAD(total_arr_delta, 1) OVER (...) > 0
    THEN 1 ELSE 0
END as has_recovery_within_30d
```

## Problem: Logic Duplication Required

**This recovery logic calculation needs to be repeated in multiple downstream models** that need to identify or exclude recovery accounts. Each model would need to:

1. Add LEAD window functions to get next month's data
2. Replicate the same CASE statement logic
3. Calculate the same recovery flag

### Downstream Models That Would Need This Logic

#### 1. `rpt_monthly_churn_summary` (Monthly Churn Reporting)

**Purpose:** Generate monthly churn reports excluding recovery accounts from true churn calculations.

**Would need to repeat:**
```sql
WITH churn_with_recovery_check AS (
    SELECT
        arr.*,
        -- DUPLICATE: Same LEAD window functions
        LEAD(total_arr_delta, 1) OVER (
            PARTITION BY account_sfid 
            ORDER BY month_start
        ) as next_month_arr_delta,
        LEAD(month_start, 1) OVER (
            PARTITION BY account_sfid 
            ORDER BY month_start
        ) as next_month_start,
        -- DUPLICATE: Same recovery calculation logic
        CASE
            WHEN total_arr_delta < 0 
                AND month_ending_arr = 0 
                AND LEAD(month_start, 1) OVER (...) IS NOT NULL
                AND DATEDIFF(day, month_end, LEAD(month_start, 1) OVER (...)) <= 30
                AND LEAD(total_arr_delta, 1) OVER (...) > 0
            THEN 1 ELSE 0
        END as has_recovery_within_30d
    FROM {{ ref('account_monthly_arr_deltas') }}
)
SELECT 
    month_start,
    customer_tier,
    SUM(ABS(total_arr_churn)) as churn_arr,
    SUM(month_starting_arr) as starting_arr,
    (SUM(ABS(total_arr_churn)) / SUM(month_starting_arr)) * 100 as churn_rate_pct
FROM churn_with_recovery_check
WHERE has_recovery_within_30d = 0  -- Exclude recovery accounts
GROUP BY month_start, customer_tier
```

**If recovery logic was upstream:**
```sql
-- Simply use upstream field - no window functions needed
SELECT 
    month_start,
    customer_tier,
    SUM(ABS(total_arr_delta)) as churn_arr,
    SUM(month_starting_arr) as starting_arr,
    (SUM(ABS(total_arr_delta)) / SUM(month_starting_arr)) * 100 as churn_rate_pct
FROM {{ ref('account_monthly_arr_deltas') }}
WHERE month_ending_arr = 0 
  AND total_arr_delta < 0
  AND has_recovery_within_30d = 0  -- Use upstream field
GROUP BY month_start, customer_tier
```

---

#### 2. `fct_churn_analysis` (Churn Analysis Fact Table)

**Purpose:** Detailed churn analysis that separates recovery accounts from true churn for deeper insights.

**Would need to repeat:**
```sql
WITH churn_analysis_base AS (
    SELECT
        arr.*,
        -- DUPLICATE: Same LEAD window functions again
        LEAD(total_arr_delta, 1) OVER (...) as next_month_arr_delta,
        LEAD(month_start, 1) OVER (...) as next_month_start,
        -- DUPLICATE: Same recovery calculation logic again
        CASE
            WHEN total_arr_delta < 0 
                AND month_ending_arr = 0 
                AND LEAD(month_start, 1) OVER (...) IS NOT NULL
                AND DATEDIFF(day, month_end, LEAD(month_start, 1) OVER (...)) <= 30
                AND LEAD(total_arr_delta, 1) OVER (...) > 0
            THEN 1 ELSE 0
        END as has_recovery_within_30d
    FROM {{ ref('account_monthly_arr_deltas') }}
)
SELECT 
    account_sfid,
    month_start,
    CASE WHEN has_recovery_within_30d = 1 THEN 'Recovery' ELSE 'True Churn' END as churn_category,
    total_arr_delta,
    ABS(total_arr_delta) as churn_amount
FROM churn_analysis_base
WHERE month_ending_arr = 0 AND total_arr_delta < 0
```

**If recovery logic was upstream:**
```sql
-- Simply use upstream field - no calculations needed
SELECT 
    account_sfid,
    month_start,
    CASE WHEN has_recovery_within_30d = 1 THEN 'Recovery' ELSE 'True Churn' END as churn_category,
    total_arr_delta,
    ABS(total_arr_delta) as churn_amount
FROM {{ ref('account_monthly_arr_deltas') }}
WHERE month_ending_arr = 0 AND total_arr_delta < 0
```

---

#### 3. `rpt_customer_retention_analysis` (Customer Retention Reports)

**Purpose:** Analyze customer retention patterns, tracking both true churn and recovery separately.

**Would need to repeat:**
```sql
WITH retention_base AS (
    SELECT
        arr.*,
        -- DUPLICATE: Same LEAD window functions repeated for third time
        LEAD(total_arr_delta, 1) OVER (...) as next_month_arr_delta,
        LEAD(month_start, 1) OVER (...) as next_month_start,
        -- DUPLICATE: Same recovery calculation logic repeated for third time
        CASE
            WHEN total_arr_delta < 0 
                AND month_ending_arr = 0 
                AND LEAD(month_start, 1) OVER (...) IS NOT NULL
                AND DATEDIFF(day, month_end, LEAD(month_start, 1) OVER (...)) <= 30
                AND LEAD(total_arr_delta, 1) OVER (...) > 0
            THEN 1 ELSE 0
        END as has_recovery_within_30d
    FROM {{ ref('account_monthly_arr_deltas') }}
)
SELECT 
    month_start,
    COUNT(DISTINCT CASE WHEN has_recovery_within_30d = 0 THEN account_sfid END) as true_churn_count,
    COUNT(DISTINCT CASE WHEN has_recovery_within_30d = 1 THEN account_sfid END) as recovery_count,
    COUNT(DISTINCT account_sfid) as total_churn_count
FROM retention_base
WHERE month_ending_arr = 0 AND total_arr_delta < 0
GROUP BY month_start
```

**If recovery logic was upstream:**
```sql
-- Simply use upstream field - clean and simple
SELECT 
    month_start,
    COUNT(DISTINCT CASE WHEN has_recovery_within_30d = 0 THEN account_sfid END) as true_churn_count,
    COUNT(DISTINCT CASE WHEN has_recovery_within_30d = 1 THEN account_sfid END) as recovery_count,
    COUNT(DISTINCT account_sfid) as total_churn_count
FROM {{ ref('account_monthly_arr_deltas') }}
WHERE month_ending_arr = 0 AND total_arr_delta < 0
GROUP BY month_start
```

---

#### 4. `fct_account_lifetime_value` (Account Lifetime Value Analysis)

**Purpose:** Calculate account lifetime value, excluding recovery accounts from true churn calculations to get accurate LTV metrics.

**Would need to repeat:**
```sql
-- DUPLICATE: Same LEAD window functions for fourth time
-- DUPLICATE: Same recovery calculation logic for fourth time
WITH ltv_base AS (
    SELECT
        arr.*,
        LEAD(total_arr_delta, 1) OVER (...) as next_month_arr_delta,
        LEAD(month_start, 1) OVER (...) as next_month_start,
        CASE
            WHEN total_arr_delta < 0 
                AND month_ending_arr = 0 
                AND LEAD(month_start, 1) OVER (...) IS NOT NULL
                AND DATEDIFF(day, month_end, LEAD(month_start, 1) OVER (...)) <= 30
                AND LEAD(total_arr_delta, 1) OVER (...) > 0
            THEN 1 ELSE 0
        END as has_recovery_within_30d
    FROM {{ ref('account_monthly_arr_deltas') }}
)
SELECT 
    account_sfid,
    -- Calculate LTV excluding recovery accounts from churn
    SUM(CASE WHEN has_recovery_within_30d = 0 AND total_arr_delta < 0 
        THEN ABS(total_arr_delta) ELSE 0 END) as true_churn_ltv_impact
FROM ltv_base
GROUP BY account_sfid
```

**If recovery logic was upstream:**
```sql
-- Simply use upstream field
SELECT 
    account_sfid,
    SUM(CASE WHEN has_recovery_within_30d = 0 AND total_arr_delta < 0 
        THEN ABS(total_arr_delta) ELSE 0 END) as true_churn_ltv_impact
FROM {{ ref('account_monthly_arr_deltas') }}
GROUP BY account_sfid
```

---

## Impact Summary

### Without Upstream Recovery Logic (Current Approach)

| Model | Duplicate Window Functions | Duplicate CASE Logic | Performance Impact |
|-------|---------------------------|---------------------|-------------------|
| `account_monthly_arr_deltas_by_type` | ✅ (current PR) | ✅ | Window functions calculated |
| `rpt_monthly_churn_summary` | ❌ Would need | ❌ Would need | Window functions recalculated |
| `fct_churn_analysis` | ❌ Would need | ❌ Would need | Window functions recalculated |
| `rpt_customer_retention_analysis` | ❌ Would need | ❌ Would need | Window functions recalculated |
| `fct_account_lifetime_value` | ❌ Would need | ❌ Would need | Window functions recalculated |

**Problems:**
- ❌ **Performance**: LEAD window functions calculated 4+ times instead of once
- ❌ **Maintenance**: Recovery logic changes need updates in 4+ places
- ❌ **Consistency Risk**: Different models might implement slightly different logic
- ❌ **Code Duplication**: Same CASE statement and LEAD functions repeated 4+ times
- ❌ **Compute Cost**: Window functions are expensive - calculating them multiple times wastes resources

### With Upstream Recovery Logic (Recommended Approach)

| Model | Uses Upstream Field | Complexity | Performance |
|-------|-------------------|-----------|-------------|
| `account_monthly_arr_deltas_by_type` | ✅ | Simple reference | No window functions needed |
| `rpt_monthly_churn_summary` | ✅ | Simple reference | No window functions needed |
| `fct_churn_analysis` | ✅ | Simple reference | No window functions needed |
| `rpt_customer_retention_analysis` | ✅ | Simple reference | No window functions needed |
| `fct_account_lifetime_value` | ✅ | Simple reference | No window functions needed |

**Benefits:**
- ✅ **Performance**: Window functions calculated once in upstream model
- ✅ **Maintenance**: Recovery logic defined once, used everywhere
- ✅ **Consistency**: Single source of truth for recovery logic
- ✅ **Code Quality**: No duplication, clean and maintainable
- ✅ **Compute Efficiency**: Window functions calculated once, shared across models

## Recommendation

**Move recovery logic upstream to `account_monthly_arr_deltas`** as a `has_recovery_within_30d` field. This enables all downstream models to:
1. Reference the upstream field instead of recalculating
2. Benefit from consistent recovery logic
3. Avoid performance overhead of duplicate window function calculations
4. Simplify maintenance with single source of truth

**See `feature/add-recovery-logic-upstream` branch for reference implementation.**

