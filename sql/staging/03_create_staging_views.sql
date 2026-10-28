
-- =====================================================
-- PROJECT: Olist Marketplace Growth Intelligence
-- STEP 6: SQL STAGING LAYER (OPTIMIZED)
-- DATABASE: olist_growth
-- =====================================================

-- =========================================
-- 1. STAGING ORDERS
-- Grain: One row per order_id
-- Optimization: Remove unnecessary ROW_NUMBER()
-- =========================================

CREATE OR REPLACE VIEW staging.stg_orders AS

SELECT
    order_id,
    customer_id,
    LOWER(TRIM(order_status)) AS order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    DATE_TRUNC(
        'month',
        order_purchase_timestamp
    )::DATE AS order_month

FROM raw.orders

WHERE order_id IS NOT NULL;
-- =====================================================
-- 2. STAGING ORDER ITEMS
-- Grain: One row per order_id + order_item_id
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_order_items AS

WITH cleaned_items AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value
    FROM raw.order_items
    WHERE order_id IS NOT NULL
      AND order_item_id IS NOT NULL
)

SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price AS item_value,
    freight_value,
    price + freight_value AS total_item_amount
FROM cleaned_items;


-- =====================================================
-- 3. STAGING PRODUCTS
-- Grain: One row per product_id
-- =====================================================

CREATE OR REPLACE VIEW staging.stg_products AS

WITH products_cleaned AS (
    SELECT
        product_id,
        product_category_name,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    FROM raw.products
    WHERE product_id IS NOT NULL
),

translated AS (
    SELECT
        p.product_id,
        p.product_category_name,
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS category_name,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm
    FROM products_cleaned p
    LEFT JOIN raw.category_translation t
        ON p.product_category_name =
           t.product_category_name
)

SELECT *
FROM translated;
