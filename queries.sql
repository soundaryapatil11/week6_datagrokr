-- Run: psql -U postgres -d sql_de_pipeline -f queries.sql

-- 1. Sales by date range (partition pruning candidate)
SELECT sale_date, SUM(sales_amount) AS daily_sales
FROM fact_sales
WHERE sale_date >= DATE '2025-01-01' AND sale_date < DATE '2026-01-01'
GROUP BY sale_date ORDER BY sale_date;

-- 2. Completed sales (partial-index predicate)
SELECT sale_date, sale_id, customer_id, sales_amount
FROM fact_sales
WHERE status = 'COMPLETED' AND sale_date >= DATE '2025-01-01'
ORDER BY sale_date;

-- 3. Customer/date composite-index candidate
SELECT customer_id, sale_date, sale_id, sales_amount
FROM fact_sales
WHERE customer_id = 1001
  AND sale_date >= DATE '2025-01-01' AND sale_date < DATE '2026-01-01'
ORDER BY sale_date;

-- 4. Revenue by customer
SELECT c.customer_name, SUM(f.sales_amount) AS total_sales
FROM fact_sales f JOIN dim_customer c ON c.customer_key = f.customer_key
WHERE f.status = 'COMPLETED'
GROUP BY c.customer_key, c.customer_name ORDER BY total_sales DESC;

-- 5. Revenue and units by product
SELECT product_id, SUM(sales_amount) AS total_sales, SUM(quantity) AS units_sold
FROM fact_sales WHERE status = 'COMPLETED'
GROUP BY product_id ORDER BY total_sales DESC;

-- 6. Sales status summary
SELECT status, COUNT(*) AS sale_count, SUM(sales_amount) AS total_amount
FROM fact_sales GROUP BY status ORDER BY sale_count DESC;

-- 7. Verify partition distribution
SELECT tableoid::regclass AS partition_name, COUNT(*) AS row_count
FROM fact_sales GROUP BY tableoid ORDER BY partition_name;

-- 8. Inspect indexes
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes WHERE tablename LIKE 'fact_sales%'
ORDER BY tablename, indexname;

-- 9. Inspect the query plan
EXPLAIN
SELECT sale_id, sale_date, sales_amount
FROM fact_sales
WHERE sale_date >= DATE '2025-01-01' AND sale_date < DATE '2026-01-01'
  AND status = 'COMPLETED';
