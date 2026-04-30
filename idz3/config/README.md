# 3 лабораторная работа 
## Описание работы
### Часть 1. ClickHouse Keeper / ZooKeeper
- *Docker Desktop установлен*
- Устанавливаем образ ClickHouse: docker pull clickhouse/clickhouse-server
  - Если возникла проблема при загрузке, может помочь docker system prune - очистит неиспользуемые файлы (осторожно)
- Создаем директорию mkdir clickhouse-lab -> cd clickhouse-lab
- Создаём пустой конфигурационный файл докера type nul > docker-compose.yml
- Создаём директории для конфигов кипера mkdir keeper
- Открываем .yml через notepad docker-compose.yml и указываем описание сервисов-киперов
```
services:
  keeper1:
    image: clickhouse/clickhouse-server:latest
    container_name: keeper1
    hostname: keeper1
    command: clickhouse-keeper --config-file=/etc/clickhouse-keeper/keeper.xml
    volumes:
      - ./keeper/keeper1.xml:/etc/clickhouse-keeper/keeper.xml
      - keeper1-data:/var/lib/clickhouse
    ports:
      - "9181:9181"

  keeper2:
    image: clickhouse/clickhouse-server:latest
    container_name: keeper2
    hostname: keeper2
    command: clickhouse-keeper --config-file=/etc/clickhouse-keeper/keeper.xml
    volumes:
      - ./keeper/keeper2.xml:/etc/clickhouse-keeper/keeper.xml
      - keeper2-data:/var/lib/clickhouse
    ports:
      - "9182:9181"

  keeper3:
    image: clickhouse/clickhouse-server:latest
    container_name: keeper3
    hostname: keeper3
    command: clickhouse-keeper --config-file=/etc/clickhouse-keeper/keeper.xml
    volumes:
      - ./keeper/keeper3.xml:/etc/clickhouse-keeper/keeper.xml
      - keeper3-data:/var/lib/clickhouse
    ports:
      - "9183:9181"

volumes:
  keeper1-data:
  keeper2-data:
  keeper3-data:
```
- Создаём конфиг для keeper1.xml
```
<clickhouse>
    <keeper_server>
        <tcp_port>9181</tcp_port>
        <server_id>1</server_id>

        <log_storage_path>/var/lib/clickhouse/coordination/log</log_storage_path>
        <snapshot_storage_path>/var/lib/clickhouse/coordination/snapshots</snapshot_storage_path>

        <coordination_settings>
            <operation_timeout_ms>10000</operation_timeout_ms>
            <session_timeout_ms>30000</session_timeout_ms>
            <raft_logs_level>information</raft_logs_level>
        </coordination_settings>

        <raft_configuration>
            <server>
                <id>1</id>
                <hostname>keeper1</hostname>
                <port>9234</port>
            </server>
            <server>
                <id>2</id>
                <hostname>keeper2</hostname>
                <port>9234</port>
            </server>
            <server>
                <id>3</id>
                <hostname>keeper3</hostname>
                <port>9234</port>
            </server>
        </raft_configuration>
    </keeper_server>
</clickhouse>
```
- Копируем конфиг 1го кипера для 2го и 3го через
  - copy keeper\keeper1.xml keeper\keeper2.xml
  - copy keeper\keeper1.xml keeper\keeper3.xml
- Открываем 2ой и 3ий кипер через notepad keeper\keeper2.xml и меняем значение <server_id></server_id> на 2, 3
- Запускаем докер docker compose up -d
  - Проверяем живой ли контейнер docker ps, должны быть указаны 1-3 киперы
  - Проверяем работоспособность распределённого Keeper-кластера, то есть что кворум образовался, а именно что киперы договорились кто из них лидер, а кто последователь, они работают сообща
    - Отвечает ли Kepper как сервис docker exec -i keeper1 bash -c "echo ruok | nc localhost 9181". Ожидаем imok
    - Проверяем роль каждого через docker exec -i keeper1 bash -c "echo mntr | nc localhost 9181". Ожидаем, что у двух в zk_server_state будет follower, а у одного leader
      - [keeper1_health](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/keeper1_health.txt)
      - [keeper2_health](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/keeper2_health.txt)
      - [keeper3_health](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/keeper3_health.txt)
