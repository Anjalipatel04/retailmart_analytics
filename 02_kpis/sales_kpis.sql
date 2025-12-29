-- ============================================================
-- SALES KPIs
-- Purpose: All sales-related metrics for dashboard
-- ============================================================

-- ============================================================
-- KPI 1: SALES OVERVIEW (For KPI Cards)
-- Shows: Total Revenue, Orders, Customers, AOV
-- ============================================================
SELECT
    ROUND(SUM(total_amount)::NUMERIC, 2) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT cust_id) AS total_customers,
    ROUND(AVG(total_amount)::NUMERIC, 2) AS avg_order_value,
    ROUND(SUM(total_amount) / COUNT(DISTINCT cust_id), 2) AS revenue_per_customer
FROM sales.orders
WHERE order_status NOT IN ('Cancelled', 'Returned');


-- ============================================================
-- KPI 2: MONTHLY REVENUE TREND (For Line Chart)
-- Shows: Revenue progression over months
-- ============================================================
WITH monthly_data AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS month,
        SUM(total_amount) AS revenue,
        COUNT(DISTINCT order_id) AS orders,
        COUNT(DISTINCT cust_id) AS customers
    FROM sales.orders
    WHERE order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    TO_CHAR(month, 'Mon YYYY') AS month_label,
    month AS month_date,
    ROUND(revenue::NUMERIC, 2) AS revenue,
    orders,
    customers,
    ROUND(revenue / NULLIF(orders, 0), 2) AS aov,
    -- Month-over-month growth
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) /
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100,
        1
    ) AS mom_growth_pct
FROM monthly_data
ORDER BY month;


-- ============================================================
-- KPI 3: REVENUE BY CATEGORY (For Pie/Donut Chart)
-- Shows: Which product categories drive revenue
-- ============================================================
SELECT
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100))::NUMERIC, 2) AS revenue,
    SUM(oi.quantity) AS units_sold,
    COUNT(DISTINCT o.order_id) AS order_count,
    -- Percentage of total
    ROUND(
        SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100)) /
        SUM(SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100))) OVER () * 100,
        1
    ) AS pct_of_total
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
JOIN products.products p ON oi.prod_id = p.prod_id
WHERE o.order_status NOT IN ('Cancelled', 'Returned')
GROUP BY p.category
ORDER BY revenue DESC;


-- ============================================================
-- KPI 4: REVENUE BY REGION (For Bar Chart)
-- Shows: Geographic performance
-- ============================================================
SELECT
    s.region,
    COUNT(DISTINCT s.store_id) AS store_count,
    ROUND(SUM(o.total_amount)::NUMERIC, 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.cust_id) AS customers,
    ROUND(AVG(o.total_amount)::NUMERIC, 2) AS avg_order_value
FROM sales.orders o
JOIN stores.stores s ON o.store_id = s.store_id
WHERE o.order_status NOT IN ('Cancelled', 'Returned')
GROUP BY s.region
ORDER BY revenue DESC;


-- ============================================================
-- KPI 5: DAILY SALES TREND (Last 30 Days)
-- Shows: Recent daily performance
-- ============================================================
SELECT
    order_date::DATE AS sale_date,
    TO_CHAR(order_date, 'Dy') AS day_name,
    ROUND(SUM(total_amount)::NUMERIC, 2) AS revenue,
    COUNT(DISTINCT order_id) AS orders,
    -- 7-day moving average
    ROUND(
        AVG(SUM(total_amount)) OVER (
            ORDER BY order_date::DATE
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        )::NUMERIC,
        2
    ) AS moving_avg_7d
FROM sales.orders
WHERE order_status NOT IN ('Cancelled', 'Returned')
    AND order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY order_date::DATE, TO_CHAR(order_date, 'Dy')
ORDER BY sale_date;


-- ============================================================
-- KPI 6: TOP 10 PRODUCTS BY REVENUE
-- Shows: Best performing products
-- ============================================================
SELECT
    p.prod_id,
    p.prod_name,
    p.category,
    p.brand,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - COALESCE(oi.discount, 0)/100))::NUMERIC, 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS order_count,
    ROUND(AVG(oi.unit_price)::NUMERIC, 2) AS avg_selling_price
FROM sales.orders o
JOIN sales.order_items oi ON o.order_id = oi.order_id
JOIN products.products p ON oi.prod_id = p.prod_id
WHERE o.order_status NOT IN ('Cancelled', 'Returned')
GROUP BY p.prod_id, p.prod_name, p.category, p.brand
ORDER BY revenue DESC
LIMIT 10;
