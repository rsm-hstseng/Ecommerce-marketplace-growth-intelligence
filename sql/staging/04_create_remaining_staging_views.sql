
-- =====================================================
-- PROJECT: Olist Marketplace Growth Intelligence
-- STEP 7A: Remaining Staging Views
-- =====================================================

-- 1. CUSTOMERS
-- Grain: 1 row per customer_id

CREATE OR REPLACE VIEW staging.stg_customers AS
SELECT
    TRIM(customer_id) AS customer_id,
    TRIM(customer_unique_id) AS customer_unique_id,
    customer_zip_code_prefix,
    INITCAP(TRIM(customer_city)) AS customer_city,
    UPPER(TRIM(customer_state)) AS customer_state
FROM raw.customers
WHERE customer_id IS NOT NULL;


-- 2. SELLERS
-- Grain: 1 row per seller_id

CREATE OR REPLACE VIEW staging.stg_sellers AS
SELECT
    TRIM(seller_id) AS seller_id,
    seller_zip_code_prefix,
    INITCAP(TRIM(seller_city)) AS seller_city,
    UPPER(TRIM(seller_state)) AS seller_state
FROM raw.sellers
WHERE seller_id IS NOT NULL;


-- 3. PAYMENTS
-- Grain: 1 row per order_id + payment_sequential

CREATE OR REPLACE VIEW staging.stg_payments AS
SELECT
    order_id,
    payment_sequential,
    LOWER(TRIM(payment_type)) AS payment_type,
    payment_installments,
    payment_value
FROM raw.payments
WHERE order_id IS NOT NULL;


-- 4. REVIEWS
-- Grain: 1 row per source review record

CREATE OR REPLACE VIEW staging.stg_reviews AS
SELECT
    review_id,
    order_id,
    review_score,
    NULLIF(TRIM(review_comment_title), '')
        AS review_comment_title,
    NULLIF(TRIM(review_comment_message), '')
        AS review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM raw.reviews
WHERE order_id IS NOT NULL;


-- 5. CATEGORY TRANSLATIONS

CREATE OR REPLACE VIEW staging.stg_categories AS
SELECT
    TRIM(product_category_name)
        AS category_name_original,
    TRIM(product_category_name_english)
        AS category_name_english
FROM raw.category_translation
WHERE product_category_name IS NOT NULL;


-- 6. GEOLOCATION
-- Aggregate coordinates to zip-code/state grain.
-- Do not directly join individual geolocation rows.

CREATE OR REPLACE VIEW staging.stg_geolocation AS
SELECT
    geolocation_zip_code_prefix,
    UPPER(TRIM(geolocation_state))
        AS geolocation_state,
    AVG(geolocation_lat) AS avg_lat,
    AVG(geolocation_lng) AS avg_lng,
    COUNT(*) AS source_record_count
FROM raw.geolocation
WHERE geolocation_zip_code_prefix IS NOT NULL
  AND geolocation_state IS NOT NULL
GROUP BY
    geolocation_zip_code_prefix,
    UPPER(TRIM(geolocation_state));
