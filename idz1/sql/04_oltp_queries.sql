-- sql/04_oltp_queries.sql
-- OLTP-нагрузка на нормализованной схеме (3NF)


-- 1. Создание заказа (транзакция с проверкой и блокировкой)
-- Только этот блок должен быть в явной транзакции, чтобы не повешать весь скрипт

-- Проверим, что товар есть, и заблокируем его цену (SELECT FOR UPDATE)
SELECT product_id, price
FROM products
WHERE name = 'Ноутбук Dell XPS'
FOR UPDATE;

-- Вставляем заказ (orders)
INSERT INTO orders (order_id, customer_id, address_id, order_date, status, total_amount)
VALUES (2001, 1, 1, CURRENT_DATE, 'new', 85000);

-- Вставляем позицию заказа (order_items)
INSERT INTO order_items (order_id, product.card, quantity, price_at_order)
VALUES (2001, 1, 1, 85000);


-- 2. Проверить, что заказ создался
SELECT *
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_id = 2001;


-- 3. Обновление статуса заказа (не нужно отдельной транзакции, autocommit достаточно)
UPDATE orders
SET status = 'shipped'
WHERE order_id = 2001;

-- Проверить обновление
SELECT order_id, order_date, status
FROM orders
WHERE order_id = 2001;


-- 4. Получение заказа (JOIN по 4 таблицам) — уже без транзакции
EXPLAIN ANALYZE
SELECT
    o.order_id,
    o.order_date,
    o.status,
    o.total_amount,
    c.name AS customer_name,
    a.address AS delivery_address,
    p.name AS product_name,
    oi.quantity,
    oi.price_at_order
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN addresses a ON a.address_id = o.address_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.order_id = 1
ORDER BY 1, 2;


-- 5. Отчёт «топ‑10 товаров» (агрегация по order_items)
EXPLAIN ANALYZE
SELECT
    p.name AS product_name,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * oi.price_at_order) AS total_revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name
ORDER BY total_revenue DESC
LIMIT 10;


-- 6. Поиск клиента по email (поиск по уникальному ключу)
-- EXPLAIN ANALYZE (его добавим позже, в части 5, с индексами)
SELECT *
FROM customers
WHERE email = 'example@email.com';


-- 7. Поиск клиента по части имени (подстрока)
-- EXPLAIN ANALYZE добавим позже, с индексом pg_trgm
SELECT *
FROM customers
WHERE name ILIKE '%Иван%';


-- 8. 4.1. Запрос к MV mv_monthly_sales
EXPLAIN ANALYZE
SELECT *
FROM mv_monthly_sales
WHERE month = '2025-01-01';


-- 9. 4.2. Аналогичный запрос к нормализованным таблицам (без MV)
EXPLAIN ANALYZE
SELECT
    DATE_TRUNC('month', o.order_date) AS month,
    p.name AS product_name,
    c.name AS category_name,
    SUM(oi.quantity) AS total_qty,
    SUM(oi.quantity * oi.price_at_order) AS total_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.order_date >= '2025-01-01'
  AND o.order_date < '2025-02-01'
GROUP BY 1, 2, 3;