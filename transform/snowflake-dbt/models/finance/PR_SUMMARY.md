# PR Summary: Churn Recovery Classification

## 📋 Code Changes Summary

### Files Modified

1. **`account_monthly_arr_deltas_by_type.sql`** - Main model changes
2. **`README.md`** - Documentation of downstream models (new file)

### Key Changes to `account_monthly_arr_deltas_by_type.sql`

#### 1. Added Recovery Logic Calculation
- Introduced `monthly_data_with_recovery_check` CTE
- Added LEAD window functions to get next month's data:
  - `next_month_arr_delta` - ARR delta for next month
  - `next_month_start` - Start date of next month
- Calculated `has_recovery_within_30d` flag using:
  - Window functions to check if account recovered within 30 days
  - CASE statement evaluating: negative ARR delta + zero ending ARR + recovery within 30 days + positive next month delta

#### 2. Updated ARR Type Classification
- Added new ARR type: **'Churn with Recovery ARR'**
- Updated classification logic:
  - `'Churn with Recovery ARR'` - Accounts that churned but recovered within 30 days
  - `'Churn ARR'` - True churn (no recovery within 30 days)

#### 3. Added New Fields
- `total_arr_churn` - ARR delta for true churn (excludes recovery accounts)
- `total_arr_churn_with_recovery` - ARR delta for accounts with recovery

#### 4. Updated Configuration
- Added `operations_team` tag to model config

#### 5. Updated Grouping
- Changed GROUP BY to include `has_recovery_within_30d` to handle different recovery scenarios

### Impact on Data

**Before:**
- All churn accounts were classified as `'Churn ARR'`
- No distinction between true churn and recovery accounts

**After:**
- Churn accounts split into:
  - `'Churn ARR'` - True churn (no recovery within 30 days)
  - `'Churn with Recovery ARR'` - Accounts that recovered within 30 days
- Separate fields for `total_arr_churn` (true churn) and `total_arr_churn_with_recovery`
- Downstream reports will show lower churn rates (recovery accounts excluded)

---

## ⚠️ Optimization Suggestion

### Problem Statement

**The recovery logic calculation (`has_recovery_within_30d`) is currently implemented in this downstream model**, but it should be moved upstream to `account_monthly_arr_deltas` for better efficiency and reuse.

### Why This Matters

**Downstream models that need recovery logic would need to duplicate the same calculation:**

1. **`rpt_monthly_churn_summary`** - Would need to recalculate recovery logic to exclude recovery accounts from churn rates
2. **`fct_churn_analysis`** - Would need to repeat LEAD window functions to separate recovery from true churn
3. **`rpt_customer_retention_analysis`** - Would need recovery logic for retention metrics
4. **`fct_account_lifetime_value`** - Would need recovery logic to exclude recovery accounts from LTV calculations

### Current Implementation Issues

**Without upstream recovery logic:**
- ❌ **Performance**: LEAD window functions calculated 4+ times (once per model) instead of once
- ❌ **Maintenance**: Recovery logic changes require updates in 4+ places
- ❌ **Consistency Risk**: Different models might implement slightly different logic
- ❌ **Code Duplication**: Same CASE statement and LEAD functions repeated across models
- ❌ **Compute Cost**: Window functions are expensive - calculating them multiple times wastes resources

### Recommended Solution

**Move recovery logic to `account_monthly_arr_deltas` upstream model:**

1. Add `has_recovery_within_30d` field to `account_monthly_arr_deltas`
2. Calculate recovery logic once in upstream model
3. All downstream models reference the upstream field

**With upstream recovery logic:**
- ✅ **Performance**: Window functions calculated once in upstream model
- ✅ **Maintenance**: Recovery logic defined once, used everywhere
- ✅ **Consistency**: Single source of truth for recovery logic
- ✅ **Code Quality**: No duplication, clean and maintainable
- ✅ **Compute Efficiency**: Window functions calculated once, shared across models

### Example: Code Simplification

**Current (without upstream):**
```sql
-- Each downstream model needs this
WITH churn_base AS (
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
```

**Recommended (with upstream):**
```sql
-- Simply reference upstream field
SELECT *
FROM {{ ref('account_monthly_arr_deltas') }}
WHERE has_recovery_within_30d = 0  -- Use upstream field directly
```

### Reference Implementation

See `feature/add-recovery-logic-upstream` branch for the optimized implementation where:
- Recovery logic is added to `account_monthly_arr_deltas` 
- `account_monthly_arr_deltas_by_type` uses the upstream field instead of recalculating

### Documentation

See `README.md` for detailed examples of all downstream models that would benefit from upstream recovery logic.

