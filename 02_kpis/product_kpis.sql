-- ============================================================
-- PRODUCT KPIs
-- Purpose: Product performance and inventory metrics
-- ============================================================

-- ============================================================
-- KPI 13: PRODUCT PERFORMANCE
-- Shows: Complete product analysis with inventory status
-- ============================================================
WITH product_sales AS (
    SELECT
        p.prod_id,
        p.prod_name,
        p.category,
        p.brand,
        p.price AS list_price,
        SUM(oi.quantity) AS units_sold,
        SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100)) AS revenue,
        COUNT(DISTINCT o.order_id) AS order_count,
        AVG(oi.unit_price) AS avg_selling_price
    FROM products.products p
    LEFT JOIN sales.order_items oi ON p.prod_id = oi.prod_id
    LEFT JOIN sales.orders o ON oi.order_id = o.order_id
        AND o.order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY p.prod_id, p.prod_name, p.category, p.brand, p.price
),
inventory_data AS (
    SELECT
        prod_id,
        SUM(stock_qty) AS current_stock,
        COUNT(DISTINCT store_id) AS stores_stocked
    FROM products.inventory
    GROUP BY prod_id
)
SELECT
    ps.prod_id,
    ps.prod_name,
    ps.category,
    ps.brand,
    ps.list_price,
    COALESCE(ps.units_sold, 0) AS units_sold,
    ROUND(COALESCE(ps.revenue, 0)::NUMERIC, 2) AS revenue,
    ps.order_count,
    COALESCE(i.current_stock, 0) AS current_stock,
    i.stores_stocked,
    -- Category rank
    RANK() OVER (PARTITION BY ps.category ORDER BY ps.revenue DESC NULLS LAST) AS category_rank,
    -- Stock status
    CASE
        WHEN COALESCE(i.current_stock, 0) = 0 THEN 'Out of Stock'
        WHEN COALESCE(i.current_stock, 0) < 10 THEN 'Low Stock'
        WHEN COALESCE(i.current_stock, 0) > 100 THEN 'Overstock'
        ELSE 'In Stock'
    END AS stock_status
FROM product_sales ps
LEFT JOIN inventory_data i ON ps.prod_id = i.prod_id
ORDER BY ps.revenue DESC NULLS LAST;


-- ============================================================
-- KPI 14: CATEGORY PERFORMANCE SUMMARY
-- Shows: Category-level aggregates for dashboard
-- ============================================================
SELECT
    p.category,
    COUNT(DISTINCT p.prod_id) AS product_count,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100))::NUMERIC, 2) AS revenue,
    ROUND(AVG(oi.unit_price)::NUMERIC, 2) AS avg_price,
    COUNT(DISTINCT o.order_id) AS order_count,
    -- Percentage of total revenue
    ROUND(
        SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100)) /
        SUM(SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100))) OVER () * 100,
        1
    ) AS pct_of_revenue
FROM products.products p
LEFT JOIN sales.order_items oi ON p.prod_id = oi.prod_id
LEFT JOIN sales.orders o ON oi.order_id = o.order_id
    AND o.order_status NOT IN ('Cancelled', 'Returned')
GROUP BY p.category
ORDER BY revenue DESC;
