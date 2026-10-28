
# Data Quality Validation Report

**Project:** Marketplace Growth Intelligence & Strategic Opportunity Engine
**Dataset:** Olist Brazilian E-Commerce Public Dataset
**Database:** PostgreSQL
**Analysis Period:** January 2017 – August 2018
**Order Scope:** Delivered orders
**GMV Definition:** Sum of item prices, excluding freight (Item GMV Proxy)

---

## 1. Objective

This report documents the data quality validation process for the Marketplace Growth Intelligence & Strategic Opportunity Engine project.

The objective is to ensure the reliability, consistency, and analytical integrity of the SQL data pipeline across four layers:

- **Raw:** Original source tables imported from the Olist dataset.
- **Staging:** Cleaned and standardized views.
- **Core:** Fact and dimension models.
- **Analytics Marts:** Business-ready KPIs, growth metrics, and opportunity rankings.

Validation focuses on:

- Row-count consistency and data completeness
- Key uniqueness and correct data grain
- Prevention of duplicate records caused by joins
- GMV reconciliation across analytical models
- Monthly reporting coverage
- Growth decomposition accuracy
- Opportunity scoring and business rule validation

---

## 2. Raw, Staging, and Core Validation

| Validation Check | Expected Result | Actual Result | Status |
|---|---|---|---|
| Raw vs. Staging Row Counts | Orders, items, and products retain expected row counts | Counts matched in Step 6 | PASS |
| Staging Key Uniqueness | No duplicate order, order-item, or product keys | No duplicates identified | PASS |
| Fact Table Row Counts | Fact tables retain their intended grain | Counts matched in Step 7 | PASS |
| Dimension Key Uniqueness | One record per dimension key | No duplicate dimension keys identified | PASS |
| Core GMV Reconciliation | Raw Item GMV equals Core Item GMV | GMV totals matched | PASS |

### Key Data Modeling Controls

**Fact Table Grain**

- `core.fct_orders`: One row per order.
- `core.fct_order_items`: One row per order item.

**Dimension Grain**

- `core.dim_products`: One row per product.
- `core.dim_customers`: One row per customer record.
- `core.dim_sellers`: One row per seller.

### Join Safety

One-to-many relationships were handled carefully to prevent inflated GMV calculations.

Order items and payments were aggregated separately before joining to the order-level fact model.

Dimension key uniqueness was validated to reduce the risk of row multiplication during analytical joins.

---

## 3. Analytics Mart Validation

The Analytics Marts transform transactional data into business-ready metrics for marketplace growth analysis.

### Validated Models

- `marts.base_growth_items`
- `marts.mart_monthly_growth`
- `marts.mart_category_growth`
- `marts.mart_seller_concentration`
- `marts.mart_category_region`

### Validation Results

| Validation Check | Expected Result | Actual Result | Status |
|---|---|---|---|
| Analytics Mart GMV Reconciliation | Base, Monthly, Category, and Region GMV totals match | All four totals matched | PASS |
| Monthly Category GMV Reconciliation | Monthly Marketplace GMV equals summed Category GMV | Monthly differences were zero | PASS |
| Month Coverage | All 20 months from January 2017 to August 2018 are present | 20 months confirmed | PASS |

### Metric Consistency

All Growth Analytics Marts use the same core metric definition:

**Item GMV Proxy = Sum of item prices from delivered orders, excluding freight.**

The reporting scope uses historical delivered orders with purchase months from January 2017 through August 2018.

This consistency ensures that GMV values can be reconciled across different reporting dimensions.

---

## 4. Growth Decomposition Validation

### Objective

Explain changes in monthly marketplace GMV by separating the contributions of:

1. Order Volume Effect
2. Average Order Value (AOV) Effect

The model uses the following accounting identity:

**GMV = Order Count × AOV**

Therefore:

**GMV Change = Volume Effect + AOV Effect**

### Validation Results

| Metric | Actual Result |
|---|---|
| Comparable months | 19 |
| Maximum reconciliation difference | 0.000000 |
| Validation status | PASS |

