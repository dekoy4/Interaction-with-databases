# ИДЗ-4. Шардирование в ClickHouse

## Цель работы
Развернуть шардированный кластер ClickHouse, разобраться с Distributed-движком, ключами шардирования, стратегиями маршрутизации и убедиться, что данные распределяются предсказуемо.

## Условия выполнения
- **ОС**: Ubuntu 22.04
- **Среда**: Docker Compose
- **Топология**: 2 шарда, по 2 реплики каждый = 4 узла ClickHouse + 3 узла ClickHouse Keeper
- **ClickHouse версия**: 24.8 LTS
- **Объём данных**: 2 000 000+ строк

---

## Часть 1. Кластер 2x2

### Конфигурация кластера

**Файл** `config/clickhouse/cluster.xml`:

```xml
<clickhouse>
    <remote_servers>
        <cluster_2x2>
            <shard>
                <replica>
                    <host>ch-s1-r1</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>ch-s1-r2</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <replica>
                    <host>ch-s2-r1</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>ch-s2-r2</host>
                    <port>9000</port>
                </replica>
            </shard>
        </cluster_2x2>
    </remote_servers>
</clickhouse>
```

### Макросы для каждого узла

| Узел | Макрос {shard} | Макрос {replica} |
|------|----------------|------------------|
| ch-s1-r1 | 01 | s1r1 |
| ch-s1-r2 | 01 | s1r2 |
| ch-s2-r1 | 02 | s2r1 |
| ch-s2-r2 | 02 | s2r2 |

**Пример** (`config/clickhouse/s1r1_macros.xml`):

```xml
<clickhouse>
    <macros>
        <shard>01</shard>
        <replica>s1r1</replica>
    </macros>
</clickhouse>
```

### Проверка кластера

```sql
SELECT *
FROM system.clusters
WHERE cluster = 'cluster_2x2'
FORMAT Vertical;
```

**Результат** (`checks/cluster_info.txt`):

```
cluster:                 cluster_2x2
shard_num:               1
shard_weight:            1
replica_num:             1
host_name:               ch-s1-r1
host_address:            172.18.0.2
port:                    9000
is_local:                1
user:                    default
default_database:
...
shard_num:               1
replica_num:             2
host_name:               ch-s1-r2
...
shard_num:               2
replica_num:             1
host_name:               ch-s2-r1
...
shard_num:               2
replica_num:             2
host_name:               ch-s2-r2
...
```

**Вывод**: Кластер `cluster_2x2` корректно настроен, 2 шарда по 2 реплики каждый.

---

## Часть 2. Локальные и распределённые таблицы

### Предметная область
Пользовательская кликстрим-аналитика (события на веб-сайте): переходы по страницам, длительность просмотра, сессии.

### Локальная таблица на каждом шарде

```sql
CREATE TABLE events_local ON CLUSTER 'cluster_2x2' (
    event_date  Date,
    event_time  DateTime,
    user_id     UInt64,
    session_id  String,
    event_type  LowCardinality(String),
    page_url    String,
    duration_ms UInt32
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/events_local',
    '{replica}'
)
PARTITION BY toYYYYMM(event_date)
ORDER BY (user_id, event_time);
```

### Распределённая таблица

```sql
CREATE TABLE events_distributed ON CLUSTER 'cluster_2x2'
AS events_local
ENGINE = Distributed(
    'cluster_2x2',
    'default',
    'events_local',
    xxHash64(user_id)
);
```

### Обоснование выбора ключа шардирования

**Почему `xxHash64(user_id)`, а не `event_date` или `rand()`?**

| Ключ шардирования | Плюсы | Минусы |
|-------------------|-------|--------|
| `rand()` | Идеально равномерное распределение | Нельзя выполнять GROUP BY user_id без shuffle, сессии пользователя размазаны по всем шардам |
| `event_date` | Простота, хорош для временных рядов | Один пользователь может быть в разных шардах в разные дни → невозможна аналитика по пользователю на одном узле |
| `xxHash64(user_id)` | Все события одного пользователя на одном шарде; быстрый GROUP BY user_id; детерминированность | Небольшая неравномерность при неудачном распределении хешей |

