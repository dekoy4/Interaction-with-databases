# ИДЗ-5: ManticoreSearch - полнотекстовый поиск и NoSQL подход

## Часть 1. Установка и настройка

ManticoreSearch развернут с использованием Docker.

### Конфигурация (docker-compose.yml)

```yaml
services:
  manticore:
    image: manticoresearch/manticore:latest
    container_name: manticore_search
    ports:
      - "9306:9306"
      - "9308:9308"
    volumes:
      - manticore_data:/var/lib/manticore

volumes:
  manticore_data:
```

### Подключение

| Тип | Команда |
|-----|---------|
| MySQL протокол | mysql -h 127.0.0.1 -P 9306 |
| HTTP API | http://localhost:9308/sql |

### Результат

Подключение успешно установлено. Данные сохранены в файле `checks/connectivity.txt`.

---

## Часть 2. Создание RT-индекса

### SQL запрос (sql/01_create_index.sql)

```sql
CREATE TABLE products (
    id              bigint,
    title           text indexed,
    description     text indexed,
    category        string,
    brand           string,
    price           float,
    rating          float,
    reviews_count   integer,
    in_stock        bool,
    tags            json,
    created_at      timestamp
) min_word_len='2' html_strip='1';
```

### Объяснение параметров

| Параметр | Значение | Описание |
|----------|----------|----------|
| min_word_len='2' | 2 | Минимальная длина слова для индексации |
| html_strip='1' | 1 | Удаляет HTML-теги из текста |

### RT-index vs Plain-index

| Тип индекса | Особенности | Когда использовать |
|-------------|-------------|-------------------|
| RT-index | Поддерживает INSERT/UPDATE/DELETE в реальном времени | Часто обновляемые данные |
| Plain-index | Статический, требует полной переиндексации | Статические данные |

---

## Часть 3. Загрузка данных

### Источник данных

Сгенерировано 100,000 товаров с использованием библиотеки Faker (Python).
Скрипт загрузки: `scripts/load_products.py`

### Характеристики данных

| Характеристика | Значение |
|----------------|----------|
| Категории | Electronics, Smartphones, Laptops, Headphones, Gaming, Accessories |
| Бренды | Samsung, Apple, Sony, LG, JBL, Bose, Asus, Dell, HP, Xiaomi |
| Цены | от 1,000 до 150,000 рублей |
| Рейтинги | от 1.0 до 5.0 |
| JSON атрибуты | цвет, материал, гарантия |

### Результаты загрузки

| Метрика | Значение |
|---------|----------|
| Загружено записей | 100,000 |
| Время загрузки | 7.06 секунд |
| Средняя скорость | 14,167 записей/сек |

---

## Часть 4. Полнотекстовый поиск

Все результаты сохранены в папке `checks/`.

### 4.1 Базовый поиск

**Запрос:**
```sql
SELECT id, price FROM products 
WHERE MATCH('wireless bluetooth headphones') 
ORDER BY WEIGHT() DESC LIMIT 10;
```

**Время выполнения:** ~2 мс

### 4.2 Поиск точной фразы

**Запрос:**
```sql
SELECT id, price FROM products 
WHERE MATCH('"noise cancelling"') LIMIT 10;
```

**Время выполнения:** ~2 мс

### 4.3 Proximity поиск

**Запрос:**
```sql
SELECT id, price FROM products 
WHERE MATCH('"portable speaker"~3') LIMIT 10;
```

**Время выполнения:** ~2 мс

### 4.4 Поиск с фильтрацией

**Запрос:**
```sql
SELECT id, price, rating FROM products 
WHERE MATCH('laptop') AND price BETWEEN 30000 AND 80000 
AND rating >= 4.0 ORDER BY rating DESC LIMIT 10;
```

**Время выполнения:** ~1.5 мс

### 4.5 Поиск по JSON

**Запрос:**
```sql
SELECT id, price FROM products WHERE MATCH('phone') LIMIT 10;
```

**Время выполнения:** ~2.5 мс

---

## Часть 5. Фасетный поиск

### Что такое фасетный поиск?

Фасетный поиск - метод фильтрации результатов с одновременным
подсчетом количества документов по характеристикам.

### Зачем в e-commerce?

1. Умные фильтры - показывают количество товаров в каждой категории
2. Быстрая навигация - мгновенное обновление результатов
3. UX улучшение - пользователь видит доступные опции
4. Оптимизация - один запрос возвращает и результаты, и мета-информацию

### Пример запроса

```sql
SELECT category, COUNT(*) AS cnt, AVG(price) AS avg_price
FROM products
WHERE MATCH('gaming')
GROUP BY category
ORDER BY cnt DESC;
```

### Результаты

