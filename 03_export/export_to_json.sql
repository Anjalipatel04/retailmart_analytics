-- ============================================================
-- JSON EXPORT QUERIES
-- Run each query and save to: 04_dashboard/data/{filename}.json
-- ============================================================

-- ============================================================
-- EXPORT 1: sales_overview.json
-- ============================================================
SELECT json_build_object(
    'generated_at', NOW(),
    'data', (
        SELECT json_build_object(
            'total_revenue', ROUND(SUM(total_amount)::NUMERIC, 2),
            'total_orders', COUNT(DISTINCT order_id),
            'total_customers', COUNT(DISTINCT cust_id),
            'avg_order_value', ROUND(AVG(total_amount)::NUMERIC, 2)
        )
        FROM sales.orders
        WHERE order_status NOT IN ('Cancelled', 'Returned')
    )
);


-- ============================================================
-- EXPORT 2: monthly_trends.json
-- ============================================================
SELECT json_build_object(
    'generated_at', NOW(),
    'data', (
        SELECT json_agg(
            json_build_object(
                'month', TO_CHAR(DATE_TRUNC('month', order_date), 'Mon YYYY'),
                'revenue', ROUND(SUM(total_amount)::NUMERIC, 2),
                'orders', COUNT(DISTINCT order_id)
            ) ORDER BY DATE_TRUNC('month', order_date)
        )
        FROM sales.orders
        WHERE order_status NOT IN ('Cancelled', 'Returned')
        GROUP BY DATE_TRUNC('month', order_date)
    )
);


-- ============================================================
-- EXPORT 3: category_sales.json
-- ============================================================
SELECT json_build_object(
    'generated_at', NOW(),
    'data', (
        SELECT json_agg(
            json_build_object(
                'category', category,
                'revenue', revenue,
                'units_sold', units_sold,
                'pct_of_total', pct_of_total
            ) ORDER BY revenue DESC
        )
        FROM (
            SELECT
                p.category,
                ROUND(SUM(oi.quantity * oi.unit_price)::NUMERIC, 2) AS revenue,
                SUM(oi.quantity) AS units_sold,
                ROUND(
                    SUM(oi.quantity * oi.unit_price) /
                    SUM(SUM(oi.quantity * oi.unit_price)) OVER () * 100,
                    1
                ) AS pct_of_total
            FROM sales.orders o
            JOIN sales.order_items oi ON o.order_id = oi.order_id
            JOIN products.products p ON oi.prod_id = p.prod_id
            WHERE o.order_status NOT IN ('Cancelled', 'Returned')
            GROUP BY p.category
        ) sub
    )
);


-- ============================================================
-- EXPORT 4: customer_segments.json
-- ============================================================
SELECT json_build_object(
    'generated_at', NOW(),
    'data', (
        SELECT json_agg(
            json_build_object(
                'segment', segment,
                'customer_count', customer_count,
                'total_revenue', total_revenue,
                'avg_clv', avg_clv
            ) ORDER BY total_revenue DESC
        )
        FROM (
            WITH customer_clv AS (
                SELECT c.cust_id, COALESCE(SUM(o.total_amount), 0) AS lifetime_value
                FROM customers.customers c
                LEFT JOIN sales.orders o ON c.cust_id = o.cust_id
                    AND o.order_status NOT IN ('Cancelled', 'Returned')
                GROUP BY c.cust_id
            )
            SELECT
                CASE
                    WHEN lifetime_value >= 10000 THEN 'Platinum'
                    WHEN lifetime_value >= 5000 THEN 'Gold'
                    WHEN lifetime_value >= 2000 THEN 'Silver'
                    WHEN lifetime_value >= 500 THEN 'Bronze'
                    ELSE 'New'
                END AS segment,
                COUNT(*) AS customer_count,
                ROUND(SUM(lifetime_value)::NUMERIC, 2) AS total_revenue,
                ROUND(AVG(lifetime_value)::NUMERIC, 2) AS avg_clv
            FROM customer_clv
            GROUP BY 1
        ) sub
    )
);


-- ============================================================
-- EXPORT 5: store_performance.json
-- ============================================================
SELECT json_build_object(
    'generated_at', NOW(),
    'data', (
        SELECT json_agg(
            json_build_object(
                'store_name', store_name,
                'city', city,
                'region', region,
                'revenue', revenue,
                'orders', total_orders,
                'performance_tier', performance_tier
            ) ORDER BY revenue DESC
        )
        FROM (
            SELECT
                s.store_name,
                s.city,
                s.region,
                ROUND(SUM(o.total_amount)::NUMERIC, 2) AS revenue,
                COUNT(o.order_id) AS total_orders,
                CASE
                    WHEN PERCENT_RANK() OVER (ORDER BY SUM(o.total_amount)) >= 0.8 THEN 'Star'
                    WHEN PERCENT_RANK() OVER (ORDER BY SUM(o.total_amount)) >= 0.5 THEN 'Average'
                    ELSE 'Needs Attention'
                END AS performance_tier
            FROM stores.stores s
            LEFT JOIN sales.orders o ON s.store_id = o.store_id
                AND o.order_status NOT IN ('Cancelled', 'Returned')
            GROUP BY s.store_id, s.store_name, s.city, s.region
        ) sub
    )
);


-- ============================================================
-- EXPORT 6: top_products.json
-- ============================================================
SELECT json_build_object(
    'generated_at', NOW(),
    'data', (
        SELECT json_agg(
            json_build_object(
                'product_name', prod_name,
                'category', category,
                'brand', brand,
                'revenue', revenue,
                'units_sold', units_sold
            )
        )
        FROM (
            SELECT
                p.prod_name,
                p.category,
                p.brand,
                ROUND(SUM(oi.quantity * oi.unit_price)::NUMERIC, 2) AS revenue,
                SUM(oi.quantity) AS units_sold
            FROM products.products p
            JOIN sales.order_items oi ON p.prod_id = oi.prod_id
            JOIN sales.orders o ON oi.order_id = o.order_id
            WHERE o.order_status NOT IN ('Cancelled', 'Returned')
            GROUP BY p.prod_id, p.prod_name, p.category, p.brand
            ORDER BY revenue DESC
            LIMIT 10
        ) sub
    )
);