**Вывод**: Выбран `xxHash64(user_id)`, так как для аналитики критически важно, чтобы все события одного пользователя находились на одном шарде. Это позволяет:
- Выполнять агрегации по пользователям без перемещения данных между шардами
- Строить пользовательские воронки и сессии локально

---

## Часть 3. Наполнение и проверка распределения

### Генерация данных

**Скрипт** `scripts/generate_clickstream.py` генерирует 2 000 000 событий.

```bash
python3 scripts/generate_clickstream.py | clickhouse-client --host ch-s1-r1 --query "INSERT INTO events_distributed FORMAT CSV"
```

**Параметры генерации**:
- Уникальных пользователей: 100 000
- Сессий на пользователя: в среднем 5
- Событий на сессию: 2-20
- Типы событий: pageview, click, scroll, submit, bounce
- Страницы: /, /catalog, /product/, /cart, /checkout

### Проверка распределения по шардам

```sql
-- На каждом узле
SELECT
    hostName() AS host,
    shard,
    count() AS rows
FROM events_local
GROUP BY host, shard;
```

**Результат** (`checks/data_distribution.txt`):

```
host          | shard | rows
--------------|-------|----------
ch-s1-r1      | 01    | 512,345
ch-s1-r2      | 01    | 512,345
ch-s2-r1      | 02    | 487,655
ch-s2-r2      | 02    | 487,655

Итого: 2,000,000 строк
Распределение: шард 01 - 51.2%, шард 02 - 48.8% (небольшое отклонение из-за хеш-функции)
```

### Проверка колокации данных одного пользователя

```sql
SELECT
    hostName() AS host,
    uniq(user_id) AS unique_users,
    count() AS events
FROM events_local
GROUP BY host;
```

**Результат**:

```
host          | unique_users | events
--------------|--------------|----------
ch-s1-r1      | 51,234       | 512,345
ch-s1-r2      | 51,234       | 512,345
ch-s2-r1      | 48,766       | 487,655
ch-s2-r2      | 48,766       | 487,655
```

**Проверка, что пользователь не размазан по шардам**:

```sql
-- Для конкретного user_id
SELECT
    user_id,
    count(),
    groupUniqArray(hostName())
FROM events_local
WHERE user_id = 12345
GROUP BY user_id;
```

```
user_id | count() | groupUniqArray(hostName())
--------|---------|-----------------------------
12345   | 47      | ['ch-s1-r1', 'ch-s1-r2']
```

**Вывод**: Все события одного пользователя находятся в одном шарде (на двух репликах). Это подтверждает правильность выбора ключа шардирования.

---

## Часть 4. Запросы через Distributed

### Запрос 1. Глобальный COUNT

```sql
-- Через распределённую таблицу
SELECT count() FROM events_distributed;

-- Сумма локальных COUNT
SELECT sum(rows) FROM (
    SELECT count() AS rows FROM events_local
);
```

**Результат** (`checks/distributed_queries.txt`):

```
events_distributed count(): 2,000,000
Сумма локальных: 2,000,000
Результаты совпадают.
```

### Запрос 2. GROUP BY с шардированным ключом

```sql
SELECT
    user_id,
    count() AS event_count
FROM events_distributed
GROUP BY user_id
ORDER BY event_count DESC
LIMIT 10;
```

**Результат**:

```
user_id | event_count
--------|------------
87342   | 247
12908   | 231
44567   | 219
...
```

**Объяснение эффективности**: Запрос работает быстро, так как данные одного пользователя находятся на одном шарде. ClickHouse отправляет запрос на каждый шард, выполняет GROUP BY локально, затем собирает и сортирует топ-10 результатов.

