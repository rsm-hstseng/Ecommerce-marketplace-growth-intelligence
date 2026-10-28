ANALYZE raw.orders;
ANALYZE raw.order_items;
ANALYZE raw.products;
ANALYZE raw.customers;
ANALYZE raw.category_translation;

-- CHECK 2: Query Plan After ANALYZE

EXPLAIN
SELECT
    category_name,
    customer_state,
    COUNT(DISTINCT order_id) AS orders,
    SUM(item_value) AS gmv
FROM marts.base_growth_items
WHERE order_month >= DATE '2018-04-01'
  AND order_month < DATE '2018-07-01'
GROUP BY category_name, customer_state;

-- CHECK 3: Query Plan After Staging Optimization

EXPLAIN
SELECT
    category_name,
    customer_state,
    COUNT(DISTINCT order_id) AS orders,
    SUM(item_value) AS gmv
FROM marts.base_growth_items
WHERE order_month >= DATE '2018-04-01'
  AND order_month < DATE '2018-07-01'
GROUP BY category_name, customer_state;
