
-- =========================================
-- OLIST GROWTH INTELLIGENCE
-- STEP 8: ANALYTICS MART VALIDATION
-- =========================================

-- CHECK 1: Monthly Growth
SELECT
    order_month,
    item_gmv,
    order_count,
    aov,
    mom_gmv_growth_pct
FROM marts.mart_monthly_growth
ORDER BY order_month;


-- CHECK 2: Category Growth Contribution
SELECT
    order_month,
    category_name,
    item_gmv,
    gmv_change,
    growth_contribution_pct
FROM marts.mart_category_growth
WHERE order_month = DATE '2018-07-01'
ORDER BY gmv_change DESC
LIMIT 10;


-- CHECK 3: Seller Concentration (HHI)
SELECT
    category_name,
    active_sellers,
    category_gmv,
    hhi,
    top_seller_share_pct
FROM marts.mart_seller_concentration
WHERE order_month = DATE '2018-07-01'
  AND category_gmv > 10000
ORDER BY hhi DESC
LIMIT 10;


-- CHECK 4: GMV Reconciliation
SELECT
    (SELECT SUM(item_value)
     FROM marts.base_growth_items) AS base_gmv,

    (SELECT SUM(item_gmv)
     FROM marts.mart_monthly_growth) AS monthly_gmv,

    (SELECT SUM(item_gmv)
     FROM marts.mart_category_growth) AS category_gmv,

    (SELECT SUM(item_gmv)
     FROM marts.mart_category_region) AS region_gmv;

-- CHECK 4B: Automated GMV Validation

WITH totals AS (
    SELECT
        (SELECT SUM(item_value)
         FROM marts.base_growth_items) AS base_gmv,

        (SELECT SUM(item_gmv)
         FROM marts.mart_monthly_growth) AS monthly_gmv,

        (SELECT SUM(item_gmv)
         FROM marts.mart_category_growth) AS category_gmv,

        (SELECT SUM(item_gmv)
         FROM marts.mart_category_region) AS region_gmv
)

SELECT
    *,
    CASE
        WHEN base_gmv = monthly_gmv
         AND base_gmv = category_gmv
         AND base_gmv = region_gmv
        THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM totals;

-- CHECK 5: Monthly GMV Reconciliation
SELECT
    m.order_month,
    m.item_gmv AS marketplace_gmv,
    SUM(c.item_gmv) AS summed_category_gmv,
    m.item_gmv - SUM(c.item_gmv) AS difference
FROM marts.mart_monthly_growth m
JOIN marts.mart_category_growth c
    ON m.order_month = c.order_month
GROUP BY
    m.order_month,
    m.item_gmv
ORDER BY m.order_month;


-- CHECK 6: Month Coverage
SELECT
    COUNT(*) AS observed_months,
    MIN(order_month) AS first_month,
    MAX(order_month) AS last_month
FROM marts.mart_monthly_growth;

-- CHECK 7: Growth Decomposition

SELECT
    order_month,
    gmv_change,
    volume_effect,
    aov_effect,
    reconciliation_difference
FROM marts.mart_growth_decomposition
ORDER BY order_month;
