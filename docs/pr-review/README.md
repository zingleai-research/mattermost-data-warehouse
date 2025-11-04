# PR Review Documentation

This directory contains detailed optimization analysis and test cases for pull requests that introduce unoptimized code patterns.

## Purpose

These documents are designed to help AI PR Reviewers identify cost and performance issues in data warehouse code. Each PR includes:

- **Optimization Suggestions**: Specific improvements to reduce costs and improve performance
- **Targeted Queries**: Exact file locations and line numbers where issues exist
- **Test Cases**: Comprehensive test scenarios to validate optimizations

## Contents

### [PR1_ENGAGEMENT_METRICS.md](./PR1_ENGAGEMENT_METRICS.md)
**PR Branch:** `pr-engagement-metrics-15min`

**Key Issues:**
- Job runs every 15 minutes but upstream data only updates hourly
- No upstream dependency checks
- Missing data freshness validation

**Primary Optimization:** Reduce schedule frequency from 15 minutes to hourly

### [PR2_USER_ENGAGEMENT_REPORT.md](./PR2_USER_ENGAGEMENT_REPORT.md)
**PR Branch:** `pr-user-engagement-report`

**Key Issues:**
- Full table scan without date filters
- Expensive window functions on entire dataset
- No incremental materialization strategy
- Multiple heavy aggregations on unfiltered data

**Primary Optimization:** Add date filters, switch to incremental materialization

## How to Use

1. **For AI Reviewers**: Use these documents to identify optimization opportunities
2. **For Developers**: Reference these when reviewing similar code patterns
3. **For Testing**: Use the test cases to validate optimizations
4. **For Cost Analysis**: Reference cost impact estimates and benchmarks

## Structure

Each PR review document contains:

1. **Overview**: Brief description of the PR
2. **Optimization Issues**: Detailed analysis of each issue with:
   - Severity and impact
   - Problem description
   - Targeted code locations (file + line numbers)
   - Optimization suggestions with code examples
   - Expected cost/performance improvements
3. **Test Cases**: Comprehensive test scenarios covering:
   - Validation tests
   - Performance tests
   - Cost analysis tests
   - Integration tests
4. **Code Review Checklist**: Items to verify during review
5. **Recommended Actions**: Prioritized list of fixes

## Cost Impact Summary

| PR | Issue | Current Cost | Optimized Cost | Savings |
|----|-------|--------------|----------------|---------|
| PR #1 | Job Frequency | 96 runs/day | 24 runs/day | ~75% |
| PR #2 | Full Table Scan | $50-200/run | $2-5/run | ~90-95% |

## Best Practices

When reviewing similar PRs, look for:

1. **Schedule Mismatches**: Job frequency should align with upstream refresh rates
2. **Missing Filters**: Queries should filter by date/time when appropriate
3. **Incremental Strategies**: Large tables should use incremental materialization
4. **Window Functions**: Apply filters before expensive window operations
5. **Full Table Scans**: Always question queries that scan entire large tables

## Contributing

When adding new PR review documentation:

1. Follow the existing structure
2. Include specific file paths and line numbers
3. Provide code examples for optimizations
4. Include test cases with clear objectives
5. Estimate cost/performance impact where possible

