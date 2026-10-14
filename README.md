# SQL DE Pipeline

A PostgreSQL data-engineering mini-project demonstrating CSV bulk loading, dimension upserts with `MERGE`, range partitioning, and composite/partial indexes.

## Requirements
- PostgreSQL 15+ (`MERGE` support)
- `psql` command-line client
- No Python packages required

## Files
- `pipeline.sql` — creates tables, bulk-loads CSV data, merges the customer dimension, loads the partitioned fact table, and creates indexes.
- `queries.sql` — analytical and validation queries.
- `data/customers.csv` — sample customer records.
- `data/sales.csv` — sample sales records.
- `.gitignore` — repository exclusions.

## Run
Create an empty PostgreSQL database named `sql_de_pipeline`, then open a terminal **in this project folder** and run:

```bash
psql -U postgres -d sql_de_pipeline -v ON_ERROR_STOP=1 -f pipeline.sql
```

Run the reports:

```bash
psql -U postgres -d sql_de_pipeline -f queries.sql
```

Replace `postgres` with your PostgreSQL username if needed. Enter your PostgreSQL password when prompted. The `\copy` commands read the CSV files from the client, so run `psql` from the project root.

## Concepts demonstrated
- **MERGE:** updates an existing customer by business key or inserts a new customer.
- **Range partitioning:** `fact_sales` partitions rows by `sale_date` into 2025, 2026, and a default partition.
- **Bulk loading:** `\copy` imports local CSV files into staging tables.
- **Composite indexes:** `(customer_id, sale_date)` and `(product_id, sale_date)`.
- **Partial index:** indexes only records where `status = 'COMPLETED'`.
- **Query analysis:** `EXPLAIN` shows the planner's execution strategy.

The script drops and recreates its demo tables each run. Do not run it against a database containing data you need to keep. Sample data is synthetic and intended for educational use.
