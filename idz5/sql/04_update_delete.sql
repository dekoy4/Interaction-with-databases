-- 1. Исходная запись
SELECT id, title, price, rating FROM products LIMIT 1;

-- 2. UPDATE - обновление цены и рейтинга
UPDATE products SET price = 99999.99, rating = 4.9 WHERE id = 1;

-- 3. Проверка UPDATE
SELECT id, title, price, rating FROM products WHERE id = 1;

-- 4. DELETE
DELETE FROM products WHERE id = 1;

-- 5. Проверка DELETE
SELECT COUNT(*) FROM products WHERE id = 1;

-- 6. REPLACE
REPLACE INTO products (id, title, description, category, brand, price, rating, reviews_count, in_stock, tags, created_at)
VALUES (1, 'Replaced Product', 'This is a replaced product description', 'Test Category', 'Test Brand', 50000.00, 4.5, 100, 1, '{"color":"red"}', NOW());

-- 7. Проверка REPLACE
SELECT id, title, price, rating FROM products WHERE id = 1;
