-- Подсчёт всех сразу
SELECT count() FROM events_distributed;

-- Сумма локальных COUNT-ов по всем шардам
SELECT sum(rows) AS value
FROM (
    SELECT hostName() AS host, count() AS rows
    FROM cluster('cluster_2x2', default, events_local)
    GROUP BY host
);

-- Топ-10 пользователей
SELECT
    user_id,
    count() AS event_count
FROM events_distributed
GROUP BY user_id
ORDER BY event_count DESC
LIMIT 10;

-- Топ-10 страниц
SELECT
    page_url,
    count() AS visits
FROM events_distributed
GROUP BY page_url
ORDER BY visits DESC
LIMIT 10;

-- Broadcast JOIN
SELECT
    e.user_id,
    u.name,
    u.segment,
    count() AS events
FROM events_distributed e
JOIN user_dict u ON e.user_id = u.user_id
GROUP BY e.user_id, u.name, u.segment
ORDER BY events DESC
LIMIT 10;
