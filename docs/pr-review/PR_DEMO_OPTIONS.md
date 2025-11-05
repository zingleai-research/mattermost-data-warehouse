# PR Demo Options - Business Logic Changes

This document provides options for creating demo PRs with different types of business logic changes. Each option includes the file to modify, the type of change, and what it demonstrates.

## Categories of Business Logic Changes

### 1. **Filtering & Exclusion Logic Changes**

#### Option A: Modify Server Size Binning Logic
**File:** `transform/mattermost-analytics/models/marts/product/fct_active_servers.sql`
**Current Logic:** Lines 11-20 - Bins servers by registered active users (e.g., '< 10', '10-100', etc.)
**Change Options:**
- Change bin thresholds (e.g., make bins larger: '< 50', '50-500', '500-5000')
- Add new bins for enterprise customers (e.g., '5000-10000', '10000+')
- Change binning strategy (e.g., use log scale instead of linear)
- Add filtering to exclude servers below certain threshold

**Demo Value:**
- Shows impact on downstream reports that use these bins
- Demonstrates data quality changes
- Shows business logic validation needs

---

#### Option B: Modify Excludable Server Filtering
**File:** `transform/mattermost-analytics/models/reports/product/active_user_base/rpt_active_user_base.sql`
**Current Logic:** Lines 22-29 - Filters out excludable servers
**Change Options:**
- Remove excludable server filtering (include all servers)
- Add additional filtering criteria (e.g., exclude servers older than X days)
- Change filtering to allow certain types of excludable servers
- Add minimum activity threshold for inclusion

**Demo Value:**
- Shows high impact on downstream dashboards
- Demonstrates data quality implications
- Shows business logic changes affecting report outputs

---

### 2. **Aggregation & Calculation Changes**

#### Option C: Change NPS Score Calculation
**File:** `transform/mattermost-analytics/models/marts/product/nps/fct_nps_score.sql`
**Current Logic:** Lines 84-91 - Aggregates promoters, detractors, passives by role
**Change Options:**
- Change aggregation method (e.g., weighted average instead of sum)
- Add new role-based calculations (e.g., separate admin vs user NPS)
- Modify NPS calculation formula (e.g., change promoter/detractor thresholds)
- Add time-based NPS calculations (e.g., rolling 30-day vs 90-day)

**Demo Value:**
- Shows calculation logic changes
- Demonstrates impact on NPS reporting
- Shows business metric definition changes

---

#### Option D: Modify Feature Activity Aggregation
**File:** `transform/mattermost-analytics/models/marts/product/features/fct_feature_daily_snapshot.sql`
**Current Logic:** Lines 38-40 - Uses SUM aggregation for feature metrics
**Change Options:**
- Change from SUM to COUNT DISTINCT (unique users vs total events)
- Add percentage calculations (e.g., feature adoption rate)
- Change aggregation window (e.g., weekly instead of daily)
- Add filtering to exclude inactive features

**Demo Value:**
- Shows aggregation logic changes
- Demonstrates impact on feature analytics
- Shows calculation accuracy considerations

---

### 3. **Join Strategy & Data Source Changes**

#### Option E: Change Join Strategy in Reports
**File:** `transform/mattermost-analytics/models/reports/product/active_user_base/rpt_active_user_base.sql`
**Current Logic:** Lines 90-97 - Multiple LEFT JOINs
**Change Options:**
- Change LEFT JOIN to INNER JOIN (exclude servers without certain data)
- Add new joins (e.g., join with license information)
- Remove certain joins (e.g., remove OAuth info join)
- Change join order/optimization

**Demo Value:**
- Shows join logic changes
- Demonstrates performance implications
- Shows data completeness trade-offs

---

#### Option F: Modify Server Info Join Logic
**File:** `transform/mattermost-analytics/models/marts/product/fct_active_servers.sql`
**Current Logic:** Line 37 - LEFT JOIN with license data
**Change Options:**
- Change to INNER JOIN (require license data)
- Add filtering before join (e.g., only join active licenses)
- Add multiple joins (e.g., join with customer info)
- Change join condition (e.g., join on installation_id instead of server_id)

**Demo Value:**
- Shows join strategy changes
- Demonstrates data quality filtering
- Shows business logic for data inclusion

---

### 4. **Time Window & Date Logic Changes**

#### Option G: Change Date Range Filtering
**File:** `transform/mattermost-analytics/models/reports/product/active_user_base/rpt_active_user_base.sql`
**Current Logic:** Line 26 - Filters to last 30 days
**Change Options:**
- Change from 30 days to 60 days or 90 days
- Add date range parameters (make configurable)
- Change from fixed window to rolling window
- Add exclusion of recent dates (e.g., exclude last 2 days for data quality)

**Demo Value:**
- Shows temporal business logic changes
- Demonstrates impact on report freshness
- Shows data quality considerations

---

#### Option H: Modify Activity Date Logic
**File:** `transform/mattermost-analytics/models/marts/product/features/fct_feature_daily_snapshot.sql`
**Current Logic:** Lines 11-21 - Uses date spine for server date ranges
**Change Options:**
- Change date spine logic (e.g., use last active date instead of max)
- Add date filtering (e.g., only include dates with activity)
- Change date range calculation (e.g., use 90-day window instead of all-time)
- Modify date aggregation (e.g., weekly instead of daily)