### Часть 2. Реплицированные таблицы
- Создаём папки для ClickHouse-сервисов
```
mkdir clickhouse
mkdir clickhouse\ch1
mkdir clickhouse\ch2
mkdir clickhouse\ch3
```
- Добавлякс CLickHouse-сервисы в docker-compose.yml. notepad docker-compose.yml. 
После киперов в блоке services:
```
  ch1:
    image: clickhouse/clickhouse-server:latest
    container_name: ch1
    hostname: ch1
    volumes:
      - ./clickhouse/ch1/config.xml:/etc/clickhouse-server/config.d/cluster.xml
      - ch1-data:/var/lib/clickhouse
    ports:
      - "8123:8123"
      - "9000:9000"
    depends_on:
      - keeper1
      - keeper2
      - keeper3

  ch2:
    image: clickhouse/clickhouse-server:latest
    container_name: ch2
    hostname: ch2
    volumes:
      - ./clickhouse/ch2/config.xml:/etc/clickhouse-server/config.d/cluster.xml
      - ch2-data:/var/lib/clickhouse
    ports:
      - "8124:8123"
      - "9001:9000"
    depends_on:
      - keeper1
      - keeper2
      - keeper3

  ch3:
    image: clickhouse/clickhouse-server:latest
    container_name: ch3
    hostname: ch3
    volumes:
      - ./clickhouse/ch3/config.xml:/etc/clickhouse-server/config.d/cluster.xml
      - ch3-data:/var/lib/clickhouse
    ports:
      - "8125:8123"
      - "9002:9000"
    depends_on:
      - keeper1
      - keeper2
      - keeper3
```
И в блок volumes
```
  ch1-data:
  ch2-data:
  ch3-data:
```
- Кратко про суть yml и переменных
  - В целом, yml файл даёт информацию докеру что ему и как запускать в контейнере. В сервисах указываются сервисы, для которых надо будет создать контейнер и обеспечить административные настройки типо имён, портов, способов взаимодействия с докером. В вольюмс создаём/используем хранилища необходимые для сервисов. Хранилища принадлежат не запускаемому контейнеру, они принадлежать докеру, их можно переиспользовать. Хранилище - папка. Кликхаус-сервисы используют хранилища для бд, логов. Киперы используют хранилища для координации, они записывают состояние реплик.
  - image - образ, который сервис использует
  - container_name - имя контейнера для Docker, то как мы через докер можем подключиться к сервису-контейнеру
  - hostname - имя машины внутри Docker-сети/контейнера, то как он представлен для других членов кластера
  - command. Контейнеры Киперов и Кликхауса отличаются. При указании образа clickhouse/clickhouse-server:latest создаётся по умолчанию контейнер типа ClickHouse Server, а для кипера нужен ClickHouse Keeper. command говорит докеру об этом и направляет на кипер конфиг
  - volumes. Через volumes мы говорим, что к данному сервису надо подключить файл с компьютера, чтобы далее его предоставлять для ClickHouse. /etc/clickhouse-server/config.d - конфиги, которые читает ClickHouse при запуске
  - ports. Для Кликхауса порт 8123 для HTTP запросов, 9000 порт для коммуникации между узлами. Порт 9181 Кипера для общения Кликхаус-узлов с ним. Левый порт - порт Windows, то есть наше взаимодействие с сервисом. Правый порт - порт внутри контейнера, то есть в каждом контейнере ClickHouse слушает один порт.
 - Создаём конфиги для сервисов
   - notepad clickhouse\ch1\config.xml
   - Указываем
```
<clickhouse>
    <remote_servers>
        <lab_cluster>
            <shard>
                <replica>
                    <host>ch1</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>ch2</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>ch3</host>
                    <port>9000</port>
                </replica>
            </shard>
        </lab_cluster>
    </remote_servers>

    <zookeeper>
        <node>
            <host>keeper1</host>
            <port>9181</port>
        </node>
        <node>
            <host>keeper2</host>
            <port>9181</port>
        </node>
        <node>
            <host>keeper3</host>
            <port>9181</port>
        </node>
    </zookeeper>

    <macros>
        <cluster>lab_cluster</cluster>
        <shard>shard1</shard>
        <replica>ch1</replica>
    </macros>
</clickhouse>
```
  - Копируем для 2го и 3го
```
copy clickhouse\ch1\config.xml clickhouse\ch2\config.xml
copy clickhouse\ch1\config.xml clickhouse\ch3\config.xml
```
  - Заменить значение `<replica>` в `<macros>` на 2, 3
