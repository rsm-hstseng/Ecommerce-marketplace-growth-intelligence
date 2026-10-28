
-- =====================================================
-- STEP 7B: CORE DIMENSIONAL MODEL
-- =====================================================

-- DIMENSION: CUSTOMERS

CREATE OR REPLACE VIEW core.dim_customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix
FROM staging.stg_customers;


-- DIMENSION: SELLERS

CREATE OR REPLACE VIEW core.dim_sellers AS
SELECT
    seller_id,
    seller_city,
    seller_state
FROM staging.stg_sellers;


-- DIMENSION: PRODUCTS
-- Preserve one row per product_id.

CREATE OR REPLACE VIEW core.dim_products AS
SELECT
    product_id,
    product_category_name,
    category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM staging.stg_products;

-- =====================================================
-- FACT: ORDERS
-- Grain: 1 row per order_id
-- =====================================================

CREATE OR REPLACE VIEW core.fct_orders AS

WITH item_totals AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(item_value) AS item_gmv,
        SUM(freight_value) AS freight_total
    FROM staging.stg_order_items
    GROUP BY order_id
),

payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM staging.stg_payments
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_month,

    CASE
        WHEN o.order_status = 'delivered'
            THEN TRUE
        ELSE FALSE
    END AS is_delivered,

    COALESCE(i.item_count, 0) AS item_count,
    COALESCE(i.item_gmv, 0) AS item_gmv,
    COALESCE(i.freight_total, 0) AS freight_total,

    p.payment_total

FROM staging.stg_orders o

LEFT JOIN item_totals i
    ON o.order_id = i.order_id

LEFT JOIN payment_totals p
    ON o.order_id = p.order_id;

-- =====================================================
-- FACT: ORDER ITEMS
-- Grain: 1 row per order_id + order_item_id
-- =====================================================

CREATE OR REPLACE VIEW core.fct_order_items AS

SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,

    o.customer_id,
    o.order_purchase_timestamp,
    o.order_month,
    o.order_status,

    i.item_value,
    i.freight_value,
    i.total_item_amount

FROM staging.stg_order_items i

LEFT JOIN staging.stg_orders o
    ON i.order_id = o.order_id;
