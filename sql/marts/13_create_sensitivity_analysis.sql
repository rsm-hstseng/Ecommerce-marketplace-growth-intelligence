
-- =====================================================
-- STEP 10A: WEIGHT SENSITIVITY ANALYSIS
-- Project: Marketplace Growth Intelligence
-- =====================================================


-- =====================================================
-- 1. MATERIALIZE VALIDATED OPPORTUNITY RESULTS
-- =====================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS
marts.mv_opportunity_scores AS
SELECT *
FROM marts.mart_opportunity_ranking;


CREATE UNIQUE INDEX IF NOT EXISTS
idx_mv_opportunity_rank
ON marts.mv_opportunity_scores (opportunity_rank);


ANALYZE marts.mv_opportunity_scores;


-- =====================================================
-- 2. BUILD SCENARIO-BASED OPPORTUNITY SCORES
-- Grain: one row per scenario + category + state
-- =====================================================

CREATE OR REPLACE VIEW
marts.mart_weight_sensitivity AS

WITH scenarios AS (

    SELECT *
    FROM (
        VALUES

        ('Baseline',
         0.35::NUMERIC,
         0.25::NUMERIC,
         0.20::NUMERIC,
         0.20::NUMERIC),

        ('Growth-focused',
         0.50::NUMERIC,
         0.20::NUMERIC,
         0.15::NUMERIC,
         0.15::NUMERIC),

        ('Balanced',
         0.25::NUMERIC,
         0.25::NUMERIC,
         0.25::NUMERIC,
         0.25::NUMERIC),

        ('Delivery-focused',
         0.20::NUMERIC,
         0.20::NUMERIC,
         0.20::NUMERIC,
         0.40::NUMERIC)

    ) AS s (
        scenario,
        growth_weight,
        scale_weight,
        diversification_weight,
        delivery_weight
    )
),

scored AS (

    SELECT
        s.scenario,

        s.growth_weight,
        s.scale_weight,
        s.diversification_weight,
        s.delivery_weight,

        o.category_name,
        o.customer_state,

        o.opportunity_rank AS baseline_rank,

        o.q1_gmv,
        o.q2_gmv,
        o.growth_pct,
        o.q2_orders,
        o.q2_active_sellers,
        o.hhi,
        o.on_time_delivery_pct,

        o.growth_score,
        o.scale_score,
        o.diversification_score,
        o.delivery_score,

        (
            s.growth_weight * o.growth_score
          + s.scale_weight * o.scale_score
          + s.diversification_weight
                * o.diversification_score
          + s.delivery_weight * o.delivery_score
        ) AS scenario_score

    FROM marts.mv_opportunity_scores o

    CROSS JOIN scenarios s
),

ranked AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY scenario

            ORDER BY
                scenario_score DESC,
                q2_gmv DESC,
                category_name,
                customer_state
        ) AS scenario_rank

    FROM scored
)

SELECT
    scenario,
    category_name,
    customer_state,

    baseline_rank,
    scenario_rank,

    baseline_rank - scenario_rank
        AS rank_improvement,

    ROUND(scenario_score, 2)
        AS opportunity_score,

    q1_gmv,
    q2_gmv,
    growth_pct,
    q2_orders,
    q2_active_sellers,
    hhi,
    on_time_delivery_pct,

    growth_weight,
    scale_weight,
    diversification_weight,
    delivery_weight

FROM ranked;