**Demo Value:**
- Shows date logic changes
- Demonstrates impact on historical analysis
- Shows temporal aggregation changes

---

### 5. **Threshold & Minimum Value Changes**

#### Option I: Change User Bucket Thresholds
**File:** `transform/mattermost-analytics/models/reports/product/active_user_base/rpt_active_user_base.sql`
**Current Logic:** Lines 13-17 - MAU buckets: '< 50', '50-500', '500-1000', '>= 1000'
**Change Options:**
- Change bucket thresholds (e.g., '< 100', '100-1000', '1000-5000', '>= 5000')
- Add more granular buckets (e.g., add '100-250', '250-500', etc.)
- Change bucket logic (e.g., use logarithmic buckets)
- Add filtering to exclude certain buckets

**Demo Value:**
- Shows threshold changes
- Demonstrates impact on customer segmentation
- Shows business definition changes

---

#### Option J: Add Minimum Activity Thresholds
**File:** `transform/mattermost-analytics/models/marts/product/fct_active_servers.sql`
**Current Logic:** No minimum threshold filtering
**Change Options:**
- Add minimum active users threshold (e.g., only include servers with 5+ active users)
- Add minimum activity period (e.g., only servers active for 7+ days)
- Add minimum version requirement (e.g., only servers on version 9.0+)
- Add combination of thresholds (e.g., active users AND activity period)

**Demo Value:**
- Shows data quality filtering
- Demonstrates impact on data volume
- Shows business rules for data inclusion

---

### 6. **Dimension & Categorization Changes**

#### Option K: Modify Server User Binning
**File:** `transform/mattermost-analytics/models/marts/product/fct_active_servers.sql`
**Current Logic:** Lines 11-20 - registered_user_bin categorization
**Change Options:**
- Change bin definitions (e.g., different size ranges)
- Add new dimension (e.g., add server_age_bin)
- Change categorization logic (e.g., use percentile-based bins)
- Add multi-dimensional categorization (e.g., size x type matrix)

**Demo Value:**
- Shows dimension logic changes
- Demonstrates impact on analytics
- Shows categorization business rules

---

#### Option L: Add New Calculated Dimensions
**File:** `transform/mattermost-analytics/models/marts/product/fct_active_servers.sql`
**Current Logic:** Limited calculated dimensions
**Change Options:**
- Add server maturity dimension (e.g., 'new', 'established', 'mature' based on age)
- Add engagement tier (e.g., 'high', 'medium', 'low' based on activity)
- Add growth stage (e.g., 'growing', 'stable', 'declining' based on trends)
- Add platform type (e.g., 'cloud', 'on-prem', 'self-hosted')

**Demo Value:**
- Shows new dimension creation
- Demonstrates business logic for categorization
- Shows impact on downstream analytics

---

## Recommended Demo PR Combinations

### **Combo 1: High Impact - Filtering Change**
- **File:** `rpt_active_user_base.sql`
- **Change:** Remove excludable server filtering OR change date window from 30 to 90 days
- **Why:** High downstream impact, shows data quality implications

### **Combo 2: Calculation Change**
- **File:** `fct_nps_score.sql`
- **Change:** Modify NPS aggregation or add new NPS calculations
- **Why:** Shows business metric definition changes, calculation logic

### **Combo 3: Threshold Change**
- **File:** `fct_active_servers.sql`
- **Change:** Modify user binning thresholds or add minimum thresholds
- **Why:** Shows business rule changes, impact on segmentation

### **Combo 4: Join Strategy Change**
- **File:** `fct_active_servers.sql` or `rpt_active_user_base.sql`
- **Change:** Change LEFT JOIN to INNER JOIN or add/remove joins
- **Why:** Shows data completeness trade-offs, performance implications

---

## Quick Reference: Files by Change Type

| File | Primary Change Types | Complexity | Downstream Impact |
|------|---------------------|------------|-------------------|
| `fct_active_users.sql` | ✅ Filtering, Joins, Thresholds | Medium | High |
| `fct_active_servers.sql` | ✅ Binning, Thresholds, Dimensions | Low-Medium | Medium |
| `rpt_active_user_base.sql` | ✅ Filtering, Joins, Date Windows | Medium | Very High |
| `fct_nps_score.sql` | ✅ Calculations, Aggregations | Medium | Medium |
| `fct_feature_daily_snapshot.sql` | ✅ Aggregations, Date Logic | Medium | Medium |
| `fct_board_activity.sql` | ✅ Simple pass-through (limited) | Low | Low |

---

## Notes for Demo Creation

1. **Start Simple**: Begin with threshold or filtering changes (easier to understand impact)
2. **Show Impact**: Choose changes that affect downstream reports/dashboards
3. **Mix Types**: Create different PRs for different change types to show variety
4. **Document Well**: Add clear comments explaining business logic changes
5. **Test Cases**: Focus on validation tests for the changed logic

---

## Example PR Structure

For each PR:
1. **Modify the SQL file** with business logic changes
2. **Add comments** explaining the change
3. **Create PR documentation** (local, not committed):
   - PR description
   - Optimizations (3-4 suggestions)
   - Test cases (3-4 tests)
   - Impact analysis (with lineage)
   - Logic review (conversation examples)

