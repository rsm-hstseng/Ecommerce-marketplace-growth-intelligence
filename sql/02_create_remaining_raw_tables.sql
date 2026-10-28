
-- Customers
CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INTEGER,
    customer_city TEXT,
    customer_state VARCHAR(10)
);

-- Sellers
CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix INTEGER,
    seller_city TEXT,
    seller_state VARCHAR(10)
);

-- Payments
CREATE TABLE IF NOT EXISTS raw.payments (
    order_id VARCHAR(50),
    payment_sequential INTEGER,
    payment_type VARCHAR(30),
    payment_installments INTEGER,
    payment_value NUMERIC(12,2)
);

-- Reviews
CREATE TABLE IF NOT EXISTS raw.reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- Geolocation
CREATE TABLE IF NOT EXISTS raw.geolocation (
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat DOUBLE PRECISION,
    geolocation_lng DOUBLE PRECISION,
    geolocation_city TEXT,
    geolocation_state VARCHAR(10)
);

-- Category translations
CREATE TABLE IF NOT EXISTS raw.category_translation (
    product_category_name TEXT,
    product_category_name_english TEXT
);
