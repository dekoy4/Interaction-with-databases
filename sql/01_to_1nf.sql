-- sql/01_to_1nf.sql
-- Приводим orders_raw к 1NF: разбиваем составные поля на строки

-- 1. Создаём таблицу orders_1nf
CREATE TABLE orders_1nf (
    order_id          INTEGER NOT NULL,
    order_date        DATE,
    customer_name     TEXT,
    customer_email    TEXT,
    customer_phone    TEXT,
    delivery_address  TEXT,
    product_name      TEXT,
    product_price     NUMERIC,
    quantity          INTEGER,
    total_amount      NUMERIC,
    status            TEXT
);

-- 2. Разбиваем составные поля из orders_raw
INSERT INTO orders_1nf (
    order_id,
    order_date,
    customer_name,
    customer_email,
    customer_phone,
    delivery_address,
    product_name,
    product_price,
    quantity,
    total_amount,
    status
)
SELECT
    o.order_id,
    o.order_date,
    o.customer_name,
    o.customer_email,
    o.customer_phone,
    o.delivery_address,
    TRIM(UNNEST(STRING_TO_ARRAY(o.product_names, ', '))) AS product_name,
    (UNNEST(STRING_TO_ARRAY(o.product_prices, ', ')))::NUMERIC AS product_price,
    (UNNEST(STRING_TO_ARRAY(o.product_quantities, ', ')))::INTEGER AS quantity,
    o.total_amount,
    o.status
FROM orders_raw o
WHERE o.product_names IS NOT NULL
  AND o.product_prices IS NOT NULL
  AND o.product_quantities IS NOT NULL
  AND o.product_names <> ''
  AND o.product_prices <> ''
  AND o.product_quantities <> '';

-- 3. Проверить (можно раскомментировать)
-- SELECT order_id, product_name, product_price, quantity
-- FROM orders_1nf
-- WHERE order_id = 1
-- ORDER BY 1, 2;