- Запускаем докер docker compose up -d. Должны появиться хранилища (вольюны) и сервисы
- Проверяем docker ps. Должны увидеть киперы и сервисы
- Подключаемся к кликхаус сервису docker exec -it ch1 clickhouse-client. Ожидаем ch1 :)
- Пробуем запустить скрипт
```
CREATE TABLE events ON CLUSTER lab_cluster
(
    event_time DateTime,
    event_type LowCardinality(String),
    user_id UInt64,
    payload String
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/events',
    '{replica}'
)
ORDER BY (event_type, event_time)
PARTITION BY toYYYYMM(event_time);
```
- Возникли проблемы:
  - Кипер оказался недоступен, узлы не могли связаться с кипером. Он слушал сообщения только внутри себя, внутри своего контейнера
    - Добавим <listen_host>0.0.0.0</listen_host> в каждый keeper*.xml сразу после `<clickhouse>`. Так Keeper начнёт принимать подключения изнутри контейнера, из Docker-сети, от других контейнеров
    - Рестартанём docker compose restart keeper1 keeper2 keeper3 ch1 ch2 ch3
    - Проверим коммуникацию сервиса с кипером docker exec -it ch1 bash -c "echo ruok | nc keeper1 9181". Ожидаем imok
  - Кликхаус узлы не могли друг с другом общаться из-за отсутствия авторизации при обращении. Каждый сервис при получения запроса ожидает пользователя, чьи данные сверяет со своими настройками авторизации
    - Сделаем одинакового default-пользователя на всех трёх узлах
    - Создадим notepad clickhouse\users.xml с пользователем
```
<clickhouse>
    <users>
        <default>
            <password></password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>1</access_management>
        </default>
    </users>
</clickhouse>
```
- Добавим `- ./clickhouse/users.xml:/etc/clickhouse-server/users.d/users.xml` в docker-compose.yml в каждый ch1/ch2/ch3 в volume
- Запустим docker compose up -d
- Подключимся к сервису docker exec -it ch1 clickhouse-client
- Пробуем запустить скрипт
```
CREATE TABLE events ON CLUSTER lab_cluster
(
    event_time DateTime,
    event_type LowCardinality(String),
    user_id UInt64,
    payload String
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/events',
    '{replica}'
)
ORDER BY (event_type, event_time)
PARTITION BY toYYYYMM(event_time);
```
- Проверяем, что таблица создалась на трёх репликах. Ожидаем три строки типа ch1 default events ReplicatedMergeTree
```
SELECT
    hostName(),
    database,
    name,
    engine
FROM clusterAllReplicas('lab_cluster', system.tables)
WHERE name = 'events';
```
### Часть 3. Проверка репликации
- Подключаемся к сервису docker exec -it ch1 clickhouse-client
- Используем следующий SQL-скрипт для внесения 100000 строк
```
INSERT INTO events
SELECT
    now() - number % 100000,
    ['click', 'view', 'purchase'][number % 3 + 1],
    number,
    concat('payload_', toString(number))
FROM numbers(100000);
```
Делаем структуру из 100000 последовательных чисел и на основании неё формируем значения строк
- Проверяем, что создалось `SELECT count() FROM events;`. Ожидаем 100000
- Подключаемся к 2му 3му сервису docker exec -it ch2 clickhouse-client и проверяем у них также `SELECT count() FROM events;`. Ожидаем 100000
- Проверяем system.replicas на каждой реплике
  - c1: `docker exec -i ch1 clickhouse-client --query "SELECT database, table, replica_name, is_leader, total_replicas, active_replicas, queue_size, inserts_in_queue, merges_in_queue, log_pointer, last_queue_update FROM system.replicas WHERE table = 'events' FORMAT Vertical" > checks\replicas_status_node1.txt`
    - [replicas_status_node1.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/replicas_status_node1.txt)
  - c2: `docker exec -i ch2 clickhouse-client --query "SELECT database, table, replica_name, is_leader, total_replicas, active_replicas, queue_size, inserts_in_queue, merges_in_queue, log_pointer, last_queue_update FROM system.replicas WHERE table = 'events' FORMAT Vertical" > checks\replicas_status_node2.txt`
    - [replicas_status_node2.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/replicas_status_node2.txt)
  - c3: `docker exec -i ch3 clickhouse-client --query "SELECT database, table, replica_name, is_leader, total_replicas, active_replicas, queue_size, inserts_in_queue, merges_in_queue, log_pointer, last_queue_update FROM system.replicas WHERE table = 'events' FORMAT Vertical" > checks\replicas_status_node3.txt`
    - [replicas_status_node3.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/replicas_status_node3.txt)
