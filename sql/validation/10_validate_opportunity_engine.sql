
-- =====================================================
-- STEP 9: OPPORTUNITY ENGINE VALIDATION
-- =====================================================

-- CHECK 1: Growth Decomposition Reconciliation
SELECT
    COUNT(*) AS months_checked,
    MAX(ABS(reconciliation_difference)) AS max_difference
FROM marts.mart_growth_decomposition;


-- CHECK 2: Opportunity Score Validation
SELECT
    COUNT(*) AS eligible_opportunities,
    MIN(opportunity_score) AS min_score,
    MAX(opportunity_score) AS max_score,
    COUNT(*) FILTER (
        WHERE opportunity_score IS NULL
           OR opportunity_score < 0
           OR opportunity_score > 100
    ) AS invalid_scores
FROM marts.mart_opportunity_ranking;


-- CHECK 3: Duplicate Category-Region Pairs
SELECT
    category_name,
    customer_state,
    COUNT(*) AS duplicate_count
FROM marts.mart_opportunity_ranking
GROUP BY category_name, customer_state
HAVING COUNT(*) > 1;


-- CHECK 4: Minimum Data Thresholds
SELECT
    opportunity_rank,
    category_name,
    customer_state,
    q1_orders,
    q2_orders,
    q2_active_sellers,
    delivery_data_coverage_pct
FROM marts.mart_opportunity_ranking
ORDER BY opportunity_rank
LIMIT 15;


-- CHECK 5: HHI and Delivery Validity
SELECT
    COUNT(*) FILTER (
        WHERE hhi IS NULL OR hhi < 0 OR hhi > 1
    ) AS invalid_hhi,
    COUNT(*) FILTER (
        WHERE on_time_delivery_pct IS NULL
           OR on_time_delivery_pct < 0
           OR on_time_delivery_pct > 100
    ) AS invalid_delivery_rates
FROM marts.mart_opportunity_ranking;

-- CHECK 6: All Opportunity Eligibility Thresholds

SELECT
    COUNT(*) FILTER (
        WHERE q1_orders < 20
           OR q2_orders < 20
           OR q2_active_sellers < 3
           OR delivery_data_coverage_pct < 80
           OR q1_orders IS NULL
           OR q2_orders IS NULL
           OR q2_active_sellers IS NULL
           OR delivery_data_coverage_pct IS NULL
    ) AS invalid_opportunities
FROM marts.mart_opportunity_ranking;
