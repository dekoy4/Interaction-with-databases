-- Сравнение Manticore Search и PostgreSQL полнотекстового поиска

-- 1. Создание таблицы в PostgreSQL
CREATE TABLE pg_products (
    id SERIAL PRIMARY KEY,
    title TEXT,
    description TEXT,
    category VARCHAR(100),
    brand VARCHAR(100),
    price DECIMAL(10,2),
    rating DECIMAL(3,1),
    reviews_count INTEGER,
    in_stock BOOLEAN,
    created_at TIMESTAMP
);

-- 2. Добавление tsvector колонки для полнотекстового поиска
ALTER TABLE pg_products ADD COLUMN tsv tsvector
    GENERATED ALWAYS AS (
        setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(description, '')), 'B')
    ) STORED;

-- 3. Создание GIN индекса
CREATE INDEX idx_tsv ON pg_products USING GIN(tsv);

-- 4. Поисковый запрос (аналог basic_search из Manticore)
SELECT id, title, ts_rank(tsv, query) AS rank
FROM pg_products, to_tsquery('english', 'wireless & bluetooth & headphones') query
WHERE tsv @@ query
ORDER BY rank DESC
LIMIT 10;

-- 5. Поиск с фильтрацией (аналог filtered_search из Manticore)
SELECT id, title, price, rating, ts_rank(tsv, query) AS rank
FROM pg_products, to_tsquery('english', 'laptop') query
WHERE tsv @@ query 
    AND price BETWEEN 30000 AND 80000 
    AND rating >= 4.0
ORDER BY rating DESC
LIMIT 10;

-- 6. Агрегация (аналог facets из Manticore)
SELECT category, COUNT(*) as cnt, AVG(price) as avg_price
FROM pg_products
WHERE tsv @@ to_tsquery('english', 'gaming')
GROUP BY category
ORDER BY cnt DESC;
