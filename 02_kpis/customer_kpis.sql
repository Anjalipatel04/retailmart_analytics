-- ============================================================
-- CUSTOMER KPIs
-- Purpose: Customer behavior and segmentation metrics
-- ============================================================

-- ============================================================
-- KPI 7: CUSTOMER LIFETIME VALUE (CLV)
-- Shows: How much each customer is worth
-- ============================================================
SELECT
    c.cust_id,
    c.full_name,
    c.city,
    c.state,
    c.join_date,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COALESCE(SUM(o.total_amount), 0)::NUMERIC, 2) AS lifetime_value,
    ROUND(COALESCE(AVG(o.total_amount), 0)::NUMERIC, 2) AS avg_order_value,
    MIN(o.order_date) AS first_order,
    MAX(o.order_date) AS last_order,
    CURRENT_DATE - MAX(o.order_date) AS days_since_last_order,
    -- CLV Segment
    CASE
        WHEN SUM(o.total_amount) >= 10000 THEN 'Platinum'
        WHEN SUM(o.total_amount) >= 5000 THEN 'Gold'
        WHEN SUM(o.total_amount) >= 2000 THEN 'Silver'
        WHEN SUM(o.total_amount) >= 500 THEN 'Bronze'
        ELSE 'New'
    END AS clv_segment
FROM customers.customers c
LEFT JOIN sales.orders o ON c.cust_id = o.cust_id
    AND o.order_status NOT IN ('Cancelled', 'Returned')
GROUP BY c.cust_id, c.full_name, c.city, c.state, c.join_date
ORDER BY lifetime_value DESC;


-- ============================================================
-- KPI 8: CUSTOMER SEGMENT SUMMARY (For Dashboard Cards)
-- Shows: Distribution across CLV segments
-- ============================================================
WITH customer_clv AS (
    SELECT
        c.cust_id,
        COALESCE(SUM(o.total_amount), 0) AS lifetime_value
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
    ROUND(AVG(lifetime_value)::NUMERIC, 2) AS avg_clv,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers
FROM customer_clv
GROUP BY 1
ORDER BY avg_clv DESC;


-- ============================================================
-- KPI 9: RFM ANALYSIS
-- Shows: Customer segmentation by behavior
-- Recency (days since last purchase)
-- Frequency (number of orders)
-- Monetary (total spend)
-- ============================================================
WITH rfm_base AS (
    SELECT
        c.cust_id,
        c.full_name,
        CURRENT_DATE - MAX(o.order_date) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        COALESCE(SUM(o.total_amount), 0) AS monetary
    FROM customers.customers c
    LEFT JOIN sales.orders o ON c.cust_id = o.cust_id
        AND o.order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY c.cust_id, c.full_name
    HAVING COUNT(o.order_id) > 0
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
)
SELECT
    cust_id,
    full_name,
    recency_days,
    frequency,
    ROUND(monetary::NUMERIC, 2) AS monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_score,
    -- Customer Segment based on RFM
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score >= 4 AND m_score >= 4 THEN 'Big Spenders'
        WHEN r_score >= 4 THEN 'Recent'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Potential'
    END AS rfm_segment
FROM rfm_scores
ORDER BY monetary DESC;


-- ============================================================
-- KPI 10: RFM SEGMENT SUMMARY (For Dashboard)
-- Shows: Count and value by RFM segment
-- ============================================================
WITH rfm_base AS (
    SELECT
        c.cust_id,
        CURRENT_DATE - MAX(o.order_date) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        COALESCE(SUM(o.total_amount), 0) AS monetary
    FROM customers.customers c
    JOIN sales.orders o ON c.cust_id = o.cust_id
        AND o.order_status NOT IN ('Cancelled', 'Returned')
    GROUP BY c.cust_id
),
rfm_segments AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
),
customer_segments AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 4 AND f_score >= 3 THEN 'Loyal'
            WHEN r_score >= 4 AND m_score >= 4 THEN 'Big Spenders'
            WHEN r_score >= 4 THEN 'Recent'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
            ELSE 'Potential'
        END AS segment
    FROM rfm_segments
)
SELECT
    segment,
    COUNT(*) AS customer_count,
    ROUND(SUM(monetary)::NUMERIC, 2) AS total_revenue,
    ROUND(AVG(monetary)::NUMERIC, 2) AS avg_value,
    ROUND(AVG(frequency)::NUMERIC, 1) AS avg_orders,
    ROUND(AVG(recency_days)::NUMERIC, 0) AS avg_recency_days
FROM customer_segments
GROUP BY segment
ORDER BY total_revenue DESC;
