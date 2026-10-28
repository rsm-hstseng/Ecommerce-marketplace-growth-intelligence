
-- STEP 9 PERFORMANCE OPTIMIZATION
-- Precompute the base analytical dataset

CREATE MATERIALIZED VIEW IF NOT EXISTS
marts.mv_base_growth_items AS
SELECT *
FROM marts.base_growth_items;

-- Indexes for month, category and region queries

CREATE INDEX IF NOT EXISTS
idx_mv_growth_month
ON marts.mv_base_growth_items (order_month);

CREATE INDEX IF NOT EXISTS
idx_mv_growth_category_region
ON marts.mv_base_growth_items (
    category_name,
    customer_state
);

-- Update statistics for the materialized view

ANALYZE marts.mv_base_growth_items;
