# PR #3: Add Engagement Rate Calculations and New Aggregations

**Branch:** `feature/add-engagement-metrics-calculations`  
**PR Title:** Add engagement rate calculations and new aggregations to fct_active_users  
**PR Number:** 3  
**Author:** @data_engineer  
**Status:** open  
**Created Date:** 2025-01-20 14:00:00  
**Labels:** `["feature", "dbt", "analytics", "product", "calculations"]`

## PR Description

This PR adds new calculated metrics and aggregations to the `fct_active_users` model to provide additional insights into user engagement patterns. The new metrics include engagement rates, retention ratios, and platform-level aggregations.

**Key Changes:**
- Add `daily_engagement_rate_pct`: percentage of registered users active daily
- Add `monthly_engagement_rate_pct`: percentage of registered users active monthly  
- Add `weekly_to_daily_ratio`: ratio of weekly to daily active users
- Add `monthly_to_daily_ratio`: ratio of monthly to daily active users
- Add `avg_platform_active_users`: average across desktop and webapp
- Add `total_daily_active_users_all_platforms`: sum across all platforms

**Impact:**
These new calculated metrics enable product teams to better understand engagement patterns, retention rates, and platform distribution. The metrics are computed at the server-date level and can be used for trend analysis and dashboard reporting.

---

## Files Changed

- `transform/mattermost-analytics/models/marts/product/fct_active_users.sql` (modified, 100 lines)

---

## Review Checklist

- [ ] SQL calculations reviewed for accuracy
- [ ] Division by zero checks verified
- [ ] Data quality tests defined for new columns
- [ ] Downstream impact assessed
- [ ] Business logic validated

