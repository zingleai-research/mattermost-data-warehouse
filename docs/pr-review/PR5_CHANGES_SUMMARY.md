# PR #5: Changes Summary

## Brief Overview

This PR adds **NPS score calculation** and **MME customer filtering** to the `fct_nps_score` model. It adds 5 new calculated columns and updates 4 files.

## Changes Breakdown

### 1. **fct_nps_score.sql** (Main Changes - 52 lines added)
- **Added 5 new columns:**
  - `nps_score_daily`: Calculated NPS score using formula `((Promoters - Detractors) / Total) × 100`
  - `nps_score_last90d`: Rolling 90-day NPS score
  - `end_user_nps_score_daily`: NPS score for end users only (user_role = 'user')
  - `end_user_nps_score_last90d`: 90-day NPS score for end users
  - `is_mme_customer`: Boolean flag for MME/Enterprise customers
- **Added 2 new columns from join:**
  - `customer_tier`: Customer tier from dimension
  - `customer_company_name`: Company name from dimension
- **Added LEFT JOIN:**
  - Joined with `dim_latest_server_customer_info` to get customer information

### 2. **fct_nps_mme_customers.sql** (Updated - 15 lines changed)
- Updated to use `is_mme_customer` flag from `fct_nps_score` instead of separate join
- Added `nps_score_daily` and `end_user_nps_score_daily` columns

### 3. **fct_nps_looker_aggregated.sql** (Updated - 9 lines added)
- Added 4 new NPS score columns for Looker dashboard
- Added `is_mme_customer` flag for filtering

### 4. **rpt_nps_company_scorecard.sql** (Updated - 7 lines added)
- Added `nps_score_daily` and `nps_score_last90d` columns
- Added `is_mme_customer` flag for company scorecard filtering

## Key Business Logic

**NPS Score Formula:**
```
NPS = ((Promoters - Detractors) / Total Respondents) × 100
```

**MME Customer Identification:**
- `customer_tier IN ('MME', 'Enterprise', 'Strategic')` OR
- `sku IN ('professional', 'enterprise', 'e20', 'e30')`

## Impact (BREAKING CHANGES)

⚠️ **CRITICAL**: This PR introduces **breaking changes**. Downstream models will have compilation errors until this PR is merged:

- **rpt_nps_company_scorecard**: Will error with `Invalid column nps_score_daily`
- **fct_nps_mme_customers**: Will error with `Invalid column is_mme_customer`
- **fct_nps_looker_aggregated**: Will error with multiple `Invalid column` errors

**Pipeline Impact:**
- Daily pipelines will **FAIL** until PR is merged
- Looker dashboard refresh (every 15 min) will **FAIL** until PR is merged
- Company scorecard report will **FAIL** until PR is merged

**After PR is merged:**
- All downstream models will work with new columns
- 3 dashboards will benefit from pre-calculated NPS scores
- Company scorecard can filter by MME customers
- Looker dashboard gets "End Users" filter capability

## Files Changed: 4 files, 73 insertions, 11 deletions

