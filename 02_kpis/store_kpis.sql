-- ============================================================
-- STORE KPIs
-- Purpose: Store performance metrics
-- ============================================================

-- ============================================================
-- KPI 11: STORE PERFORMANCE RANKING
-- Shows: Complete store comparison
-- ============================================================
WITH store_sales AS (
    SELECT
        s.store_id,
        s.store_name,
        s.city,
        s.state,
        s.region,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT o.cust_id) AS unique_customers,
        COALESCE(SUM(o.total_amount), 0) AS revenue
    FROM stores.stores s
    LEFT JOIN sales.orders o ON s.store_id = o.store_id
        AND o.order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY s.store_id, s.store_name, s.city, s.state, s.region
),
store_expenses AS (
    SELECT
        store_id,
        COALESCE(SUM(amount), 0) AS total_expenses
    FROM stores.expenses
    GROUP BY store_id
)
SELECT
    ss.store_id,
    ss.store_name,
    ss.city,
    ss.region,
    ss.total_orders,
    ss.unique_customers,
    ROUND(ss.revenue::NUMERIC, 2) AS revenue,
    ROUND(COALESCE(se.total_expenses, 0)::NUMERIC, 2) AS expenses,
    ROUND((ss.revenue - COALESCE(se.total_expenses, 0))::NUMERIC, 2) AS profit,
    -- Profit margin
    ROUND(
        CASE WHEN ss.revenue > 0 THEN
            (ss.revenue - COALESCE(se.total_expenses, 0)) / ss.revenue * 100
        ELSE 0 END::NUMERIC,
        1
    ) AS profit_margin_pct,
    -- AOV
    ROUND(
        CASE WHEN ss.total_orders > 0 THEN
            ss.revenue / ss.total_orders
        ELSE 0 END::NUMERIC,
        2
    ) AS avg_order_value,
    -- Rankings
    RANK() OVER (ORDER BY ss.revenue DESC) AS overall_rank,
    RANK() OVER (PARTITION BY ss.region ORDER BY ss.revenue DESC) AS regional_rank,
    -- Performance tier
    CASE
        WHEN PERCENT_RANK() OVER (ORDER BY ss.revenue) >= 0.8 THEN 'Star'
        WHEN PERCENT_RANK() OVER (ORDER BY ss.revenue) >= 0.5 THEN 'Average'
        WHEN PERCENT_RANK() OVER (ORDER BY ss.revenue) >= 0.2 THEN 'Improving'
        ELSE 'Needs Attention'
    END AS performance_tier
FROM store_sales ss
LEFT JOIN store_expenses se ON ss.store_id = se.store_id
ORDER BY ss.revenue DESC;


-- ============================================================
-- KPI 12: REGION SUMMARY (For Dashboard)
-- Shows: Aggregated regional performance
-- ============================================================
SELECT
    s.region,
    COUNT(DISTINCT s.store_id) AS store_count,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.cust_id) AS unique_customers,
    ROUND(SUM(o.total_amount)::NUMERIC, 2) AS total_revenue,
    ROUND(AVG(o.total_amount)::NUMERIC, 2) AS avg_order_value,
    ROUND(
        SUM(o.total_amount) / COUNT(DISTINCT s.store_id)::NUMERIC,
        2
    ) AS revenue_per_store
FROM stores.stores s
LEFT JOIN sales.orders o ON s.store_id = o.store_id
    AND o.order_status NOT IN ('Cancelled', 'Returned')
GROUP BY s.region
ORDER BY total_revenue DESC;
