
-- =====================================================
-- STEP 9B: STRATEGIC OPPORTUNITY ENGINE
-- Grain: Category x Customer State
-- Compare: 2018 Q1 vs 2018 Q2
-- =====================================================

CREATE OR REPLACE VIEW marts.mart_opportunity_ranking AS

WITH quarterly_sales AS (
    SELECT
        category_name,
        customer_state,

        SUM(item_value) FILTER (
            WHERE order_month >= DATE '2018-01-01'
              AND order_month < DATE '2018-04-01'
        ) AS q1_gmv,

        COUNT(DISTINCT order_id) FILTER (
            WHERE order_month >= DATE '2018-01-01'
              AND order_month < DATE '2018-04-01'
        ) AS q1_orders,

        SUM(item_value) FILTER (
            WHERE order_month >= DATE '2018-04-01'
              AND order_month < DATE '2018-07-01'
        ) AS q2_gmv,

        COUNT(DISTINCT order_id) FILTER (
            WHERE order_month >= DATE '2018-04-01'
              AND order_month < DATE '2018-07-01'
        ) AS q2_orders,

        COUNT(DISTINCT seller_id) FILTER (
            WHERE order_month >= DATE '2018-04-01'
              AND order_month < DATE '2018-07-01'
        ) AS q2_active_sellers

    FROM marts.mv_base_growth_items

    WHERE order_month >= DATE '2018-01-01'
      AND order_month < DATE '2018-07-01'

    GROUP BY category_name, customer_state
),

seller_sales AS (
    SELECT
        category_name,
        customer_state,
        seller_id,
        SUM(item_value) AS seller_gmv

    FROM marts.mv_base_growth_items

    WHERE order_month >= DATE '2018-04-01'
      AND order_month < DATE '2018-07-01'
      AND seller_id IS NOT NULL

    GROUP BY
        category_name, customer_state, seller_id
),

seller_shares AS (
    SELECT
        *,
        seller_gmv / NULLIF(
            SUM(seller_gmv) OVER (
                PARTITION BY category_name, customer_state
            ), 0
        ) AS seller_share
    FROM seller_sales
),

seller_health AS (
    SELECT
        category_name,
        customer_state,

        SUM(POWER(seller_share, 2)) AS hhi,

        MAX(seller_share) AS top_seller_share

    FROM seller_shares

    GROUP BY category_name, customer_state
),

delivery_health AS (
    SELECT
        b.category_name,
        b.customer_state,

        COUNT(DISTINCT b.order_id)
            AS delivered_orders,

        COUNT(DISTINCT b.order_id) FILTER (
            WHERE o.order_delivered_customer_date IS NOT NULL
              AND o.order_estimated_delivery_date IS NOT NULL
        ) AS orders_with_delivery_dates,

        COUNT(DISTINCT b.order_id) FILTER (
            WHERE o.order_delivered_customer_date IS NOT NULL
              AND o.order_estimated_delivery_date IS NOT NULL
              AND o.order_delivered_customer_date
                  <= o.order_estimated_delivery_date
        ) AS on_time_orders

    FROM marts.mv_base_growth_items b

    LEFT JOIN staging.stg_orders o
      ON b.order_id = o.order_id

    WHERE b.order_month >= DATE '2018-04-01'
      AND b.order_month < DATE '2018-07-01'

    GROUP BY b.category_name, b.customer_state
),

metrics AS (
    SELECT
        q.category_name,
        q.customer_state,

        q.q1_gmv,
        q.q2_gmv,
        q.q1_orders,
        q.q2_orders,
        q.q2_active_sellers,

        (q.q2_gmv - q.q1_gmv)
            / NULLIF(q.q1_gmv, 0) AS growth_rate,

        s.hhi,
        s.top_seller_share,
        1 - s.hhi AS diversification,

        d.delivered_orders,
        d.orders_with_delivery_dates,

        d.on_time_orders::NUMERIC
            / NULLIF(d.orders_with_delivery_dates, 0)
            AS on_time_rate,

        d.orders_with_delivery_dates::NUMERIC
            / NULLIF(d.delivered_orders, 0)
            AS delivery_data_coverage

    FROM quarterly_sales q

    LEFT JOIN seller_health s
      ON q.category_name = s.category_name
     AND q.customer_state = s.customer_state

    LEFT JOIN delivery_health d
      ON q.category_name = d.category_name
     AND q.customer_state = d.customer_state
),

eligible AS (
    SELECT *
    FROM metrics

    WHERE q1_orders >= 20
      AND q2_orders >= 20
      AND q2_active_sellers >= 3
      AND q1_gmv > 0
      AND q2_gmv > 0
      AND hhi IS NOT NULL
      AND orders_with_delivery_dates >= 20
      AND delivery_data_coverage >= 0.80
      AND category_name <> 'unknown'
      AND customer_state <> 'unknown'
),

normalized AS (
    SELECT
        *,

        100.0 * (
            growth_rate - MIN(growth_rate) OVER ()
        ) / NULLIF(
            MAX(growth_rate) OVER ()
            - MIN(growth_rate) OVER (), 0
        ) AS growth_score,

        100.0 * (
            q2_gmv - MIN(q2_gmv) OVER ()
        ) / NULLIF(
            MAX(q2_gmv) OVER ()
            - MIN(q2_gmv) OVER (), 0
        ) AS scale_score,

        100.0 * (
            diversification - MIN(diversification) OVER ()
        ) / NULLIF(
            MAX(diversification) OVER ()
            - MIN(diversification) OVER (), 0
        ) AS diversification_score,

        100.0 * (
            on_time_rate - MIN(on_time_rate) OVER ()
        ) / NULLIF(
            MAX(on_time_rate) OVER ()
            - MIN(on_time_rate) OVER (), 0
        ) AS delivery_score

    FROM eligible
),

scored AS (
    SELECT
        *,

        0.35 * COALESCE(growth_score, 50)
      + 0.25 * COALESCE(scale_score, 50)
      + 0.20 * COALESCE(diversification_score, 50)
      + 0.20 * COALESCE(delivery_score, 50)
            AS opportunity_score

    FROM normalized
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY opportunity_score DESC,
                 q2_gmv DESC,
                 category_name,
                 customer_state
    ) AS opportunity_rank,

    category_name,
    customer_state,

    ROUND(q1_gmv, 2) AS q1_gmv,
    ROUND(q2_gmv, 2) AS q2_gmv,

    q1_orders,
    q2_orders,
    q2_active_sellers,

    ROUND(growth_rate * 100, 2) AS growth_pct,
    ROUND(hhi, 4) AS hhi,
    ROUND(top_seller_share * 100, 2)
        AS top_seller_share_pct,

    ROUND(on_time_rate * 100, 2)
        AS on_time_delivery_pct,

    ROUND(delivery_data_coverage * 100, 2)
        AS delivery_data_coverage_pct,

    ROUND(COALESCE(growth_score, 50), 2)
        AS growth_score,

    ROUND(COALESCE(scale_score, 50), 2)
        AS scale_score,

    ROUND(COALESCE(diversification_score, 50), 2)
        AS diversification_score,

    ROUND(COALESCE(delivery_score, 50), 2)
        AS delivery_score,

    ROUND(opportunity_score, 2)
        AS opportunity_score

FROM scored;