The decomposition reconciles monthly GMV changes into volume and AOV effects.

The analysis provides a descriptive explanation of growth drivers, not causal evidence.

---

## 5. Strategic Opportunity Engine Validation

### Objective

Rank Category × Region combinations based on four business dimensions:

| Scoring Dimension | Weight | Business Interpretation |
|---|---|---|
| Growth Momentum | 35% | Quarter-over-quarter GMV growth |
| Market Scale | 25% | Current-quarter Item GMV |
| Seller Diversification | 20% | Degree of seller diversification, measured using HHI |
| Delivery Reliability | 20% | Historical on-time delivery performance |

Each metric is normalized to a 0–100 scale before applying the weighted scoring formula.

### Analysis Period

- **Previous Period:** 2018 Q1 (January–March)
- **Current Period:** 2018 Q2 (April–June)

### Eligibility Requirements

Each eligible Category × Region combination must satisfy:

- At least 20 orders in Q1
- At least 20 orders in Q2
- At least 3 active sellers in Q2
- Positive GMV in both quarters
- At least 20 orders with usable delivery dates
- At least 80% delivery-data coverage
- Valid category and region information

These thresholds are project-defined analytical filters rather than universal business standards.

### Validation Results

| Validation Check | Actual Result | Status |
|---|---|---|
| Eligible Opportunities | 153 category-region combinations | PASS |
| Opportunity Score Range | 24.99–72.87 | PASS |
| Invalid Opportunity Scores | 0 | PASS |
| Duplicate Category × Region Pairs | 0 | PASS |
| Minimum Eligibility Threshold Violations | 0 | PASS |
| Invalid Seller HHI Values | 0 | PASS |
| Invalid Delivery Rate Values | 0 | PASS |

### Interpretation

The Opportunity Engine identifies 153 eligible Category × Region combinations.

All calculated opportunity scores fall within the expected 0–100 range, and the validation queries found no duplicate category-region combinations or invalid HHI and delivery-rate values.

The rankings are based on predefined business weights and represent relative prioritization opportunities.

They should not be interpreted as predictions of revenue, profit, or investment returns.

---

## 6. Query Performance Optimization

### Initial Performance Issue

The original Opportunity Ranking query ran for more than 10 minutes.

The query combined multiple transformations, joins, aggregations, distinct order counts, window functions, and ranking calculations.

### Optimization Actions

**1. Simplified the Staging Orders View**

The original `staging.stg_orders` view used a `ROW_NUMBER()` window function to deduplicate orders.

After validating order ID uniqueness, the transformation was simplified to remove the unnecessary window operation.

**2. Introduced a Materialized Base Dataset**

A materialized view was created:

`marts.mv_base_growth_items`

This stores the transformed analytical base dataset instead of repeatedly calculating the same joins.

**3. Added Supporting Indexes**

Indexes were created to support month-based and Category × Region analytical queries.

**4. Updated the Opportunity Engine**

The Opportunity Ranking model was updated to use the materialized base dataset.

### Outcome

Following the optimizations, the Opportunity Ranking query successfully returned the Top 15 ranked category-region combinations.

The improvement enabled practical use of the ranking model. A formal execution-time benchmark has not yet been recorded.

### Maintenance Consideration

Because the analytical base is materialized, it must be refreshed when underlying source data changes.

---

## 7. Validation Evidence

### SQL Validation Scripts

- `sql/validation/07_validate_growth_marts.sql`
- `sql/validation/10_validate_opportunity_engine.sql`
- `sql/validation/11_performance_diagnostics.sql`

### Supporting Model Scripts

- `sql/staging/03_create_staging_views.sql`
- `sql/marts/06_create_growth_marts.sql`
- `sql/marts/08_create_growth_decomposition.sql`
- `sql/marts/09_create_opportunity_engine.sql`
- `sql/marts/12_optimize_base_growth.sql`

### Exported Validation Evidence

- `docs/validation/gmv_reconciliation.csv`
- `docs/validation/monthly_reconciliation.csv`

