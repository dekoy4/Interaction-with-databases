# Interaction-with-databases

Лабораторная работа по взаимодействию с базами данных.  
Реализована схема интернет‑магазина (заказы, клиенты, товары, категории, адреса) с OLTP‑ и элементами OLAP‑нагрузки.

---

## Структура репозитория

- `sql/` — SQL‑скрипты по частям задания:
  - `01_*` — создание схемы (1NF → 3NF).
  - `04_oltp_queries.sql` — OLTP‑запросы (создание, обновление и чтение заказов).
  - `05_indexes.sql` — индексы для ускорения запросов.
  - `06_denorm_mv.sql` — материализованное представление для отчётов.
  - `07_denorm_table.sql` — денормализация в таблицу (избыточные поля).

- `checks/` — файлы планов `EXPLAIN ANALYZE`:
  - `explain_oltp_before_indexes.txt` — план запроса к заказу `2001` до индексов.
  - `explain_oltp_after_indexes.txt` — план этого же запроса после создания индексов.
  - `explain_oltp_before_indexes` и отдельные `EXPLAIN` для MV (при необходимости).

---

## 1–3. Нормализация и OLTP‑нагрузка

Схема БД построена по принципам **1NF → 2NF → 3NF**:

- таблицы: `customers`, `orders`, `order_items`, `products`, `categories`, `addresses`;
- связи организованы через внешние ключи;
- отсутствует избыточность данных на уровне сущностей.

В `sql/04_oltp_queries.sql` реализована типичная OLTP‑нагрузка:

- создание заказа в транзакции с `SELECT FOR UPDATE` по товару;
- `INSERT` в `orders` и `order_items`;
- `UPDATE` статуса заказа;
- `JOIN`‑запрос по 4+ таблицам для получения деталей заказа;
- `EXPLAIN ANALYZE` по `order_id = 2001` для оценки производительности.

---

## 4. Денормализация

### 4.1. Материализованное представление для отчётов

Создано материализованное представление:

```sql
CREATE MATERIALIZED VIEW mv_monthly_sales AS
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
GROUP BY 1, 2, 3;
```

- используется для быстрых аналитических отчётов по ежемесячным продажам;
- ускорение чтения за счёт предварительного агрегированного хранения;
- требуется периодическое `REFRESH MATERIALIZED VIEW mv_monthly_sales`.

Сравнение `EXPLAIN ANALYZE` запроса к `mv_monthly_sales` и аналогичного «вручную» с `GROUP BY` по 4 таблицам показывает разницу в `Execution Time` и нагрузке на OLTP‑часть.

### 4.2. Денормализация в таблицу

В таблицу `orders` добавлено избыточное поле:

```sql
ALTER TABLE orders ADD COLUMN customer_name TEXT;

UPDATE orders o
SET customer_name = c.name
FROM customers c
WHERE c.customer_id = o.customer_id;

CREATE INDEX IF NOT EXISTS idx_orders_customer_name ON orders(customer鄢_name);
```

- `customer_name` ускоряет поиск по имени клиента без `JOIN` к `customers`;
- хранит «имя на момент заказа», что полезно для аудита и отчётов;
- требует синхронизации при обновлении `customers.name` (через триггеры или бизнес‑логику).

Денормализация оправдана, когда запросы по имени клиента часты, а обновления `customers.name` встречаются редко.

---

## 5. Индексы

В `sql/05_indexes.sql` созданы следующие индексы:

- базовые B‑tree по внешним и первичным ключам:
  - `idx_orders_customer_id`, `idx_orders_address_id`, `idx_order_items_order_id`, `idx_order_items_product_id`;
- индекс по дате заказа: `idx_orders_order_date` (ускоряет сортировку и диапазонные запросы);
- индекс по `email` клиента: `idx_customers_email`;
- `GIN`‑индекс с `pg_trgm` по `customers.name` для ускорения `ILIKE`‑поиска:
  - `CREATE INDEX idx_customers_name_gin ON customers USING gin (name gin_trgm_ops);`
- индекс по `mv_monthly_sales(month, total_revenue DESC)` для ускорения отчётов;
- индекс по `orders.customer_name` для быстрого поиска по имени.

Сравнение `checks/explain_oltp_before_indexes.txt` и `checks/explain_oltp_after_indexes.txt` показывает:

- снижение `Execution Time`;
- уменьшение `Seq Scan` и переход на `Index Scan`;
- ускорение `ORDER BY` и `WHERE` по ключевым полям.

---

## 6. Сравнительная таблица OLTP vs OLAP

| Характеристика                  | OLTP                                  | OLAP / отчёты в нашем проекте                           |
|---------------------------------|----------------------------------------|--------------------------------------------------------|
| **Основная цель**              | Обработка текущих операций (заказы, платёжки) | Анализ истории, отчёты, дашборды                     |
| **Структура данных**           | Нормализованная 3NF, много таблиц    | Частично денормализованная (MV, `orders.customer_name`) |
| **Тип запросов**               | Простые `INSERT`/`UPDATE`/`SELECT` по ключам | Сложные `GROUP BY`, агрегации, `JOIN` по большим наборам |
| **Типичный запрос**            | `SELECT ... WHERE order_id = 2001`   | `SELECT ... GROUP BY month, product_name` (MV)        |
| **Информация во времени**      | Текущие транзакции                   | Исторические данные по месяцам, категориям, клиентам   |
| **Избыточность**               | Минимальная, нормализация 3NF        | Денормализация (MV, материализованные поля)           |
| **Тип операций**               | Много операций записи                | Преимущественно чтение                                |
| **Пример использования**       | Создать заказ, обновить статус       | Топ‑10 товаров, ежемесячные продажи                   |

В рамках проекта:

- OLTP‑нагрузка реализована в `04_oltp_queries.sql`: операции с заказами, клиентами и позициями заказов;
- элементы OLAP‑стиля реализованы через `mv_monthly_sales` и избыточное поле `orders.customer_name`, ускоряющее отчёты и аналитические запросы.

---

## Как запустить и проверить

1. Запустить контейнер Postgres (если ещё не запущен):
   ```bash
   docker start postgres-idz1
   ```

2. Залить и выполнить SQL‑скрипты (например):
   ```bash
   docker cp sql/05_indexes.sql postgres-idz1:/tmp/05_indexes.sql
   docker exec -it postgres-idz1 psql -U postgres -d idz1 -f /tmp/05_indexes.sql
   ```

3. Посмотреть результаты запросов и планы:
   ```bash
   type checks\explain_oltp_before_indexes.txt
   type checks\explain_oltp_after_indexes.txt
   ```