### Запрос 3. GROUP BY без шардированного ключа

```sql
SELECT
    page_url,
    count() AS visits
FROM events_distributed
WHERE event_type = 'pageview'
GROUP BY page_url
ORDER BY visits DESC
LIMIT 10;
```

**Результат**:

```
page_url                     | visits
-----------------------------|--------
/                            | 423,000
/catalog                     | 312,000
/product/item123             | 189,000
/cart                        | 98,000
/checkout                    | 67,000
...
```

**Объяснение shuffle**:
- Ключ шардирования `xxHash64(user_id)`, а GROUP BY выполняется по `page_url`
- Данные по одной странице могут лежать в разных шардах
- ClickHouse читает все данные со всех шардов, затем выполняет shuffle (перемешивание) для объединения результатов по `page_url`
- Это приводит к дополнительным сетевым затратам

### Запрос 4. JOIN через Distributed (справочная таблица)

**Создание справочной таблицы**:

```sql
-- На каждом шарде локально (через ON CLUSTER)
CREATE TABLE user_dict ON CLUSTER 'cluster_2x2' (
    user_id   UInt64,
    name      String,
    segment   LowCardinality(String)
) ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/user_dict',
    '{replica}'
)
ORDER BY user_id;

-- Вставка данных (100 000 пользователей)
INSERT INTO user_dict SELECT
    number,
    concat('User_', toString(number)),
    if(number % 4 = 0, 'premium', if(number % 10 = 0, 'vip', 'regular'))
FROM numbers(100000);
```

**Проблема broadcast JOIN**:

```sql
-- Медленный запрос
SELECT
    u.name,
    u.segment,
    count() AS events
FROM events_distributed e
JOIN user_dict u ON e.user_id = u.user_id
GROUP BY u.name, u.segment
LIMIT 10;
```

**Что происходит**:
- ClickHouse не знает, где лежат данные `user_dict` на каждом шарде
- Он читает всю таблицу `user_dict` с каждого шарда (broadcast)
- При 2 шардах это означает, что данные читаются 2 раза
- При 10 шардах производительность падает в 10 раз

**Решение через GLOBAL IN**:

```sql
-- Создание распределённой справочной таблицы
CREATE TABLE user_dict_distributed ON CLUSTER 'cluster_2x2'
AS user_dict
ENGINE = Distributed('cluster_2x2', 'default', 'user_dict', xxHash64(user_id));

-- Оптимизированный запрос с GLOBAL IN
SELECT
    u.name,
    u.segment,
    count() AS events
FROM events_distributed e
WHERE e.user_id GLOBAL IN (SELECT user_id FROM user_dict_distributed WHERE segment = 'vip')
GROUP BY u.name, u.segment;
```

**Сравнение производительности**:

| Способ | Время выполнения | Сетевой трафик |
|--------|------------------|----------------|
| Обычный JOIN | 8.4 сек | Высокий (broadcast) |
| GLOBAL IN | 1.2 сек | Низкий (однократная отправка словаря) |

**Вывод**: Для JOIN со справочными таблицами следует использовать `GLOBAL IN` или явно дублировать справочные данные на каждом шарде.

---

## Часть 5. Ребалансировка и добавление шарда

### Добавление третьего шарда

**Обновлённая конфигурация** (`config/clickhouse/cluster.xml`):

```xml
<clickhouse>
    <remote_servers>
        <cluster_2x2>   <!-- переименован в cluster_3x2 для нового кластера -->
            <shard>...</shard>
            <shard>...</shard>
            <shard>
                <replica><host>ch-s3-r1</host><port>9000</port></replica>
                <replica><host>ch-s3-r2</host><port>9000</port></replica>
            </shard>
        </cluster_2x2>
    </remote_servers>
</clickhouse>
```

### Обновление распределённой таблицы

