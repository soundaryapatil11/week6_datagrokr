-- SQL DE Pipeline: PostgreSQL 15+
-- Run from project root:
-- psql -U postgres -d sql_de_pipeline -v ON_ERROR_STOP=1 -f pipeline.sql
-- Demo script: drops and recreates its own tables on every run.

BEGIN;
DROP TABLE IF EXISTS fact_sales CASCADE;
DROP TABLE IF EXISTS stg_sales;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS stg_customers;

CREATE TABLE stg_customers (
 customer_id BIGINT PRIMARY KEY,
 customer_name TEXT NOT NULL,
 email TEXT NOT NULL,
 city TEXT,
 segment TEXT NOT NULL,
 updated_at TIMESTAMP NOT NULL
);
CREATE TABLE stg_sales (
 sale_id BIGINT NOT NULL,
 sale_date DATE NOT NULL,
 customer_id BIGINT NOT NULL,
 product_id BIGINT NOT NULL,
 quantity INTEGER NOT NULL CHECK (quantity > 0),
 unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
 status TEXT NOT NULL CHECK (status IN ('COMPLETED','PENDING','CANCELLED')),
 PRIMARY KEY (sale_id, sale_date)
);

-- psql client-side bulk load; run psql from this folder.
\copy stg_customers (customer_id, customer_name, email, city, segment, updated_at) FROM 'data/customers.csv' WITH (FORMAT csv, HEADER true)
\copy stg_sales (sale_id, sale_date, customer_id, product_id, quantity, unit_price, status) FROM 'data/sales.csv' WITH (FORMAT csv, HEADER true)

CREATE TABLE dim_customer (
 customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 customer_id BIGINT NOT NULL UNIQUE,
 customer_name TEXT NOT NULL,
 email TEXT NOT NULL,
 city TEXT NOT NULL DEFAULT 'Unknown',
 segment TEXT NOT NULL,
 source_updated_at TIMESTAMP NOT NULL,
 warehouse_updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

MERGE INTO dim_customer AS target
USING stg_customers AS source
ON target.customer_id = source.customer_id
WHEN MATCHED AND source.updated_at >= target.source_updated_at THEN
 UPDATE SET customer_name = source.customer_name,
            email = source.email,
            city = COALESCE(source.city, 'Unknown'),
            segment = source.segment,
            source_updated_at = source.updated_at,
            warehouse_updated_at = CURRENT_TIMESTAMP
WHEN NOT MATCHED THEN
 INSERT (customer_id, customer_name, email, city, segment, source_updated_at)
 VALUES (source.customer_id, source.customer_name, source.email,
         COALESCE(source.city, 'Unknown'), source.segment, source.updated_at);

CREATE TABLE fact_sales (
 sale_id BIGINT NOT NULL,
 sale_date DATE NOT NULL,
 customer_key BIGINT NOT NULL REFERENCES dim_customer(customer_key),
 customer_id BIGINT NOT NULL,
 product_id BIGINT NOT NULL,
 quantity INTEGER NOT NULL CHECK (quantity > 0),
 unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
 status TEXT NOT NULL CHECK (status IN ('COMPLETED','PENDING','CANCELLED')),
 sales_amount NUMERIC(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
 loaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (sale_id, sale_date)
) PARTITION BY RANGE (sale_date);

CREATE TABLE fact_sales_2025 PARTITION OF fact_sales
 FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE fact_sales_2026 PARTITION OF fact_sales
 FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE fact_sales_default PARTITION OF fact_sales DEFAULT;

INSERT INTO fact_sales
 (sale_id, sale_date, customer_key, customer_id, product_id, quantity, unit_price, status)
SELECT s.sale_id, s.sale_date, c.customer_key, s.customer_id, s.product_id,
       s.quantity, s.unit_price, s.status
FROM stg_sales s
JOIN dim_customer c ON c.customer_id = s.customer_id
ON CONFLICT (sale_id, sale_date) DO UPDATE SET
 customer_key = EXCLUDED.customer_key,
 customer_id = EXCLUDED.customer_id,
 product_id = EXCLUDED.product_id,
 quantity = EXCLUDED.quantity,
 unit_price = EXCLUDED.unit_price,
 status = EXCLUDED.status,
 loaded_at = CURRENT_TIMESTAMP;

CREATE INDEX idx_fact_sales_customer_date ON fact_sales (customer_id, sale_date);
CREATE INDEX idx_fact_sales_product_date ON fact_sales (product_id, sale_date);
CREATE INDEX idx_fact_sales_completed_date ON fact_sales (sale_date)
 WHERE status = 'COMPLETED';

ANALYZE dim_customer;
ANALYZE fact_sales;
COMMIT;

SELECT 'stg_customers' AS table_name, COUNT(*) AS row_count FROM stg_customers
UNION ALL SELECT 'stg_sales', COUNT(*) FROM stg_sales
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'fact_sales', COUNT(*) FROM fact_sales;

SELECT tableoid::regclass AS partition_name, COUNT(*) AS row_count
FROM fact_sales GROUP BY tableoid ORDER BY partition_name;