### Часть 4. Отказоустойчивость
#### A. Потеря одной реплики
- Останавливаем один из сервисов `docker stop ch3`
- Вносим новые файлы в бд `docker exec -i ch1 clickhouse-client --query "INSERT INTO events SELECT now(), 'after_ch3_down', number + 100000, concat('payload_A_', toString(number)) FROM numbers(10000)"`
- Проверяем, что вторая сервис получил данные `docker exec -i ch2 clickhouse-client --query "SELECT event_type, count() FROM events WHERE event_type = 'after_ch3_down' GROUP BY event_type"`
- Поднимаем отключенный сервис `docker start ch3`
- *Синхронизация прошла очень быстро* - не получилось выполнить 5 часть
- Сохраняем состояние синхронизировавшийся реплики `docker exec -i ch3 clickhouse-client --query "SELECT database, table, replica_name, queue_size, inserts_in_queue, merges_in_queue, total_replicas, active_replicas FROM system.replicas WHERE table = 'events' FORMAT Vertical" > checks\experiment_A_ch3_recovered.txt`
  - [experiment_A_ch3_recovered.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/experiment_A_ch3_recovered.txt)
#### B. Потеря Keeper-узла
- Остановим 3ий кипер `docker stop keeper3`
- Проверяем, что кворумы живы
  - [experiment_B_keeper1_mntr.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/experiment_B_keeper1_mntr.txt)
  - [experiment_B_keeper2_mntr.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/experiment_B_keeper2_mntr.txt)
```
docker exec -i keeper1 bash -c "echo mntr | nc localhost 9181" > checks\experiment_B_keeper1_mntr.txt
docker exec -i keeper2 bash -c "echo mntr | nc localhost 9181" > checks\experiment_B_keeper2_mntr.txt
```
- Внесём данные `docker exec -i ch1 clickhouse-client --query "INSERT INTO events SELECT now(), 'keeper_one_down', number + 200000, concat('payload_B1_', toString(number)) FROM numbers(1000)"`
- Проверим, что кворум сработал и данные реплицировались `docker exec -i ch2 clickhouse-client --query "SELECT event_type, count() FROM events WHERE event_type = 'keeper_one_down' GROUP BY event_type"`
- Остановим второй кипер - разрушим кворум `docker stop keeper2`
- Пробуем вставить 'docker exec -i ch1 clickhouse-client --query "INSERT INTO events SELECT now(), 'keeper_quorum_lost', number + 300000, concat('payload_B2_', toString(number)) FROM numbers(1000)" > checks\experiment_B_insert_without_quorum.txt 2>&1'
  - Запрос завис, до ошибки не дошло, файл [experiment_B_insert_without_quorum.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/experiment_B_insert_without_quorum.txt) оказался пустой
- Проверяем, что чтение доступно `docker exec -i ch1 clickhouse-client --query "SELECT count() FROM events" > checks\experiment_B_select_without_quorum.txt`
  - [experiment_B_select_without_quorum.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/experiment_B_select_without_quorum.txt)
### C. Конфликт данных
- Остановить реплику `docker stop ch2`
- Внести данные `docker exec -i ch1 clickhouse-client --query "INSERT INTO events SELECT now(), 'conflict_test', number + 400000, concat('payload_C_', toString(number)) FROM numbers(5000)"`
- Включить реплику `docker start ch2`
- Проверяем, что реплика догнала `docker exec -i ch2 clickhouse-client --query "SELECT event_type, count() FROM events WHERE event_type = 'conflict_test' GROUP BY event_type"`
- Проверяем очередь `docker exec -i ch2 clickhouse-client --query "SELECT replica_name, queue_size, inserts_in_queue, merges_in_queue FROM system.replicas WHERE table = 'events' FORMAT Vertical" > checks\experiment_C_ch2_queue.txt`
  - [experiment_C_ch2_queue.txt](https://github.com/danilaercegovac/Data-Base-2026/blob/main/3rd%20LAB/checks/experiment_C_ch2_queue.txt)
