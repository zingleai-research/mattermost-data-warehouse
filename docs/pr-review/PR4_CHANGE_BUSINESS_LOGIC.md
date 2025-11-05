# PR #4: Change Business Logic for fct_active_users Filtering and Joins

**Branch:** `feature/change-active-users-business-logic`  
**PR Title:** Change business logic for fct_active_users filtering and joins  
**PR Number:** 4  
**Author:** @data_engineer  
**Status:** open  
**Created Date:** 2025-01-20 15:00:00  
**Labels:** `["enhancement", "dbt", "data-quality", "product", "business-logic"]`

## PR Description

This PR changes the business logic of the `fct_active_users` model to improve data quality by filtering out excludable servers at the fact table level and changing the join strategy. Previously, excludable servers were only filtered in downstream reports, which could lead to inconsistencies.

**Key Changes:**
- Filter out excludable servers at fact table level (previously only in downstream reports)
- Change from FULL OUTER JOIN to LEFT JOIN (only include servers with telemetry data)
- Add minimum threshold: only include servers with at least 1 active user
- Apply excludable server filter to both user telemetry and server telemetry sides

**Impact:**
This change improves data quality by excluding test servers, internal servers, and invalid data at the source level. However, it may reduce the number of rows in the fact table and could affect historical comparisons. Downstream reports like `rpt_active_user_base` may see different results.

---

## Files Changed

- `transform/mattermost-analytics/models/marts/product/fct_active_users.sql` (modified, 80 lines)

---

## Review Checklist

- [ ] Business logic changes reviewed
- [ ] Data quality impact assessed
- [ ] Downstream impact validated
- [ ] Historical comparison implications considered
- [ ] Excludable server logic verified