The exported CSV files serve as additional evidence when saved and included in the project repository.

---

## 8. Known Limitations

### Historical Dataset

The Olist dataset contains historical marketplace transactions rather than current business activity.

### GMV Definition

Item GMV is a proxy for merchandise sales value.

It does not represent net revenue, profit, or cash received.

Freight is excluded from the GMV calculation.

### Delivered-Order Scope

The analysis includes only delivered orders.

This may introduce selection bias, especially near the dataset's reporting boundaries.

### Reporting Period

The reporting window is January 2017 through August 2018.

Although all 20 reporting months are represented, month coverage alone does not guarantee complete transaction or delivery coverage.

### Opportunity Score Assumptions

The scoring framework uses predefined business weights.

The weights and eligibility thresholds represent analytical assumptions and may affect the final rankings.

### Materialized View Refresh

Materialized views contain stored results and are not automatically updated when source records change.

---

## 9. Overall Validation Summary

| Validation Area | Status |
|---|---|
| Raw and Staging Data Consistency | PASS |
| Core Fact and Dimension Integrity | PASS |
| GMV Reconciliation | PASS |
| Monthly Reporting Coverage | PASS |
| Growth Decomposition Reconciliation | PASS |
| Opportunity Score Validity | PASS |
| Category × Region Uniqueness | PASS |
| Opportunity Eligibility Thresholds | PASS |
| Seller HHI and Delivery Validity | PASS |

### Conclusion

The completed validation checks support the consistency and integrity of the Raw, Staging, Core, and Analytics Mart layers.

Growth decomposition calculations reconcile successfully, and the Strategic Opportunity Engine produces valid rankings for 153 eligible Category × Region combinations.

The resulting analytical models provide a foundation for interactive marketplace performance reporting and explainable business opportunity prioritization.

---

## 10. Next Steps

1. Conduct weight sensitivity analysis to assess Opportunity Ranking stability.
2. Evaluate the impact of different eligibility thresholds.
3. Develop an interactive Streamlit BI Dashboard.
4. Document key business findings, insights, and recommendations.
5. Publish the project code, methodology, and dashboard documentation on GitHub.

## 11. Weight Sensitivity Analysis

### Objective

Evaluate the stability of Category × Region opportunity rankings under alternative business-weight assumptions.

### Scenario Definitions

| Scenario | Growth | Scale | Diversification | Delivery |
|---|---:|---:|---:|---:|
| Baseline | 35% | 25% | 20% | 20% |
| Growth-focused | 50% | 20% | 15% | 15% |
| Balanced | 25% | 25% | 25% | 25% |
| Delivery-focused | 20% | 20% | 20% | 40% |

### Top 10 Ranking Stability

| Scenario | Top 10 Overlap with Baseline |
|---|---:|
| Baseline | 10 / 10 |
| Growth-focused | 9 / 10 |
| Balanced | 5 / 10 |
| Delivery-focused | 5 / 10 |

### Key Findings

1. **Growth-focused rankings are relatively stable.**
   Nine of the baseline Top 10 opportunities remain in the Top 10 under the Growth-focused scenario.

2. **Rankings are sensitive to balanced and delivery-focused priorities.**
   Only five of the baseline Top 10 opportunities remain under each of these scenarios.

3. **Business priorities materially affect opportunity selection.**
   A single set of scoring weights should not be treated as an objective or universally optimal ranking.

### Business Implications

- Use the Baseline ranking as an initial prioritization framework.
- Compare alternative weighting scenarios before making resource allocation decisions.
- Investigate opportunities that remain highly ranked across multiple scenarios.
- Review opportunities that enter or leave the Top 10 when operational priorities change.

### Conclusion

The sensitivity analysis demonstrates that opportunity rankings are relatively stable under a Growth-focused scenario but less stable under Balanced and Delivery-focused scenarios.

This reinforces the importance of transparent scoring assumptions and scenario-based decision support.

The analysis measures ranking robustness, not causal effects or predicted financial returns.