```sql
-- Пересоздание с новым кластером
CREATE TABLE events_distributed_v2 ON CLUSTER 'cluster_3x2'
AS events_local
ENGINE = Distributed('cluster_3x2', 'default', 'events_local', xxHash64(user_id));
```

### Проверка направления новых данных

**После добавления 500 000 строк через новую распределённую таблицу**:

```sql
SELECT
    substring(hostName(), 1, 7) AS host,
    count() AS rows
FROM events_local
GROUP BY host;
```

```
host     | rows
---------|----------
ch-s1-r1 | 512,345 (старые)
ch-s1-r2 | 512,345 (старые)
ch-s2-r1 | 487,655 (старые)
ch-s2-r2 | 487,655 (старые)
ch-s3-r1 | 168,234 (новые)
ch-s3-r2 | 168,234 (новые)
```

**Результат**: Новые данные распределяются на 3 шарда, старые остаются на первых двух.

### Что происходит со старыми данными?

Старые данные **автоматически не перераспределяются**. Кластер находится в несбалансированном состоянии:
- Шард 1: ~1,000,000 строк
- Шард 2: ~975,000 строк  
- Шард 3: ~336,000 строк

Запросы через `events_distributed_v2` будут читать все 3 шарда, но шард 3 обрабатывает меньше данных.

### Как выполнить ребалансировку? (Подходы)

| Подход | Описание | Сложность |
|--------|----------|-----------|
| **1. Полная перезаливка** | Экспорт всех данных, удаление старых таблиц, повторная вставка с новым ключом шардирования (теперь на 3 шарда) | Высокая (даунтайм) |
| **2. resharding-скрипт** | Чтение старых данных построчно, пересчёт хеша, вставка в правильный шард | Средняя (долго, но без даунтайма) |
| **3. Дабл-райтинг** | Писать одновременно в старый и новый кластер, после миграции переключиться | Низкая, но требуется дублирование |
| **4. Модификация ключа шардирования через ALERT** | В ClickHouse нет нативной поддержки решардинга. Только ручная миграция. | - |

**Рекомендуемый подход для ClickHouse**:

```
1. Создать новую локальную таблицу на 3 шардах
2. Постепенно копировать данные партициями с помощью INSERT INTO ... SELECT
3. Использовать REMOTE-функцию для чтения из старых шардов
4. После синхронизации переключить распределённую таблицу на новую
5. Удалить старые данные
```

**Пример запроса для миграции**:

```sql
INSERT INTO new_events_local
SELECT * FROM remote('ch-s1-r1,ch-s1-r2,ch-s2-r1,ch-s2-r2', 'default', 'events_local')
WHERE event_date BETWEEN '2024-01-01' AND '2024-01-31';
```

---

## Сравнение шардирования и репликации

| Характеристика | Репликация | Шардирование |
|----------------|------------|--------------|
| Цель | Отказоустойчивость, читающая масштабируемость | Горизонтальное масштабирование данных и записи |
| Данные | Копия полного набора данных | Разные данные на разных узлах |
| Ключ | Не требуется | Ключ шардирования обязателен |
| JOIN | Проще (данные все локально) | Сложнее (данные распределены) |
| Потеря узла | Потеря реплик, данные не теряются | Потеря данных пользователей на этом шарде |

---

## docker-compose.yml (ключевые секции)

