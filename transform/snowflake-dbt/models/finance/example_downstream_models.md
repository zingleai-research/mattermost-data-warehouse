# Example Downstream Models That Would Need Recovery Logic

## Models That Would Benefit from Upstream Recovery Logic

### 1. `rpt_monthly_churn_summary` (Churn Reporting)
**Current Issue:** Would need to recalculate recovery logic to exclude recovery accounts from churn

**If recovery logic is NOT upstream:**
```sql
-- Would need to repeat the same LEAD window function calculation
WITH churn_with_recovery_check AS (
    SELECT
        arr.*,
        LEAD(total_arr_delta, 1) OVER (
            PARTITION BY account_sfid 
            ORDER BY month_start
        ) as next_month_arr_delta,
        LEAD(month_start, 1) OVER (
            PARTITION BY account_sfid 
            ORDER BY month_start
        ) as next_month_start,
        -- DUPLICATE LOGIC: Same recovery calculation as in account_monthly_arr_deltas_by_type
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
SELECT * FROM churn_with_recovery_check
WHERE arr_type = 'Churn ARR'  -- Exclude recovery accounts
```

**If recovery logic IS upstream:**
```sql
-- Simply use the upstream field
SELECT * 
FROM {{ ref('account_monthly_arr_deltas') }}
WHERE month_ending_arr = 0 
  AND total_arr_delta < 0
  AND has_recovery_within_30d = 0  -- Use upstream field directly
```

---

### 2. `fct_churn_analysis` (Churn Analysis Fact Table)
**Current Issue:** Needs to identify recovery accounts separately from true churn

**If recovery logic is NOT upstream:**
```sql
-- Would need to repeat the same LEAD window function calculation
WITH churn_analysis AS (
    SELECT
        arr.*,
        -- DUPLICATE LOGIC: Same recovery calculation repeated
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
    *,
    CASE WHEN has_recovery_within_30d = 1 THEN 'Recovery' ELSE 'True Churn' END as churn_category
FROM churn_analysis
```

**If recovery logic IS upstream:**
```sql
-- Simply use the upstream field
SELECT 
    *,
    CASE WHEN has_recovery_within_30d = 1 THEN 'Recovery' ELSE 'True Churn' END as churn_category
FROM {{ ref('account_monthly_arr_deltas') }}
WHERE month_ending_arr = 0 AND total_arr_delta < 0
```

---

### 3. `rpt_customer_retention_analysis` (Hypothetical Retention Report)
**Current Issue:** Would need recovery logic to calculate retention metrics excluding recovery accounts

**If recovery logic is NOT upstream:**
```sql
-- Would need to repeat the same LEAD window function calculation
WITH retention_base AS (
    SELECT
        arr.*,
        -- DUPLICATE LOGIC: Same recovery calculation repeated again
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
    month_start,
    COUNT(DISTINCT CASE WHEN has_recovery_within_30d = 0 THEN account_sfid END) as true_churn_count,
    COUNT(DISTINCT CASE WHEN has_recovery_within_30d = 1 THEN account_sfid END) as recovery_count
FROM retention_base
GROUP BY month_start
```

**If recovery logic IS upstream:**
```sql
-- Simply use the upstream field
SELECT 
    month_start,
    COUNT(DISTINCT CASE WHEN has_recovery_within_30d = 0 THEN account_sfid END) as true_churn_count,
    COUNT(DISTINCT CASE WHEN has_recovery_within_30d = 1 THEN account_sfid END) as recovery_count
FROM {{ ref('account_monthly_arr_deltas') }}
WHERE month_ending_arr = 0 AND total_arr_delta < 0
GROUP BY month_start
```

---

## Summary

**Without upstream recovery logic:**
- Each downstream model must recalculate the same LEAD window functions
- Same CASE statement logic repeated 3+ times
- Performance impact: Window functions calculated multiple times
- Maintenance burden: Logic changes need to be updated in multiple places
- Risk of inconsistency: Different models might implement slightly different logic

**With upstream recovery logic:**
- Single calculation in `account_monthly_arr_deltas`
- All downstream models simply reference `has_recovery_within_30d` field
- Better performance: Window functions calculated once
- Single source of truth: Logic defined once, used everywhere
- Easier maintenance: Update logic in one place

