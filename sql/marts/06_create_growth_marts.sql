-- ===============================================
-- STEP 8A: BASE ANALYTICAL DATA
-- Grain: 1 row per order item
-- ===============================================

CREATE OR REPLACE VIEW marts.base_growth_items AS
SELECT
    f.order_id,
    f.order_item_id,
    f.product_id,
    f.seller_id,
    f.customer_id,
    f.order_month,
    f.item_value,
    f.freight_value,
    COALESCE(
        p.category_name,
        'unknown'
    ) AS category_name,
    COALESCE(
        c.customer_state,
        'unknown'
    ) AS customer_state

FROM core.fct_order_items f

LEFT JOIN core.dim_products p
    ON f.product_id = p.product_id

LEFT JOIN core.dim_customers c
    ON f.customer_id = c.customer_id

WHERE f.order_status = 'delivered'
  AND f.order_month >= DATE '2017-01-01'
  AND f.order_month < DATE '2018-09-01';

-- ===============================================
-- STEP 8B: MONTHLY GROWTH MART
-- Grain: 1 row per month
-- ===============================================

CREATE OR REPLACE VIEW marts.mart_monthly_growth AS

WITH monthly_metrics AS (
    SELECT
        order_month,
        SUM(item_value) AS item_gmv,
        COUNT(DISTINCT order_id) AS order_count,
        COUNT(*) AS items_sold,
        COUNT(DISTINCT seller_id) AS active_sellers

    FROM marts.base_growth_items
    GROUP BY order_month
),

growth_calculation AS (
    SELECT
        *,
        LAG(item_gmv) OVER (
            ORDER BY order_month
        ) AS previous_month_gmv,

        LAG(order_count) OVER (
            ORDER BY order_month
        ) AS previous_month_orders

    FROM monthly_metrics
)

SELECT
    order_month,
    item_gmv,
    order_count,
    items_sold,
    active_sellers,

    ROUND(
        item_gmv / NULLIF(order_count, 0),
        2
    ) AS aov,

    previous_month_gmv,
    previous_month_orders,

    ROUND(
        100.0 * (item_gmv - previous_month_gmv)
        / NULLIF(previous_month_gmv, 0),
        2
    ) AS mom_gmv_growth_pct

FROM growth_calculation;

-- ===============================================
-- STEP 8C: CATEGORY GROWTH CONTRIBUTION
-- Grain: 1 row per month + category
-- ===============================================

CREATE OR REPLACE VIEW marts.mart_category_growth AS

WITH calendar AS (
    SELECT
        GENERATE_SERIES(
            DATE '2017-01-01',
            DATE '2018-08-01',
            INTERVAL '1 month'
        )::DATE AS order_month
),

categories AS (
    SELECT DISTINCT category_name
    FROM marts.base_growth_items
),

category_months AS (
    SELECT
        c.order_month,
        p.category_name
    FROM calendar c
    CROSS JOIN categories p
),

category_sales AS (
    SELECT
        order_month,
        category_name,
        SUM(item_value) AS item_gmv,
        COUNT(DISTINCT order_id) AS order_count
    FROM marts.base_growth_items
    GROUP BY order_month, category_name
),

monthly_comparison AS (
    SELECT
        cm.order_month,
        cm.category_name,
        COALESCE(s.item_gmv, 0) AS item_gmv,
        COALESCE(s.order_count, 0) AS order_count
    FROM category_months cm
    LEFT JOIN category_sales s
      ON cm.order_month = s.order_month
     AND cm.category_name = s.category_name
),

growth AS (
    SELECT
        *,
        LAG(item_gmv) OVER (
            PARTITION BY category_name
            ORDER BY order_month
        ) AS previous_month_gmv
    FROM monthly_comparison
),

contribution AS (
    SELECT
        *,
        item_gmv - previous_month_gmv
            AS gmv_change
    FROM growth
)

SELECT
    order_month,
    category_name,
    item_gmv,
    order_count,
    previous_month_gmv,
    gmv_change,

    ROUND(
        100.0 * gmv_change /
        NULLIF(previous_month_gmv, 0),
        2
    ) AS mom_growth_pct,

    ROUND(
        100.0 * gmv_change /
        NULLIF(
            SUM(gmv_change) OVER (
                PARTITION BY order_month
            ), 0
        ),
        2
    ) AS growth_contribution_pct

FROM contribution;

-- ===============================================
-- STEP 8D: SELLER CONCENTRATION
-- Grain: 1 row per month + category
-- ===============================================

CREATE OR REPLACE VIEW marts.mart_seller_concentration AS

WITH seller_sales AS (
    SELECT
        order_month,
        category_name,
        seller_id,
        SUM(item_value) AS seller_gmv

    FROM marts.base_growth_items
    WHERE seller_id IS NOT NULL

    GROUP BY
        order_month,
        category_name,
        seller_id
),

seller_shares AS (
    SELECT
        *,
        seller_gmv / NULLIF(
            SUM(seller_gmv) OVER (
                PARTITION BY order_month, category_name
            ), 0
        ) AS seller_share

    FROM seller_sales
)

SELECT
    order_month,
    category_name,

    COUNT(*) AS active_sellers,

    SUM(seller_gmv) AS category_gmv,

    ROUND(
        SUM(POWER(seller_share, 2)),
        4
    ) AS hhi,

    ROUND(
        100.0 * MAX(seller_share),
        2
    ) AS top_seller_share_pct

FROM seller_shares

GROUP BY
    order_month,
    category_name;

-- ===============================================
-- STEP 8E: CATEGORY × REGION PERFORMANCE
-- Grain: 1 row per month + category + state
-- ===============================================

CREATE OR REPLACE VIEW marts.mart_category_region AS

SELECT
    order_month,
    category_name,
    customer_state,

    SUM(item_value) AS item_gmv,

    COUNT(*) AS items_sold,

    COUNT(DISTINCT order_id) AS order_count,

    COUNT(DISTINCT seller_id) AS active_sellers

FROM marts.base_growth_items

GROUP BY
    order_month,
    category_name,
    customer_state;
