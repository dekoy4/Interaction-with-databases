-- sql/03_to_3nf.sql
-- Приводим схему к 3NF: устраняем транзитивные зависимости.

-- 1. Таблица категорий
CREATE TABLE categories (
    category_id   SERIAL PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE
);

-- 2. Добавим category_id в products
ALTER TABLE products
ADD COLUMN category_id INTEGER;

-- 3. Заполним несколько примеров категорий
INSERT INTO categories (name) VALUES
('Ноутбуки'),
('Периферия'),
('Хранение'),
('Аксессуары');

-- 4. Назначим категорию каждому продукту (пример)
UPDATE products
SET category_id = 1
WHERE name LIKE '%Ноутбук%';

UPDATE products
SET category_id = 2
WHERE name IN ('Мышь Logitech', 'Клавиатура', 'Коврик');

UPDATE products
SET category_id = 3
WHERE name LIKE '%SSD%'
   OR name LIKE '%HDD%';

UPDATE products
SET category_id = 4
WHERE name LIKE '%кабель%'
   OR name LIKE '%чехол%'
   OR name LIKE '%HDMI%';

-- 5. Сделаем category_id NOT NULL и FK
ALTER TABLE products
ALTER COLUMN category_id SET NOT NULL;

ALTER TABLE products
ADD CONSTRAINT fk_products_category
FOREIGN KEY (category_id)
REFERENCES categories(category_id);

-- 6. Таблица адресов
CREATE TABLE addresses (
    address_id     SERIAL PRIMARY KEY,
    customer_id    INTEGER NOT NULL REFERENCES customers(customer_id),
    address        TEXT NOT NULL,
    is_default     BOOLEAN DEFAULT FALSE
);

-- 7. Перенесём адреса из orders в addresses
INSERT INTO addresses (customer_id, address)
SELECT DISTINCT
    o.customer_id,
    o.delivery_address
FROM orders o
ORDER BY o.customer_id, o.delivery_address;

-- 8. Добавим address_id в orders
ALTER TABLE orders
ADD COLUMN address_id INTEGER NOT NULL
    DEFAULT 1;  -- чтобы временно не было NULL, ниже подправим

-- 9. Свяжем orders с addresses
UPDATE orders o
SET address_id = a.address_id
FROM addresses a
WHERE a.customer_id = o.customer_id
  AND a.address = o.delivery_address;

-- 10. Уберём delivery_address из orders (если хочешь, см. ниже)
-- ALTER TABLE orders DROP COLUMN delivery_address;

-- 11. Делаем address_id внешним ключом
ALTER TABLE orders
ADD CONSTRAINT fk_orders_address
FOREIGN KEY (address_id)
REFERENCES addresses(address_id);

-- 12. Индексы для производительности (опционально)
CREATE INDEX IF NOT EXISTS idx_orders_customer_date ON orders(customer_id, order_date);
CREATE INDEX IF NOT EXISTS idx_order_items_order_product ON order_items(order_id, product_id);

-- 13. Проверить примерный вид заказа 1
-- SELECT
--     o.order_id,
--     o.order_date,
--     o.status,
--     c.name AS customer_name,
--     a.address AS delivery_address,
--     p.name AS product_name,
--     oi.quantity,
--     oi.price_at_order
-- FROM orders o
-- JOIN customers c ON c.customer_id = o.customer_id
-- JOIN addresses a ON a.address_id = o.address_id
-- JOIN order_items oi ON oi.order_id = o.order_id
-- JOIN products p ON p.product_id = oi.product_id
-- WHERE o.order_id = 1
-- ORDER BY 1, 2, 4;