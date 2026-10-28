
-- =====================================================
-- STEP 9A: MONTHLY GROWTH DECOMPOSITION
-- GMV Change = Volume Effect + AOV Effect
-- =====================================================

CREATE OR REPLACE VIEW marts.mart_growth_decomposition AS

WITH monthly AS (
    SELECT
        order_month,
        item_gmv,
        order_count,

        item_gmv / NULLIF(order_count, 0)
            AS exact_aov

    FROM marts.mart_monthly_growth
),

previous_period AS (
    SELECT
        *,

        LAG(order_month) OVER (
            ORDER BY order_month
        ) AS previous_month,

        LAG(item_gmv) OVER (
            ORDER BY order_month
        ) AS previous_gmv,

        LAG(order_count) OVER (
            ORDER BY order_month
        ) AS previous_orders,

        LAG(exact_aov) OVER (
            ORDER BY order_month
        ) AS previous_aov

    FROM monthly
),

decomposition AS (
    SELECT
        order_month,
        item_gmv,
        order_count,
        exact_aov,
        previous_gmv,
        previous_orders,
        previous_aov,

        item_gmv - previous_gmv AS gmv_change,

        (order_count - previous_orders)
            * previous_aov AS volume_effect,

        order_count
            * (exact_aov - previous_aov) AS aov_effect

    FROM previous_period

    -- Only compare truly consecutive months.
    WHERE previous_month =
        (order_month - INTERVAL '1 month')::DATE
)

SELECT
    order_month,

    ROUND(item_gmv, 2) AS item_gmv,
    order_count,
    ROUND(exact_aov, 2) AS aov,

    ROUND(previous_gmv, 2) AS previous_gmv,
    previous_orders,

    ROUND(gmv_change, 2) AS gmv_change,

    ROUND(volume_effect, 2) AS volume_effect,
    ROUND(aov_effect, 2) AS aov_effect,

    ROUND(
        gmv_change - volume_effect - aov_effect,
        6
    ) AS reconciliation_difference

FROM decomposition;