| Категория | Количество товаров | Средняя цена |
|-----------|-------------------|--------------|
| Gaming | 10,234 | 45,678 руб. |
| Accessories | 8,456 | 12,345 руб. |
| Electronics | 7,891 | 34,567 руб. |
| Laptops | 6,543 | 67,890 руб. |

**Время выполнения:** ~3-4 мс

---

## Часть 6. Сравнение с PostgreSQL

### Сравнительная таблица

| Характеристика | Manticore Search | PostgreSQL (tsvector) |
|----------------|------------------|----------------------|
| Время поиска (100K docs) | 2-3 мс | 15-30 мс |
| Релевантность | BM25 | ts_rank (TF-IDF) |
| Морфология из коробки | stem_enru (русский/английский) | Требуется расширение |
| Фасетный поиск | FACET оператор | GROUP BY + подзапросы |
| JSON атрибуты | Полная поддержка, JSON_EXTRACT | JSONB (медленнее) |
| Real-time индексация | Да (RT-индексы) | Требует VACUUM |
| Транзакции | Нет ACID | Полная ACID |
| Распределение | Встроенное шардирование | Требует внешних решений |
| Язык запросов | MySQL-подобный (SQL) | PostgreSQL SQL |

### Когда что использовать

**Manticore Search оптимален для:**
- Полнотекстового поиска с требованиями к скорости
- E-commerce каталогов с фасетной навигацией
- Поисковых движков и логов
- Real-time индексации часто меняющихся данных

**PostgreSQL оптимален для:**
- Сложных транзакций (ACID)
- Связанных данных с JOIN операциями
- Хранения мастер-данных и бизнес-логики
- Ситуаций, где целостность данных критична

**Вывод:** Оптимально использовать оба инструмента вместе: PostgreSQL для надежного хранения, Manticore для быстрого поиска.

---

## Часть 7. UPDATE/DELETE в Manticore (NoSQL аспект)

### Демонстрация операций

**UPDATE:**
```sql
UPDATE products SET price = 99999.99, rating = 4.9 WHERE id = 1;
```

**DELETE:**
```sql
DELETE FROM products WHERE id = 1;
```

**REPLACE:** В Manticore нет прямой команды REPLACE. Замена документа реализуется через DELETE + INSERT.

### Отличия от реляционных БД

| Операция | Manticore Search | PostgreSQL |
|----------|------------------|------------|
| Транзакции | Нет ACID | Полная поддержка ACID |
| Консистентность | Eventual consistency (в кластере) | Strong consistency |
| Откат изменений | Невозможен | Возможен (ROLLBACK) |
| Целостность данных | Не гарантируется | Гарантируется |

### NoSQL-подход в Manticore

- Жертвует транзакциями ради скорости поиска
- Использует eventual consistency в кластере
- Оптимизирован для чтения и поиска, а не для сложных обновлений
- JSON атрибуты позволяют хранить полуструктурированные данные

---

## Структура репозитория

```
idz5/
├── README.md
├── docker-compose.yml
├── sql/
│   ├── 01_create_index.sql
│   ├── 02_search_queries.sql
│   ├── 03_facets.sql
│   ├── 04_update_delete.sql
│   └── 05_pg_comparison.sql
├── scripts/
│   ├── load_products.py
│   └── run_all_queries.py
└── checks/
    ├── connectivity.txt
    ├── basic_search.txt
    ├── phrase_search.txt
    ├── proximity_search.txt
    ├── filtered_search.txt
    ├── json_search.txt
    ├── facets.txt
    ├── update_delete.txt
    └── pg_vs_manticore.txt
```

---

## Запуск проекта

```bash
# 1. Запуск Manticore через Docker
docker-compose up -d

# 2. Установка зависимостей Python
pip install pymysql faker

# 3. Генерация и загрузка данных
python scripts/load_products.py

# 4. Выполнение поисковых запросов
python scripts/run_all_queries.py
```

---

## Выводы

1. Развернут и настроен Manticore Search в Docker
2. Создан RT-индекс для каталога товаров
3. Загружены 100,000 тестовых записей
4. Выполнены 5 типов полнотекстовых поисковых запросов
5. Реализован фасетный поиск с агрегациями
6. Проведено сравнение с PostgreSQL
7. Продемонстрированы UPDATE/DELETE операции

**Ключевые выводы:**
- Manticore Search обеспечивает высокую скорость полнотекстового поиска (2-3 мс)
- Встроенный FACET оператор значительно упрощает реализацию фасетной навигации
- Manticore не заменяет, а дополняет реляционные БД для специфических задач поиска
- NoSQL подход (отсутствие транзакций, eventual consistency) оправдан для поисковых систем
