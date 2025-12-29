CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.kpi_metadata CASCADE;
CREATE TABLE analytics.kpi_metadata (
    kpi_id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kpi_name            VARCHAR(100) NOT NULL UNIQUE,
    kpi_category        VARCHAR(50) NOT NULL,
    description         TEXT,
    formula             TEXT,
    source_tables       TEXT,
    owner               VARCHAR(100) DEFAULT CURRENT_USER,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

DROP TABLE IF EXISTS analytics.execution_log CASCADE;
CREATE TABLE analytics.execution_log (
    log_id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kpi_name            VARCHAR(100) NOT NULL,
    executed_at         TIMESTAMP NOT NULL DEFAULT NOW(),
    execution_time_ms   INTEGER,
    rows_returned       INTEGER,
    status              VARCHAR(20) NOT NULL DEFAULT 'SUCCESS'
                        CHECK (status IN ('SUCCESS','FAILED','PARTIAL')),
    error_message       TEXT
);

CREATE INDEX idx_execution_log_kpi_name
    ON analytics.execution_log (kpi_name);

DROP TABLE IF EXISTS analytics.refresh_history CASCADE;
CREATE TABLE analytics.refresh_history (
    refresh_id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data_file           VARCHAR(100) NOT NULL,
    refreshed_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    record_count        INTEGER,
    file_size_kb        NUMERIC(10,2)
);

CREATE INDEX idx_refresh_history_file
    ON analytics.refresh_history (data_file);

INSERT INTO analytics.kpi_metadata
(kpi_name, kpi_category, description, formula, source_tables) VALUES
('total_revenue', 'Sales', 'Total revenue from all completed orders',
 'SUM(total_amount) WHERE status != ''Cancelled''', 'sales.orders'),
('order_count', 'Sales', 'Total number of orders',
 'COUNT(DISTINCT order_id)', 'sales.orders'),
('avg_order_value', 'Sales', 'Average value per order',
 'SUM(total_amount) / COUNT(order_id)', 'sales.orders'),
('customer_lifetime_value', 'Customer', 'Total revenue per customer',
 'SUM(total_amount) GROUP BY cust_id', 'sales.orders, customers.customers'),
('customer_count', 'Customer', 'Total unique customers',
 'COUNT(DISTINCT cust_id)', 'customers.customers'),
('store_revenue', 'Store', 'Revenue by store',
 'SUM(total_amount) GROUP BY store_id', 'sales.orders, stores.stores'),
('product_sales', 'Product', 'Units sold by product',
 'SUM(quantity) GROUP BY prod_id', 'sales.order_items, products.products');

SELECT 'Analytics schema created successfully!' AS status;
SELECT * FROM analytics.kpi_metadata;
