# PR6: Update Churn Formula with 30-Day Grace Period - Demo Summary

## Quick Overview

**PR Title:** Update Churn Formula with 30-Day Grace Period  
**Target Model:** `account_monthly_arr_deltas_by_type.sql`  
**Change Type:** Business Metric Formula Change  
**Impact:** 1 Direct Model + 2 Downstream Models

## Business Context

The current churn formula counts all accounts with zero ending ARR as churn, even if they recover within 30 days. This PR implements a 30-day grace period to separate temporary churn from permanent churn, providing more accurate finance metrics.

## Key Changes

1. **Churn Logic Update**: Accounts with recovery within 30 days → "Churn with Recovery ARR"
2. **New Column**: `total_arr_churn_with_recovery` added
3. **Formula Change**: `total_arr_churn` now excludes accounts with recovery

## Impact Analysis

### Directly Affected (1 model)
- **account_monthly_arr_deltas_by_type**: Formula change, new column added

### Downstream Affected (2 models)
1. **rpt_monthly_churn_summary** - Distribution change
   - Churn values decrease (accounts with recovery excluded)
   - Churn rates recalculate lower
   - No breaking errors, but metrics change

2. **fct_churn_analysis** - New column handling
   - References `total_arr_churn_with_recovery` (doesn't exist in base)
   - **Compilation error** until PR is merged
   - Breaking change

## Test Coverage

- **8 Existing Test Cases**: Data quality, business logic, edge cases
- **4 Suggested Test Cases**: Grace period validation, recovery classification, distribution validation, new column validation

## Optimization Opportunities

- **3 Optimization Suggestions**: Window function optimization (40-60% improvement), incremental materialization, date range filtering

## Files Structure

```
docs/pr-review/
├── PR6_UPDATE_CHURN_FORMULA.md      # Main PR description
├── PR6_OPTIMIZATIONS.json            # 3 optimization suggestions
├── PR6_TEST_CASES.json               # 8 existing + 4 suggested tests
├── PR6_IMPACT_ANALYSIS.json          # Impact analysis with lineage
├── PR6_LOGIC_REVIEW.json             # Chatbot conversation examples
└── PR6_SUMMARY.md                    # This file
```

## Demo Platform Integration

### Tab: Optimizations
- **File:** `PR6_OPTIMIZATIONS.json`
- **Count:** 3 suggestions
- **Focus:** Performance improvements for grace period logic

### Tab: Test Cases
- **File:** `PR6_TEST_CASES.json`
- **Existing:** 8 test cases
- **Suggested:** 4 test cases
- **Focus:** Grace period validation, recovery classification

### Tab: Impact Analysis
- **File:** `PR6_IMPACT_ANALYSIS.json`
- **Lineage:** 3 models (1 direct + 2 downstream)
- **Impact Types:** 
  - Distribution change (rpt_monthly_churn_summary)
  - New column handling (fct_churn_analysis)
- **Breaking Changes:** 1 model (fct_churn_analysis)

### Tab: Logic Review
- **File:** `PR6_LOGIC_REVIEW.json`
- **Conversations:** 6 chatbot conversations
- **Topics:** Grace period logic, downstream impact, testing, performance

## Key Metrics for Demo

- **Churn Rate Change**: Will decrease (more accurate metrics)
- **Compilation Errors**: 1 model (fct_churn_analysis)
- **Distribution Changes**: Churn values decrease across segments
- **Performance Impact**: 40-60% improvement with optimization
- **Cost Savings**: $28-45 per run with optimizations

## Demo Talking Points

1. **Business Impact**: Real-world scenario where churn formula affects finance reporting
2. **Formula Validation**: Test cases validate grace period logic
3. **Downstream Impact**: Shows both distribution changes and breaking changes
4. **Performance**: Optimization opportunities for window functions
5. **Data Quality**: Comprehensive test coverage for new business logic

## Next Steps for Implementation

1. Create base branch `feature/churn-downstream-models` with 2 downstream models
2. Create PR branch `feature/update-churn-formula-grace-period`
3. Modify `account_monthly_arr_deltas_by_type.sql` with new logic
4. Update `fct_churn_analysis.sql` to reference new column
5. All PR documentation files are ready in `docs/pr-review/`

