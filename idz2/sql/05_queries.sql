-- 1) Топ-10 товаров по выручке
SELECT 
    product_id,
    product_name,
    SUM(line_total) AS total_revenue
FROM test_db.orders_flat
GROUP BY product_id, product_name
ORDER BY total_revenue DESC
LIMIT 10;

-- 2) Ежемесячная динамика продаж по категориям
SELECT 
    toStartOfMonth(order_date) AS month,
    category,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(quantity) AS total_quantity,
    SUM(line_total) AS total_revenue,
    AVG(line_total) AS avg_order_value
FROM test_db.orders_flat
GROUP BY month, category
ORDER BY month, category;

-- 3) Процентиль p95/p99 стоимости заказа
WITH order_totals AS (
    SELECT 
        order_id,
        SUM(line_total) AS order_total
    FROM test_db.orders_flat
    GROUP BY order_id
)
SELECT 
    quantileExact(0.95)(order_total) AS p95_exact,
    quantileExact(0.99)(order_total) AS p99_exact
FROM order_totals;

-- 4) Поиск клиента по подстроке email (work)
SELECT DISTINCT
    customer_id,
    customer_name,
    customer_email,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(line_total) AS total_spent
FROM test_db.orders_flat
WHERE customer_email LIKE 'quiet.storm@test.example'
GROUP BY customer_id, customer_name, customer_email
ORDER BY total_spent DESC
LIMIT 100;

-- 5) Сравнение результата из orders_flat и monthly_sales (показать, что агрегаты предвычислены)

-- Запрос из orders_flat (с ручной агрегацией):
SELECT 
    toStartOfMonth(month_date) AS month,
    SUM(total_revenue) AS revenue_flat,
    SUM(total_quantity) AS quantity_flat,
    SUM(total_orders) AS orders_flat,
    SUM(unique_customers) AS customers_flat
FROM (
    SELECT 
        toStartOfMonth(order_date) AS month_date,
        SUM(line_total) AS total_revenue,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM test_db.orders_flat
    WHERE order_status = 'delivered'
    GROUP BY month_date, category, region
) AS subquery
GROUP BY month
ORDER BY month;

-- Данные из monthly_sales (предвычисленные агрегаты):
SELECT 
    toStartOfMonth(month_date) AS month,
    SUM(total_revenue) AS revenue_aggregated,
    SUM(total_quantity) AS quantity_aggregated,
    SUM(total_orders) AS orders_aggregated,
    SUM(unique_customers) AS customers_aggregated
FROM test_db.monthly_sales
GROUP BY month
ORDER BY month;

-- Поисковой запрос в orders_flat:
SELECT 
    toStartOfMonth(order_date) AS month,
    category,
    region,
    SUM(line_total) AS revenue
FROM test_db.orders_flat
WHERE order_date >= '2024-01-01' AND order_date < '2024-02-01' AND order_status = 'delivered'
GROUP BY month, category, region;

-- Поисковой запрос в monthly_sales:
SELECT 
    month_date,
    category,
    region,
    total_revenue
FROM test_db.monthly_sales
WHERE month_date >= '2024-01-01' AND month_date < '2024-02-01';