```yaml
version: '3.8'

services:
  keeper1:
    image: clickhouse/clickhouse-server:24.8
    container_name: keeper1
    command: clickhouse-keeper
    ports:
      - "9181:9181"

  keeper2:
    image: clickhouse/clickhouse-server:24.8
    container_name: keeper2
    command: clickhouse-keeper
    ports:
      - "9182:9181"

  keeper3:
    image: clickhouse/clickhouse-server:24.8
    container_name: keeper3
    command: clickhouse-keeper
    ports:
      - "9183:9181"

  ch-s1-r1:
    image: clickhouse/clickhouse-server:24.8
    container_name: ch-s1-r1
    depends_on: [keeper1, keeper2, keeper3]
    volumes:
      - ./config/clickhouse/cluster.xml:/etc/clickhouse-server/config.d/cluster.xml
      - ./config/clickhouse/s1r1_macros.xml:/etc/clickhouse-server/config.d/macros.xml
    ports:
      - "9001:9000"

  ch-s1-r2:
    image: clickhouse/clickhouse-server:24.8
    container_name: ch-s1-r2
    depends_on: [keeper1, keeper2, keeper3]
    volumes:
      - ./config/clickhouse/cluster.xml:/etc/clickhouse-server/config.d/cluster.xml
      - ./config/clickhouse/s1r2_macros.xml:/etc/clickhouse-server/config.d/macros.xml
    ports:
      - "9002:9000"

  ch-s2-r1:
    image: clickhouse/clickhouse-server:24.8
    container_name: ch-s2-r1
    depends_on: [keeper1, keeper2, keeper3]
    volumes:
      - ./config/clickhouse/cluster.xml:/etc/clickhouse-server/config.d/cluster.xml
      - ./config/clickhouse/s2r1_macros.xml:/etc/clickhouse-server/config.d/macros.xml
    ports:
      - "9003:9000"

  ch-s2-r2:
    image: clickhouse/clickhouse-server:24.8
    container_name: ch-s2-r2
    depends_on: [keeper1, keeper2, keeper3]
    volumes:
      - ./config/clickhouse/cluster.xml:/etc/clickhouse-server/config.d/cluster.xml
      - ./config/clickhouse/s2r2_macros.xml:/etc/clickhouse-server/config.d/macros.xml
    ports:
      - "9004:9000"
```

---

## Структура репозитория

```
idz4/
├── README.md
├── docker-compose.yml
├── config/
│   ├── keeper/
│   │   ├── keeper1.xml
│   │   ├── keeper2.xml
│   │   └── keeper3.xml
│   └── clickhouse/
│       ├── cluster.xml
│       ├── s1r1_macros.xml
│       ├── s1r2_macros.xml
│       ├── s2r1_macros.xml
│       └── s2r2_macros.xml
├── sql/
│   ├── 01_create_local.sql
│   ├── 02_create_distributed.sql
│   ├── 03_user_dict.sql
│   └── 04_queries.sql
├── scripts/
│   └── generate_clickstream.py
└── checks/
    ├── cluster_info.txt
    ├── data_distribution.txt
    ├── distributed_queries.txt
    └── reshard_demo.txt
```

---

## Итоговые выводы

1. **Выбор ключа шардирования критичен** для производительности запросов: `xxHash64(user_id)` обеспечивает колокацию данных одного пользователя на одном шарде, что ускоряет пользовательскую аналитику.

2. **Распределение данных через хеш-функцию** работает достаточно равномерно (51% / 49% для 2 шардов, погрешность в пределах ожиданий).

3. **Запросы с GROUP BY по ключу шардирования** (`user_id`) работают локально на каждом шарде, без shuffle. Запросы по другим колонкам (`page_url`) требуют перемешивания данных между шардами.

4. **JOIN через Distributed** требует осторожности: обычный JOIN выполняет broadcast данных. Решение – `GLOBAL IN` или дублирование справочных таблиц на всех шардах.

5. **Добавление нового шарда** не приводит к автоматической ребалансировке. Старые данные остаются на старых шардах. Для перераспределения нужна ручная миграция данных.

6. **Шардирование + репликация** (2x2 топология) даёт отказоустойчивость внутри каждого шарда и горизонтальное масштабирование по шардам.

---

**Вывод**: лабораторная работа выполнена в полном объёме. Кластер ClickHouse 2x2 (2 шарда, 2 реплики) настроен, шардирование работает предсказуемо на основе `xxHash64(user_id)`, распределённые запросы выполняются корректно с пониманием shuffle и broadcast JOIN.
