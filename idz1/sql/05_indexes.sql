-- sql/05_indexes.sql
-- Индексы для ускорения OLTP и отчётов

-- 1. Базовые индексы для OLTP (по внешним и первичным ключам)
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_address_id ON orders(address_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- 2. Индекс для ускорения сортировки по дате (OLTP, отчёты)
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders(order_date);

-- 3. Индекс для поиска клиента по email (уникальный)
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);

-- 4. pg_trgm для поиска по подстроке в имени клиента
-- Сначала подключим расширение (если ещё не создан)
CREATE EXTENSION IF NOT EXISTS pg_trgm
SCHEMA public;

-- Теперь индекс GIN для ILIKE
CREATE INDEX IF NOT EXISTS idx_customers_name_gin
ON customers USING gin (name gin_trgm_ops);

-- 5. Индекс для материализованного представления mv_monthly_sales
CREATE INDEX IF NOT EXISTS idx_mv_monthly_sales_month
ON mv_monthly_sales(month, total_revenue DESC);

-- 6. Индекс для избыточного поля customer_name в orders
CREATE INDEX IF NOT EXISTS idx_orders_customer_name
ON orders(customer_name);