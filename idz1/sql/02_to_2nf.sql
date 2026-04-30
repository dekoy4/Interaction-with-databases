-- sql/02_to_2nf.sql
-- Приводим к 2NF: устраняем частичные зависимости.
-- Выделяем сущности: customers, products, orders, order_items.

-- 1. Таблица клиентов
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    email         TEXT NOT NULL UNIQUE,
    phone         TEXT
);

-- 2. Таблица товаров
CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    price         NUMERIC NOT NULL CHECK (price > 0),
    -- Уникальность по имени и цене (для простоты)
    CONSTRAINT uk_product_name_price
      UNIQUE (name, price)
);

-- 3. Таблица заказов
CREATE TABLE orders (
    order_id      INTEGER PRIMARY KEY,
    customer_id   INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date    DATE NOT NULL,
    delivery_address TEXT NOT NULL,
    total_amount  NUMERIC NOT NULL CHECK (total_amount >= 0),
    status        TEXT NOT NULL
        CHECK (status IN ('new', 'processing', 'shipped', 'delivered', 'cancelled'))
);

-- 4. Таблица позиций заказа
CREATE TABLE order_items (
    item_id       SERIAL PRIMARY KEY,
    order_id      INTEGER NOT NULL REFERENCES orders(order_id),
    product_id    INTEGER NOT NULL REFERENCES products(product_id),
    quantity      INTEGER NOT NULL CHECK (quantity > 0),
    price_at_order NUMERIC NOT NULL CHECK (price_at_order > 0)
);

-- 5. Заполнить customers из orders_1nf
INSERT INTO customers (name, email, phone)
SELECT DISTINCT customer_name, customer_email, customer_phone
FROM orders_1nf
WHERE customer_name IS NOT NULL
  AND customer_email IS NOT NULL
ORDER BY customer_name, customer_email;

-- 6. Заполнить products из orders_1nf
INSERT INTO products (name, price)
SELECT DISTINCT product_name, product_price
FROM orders_1nf
WHERE product_name IS NOT NULL
  AND product_price IS NOT NULL
ORDER BY product_name, product_price;

-- 7. Заполнить orders (без деталей позиций)
INSERT INTO orders (order_id, customer_id, order_date, delivery_address, total_amount, status)
SELECT DISTINCT
    o1.order_id,
    c.customer_id,
    o1.order_date,
    o1.delivery_address,
    o1.total_amount,
    o1.status
FROM orders_1nf o1
JOIN customers c ON c.name = o1.customer_name
                AND c.email = o1.customer_email;

-- 8. Заполнить order_items
INSERT INTO order_items (order_id, product_id, quantity, price_at_order)
SELECT
    o1.order_id,
    p.product_id,
    o1.quantity,
    o1.product_price
FROM orders_1nf o1
JOIN products p ON p.name = o1.product_name
               AND p.price = o1.product_price;

-- 9. Проверить, например, заказ 1
-- SELECT *
-- FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
-- WHERE o.order_id = 1;